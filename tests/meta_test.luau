-- Long-term progression math: luck sources, potion stacking, cooldowns, daily streak, costs.
local Config = MODULES.Config
local Cards = MODULES.Cards
local Rarity = MODULES.Rarity
local Meta = MODULES.Meta
local Rewards = MODULES.Rewards

-- Artifacts (Items.luau): drop odds grow with D, rarities sum to 1, worn artifacts add bonuses.
local Items = MODULES.Items
check(Items.ArtifactChance(12) > Items.ArtifactChance(1), "harder fights drop artifacts more often")
for _, d in { 1, 6, 12 } do
	local sum = 0
	for _, chance in Items.RarityChances(d) do
		sum += chance
	end
	check(math.abs(sum - 1) < 1e-9, `gear rarity chances add up to 100% at D {d}`)
end
check(Items.RarityChances(1).Mythic == 0 and Items.RarityChances(12).Mythic > 0, "Mythic gear only drops from the hard fights")
check(Items.RarityChances(12).Legendary > Items.RarityChances(1).Legendary, "harder fights drop rarer gear")
local gear = Items.Empty()
gear.Artifacts = { clover = 3, voideye = 1, coin = 1 }
gear.Worn = { "clover", "voideye" }
check(math.abs(Items.ArtifactBonus(gear, "Luck") - (0.05 + 0.02 * 2 + 0.5)) < 1e-9, "worn luck artifacts add up, with levels")
check(Items.ArtifactBonus(gear, "ShardGain") == 0, "an artifact in the bag (not worn) does nothing")
check(math.abs(Meta.BaseLuck({}, {}, nil, 1, gear) - (1 + 0.59)) < 1e-9, "worn artifacts raise base luck")
check(Meta.Describe({ Artifacts = { voideye = 1 } }):find("Void Eye") ~= nil, "loot text names the artifact")
local drng = Random.new(3)
local artifactDrops = 0
for _ = 1, 40000 do
	if Items.RollDrops(6, drng).Artifacts then
		artifactDrops += 1
	end
end
check(math.abs(artifactDrops / 40000 - Items.ArtifactChance(6)) < 0.006, "artifacts drop at their listed chance")

-- Traits (Traits.luau): odds add up, rarer tiers are rarer, picks follow the odds, never ATK / HP.
local Traits = MODULES.Traits
local traitSum = 0
for _, chance in Traits.Chances() do
	traitSum += chance
end
check(math.abs(traitSum - 1) < 1e-9, "trait odds add up to 100%")
local traitsOk = true
for i = 2, #Traits.Tiers do
	traitsOk = traitsOk and Traits.Tiers[i].Chance < Traits.Tiers[i - 1].Chance
end
for _, trait in Traits.List do
	for _, effect in trait.Effects do
		traitsOk = traitsOk and effect.Stat ~= "ATK" and effect.Stat ~= "HP"
	end
	traitsOk = traitsOk and Rarity.Get(trait.Tier) ~= nil
end
check(traitsOk, "rarer trait tiers are rarer, and no trait adds ATK / HP (rarity still wins)")
check(Traits.Pick(0, 0) == Traits.List[1].Id and Traits.TierIndex(Traits.Pick(0.9999, 0)) == #Traits.Tiers, "trait picks span every tier")
check(Traits.Better("godspeed", "swift") and not Traits.Better("swift", "fleet") and Traits.Better("swift", nil), "a better trait beats a worse one or none")
local trng = Random.new(9)
local mythic = 0
for _ = 1, 200000 do
	if Traits.TierIndex(Traits.Pick(trng:NextNumber(), trng:NextNumber())) == #Traits.Tiers then
		mythic += 1
	end
end
check(math.abs(mythic / 200000 - Traits.Tiers[#Traits.Tiers].Chance) < 0.001, "Mythic traits roll at their listed chance")
check(Traits.Text("tempest"):find("speed") ~= nil, "trait text names its effects")

-- Luck sources.
check(near(Meta.BaseLuck({ Luck = 0 }, {}), 1), "base luck starts at 1x")
check(near(Meta.BaseLuck({ Luck = 10 }, {}), 1.5), "10 Lucky Charm levels give +0.5x")
local allClaimed = {}
for _, id in MODULES.Borders.Order do
	allClaimed[id] = true
end
check(near(Meta.BaseLuck({ Luck = 0 }, allClaimed), 1.75), "a full Index at every border gives +0.75x luck")
check(near(Meta.BaseLuck({ Luck = 0 }, {}, { Luck = 10 }), 1.2), "10 Luck stat points give +0.2x base luck")

-- Stat points: one per level past 1, capped per stat, and they show up where they should.
check(Meta.StatPoints(1) == 0 and Meta.StatPoints(10) == 9, "a stat point for every level past 1")
check(Meta.StatsSpent({ Luck = 3, XPGain = 2 }) == 5, "spent points add up")
local statTotal = 0
for _, stat in Meta.Stats do
	check(stat.Max > 0 and stat.Per > 0, `{stat.Id} has a cap and a step`)
	statTotal += stat.Max
end
check(statTotal > Meta.StatPoints(Meta.MaxLevel), "there are more stat slots than points, so choices matter")
check(near(Meta.Cooldown({ RollSpeed = 0 }, {}, nil, { RollSpeed = 10 }), Config.Roll.Cooldown * 0.9), "10 Roll Speed points cut the cooldown 10%")
check(Meta.StatResetCost({ Luck = 4 }) == 4 * Meta.StatResetPerPoint and Meta.StatResetCost({}) == 0, "a reset costs Shards per spent point")
check(near(Meta.PotionLuck({}), 1), "no potion: x1")
check(near(Meta.PotionLuck({ luck = 30, superluck = 10 }), 2), "luck potions don't multiply each other: the best applies")
check(near(Meta.PotionLuck({ superluck = 0 }), 1), "an expired potion does nothing")
check(near(Meta.TotalLuck(5, 6), Config.Roll.LuckCap) and Config.Roll.LuckCap == 25, "total luck is capped at 25x")

-- Cooldown.
check(near(Meta.Cooldown({ RollSpeed = 0 }, {}), Config.Roll.Cooldown), "roll cooldown starts at 1.2 s")
check(near(Meta.Cooldown({ RollSpeed = 4 }, {}), 0.8), "max Quick Hands brings it to 0.8 s (design doc)")
check(Meta.Cooldown({ RollSpeed = 4 }, { speed = 60 }) < 0.8 and Meta.Cooldown({ RollSpeed = 4 }, { speed = 60 }) >= 0.4,
	"a Speed Potion cuts it further, never below 0.4 s")

-- Upgrade costs.
check(Meta.UpgradeCost("RollSpeed", 0) == 60 and Meta.UpgradeCost("RollSpeed", 4) == nil, "upgrade costs and max level")
local rising = true
for _, upgrade in Meta.Upgrades do
	for i = 2, #upgrade.Costs do
		if upgrade.Costs[i] <= upgrade.Costs[i - 1] then
			rising = false
		end
	end
end
check(rising, "every upgrade level costs more than the last")

-- Daily streak.
local can, day = Meta.DailyStatus({ Day = 0, Streak = 0 }, 20000)
check(can and day == 1, "first daily claim is day 1")
can, day = Meta.DailyStatus({ Day = 19999, Streak = 3 }, 20000)
check(can and day == 4, "claiming the next day continues the streak")
can, day = Meta.DailyStatus({ Day = 19990, Streak = 5 }, 20000)
check(can and day == 1, "missing a day restarts the streak")
can = Meta.DailyStatus({ Day = 20000, Streak = 2 }, 20000)
check(not can, "only one daily claim per day")
can, day = Meta.DailyStatus({ Day = 19999, Streak = #Meta.Daily }, 20000)
check(can and day == 1, "after day 7 the streak loops back to day 1")

-- Reward tables only name real potions and rarities.
local function bundleOk(bundle)
	for id in bundle.Potions or {} do
		if Meta.PotionById[id] == nil then
			return false
		end
	end
	return true
end
local tablesOk = true
for _, b in Meta.Daily do
	tablesOk = tablesOk and bundleOk(b)
end
for _, g in Meta.Playtime do
	tablesOk = tablesOk and bundleOk(g.Reward)
end
for _, m in Meta.Milestones do
	tablesOk = tablesOk and bundleOk(m.Reward)
end
for _, id in MODULES.Borders.Order do
	local reward = Meta.IndexRewards[id]
	tablesOk = tablesOk and reward ~= nil and bundleOk(reward.Reward)
end
for d = 1, 9 do
	tablesOk = tablesOk and Meta.PotionById[Rewards.For(d).Potion] ~= nil and Rewards.For(d).Shards == 15 * d
end
for _, q in Meta.Quests do
	tablesOk = tablesOk and bundleOk(q.Reward) and q.Goal > 0
end
check(tablesOk, "daily / playtime / milestone / Index / quest / boss drop rewards all name real potions and rarities")

-- Daily quests: the same pick for the same day and player, all different, and they change by day.
local a, b = Meta.QuestsFor(20000, 123456), Meta.QuestsFor(20000, 123456)
local distinct = #a == Meta.QuestsPerDay and a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3]
check(distinct and table.concat(a) == table.concat(b), "daily quests: 3 different ones, the same on server and client")
local changes = false
for d = 20001, 20010 do
	changes = changes or table.concat(Meta.QuestsFor(d, 123456)) ~= table.concat(a)
end
check(changes, "daily quests change from day to day")

-- Levels: each level costs more than the last, rewards name real potions, luck every 10 levels.
local levelsOk = true
for level = 1, Meta.MaxLevel - 1 do
	if Meta.XPToNext(level + 1) <= Meta.XPToNext(level) or not bundleOk(Meta.LevelReward(level)) then
		levelsOk = false
	end
end
check(levelsOk and Meta.XPToNext(1) == 80, "level costs rise every level and rewards name real potions")
check(near(Meta.BaseLuck({}, {}, nil, 37), 1 + 3 * Meta.LevelLuck), "every 10 levels add permanent base luck")

-- Events: one runs for the last 5 minutes of every 15, in turn; the override wins.
local event, left, untilNext = Meta.EventAt(Meta.EventEvery * 1000 + 60)
check(event == nil and near(untilNext, Meta.EventEvery - Meta.EventSeconds - 60), "no event early in the cycle")
event, left = Meta.EventAt(Meta.EventEvery * 1000 + Meta.EventEvery - 30)
check(event ~= nil and near(left, 30), "an event runs at the end of the cycle")
local nextEvent = Meta.EventAt(Meta.EventEvery * 1001 + Meta.EventEvery - 30)
check(nextEvent ~= event, "events take turns")
check(Meta.EventAt(10, { Id = "xp", Ends = 20 }).Id == "xp", "a forced event overrides the schedule")
check(near(Meta.TotalLuck(4, 4, 2), Config.Roll.LuckCap), "event luck stays under the cap")
check(Meta.Cooldown({ RollSpeed = 4 }, {}, 0.4) >= 0.4, "event speed never takes rolls under 0.4 s")

-- Lucky Wheel: positive weights, real potions, and the pick covers every slice.
local wheelOk = true
for _, prize in Meta.Wheel.Prizes do
	wheelOk = wheelOk and prize.Weight > 0 and bundleOk(prize.Reward)
end
check(wheelOk, "wheel prizes have weights and name real potions")
check(Meta.WheelPick(0) == 1 and Meta.WheelPick(0.9999) == #Meta.Wheel.Prizes, "wheel picks span every prize")
check(#Meta.Daily == 7, "the daily streak is 7 days")
