--!nonstrict
-- The battle engine: up to 8 cards against an enemy squad (the leader and its three guards) on
-- action timers. A pure simulation with no Roblox services: BattleService steps it in real time and
-- streams its events to the client, and tests/battle_test.luau runs whole fights headless.
--
-- Rules (design doc, "Battle system", made 4v4 on 2026-10-23, real-time archetypes 2026-10-30):
--   * Attack cards act in real time by archetype (Cards.Archetype: Fast / Balanced / Heavy from SPD): a
--     Basic every BasicInterval seconds, a Skill every SkillCooldown seconds, an Ultimate at UltimateCost
--     energy (charged at Config.Battle.EnergyPerSecond, plus a little from enemy hits). The four slots open
--     their first Basics on Config.Battle.SlotOffsets. SPD buffs / slows scale both timers.
--   * Enemies keep action bars that fill at their SPD (a SPD 100 bar once per Config.Battle.TurnSeconds);
--     at most one enemy acts per tick. Status durations count turns of TurnSeconds.
--   * Attack cards (front row) have HP and take every enemy hit. Support cards (back row) have no HP:
--     they can't be hit or KO'd and only modify their matching Attack slot.
--   * The enemy side is the leader ("Boss": a world boss, or a tower echo) and three guards (G1-G3,
--     Bosses.GuardTypes), each linked to the leader by its role: Warders taunt, cut the leader's damage taken
--     (Protect) and absorb part of the Shield bar's fill; Menders mend the leader every MendSeconds and
--     cleanse it; Strikers / Hexers stack Expose / Weaken (Hexers also Burn) on your highest-ATK card.
--   * Cards hit the player's focus target (SetFocus, tapped on screen) when it's alive, otherwise a
--     taunting guard, otherwise the enemy with the least HP left. Abilities with Target "Enemies" hit
--     every enemy, "RandomEnemy" picks again for each hit.
--   * Vanguard: Attack slot 1 draws Config.Battle.Vanguard of single-target enemy attacks (more as a Warder).
--   * Ultimates: UseUltimate (a tap on the card) or AutoUlt, which fires one ready Ultimate at a time. With
--     HoldForBreak, AutoUlt holds full Ultimates while the leader's Shield bar is past HoldAbove, then fires
--     them one after another once the Shield breaks.
--   * Boss Shield (the leader's Stagger bar): the leader takes ShieldTaken damage while it stands. Card hits
--     fill it (Basics chip, Skills chunk, Heavy Skills most), a guard KO adds GuardKOShield. Full = Shield
--     Break: StaggerSeconds stunned (its warned move cancelled) and BrokenTaken damage taken.
--   * Boss Clash: a leader's warned move opens a ClashWindow when its warning runs out. Clash() in time sends
--     the strongest card in (reflects ClashReflect x ATK, cuts the move's damage by ClashCut, fills the Shield
--     ClashShield); ignored, the move lands as normal.
--   * Threat: an enemy hit takes at least Config.Battle.MinHit of the target's max HP (before Guard); a
--     leader's warned move pierces SkillPierce of shields.
--   * At 50% HP the leader adds its phase-2 move; at 20% it enrages.
--   * Win when the leader falls. Lose when every Attack card is KO'd or the timer runs out.
--   * Damage = ATK x Skill% x (1 + sum of buffs) x Crit x (1 - target DEF) x (1 - Protect on the leader)
--     x the leader's Shield multiplier x (1 - Weaken stacks). Elements are themes only (no multiplier).
--   * Familiar bonds (ColumnBonds) fire one combo hit each, when the leader first drops to half HP or at
--     Elements.BondAt seconds.
--   * Supports: bounded passive effects (Cards.Support), no timers, damage, HP or active skills.
--   * Unit effects (traits, foils, mastery, tower mutators) arrive as UnitSpec.Trait: buffs for the
--     whole fight, StartEnergy, SkillDMG (Skill / Ultimate damage) and HPCost (HP lost per action).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)
local Elements = require(Shared.Elements)
local Awaken = require(Shared.Awaken)
local ColumnBonds = require(Shared.ColumnBonds)

local B = Config.Battle

local Engine = {}
Engine.__index = Engine

export type UnitSpec = {
	Id: string,
	CardId: string,
	Stars: number,
	Border: string?,
	Awaken: number?, -- Awakening node (Awaken.luau): stats, and the 400% bond at node 3
	Copies: number?, -- copies held at Border: the duplicate bonus (Cards.DupeBonus)
	Trait: { { Stat: string, Amount: number } }?, -- unit effects: traits, foil, Awakening, mutator
}
-- Stats (optional) replaces the difficulty's HP / ATK / WarnSeconds and adds to the leader's DEF / SPD:
-- the Infinite Tower (Tower.luau) fights a boss's moves at stats scaled to the floor. Difficulty still
-- picks which moves are in (MinDifficulty). Guards (optional) replaces the boss's own guard ids ({} = the
-- leader alone, as in a raid). TimeLimit (optional) replaces Config.Battle.TimeLimit. Stats.BarrierHP
-- (optional) sizes barriers off that HP instead of the leader's max (a raid Colossus's HP is a pool).
export type Stats = { HP: number, ATK: number, WarnSeconds: number, DEF: number?, SPD: number?, BarrierHP: number? }
export type Setup = {
	Units: { UnitSpec },
	BossId: string,
	Difficulty: string,
	Rng: Random?,
	Stats: Stats?,
	Guards: { string }?,
	TimeLimit: number?,
	WeatherId: string?,
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
		Element = card.Element,
		Awaken = spec.Awaken or 0,
		Border = spec.Border or "Normal",
		Stars = spec.Stars,
		SupportMods = {},
		EquipEffects = spec.Trait or {},
		Triggered = {},
		HealingLock = 0,
		HPCost = 0,
		Main = Cards.Stat(card, card.Main, spec.Stars, spec.Border, spec.Awaken, spec.Copies),
		MaxHP = if hasHP then Cards.Stat(card, card.HP or 0, spec.Stars, spec.Border, spec.Awaken, spec.Copies) else 0,
		SPD = card.SPD,
		Gauge = 0, -- Basic progress, 0-1 (a full bar is the next Basic)
		SkillGauge = 0, -- Skill cooldown progress, 0-1
		Interval = card.BasicInterval or B.TurnSeconds,
		Cooldown = card.SkillCooldown or 10,
		UltCost = card.UltimateCost or 100,
		Archetype = card.Archetype,
		Weaken = 0, -- Hexer stacks: -HexStack DMG dealt each
		Expose = 0, -- Striker stacks: +HexStack DMG taken each
		HexLeft = 0,
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
	unit.BaseMain=unit.Main
	unit.BaseMaxHP=unit.MaxHP
	-- The card's trait (Traits.luau): a head start on its Ultimate, or a buff that lasts the whole
	-- fight (Left = huge, so it never runs out and bosses can't steal it).
	for i, effect in (spec.Trait or {}) :: { { Amount: number, Stat: string } } do
		if effect.Stat == "StartEnergy" then
			if unit.Ultimate then
				unit.Energy = math.min(unit.UltCost, unit.Energy + effect.Amount * unit.UltCost)
			end
		elseif effect.Stat == "HPCost" then
			unit.HPCost += effect.Amount
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
		Element = props.Element,
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
		Stagger = 0, -- leader: the Shield bar's fill, 0-1
		Staggered = 0, -- leader: seconds of Shield Break left
		Staggers = 0,
		CounterStaggers = 0, -- legacy summary field (elements no longer counter)
		MendName = props.MendName,
		MendLeft = B.MendSeconds,
		Role = props.Role,
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
	self.WeatherId=setup.WeatherId or "clear"
	self.NextTeamUltimateAt=0
	self.Over = false
	self.Result = nil
	self.AutoUlt = false
	self.HoldForBreak = true -- AUTO ULT holds full Ultimates for a Shield Break (BattleInput HoldUlt)
	self.Holding = false
	self.Focus = nil -- the enemy id the player tapped
	self.Events = {}
	self.Opened = false
	self.Slot = nil -- the slot of the ability being cast (Basic | Skill | Ultimate | Opening)
	self.WarnSeconds = difficulty.WarnSeconds
	self.BossId = def.Id
	self.Difficulty = setup.Difficulty
	self.DifficultyIndex = Bosses.DifficultyIndex(setup.Difficulty)
	self.TimeLimit = setup.TimeLimit or B.TimeLimit
	self.Synergies = {} -- the deck's active synergies (Elements.ActiveSynergies)
	self.Bonds = {} -- { Bond, A, B (units) } for each bond in the deck
	self.BondsFired = false

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
		Element = def.Element,
		Moves = movesFor(def.Moves),
		HP = leaderHP,
		ATK = leaderATK,
		DEF = def.DEF + (setup.Stats and setup.Stats.DEF or 0),
		SPD = def.SPD + (setup.Stats and setup.Stats.SPD or 0),
	})
	self.Boss.BarrierHP = setup.Stats and setup.Stats.BarrierHP or self.Boss.MaxHP
	self.Enemies = { self.Boss }
	self.ById = { Boss = self.Boss }
	for i, guardId in setup.Guards or def.Guards or {} do
		local g = Bosses.GuardTypes[guardId]
		assert(g, `Unknown guard {guardId}`)
		local enemy = newEnemy(`G{i}`, 100 + i, {
			Def = g,
			Name = g.Name,
			Element = g.Element,
			Moves = movesFor(g.Moves),
			HP = leaderHP * g.HP,
			ATK = leaderATK * g.ATK,
			DEF = g.DEF,
			SPD = g.SPD,
			Taunt = g.Taunt,
			Protect = g.Protect,
			MendName = g.MendName,
			Role = g.Role,
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

	-- Supports are equipment for the matching attacker, never extra combatants.
	self.Links = {}
	self:SetWeather(self.WeatherId)
	for _, unit in self.Allies do
		local link = if unit.Card.Support then table.clone(unit.Card.Support) else nil
		local slot = string.match(unit.Id, "^S(%d+)$")
		local front = slot and self.ById[`A{slot}`]
		if link and front and front.HasHP then
			local bond=ColumnBonds.For(front.Card,unit.Card)
			unit.Bond=bond
			if bond then
				if bond.Stat=="Chance" then link.Chance=math.min(1,(link.Chance or 0)+bond.Amount)
				elseif bond.Stat=="Uses" then link.Uses=(link.Uses or 0)+bond.Amount
				elseif bond.Stat=="Guard" then front.Buffs[`Bond:{unit.Id}`]={Stat="Guard",Amount=bond.Amount,Left=math.huge} end
				table.insert(self.Bonds,{Bond={Name=bond.Name,Pct=3},A=front,B=unit})
			end
			-- A passive card never acts. Its traits, foil and mastery therefore belong to its paired attacker.
			for i, effect in unit.EquipEffects do
				if effect.Stat == "StartEnergy" then
					if front.Ultimate then front.Energy = math.min(front.UltCost, front.Energy + effect.Amount * front.UltCost) end
				elseif effect.Stat == "HPCost" then front.HPCost += effect.Amount
				else front.Buffs[`SupportTrait:{unit.Id}:{i}`] = { Stat=effect.Stat, Amount=effect.Amount, Left=math.huge } end
			end
			local amount = Cards.SupportValue(unit.Card, unit.Stars, unit.Border, unit.Awaken)
			if bond and bond.Stat=="Amount" then amount=math.min(.5,amount+bond.Amount) end
			local mod = { Source = unit, Def = link, Amount = amount, BaseAmount=amount, Used = 0, Healed = 0 }
			unit.Modifier = mod
			unit.Paired = front
			if unit.Card.Weather then
				local bonus=(if unit.Card.Weather==self.WeatherId then .2 else 0)+(if bond and bond.Stat=="Celestial" then .2 else 0)
				mod.Amount=math.min(.5,math.floor(amount*(1+bonus)*20+.5)/20)
				amount=mod.Amount
			end
			table.insert(front.SupportMods, mod)
			if link.Kind == "StartEnergy" then
				if front.Ultimate then
					front.Energy = math.min(front.UltCost, front.Energy + amount * front.UltCost)
					mod.Used = 1
				end
			elseif link.Kind == "Haste" then
				front.Buffs[`Link:{unit.Id}`] = { Stat = "SPD", Amount = amount, Left = turns(link.Turns) }
				mod.Used = 1
			elseif link.Kind == "OpeningShield" then
				front.Shield = round(front.MaxHP * amount)
				front.ShieldLeft = math.huge
				unit.Healed = front.Shield
				mod.Used = 1
			end
			table.insert(self.Links, { From = unit.Id, To = front.Id, Name = link.Name })
		end
	end

	-- Passives, auras and signatures that are on from the start.
	for _, unit in self.Allies do
		for _, ability in unit.Card.Abilities do
			if ability.Trigger then
				table.insert(unit.Triggered, { Ability = ability, Used = 0 })
				continue
			end
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
	for _, unit in self.Allies do self:Trigger(unit, "OnEntry") end
	-- Synergies: the deck's element counts switch on whole-deck bonuses for the fight.
	local elements, cardIds = {}, {}
	for _, unit in self.Allies do
		table.insert(elements, unit.Element)
		table.insert(cardIds, unit.Card.Id)
	end
	if #self.Allies > 0 then
		for _, active in Elements.ActiveSynergies(elements) do
			table.insert(self.Synergies, active)
			for _, effect in active.Tier.Effects do
				self:RunEffect(self.Allies[1], effect, true, `Synergy:{active.Synergy.Element}`)
			end
		end
	end
	self.Events = {} -- start-of-battle effects are part of the initial state, not news
	-- The squad opens in a ripple: slot N's first Basic lands SlotOffsets[N] seconds in. Enemy bars begin
	-- part-filled (by SPD and order, the same every fight) so they act in turn.
	for _, unit in self.Allies do
		if unit.HasHP then
			local slot = tonumber(string.match(unit.Id, "^A(%d+)$")) or 1
			unit.Gauge = 1 - (B.SlotOffsets[slot] or 0) / unit.Interval
		end
	end
	local g = B.StartGauge
	for i, enemy in self.Enemies do
		local spread = ((i + #self.Allies) * 0.37 + (enemy.SPD or 100) / 100) % 1
		enemy.Gauge = g.Min + (g.Max - g.Min) * spread
	end
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
				total += Cards.EffectAmount(unit.Card, effect, unit.Border)
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
	if unit.Type == "Support" then return 0 end
	if unit.Type == "Enemy" then
		return unit.SPD * math.max(0.2, 1 - self:EnemyDebuff(unit, "SPD"))
	end
	return unit.SPD * self:Haste(unit)
end

-- An Attack card's timer speed: 1 normally, more with SPD buffs, less when slowed (never under 0.2).
function Engine:Haste(unit): number
	return math.max(0.2, 1 + self:Buff(unit, "SPD"))
end

-- The leader's Shield multiplier on damage taken: ShieldTaken while it stands, BrokenTaken when broken.
function Engine:ShieldFactor(enemy): number
	if not enemy.Leader then
		return 1
	end
	return if enemy.Staggered > 0 then B.BrokenTaken else B.ShieldTaken
end

-- Is a Warder standing beside the leader (it absorbs part of the Shield bar's fill)?
function Engine:WarderUp(): boolean
	for _, enemy in self.Enemies do
		if enemy.Alive and enemy.Role == "Warder" then
			return true
		end
	end
	return false
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
		unit.Energy = math.min(unit.UltCost or 100, unit.Energy + amount)
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
	local enemy = self.EffectTarget or self:CardTarget()
	return if enemy and enemy.Alive then { enemy } else {}
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

-- shield: the leader's Shield state the hit met (ShieldFactor): "Up" (muted number) or "Broken" (big gold).
function Engine:DamageEnemy(enemy, source, amount: number, crit: boolean, kind: string, el: number?, shield: string?)
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
		El = el, -- legacy: elements are neutral, always nil
		Sd = if shield == "Up" then true else nil,
		Bk = if shield == "Broken" then true else nil,
	})

	if enemy.HP <= 0 then
		if source then self:OpponentDefeated(source) end
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
		-- A fallen guard's link snaps: a chunk of the leader's Shield shatters with it.
		self:FillStagger(self.Boss, B.GuardKOShield)
		return
	end
	if not enemy.Leader then
		return
	end
	if enemy.Phase == 1 and enemy.HP <= enemy.MaxHP * B.PhaseAt then
		enemy.Phase = 2
		enemy.PhaseActions = 0
		enemy.SkipPhaseMove = enemy.Staggered > 0 -- staggered at half HP: its first phase-2 move is lost
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

local function elementFlag(mult: number): number?
	return if mult > 1 then 1 elseif mult < 1 then -1 else nil
end

function Engine:HitEnemy(unit, enemy, pct: number, ignoreDef: boolean?, kind: string?)
	if not unit.HasHP then return end
	local buffs = self:Buff(unit, "ATK") + self:EnemyDebuff(enemy, "Vuln")
	local crit = self.Rng:NextNumber() < B.CritChance + self:Buff(unit, "Crit")
	local critMult = if crit then B.CritDamage + self:Buff(unit, "CritDamage") else 1
	local def = if ignoreDef then 0 else self:EnemyDEF(enemy)
	local protect = if ignoreDef then 0 else self:Protection(enemy)
	local element = Elements.Multiplier(unit.Element, enemy.Element)
	local burst = self.Slot == "Skill" or self.Slot == "Ultimate"
	local skill = if burst then 1 + self:Buff(unit, "SkillDMG") else 1
	local shield = self:ShieldFactor(enemy)
	local weaken = 1 - math.min(0.8, unit.Weaken * B.HexStack)
	local amount = math.max(1, round(unit.Main * pct * (1 + buffs) * critMult * (1 - def) * (1 - protect) * element * skill * shield * weaken))
	amount = if ignoreDef then amount else self:ThroughBarrier(enemy, amount, burst)
	local dealt = math.max(0, math.min(enemy.HP, amount))
	local state = if enemy.Leader then (if enemy.Staggered > 0 then "Broken" else "Up") else nil
	self:DamageEnemy(enemy, unit, amount, crit, kind or "Hit", elementFlag(element), state)
	-- Basics chip the Shield, Skills chunk it (a Heavy card's twice as hard), Ultimates crack it a little;
	-- a Warder standing absorbs part of every hit's fill.
	if enemy.Leader and enemy.Alive and enemy.Staggered <= 0 and not self.Over then
		local rate = B.ShieldFill[self.Slot or ""] or 0
		if self.Slot == "Skill" then
			rate *= (B.Archetypes[unit.Archetype or ""] or {}).SkillShield or 1
		end
		if rate > 0 then
			self:FillStagger(enemy, pct * rate * (if self:WarderUp() then 1 - B.WarderAbsorb else 1))
		end
	end
	if crit and enemy.Alive then self:Trigger(unit, "OnCrit", enemy) end
	if enemy.Alive then self:Trigger(unit, "OnHit", enemy) end
	for _, mod in unit.SupportMods do
		if mod.Def.Kind == "Lifesteal" and unit.Alive and dealt > 0 and unit.HealingLock <= 0 and self.Rng:NextNumber() < (mod.Def.Chance or 1) then
			local cap = round(unit.MaxHP * (mod.Def.Threshold or 0.25))
			local healed = math.min(round(dealt * mod.Amount), cap - mod.Healed, unit.MaxHP - unit.HP)
			if healed > 0 then
				mod.Healed += self:SupportHeal(mod, unit, healed)
			end
		elseif mod.Def.Kind == "Weaken" and burst and enemy.Alive and mod.Used < (mod.Def.Uses or 0) and mod.LastAction ~= self.ActionToken then
			mod.LastAction = self.ActionToken
			if self.Rng:NextNumber() < (mod.Def.Chance or 1) then
				mod.Used += 1
				enemy.Debuffs[`Support:{mod.Source.Id}`] = { Stat = "ATK", Amount = mod.Amount, Left = turns(mod.Def.Turns) }
				self:Emit({ K = "Debuff", U = unit.Id, T = enemy.Id, Stat = "ATK", A = mod.Amount })
				if mod.Def.Burn then
					table.insert(enemy.Burns, { Damage = round(unit.Main * mod.Def.Burn), Ticks = 3, Timer = B.TurnSeconds, Source = unit, Kind = "Burn" })
					self:Emit({ K = "Burned", U = unit.Id, T = enemy.Id })
				end
			end
		end
	end
end

function Engine:SupportHeal(mod, target, amount: number): number
	if not target.Alive or target.HealingLock > 0 then return 0 end
	amount = math.max(0, math.min(amount, target.MaxHP - target.HP))
	target.HP += amount
	mod.Source.Healed += amount
	self:Emit({ K = "Heal", U = mod.Source.Id, T = target.Id, A = amount })
	return amount
end

-- A reactive ability rolls once for the whole bundle and shares its limit across every effect.
function Engine:Trigger(unit, trigger: string, enemy)
	if self.Over or not unit.Alive or not unit.HasHP then return end
	for _, entry in unit.Triggered do
		local ability = entry.Ability
		if entry.Running or ability.Trigger ~= trigger or (ability.Limit and entry.Used >= ability.Limit) then continue end
		if trigger == "BelowHalf" and (unit.HP <= 0 or unit.HP > unit.MaxHP * 0.5) then continue end
		if trigger == "OnAct" and ability.Every and unit.Actions % ability.Every ~= 0 then continue end
		if ability.Chance and self.Rng:NextNumber() >= ability.Chance then continue end
		entry.Running = true
		entry.Used += 1
		local previous = self.EffectTarget
		self.EffectTarget = enemy
		for _, effect in ability.Effects do self:RunEffect(unit, effect, false, ability.Name) end
		self.EffectTarget = previous
		entry.Running = false
	end
end

function Engine:OpponentDefeated(unit)
	if not unit.Alive or not unit.HasHP then return end
	self:Trigger(unit, "OnKill")
	for _, mod in unit.SupportMods do
		if mod.Def.Kind == "KillMend" and mod.Used < (mod.Def.Uses or 0) then
			mod.Used += 1
			self:SupportHeal(mod, unit, round(unit.MaxHP * mod.Amount))
		end
	end
end

-- Fills the leader's Shield bar by `amount` (a share of the bar); a full bar is a Shield Break: the leader
-- is stunned for StaggerSeconds, its warned move (or Clash window) is cancelled, and held Ultimates may go.
function Engine:FillStagger(enemy, amount: number)
	if not enemy.Leader or not enemy.Alive or enemy.Staggered > 0 or self.Over or amount <= 0 then
		return
	end
	enemy.Stagger += amount
	if enemy.Stagger < 1 then
		return
	end
	enemy.Stagger = 0
	enemy.Staggered = B.StaggerSeconds
	enemy.Staggers += 1
	local cancelled = enemy.Pending and enemy.Pending.Move.Name
	enemy.Pending = nil
	enemy.Gauge = 0
	self.NextTeamUltimateAt = self.Time -- held Ultimates fire straight into the break
	self:Emit({ K = "Stagger", T = enemy.Id, S = B.StaggerSeconds, N = cancelled })
end

function Engine:DamageAlly(target, amount: number, kind: string, sourceId: string?, el: number?, pierce: number?)
	if not target.Alive or not target.HasHP or self.Over then
		return
	end
	if target.Invuln > 0 then
		self:Emit({ K = kind, U = sourceId, T = target.Id, A = 0 })
		return
	end
	local previousHP = target.HP
	local absorbed = math.min(target.Shield, round(amount * (1 - (pierce or 0)))) -- a pierce goes past shields
	target.Shield -= absorbed
	target.HP -= amount - absorbed
	self:Emit({ K = kind, U = sourceId, T = target.Id, A = amount, Sh = if absorbed > 0 then absorbed else nil, El = el })

	if target.HP > 0 then
		self:Trigger(target, "BelowHalf")
		for _, mod in target.SupportMods do
			local source = sourceId and self.ById[sourceId]
			if mod.Def.Kind == "Counter" and kind == "Hit" and source and source.Type == "Enemy" and source.Alive and mod.Used < (mod.Def.Uses or 0) and self.Rng:NextNumber() < (mod.Def.Chance or 1) then
				mod.Used += 1
				local reflected = round(math.min(previousHP, amount - absorbed) * mod.Amount)
				if reflected > 0 then self:DamageEnemy(source, target, reflected, false, "Hit") end
			end
			if mod.Def.Kind == "LowHeal" and mod.Used < (mod.Def.Uses or 0) and target.HealingLock <= 0 and target.HP <= target.MaxHP * (mod.Def.Threshold or 0.5) then
				mod.Used += 1
				self:SupportHeal(mod, target, math.min(round(target.MaxHP * mod.Amount), target.MaxHP - target.HP))
				table.clear(target.Burns)
				target.Frozen = false
			end
		end
		return
	end
	for _, mod in target.SupportMods do
		if mod.Def.Kind == "LastStand" and mod.Used < (mod.Def.Uses or 0) then
			mod.Used += 1
			target.HP = math.max(1, round(target.MaxHP * mod.Amount))
			self:Emit({ K = "SupportProc", U = mod.Source.Id, T = target.Id, N = mod.Def.Name })
			return
		end
	end
	local oath = self.DawnOath
	if oath and not oath.Used then
		oath.Used = true
		target.HP = 1
		target.Invuln = oath.Seconds
		self:Emit({ K = "Signature", U = oath.Owner.Id, T = target.Id, N = "Seal's Last Gate" })
		return
	end
	target.HP = 0
	target.Alive = false
	target.Shield = 0
	table.clear(target.Burns)
	target.Frozen = false
	target.Taunt = 0
	target.Gauge = 0
	target.Energy = 0
	self:Emit({ K = "KO", T = target.Id })
	if not self:AttackAlive() then
		self:Finish("Lose")
	end
end

-- cut: share of the move's damage a successful Clash takes off (0 / nil = none).
function Engine:HitAlly(enemy, target, move, cut: number?)
	if not target.Alive then
		return
	end
	for _, mod in target.SupportMods do
		if mod.Def.Kind == "Dodge" and mod.Used < (mod.Def.Uses or math.huge) and self.Rng:NextNumber() < mod.Amount then
			mod.Used += 1
			enemy.Debuffs[`Feint:{mod.Source.Id}`] = { Stat = "ATK", Amount = mod.Def.Penalty or 0, Left = turns(mod.Def.Turns) }
			self:Emit({ K = "Miss", U = enemy.Id, T = target.Id })
			return
		end
	end
	if target.Evades > 0 then
		target.Evades -= 1
		self:Emit({ K = "Miss", U = enemy.Id, T = target.Id })
		return
	end
	local element = Elements.Multiplier(enemy.Element, target.Element)
	local atk = self:EnemyATK(enemy) * element
	-- Threat floor: every hit takes at least a share of the card's max HP (B.MinHit), before Guard.
	local floorShare = if enemy.Leader then (if move.Warn then B.MinHit.LeaderSkill else B.MinHit.Leader) else B.MinHit.Guard
	local raw = math.max(atk * move.Pct, (target.MaxHP or 0) * floorShare)
	local guard = 1 - math.min(0.8, math.max(0, self:Buff(target, "Guard")))
	local exposed = 1 + (target.Expose or 0) * B.HexStack
	local amount = math.max(1, round(raw * guard * exposed * (1 - (cut or 0))))
	self:DamageAlly(target, amount, "Hit", enemy.Id, elementFlag(element), if enemy.Leader and move.Warn then B.SkillPierce else nil)
	if not target.Alive then
		return
	end
	if self.Time >= (target.NextHitEnergyAt or 0) then
		self:GainEnergy(target, B.EnergyPerHit)
		target.NextHitEnergyAt=self.Time+B.HitEnergyInterval
	end
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
	self:SupportCleanse(target, enemy)
end

function Engine:SupportCleanse(target, enemy)
	for _, mod in target.SupportMods do
		if mod.Def.Kind == "Cleanse" and mod.Used < (mod.Def.Uses or 0) and (target.Frozen or #target.Burns > 0) then
			mod.Used += 1
			if enemy and enemy.Alive then
				if target.Frozen then enemy.Frozen = true end
				if #target.Burns > 0 then
					table.insert(enemy.Burns, { Damage = round(target.Main * mod.Amount), Ticks = 3, Timer = B.TurnSeconds, Source = target, Kind = "Burn" })
				end
			end
			target.Frozen = false
			table.clear(target.Burns)
			self:Emit({ K = "Cleanse", U = mod.Source.Id, T = target.Id })
		end
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
	elseif kind == "Burn" or kind == "Bleed" then
		if effect.Chance == nil or rng:NextNumber() < effect.Chance then
			for _, enemy in self:EnemyTargets(effect.Target) do
				table.insert(enemy.Burns, {
					Damage = math.max(1, round(unit.Main * effect.Pct * Elements.Multiplier(unit.Element, enemy.Element))),
					Ticks = effect.Turns or 3,
					Timer = B.TurnSeconds,
					Source = unit,
					Kind = kind,
				})
				self:Emit({ K = "Burned", U = unit.Id, T = enemy.Id, Status = kind })
			end
		end
	elseif kind == "Heal" then
		for _, target in self:Targets(unit, effect.Target or "Lowest", kind) do
			if target.HealingLock > 0 then continue end
			local healed = math.min(round((if effect.MaxHP then target.MaxHP else unit.Main) * effect.Pct), target.MaxHP - target.HP)
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
		local amount = Cards.EffectAmount(unit.Card, effect, unit.Border)
		local targets = self:Targets(unit, effect.Target or "Self", kind)
		local key = `{unit.Id}:{abilityName or "Passive"}:{effect.Stat}`
		for _, target in targets do
			target.Buffs[key] = { Stat = effect.Stat, Amount = amount, Left = turns(effect.Turns) }
		end
		if not quiet then
			self:Emit({ K = "Buff", U = unit.Id, T = ids(targets), Stat = effect.Stat, A = amount })
		end
	elseif kind == "Debuff" then
		local amount = Cards.EffectAmount(unit.Card, effect, unit.Border)
		local key = `{unit.Id}:{abilityName or "Passive"}:{effect.Stat}`
		for _, enemy in self:EnemyTargets(effect.Target) do
			enemy.Debuffs[key] = { Stat = effect.Stat, Amount = amount, Left = turns(effect.Turns) }
			if not quiet then
				self:Emit({ K = "Debuff", U = unit.Id, T = enemy.Id, Stat = effect.Stat, A = amount })
			end
		end
	elseif kind == "Energy" then
		local targets = self:Targets(unit, effect.Target or "All", kind)
		for _, target in targets do
			-- Amount is a share (in %) of each target's own Ultimate cost, so "25% charge" holds for every archetype.
			self:GainEnergy(target, effect.Amount / 100 * (target.UltCost or 100))
			if effect.ResetSkill and target.Skill then
				target.SkillGauge = 1
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
	elseif kind == "HealingLock" then
		unit.HealingLock = math.huge
	elseif kind == "Evade" then
		for _, target in self:Targets(unit, effect.Target or "Self", kind) do
			target.Evades += effect.Hits or 1
		end
	end
end

function Engine:RunAbility(unit, ability, slot: string)
	self.ActionToken = (self.ActionToken or 0) + 1
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

-- Supports were already attached in Engine.new; opening never casts extra moves.
function Engine:Opening()
	self.Opened = true
end

function Engine:SetWeather(id: string)
	self.WeatherId=id
	for _,unit in self.Allies do
		if unit.HasHP then
			local bonus=if unit.Card.Weather==id then .2 else 0
			local ratio=unit.HP/math.max(1,unit.MaxHP)
			local newHP=round(unit.BaseMaxHP*(1+bonus))
			unit.Shield=round(unit.Shield*newHP/math.max(1,unit.MaxHP))
			unit.Main=round(unit.BaseMain*(1+bonus));unit.MaxHP=newHP;unit.HP=round(newHP*ratio)

		end
	end
end

-- One card action: its Basic, or its Skill when the Skill timer is full (Step decides).
function Engine:CardAct(unit, slot: string?)
	if not unit.HasHP then return end
	unit.Actions += 1
	slot = slot or "Basic"
	local ability = if slot == "Skill" then unit.Skill else unit.Basic
	if ability then
		local target = self:CardTarget()
		self:Emit({ K = "Act", U = unit.Id, Ab = slot, N = ability.Name, T = if target then target.Id else nil })
		self:RunAbility(unit, ability, slot)
	end
	if self.Over then
		return
	end
	-- A Demon Seal pays for its ATK in HP (never below 1).
	if unit.HPCost > 0 and unit.HasHP and unit.Alive and unit.HP > 1 then
		local cost = math.min(unit.HP - 1, round(unit.MaxHP * unit.HPCost))
		unit.HP -= cost
		self:Emit({ K = "HPCost", T = unit.Id, A = cost })
	end
	self:Trigger(unit, "OnAct")
	for _, passive in unit.Passives do
		if passive.When == "OnAct" then
			self:RunEffect(unit, passive, true)
		end
	end
	if unit.EclipseEvery and unit.Actions % unit.EclipseEvery == 0 and unit.Alive then
		self:Emit({ K = "Signature", U = unit.Id, N = "Moving Without Thought" })
		self:CardAct(unit, "Basic")
	end
end

-- The leader's next warned (big) move and how many of its actions until it: { N, In } (In 1 = its next).
function Engine:NextBigMove(enemy)
	if enemy.Pending then
		return { N = enemy.Pending.Move.Name, In = 0 }
	end
	local best = nil
	for _, move in enemy.Moves do
		local phase = move.Phase or 1
		if move.Warn and move.Every and phase <= enemy.Phase then
			local count = if phase >= 2 then enemy.PhaseActions else enemy.Actions
			local left = move.Every - (count % move.Every)
			if best == nil or left < best.In then
				best = { N = move.Name, In = left }
			end
		end
	end
	return best
end

function Engine:ChooseMove(enemy)
	local moves = enemy.Moves
	for _, move in moves do
		local phase = move.Phase or 1
		if phase == 2 and enemy.SkipPhaseMove then
			-- passed over once (see Stagger)
		elseif phase <= enemy.Phase then
			if move.Every == nil then
				return move
			end
			local count = if phase >= 2 then enemy.PhaseActions else enemy.Actions
			if count % move.Every == 0 then
				return move
			end
		end
		if phase == 2 and enemy.SkipPhaseMove and move.Every and enemy.PhaseActions % move.Every == 0 then
			enemy.SkipPhaseMove = false
			self:Emit({ K = "PhaseCancel", U = enemy.Id, N = move.Name })
		end
	end
	return moves[#moves]
end

-- A pick on the player's side: the taunting card, else (single-target moves) the Vanguard in Attack slot 1
-- for its share of attacks, else a random Attack card.
function Engine:PickTarget(single: boolean?)
	local front = self:Alive("Attack")
	for _, unit in front do
		if unit.Taunt > 0 then
			return unit
		end
	end
	if #front == 0 then
		return nil
	end
	local vanguard = self.ById.A1
	if single and vanguard and vanguard.Alive and vanguard.HasHP and #front > 1 then
		local share = if vanguard.Card.Role == "Warder" then B.WarderVanguard else B.Vanguard
		if self.Rng:NextNumber() < share then
			return vanguard
		end
		local others = {}
		for _, unit in front do
			if unit ~= vanguard then
				table.insert(others, unit)
			end
		end
		return others[self.Rng:NextInteger(1, #others)]
	end
	return front[self.Rng:NextInteger(1, #front)]
end

-- The card Strikers and Hexers single out: the highest ATK still standing.
function Engine:Strongest()
	local best = nil
	for _, unit in self:Alive("Attack") do
		if best == nil or unit.Main > best.Main then
			best = unit
		end
	end
	return best
end

function Engine:EnemyAct(enemy)
	enemy.Actions += 1
	if enemy.Phase >= 2 then
		enemy.PhaseActions += 1
	end
	local move = self:ChooseMove(enemy)
	local target = if move.Target == "Single" then self:PickTarget(true) else nil
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

function Engine:EnemyStrike(enemy, move, target, cut: number?)
	if not enemy.Alive then
		return
	end
	self:Emit({ K = "Act", U = enemy.Id, Ab = if move.Warn then "Skill" else "Basic", N = move.Name })

	if move.Target == "Self" then
		if move.Barrier then
			enemy.Barrier = round((enemy.BarrierHP or enemy.MaxHP) * move.Barrier)
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
			local unit = self:PickTarget(false)
			if unit then
				table.insert(hitList, unit)
			end
		end
	else
		-- A taunt raised during the warning still pulls the hit; a KO'd target is replaced.
		local pick = self:PickTarget(true)
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
		self:HitAlly(enemy, unit, move, cut)
	end
	if not self.Over and (enemy.Role == "Striker" or enemy.Role == "Hexer") then
		self:Hex(enemy)
	end

	if move.Slow and not self.Over then
		for _, unit in self:Alive() do
			unit.Buffs["Boss:Slow"] = { Stat = "SPD", Amount = -move.Slow.Amount, Left = turns(move.Slow.Turns) }
		end
		self:Emit({ K = "Slow", U = enemy.Id, A = move.Slow.Amount })
	end
end

-- A Striker stacks Expose (more DMG taken), a Hexer stacks Weaken (less DMG dealt) and Burns, on the
-- squad's highest-ATK card; every new stack refreshes the stack timer.
function Engine:Hex(enemy)
	local target = self:Strongest()
	if target == nil then
		return
	end
	local stat = if enemy.Role == "Striker" then "Expose" else "Weaken"
	target[stat] = math.min(B.HexStacks, (target[stat] or 0) + 1)
	target.HexLeft = B.HexSeconds
	if stat == "Weaken" then
		table.insert(target.Burns, {
			Damage = math.max(1, round(self:EnemyATK(enemy) * 0.25)),
			Ticks = 2,
			Timer = B.TurnSeconds,
			Source = enemy.Id,
		})
	end
	self:Emit({ K = "Hex", U = enemy.Id, T = target.Id, Stat = stat, A = target[stat] })
end

-- Boss Clash ------------------------------------------------------------------------------

-- Can this warned move be Clashed? A leader's move that hits the squad.
local function clashable(enemy, move): boolean
	return enemy.Leader and move.Warn == true and move.Target ~= "Self" and move.Target ~= "Ally" and (move.Pct or 0) > 0
end

-- The player's Clash (tap / Space): only inside an open window. The strongest card dashes in: it reflects
-- ClashReflect x its ATK into the leader, the Shield bar fills ClashShield, and the move lands for
-- ClashCut less (if the Shield broke, it doesn't land at all).
function Engine:Clash(): (boolean, string?)
	local boss = self.Boss
	local pending = boss.Pending
	if self.Over or not boss.Alive or pending == nil or (pending.Window or 0) <= 0 then
		return false, "NoClash"
	end
	local card = nil
	for _, unit in self:Alive("Attack") do
		if not unit.Frozen and (card == nil or unit.Main > card.Main) then
			card = unit
		end
	end
	card = card or self:Strongest()
	if card == nil then
		return false, "NoClash"
	end
	pending.Window = 0
	self:Emit({ K = "Clash", U = card.Id, T = boss.Id, N = pending.Move.Name })
	local previous = self.Slot
	self.Slot = "Clash"
	self:HitEnemy(card, boss, B.ClashReflect, false, "Hit")
	self.Slot = previous
	if self.Over then
		return true, nil
	end
	self:FillStagger(boss, B.ClashShield)
	if boss.Pending == pending then
		boss.Pending = nil
		self:EnemyStrike(boss, pending.Move, pending.Target, B.ClashCut)
	end
	return true, nil
end

-- Ultimates -------------------------------------------------------------------------------

function Engine:CanUltimate(unit): boolean
	return unit ~= nil
		and unit.Type ~= "Enemy"
		and unit.Alive
		and unit.Ultimate ~= nil
		and unit.Energy >= (unit.UltCost or 100)
		and not self.Over
end

function Engine:UseUltimate(id: string): (boolean, string?)
	local unit = self.ById[id]
	if not self:CanUltimate(unit) then
		return false, "NotReady"
	end
	unit.Energy = 0
	self.NextTeamUltimateAt = self.Time + (if self.Boss.Staggered > 0 then B.BreakChainGap else B.TeamUltimateGap)
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
			if burns[i] ~= burn then continue end -- a reactive cleanse may have removed this tick
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
			unit.HealingLock = math.max(0, unit.HealingLock - dt)
			if unit.HexLeft > 0 then
				unit.HexLeft -= dt
				if unit.HexLeft <= 0 then
					unit.Weaken, unit.Expose = 0, 0
				end
			end
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
			if enemy.Staggered > 0 then
				enemy.Staggered = math.max(0, enemy.Staggered - dt)
				if enemy.Staggered <= 0 then
					self:Emit({ K = "Recover", T = enemy.Id })
				end
			end
			tickTimers(enemy.Debuffs, dt)
			tickTimers(enemy.Buffs, dt)
			tickBurns(enemy.Burns, dt, function(burn)
				local amount = round(burn.Damage * (1 - self:Protection(enemy)) * self:ShieldFactor(enemy))
				self:DamageEnemy(enemy, burn.Source, self:ThroughBarrier(enemy, amount, false), false, burn.Kind or "Burn")
			end)
		end
	end
	if self.Over then
		return
	end

	-- Menders mend the leader on a timer and wipe its debuffs and burns.
	local boss = self.Boss
	for _, enemy in self.Enemies do
		if enemy.Alive and enemy.MendName and boss.Alive then
			enemy.MendLeft -= dt
			if enemy.MendLeft <= 0 then
				enemy.MendLeft += B.MendSeconds
				local healed = math.min(round(boss.MaxHP * B.MendHeal), boss.MaxHP - boss.HP)
				boss.HP += healed
				local cleansed = #boss.Burns
				for key in boss.Debuffs do
					cleansed += 1
					boss.Debuffs[key] = nil
				end
				table.clear(boss.Burns)
				self:Emit({ K = "EnemyHeal", U = enemy.Id, T = boss.Id, A = healed, N = enemy.MendName, C = if cleansed > 0 then cleansed else nil })
			end
		end
	end

	-- A warned move lands when its warning runs out; a leader's opens a Clash window first.
	for _, enemy in self.Enemies do
		local pending = enemy.Pending
		if enemy.Alive and pending then
			if pending.Window then
				pending.Window -= dt
			else
				pending.Left -= dt
				if pending.Left <= 0 and clashable(enemy, pending.Move) then
					pending.Window = B.ClashWindow
					self:Emit({ K = "ClashOpen", U = enemy.Id, N = pending.Move.Name, S = B.ClashWindow })
				end
			end
			if pending.Left <= 0 and (pending.Window or 0) <= 0 then
				enemy.Pending = nil
				self:EnemyStrike(enemy, pending.Move, pending.Target)
				if self.Over then
					return
				end
			end
		end
	end

	-- Attack cards: real-time timers. A Skill whose cooldown is full goes first; else a due Basic. A frozen
	-- card loses its next Basic thawing out (its Skill waits).
	for _, unit in self.Allies do
		if self.Over then
			return
		end
		if unit.Alive and unit.HasHP then
			local haste = self:Haste(unit)
			if unit.Ultimate then
				self:GainEnergy(unit, B.EnergyPerSecond * dt)
			end
			if unit.Skill then
				unit.SkillGauge = math.min(1, unit.SkillGauge + dt * haste / unit.Cooldown)
			end
			unit.Gauge = math.min(2, unit.Gauge + dt * haste / unit.Interval)
			if unit.Frozen then
				if unit.Gauge >= 1 then
					unit.Gauge -= 1
					unit.Frozen = false
					self:Emit({ K = "Thaw", U = unit.Id })
				end
			elseif unit.Skill and unit.SkillGauge >= 1 then
				unit.SkillGauge = 0
				unit.Gauge = math.min(unit.Gauge, 1)
				unit.ActedAt = self.Time
				self:CardAct(unit, "Skill")
			elseif unit.Gauge >= 1 then
				unit.Gauge -= 1
				unit.ActedAt = self.Time
				self:CardAct(unit, "Basic")
			end
		end
	end

	-- Enemy action bars: fill, then the fullest acts (one per tick; ties to the left).
	local ready = {}
	for _, enemy in self.Enemies do
		if enemy.Alive and enemy.Pending == nil and enemy.Staggered <= 0 then
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
	local acted = 0
	for _, unit in ready do
		if self.Over then
			return
		end
		if B.OneActionPerTick and acted >= 1 then
			break -- the rest keep a full bar and go next tick, in turn
		end
		if unit.Alive and unit.Gauge >= 1 then
			acted += 1
			unit.Gauge -= 1
			if unit.Frozen then
				unit.Frozen = false
				self:Emit({ K = "Thaw", U = unit.Id })
			else
				self:EnemyAct(unit)
			end
		end
	end

	-- AUTO ULT: one ready Ultimate at a time. HOLD ULT FOR BREAK keeps them while the Shield is nearly
	-- full, then chains them (BreakChainGap apart) once it breaks.
	self.Holding = self.AutoUlt and self.HoldForBreak and boss.Alive and boss.Staggered <= 0 and boss.Stagger >= B.HoldAbove
	if self.AutoUlt and not self.Holding and not self.Over and self.Time >= self.NextTeamUltimateAt then
		for _, unit in self.Allies do
			if unit.ActedAt ~= self.Time and self:CanUltimate(unit) then
				self:UseUltimate(unit.Id)
				break -- one auto Ultimate per tick
			end
		end
	end

	if not self.Over and not self.BondsFired and (self.Boss.Phase >= 2 or self.Time >= Elements.BondAt) then
		self:FireBonds()
	end

	if not self.Over and self.Time >= self.TimeLimit then
		self:Finish("Timeout")
	end
end

-- Dual Ultimates: every bond in the deck whose two cards still stand hits the leader once.
function Engine:FireBonds()
	self.BondsFired = true
	for _, entry in self.Bonds do
		if self.Over then
			return
		end
		local a, b = entry.A, entry.B
		if a.Alive and b.Alive then
			self:Emit({ K = "Bond", N = entry.Bond.Name, U = { a.Id, b.Id } })
			local previous = self.Slot
			self.Slot = "Ultimate" -- breaks barriers like an Ultimate
			local pct = if a.Awaken >= 3 or b.Awaken >= 3 then Awaken.BondPct else entry.Bond.Pct
			self:HitEnemy(a, self.Boss, pct * (a.Main + b.Main) / a.Main, false)
			self.Slot = previous
		end
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
			Element = unit.Element,
			MaxHP = if unit.HasHP then unit.MaxHP else nil,
			Main = if unit.HasHP then unit.Main else nil,
			Bond = unit.Bond,
			Ultimate = if unit.Ultimate then unit.Ultimate.Name else nil,
			Skill = if unit.Skill then unit.Skill.Name else nil, -- its countdown rides in the snapshot (K, seconds)
			Archetype = unit.Archetype,
			Interval = if unit.HasHP then unit.Interval else nil,
			Cooldown = if unit.HasHP and unit.Skill then unit.Cooldown else nil,
			UltCost = if unit.Ultimate then unit.UltCost else nil,
		})
	end
	local enemies = {}
	for _, enemy in self.Enemies do
		table.insert(enemies, {
			Id = enemy.Id,
			Leader = enemy.Leader,
			GuardId = if enemy.Leader then nil else enemy.Def.Id,
			Name = enemy.Name,
			Element = enemy.Element,
			Icon = if enemy.Leader then nil else enemy.Def.Icon,
			Role = if enemy.Leader then "Leader" else enemy.Def.Role,
			MaxHP = enemy.MaxHP,
			ATK = round(enemy.ATK),
			Taunt = enemy.Taunt or nil,
			Protect = if enemy.Protect > 0 then enemy.Protect else nil,
			Mend = enemy.MendName,
		})
	end
	local synergies = {}
	for _, active in self.Synergies do
		table.insert(synergies, { Element = active.Synergy.Element, Name = active.Synergy.Name, Count = active.Count, Text = active.Tier.Text })
	end
	local bonds = {}
	for _, entry in self.Bonds do
		table.insert(bonds, { Name = entry.Bond.Name, Units = { entry.A.Id, entry.B.Id } })
	end
	local boss = self.Boss
	return {
		BossId = self.BossId,
		Difficulty = self.Difficulty,
		Boss = { MaxHP = boss.MaxHP, ATK = round(boss.ATK), DEF = boss.DEF, SPD = boss.SPD, Element = boss.Element },
		Enemies = enemies,
		Allies = allies,
		Synergies = synergies,
		Bonds = bonds,
		Links = self.Links,
		TimeLimit = self.TimeLimit,
		UltimateCost = 100, -- legacy; each card's own cost is Allies[i].UltCost
		ClashWindow = B.ClashWindow,
		Shield = { Taken = B.ShieldTaken, Broken = B.BrokenTaken, Hold = B.HoldAbove, BreakSeconds = B.StaggerSeconds },
	}
end

local function gauge(value: number): number
	return math.floor(math.clamp(value, 0, 1) * 100) / 100
end

-- Live numbers for every unit. Card flags: B burning, Z frozen, T taunt, U buffed, S slowed,
-- G guarded, I invulnerable, N healing blocked, H holding a full Ultimate for a Shield Break. Card numbers:
-- G Basic progress, K seconds to its Skill, NextIn seconds to its Basic, E / EC energy and Ultimate cost,
-- Wk / Ex Weaken / Expose stacks. Enemy flags: D DEF down, A ATK down, S slowed, V takes more damage,
-- B burning, L bleeding, Z frozen, E enraged, W winding up, R barrier up, X rallied (ATK up), P protected
-- by a Warder, Q Shield Broken. Leader numbers: St Shield fill, Br break seconds left, Cl Clash window left.
-- Support cards send no HP. Fo is the player's focus target; Ho = AUTO ULT is holding for a break.
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
		if unit.HealingLock > 0 then flags ..= "N" end
		local full = unit.Ultimate ~= nil and unit.Alive and unit.Energy >= unit.UltCost
		if full and self.Holding then flags ..= "H" end
		units[unit.Id] = {
			H = if unit.HasHP then math.max(0, round(unit.HP)) else nil,
			S = if unit.HasHP then round(unit.Shield) else nil,
			E = unit.Energy,
			G = if unit.Alive then gauge(unit.Gauge) else 0,
			F = flags,
			K = if unit.Skill and unit.Alive and unit.HasHP then math.floor(math.max(0, 1 - unit.SkillGauge) * unit.Cooldown / self:Haste(unit) * 10 + 0.5) / 10 else nil,
			EC = if unit.Ultimate then unit.UltCost else nil,
			UltIn = if unit.Ultimate and unit.Alive then math.max(0, unit.UltCost - unit.Energy) / B.EnergyPerSecond else nil,
			M=if unit.HasHP then unit.MaxHP else nil,
			Bond=if unit.Bond then unit.Bond.Name else nil,
			NextIn = if unit.HasHP and unit.Alive then math.max(0, 1 - unit.Gauge) * unit.Interval / self:Haste(unit) else nil,
			Wk = if unit.Weaken > 0 then unit.Weaken else nil,
			Ex = if unit.Expose > 0 then unit.Expose else nil,
			PairedAlive = if unit.Type == "Support" then unit.Paired ~= nil and unit.Paired.Alive else nil,
			UsesLeft = if unit.Modifier and unit.Modifier.Def.Uses then math.max(0, unit.Modifier.Def.Uses - unit.Modifier.Used) else nil,
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
		local burned, bled = false, false
		for _, dot in enemy.Burns do
			if dot.Kind == "Bleed" then bled = true else burned = true end
		end
		if burned then flags ..= "B" end
		if bled then flags ..= "L" end
		if enemy.Frozen then flags ..= "Z" end
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
		if enemy.Staggered > 0 then
			flags ..= "Q"
		end
		units[enemy.Id] = {
			H = round(enemy.HP),
			G = if not enemy.Alive then 0 elseif enemy.Pending then 1 else gauge(enemy.Gauge),
			F = flags,
			Bar = if enemy.Barrier > 0 then enemy.Barrier else nil,
			St = if enemy.Leader then math.floor(enemy.Stagger * 100) / 100 else nil,
			Br = if enemy.Leader and enemy.Staggered > 0 then math.floor(enemy.Staggered * 10 + 0.5) / 10 else nil,
			Cl = if enemy.Pending and (enemy.Pending.Window or 0) > 0 then math.floor(enemy.Pending.Window * 10 + 0.5) / 10 else nil,
			Nx = if enemy.Leader and enemy.Alive then self:NextBigMove(enemy) else nil, -- { N = name, In = actions }
		}
	end
	return { T = math.floor(self.Time * 10) / 10, U = units, Fo = self.Focus, Ho = self.Holding or nil, AU = self.AutoUlt or nil, HB = self.HoldForBreak or nil }
end

-- End-of-fight numbers for the results screen.
function Engine:Summary()
	local dealt = {}
	for _, unit in self.Allies do
		local mod = unit.Modifier
		dealt[unit.Id] = {
			Dealt = unit.Dealt, Healed = unit.Healed, Alive = unit.Alive,
			Passive = if unit.Type == "Support" then {
				Attached = mod ~= nil, Used = if mod then mod.Used else 0,
				Uses = if mod then mod.Def.Uses else nil,
			} else nil,
		}
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
		Staggers = self.Boss.Staggers,
		CounterStaggers = self.Boss.CounterStaggers,
		Guards = #self.Enemies - 1,
		Units = dealt,
	}
end

return Engine
