--!strict
-- Card borders ARE the tiers. Every pull rolls a card (Cards.Pool / Weight) and, on its own, a border:
-- Base 99.48%, Gold 0.5% (1/200), Rainbow 0.02% (1/5,000), Secret 0.0002% (1/500,000) at 1x luck: rare
-- on purpose (user's call 2026-10-24). Story bosses are beatable with Base + Gold (Gold also comes from
-- fusing 100 copies); Rainbow and Secret are the chase for the towers. The border multiplies the card's stats by its Multiplier (1x / 4x / 16x / 64x: constant 4x
-- steps), so a better border always wins (5 stars + Awakening node 1 are only 1.375x).
-- Luck raises the special borders by luck ^ LuckExponent, and the Border Chance stat / artifacts, surges
-- and infused packs multiply them; Base takes what's left.
-- A card keeps a copy count per border (Cards[id].BorderCopies) and wears its best. Hoshi fuses
-- Config.FusionCopies (100) copies at one border into 1 copy at the next (FusionService).
-- Id "Normal" is the save key of the Base border (its name on screen is "Base").
-- Shared so the odds panel shows exactly what the server rolls.

local Borders = {}

export type Border = {
	Id: string,
	Name: string,
	OneIn: number, -- 1 in OneIn pulls at 1x luck before boosts (0 = the fallback, Base)
	LuckExponent: number, -- luck raises this border's chance by luck ^ this
	Multiplier: number, -- stat multiplier (the tier)
	Cost: number, -- Deck Cost of a card wearing it (the Cost Challenge)
	Color: Color3, -- main colour (labels, ribbons)
	Dark: Color3, -- deep shade (card backs, reveal backdrops)
	Ladder: number, -- how big its reveal is (1 quiet ... 7 the full light show)
	Sting: string, -- which reveal sting plays (UI/Sfx STINGS key)
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
		Name = "Base",
		Ladder = 1,
		Sting = "Common",
		Dark = Color3.fromRGB(34, 38, 52),
		OneIn = 0,
		LuckExponent = 0,
		Multiplier = 1,
		Cost = 2,
		Color = Color3.fromRGB(220, 220, 235),
		Gradient = seq({ Color3.fromRGB(220, 220, 235), Color3.fromRGB(160, 160, 180) }),
	},
	{
		Id = "Gold",
		Name = "Gold",
		Ladder = 4,
		Sting = "Epic",
		Dark = Color3.fromRGB(96, 64, 8),
		OneIn = 200,
		LuckExponent = 0.6,
		Multiplier = 4,
		Cost = 4,
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
		Ladder = 6,
		Sting = "Mythic",
		Dark = Color3.fromRGB(70, 22, 80),
		OneIn = 5000,
		LuckExponent = 0.8,
		Multiplier = 16,
		Cost = 6,
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
		Ladder = 7,
		Sting = "Secret",
		Dark = Color3.fromRGB(14, 12, 24),
		OneIn = 500000,
		LuckExponent = 1,
		Multiplier = 64,
		Cost = 8,
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

-- Each border's chance (0-1) at `luck` (1x-Config luck cap) with `boost` (Border Chance stat, artifacts,
-- surges: 0.3 = +30%). Base takes the rest (never below half, however much is stacked).
function Borders.Chances(boost: number?, luck: number?): { [string]: number }
	local chances = {}
	local special = 0
	local l = math.max(1, luck or 1)
	for _, border in Borders.List do
		if border.OneIn > 0 then
			chances[border.Id] = (1 / border.OneIn) * (1 + (boost or 0)) * l ^ border.LuckExponent
			special += chances[border.Id]
		end
	end
	if special > 0.5 then
		for id, chance in chances do
			chances[id] = chance * 0.5 / special
		end
		special = 0.5
	end
	chances.Normal = 1 - special
	return chances
end

-- Which border a roll in [0, 1) gives, rarest checked first.
function Borders.Pick(roll: number, boost: number?, luck: number?): string
	local chances = Borders.Chances(boost, luck)
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

-- The stat multiplier a border gives (1 / 4 / 16 / 64).
function Borders.Multiplier(id: string?): number
	return Borders.Get(id).Multiplier
end

-- The next border up (fusion), or nil at Secret.
function Borders.Next(id: string?): string?
	return Borders.Order[Borders.Index(id) + 1]
end

-- The best border among a card's copies ({ Normal = 12, Gold = 1 }), counting only ones it still has.
function Borders.BestOwned(copies: { [string]: number }?): string
	local best = "Normal"
	for id, count in (copies or {}) :: { [string]: number } do
		if count > 0 and Borders.Index(id) > Borders.Index(best) then
			best = id
		end
	end
	return best
end

-- What a reveal needs about a pull's border: its name, how big the show is (Index 1-7), colours, sting.
function Borders.RevealTier(id: string?): { Name: string, Index: number, Color: Color3, Dark: Color3, Sting: string }
	local border = Borders.Get(id)
	return { Name = border.Name, Index = border.Ladder, Color = border.Color, Dark = border.Dark, Sting = border.Sting }
end

-- "Gold Border · 4x"
function Borders.Label(id: string?): string
	local border = Borders.Get(id)
	return `{border.Name} Border · {border.Multiplier}x`
end

-- "1 in 2,500" style text for a border's odds with a boost and luck.
function Borders.OddsText(id: string, boost: number?, luck: number?): string
	local chance = Borders.Chances(boost, luck)[id] or 0
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
