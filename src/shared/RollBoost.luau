--!strict
-- Long-session rolling: Momentum and the Overcharge Surge. Shared so the HUD meter and the server agree.
--
--   * Momentum: every card roll (Roll, Quick, Auto, surge cards; not Roll Packs) adds 1 to a chain. Each
--     10 in the chain gives +1% roll speed and +0.01x base luck, up to +50% and +0.5x at 500. The chain
--     breaks after BreakSeconds without a roll, but that clock stops while the player is in a fight
--     (boss, tower or raid), so fighting never costs a streak. Session only (not saved).
--   * Overcharge Surge: every 25th roll (by lifetime rolls) is a surge.
--       - On Auto Roll: the card is Rare or better, with 1.5x border and foil odds.
--       - By hand, inside the Surge window (the PerfectWindow seconds after the cooldown is ready), or
--         on Auto with the Auto Roll pass: a PERFECT surge rolls 3 cards at once, the first Epic or
--         better, all with 2x border and foil odds. A late click gets the plain surge.

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
	Floor = "Rare", -- plain surge
	BorderMult = 1.5,
	PerfectFloor = "Epic", -- the first card of a perfect surge
	PerfectBorderMult = 2,
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

-- Rolls until the next surge, counting the next roll as 1.
function RollBoost.UntilSurge(totalRolls: number): number
	local every = RollBoost.Surge.Every
	return every - totalRolls % every
end

return RollBoost
