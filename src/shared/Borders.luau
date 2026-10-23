--!strict
-- Card borders: every pull also rolls a border, separately from its rarity. Normal most of the time,
-- sometimes Gold, rarely Rainbow, very rarely Secret. A card keeps every border it has found (the
-- Index collects them) and wears its best one. The bonus is small on purpose: a 5-star top-of-tier
-- card with a Secret border still stays under the weakest card of the next rarity, so rarity always
-- wins (odds_test checks this).
-- Shared so the odds panel shows exactly what the server rolls.

local Borders = {}

export type Border = {
	Id: string,
	Name: string,
	OneIn: number, -- 1 in OneIn pulls before the Border Chance stat (0 = the fallback, Normal)
	Bonus: number, -- stat bonus (0.02 = +2%)
	Color: Color3, -- main colour (labels, ribbons)
	Gradient: ColorSequence, -- the frame
}

local function seq(colors: { Color3 }): ColorSequence
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

Borders.List = {
	{
		Id = "Normal",
		Name = "Normal",
		OneIn = 0,
		Bonus = 0,
		Color = Color3.fromRGB(220, 220, 235),
		Gradient = seq({ Color3.fromRGB(220, 220, 235), Color3.fromRGB(160, 160, 180) }),
	},
	{
		Id = "Gold",
		Name = "Gold",
		OneIn = 25,
		Bonus = 0.01,
		Color = Color3.fromRGB(255, 200, 60),
		Gradient = seq({
			Color3.fromRGB(255, 244, 170),
			Color3.fromRGB(255, 190, 40),
			Color3.fromRGB(190, 120, 10),
			Color3.fromRGB(255, 220, 90),
		}),
	},
	{
		Id = "Rainbow",
		Name = "Rainbow",
		OneIn = 250,
		Bonus = 0.02,
		Color = Color3.fromRGB(255, 110, 200),
		Gradient = seq({
			Color3.fromRGB(255, 70, 90),
			Color3.fromRGB(255, 170, 40),
			Color3.fromRGB(250, 240, 60),
			Color3.fromRGB(70, 220, 110),
			Color3.fromRGB(60, 160, 255),
			Color3.fromRGB(170, 90, 255),
			Color3.fromRGB(255, 70, 90),
		}),
	},
	{
		Id = "Secret",
		Name = "Secret",
		OneIn = 2500,
		Bonus = 0.04,
		Color = Color3.fromRGB(200, 120, 255),
		Gradient = seq({
			Color3.fromRGB(10, 6, 20),
			Color3.fromRGB(240, 236, 255),
			Color3.fromRGB(150, 60, 255),
			Color3.fromRGB(10, 6, 20),
			Color3.fromRGB(120, 255, 240),
			Color3.fromRGB(10, 6, 20),
		}),
	},
} :: { Border }

Borders.ById = {} :: { [string]: Border }
Borders.Order = {} :: { string }
for i, border in Borders.List do
	Borders.ById[border.Id] = border
	Borders.Order[i] = border.Id
end

function Borders.Get(id: string?): Border
	return Borders.ById[id or "Normal"] or Borders.ById.Normal
end

-- 1 = Normal ... 4 = Secret.
function Borders.Index(id: string?): number
	return table.find(Borders.Order, id or "Normal") or 1
end

-- Each border's chance with the Border Chance stat (`boost` 0.3 = +30%). Normal takes the rest.
function Borders.Chances(boost: number?): { [string]: number }
	local chances = {}
	local special = 0
	for _, border in Borders.List do
		if border.OneIn > 0 then
			chances[border.Id] = (1 / border.OneIn) * (1 + (boost or 0))
			special += chances[border.Id]
		end
	end
	chances.Normal = 1 - special
	return chances
end

-- Which border a roll in [0, 1) gives, rarest checked first.
function Borders.Pick(roll: number, boost: number?): string
	local chances = Borders.Chances(boost)
	local target = roll
	for i = #Borders.List, 2, -1 do
		local id = Borders.List[i].Id
		target -= chances[id]
		if target < 0 then
			return id
		end
	end
	return "Normal"
end

-- The best border in a set of found ones ({ Gold = true, ... }), or "Normal".
function Borders.Best(found: { [string]: boolean }?): string
	local best = "Normal"
	for id, has in (found or {}) :: { [string]: boolean } do
		if has and Borders.Index(id) > Borders.Index(best) then
			best = id
		end
	end
	return best
end

-- The stat multiplier a border gives (1.04 for Secret).
function Borders.Multiplier(id: string?): number
	return 1 + Borders.Get(id).Bonus
end

-- "1 in 2,500" style text for a border's odds with a boost.
function Borders.OddsText(id: string, boost: number?): string
	local chance = Borders.Chances(boost)[id] or 0
	if chance <= 0 then
		return "-"
	end
	local oneIn = math.floor(1 / chance + 0.5)
	local s = tostring(oneIn):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if s:sub(1, 1) == "," then
		s = s:sub(2)
	end
	return `1 in {s}`
end

return Borders
