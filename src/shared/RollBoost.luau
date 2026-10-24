--!strict
-- Long-session rolling: Momentum and the Overcharge Surge. Shared so the HUD meter and the server agree.
--
--   * Momentum: every card roll (Roll, Quick, Auto, surge cards; not Roll Packs) adds 1 to a chain. Each
--     10 in the chain gives +1% roll speed and +0.01x base luck, up to +50% and +0.5x at 500. The chain
--     breaks after BreakSeconds without a roll, but that clock stops while the player is in a fight
--     (boss, tower or raid), so fighting never costs a streak. Session only (not saved).
--   * Overcharge Surge: every 25th roll (TotalRolls % 25 == 0, by lifetime rolls) is a surge. No pity: a
--     surge only multiplies the special border odds (Gold / Rainbow / Secret; Base takes the rest).
--       - Standard (Auto Roll, a late tap): 5x border odds (Gold 2.5%, Rainbow 0.1%, Secret 1 in 100,000 at
--         1x luck) and 1.5x foil odds.
--       - By hand, a clean tap inside the Surge window (the PerfectWindow seconds after the cooldown is
--         ready and the surge ring lights up), or on Auto with the Auto Roll pass: a PERFECT surge rolls
--         3 cards at once, all with 6x border odds and 2x foil odds. A late tap, or one
--         made while the cooldown was still running (an Early input, queued by the client), gets the
--         plain surge.

local RollBoost = {}

RollBoost.Momentum = {
	Step = 10, -- rolls per step
	SpeedPerStep = 0.01, -- +1% roll speed per step
	LuckPerStep = 0.01, -- +0.01x base luck per step
	Max = 500, -- the chain stops growing here (+50% speed, +0.5x luck)
	BreakSeconds = 30, -- out of a fight, this long without a roll breaks the chain
}

RollBoost.Surge = {
	Every = 25,
	PerfectWindow = 1.5,
	BorderMult = 5, -- standard surge: x border odds
	FoilMult = 1.5,
	PerfectBorderMult = 6, -- perfect surge: every card
	PerfectFoilMult = 2,
	PerfectCards = 3,
}

-- The roll speed and base luck a chain gives.
function RollBoost.MomentumBonus(count: number): (number, number)
	local m = RollBoost.Momentum
	local steps = math.floor(math.clamp(count, 0, m.Max) / m.Step)
	return steps * m.SpeedPerStep, steps * m.LuckPerStep
end

-- Whether lifetime roll number `n` (the roll about to happen is TotalRolls + 1) is a surge.
function RollBoost.IsSurge(n: number): boolean
	return n > 0 and n % RollBoost.Surge.Every == 0
end

-- Whether a hand roll of a surge is PERFECT: `early` (tapped while the cooldown still ran), `left` = the
-- cooldown still left when it reached the server (negative = that long since it came back), `tolerance`
-- the network slack the server forgives.
function RollBoost.IsPerfect(early: boolean, left: number, tolerance: number): boolean
	return not early and left <= tolerance and left > -(RollBoost.Surge.PerfectWindow + tolerance)
end

-- The surge meter: rolls made in the current cycle, 0-24 (0 right after a surge). The HUD binds to it.
function RollBoost.SurgeProgress(totalRolls: number): number
	return totalRolls % RollBoost.Surge.Every
end

-- Whether the roll that brought lifetime rolls to `totalRolls` was a surge.
function RollBoost.IsSurgeRoll(totalRolls: number): boolean
	return RollBoost.IsSurge(totalRolls)
end

-- Rolls until the next surge, counting the next roll as 1.
function RollBoost.UntilSurge(totalRolls: number): number
	local every = RollBoost.Surge.Every
	return every - totalRolls % every
end

return RollBoost
