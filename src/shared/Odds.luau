--!strict
-- Roll odds. Shared by the server (to roll) and the client (to show the Odds panel),
-- so what players see is exactly what the server uses.
--
-- Luck multiplies every Rare-and-above chance; the extra comes out of Common.
-- A rarity floor (optional) upgrades any result below it to the floor tier. There is no pity: every
-- roll is pure luck.

local Config = require(script.Parent.Config)
local Rarity = require(script.Parent.Rarity)

local Odds = {}

export type Chances = { [string]: number }

-- Percent chance for each rarity at the given luck and optional floor. Always sums to 100.
function Odds.Chances(luck: number, floor: string?): Chances
	luck = math.clamp(luck, 1, Config.Roll.LuckCap)

	local chances: Chances = {}
	local rarePlus = 0
	for i = 3, #Rarity.Order do
		local name = Rarity.Order[i]
		local chance = Rarity.Tiers[name].BaseChance * luck
		chances[name] = chance
		rarePlus += chance
	end
	chances.Uncommon = Rarity.Tiers.Uncommon.BaseChance
	chances.Common = math.max(0, 100 - chances.Uncommon - rarePlus)

	if floor ~= nil then
		local floorIndex = Rarity.Index(floor)
		for i = 1, floorIndex - 1 do
			local name = Rarity.Order[i]
			chances[floor] += chances[name]
			chances[name] = 0
		end
	end

	-- Normalise so the total is exactly 100 even with floating-point error.
	local total = 0
	for _, name in Rarity.Order do
		total += chances[name]
	end
	for _, name in Rarity.Order do
		chances[name] = chances[name] / total * 100
	end
	return chances
end

-- Pick a rarity from a chance table using the given Random.
function Odds.PickTier(chances: Chances, rng: Random): string
	local roll = rng:NextNumber() * 100
	local acc = 0
	local lastNonZero = Rarity.Order[1]
	for i = #Rarity.Order, 1, -1 do
		local name = Rarity.Order[i]
		local chance = chances[name]
		if chance > 0 then
			lastNonZero = name
			acc += chance
			if roll < acc then
				return name
			end
		end
	end
	return lastNonZero
end

-- "12.5%", "0.900%", "0.0100%" depending on size.
function Odds.FormatPercent(pct: number): string
	if pct <= 0 then
		return "0%"
	elseif pct >= 10 then
		return string.format("%.1f%%", pct)
	elseif pct >= 1 then
		return string.format("%.2f%%", pct)
	elseif pct >= 0.1 then
		return string.format("%.3f%%", pct)
	end
	return string.format("%.4f%%", pct)
end

-- "1 in 1,111"
function Odds.FormatOneIn(pct: number): string
	if pct <= 0 then
		return "-"
	end
	local n = 100 / pct
	if n < 10 then
		return string.format("1 in %.1f", n)
	end
	local whole = tostring(math.floor(n + 0.5))
	local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "1 in " .. withCommas
end

return Odds
