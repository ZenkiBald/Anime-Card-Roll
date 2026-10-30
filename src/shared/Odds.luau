--!strict
-- Roll odds. Shared by the server (to roll) and the client (to show the Odds panel), so what players
-- see is exactly what the server uses. A pull is a card (Cards.PullChances: each card's Weight in the
-- pool) and a border (Borders.Chances: the tier). Luck (capped at Config.Roll.LuckCap, 25x) raises the
-- special borders: Gold by luck ^ 0.6, Rainbow ^ 0.8, Secret ^ 1. There is no pity: pure luck.

local Config = require(script.Parent.Config)
local Borders = require(script.Parent.Borders)

local Odds = {}

export type Chances = { [string]: number }

-- Percent chance of each border at `luck` with `boost` (Border Chance stat etc.). Sums to 100.
function Odds.Chances(luck: number, boost: number?): Chances
	local chances = Borders.Chances(boost, math.max(1,luck))
	local percent: Chances = {}
	for id, chance in chances do
		percent[id] = chance * 100
	end
	return percent
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

-- The round numbers rarity numbers snap to: these mantissas times a power of ten (12, 125, 2,500, 7,500,000).
Odds.RoundSteps = { 1, 1.2, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3, 3.25, 4, 5, 6, 6.25, 6.5, 7.5, 8, 10 }

-- `n` snapped to the nearest round number (nearest in ratio, so 48 -> 50 and 9,950,000 -> 10,000,000).
function Odds.Round(n: number): number
	if n <= 0 then
		return 0
	end
	local scale = 10 ^ math.floor(math.log10(n))
	local best, gap = n, math.huge
	for _, step in Odds.RoundSteps do
		local value = step * scale
		local g = math.abs(math.log(n / value))
		if g < gap then
			best, gap = value, g
		end
	end
	return math.floor(best + 0.5)
end

-- The rarity number for a chance in percent: how many tries it takes on average, as a plain number
-- ("5,000", never "1 in 5,000": the user's call, the big ones are the flex). "" for anything more common
-- than 1 in 1.5 (the Base border), "-" for a zero chance.
function Odds.FormatRarity(pct: number): string
	if pct <= 0 then
		return "-"
	end
	local n = 100 / pct
	if n < 1.5 then
		return ""
	elseif n < 10 then
		return string.format("%.1f", n)
	end
	local whole = tostring(Odds.Round(n))
	return (whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

return Odds
