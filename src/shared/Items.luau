--!strict
-- Gear that drops from boss wins (and later the Infinite Tower), kept in the BAG.
--   Artifacts: relics for the player. Wear up to ArtifactSlots; each boosts luck, roll speed, border
--     chance, Shards or XP. A duplicate levels it up (up to MaxLevel); past that it melts into Shards.
--   Accessories: worn by cards, one each, for speed, crits, guard or a head start on the Ultimate.
--     They never add ATK / HP, so Deck Power and "rarity always wins" stay as they are.
-- Shared so the BAG, the boss screen and the server agree on every number. Adding an item is one entry.

local Items = {}

export type Artifact = {
	Id: string,
	Name: string,
	Icon: string,
	Rarity: string,
	Kind: string, -- Luck (adds base luck, x) | RollSpeed | Border | ShardGain | XPGain (fractions, 0.05 = +5%)
	Amount: number, -- at level 1
	PerLevel: number, -- added for each level past 1
}

export type Effect = { Stat: string, Amount: number } -- battle buff: SPD | Crit | CritDamage | Guard | StartEnergy
export type Accessory = { Id: string, Name: string, Icon: string, Rarity: string, Effects: { Effect } }

Items.ArtifactSlots = 3
Items.MaxLevel = 5

Items.Artifacts = {
	{ Id = "clover", Name = "Four-Leaf Relic", Icon = "🍀", Rarity = "Rare", Kind = "Luck", Amount = 0.05, PerLevel = 0.02 },
	{ Id = "hourglass", Name = "Quicksand Hourglass", Icon = "⏳", Rarity = "Rare", Kind = "RollSpeed", Amount = 0.03, PerLevel = 0.01 },
	{ Id = "coin", Name = "Merchant's Coin", Icon = "🪙", Rarity = "Rare", Kind = "ShardGain", Amount = 0.08, PerLevel = 0.03 },
	{ Id = "tome", Name = "Sage's Tome", Icon = "📘", Rarity = "Rare", Kind = "XPGain", Amount = 0.08, PerLevel = 0.03 },
	{ Id = "prism", Name = "Prism Shard", Icon = "🔷", Rarity = "Epic", Kind = "Border", Amount = 0.15, PerLevel = 0.05 },
	{ Id = "moonstone", Name = "Moonstone", Icon = "🌙", Rarity = "Epic", Kind = "Luck", Amount = 0.12, PerLevel = 0.04 },
	{ Id = "emberheart", Name = "Ember Heart", Icon = "🔥", Rarity = "Legendary", Kind = "Luck", Amount = 0.25, PerLevel = 0.06 },
	{ Id = "frostsigil", Name = "Frost Sigil", Icon = "❄️", Rarity = "Legendary", Kind = "RollSpeed", Amount = 0.08, PerLevel = 0.02 },
	{ Id = "voideye", Name = "Void Eye", Icon = "👁️", Rarity = "Mythic", Kind = "Luck", Amount = 0.5, PerLevel = 0.1 },
	{ Id = "stormcrown", Name = "Storm Crown", Icon = "👑", Rarity = "Mythic", Kind = "Border", Amount = 0.5, PerLevel = 0.1 },
} :: { Artifact }

Items.Accessories = {
	{ Id = "feather", Name = "Feather Charm", Icon = "🪶", Rarity = "Rare", Effects = { { Stat = "SPD", Amount = 0.05 } } },
	{ Id = "hawkeye", Name = "Hawk-Eye Pendant", Icon = "🎯", Rarity = "Rare", Effects = { { Stat = "Crit", Amount = 0.05 } } },
	{ Id = "bangle", Name = "Iron Bangle", Icon = "🛡️", Rarity = "Rare", Effects = { { Stat = "Guard", Amount = 0.06 } } },
	{ Id = "spark", Name = "Spark Earring", Icon = "⚡", Rarity = "Epic", Effects = { { Stat = "StartEnergy", Amount = 0.25 } } },
	{ Id = "fang", Name = "Tiger Fang", Icon = "🐯", Rarity = "Epic", Effects = { { Stat = "CritDamage", Amount = 0.2 } } },
	{ Id = "scarf", Name = "Gale Scarf", Icon = "🧣", Rarity = "Epic", Effects = { { Stat = "SPD", Amount = 0.09 } } },
	{ Id = "scale", Name = "Dragon Scale", Icon = "🐉", Rarity = "Legendary", Effects = { { Stat = "Guard", Amount = 0.12 } } },
	{
		Id = "phoenix",
		Name = "Phoenix Plume",
		Icon = "🪽",
		Rarity = "Legendary",
		Effects = { { Stat = "Crit", Amount = 0.08 }, { Stat = "CritDamage", Amount = 0.15 } },
	},
	{
		Id = "thunder",
		Name = "Thunder Crest",
		Icon = "🌩️",
		Rarity = "Mythic",
		Effects = { { Stat = "SPD", Amount = 0.12 }, { Stat = "StartEnergy", Amount = 0.35 } },
	},
} :: { Accessory }

Items.ArtifactById = {} :: { [string]: Artifact }
for _, artifact in Items.Artifacts do
	Items.ArtifactById[artifact.Id] = artifact
end
Items.AccessoryById = {} :: { [string]: Accessory }
for _, accessory in Items.Accessories do
	Items.AccessoryById[accessory.Id] = accessory
end

-- A max-level artifact that drops again melts into this many Shards.
Items.MeltShards = { Rare = 150, Epic = 400, Legendary = 1200, Mythic = 4000 } :: { [string]: number }

-- Drops -------------------------------------------------------------------------------------------
-- Every boss win rolls once for an accessory and once for an artifact. The chance and the rarity mix
-- improve with the fight's difficulty score D (1-12).

Items.ItemRarities = { "Rare", "Epic", "Legendary", "Mythic" }

function Items.AccessoryChance(d: number): number
	return math.min(0.6, 0.2 + 0.03 * d)
end

function Items.ArtifactChance(d: number): number
	return math.min(0.15, 0.03 + 0.007 * d)
end

-- Rarity weights at D: Rare fades, the rarer ones grow (Mythic only from D 7).
function Items.RarityWeights(d: number): { [string]: number }
	return {
		Rare = math.max(20, 72 - 4 * d),
		Epic = 24 + d,
		Legendary = 4 + 1.6 * d,
		Mythic = if d >= 7 then (d - 6) * 1.5 else 0,
	}
end

-- Each rarity's share of a drop at D (sums to 1).
function Items.RarityChances(d: number): { [string]: number }
	local weights = Items.RarityWeights(d)
	local total = 0
	for _, w in weights do
		total += w
	end
	local chances = {}
	for rarity, w in weights do
		chances[rarity] = w / total
	end
	return chances
end

local function pickRarity(d: number, roll: number): string
	local chances = Items.RarityChances(d)
	for _, rarity in Items.ItemRarities do
		roll -= chances[rarity]
		if roll < 0 then
			return rarity
		end
	end
	return "Rare"
end

local function pickFrom(list: { any }, rarity: string, roll: number): string?
	local pool = {}
	for _, item in list do
		if item.Rarity == rarity then
			table.insert(pool, item.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
end

-- What a win at D drops: { Accessories = { id = 1 }?, Artifacts = { id = 1 }? }. `rng` is a Random.
-- `boost` multiplies both chances (the Infinite Tower and events can use it).
function Items.RollDrops(d: number, rng: Random, boost: number?): { Accessories: { [string]: number }?, Artifacts: { [string]: number }? }
	local drops = {}
	local mult = boost or 1
	if rng:NextNumber() < Items.AccessoryChance(d) * mult then
		local id = pickFrom(Items.Accessories, pickRarity(d, rng:NextNumber()), rng:NextNumber())
		if id then
			drops.Accessories = { [id] = 1 }
		end
	end
	if rng:NextNumber() < Items.ArtifactChance(d) * mult then
		local id = pickFrom(Items.Artifacts, pickRarity(d, rng:NextNumber()), rng:NextNumber())
		if id then
			drops.Artifacts = { [id] = 1 }
		end
	end
	return drops
end

-- Bonuses ------------------------------------------------------------------------------------------

export type Gear = {
	Artifacts: { [string]: number }, -- owned: id -> level
	Accessories: { [string]: number }, -- owned, not worn: id -> count
	Worn: { string }, -- artifact ids being worn (up to ArtifactSlots)
	Cards: { [string]: string }, -- cardId -> accessory id it wears
}

function Items.Empty(): Gear
	return { Artifacts = {}, Accessories = {}, Worn = {}, Cards = {} }
end

-- An artifact's bonus at a level.
function Items.ArtifactValue(artifact: Artifact, level: number): number
	return artifact.Amount + artifact.PerLevel * (math.clamp(level, 1, Items.MaxLevel) - 1)
end

-- What the worn artifacts add for a Kind (Luck, RollSpeed, Border, ShardGain, XPGain).
function Items.ArtifactBonus(gear: Gear?, kind: string): number
	if gear == nil then
		return 0
	end
	local total = 0
	for _, id in gear.Worn or {} do
		local artifact = Items.ArtifactById[id]
		local level = (gear.Artifacts or {})[id]
		if artifact and level and artifact.Kind == kind then
			total += Items.ArtifactValue(artifact, level)
		end
	end
	return total
end

-- The battle effects of the accessory a card wears (empty when none).
function Items.CardEffects(gear: Gear?, cardId: string): { Effect }
	local id = gear and gear.Cards and gear.Cards[cardId]
	local accessory = id and Items.AccessoryById[id]
	return if accessory then accessory.Effects else {}
end

-- "+5% speed", "+0.25x luck" ...
local STAT_TEXT = {
	SPD = "speed",
	Crit = "crit chance",
	CritDamage = "crit damage",
	Guard = "less damage taken",
	StartEnergy = "Ultimate charge at the start",
}
local KIND_TEXT = {
	RollSpeed = "faster rolls",
	Border = "border chance",
	ShardGain = "Shards",
	XPGain = "XP",
}

local function percent(x: number): string
	return `{math.floor(x * 100 + 0.5)}%`
end

function Items.ArtifactText(artifact: Artifact, level: number): string
	local value = Items.ArtifactValue(artifact, level)
	if artifact.Kind == "Luck" then
		return string.format("+%.2fx luck", value)
	end
	return `+{percent(value)} {KIND_TEXT[artifact.Kind] or artifact.Kind}`
end

function Items.AccessoryText(accessory: Accessory): string
	local parts = {}
	for _, effect in accessory.Effects do
		table.insert(parts, `+{percent(effect.Amount)} {STAT_TEXT[effect.Stat] or effect.Stat}`)
	end
	return table.concat(parts, ", ")
end

return Items
