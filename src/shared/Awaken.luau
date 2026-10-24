--!strict
-- Awakening: on the way to Hoshi's 100-copy border fusion, every 20 copies of a card unlock an Awakening
-- node on it, for good (the save keeps the highest node reached, Cards[id].Awaken; fusing uses the copies
-- up but never takes a node back).
--   1 (20 copies)   +10% base stats (Cards.Stat)
--   2 (40 copies)   +15% Skill and Ultimate damage (battle)
--   3 (60 copies)   the card's bonds (Elements.luau) hit for 400% instead of 300%
--   4 (80 copies)   opens trait slot 2 at the Trait Master (Traits.Slot2Node)
--   5 (100 copies)  fuse into the next border at Hoshi (4x the stats) and 25 Trait Shards, every fusion
-- Stars come first (the first 5 duplicates). Node 1's +10% keeps "the border always wins": 5 stars x node 1
-- is 1.25 x 1.1 = 1.375, far under the next border's 4x (odds_test checks).

local Awaken = {}

export type Node = { Node: number, Copies: number, Name: string, Text: string }

Awaken.Every = 20
Awaken.StatBonus = 0.1 -- node 1
Awaken.SkillBonus = 0.15 -- node 2
Awaken.BondPct = 4 -- node 3: the bond's Pct (Elements.Bonds use 3)
Awaken.FusionTraitShards = 25 -- node 5: Trait Shards per fusion

Awaken.Nodes = {
	{ Node = 1, Copies = 20, Name = "Awakened Body", Text = "+10% base stats" },
	{ Node = 2, Copies = 40, Name = "Awakened Technique", Text = "+15% Skill and Ultimate damage" },
	{ Node = 3, Copies = 60, Name = "Awakened Bond", Text = "Its bond combo hits for 400% instead of 300%" },
	{ Node = 4, Copies = 80, Name = "Awakened Soul", Text = "Opens trait slot 2 at the Trait Master" },
	{ Node = 5, Copies = 100, Name = "Border Fusion", Text = "Fuse 100 copies into the next border at Hoshi (4x stats) and 25 Trait Shards" },
} :: { Node }

-- The node a card has from its copies right now (1-4; node 5 is reached by fusing).
function Awaken.FromCopies(copies: number): number
	return math.clamp(math.floor(copies / Awaken.Every), 0, 4)
end

-- The card's node: the highest it has reached (saved), its copies now, and 5 once it has fused.
function Awaken.Level(entry: { Copies: number, Awaken: number?, Fusion: number? }?): number
	if entry == nil then
		return 0
	end
	local level = math.max(entry.Awaken or 0, Awaken.FromCopies(entry.Copies))
	if (entry.Fusion or 0) > 0 then
		level = 5
	end
	return level
end

-- The stat multiplier node 1 gives.
function Awaken.StatMultiplier(level: number?): number
	return if (level or 0) >= 1 then 1 + Awaken.StatBonus else 1
end

-- Battle effects from the node (the trait effect format, plus SkillDMG).
function Awaken.Effects(level: number?): { { Stat: string, Amount: number } }
	if (level or 0) >= 2 then
		return { { Stat = "SkillDMG", Amount = Awaken.SkillBonus } }
	end
	return {}
end

-- The next node to reach and how many copies it needs, or nil when all four are open.
function Awaken.Next(entry: { Copies: number, Awaken: number?, Fusion: number? }): Node?
	local level = Awaken.Level(entry)
	return Awaken.Nodes[level + 1]
end

return Awaken
