--!strict
-- Server raids (design bible v2, "World Boss Raids", made our own). On the clock, the same on every
-- server: every Every seconds a raid opens for Duration seconds. A Colossus (a world boss alone, huge)
-- appears, and everyone on the server fights it in their own FightSeconds runs; every hit drains one
-- shared HP pool for the whole server.
--
--   * Each player's Colossus is sized to their Deck Power (the tower curve at their power, HPRuns x its
--     HP so no run can fell it alone), so a new player's runs count as much as a veteran's, in effort.
--   * The first run a player starts adds PoolShare x that HP to the pool: the pool grows with the server,
--     and it takes everyone two or three good runs.
--   * Drain the pool before the window closes: everyone who hit it is paid (more for more damage, a Big
--     Roll Pack for the top hitter), and the whole server gets Raid Luck for LuckSeconds. A failed raid
--     still pays its hitters some Shards.
-- Shared so the client shows the same schedule, numbers and rewards the server uses.

local Tower = require(script.Parent.Tower)

local Raid = {}

Raid.Id = "raid" -- what the client sends to BattleStart for a raid run
Raid.Every = 3600 -- a raid every hour...
Raid.Offset = 1800 -- ...at half past (UTC)
Raid.Duration = 600 -- open for 10 minutes
Raid.FightSeconds = 60 -- one run
Raid.Difficulty = "Hard" -- which of the boss's moves the Colossus uses
Raid.HPRuns = 4 -- a player's Colossus: 4x the tower leader HP at their power
Raid.ATK = 1.1 -- and 1.1x its ATK
Raid.PoolShare = 3 -- the first run adds 3x that HP to the server's pool
Raid.MaxScore = 4 -- rewards count up to 4 "runs' worth" of damage (damage / the tower HP at their power)
Raid.LuckBoost = 2 -- Raid Luck: x2 luck for everyone on the server...
Raid.LuckSeconds = 600 -- ...for 10 minutes after a clear
Raid.ClearPacks = { ["10"] = 1 } :: { [string]: number } -- every hitter of a cleared raid
Raid.TopPacks = { ["100"] = 1 } :: { [string]: number } -- the top hitter, on top
Raid.ClearDropBoost = 2 -- artifact odds on a clear (Items.RollDrops)

-- Pool: a multiplier on the pool share for a kit that is slower to chew through (Vex's barrier wants
-- Skills, Tenrai's chain lightning wears a young deck down; measured in tests/strategy_test.luau).
export type Colossus = { Boss: string, Name: string, Pool: number? }

Raid.Colossi = {
	{ Boss = "kurogane", Name = "Ash Colossus" },
	{ Boss = "rimeveil", Name = "Glacier Colossus" },
	{ Boss = "vex", Name = "Null Colossus", Pool = 0.65 },
	{ Boss = "tenrai", Name = "Storm Colossus", Pool = 0.9 },
} :: { Colossus }

export type Window = {
	Index: number, -- which raid this is (one id per window, the same on every server)
	Colossus: Colossus,
	Starts: number,
	Ends: number,
	Open: boolean,
	Next: number, -- when the next window opens
}

-- The raid window at time `t` (seconds, server time). `override` (the test tools) opens one now.
function Raid.At(t: number, override: { Ends: number }?): Window
	if override and override.Ends > t then
		local index = -math.floor(override.Ends)
		return {
			Index = index,
			Colossus = Raid.Colossi[math.floor(override.Ends) % #Raid.Colossi + 1],
			Starts = override.Ends - Raid.Duration,
			Ends = override.Ends,
			Open = true,
			Next = override.Ends - Raid.Duration + Raid.Every,
		}
	end
	local index = math.floor((t - Raid.Offset) / Raid.Every)
	local starts = index * Raid.Every + Raid.Offset
	local ends = starts + Raid.Duration
	return {
		Index = index,
		Colossus = Raid.Colossi[index % #Raid.Colossi + 1],
		Starts = starts,
		Ends = ends,
		Open = t >= starts and t < ends,
		Next = starts + Raid.Every,
	}
end

-- A player's Colossus for one run: HP / ATK off the tower curve at their Deck Power.
function Raid.StatsFor(power: number): { HP: number, ATK: number, WarnSeconds: number, Base: number }
	local hp, atk = Tower.StatsAt(math.max(power, 1000))
	return {
		HP = math.floor(hp * Raid.HPRuns + 0.5),
		ATK = math.floor(atk * Raid.ATK + 0.5),
		WarnSeconds = 2,
		Base = hp, -- one "run's worth": rewards count damage in these
	}
end

-- What the pool grows by when a player of this power joins (against `colossus`).
function Raid.PoolFor(power: number, colossus: Colossus?): number
	return math.floor(Raid.StatsFor(power).Base * Raid.PoolShare * (colossus and colossus.Pool or 1) + 0.5)
end

-- How many "runs' worth" a player's damage is (for rewards), capped.
function Raid.Score(damage: number, power: number): number
	return math.min(Raid.MaxScore, damage / Raid.StatsFor(power).Base)
end

export type Reward = { D: number, Shards: number, Packs: { [string]: number }?, DropBoost: number, TraitShards: number }

Raid.ClearTraitShards = 5 -- every hitter of a cleared raid, + 2 per run's worth of damage
Raid.FailTraitShards = 2 -- a failed raid, + 1 per run's worth
Raid.TopTraitShards = 10 -- the top hitter, on top

-- A hitter left mid-raid: the part of their share they never dealt comes off the pool, so the raid stays
-- winnable for the rest (it never drops below what's been dealt already).
function Raid.PoolAfterLeave(max: number, dealt: number, share: number, damage: number): number
	return math.max(dealt, max - math.max(0, share - damage))
end

-- What a hitter is paid: scaled to their progress (the tower floor matching their power) and damage.
function Raid.Reward(cleared: boolean, damage: number, power: number, top: boolean): Reward
	local floor = Tower.FloorForPower(power)
	local base = Tower.Reward(floor)
	local score = Raid.Score(damage, power)
	local topShards = if top then Raid.TopTraitShards else 0
	if not cleared then
		return {
			D = base.D,
			Shards = math.floor(base.Shards * 0.5 * (1 + score) + 0.5),
			DropBoost = 0,
			TraitShards = Raid.FailTraitShards + math.floor(score) + topShards,
		}
	end
	local packs: { [string]: number } = table.clone(Raid.ClearPacks)
	if top then
		for id, count in Raid.TopPacks do
			packs[id] = (packs[id] or 0) + count
		end
	end
	return {
		D = base.D,
		Shards = math.floor(base.Shards * (1 + score) + 0.5),
		Packs = packs,
		DropBoost = Raid.ClearDropBoost,
		TraitShards = Raid.ClearTraitShards + 2 * math.floor(score) + topShards,
	}
end

-- Raid Luck's multiplier at `t`, given when the last one ends (nil = none).
function Raid.LuckAt(t: number, luckEnds: number?): number
	return if luckEnds and luckEnds > t then Raid.LuckBoost else 1
end

return Raid
