--!strict
-- The seven rarity tiers. Each tier's stats are at least 1.6x the tier below,
-- more than the most a lower card can gain (+-10% variance, +25% at 5 stars),
-- so a higher rarity always wins.

export type Tier = {
	Name: string,
	Index: number,
	BaseChance: number, -- percent at 1x luck
	Multiplier: number, -- stat multiplier
	Color: Color3,
	Dark: Color3,
	Abilities: string,
}

local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local tiers: { [string]: Tier } = {
	Common = {
		Name = "Common",
		Index = 1,
		BaseChance = 60,
		Multiplier = 1.0,
		Color = Color3.fromRGB(176, 184, 196),
		Dark = Color3.fromRGB(58, 62, 72),
		Abilities = "Basic",
	},
	Uncommon = {
		Name = "Uncommon",
		Index = 2,
		BaseChance = 25,
		Multiplier = 1.6,
		Color = Color3.fromRGB(86, 214, 138),
		Dark = Color3.fromRGB(22, 72, 48),
		Abilities = "Basic + Passive",
	},
	Rare = {
		Name = "Rare",
		Index = 3,
		BaseChance = 10,
		Multiplier = 2.6,
		Color = Color3.fromRGB(64, 156, 255),
		Dark = Color3.fromRGB(16, 48, 96),
		Abilities = "Basic + Skill",
	},
	Epic = {
		Name = "Epic",
		Index = 4,
		BaseChance = 4,
		Multiplier = 4.2,
		Color = Color3.fromRGB(176, 92, 255),
		Dark = Color3.fromRGB(56, 22, 96),
		Abilities = "Basic + Skill + Passive",
	},
	Legendary = {
		Name = "Legendary",
		Index = 5,
		BaseChance = 0.9,
		Multiplier = 7.0,
		Color = Color3.fromRGB(255, 196, 46),
		Dark = Color3.fromRGB(96, 64, 8),
		Abilities = "+ Ultimate",
	},
	Mythic = {
		Name = "Mythic",
		Index = 6,
		BaseChance = 0.09,
		Multiplier = 12,
		Color = Color3.fromRGB(255, 58, 92),
		Dark = Color3.fromRGB(96, 10, 28),
		Abilities = "2-effect Ultimate + Aura",
	},
	Secret = {
		Name = "Secret",
		Index = 7,
		BaseChance = 0.01,
		Multiplier = 20,
		Color = Color3.fromRGB(240, 236, 255),
		Dark = Color3.fromRGB(14, 12, 24),
		Abilities = "+ Signature mechanic",
	},
}

Rarity.Tiers = tiers

function Rarity.Get(name: string): Tier
	local tier = tiers[name]
	assert(tier, `Unknown rarity "{name}"`)
	return tier
end

function Rarity.Index(name: string): number
	return Rarity.Get(name).Index
end

-- true when rarity a is the same as or better than rarity b
function Rarity.AtLeast(a: string, b: string): boolean
	return Rarity.Index(a) >= Rarity.Index(b)
end

-- Two-tone gradient for card frames; Secret is prismatic.
function Rarity.Gradient(name: string): ColorSequence
	if name == "Secret" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 140)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 196, 46)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(110, 240, 160)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 190, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(176, 110, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 92, 140)),
		})
	end
	local tier = Rarity.Get(name)
	local h, s, v = tier.Color:ToHSV()
	local light = Color3.fromHSV(h, math.max(0, s - 0.25), math.min(1, v + 0.15))
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.5, tier.Color),
		ColorSequenceKeypoint.new(1, light),
	})
end

return Rarity
