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
	local chances = Borders.Chances(boost, math.clamp(luck, 1, Config.Roll.LuckCap))
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
