--!nonstrict
-- The battle engine: up to 8 cards against an enemy squad (the leader and its three guards) on
-- action timers. A pure simulation with no Roblox services: BattleService steps it in real time and
-- streams its events to the client, and tests/battle_test.luau runs whole fights headless.
--
-- Rules (design doc, "Battle system", made 4v4 on 2026-10-23):
--   * Every card and every enemy has an action bar that fills at its SPD; a SPD 100 bar fills once
--     per turn (Config.Battle.TurnSeconds). A full bar means it acts. Ties go to the leftmost card.
--   * A card's action is its Skill when the cooldown is ready, otherwise its Basic.
--   * Attack cards (front row) have HP and take every enemy hit. Support cards (back row) have no HP:
--     they can't be hit or KO'd, and each casts its Basic once as the fight opens.
--   * The enemy side is the leader ("Boss": a world boss, or a tower echo) and three guards (G1-G3,
--     Bosses.GuardTypes): Strikers hit hard, Hexers burn / freeze / slow, Menders heal the squad and
--     rally it, Warders taunt and shield the leader (Protect). Guards can be KO'd; the leader can't be
--     helped once it falls.
--   * Cards hit the player's focus target (SetFocus, tapped on screen) when it's alive, otherwise a
--     taunting guard, otherwise the enemy with the least HP left. Abilities with Target "Enemies" hit
--     every enemy, "RandomEnemy" picks again for each hit.
--   * Ultimates cost 100 energy (+20 per action, +10 per hit taken); fired by UseUltimate or AutoUlt.
--   * Big enemy moves show a warning first. At 50% HP the leader adds its phase-2 move; at 20% it enrages.
--   * Win when the leader falls. Lose when every Attack card is KO'd or the timer runs out.
--   * Damage = ATK x Skill% x (1 + sum of buffs) x Crit x (1 - target DEF) x (1 - Protect on the leader).

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
	Trait: { { Stat: string, Amount: number } }?, -- the card's trait effects (Traits.Effects)
}
-- Stats (optional) replaces the difficulty's HP / ATK / WarnSeconds and adds to the leader's DEF / SPD:
-- the Infinite Tower (Tower.luau) fights a boss's moves at stats scaled to the floor. Difficulty still
-- picks which moves are in (MinDifficulty). Guards (optional) replaces the boss's own guard ids.
export type Stats = { HP: number, ATK: number, WarnSeconds: number, DEF: number?, SPD: number? }
export type Setup = {
	Units: { UnitSpec },
	BossId: string,
	Difficulty: string,
	Rng: Random?,
	Stats: Stats?,
	Guards: { string }?,
}

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
	-- The card's trait (Traits.luau): a head start on its Ultimate, or a buff that lasts the whole
	-- fight (Left = huge, so it never runs out and bosses can't steal it).
	for i, effect in spec.Trait or {} do
		if effect.Stat == "StartEnergy" then
			if unit.Ultimate then
				unit.Energy = math.min(B.UltimateCost, unit.Energy + effect.Amount * B.UltimateCost)
			end
		else
			unit.Buffs[`Trait:{i}`] = { Stat = effect.Stat, Amount = effect.Amount, Left = math.huge }
		end
	end
	return unit
end

-- One enemy: the leader (a boss) or a guard. Both share every field the engine reads.
local function newEnemy(id: string, order: number, props)
	local enemy = {
		Id = id,
		Order = order,
		Type = "Enemy",
		Leader = props.Leader == true,
		Def = props.Def,
		Name = props.Name,
		Moves = props.Moves,
		MaxHP = math.max(1, round(props.HP)),
		ATK = props.ATK,
		DEF = math.min(B.MaxDEF, props.DEF),
		SPD = props.SPD,
		Taunt = props.Taunt == true,
		Protect = props.Protect or 0,
		Gauge = 0,
		Alive = true,
		Actions = 0,
		PhaseActions = 0,
		Phase = 1,
		Enraged = false,
		BonusATK = 0, -- from stolen buffs (leader)
		Barrier = 0,
		Pending = nil, -- { Move, Target, Left } while a warned move winds up
		Debuffs = {}, -- [source key] = { Stat, Amount, Left }: from the player's cards
		Buffs = {}, -- [source key] = { Stat, Amount, Left }: from a Mender's Rally
		Burns = {},
		Dealt = 0,
	}
	enemy.HP = enemy.MaxHP
	return enemy
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
	self.Focus = nil -- the enemy id the player tapped
	self.Events = {}
	self.Opened = false
	self.Slot = nil -- the slot of the ability being cast (Basic | Skill | Ultimate | Opening)
	self.WarnSeconds = difficulty.WarnSeconds
	self.BossId = def.Id
	self.Difficulty = setup.Difficulty
	self.DifficultyIndex = Bosses.DifficultyIndex(setup.Difficulty)

	local function movesFor(list)
		local moves = {}
		for _, move in list do
			if move.MinDifficulty == nil or Bosses.DifficultyIndex(move.MinDifficulty) <= self.DifficultyIndex then
				table.insert(moves, move)
			end
		end
		return moves
	end

	local leaderHP, leaderATK = difficulty.HP, difficulty.ATK
	self.Boss = newEnemy("Boss", 100, {
		Leader = true,
		Def = def,
		Name = def.Name,
		Moves = movesFor(def.Moves),
		HP = leaderHP,
		ATK = leaderATK,
		DEF = def.DEF + (setup.Stats and setup.Stats.DEF or 0),
		SPD = def.SPD + (setup.Stats and setup.Stats.SPD or 0),
	})
	self.Enemies = { self.Boss }
	self.ById = { Boss = self.Boss }
	for i, guardId in setup.Guards or def.Guards or {} do
		local g = Bosses.GuardTypes[guardId]
		assert(g, `Unknown guard {guardId}`)
		local enemy = newEnemy(`G{i}`, 100 + i, {
			Def = g,
			Name = g.Name,
			Moves = movesFor(g.Moves),
			HP = leaderHP * g.HP,
			ATK = leaderATK * g.ATK,
			DEF = g.DEF,
			SPD = g.SPD,
			Taunt = g.Taunt,
			Protect = g.Protect,
		})
		table.insert(self.Enemies, enemy)
		self.ById[enemy.Id] = enemy
	end

	self.Allies = {}
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

-- The player's target: an enemy id (it must be alive), or nil to let the cards pick.
function Engine:SetFocus(id: unknown): boolean
	if id == nil then
		self.Focus = nil
		return true
	end
	local enemy = if type(id) == "string" then self.ById[id] else nil
	if enemy == nil or enemy.Type ~= "Enemy" or not enemy.Alive or self.Over then
		return false
	end
	self.Focus = id
	return true
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

function Engine:EnemyDebuff(enemy, stat: string): number
	return sumStat(enemy.Debuffs, stat)
end

function Engine:EnemyDEF(enemy): number
	return math.clamp(enemy.DEF - self:EnemyDebuff(enemy, "DEF"), 0, B.MaxDEF)
end

function Engine:EnemyATK(enemy): number
	local factor = 1
		+ (if enemy.Enraged then B.EnrageATK else 0)
		+ enemy.BonusATK
		+ sumStat(enemy.Buffs, "ATK")
		- self:EnemyDebuff(enemy, "ATK")
	return enemy.ATK * math.max(0.1, factor)
end

-- How much less damage the leader takes while a Warder stands (the strongest one counts).
function Engine:Protection(enemy): number
	if not enemy.Leader then
		return 0
	end
	local best = 0
	for _, other in self.Enemies do
		if other.Alive and other ~= enemy then
			best = math.max(best, other.Protect)
		end
	end
	return best
end

function Engine:Speed(unit): number
	if unit.Type == "Enemy" then
		return unit.SPD * math.max(0.2, 1 - self:EnemyDebuff(unit, "SPD"))
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

function Engine:AliveEnemies()
	local list = {}
	for _, enemy in self.Enemies do
		if enemy.Alive then
			table.insert(list, enemy)
		end
	end
	return list
end

-- Who the cards hit: the player's focus, else a taunting guard, else whoever has the least HP left.
function Engine:CardTarget()
	local focus = self.Focus and self.ById[self.Focus]
	if focus and focus.Alive then
		return focus
	end
	local best = nil
	for _, enemy in self.Enemies do
		if enemy.Alive then
			if enemy.Taunt then
				return enemy
			end
			if best == nil or enemy.HP < best.HP then
				best = enemy
			end
		end
	end
	return best
end

-- The enemies an effect on the enemy side reaches.
function Engine:EnemyTargets(target: string?)
	if target == "Enemies" then
		return self:AliveEnemies()
	elseif target == "RandomEnemy" then
		local alive = self:AliveEnemies()
		return if #alive > 0 then { alive[self.Rng:NextInteger(1, #alive)] } else {}
	end
	local enemy = self:CardTarget()
	return if enemy then { enemy } else {}
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

-- Who an effect on the player's side reaches. Heals, shields, cleanses and evades only reach Attack cards.
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

function Engine:BreakBarrier(enemy)
	enemy.Barrier = 0
	enemy.Debuffs["Boss:Broken"] = { Stat = "Vuln", Amount = B.BreakVuln, Left = turns(B.BreakTurns) }
	self:Emit({ K = "Break", T = enemy.Id })
end

-- A barrier soaks Skill / Ultimate damage and lets only a little of anything else through.
function Engine:ThroughBarrier(enemy, amount: number, burst: boolean): number
	if enemy.Barrier <= 0 then
		return amount
	end
	if not burst then
		return round(amount * B.BarrierLeak)
	end
	local absorbed = math.min(enemy.Barrier, amount)
	enemy.Barrier -= absorbed
	if enemy.Barrier <= 0 then
		self:BreakBarrier(enemy)
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

function Engine:DamageEnemy(enemy, source, amount: number, crit: boolean, kind: string)
	if self.Over or not enemy.Alive then
		return
	end
	enemy.HP = math.max(0, enemy.HP - amount)
	if source then
		source.Dealt += amount
	end
	self:Emit({
		K = kind,
		U = if source then source.Id else nil,
		T = enemy.Id,
		A = amount,
		C = crit or nil,
		Bl = if enemy.Barrier > 0 then true else nil,
	})

	if enemy.HP <= 0 then
		if enemy.Leader then
			self:Finish("Win")
			return
		end
		enemy.Alive = false
		enemy.Pending = nil
		enemy.Burns = {}
		enemy.Gauge = 0
		self:Emit({ K = "KO", T = enemy.Id })
		if self.Focus == enemy.Id then
			self.Focus = nil
		end
		return
	end
	if not enemy.Leader then
		return
	end
	if enemy.Phase == 1 and enemy.HP <= enemy.MaxHP * B.PhaseAt then
		enemy.Phase = 2
		enemy.PhaseActions = 0
		local added = {}
		for _, move in enemy.Moves do
			if move.Phase == 2 then
				table.insert(added, move.Name)
			end
		end
		self:Emit({ K = "Phase", N = table.concat(added, ", ") })
		self:StealBuffs()
	end
	if not enemy.Enraged and enemy.HP <= enemy.MaxHP * B.EnrageAt then
		enemy.Enraged = true
		self:Emit({ K = "Enrage" })
		self:StealBuffs()
	end
end

function Engine:HitEnemy(unit, enemy, pct: number, ignoreDef: boolean?)
	local buffs = self:Buff(unit, "ATK") + self:EnemyDebuff(enemy, "Vuln")
	local crit = self.Rng:NextNumber() < B.CritChance + self:Buff(unit, "Crit")
	local critMult = if crit then B.CritDamage + self:Buff(unit, "CritDamage") else 1
	local def = if ignoreDef then 0 else self:EnemyDEF(enemy)
	local protect = if ignoreDef then 0 else self:Protection(enemy)
	local amount = math.max(1, round(unit.Main * pct * (1 + buffs) * critMult * (1 - def) * (1 - protect)))
	local burst = self.Slot == "Skill" or self.Slot == "Ultimate"
	amount = if ignoreDef then amount else self:ThroughBarrier(enemy, amount, burst)
	self:DamageEnemy(enemy, unit, amount, crit, "Hit")
end

function Engine:DamageAlly(target, amount: number, kind: string, sourceId: string?)
	if not target.Alive or not target.HasHP or self.Over then
		return
	end
	if target.Invuln > 0 then
		self:Emit({ K = kind, U = sourceId, T = target.Id, A = 0 })
		return
	end
	local absorbed = math.min(target.Shield, amount)
	target.Shield -= absorbed
	target.HP -= amount - absorbed
	self:Emit({ K = kind, U = sourceId, T = target.Id, A = amount, Sh = if absorbed > 0 then absorbed else nil })

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

function Engine:HitAlly(enemy, target, move)
	if not target.Alive then
		return
	end
	if target.Evades > 0 then
		target.Evades -= 1
		self:Emit({ K = "Miss", U = enemy.Id, T = target.Id })
		return
	end
	local atk = self:EnemyATK(enemy)
	local amount = math.max(1, round(atk * move.Pct * (1 - math.min(0.8, self:Buff(target, "Guard")))))
	self:DamageAlly(target, amount, "Hit", enemy.Id)
	if not target.Alive then
		return
	end
	self:GainEnergy(target, B.EnergyPerHit)
	if move.Burn then
		table.insert(target.Burns, {
			Damage = math.max(1, round(atk * move.Burn.Pct)),
			Ticks = move.Burn.Turns,
			Timer = B.TurnSeconds,
			Source = enemy.Id,
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
			for _, enemy in self:EnemyTargets(effect.Target) do
				if self.Over then
					return
				end
				self:HitEnemy(unit, enemy, effect.Pct, effect.IgnoreDef)
			end
		end
		for _, passive in unit.Passives do
			if passive.When == "OnHit" then
				self:RunEffect(unit, passive, false)
			end
		end
	elseif kind == "Burn" then
		if effect.Chance == nil or rng:NextNumber() < effect.Chance then
			for _, enemy in self:EnemyTargets(effect.Target) do
				table.insert(enemy.Burns, {
					Damage = math.max(1, round(unit.Main * effect.Pct)),
					Ticks = effect.Turns or 3,
					Timer = B.TurnSeconds,
					Source = unit,
				})
				self:Emit({ K = "Burned", U = unit.Id, T = enemy.Id })
			end
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
		for _, enemy in self:EnemyTargets(effect.Target) do
			enemy.Debuffs[key] = { Stat = effect.Stat, Amount = effect.Amount, Left = turns(effect.Turns) }
			if not quiet then
				self:Emit({ K = "Debuff", U = unit.Id, T = enemy.Id, Stat = effect.Stat, A = effect.Amount })
			end
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
		local target = self:CardTarget()
		self:Emit({ K = "Act", U = unit.Id, Ab = slot, N = ability.Name, T = if target then target.Id else nil })
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

function Engine:ChooseMove(enemy)
	local moves = enemy.Moves
	for _, move in moves do
		local phase = move.Phase or 1
		if phase <= enemy.Phase then
			if move.Every == nil then
				return move
			end
			local count = if phase >= 2 then enemy.PhaseActions else enemy.Actions
			if count % move.Every == 0 then
				return move
			end
		end
	end
	return moves[#moves]
end

-- Single-target pick on the player's side: the taunting card, else a random Attack card.
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

function Engine:EnemyAct(enemy)
	enemy.Actions += 1
	if enemy.Phase >= 2 then
		enemy.PhaseActions += 1
	end
	local move = self:ChooseMove(enemy)
	local target = if move.Target == "Single" then self:PickTarget() else nil
	if move.Warn then
		enemy.Pending = { Move = move, Target = target, Left = self.WarnSeconds }
		local marked = if target then { target.Id } elseif move.Target == "Self" or move.Target == "Ally" then {} else ids(self:Alive("Attack"))
		self:Emit({ K = "Warn", U = enemy.Id, N = move.Name, T = marked, S = self.WarnSeconds })
	else
		self:EnemyStrike(enemy, move, target)
	end
end

-- A Mender's support move: heal the most hurt enemy, or rally the squad.
function Engine:EnemySupport(enemy, move)
	if move.Heal then
		local hurt, ratio = nil, 1
		for _, other in self:AliveEnemies() do
			local r = other.HP / other.MaxHP
			if r < ratio then
				hurt, ratio = other, r
			end
		end
		if hurt then
			local healed = math.min(round(self.Boss.MaxHP * move.Heal), hurt.MaxHP - hurt.HP)
			hurt.HP += healed
			self:Emit({ K = "EnemyHeal", U = enemy.Id, T = hurt.Id, A = healed })
		end
	end
	if move.Rally then
		for _, other in self:AliveEnemies() do
			other.Buffs[`Rally:{enemy.Id}`] = { Stat = "ATK", Amount = move.Rally.Amount, Left = turns(move.Rally.Turns) }
		end
		self:Emit({ K = "Rally", U = enemy.Id, A = move.Rally.Amount })
	end
end

function Engine:EnemyStrike(enemy, move, target)
	if not enemy.Alive then
		return
	end
	self:Emit({ K = "Act", U = enemy.Id, Ab = if move.Warn then "Skill" else "Basic", N = move.Name })

	if move.Target == "Self" then
		if move.Barrier then
			enemy.Barrier = round(enemy.MaxHP * move.Barrier)
			self:Emit({ K = "Barrier", U = enemy.Id, A = enemy.Barrier })
		end
		return
	elseif move.Target == "Ally" then
		self:EnemySupport(enemy, move)
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
		self:HitAlly(enemy, unit, move)
	end

	if move.Slow and not self.Over then
		for _, unit in self:Alive() do
			unit.Buffs["Boss:Slow"] = { Stat = "SPD", Amount = -move.Slow.Amount, Left = turns(move.Slow.Turns) }
		end
		self:Emit({ K = "Slow", U = enemy.Id, A = move.Slow.Amount })
	end
end

-- Ultimates -------------------------------------------------------------------------------

function Engine:CanUltimate(unit): boolean
	return unit ~= nil
		and unit.Type ~= "Enemy"
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
	local target = self:CardTarget()
	self:Emit({ K = "Act", U = unit.Id, Ab = "Ultimate", N = unit.Ultimate.Name, T = if target then target.Id else nil })
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
				self:DamageAlly(unit, burn.Damage, "Burn", burn.Source)
			end)
		end
	end
	for _, enemy in self.Enemies do
		if enemy.Alive then
			tickTimers(enemy.Debuffs, dt)
			tickTimers(enemy.Buffs, dt)
			tickBurns(enemy.Burns, dt, function(burn)
				local amount = round(burn.Damage * (1 - self:Protection(enemy)))
				self:DamageEnemy(enemy, burn.Source, self:ThroughBarrier(enemy, amount, false), false, "Burn")
			end)
		end
	end
	if self.Over then
		return
	end

	-- A warned move lands when its warning runs out.
	for _, enemy in self.Enemies do
		local pending = enemy.Pending
		if enemy.Alive and pending then
			pending.Left -= dt
			if pending.Left <= 0 then
				enemy.Pending = nil
				self:EnemyStrike(enemy, pending.Move, pending.Target)
				if self.Over then
					return
				end
			end
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
	for _, enemy in self.Enemies do
		if enemy.Alive and enemy.Pending == nil then
			enemy.Gauge += self:Speed(enemy) * dt / (100 * B.TurnSeconds)
			if enemy.Gauge >= 1 then
				table.insert(ready, enemy)
			end
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
			if unit.Type == "Enemy" then
				self:EnemyAct(unit)
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
	local enemies = {}
	for _, enemy in self.Enemies do
		table.insert(enemies, {
			Id = enemy.Id,
			Leader = enemy.Leader,
			GuardId = if enemy.Leader then nil else enemy.Def.Id,
			Name = enemy.Name,
			Icon = if enemy.Leader then nil else enemy.Def.Icon,
			Role = if enemy.Leader then "Leader" else enemy.Def.Role,
			MaxHP = enemy.MaxHP,
			ATK = round(enemy.ATK),
			Taunt = enemy.Taunt or nil,
			Protect = if enemy.Protect > 0 then enemy.Protect else nil,
		})
	end
	local boss = self.Boss
	return {
		BossId = self.BossId,
		Difficulty = self.Difficulty,
		Boss = { MaxHP = boss.MaxHP, ATK = round(boss.ATK), DEF = boss.DEF, SPD = boss.SPD },
		Enemies = enemies,
		Allies = allies,
		TimeLimit = B.TimeLimit,
		UltimateCost = B.UltimateCost,
	}
end

local function gauge(value: number): number
	return math.floor(math.clamp(value, 0, 1) * 100) / 100
end

-- Live numbers for every unit. Card flags: B burning, Z frozen, T taunt, U buffed, S slowed,
-- G guarded, I invulnerable. Enemy flags: D DEF down, A ATK down, S slowed, V takes more damage,
-- B burning, E enraged, W winding up, R barrier up, X rallied (ATK up), P protected by a Warder.
-- Support cards send no HP. Fo is the player's focus target.
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
	for _, enemy in self.Enemies do
		local flags = ""
		for _, stat in { "DEF", "ATK", "SPD", "Vuln" } do
			for _, debuff in enemy.Debuffs do
				if debuff.Stat == stat and debuff.Left ~= math.huge then
					flags ..= if stat == "DEF" then "D" elseif stat == "ATK" then "A" elseif stat == "SPD" then "S" else "V"
					break
				end
			end
		end
		if #enemy.Burns > 0 then
			flags ..= "B"
		end
		if enemy.Enraged then
			flags ..= "E"
		end
		if enemy.Pending then
			flags ..= "W"
		end
		if enemy.Barrier > 0 then
			flags ..= "R"
		end
		if next(enemy.Buffs) ~= nil then
			flags ..= "X"
		end
		if enemy.Alive and self:Protection(enemy) > 0 then
			flags ..= "P"
		end
		units[enemy.Id] = {
			H = round(enemy.HP),
			G = if not enemy.Alive then 0 elseif enemy.Pending then 1 else gauge(enemy.Gauge),
			F = flags,
			Bar = if enemy.Barrier > 0 then enemy.Barrier else nil,
		}
	end
	return { T = math.floor(self.Time * 10) / 10, U = units, Fo = self.Focus }
end

-- End-of-fight numbers for the results screen.
function Engine:Summary()
	local dealt = {}
	for _, unit in self.Allies do
		dealt[unit.Id] = { Dealt = unit.Dealt, Healed = unit.Healed, Alive = unit.Alive }
	end
	local guardsDown = 0
	for _, enemy in self.Enemies do
		if not enemy.Leader and not enemy.Alive then
			guardsDown += 1
		end
	end
	return {
		Result = self.Result,
		Time = math.floor(self.Time * 10) / 10,
		BossHP = round(self.Boss.HP),
		BossMaxHP = self.Boss.MaxHP,
		GuardsDown = guardsDown,
		Guards = #self.Enemies - 1,
		Units = dealt,
	}
end

return Engine
