--!strict
-- Artifacts: relics that drop from boss wins and Infinite Tower floors, kept in the BAG. Wear up to
-- ArtifactSlots; each boosts luck, roll speed, border chance, Shards or XP. A duplicate levels it up
-- (up to MaxLevel); past that it melts into Shards. (Card accessories were removed on 2026-10-23:
-- per-card battle bonuses are traits now, Traits.luau.)
-- Shared so the BAG, the boss screen and the server agree on every number. Adding an artifact is one entry.

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

Items.ArtifactById = {} :: { [string]: Artifact }
for _, artifact in Items.Artifacts do
	Items.ArtifactById[artifact.Id] = artifact
end

-- A max-level artifact that drops again melts into this many Shards.
Items.MeltShards = { Rare = 150, Epic = 400, Legendary = 1200, Mythic = 4000 } :: { [string]: number }

-- Drops -------------------------------------------------------------------------------------------
-- Every boss win and tower floor rolls once for an artifact. The chance and the rarity mix improve with
-- the fight's difficulty score D (1-12 for bosses, floor x 0.25 in the tower).

Items.ItemRarities = { "Rare", "Epic", "Legendary", "Mythic" }

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

-- What a win at D drops: { Artifacts = { id = 1 }? }. `rng` is a Random. `boost` multiplies the chance
-- (tower Guardians use it).
function Items.RollDrops(d: number, rng: Random, boost: number?): { Artifacts: { [string]: number }? }
	local drops = {}
	local mult = boost or 1
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
	Worn: { string }, -- artifact ids being worn (up to ArtifactSlots)
}

function Items.Empty(): Gear
	return { Artifacts = {}, Worn = {} }
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
	for _, id in (gear.Worn or {}) :: { string } do
		local artifact = Items.ArtifactById[id]
		local level = (gear.Artifacts or {})[id]
		if artifact and level and artifact.Kind == kind then
			total += Items.ArtifactValue(artifact, level)
		end
	end
	return total
end

-- "+0.25x luck", "+5% faster rolls" ...
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

return Items
