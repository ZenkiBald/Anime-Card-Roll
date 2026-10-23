--!strict
-- The Infinite Tower: climb floor after floor, each one a random enemy that hits harder and pays more.
-- Shared so the tower screen previews exactly the fight and rewards the server runs.
--
--   * Progress is permanent: the player always fights the floor above their highest clear, and a floor
--     pays once (no farming). The best floor is saved and shown on the leaderboard.
--   * Each floor's enemy is one of the world bosses (their moves, models and backdrops) at stats scaled
--     to the floor, picked by a seeded hash of the floor number: random-looking, but the same for every
--     player on every server, so the screen can preview it and a retry faces the same fight.
--   * From AffixFrom up, a floor may roll an affix: a fair trade (more of one stat, less of another) that
--     changes how the fight plays, not how hard it is. Every GuardianEvery floors a Guardian stands
--     guard: stronger, with more Shards, a sure potion and better gear odds.
--   * Recommended power grows by Growth per floor, without end; HP / ATK follow the same curve the world
--     bosses are tuned on. tests/tower_test.luau checks a deck at a floor's recommended power wins it.
--   * Every floor pays Shards, XP and a roll for gear (Items.RollDrops at D = floor x DPerFloor, World 1
--     Normal = 1, boosted on Guardians); some floors also drop Roll Packs (Packs.ForFloor).
-- A new enemy or affix is one entry below.

local Bosses = require(script.Parent.Bosses)
local Rewards = require(script.Parent.Rewards)
local Packs = require(script.Parent.Packs)
local Items = require(script.Parent.Items)

local Tower = {}

Tower.Id = "tower" -- what the client sends to BattleStart for a tower floor
Tower.UnlockAfter = "kurogane:Normal" -- with Config.Unlocks on, the tower opens after this clear

export type Enemy = {
	Boss: string, -- the boss whose moves, model and backdrop the floor uses
	Name: string, -- shown instead of the boss's name
	MinFloor: number, -- in the pool from this floor up
	HP: number, -- multipliers on the floor's curve, for how hard the boss's kit is at the same stats
	ATK: number,
}

export type Affix = {
	Id: string,
	Name: string,
	Icon: string,
	Text: string,
	HP: number?, -- multipliers
	ATK: number?,
	DEF: number?, -- added (boss DEF is capped at Config.Battle.MaxDEF)
	SPD: number?, -- added
}

Tower.Enemies = {
	{ Boss = "kurogane", Name = "Ash Echo", MinFloor = 1, HP = 1, ATK = 1 },
	{ Boss = "rimeveil", Name = "Rime Echo", MinFloor = 1, HP = 0.9, ATK = 1 },
	{ Boss = "vex", Name = "Void Echo", MinFloor = 24, HP = 0.75, ATK = 1 }, -- his barrier needs Skills: not before floor 24
	{ Boss = "tenrai", Name = "Storm Echo", MinFloor = 30, HP = 0.92, ATK = 1 },
} :: { Enemy }

Tower.Affixes = {
	{ Id = "swift", Name = "Swift", Icon = "💨", Text = "+15 SPD, -12% ATK", SPD = 15, ATK = 0.88 },
	{ Id = "armored", Name = "Armored", Icon = "🛡️", Text = "+10% DEF, -12% HP", DEF = 0.1, HP = 0.88 },
	{ Id = "brutal", Name = "Brutal", Icon = "💢", Text = "+20% ATK, -15% HP", ATK = 1.2, HP = 0.85 },
	{ Id = "colossal", Name = "Colossal", Icon = "⛰️", Text = "+20% HP, -15% ATK", HP = 1.2, ATK = 0.85 },
} :: { Affix }

Tower.AffixFrom = 5 -- floors from here up may roll an affix
Tower.AffixChance = 0.5
Tower.GuardianEvery = 10 -- floor 10, 20, 30 ...: a Guardian
Tower.GuardianPower = 1.15 -- its recommended power over the floor's

-- The curve: recommended Deck Power at floor 1 and its growth per floor, without end. HP and ATK come
-- from Points: the leader HP / ATK (guards are shares of it) that a deck of that power beats in about 70 s
-- (measured with the battle simulator against the fixture decks and the floor's guards, then smoothed so
-- neither ever drops as power grows), joined in
-- log space between points and carried on past the last one by the Beyond exponents.
Tower.Curve = {
	Power = 9000,
	Growth = 1.068, -- about 2x every 10 floors; floor 48 is about Tenrai Nightmare
	Points = {
		{ Power = 9000, HP = 11000, ATK = 85 },
		{ Power = 12000, HP = 14500, ATK = 105 },
		{ Power = 18000, HP = 18500, ATK = 115 },
		{ Power = 24000, HP = 36000, ATK = 240 },
		{ Power = 28500, HP = 43000, ATK = 320 },
		{ Power = 43000, HP = 135000, ATK = 440 },
		{ Power = 55000, HP = 175000, ATK = 480 },
		{ Power = 74500, HP = 450000, ATK = 700 },
		{ Power = 99500, HP = 1050000, ATK = 1000 },
		{ Power = 137000, HP = 1400000, ATK = 2600 },
		{ Power = 171000, HP = 1800000, ATK = 3300 },
		{ Power = 203000, HP = 2000000, ATK = 4000 },
	},
	Beyond = { HP = 1.3, ATK = 1.3 }, -- past the last point: HP x (power / last) ^ 1.3
}

-- Which of a boss's moves are in: the Hard-only moves join at floor HardFrom, Nightmare's at NightmareFrom
-- (Nightmare also shortens the warning before big moves).
Tower.HardFrom = 15
Tower.NightmareFrom = 30

Tower.DPerFloor = 0.25 -- reward score D = floor x 0.25 (floor 4 pays like World 1 Normal)
Tower.ShardsBase = 20 -- Shards = 20 + 5 x floor, x3 on a Guardian
Tower.ShardsPerFloor = 5
Tower.GuardianShards = 3
Tower.DropBoost = 1 -- gear drop chance multiplier (Items.RollDrops) on an ordinary floor
Tower.GuardianDropBoost = 4 -- and on a Guardian: an artifact up to 60%, an accessory almost sure

export type Floor = {
	Floor: number,
	Boss: string,
	Name: string,
	Guardian: boolean,
	Affix: string?, -- Tower.AffixById key
	Guards: { string }, -- three Bosses.GuardTypes ids standing with the echo (a Warder last, in front)
	Difficulty: string, -- which boss moves are in: Normal | Hard | Nightmare
	Recommended: number,
	HP: number,
	ATK: number,
	DEF: number, -- added to the boss's own
	SPD: number,
	WarnSeconds: number,
}

export type Reward = {
	D: number,
	Packs: { [string]: number }?, -- Roll Packs this floor drops (Packs.ForFloor)
	Shards: number,
	Potion: string?, -- Guardians: a sure potion
	DropBoost: number,
}

Tower.AffixById = {} :: { [string]: Affix }
for _, affix in Tower.Affixes do
	Tower.AffixById[affix.Id] = affix
end

-- A small seeded hash of the floor number, the same on the server, the client and in tests.
local function hash(floor: number, salt: number): number
	local seed = (floor * 7919 + salt * 104729 + 13) % 2147483647
	for _ = 1, 3 do
		seed = (seed * 48271 + 11) % 2147483647
	end
	return seed
end

function Tower.IsGuardian(floor: number): boolean
	return floor % Tower.GuardianEvery == 0
end

function Tower.Recommended(floor: number): number
	local c = Tower.Curve
	local power = c.Power * c.Growth ^ (math.max(1, floor) - 1)
	if Tower.IsGuardian(floor) then
		power *= Tower.GuardianPower
	end
	return math.floor(power / 100 + 0.5) * 100
end

-- Boss HP and ATK for a recommended power, off Curve.Points.
function Tower.StatsAt(power: number): (number, number)
	local points = Tower.Curve.Points
	local first, last = points[1], points[#points]
	if power <= first.Power then
		return first.HP * power / first.Power, first.ATK * power / first.Power
	end
	if power >= last.Power then
		local x = power / last.Power
		return last.HP * x ^ Tower.Curve.Beyond.HP, last.ATK * x ^ Tower.Curve.Beyond.ATK
	end
	for i = 2, #points do
		local lo, hi = points[i - 1], points[i]
		if power <= hi.Power then
			local t = math.log(power / lo.Power) / math.log(hi.Power / lo.Power)
			return lo.HP * (hi.HP / lo.HP) ^ t, lo.ATK * (hi.ATK / lo.ATK) ^ t
		end
	end
	return last.HP, last.ATK
end

-- Which enemy and affix a floor has (forced ones are for tests).
function Tower.Pick(floor: number): (Enemy, Affix?)
	local pool = {}
	for _, enemy in Tower.Enemies do
		if floor >= enemy.MinFloor then
			table.insert(pool, enemy)
		end
	end
	local enemy = pool[hash(floor, 1) % #pool + 1]
	local affix = nil
	if floor >= Tower.AffixFrom and not Tower.IsGuardian(floor) and hash(floor, 2) % 1000 < Tower.AffixChance * 1000 then
		affix = Tower.Affixes[hash(floor, 3) % #Tower.Affixes + 1]
	end
	return enemy, affix
end

-- The floor's three guards: drawn (seeded) from the guards of every world whose echo the floor can
-- roll, at most one Warder and one Mender, the Warder last (it stands in front).
function Tower.GuardsAt(floor: number): { string }
	local maxWorld = 1
	for _, enemy in Tower.Enemies do
		if floor >= enemy.MinFloor then
			maxWorld = math.max(maxWorld, (Bosses.Get(enemy.Boss) :: any).World)
		end
	end
	local pool = {}
	for _, g in Bosses.GuardList do
		if g.World <= maxWorld then
			table.insert(pool, g)
		end
	end
	local picked, warder, roles = {}, nil, {}
	local salt = 10
	while #picked + (if warder then 1 else 0) < 3 and salt < 60 do
		local g = pool[hash(floor, salt) % #pool + 1]
		salt += 1
		local taken = (warder and warder.Id == g.Id) or table.find(picked, g.Id) ~= nil
		if not taken then
			if g.Role == "Warder" then
				warder = warder or g
			elseif g.Role ~= "Mender" or not roles.Mender then
				roles[g.Role] = true
				table.insert(picked, g.Id)
			end
		end
	end
	if warder then
		table.insert(picked, warder.Id)
	end
	return picked
end

-- Everything about a floor's fight. `enemy` / `affix` override the pick (tests); pass false for no affix.
function Tower.FloorAt(floor: number, enemy: Enemy?, affix: (Affix | false)?): Floor
	floor = math.max(1, math.floor(floor))
	local pickedEnemy, pickedAffix = Tower.Pick(floor)
	local e = enemy or pickedEnemy
	local a: Affix? = if affix == false then nil elseif affix then affix else pickedAffix
	local recommended = Tower.Recommended(floor)
	local hp, atk = Tower.StatsAt(recommended)
	local difficulty = if floor >= Tower.NightmareFrom then "Nightmare" elseif floor >= Tower.HardFrom then "Hard" else "Normal"
	return {
		Floor = floor,
		Boss = e.Boss,
		Name = if Tower.IsGuardian(floor) then `{e.Name} Guardian` else e.Name,
		Guardian = Tower.IsGuardian(floor),
		Affix = a and a.Id,
		Guards = Tower.GuardsAt(floor),
		Difficulty = difficulty,
		Recommended = recommended,
		HP = math.floor(hp * e.HP * (a and a.HP or 1) / 100 + 0.5) * 100,
		ATK = math.floor(atk * e.ATK * (a and a.ATK or 1) + 0.5),
		DEF = a and a.DEF or 0,
		SPD = a and a.SPD or 0,
		WarnSeconds = if difficulty == "Nightmare" then 1 else 2,
	}
end

-- What clearing a floor pays (once: cleared floors can't be fought again).
function Tower.Reward(floor: number): Reward
	local d = floor * Tower.DPerFloor
	local base = Rewards.For(d)
	local guardian = Tower.IsGuardian(floor)
	local shards = Tower.ShardsBase + Tower.ShardsPerFloor * floor
	return {
		D = d,
		Packs = Packs.ForFloor(floor),
		Shards = if guardian then shards * Tower.GuardianShards else shards,
		Potion = if guardian then base.Potion else nil,
		DropBoost = if guardian then Tower.GuardianDropBoost else Tower.DropBoost,
	}
end

-- The gear odds a floor's win rolls (for the tower screen): accessory and artifact chance.
function Tower.DropChances(floor: number): (number, number)
	local reward = Tower.Reward(floor)
	return math.min(1, Items.AccessoryChance(reward.D) * reward.DropBoost), math.min(1, Items.ArtifactChance(reward.D) * reward.DropBoost)
end

-- "Beat Kurogane on Normal": what opens the tower (with Config.Unlocks on).
function Tower.UnlockHint(): string
	local id, difficulty = string.match(Tower.UnlockAfter, "^(.-):(.+)$")
	local boss = Bosses.Get(id or "")
	return if boss then `Beat {boss.Name} on {difficulty}` else ""
end

-- The next Guardian floor at or above `floor`.
function Tower.NextGuardian(floor: number): number
	return math.ceil(math.max(1, floor) / Tower.GuardianEvery) * Tower.GuardianEvery
end

return Tower
