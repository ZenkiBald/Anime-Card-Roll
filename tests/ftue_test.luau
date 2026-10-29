-- Kenji's first-session questline (Tutorial.luau), the surge window rule (RollBoost.IsPerfect), a raid
-- leaver's share (Raid.PoolAfterLeave), and the counter-element Stagger the last quest counts.
local Tutorial = MODULES.Tutorial
local RollBoost = MODULES.RollBoost
local Raid = MODULES.Raid
local Meta = MODULES.Meta
local Packs = MODULES.Packs
local Bosses = MODULES.Bosses
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. The questline -----------------------------------------------------------------------------------
check(#Tutorial.Steps == 6, "Kenji's path has 6 quests")
local ids = {}
for i, quest in Tutorial.Steps do
	ids[quest.Id] = true
	local ok = quest.Goal > 0 and (quest.Check ~= "Flag" or quest.Flag ~= nil) and (quest.Check ~= "Clear" or quest.Fight ~= nil)
	for potion in quest.Reward.Potions or {} do
		ok = ok and Meta.PotionById[potion] ~= nil
	end
	for pack in quest.Reward.Packs or {} do
		ok = ok and Packs.ById[pack] ~= nil
	end
	check(ok, `quest {i} ({quest.Name}) is well formed and its reward exists`)
end
local count = 0
for _ in ids do
	count += 1
end
check(count == 6, "quest ids are unique")
local s = Tutorial.Steps
check(s[1].Goal == 5 and s[1].Reward.Shards == 50 and s[1].Reward.Potions.superluck == 1, "Q1: roll 5 -> 50 Shards + a Super Luck potion")
check(s[2].Goal == 8 and s[2].Reward.Packs["10"] == 1, "Q2: 4 + 4 deck -> a Roll Pack")
check(s[3].Fight == Bosses.FightKey("kurogane", "Normal") and s[3].Reward.TraitShards == 25 and s[3].Reward.Shards == 100, "Q3: Kurogane Normal -> 25 Trait Shards + 100 Shards")
check(s[4].Flag == "TraitRoll" and s[4].Reward.TraitShards == 15, "Q4: a trait roll -> 15 Trait Shards")
check(s[5].Flag == "Condense" and s[5].Reward.Packs["100"] == 1 and s[5].Supply.Count == 10, "Q5: condense -> a Big Roll Pack (topped up to 10 packs)")
check(s[6].Flag == "CounterStagger" and s[6].Reward.Shards == 500 and s[6].Title == "Apprentice", "Q6: a counter Stagger -> 500 Shards + Apprentice")

local facts = { TotalRolls = 3, DeckCards = 0, Cleared = {}, Flags = {} }
local c, g = Tutorial.Progress(1, facts)
check(c == 3 and g == 5 and not Tutorial.Ready(1, facts), "Q1 counts lifetime rolls (3/5)")
facts.TotalRolls = 40
c = Tutorial.Progress(1, facts)
check(c == 5 and Tutorial.Ready(1, facts), "progress caps at the goal and the quest is ready")
facts.DeckCards = 7
check(not Tutorial.Ready(2, facts), "Q2 needs all 8 slots")
facts.DeckCards = 8
check(Tutorial.Ready(2, facts), "a full deck finishes Q2")
check(not Tutorial.Ready(3, facts), "Q3 waits for the clear")
facts.Cleared["kurogane:Normal"] = true
check(Tutorial.Ready(3, facts), "clearing Kurogane Normal finishes Q3")
facts.Flags.Condense = true
check(not Tutorial.Ready(4, facts) and Tutorial.Ready(5, facts), "a flag noted early finishes its quest the moment it opens")
check(not Tutorial.Done(6) and Tutorial.Done(7), "the path is done after the 6th claim")
check(Tutorial.Progress(7, facts) == 0 and not Tutorial.Ready(7, facts), "nothing is open after the last quest")

-- 2. The surge window ----------------------------------------------------------------------------
local tol = 0.15
check(not RollBoost.IsPerfect(true, 0, tol) and not RollBoost.IsPerfect(true, -0.5, tol), "a tap made during the cooldown is Early: never perfect")
check(RollBoost.IsPerfect(false, 0.1, tol) and RollBoost.IsPerfect(false, -1.2, tol), "a clean tap inside the window is perfect")
check(not RollBoost.IsPerfect(false, -(RollBoost.Surge.PerfectWindow + 0.5), tol), "a late tap misses the window")
check(not RollBoost.IsPerfect(false, 0.5, tol), "a tap the server sees well before the cooldown is not perfect")

-- 3. A raid leaver's share ------------------------------------------------------------------------
check(Raid.PoolAfterLeave(1000, 200, 300, 100) == 800, "a leaver's unearned share (300 - 100) leaves the pool")
check(Raid.PoolAfterLeave(1000, 200, 300, 400) == 1000, "a leaver who out-hit their share leaves the pool as it is")
check(Raid.PoolAfterLeave(1000, 900, 300, 0) == 900, "the pool never drops below what's been dealt (the raid clears)")

-- 4. The counter Stagger ---------------------------------------------------------------------------
local owned = F.allOwned(0)
local function counterStaggers(attackId)
	local battle = Engine.new({ Units = F.units(F.deck({ attackId }, {}), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(4), Guards = {} })
	battle.Boss.Stagger = 0.999
	battle.Slot = "Basic" -- a Basic chips the Shield bar
	battle:HitEnemy(battle.ById.A1, battle.Boss, 1)
	return battle:Summary().Staggers or 0
end
check(counterStaggers("mirai") == 1, "a Stagger of any theme counts for the guide (Q6)")
check(counterStaggers("rook") == 1, "a neutral theme also completes the Stagger guide")

-- 5. Shard bundles (STORE middle section) ---------------------------------------------------------
local MonetizationConfig = MODULES.MonetizationConfig
local keys, rising = 0, true
for i, bundle in MonetizationConfig.ShardBundles do
	keys += if MonetizationConfig.BundleByKey[bundle.Key] == bundle then 1 else 0
	local before = MonetizationConfig.ShardBundles[i - 1]
	if before and (bundle.Shards <= before.Shards or bundle.Price <= before.Price) then
		rising = false
	end
end
check(keys == #MonetizationConfig.ShardBundles and keys >= 1, "every Shard bundle is found by its key")
check(rising, "bigger Shard bundles cost more and give more")
for _, quest in Tutorial.Steps do
	check(not quest.Hint:find("HUB") and not quest.Hint:find("BAG >"), `quest hint "{quest.Hint}" points at the new layout`)
end
