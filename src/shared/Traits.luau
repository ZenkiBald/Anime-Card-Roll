--!strict
-- Card traits: rolled at Kenshin the Trait Master in town (or from the Index card detail), never on
-- pulls: a fresh card has no trait. A roll costs Trait Shards (RollCost); the player sees the new trait
-- and chooses KEEP OLD or APPLY NEW, so a bad roll never downgrades a card. Pure luck: the tier odds
-- below, the same for everyone, shown in the ODDS panel. A card that reaches Awakening node 4
-- (Awaken.luau) opens a second trait slot; LOCK & ROLL (LockCost) keeps one slot and rolls the other
-- twice, so the player picks the better of two. AUTO ROLL rolls one slot again and again (RollCost each,
-- up to AutoMax a tap) until it lands one of the traits the player ticked, which it applies; with no
-- hit the old trait stays.
-- Traits are battle-only buffs (speed, crits, guard, a head start on the Ultimate) applied as permanent
-- unit buffs in BattleEngine: they never add ATK or HP, so Deck Power and "rarity always wins" stay put.
-- Saved as Cards[id].Trait (slot 1), Cards[id].Trait2 (slot 2) and Cards[id].Pending (an unchosen roll).
-- A new trait is one entry in Traits.List.

local Traits = {}

export type Effect = { Stat: string, Amount: number } -- SPD | Crit | CritDamage | Guard | StartEnergy
export type Trait = { Id: string, Name: string, Icon: string, Tier: string, Effects: { Effect } }

-- Tiers (they reuse the card rarity colours) and the chance a pull's trait is of that tier.
Traits.Tiers = {
	{ Tier = "Rare", Chance = 0.75 },
	{ Tier = "Epic", Chance = 0.2 },
	{ Tier = "Legendary", Chance = 0.045 },
	{ Tier = "Mythic", Chance = 0.005 },
}

Traits.List = {
	{ Id = "swift", Name = "Swift", Icon = "💨", Tier = "Rare", Effects = { { Stat = "SPD", Amount = 0.04 } } },
	{ Id = "keen", Name = "Keen", Icon = "🎯", Tier = "Rare", Effects = { { Stat = "Crit", Amount = 0.04 } } },
	{ Id = "sturdy", Name = "Sturdy", Icon = "🪨", Tier = "Rare", Effects = { { Stat = "Guard", Amount = 0.05 } } },
	{ Id = "eager", Name = "Eager", Icon = "🔋", Tier = "Rare", Effects = { { Stat = "StartEnergy", Amount = 0.15 } } },
	{ Id = "fleet", Name = "Fleet", Icon = "🪶", Tier = "Epic", Effects = { { Stat = "SPD", Amount = 0.08 } } },
	{ Id = "sharp", Name = "Sharp", Icon = "🗡️", Tier = "Epic", Effects = { { Stat = "CritDamage", Amount = 0.2 } } },
	{ Id = "stalwart", Name = "Stalwart", Icon = "🛡️", Tier = "Epic", Effects = { { Stat = "Guard", Amount = 0.1 } } },
	{ Id = "charged", Name = "Charged", Icon = "⚡", Tier = "Epic", Effects = { { Stat = "StartEnergy", Amount = 0.3 } } },
	{
		Id = "tempest",
		Name = "Tempest",
		Icon = "🌪️",
		Tier = "Legendary",
		Effects = { { Stat = "SPD", Amount = 0.1 }, { Stat = "StartEnergy", Amount = 0.2 } },
	},
	{
		Id = "assassin",
		Name = "Assassin",
		Icon = "🥷",
		Tier = "Legendary",
		Effects = { { Stat = "Crit", Amount = 0.1 }, { Stat = "CritDamage", Amount = 0.25 } },
	},
	{
		Id = "bulwark",
		Name = "Bulwark",
		Icon = "🏯",
		Tier = "Legendary",
		Effects = { { Stat = "Guard", Amount = 0.15 }, { Stat = "SPD", Amount = 0.04 } },
	},
	{
		Id = "godspeed",
		Name = "Godspeed",
		Icon = "⚜️",
		Tier = "Mythic",
		Effects = { { Stat = "SPD", Amount = 0.15 }, { Stat = "StartEnergy", Amount = 0.4 } },
	},
	{
		Id = "executioner",
		Name = "Executioner",
		Icon = "💀",
		Tier = "Mythic",
		Effects = { { Stat = "Crit", Amount = 0.15 }, { Stat = "CritDamage", Amount = 0.4 } },
	},
} :: { Trait }

Traits.RollCost = 10 -- Trait Shards for one roll at the Trait Master
Traits.LockCost = 25 -- LOCK & ROLL: keep one slot, roll the other twice and pick
Traits.Slot2Node = 4 -- Awakening node that opens trait slot 2
Traits.BigTier = 3 -- Legendary and up: the roll button pauses and the screen flashes
Traits.AutoMax = 100 -- AUTO ROLL: at most this many rolls (RollCost each) per tap

Traits.ById = {} :: { [string]: Trait }
local tierIndex: { [string]: number } = {}
local byTier: { [string]: { Trait } } = {}
for i, tier in Traits.Tiers do
	tierIndex[tier.Tier] = i
	byTier[tier.Tier] = {}
end
for _, trait in Traits.List do
	Traits.ById[trait.Id] = trait
	table.insert(byTier[trait.Tier], trait)
end

function Traits.Get(id: string?): Trait?
	return if id then Traits.ById[id] else nil
end

-- 1 = Rare ... 4 = Mythic; 0 for no trait.
function Traits.TierIndex(id: string?): number
	local trait = Traits.Get(id)
	return if trait then tierIndex[trait.Tier] else 0
end

-- True when trait `a` is better (a higher tier) than `b`.
function Traits.Better(a: string?, b: string?): boolean
	return Traits.TierIndex(a) > Traits.TierIndex(b)
end

-- A pull's trait from two random numbers in [0, 1): the tier, then a trait of that tier.
function Traits.Pick(tierRoll: number, pickRoll: number): string
	local tier = Traits.Tiers[1].Tier
	for _, t in Traits.Tiers do
		tierRoll -= t.Chance
		if tierRoll < 0 then
			tier = t.Tier
			break
		end
	end
	local pool = byTier[tier]
	return pool[math.clamp(math.floor(pickRoll * #pool) + 1, 1, #pool)].Id
end

-- Each trait's chance per pull (for the odds panel; sums to 1).
function Traits.Chances(): { [string]: number }
	local chances = {}
	for _, t in Traits.Tiers do
		local pool = byTier[t.Tier]
		for _, trait in pool do
			chances[trait.Id] = t.Chance / #pool
		end
	end
	return chances
end

-- The battle effects of a card's trait (empty when none).
function Traits.Effects(id: string?): { Effect }
	local trait = Traits.Get(id)
	return if trait then trait.Effects else {}
end

-- Both slots' effects together (slot 2 only counts once it's open).
function Traits.SlotEffects(slot1: string?, slot2: string?): { Effect }
	local list = table.clone(Traits.Effects(slot1))
	for _, effect in Traits.Effects(slot2) do
		table.insert(list, effect)
	end
	return list
end

local STAT_TEXT = {
	SPD = "speed",
	Crit = "crit chance",
	CritDamage = "crit damage",
	Guard = "less damage taken",
	StartEnergy = "Ultimate charge at the start",
}

-- "+5% speed, +15% Ultimate charge at the start".
function Traits.Text(id: string?): string
	local trait = Traits.Get(id)
	if trait == nil then
		return ""
	end
	local parts = {}
	for _, effect in trait.Effects do
		table.insert(parts, `+{math.floor(effect.Amount * 100 + 0.5)}% {STAT_TEXT[effect.Stat] or effect.Stat}`)
	end
	return table.concat(parts, ", ")
end

-- AUTO ROLL: rolls with `pick` until a trait in `targets` (id -> true) lands, at most `maxRolls` times.
-- Returns every trait rolled, in order, and the hit (nil when none landed).
function Traits.AutoRun(pick: () -> string, targets: { [string]: boolean }, maxRolls: number): ({ string }, string?)
	local rolled = {}
	for _ = 1, math.max(0, math.floor(maxRolls)) do
		local id = pick()
		table.insert(rolled, id)
		if targets[id] then
			return rolled, id
		end
	end
	return rolled, nil
end

return Traits
