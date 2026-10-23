--!nonstrict
-- The battle engine: up to 8 cards against one boss on action timers.
-- A pure simulation with no Roblox services: BattleService steps it in real time and
-- streams its events to the client, and tests/battle_test.luau runs whole fights headless.
--
-- Rules (design doc, "Battle system"):
--   * Every card and the boss has an action bar that fills at its SPD; a SPD 100 bar fills once
--     per turn (Config.Battle.TurnSeconds). A full bar means it acts. Ties go to the leftmost card.
--   * A card's action is its Skill when the cooldown is ready, otherwise its Basic.
--   * Attack cards (front row) have HP and take every boss hit. Support cards (back row) have no HP:
--     they can't be hit or KO'd, and each casts its Basic once as the fight opens.
--   * Ultimates cost 100 energy (+20 per action, +10 per hit taken); fired by UseUltimate or AutoUlt.
--   * Big boss moves show a warning first. At 50% HP the boss adds its phase-2 move; at 20% it enrages.
--   * Win at boss 0 HP. Lose when every Attack card is KO'd or the timer runs out.
--   * Damage = ATK x Skill% x (1 + sum of buffs) x Crit x (1 - boss DEF).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)

local B = Config.Battle

local Engine = {}
Engine.__index = Engine

export type UnitSpec = {
	Id: string,
	CardId: string,
	Stars: number,
	Fusion: number?,
	Border: string?,
	Gear: { { Stat: string, Amount: number } }?, -- the accessory's effects (Items.CardEffects)
}
-- Stats (optional) replaces the difficulty's HP / ATK / WarnSeconds and adds to the boss's DEF / SPD:
-- the Infinite Tower (Tower.luau) fights a boss's moves at stats scaled to the floor. Difficulty still
-- picks which moves are in (MinDifficulty).
export type Stats = { HP: number, ATK: number, WarnSeconds: number, DEF: number?, SPD: number? }
export type Setup = { Units: { UnitSpec }, BossId: string, Difficulty: string, Rng: Random?, Stats: Stats? }

-- Effects that only make sense on a card with HP.
local HP_ONLY = { Heal = true, Shield = true, Cleanse = true, Evade = true, Revive = true }

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function turns(n: number?): number
	return if n then n * B.TurnSeconds else math.huge
end

local function sumStat(effects, stat: string): number
	local total = 0
	for _, effect in effects do
		if effect.Stat == stat then
			total += effect.Amount
		end
	end
	return total
end

local function newUnit(spec: UnitSpec)
	local card = Cards.Get(spec.CardId)
	assert(card, `Unknown card {spec.CardId}`)
	local hasHP = card.Type == "Attack"
	local unit = {
		Id = spec.Id,
		Order = 0,
		Type = card.Type,
		HasHP = hasHP,
		Card = card,
		Main = Cards.Stat(card, card.Main, spec.Stars, spec.Fusion, spec.Border),
		MaxHP = if hasHP then Cards.Stat(card, card.HP or 0, spec.Stars, spec.Fusion, spec.Border) else 0,
		SPD = card.SPD,
		Gauge = 0,
		Energy = 0,
		Shield = 0,
		ShieldLeft = 0,
		Alive = true,
		Frozen = false,
		Actions = 0,
		Buffs = {}, -- [source key] = { Stat, Amount, Left (seconds) }
		Burns = {}, -- { Damage, Ticks, Timer }
		Taunt = 0,
		Invuln = 0,
		Evades = 0,
		Basic = Cards.Ability(card, "Basic"),
		Skill = Cards.Ability(card, "Skill"),
		Ultimate = Cards.Ability(card, "Ultimate"),
		Passives = {}, -- passive effects with a When condition
		Dealt = 0, -- damage dealt this battle
		Healed = 0, -- HP healed + shields given this battle
	}
	unit.HP = unit.MaxHP
	unit.SkillCooldown = if unit.Skill then (unit.Skill.Every or 3) - 1 else 0
	-- The card's accessory (Items.luau): a head start on its Ultimate, or a buff that lasts the whole
	-- fight (Left = huge, so it never runs out and bosses can't steal it).
	for i, effect in spec.Gear or {} do
		if effect.Stat == "StartEnergy" then
			if unit.Ultimate then
				unit.Energy = math.min(B.UltimateCost, unit.Energy + effect.Amount * B.UltimateCost)
			end
		else
			unit.Buffs[`Gear:{i}`] = { Stat = effect.Stat, Amount = effect.Amount, Left = math.huge }
		end
	end
	return unit
end

function Engine.new(setup: Setup)
	local def = Bosses.Get(setup.BossId)
	assert(def, `Unknown boss {setup.BossId}`)
	assert(def.Difficulties[setup.Difficulty], `Unknown difficulty {setup.Difficulty}`)
	local difficulty = setup.Stats or def.Difficulties[setup.Difficulty]

	local self = setmetatable({}, Engine)
	self.Rng = setup.Rng or Random.new()
	self.Time = 0
	self.Over = false
	self.Result = nil
	self.AutoUlt = false
	self.Events = {}
	self.Opened = false
	self.Slot = nil -- the slot of the ability being cast (Basic | Skill | Ultimate | Opening)
	self.WarnSeconds = difficulty.WarnSeconds
	self.BossId = def.Id
	self.Difficulty = setup.Difficulty
	self.DifficultyIndex = Bosses.DifficultyIndex(setup.Difficulty)

	local moves = {}
	for _, move in def.Moves do
		if move.MinDifficulty == nil or Bosses.DifficultyIndex(move.MinDifficulty) <= self.DifficultyIndex then
			table.insert(moves, move)
		end
	end

	self.Boss = {
		Id = "Boss",
		Order = 99,
		Type = "Boss",
		Def = def,
		Moves = moves,
		MaxHP = difficulty.HP,
		ATK = difficulty.ATK,
		DEF = math.min(B.MaxDEF, def.DEF + (setup.Stats and setup.Stats.DEF or 0)),
		SPD = def.SPD + (setup.Stats and setup.Stats.SPD or 0),
		Gauge = 0,
		Alive = true,
		Actions = 0,
		PhaseActions = 0,
		Phase = 1,
		Enraged = false,
		BonusATK = 0, -- from stolen buffs
		Barrier = 0,
		Pending = nil, -- { Move, Target, Left } while a warned move winds up
		Debuffs = {}, -- [source key] = { Stat, Amount, Left }
		Burns = {},
	}
	self.Boss.HP = self.Boss.MaxHP

	self.Allies = {}
	self.ById = { Boss = self.Boss }
	for _, spec in setup.Units do
		local unit = newUnit(spec)
		table.insert(self.Allies, unit)
		self.ById[unit.Id] = unit
	end
	table.sort(self.Allies, function(a, b)
		-- Front row first, then left to right.
		if a.Type ~= b.Type then
			return a.Type == "Attack"
		end
		return a.Id < b.Id
	end)
	for i, unit in self.Allies do
		unit.Order = i
	end

	-- Passives, auras and signatures that are on from the start.
	for _, unit in self.Allies do
		for _, ability in unit.Card.Abilities do
			for _, effect in ability.Effects do
				if ability.Slot == "Passive" then
					if effect.When then
						table.insert(unit.Passives, effect)
					else
						self:RunEffect(unit, effect, true)
					end
				elseif ability.Slot == "Aura" then
					self:RunEffect(unit, effect, true)
				elseif ability.Slot == "Signature" then
					if effect.Kind == "Eclipse" then
						unit.EclipseEvery = effect.Every or 5
					elseif effect.Kind == "DawnOath" then
						self.DawnOath = { Owner = unit, Used = false, Seconds = turns(effect.Turns or 1) }
					end
				end
			end
		end
	end
	self.Events = {} -- start-of-battle effects are part of the initial state, not news
	return self
end

-- Events ------------------------------------------------------------------------

function Engine:Emit(event)
	table.insert(self.Events, event)
end

-- Returns and clears the events since the last call.
function Engine:TakeEvents()
	local events = self.Events
	self.Events = {}
	return events
end

function Engine:Finish(result: string)
	if self.Over then
		return
	end
	self.Over = true
	self.Result = result
	self:Emit({ K = "End", R = result, Time = self.Time })
end

function Engine:Forfeit()
	self:Finish("Forfeit")
end

-- Stats ---------------------------------------------------------------------------

function Engine:Buff(unit, stat: string): number
	local total = sumStat(unit.Buffs, stat)
	local boss = self.Boss
	for _, effect in unit.Passives do
		if effect.Kind == "Buff" and effect.Stat == stat then
			local on = (effect.When == "BossAbove50" and boss.HP > boss.MaxHP * 0.5)
				or (effect.When == "SelfBelow50" and unit.HasHP and unit.HP < unit.MaxHP * 0.5)
			if on then
				total += effect.Amount
			end
		end
	end
	return total
end

function Engine:BossDebuff(stat: string): number
	return sumStat(self.Boss.Debuffs, stat)
end

function Engine:BossDEF(): number
	return math.clamp(self.Boss.DEF - self:BossDebuff("DEF"), 0, B.MaxDEF)
end

function Engine:BossATK(): number
	local boss = self.Boss
	local factor = 1 + (if boss.Enraged then B.EnrageATK else 0) + boss.BonusATK - self:BossDebuff("ATK")
	return boss.ATK * math.max(0.1, factor)
end

function Engine:Speed(unit): number
	if unit == self.Boss then
		return unit.SPD * math.max(0.2, 1 - self:BossDebuff("SPD"))
	end
	return unit.SPD * math.max(0.2, 1 + self:Buff(unit, "SPD"))
end

function Engine:AttackAlive(): boolean
	for _, unit in self.Allies do
		if unit.HasHP and unit.Alive then
			return true
		end
	end
	return false
end

function Engine:GainEnergy(unit, amount: number)
	if unit.Alive and unit.Ultimate then
		unit.Energy = math.min(B.UltimateCost, unit.Energy + amount)
	end
end

-- Targeting -------------------------------------------------------------------------

function Engine:Alive(filter: string?)
	local list = {}
	for _, unit in self.Allies do
		if unit.Alive and (filter == nil or unit.Type == filter) then
			table.insert(list, unit)
		end
	end
	return list
end

local function lowest(list)
	local best, bestRatio = nil, math.huge
	for _, unit in list do
		local ratio = unit.HP / unit.MaxHP
		if ratio < bestRatio then
			best, bestRatio = unit, ratio
		end
	end
	return best
end

-- Who an effect reaches. Heals, shields, cleanses and evades only reach Attack cards.
function Engine:Targets(source, target: string, kind: string?)
	local hpOnly = kind ~= nil and HP_ONLY[kind] == true
	if target == "Self" then
		return if hpOnly and not source.HasHP then {} else { source }
	elseif target == "Lowest" then
		local unit = lowest(self:Alive("Attack"))
		return if unit then { unit } else {}
	elseif target == "Attack" then
		return self:Alive("Attack")
	elseif target == "All" then
		return if hpOnly then self:Alive("Attack") else self:Alive()
	elseif target == "Random" then
		-- Energy only matters to cards with an Ultimate.
		local pool = {}
		for _, unit in self:Alive() do
			if unit.Ultimate then
				table.insert(pool, unit)
			end
		end
		if #pool == 0 then
			return {}
		end
		return { pool[self.Rng:NextInteger(1, #pool)] }
	end
	return {}
end

local function ids(list)
	local out = {}
	for _, unit in list do
		table.insert(out, unit.Id)
	end
	return out
end

-- Damage ----------------------------------------------------------------------------

function Engine:BreakBarrier()
	local boss = self.Boss
	boss.Barrier = 0
	boss.Debuffs["Boss:Broken"] = { Stat = "Vuln", Amount = B.BreakVuln, Left = turns(B.BreakTurns) }
	self:Emit({ K = "Break" })
end

-- A boss barrier soaks Skill / Ultimate damage and lets only a little of anything else through.
function Engine:ThroughBarrier(amount: number, burst: boolean): number
	local boss = self.Boss
	if boss.Barrier <= 0 then
		return amount
	end
	if not burst then
		return round(amount * B.BarrierLeak)
	end
	local absorbed = math.min(boss.Barrier, amount)
	boss.Barrier -= absorbed
	if boss.Barrier <= 0 then
		self:BreakBarrier()
	end
	return amount - absorbed
end

function Engine:StealBuffs()
	local steal = self.Boss.Def.OnPhase and self.Boss.Def.OnPhase.Steal
	if not steal then
		return
	end
	local stolen = 0
	for _, unit in self:Alive("Attack") do
		local bestKey, bestAmount = nil, 0
		for key, buff in unit.Buffs do
			if buff.Left ~= math.huge and buff.Amount > bestAmount then
				bestKey, bestAmount = key, buff.Amount
			end
		end
		if bestKey then
			unit.Buffs[bestKey] = nil
			stolen += 1
		end
	end
	self.Boss.BonusATK += steal
	self:Emit({ K = "Steal", A = stolen, Stat = steal })
end

function Engine:DamageBoss(source, amount: number, crit: boolean, kind: string)
	local boss = self.Boss
	if self.Over then
		return
	end
	boss.HP = math.max(0, boss.HP - amount)
	source.Dealt += amount
	self:Emit({ K = kind, U = source.Id, T = "Boss", A = amount, C = crit or nil, Bl = if boss.Barrier > 0 then true else nil })

	if boss.HP <= 0 then
		self:Finish("Win")
		return
	end
	if boss.Phase == 1 and boss.HP <= boss.MaxHP * B.PhaseAt then
		boss.Phase = 2
		boss.PhaseActions = 0
		local added = {}
		for _, move in boss.Moves do
			if move.Phase == 2 then
				table.insert(added, move.Name)
			end
		end
		self:Emit({ K = "Phase", N = table.concat(added, ", ") })
		self:StealBuffs()
	end
	if not boss.Enraged and boss.HP <= boss.MaxHP * B.EnrageAt then
		boss.Enraged = true
		self:Emit({ K = "Enrage" })
		self:StealBuffs()
	end
end

function Engine:HitBoss(unit, pct: number, ignoreDef: boolean?)
	local buffs = self:Buff(unit, "ATK") + self:BossDebuff("Vuln")
	local crit = self.Rng:NextNumber() < B.CritChance + self:Buff(unit, "Crit")
	local critMult = if crit then B.CritDamage + self:Buff(unit, "CritDamage") else 1
	local def = if ignoreDef then 0 else self:BossDEF()
	local amount = math.max(1, round(unit.Main * pct * (1 + buffs) * critMult * (1 - def)))
	local burst = self.Slot == "Skill" or self.Slot == "Ultimate"
	amount = if ignoreDef then amount else self:ThroughBarrier(amount, burst)
	self:DamageBoss(unit, amount, crit, "Hit")
end

function Engine:DamageAlly(target, amount: number, kind: string)
	if not target.Alive or not target.HasHP or self.Over then
		return
	end
	if target.Invuln > 0 then
		self:Emit({ K = kind, U = "Boss", T = target.Id, A = 0 })
		return
	end
	local absorbed = math.min(target.Shield, amount)
	target.Shield -= absorbed
	target.HP -= amount - absorbed
	self:Emit({ K = kind, U = "Boss", T = target.Id, A = amount, Sh = if absorbed > 0 then absorbed else nil })

	if target.HP > 0 then
		return
	end
	local oath = self.DawnOath
	if oath and not oath.Used then
		oath.Used = true
		target.HP = 1
		target.Invuln = oath.Seconds
		self:Emit({ K = "Signature", U = oath.Owner.Id, T = target.Id, N = "Dawn Oath" })
		return
	end
	target.HP = 0
	target.Alive = false
	target.Shield = 0
	target.Burns = {}
	target.Frozen = false
	target.Taunt = 0
	target.Gauge = 0
	target.Energy = 0
	self:Emit({ K = "KO", T = target.Id })
	if not self:AttackAlive() then
		self:Finish("Lose")
	end
end

function Engine:HitAlly(target, move)
	if not target.Alive then
		return
	end
	if target.Evades > 0 then
		target.Evades -= 1
		self:Emit({ K = "Miss", T = target.Id })
		return
	end
	local atk = self:BossATK()
	local amount = math.max(1, round(atk * move.Pct * (1 - math.min(0.8, self:Buff(target, "Guard")))))
	self:DamageAlly(target, amount, "Hit")
	if not target.Alive then
		return
	end
	self:GainEnergy(target, B.EnergyPerHit)
	if move.Burn then
		table.insert(target.Burns, {
			Damage = math.max(1, round(atk * move.Burn.Pct)),
			Ticks = move.Burn.Turns,
			Timer = B.TurnSeconds,
		})
	end
	if move.Freeze and not target.Frozen then
		target.Frozen = true
		self:Emit({ K = "Frozen", T = target.Id })
	end
end

-- Effects -----------------------------------------------------------------------------

-- quiet: passive/aura upkeep that shouldn't pop text on screen.
function Engine:RunEffect(unit, effect, quiet: boolean?, abilityName: string?)
	local kind = effect.Kind
	local rng = self.Rng
	if kind == "Damage" then
		for _ = 1, effect.Hits or 1 do
			if self.Over then
				return
			end
			self:HitBoss(unit, effect.Pct, effect.IgnoreDef)
		end
		for _, passive in unit.Passives do
			if passive.When == "OnHit" then
				self:RunEffect(unit, passive, false)
			end
		end
	elseif kind == "Burn" then
		if effect.Chance == nil or rng:NextNumber() < effect.Chance then
			table.insert(self.Boss.Burns, {
				Damage = math.max(1, round(unit.Main * effect.Pct)),
				Ticks = effect.Turns or 3,
				Timer = B.TurnSeconds,
				Source = unit,
			})
			self:Emit({ K = "Burned", U = unit.Id, T = "Boss" })
		end
	elseif kind == "Heal" then
		for _, target in self:Targets(unit, effect.Target or "Lowest", kind) do
			local healed = math.min(round(unit.Main * effect.Pct), target.MaxHP - target.HP)
			target.HP += healed
			unit.Healed += healed
			if not quiet then
				self:Emit({ K = "Heal", U = unit.Id, T = target.Id, A = healed })
			end
		end
	elseif kind == "Shield" then
		local amount = round(unit.Main * effect.Pct)
		for _, target in self:Targets(unit, effect.Target or "Lowest", kind) do
			unit.Healed += math.max(0, amount - target.Shield)
			target.Shield = math.max(target.Shield, amount)
			target.ShieldLeft = turns(B.ShieldTurns)
			if not quiet then
				self:Emit({ K = "Shield", U = unit.Id, T = target.Id, A = amount })
			end
		end
	elseif kind == "Buff" then
		local targets = self:Targets(unit, effect.Target or "Self", kind)
		local key = `{unit.Id}:{abilityName or "Passive"}:{effect.Stat}`
		for _, target in targets do
			target.Buffs[key] = { Stat = effect.Stat, Amount = effect.Amount, Left = turns(effect.Turns) }
		end
		if not quiet then
			self:Emit({ K = "Buff", U = unit.Id, T = ids(targets), Stat = effect.Stat, A = effect.Amount })
		end
	elseif kind == "Debuff" then
		local key = `{unit.Id}:{abilityName or "Passive"}:{effect.Stat}`
		self.Boss.Debuffs[key] = { Stat = effect.Stat, Amount = effect.Amount, Left = turns(effect.Turns) }
		if not quiet then
			self:Emit({ K = "Debuff", U = unit.Id, T = "Boss", Stat = effect.Stat, A = effect.Amount })
		end
	elseif kind == "Energy" then
		local targets = self:Targets(unit, effect.Target or "All", kind)
		for _, target in targets do
			self:GainEnergy(target, effect.Amount)
			if effect.ResetSkill and target.Skill then
				target.SkillCooldown = 0
			end
		end
		if not quiet and effect.When == nil then
			self:Emit({ K = "Energy", U = unit.Id, T = ids(targets), A = effect.Amount })
		end
	elseif kind == "Cleanse" then
		for _, target in self:Targets(unit, effect.Target or "All", kind) do
			local removed = 0
			for _ = 1, effect.Amount or 1 do
				if target.Frozen then
					target.Frozen = false
					removed += 1
				elseif #target.Burns > 0 then
					table.remove(target.Burns, 1)
					removed += 1
				end
			end
			if removed > 0 and not quiet then
				self:Emit({ K = "Cleanse", U = unit.Id, T = target.Id })
			end
		end
	elseif kind == "Taunt" then
		if unit.HasHP then
			unit.Taunt = turns(effect.Turns or 2)
			self:Emit({ K = "Taunt", U = unit.Id })
		end
	elseif kind == "Revive" then
		for _, target in self.Allies do
			if target.HasHP and not target.Alive then
				target.Alive = true
				target.HP = math.max(1, round(target.MaxHP * effect.Pct))
				target.Gauge = 0
				self:Emit({ K = "Revive", U = unit.Id, T = target.Id, A = target.HP })
			end
		end
	elseif kind == "Evade" then
		for _, target in self:Targets(unit, effect.Target or "Self", kind) do
			target.Evades += effect.Hits or 1
		end
	end
end

function Engine:RunAbility(unit, ability, slot: string)
	local previous = self.Slot
	self.Slot = slot
	for _, effect in ability.Effects do
		if self.Over then
			break
		end
		self:RunEffect(unit, effect, false, ability.Name)
	end
	self.Slot = previous
end

-- Actions ---------------------------------------------------------------------------

-- As the fight opens, every Support card casts its Basic once (shields up, buffs on, debuffs out).
function Engine:Opening()
	self.Opened = true
	local any = false
	for _, unit in self.Allies do
		if unit.Type == "Support" and unit.Basic then
			if not any then
				self:Emit({ K = "Opening" })
				any = true
			end
			self:Emit({ K = "Act", U = unit.Id, Ab = "Opening", N = unit.Basic.Name })
			self:RunAbility(unit, unit.Basic, "Opening")
		end
	end
end

function Engine:CardAct(unit)
	unit.Actions += 1
	local ability, slot = unit.Basic, "Basic"
	if unit.Skill then
		if unit.SkillCooldown <= 0 then
			ability, slot = unit.Skill, "Skill"
			unit.SkillCooldown = (unit.Skill.Every or 3) - 1
		else
			unit.SkillCooldown -= 1
		end
	end
	if ability then
		self:Emit({ K = "Act", U = unit.Id, Ab = slot, N = ability.Name })
		self:RunAbility(unit, ability, slot)
	end
	if self.Over then
		return
	end
	self:GainEnergy(unit, B.EnergyPerAction)
	for _, passive in unit.Passives do
		if passive.When == "OnAct" then
			self:RunEffect(unit, passive, true)
		end
	end
	if unit.EclipseEvery and unit.Actions % unit.EclipseEvery == 0 and unit.Alive then
		self:Emit({ K = "Signature", U = unit.Id, N = "Eclipse" })
		self:CardAct(unit)
	end
end

function Engine:ChooseMove()
	local boss = self.Boss
	local moves = boss.Moves
	for _, move in moves do
		local phase = move.Phase or 1
		if phase <= boss.Phase then
			if move.Every == nil then
				return move
			end
			local count = if phase >= 2 then boss.PhaseActions else boss.Actions
			if count % move.Every == 0 then
				return move
			end
		end
	end
	return moves[#moves]
end

-- Single-target pick: the taunting card, else a random Attack card.
function Engine:PickTarget()
	local front = self:Alive("Attack")
	for _, unit in front do
		if unit.Taunt > 0 then
			return unit
		end
	end
	if #front == 0 then
		return nil
	end
	return front[self.Rng:NextInteger(1, #front)]
end

function Engine:BossAct()
	local boss = self.Boss
	boss.Actions += 1
	if boss.Phase >= 2 then
		boss.PhaseActions += 1
	end
	local move = self:ChooseMove()
	local target = if move.Target == "Single" then self:PickTarget() else nil
	if move.Warn then
		boss.Pending = { Move = move, Target = target, Left = self.WarnSeconds }
		local marked = if target then { target.Id } elseif move.Target == "Self" then {} else ids(self:Alive("Attack"))
		self:Emit({ K = "Warn", N = move.Name, T = marked, S = self.WarnSeconds })
	else
		self:BossStrike(move, target)
	end
end

function Engine:BossStrike(move, target)
	local boss = self.Boss
	self:Emit({ K = "Act", U = "Boss", Ab = if move.Warn then "Skill" else "Basic", N = move.Name })

	if move.Target == "Self" then
		if move.Barrier then
			boss.Barrier = round(boss.MaxHP * move.Barrier)
			self:Emit({ K = "Barrier", A = boss.Barrier })
		end
		return
	end

	local hitList = {}
	if move.Target == "All" then
		for _, unit in self:Alive("Attack") do
			for _ = 1, move.Hits or 1 do
				table.insert(hitList, unit)
			end
		end
	elseif move.Target == "Random" then
		for _ = 1, move.Hits or 1 do
			local unit = self:PickTarget()
			if unit then
				table.insert(hitList, unit)
			end
		end
	else
		-- A taunt raised during the warning still pulls the hit; a KO'd target is replaced.
		local pick = self:PickTarget()
		if pick and pick.Taunt > 0 then
			target = pick
		elseif target == nil or not target.Alive then
			target = pick
		end
		if target then
			for _ = 1, move.Hits or 1 do
				table.insert(hitList, target)
			end
		end
	end
	for _, unit in hitList do
		if self.Over then
			return
		end
		self:HitAlly(unit, move)
	end

	if move.Slow and not self.Over then
		for _, unit in self:Alive() do
			unit.Buffs["Boss:Slow"] = { Stat = "SPD", Amount = -move.Slow.Amount, Left = turns(move.Slow.Turns) }
		end
		self:Emit({ K = "Slow", A = move.Slow.Amount })
	end
end

-- Ultimates -------------------------------------------------------------------------------

function Engine:CanUltimate(unit): boolean
	return unit ~= nil
		and unit ~= self.Boss
		and unit.Alive
		and unit.Ultimate ~= nil
		and unit.Energy >= B.UltimateCost
		and not self.Over
end

function Engine:UseUltimate(id: string): (boolean, string?)
	local unit = self.ById[id]
	if not self:CanUltimate(unit) then
		return false, "NotReady"
	end
	unit.Energy = 0
	self:Emit({ K = "Act", U = unit.Id, Ab = "Ultimate", N = unit.Ultimate.Name })
	self:RunAbility(unit, unit.Ultimate, "Ultimate")
	return true, nil
end

-- Time -------------------------------------------------------------------------------------

local function tickTimers(list, dt: number)
	for key, entry in list do
		entry.Left -= dt
		if entry.Left <= 0 then
			list[key] = nil
		end
	end
end

-- Advances burns: calls hit(burn) for each tick that is due.
local function tickBurns(burns, dt: number, hit)
	local i = 1
	while i <= #burns do
		local burn = burns[i]
		burn.Timer -= dt
		if burn.Timer <= 0 then
			burn.Timer += B.TurnSeconds
			burn.Ticks -= 1
			hit(burn)
		end
		if burn.Ticks <= 0 then
			table.remove(burns, i)
		else
			i += 1
		end
	end
end

function Engine:Step(dt: number)
	if self.Over then
		return
	end
	if not self:AttackAlive() then
		self:Finish("Lose")
		return
	end
	if not self.Opened then
		self:Opening()
		if self.Over then
			return
		end
	end
	self.Time += dt
	local boss = self.Boss

	-- Durations and damage over time.
	for _, unit in self.Allies do
		if unit.Alive then
			tickTimers(unit.Buffs, dt)
			unit.Taunt = math.max(0, unit.Taunt - dt)
			unit.Invuln = math.max(0, unit.Invuln - dt)
			if unit.Shield > 0 then
				unit.ShieldLeft -= dt
				if unit.ShieldLeft <= 0 then
					unit.Shield = 0
				end
			end
			tickBurns(unit.Burns, dt, function(burn)
				self:DamageAlly(unit, burn.Damage, "Burn")
			end)
		end
	end
	tickTimers(boss.Debuffs, dt)
	tickBurns(boss.Burns, dt, function(burn)
		self:DamageBoss(burn.Source, self:ThroughBarrier(burn.Damage, false), false, "Burn")
	end)
	if self.Over then
		return
	end

	-- A warned boss move lands when its warning runs out.
	if boss.Pending then
		boss.Pending.Left -= dt
		if boss.Pending.Left <= 0 then
			local pending = boss.Pending
			boss.Pending = nil
			self:BossStrike(pending.Move, pending.Target)
		end
	end

	-- Fill action bars, then let every full bar act (fullest first, ties to the left).
	local ready = {}
	for _, unit in self.Allies do
		if unit.Alive then
			unit.Gauge += self:Speed(unit) * dt / (100 * B.TurnSeconds)
			if unit.Gauge >= 1 then
				table.insert(ready, unit)
			end
		end
	end
	if boss.Pending == nil then
		boss.Gauge += self:Speed(boss) * dt / (100 * B.TurnSeconds)
		if boss.Gauge >= 1 then
			table.insert(ready, boss)
		end
	end
	table.sort(ready, function(a, b)
		if a.Gauge ~= b.Gauge then
			return a.Gauge > b.Gauge
		end
		return a.Order < b.Order
	end)
	for _, unit in ready do
		if self.Over then
			return
		end
		if unit.Alive and unit.Gauge >= 1 then
			unit.Gauge -= 1
			if unit == boss then
				self:BossAct()
			elseif unit.Frozen then
				unit.Frozen = false
				self:Emit({ K = "Thaw", U = unit.Id })
			else
				self:CardAct(unit)
			end
		end
	end

	if self.AutoUlt then
		for _, unit in self.Allies do
			if self:CanUltimate(unit) then
				self:UseUltimate(unit.Id)
			end
		end
	end

	if not self.Over and self.Time >= B.TimeLimit then
		self:Finish("Timeout")
	end
end

-- For the client ------------------------------------------------------------------------------

-- Static facts the battle screen needs once.
function Engine:Info()
	local allies = {}
	for _, unit in self.Allies do
		table.insert(allies, {
			Id = unit.Id,
			CardId = unit.Card.Id,
			MaxHP = if unit.HasHP then unit.MaxHP else nil,
			Main = unit.Main,
			Ultimate = if unit.Ultimate then unit.Ultimate.Name else nil,
		})
	end
	local boss = self.Boss
	return {
		BossId = self.BossId,
		Difficulty = self.Difficulty,
		Boss = { MaxHP = boss.MaxHP, ATK = round(boss.ATK), DEF = boss.DEF, SPD = boss.SPD },
		Allies = allies,
		TimeLimit = B.TimeLimit,
		UltimateCost = B.UltimateCost,
	}
end

local function gauge(value: number): number
	return math.floor(math.clamp(value, 0, 1) * 100) / 100
end

-- Live numbers for every unit. Card flags: B burning, Z frozen, T taunt, U buffed, S slowed,
-- G guarded, I invulnerable. Boss flags: D DEF down, A ATK down, S slowed, V takes more damage,
-- B burning, E enraged, W winding up, R barrier up. Support cards send no HP.
function Engine:Snapshot()
	local units = {}
	for _, unit in self.Allies do
		local flags = ""
		if #unit.Burns > 0 then
			flags ..= "B"
		end
		if unit.Frozen then
			flags ..= "Z"
		end
		if unit.Taunt > 0 then
			flags ..= "T"
		end
		local up, slowed, guarded = false, false, false
		for _, buff in unit.Buffs do
			local stat: string = buff.Stat
			if buff.Left ~= math.huge then
				if stat == "Guard" then
					guarded = true
				elseif buff.Amount > 0 then
					up = true
				elseif stat == "SPD" then
					slowed = true
				end
			end
		end
		if up then
			flags ..= "U"
		end
		if slowed then
			flags ..= "S"
		end
		if guarded then
			flags ..= "G"
		end
		if unit.Invuln > 0 then
			flags ..= "I"
		end
		units[unit.Id] = {
			H = if unit.HasHP then math.max(0, round(unit.HP)) else nil,
			S = if unit.HasHP then round(unit.Shield) else nil,
			E = unit.Energy,
			G = if unit.Alive then gauge(unit.Gauge) else 0,
			F = flags,
		}
	end
	local boss = self.Boss
	local flags = ""
	for _, stat in { "DEF", "ATK", "SPD", "Vuln" } do
		for _, debuff in boss.Debuffs do
			if debuff.Stat == stat and debuff.Left ~= math.huge then
				flags ..= if stat == "DEF" then "D" elseif stat == "ATK" then "A" elseif stat == "SPD" then "S" else "V"
				break
			end
		end
	end
	if #boss.Burns > 0 then
		flags ..= "B"
	end
	if boss.Enraged then
		flags ..= "E"
	end
	if boss.Pending then
		flags ..= "W"
	end
	if boss.Barrier > 0 then
		flags ..= "R"
	end
	units.Boss = {
		H = round(boss.HP),
		G = if boss.Pending then 1 else gauge(boss.Gauge),
		F = flags,
		Bar = if boss.Barrier > 0 then boss.Barrier else nil,
	}
	return { T = math.floor(self.Time * 10) / 10, U = units }
end

-- End-of-fight numbers for the results screen.
function Engine:Summary()
	local dealt = {}
	for _, unit in self.Allies do
		dealt[unit.Id] = { Dealt = unit.Dealt, Healed = unit.Healed, Alive = unit.Alive }
	end
	return {
		Result = self.Result,
		Time = math.floor(self.Time * 10) / 10,
		BossHP = round(self.Boss.HP),
		BossMaxHP = self.Boss.MaxHP,
		Units = dealt,
	}
end

return Engine
