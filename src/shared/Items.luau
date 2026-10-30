--!strict
-- Gear, in two sets (the user's call, 2026-10-24):
--   * RELICS (Items.Artifacts in code, Gear.Artifacts in saves, shown as "Relic"): the ten wearable items.
--     They drop only from Infinite Tower wins on floor RelicFloor and up, at RelicChance a win. Wear up to
--     ArtifactSlots. Every relic adds base Luck and Border Chance by tier (2026-10-30: Rare +0.75x / +15% up
--     to the rarest Mythic +2.5x / +35%; the best three worn = +6.5x / +90%); four also keep a specialty
--     (roll speed, Trait Shards or XP) that a duplicate levels up (up to MaxLevel). Past that, or for a relic
--     without a specialty, a duplicate melts into Shards.
--   * ARTIFACTS (Items.TowerArtifacts, Gear.TowerArtifacts, shown as "Artifact"): the Pagoda's floor-100
--     crown and the Infinite Tower's floor-InfiniteArtifactFloor milestone heart. Always on, no slot;
--     several bonuses (ATK = squad ATK, applied to every Attack card in battle).
-- Bosses, raids and other floors drop neither. (Card accessories were removed on 2026-10-23: per-card
-- battle bonuses are traits now, Traits.luau.)
-- Shared so the BAG, the tower screens and the server agree on every number. Adding one is one entry.

local Items = {}

export type Artifact = {
	Id: string,
	Name: string,
	Icon: string,
	Rarity: string,
	Luck: number, -- base luck added (x), fixed
	Border: number, -- border chance added (0.15 = +15%), fixed
	Kind: string?, -- the specialty: RollSpeed | ShardGain | XPGain (fractions, 0.05 = +5%)
	Amount: number?, -- the specialty at level 1
	PerLevel: number?, -- added to the specialty for each level past 1
}

Items.ArtifactSlots = 3
Items.MaxLevel = 5

-- Rarest last: Rare 0.75x / 15%, Epic 1-1.25x / 20%, Legendary 1.5-1.75x / 20-25%, Mythic 2.25-2.5x / 30-35%.
Items.Artifacts = {
	{ Id = "clover", Name = "Four-Leaf Relic", Icon = "🍀", Rarity = "Rare", Luck = 0.75, Border = 0.15 },
	{ Id = "hourglass", Name = "Quicksand Hourglass", Icon = "⏳", Rarity = "Rare", Luck = 0.75, Border = 0.15, Kind = "RollSpeed", Amount = 0.03, PerLevel = 0.01 },
	{ Id = "coin", Name = "Merchant's Coin", Icon = "🪙", Rarity = "Rare", Luck = 0.75, Border = 0.15, Kind = "ShardGain", Amount = 0.08, PerLevel = 0.03 },
	{ Id = "tome", Name = "Sage's Tome", Icon = "📘", Rarity = "Rare", Luck = 0.75, Border = 0.15, Kind = "XPGain", Amount = 0.08, PerLevel = 0.03 },
	{ Id = "prism", Name = "Prism Shard", Icon = "🔷", Rarity = "Epic", Luck = 1, Border = 0.2 },
	{ Id = "moonstone", Name = "Moonstone", Icon = "🌙", Rarity = "Epic", Luck = 1.25, Border = 0.2 },
	{ Id = "frostsigil", Name = "Frost Sigil", Icon = "❄️", Rarity = "Legendary", Luck = 1.5, Border = 0.2, Kind = "RollSpeed", Amount = 0.08, PerLevel = 0.02 },
	{ Id = "emberheart", Name = "Ember Heart", Icon = "🔥", Rarity = "Legendary", Luck = 1.75, Border = 0.25 },
	{ Id = "stormcrown", Name = "Storm Crown", Icon = "👑", Rarity = "Mythic", Luck = 2.25, Border = 0.3 },
	{ Id = "voideye", Name = "Void Eye", Icon = "👁️", Rarity = "Mythic", Luck = 2.5, Border = 0.35 },
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
		Bonuses = { Luck = 3, Border = 0.5, ATK = 0.15 },
	},
	{
		Id = "spireheart",
		Name = "Heart of the Endless Spire",
		Icon = "🗼",
		Source = "Infinite Tower, first run to floor 100",
		Bonuses = { Luck = 2, RollSpeed = 0.15 },
	},
} :: { TowerArtifact }

-- The Infinite Tower floor whose first record clear gives the spire's artifact.
Items.InfiniteArtifactFloor = 100
Items.InfiniteArtifact = "spireheart"

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

-- A relic's specialty at a level (0 without one).
function Items.ArtifactValue(artifact: Artifact, level: number): number
	if artifact.Kind == nil then
		return 0
	end
	return (artifact.Amount or 0) + (artifact.PerLevel or 0) * (math.clamp(level, 1, Items.MaxLevel) - 1)
end

-- Does a duplicate of this relic at `level` still level it up (else it melts into Shards)?
function Items.CanLevel(artifact: Artifact, level: number): boolean
	return artifact.Kind ~= nil and level < Items.MaxLevel
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
		if artifact and level then
			if kind == "Luck" then
				total += artifact.Luck
			elseif kind == "Border" then
				total += artifact.Border
			end
			if artifact.Kind == kind then
				total += Items.ArtifactValue(artifact, level)
			end
		end
	end
	return total
end

-- "+0.25x luck", "+5% faster rolls" ...
local KIND_TEXT = {
	ATK = "squad ATK",
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
	local text = `{bonusText("Luck", artifact.Luck)} · {bonusText("Border", artifact.Border)}`
	if artifact.Kind then
		text ..= ` · {bonusText(artifact.Kind, Items.ArtifactValue(artifact, level))}`
	end
	return text
end

-- "+0.50x luck · +10% faster rolls · +25% border chance" for an artifact (fixed order).
function Items.TowerArtifactText(artifact: TowerArtifact): string
	local parts = {}
	for _, kind in { "Luck", "Border", "ATK", "RollSpeed", "ShardGain", "XPGain" } do
		local value = artifact.Bonuses[kind]
		if value then
			table.insert(parts, bonusText(kind, value))
		end
	end
	return table.concat(parts, " · ")
end

return Items
