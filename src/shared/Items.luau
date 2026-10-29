--!strict
-- Gear, in two sets (the user's call, 2026-10-24):
--   * RELICS (Items.Artifacts in code, Gear.Artifacts in saves, shown as "Relic"): the ten wearable items.
--     They drop only from Infinite Tower wins on floor RelicFloor and up, at RelicChance a win. Wear up to
--     ArtifactSlots; each boosts luck, roll speed, border chance, Shards or XP. A duplicate levels it up
--     (up to MaxLevel); past that it melts into Shards.
--   * ARTIFACTS (Items.TowerArtifacts, Gear.TowerArtifacts, shown as "Artifact"): one per finite tower,
--     given only for clearing its last floor (the Pagoda's floor 100). Always on, no slot; several bonuses.
-- Bosses, raids and other floors drop neither. (Card accessories were removed on 2026-10-23: per-card
-- battle bonuses are traits now, Traits.luau.)
-- Shared so the BAG, the tower screens and the server agree on every number. Adding one is one entry.

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

-- Artifacts: always on once owned (Gear.TowerArtifacts[id] = true). Bonuses use the relic Kinds.
export type TowerArtifact = { Id: string, Name: string, Icon: string, Source: string, Bonuses: { [string]: number } }

Items.TowerArtifacts = {
	{
		Id = "hundredcrown",
		Name = "Crown of the Hundred Floors",
		Icon = "🏯",
		Source = "Hundred-Floor Pagoda, floor 100",
		Bonuses = { Luck = 0.5, RollSpeed = 0.1, Border = 0.25 },
	},
} :: { TowerArtifact }

Items.TowerArtifactById = {} :: { [string]: TowerArtifact }
for _, artifact in Items.TowerArtifacts do
	Items.TowerArtifactById[artifact.Id] = artifact
end

-- Relic drops -------------------------------------------------------------------------------------
-- Only Infinite Tower wins on floor RelicFloor and up roll for a relic, at RelicChance. Its rarity mix
-- improves with the floor's score D (floor x 0.25, Tower.DPerFloor).

Items.RelicFloor = 50
Items.RelicChance = 0.001 -- 0.1% a win

Items.ItemRarities = { "Rare", "Epic", "Legendary", "Mythic" }

-- The relic chance for an Infinite Tower win on `floor` (0 below RelicFloor).
function Items.RelicChanceAt(floor: number): number
	return if floor >= Items.RelicFloor then Items.RelicChance else 0
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

-- What an Infinite Tower win on `floor` drops: { Artifacts = { relicId = 1 }? }. `rng` is a Random.
function Items.RollDrops(floor: number, rng: Random): { Artifacts: { [string]: number }? }
	local drops = {}
	local d = floor * 0.25
	if rng:NextNumber() < Items.RelicChanceAt(floor) then
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
	Worn: { string }, -- relic ids being worn (up to ArtifactSlots)
	TowerArtifacts: { [string]: boolean }?, -- artifacts owned (always on)
}

function Items.Empty(): Gear
	return { Artifacts = {}, Worn = {}, TowerArtifacts = {} }
end

-- An artifact's bonus at a level.
function Items.ArtifactValue(artifact: Artifact, level: number): number
	return artifact.Amount + artifact.PerLevel * (math.clamp(level, 1, Items.MaxLevel) - 1)
end

-- What the worn relics and the owned artifacts add for a Kind (Luck, RollSpeed, Border, ShardGain, XPGain).
function Items.ArtifactBonus(gear: Gear?, kind: string): number
	if gear == nil then
		return 0
	end
	local total = 0
	for id, owned in (gear.TowerArtifacts or {}) :: { [string]: boolean } do
		local artifact = Items.TowerArtifactById[id]
		if owned and artifact then
			total += artifact.Bonuses[kind] or 0
		end
	end
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
	ShardGain = "Trait Shards",
	XPGain = "XP",
}

local function percent(x: number): string
	return `{math.floor(x * 100 + 0.5)}%`
end

local function bonusText(kind: string, value: number): string
	if kind == "Luck" then
		return string.format("+%.2fx luck", value)
	end
	return `+{percent(value)} {KIND_TEXT[kind] or kind}`
end

function Items.ArtifactText(artifact: Artifact, level: number): string
	return bonusText(artifact.Kind, Items.ArtifactValue(artifact, level))
end

-- "+0.50x luck · +10% faster rolls · +25% border chance" for an artifact (fixed order).
function Items.TowerArtifactText(artifact: TowerArtifact): string
	local parts = {}
	for _, kind in { "Luck", "RollSpeed", "Border", "ShardGain", "XPGain" } do
		local value = artifact.Bonuses[kind]
		if value then
			table.insert(parts, bonusText(kind, value))
		end
	end
	return table.concat(parts, " · ")
end

return Items
