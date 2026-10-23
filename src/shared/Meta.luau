--!strict
-- Long-term progression, shared so the screens show exactly what the server pays:
-- potions, Shard upgrades, Index completion rewards, daily streak, playtime gifts, roll milestones,
-- daily quests, levels and stat points.
-- Everything here is earned in game; nothing is sold for Robux (see CLAUDE.md before changing that).

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)
local Packs = require(script.Parent.Packs)

export type Bundle = {
	Shards: number?,
	Potions: { [string]: number }?,
	Artifacts: { [string]: number }?, -- Items.luau ids
	Packs: { [string]: number }?, -- Roll Packs (Packs.luau ids)
}

export type Potion = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Kind: string, -- "Luck" (multiplies luck) | "Speed" (shorter roll cooldown)
	Amount: number, -- luck multiplier, or cooldown cut (0.3 = 30% faster)
	Seconds: number,
	Price: number, -- Shards in the shop
	Text: string,
}

export type Upgrade = {
	Id: string,
	Name: string,
	Icon: string,
	Text: string,
	Step: number,
	Costs: { number }, -- cost of each level; its length is the max level
}

export type Gift = { Minutes: number, Reward: Bundle }
export type Milestone = { Rolls: number, Reward: Bundle }
export type IndexReward = { Luck: number, Reward: Bundle }
export type Quest = { Id: string, Text: string, Stat: string, Goal: number, Reward: Bundle }

local Meta = {}

Meta.Potions = {
	{
		Id = "luck",
		Name = "Luck Potion",
		Icon = "🍀",
		Color = Color3.fromRGB(86, 214, 138),
		Kind = "Luck",
		Amount = 1.5,
		Seconds = 300,
		Price = 40,
		Text = "x1.5 luck for 5 min",
	},
	{
		Id = "speed",
		Name = "Speed Potion",
		Icon = "⚡",
		Color = Color3.fromRGB(80, 180, 255),
		Kind = "Speed",
		Amount = 0.3,
		Seconds = 300,
		Price = 40,
		Text = "Rolls 30% faster for 5 min",
	},
	{
		Id = "superluck",
		Name = "Super Luck Potion",
		Icon = "🌟",
		Color = Color3.fromRGB(255, 196, 46),
		Kind = "Luck",
		Amount = 2,
		Seconds = 300,
		Price = 150,
		Text = "x2 luck for 5 min",
	},
	{
		Id = "mythic",
		Name = "Mythic Elixir",
		Icon = "🔮",
		Color = Color3.fromRGB(255, 58, 92),
		Kind = "Luck",
		Amount = 3,
		Seconds = 120,
		Price = 600,
		Text = "x3 luck for 2 min",
	},
} :: { Potion }

Meta.PotionById = {} :: { [string]: Potion }
for _, potion in Meta.Potions do
	Meta.PotionById[potion.Id] = potion
end

-- Using a potion that is already running adds to its time, up to this much.
Meta.MaxPotionSeconds = 3600

Meta.Upgrades = {
	{
		Id = "RollSpeed",
		Name = "Quick Hands",
		Icon = "⏱️",
		Text = "-0.1 s roll cooldown per level",
		Step = 0.1,
		Costs = { 60, 180, 450, 1100 }, -- 1.2 s down to 0.8 s, as in the design doc
	},
	{
		Id = "Luck",
		Name = "Lucky Charm",
		Icon = "🍀",
		Text = "+0.05x base luck per level",
		Step = 0.05,
		Costs = { 40, 70, 110, 160, 230, 320, 440, 600, 800, 1100 },
	},
} :: { Upgrade }

Meta.UpgradeById = {} :: { [string]: Upgrade }
for _, upgrade in Meta.Upgrades do
	Meta.UpgradeById[upgrade.Id] = upgrade
end

-- Finding every card of a rarity pays permanent luck plus a bundle, once.
Meta.IndexRewards = {
	Common = { Luck = 0.02, Reward = { Shards = 25, Potions = { luck = 1 } } },
	Uncommon = { Luck = 0.03, Reward = { Shards = 50, Potions = { luck = 2 } } },
	Rare = { Luck = 0.05, Reward = { Shards = 100, Potions = { speed = 2, luck = 2 } } },
	Epic = { Luck = 0.05, Reward = { Shards = 200, Potions = { superluck = 1 } } },
	Legendary = { Luck = 0.1, Reward = { Shards = 400, Potions = { superluck = 2 } } },
	Mythic = { Luck = 0.1, Reward = { Shards = 800, Potions = { mythic = 1 } } },
	Secret = { Luck = 0.15, Reward = { Shards = 2000, Potions = { mythic = 3 } } },
} :: { [string]: IndexReward }

-- Daily login streak: claim once per day; missing a day restarts at day 1; day 7 loops back.
Meta.Daily = {
	{ Shards = 20 },
	{ Potions = { luck = 1 } },
	{ Shards = 50, Packs = { ["10"] = 1 } },
	{ Potions = { speed = 2 } },
	{ Shards = 100, Potions = { luck = 1 } },
	{ Potions = { superluck = 1 } },
	{ Shards = 250, Potions = { mythic = 1 }, Packs = { ["10"] = 3 } },
} :: { Bundle }

-- Free gifts for time spent in this server session.
Meta.Playtime = {
	{ Minutes = 3, Reward = { Shards = 10 } },
	{ Minutes = 6, Reward = { Potions = { luck = 1 } } },
	{ Minutes = 10, Reward = { Shards = 25 } },
	{ Minutes = 15, Reward = { Potions = { speed = 1 } } },
	{ Minutes = 25, Reward = { Shards = 60, Potions = { luck = 1 } } },
	{ Minutes = 40, Reward = { Potions = { superluck = 1 } } },
	{ Minutes = 60, Reward = { Shards = 150, Potions = { superluck = 1 } } },
	{ Minutes = 90, Reward = { Potions = { mythic = 1 } } },
	{ Minutes = 120, Reward = { Shards = 400, Potions = { superluck = 2 } } },
	{ Minutes = 150, Reward = { Shards = 600, Potions = { mythic = 1 } } },
	{ Minutes = 180, Reward = { Shards = 1200, Potions = { mythic = 2 } } },
} :: { Gift }

-- Lifetime roll milestones.
Meta.Milestones = {
	{ Rolls = 50, Reward = { Shards = 20 } },
	{ Rolls = 100, Reward = { Potions = { luck = 2 } } },
	{ Rolls = 250, Reward = { Shards = 60, Potions = { speed = 2 } } },
	{ Rolls = 500, Reward = { Potions = { superluck = 1 }, Packs = { ["10"] = 2 } } },
	{ Rolls = 1000, Reward = { Shards = 200, Potions = { superluck = 1 } } },
	{ Rolls = 2500, Reward = { Potions = { mythic = 1 }, Packs = { ["100"] = 1 } } },
	{ Rolls = 5000, Reward = { Shards = 600, Potions = { mythic = 1 } } },
	{ Rolls = 10000, Reward = { Shards = 1500, Potions = { mythic = 2 } } },
	{ Rolls = 25000, Reward = { Shards = 4000, Potions = { mythic = 4 }, Packs = { ["1000"] = 1 } } },
} :: { Milestone }

-- Daily quests: each day every player gets QuestsPerDay of these, picked from the day and their user
-- id (Meta.QuestsFor), so server and client agree without saving the pick. Stat is what the server
-- counts (MetaService.Track): Rolls, EpicPulls (Epic or better), BossWins, HardWins (Hard or
-- Nightmare), Fusions, Gifts (playtime gifts claimed), Potions (potions used).
Meta.Quests = {
	{ Id = "roll50", Text = "Roll 50 times", Stat = "Rolls", Goal = 50, Reward = { Shards = 30 } },
	{ Id = "roll200", Text = "Roll 200 times", Stat = "Rolls", Goal = 200, Reward = { Shards = 60, Potions = { luck = 1 } } },
	{ Id = "epic", Text = "Pull an Epic or better", Stat = "EpicPulls", Goal = 1, Reward = { Shards = 50 } },
	{ Id = "boss1", Text = "Beat any boss", Stat = "BossWins", Goal = 1, Reward = { Shards = 40 } },
	{ Id = "boss3", Text = "Beat 3 bosses", Stat = "BossWins", Goal = 3, Reward = { Shards = 40, Potions = { speed = 1 } } },
	{ Id = "hard", Text = "Beat a boss on Hard or Nightmare", Stat = "HardWins", Goal = 1, Reward = { Potions = { superluck = 1 } } },
	{ Id = "fuse", Text = "Fuse a card", Stat = "Fusions", Goal = 1, Reward = { Shards = 80 } },
	{ Id = "gifts", Text = "Claim 2 playtime gifts", Stat = "Gifts", Goal = 2, Reward = { Shards = 25 } },
	{ Id = "potion", Text = "Use a potion", Stat = "Potions", Goal = 1, Reward = { Shards = 20 } },
	{ Id = "tower", Text = "Climb 2 Infinite Tower floors", Stat = "TowerFloors", Goal = 2, Reward = { Shards = 50 } },
	{ Id = "raid", Text = "Fight 2 raid runs", Stat = "RaidRuns", Goal = 2, Reward = { Shards = 60, Potions = { luck = 1 } } },
} :: { Quest }

Meta.QuestById = {} :: { [string]: Quest }
for _, quest in Meta.Quests do
	Meta.QuestById[quest.Id] = quest
end

Meta.QuestsPerDay = 3

-- Today's quest ids for a player (a small seeded shuffle, the same everywhere).
function Meta.QuestsFor(day: number, userId: number): { string }
	local seed = (day * 7919 + math.abs(userId) % 1000003 * 104729) % 2147483647
	local pool = {}
	for i = 1, #Meta.Quests do
		pool[i] = i
	end
	local picked = {}
	for _ = 1, math.min(Meta.QuestsPerDay, #pool) do
		seed = (seed * 48271 + 11) % 2147483647
		local index = seed % #pool + 1
		table.insert(picked, Meta.Quests[pool[index]].Id)
		table.remove(pool, index)
	end
	return picked
end

-- Stat points ------------------------------------------------------------------------------------
-- Every level past 1 gives one point (Meta.StatPoints) to put into one of these, up to its Max.
-- Per is what one point adds. Points can be taken back with a Shard reset (Meta.StatResetCost).

export type Stat = { Id: string, Name: string, Icon: string, Color: Color3, Per: number, Max: number, Text: string }

Meta.Stats = {
	{ Id = "Luck", Name = "Luck", Icon = "🍀", Color = Color3.fromRGB(86, 214, 138), Per = 0.02, Max = 40, Text = "+0.02x base luck" },
	{ Id = "RollSpeed", Name = "Roll Speed", Icon = "⚡", Color = Color3.fromRGB(80, 180, 255), Per = 0.01, Max = 30, Text = "-1% roll cooldown" },
	{ Id = "Border", Name = "Border Chance", Icon = "🌈", Color = Color3.fromRGB(255, 120, 220), Per = 0.03, Max = 30, Text = "+3% Gold / Rainbow / Secret border chance" },
	{ Id = "ShardGain", Name = "Shard Gain", Icon = "💎", Color = Color3.fromRGB(196, 140, 255), Per = 0.03, Max = 30, Text = "+3% Shards from everything" },
	{ Id = "XPGain", Name = "XP Gain", Icon = "⭐", Color = Color3.fromRGB(255, 196, 46), Per = 0.03, Max = 30, Text = "+3% XP from everything" },
} :: { Stat }

Meta.StatById = {} :: { [string]: Stat }
for _, stat in Meta.Stats do
	Meta.StatById[stat.Id] = stat
end

-- Points earned at a level (one per level past 1).
function Meta.StatPoints(level: number): number
	return math.max(0, (level or 1) - 1)
end

function Meta.StatsSpent(stats: { [string]: number }?): number
	local spent = 0
	for _, value in stats or {} do
		spent += value
	end
	return spent
end

-- What a stat adds: points x Per (0 when none).
function Meta.StatBonus(stats: { [string]: number }?, id: string): number
	local stat = Meta.StatById[id]
	return if stat and stats then (stats[id] or 0) * stat.Per else 0
end

-- Stat points plus worn artifacts (Items.luau) for one bonus id: Luck, RollSpeed, Border, ShardGain, XPGain.
function Meta.Bonus(stats: { [string]: number }?, gear: Items.Gear?, id: string): number
	return Meta.StatBonus(stats, id) + Items.ArtifactBonus(gear, id)
end

-- Taking every point back costs Shards per point spent.
Meta.StatResetPerPoint = 25
function Meta.StatResetCost(stats: { [string]: number }?): number
	return Meta.StatsSpent(stats) * Meta.StatResetPerPoint
end

-- Player level ---------------------------------------------------------------------------------
-- XP comes from everything you do; each level-up pays its reward at once (MetaService.AddXP).

Meta.XP = {
	Roll = 2, -- every roll (Roll, Quick, Auto, boss reward rolls)
	NewCard = 10, -- on top, for a card you didn't have
	BossWinPerD = 30, -- x the fight's difficulty score D
	Quest = 60, -- per daily quest claimed
	Fusion = 120,
	Minute = 6, -- every minute in the game
}
Meta.MaxLevel = 100
Meta.LevelLuck = 0.02 -- permanent base luck for every 10 levels

-- XP from `level` to the next (80 at level 1, about 1,800 at 10, 15,700 at 50).
function Meta.XPToNext(level: number): number
	return math.floor(80 * level ^ 1.35 / 10 + 0.5) * 10
end

-- What reaching `level` pays: Shards every level, potions every 5th, better ones at 10 and 25.
function Meta.LevelReward(level: number): Bundle
	local potions: { [string]: number }? = nil
	if level % 25 == 0 then
		potions = { mythic = 1 }
	elseif level % 10 == 0 then
		potions = { superluck = 1 }
	elseif level % 5 == 0 then
		potions = { luck = 2 }
	end
	return { Shards = 15 + level * 5, Potions = potions }
end

-- Server events ---------------------------------------------------------------------------------
-- Every EventEvery seconds an event runs for EventSeconds, the same on every server (it follows
-- the clock), in this order. Everyone in the game gets it.

export type GameEvent = { Id: string, Name: string, Text: string, Icon: string, Color: Color3, Luck: number?, Speed: number?, XP: number? }

Meta.Events = {
	{ Id = "luck", Name = "LUCKY STORM", Text = "2x luck for everyone", Icon = "🍀", Color = Color3.fromRGB(86, 214, 138), Luck = 2 },
	{ Id = "rush", Name = "ROLL RUSH", Text = "Rolls 40% faster", Icon = "⚡", Color = Color3.fromRGB(80, 180, 255), Speed = 0.4 },
	{ Id = "xp", Name = "DOUBLE XP", Text = "2x XP from everything", Icon = "⭐", Color = Color3.fromRGB(255, 196, 46), XP = 2 },
} :: { GameEvent }

Meta.EventById = {} :: { [string]: GameEvent }
for _, event in Meta.Events do
	Meta.EventById[event.Id] = event
end

Meta.EventEvery = 15 * 60
Meta.EventSeconds = 5 * 60

-- The event running at server time `t` (nil if none), seconds left on it, and seconds until the next
-- one starts. `override` = { Id, Ends } forces one (test tools).
function Meta.EventAt(t: number, override: { Id: string, Ends: number }?): (GameEvent?, number, number)
	if override and override.Ends > t and Meta.EventById[override.Id] then
		return Meta.EventById[override.Id], override.Ends - t, 0
	end
	local cycle = math.floor(t / Meta.EventEvery)
	local into = t - cycle * Meta.EventEvery
	local startsAt = Meta.EventEvery - Meta.EventSeconds -- each event closes its cycle
	if into >= startsAt then
		return Meta.Events[cycle % #Meta.Events + 1], Meta.EventEvery - into, 0
	end
	return nil, 0, startsAt - into
end

-- Lucky Wheel -------------------------------------------------------------------------------------
-- A free spin for every SpinEvery seconds in the game (banked up to MaxSpins). Every prize and its
-- chance is shown on the wheel. Nothing about it is sold.

export type Prize = { Label: string, Weight: number, Reward: Bundle, Color: Color3 }

Meta.Wheel = {
	SpinEvery = 20 * 60,
	MaxSpins = 5,
	Prizes = {
		{ Label = "💎50", Weight = 28, Reward = { Shards = 50 }, Color = Color3.fromRGB(150, 110, 255) },
		{ Label = "🍀x2", Weight = 18, Reward = { Potions = { luck = 2 } }, Color = Color3.fromRGB(86, 214, 138) },
		{ Label = "💎150", Weight = 15, Reward = { Shards = 150 }, Color = Color3.fromRGB(176, 92, 255) },
		{ Label = "⚡x2", Weight = 12, Reward = { Potions = { speed = 2 } }, Color = Color3.fromRGB(80, 180, 255) },
		{ Label = "🌟x1", Weight = 10, Reward = { Potions = { superluck = 1 } }, Color = Color3.fromRGB(255, 196, 46) },
		{ Label = "💎500", Weight = 8, Reward = { Shards = 500 }, Color = Color3.fromRGB(220, 90, 255) },
		{ Label = "🔮x1", Weight = 6, Reward = { Potions = { mythic = 1 } }, Color = Color3.fromRGB(255, 80, 110) },
		{ Label = "JACKPOT", Weight = 3, Reward = { Shards = 2000, Potions = { mythic = 2 } }, Color = Color3.fromRGB(255, 220, 60) },
	} :: { Prize },
}

function Meta.WheelTotalWeight(): number
	local total = 0
	for _, prize in Meta.Wheel.Prizes do
		total += prize.Weight
	end
	return total
end

-- Which prize a roll in [0, 1) lands on.
function Meta.WheelPick(roll: number): number
	local target = roll * Meta.WheelTotalWeight()
	for i, prize in Meta.Wheel.Prizes do
		target -= prize.Weight
		if target < 0 then
			return i
		end
	end
	return #Meta.Wheel.Prizes
end

-- Luck and speed -----------------------------------------------------------------------------

-- 1x, plus Lucky Charm levels, plus every claimed Index reward, plus Luck stat points and worn luck
-- artifacts, plus every 10 levels.
function Meta.BaseLuck(
	upgrades: { [string]: number },
	indexClaimed: { [string]: boolean },
	stats: { [string]: number }?,
	level: number?,
	gear: Items.Gear?
): number
	local luck = 1
		+ (upgrades.Luck or 0) * Meta.UpgradeById.Luck.Step
		+ Meta.Bonus(stats, gear, "Luck")
		+ math.floor((level or 1) / 10) * Meta.LevelLuck
	for rarity, claimed in indexClaimed do
		local reward = Meta.IndexRewards[rarity]
		if claimed and reward then
			luck += reward.Luck
		end
	end
	return luck
end

-- The strongest running luck potion (potions don't multiply each other).
function Meta.PotionLuck(active: { [string]: number }): number
	local best = 1
	for id, seconds in active do
		local potion = Meta.PotionById[id]
		if potion and potion.Kind == "Luck" and seconds > 0 then
			best = math.max(best, potion.Amount)
		end
	end
	return best
end

-- Base x potion x the running event's luck (if any), under the cap.
function Meta.TotalLuck(base: number, potionLuck: number, eventLuck: number?): number
	return math.min(Config.Roll.LuckCap, base * potionLuck * (eventLuck or 1))
end

function Meta.Cooldown(
	upgrades: { [string]: number },
	active: { [string]: number },
	eventSpeed: number?,
	stats: { [string]: number }?,
	gear: Items.Gear?
): number
	local cooldown = Config.Roll.Cooldown - (upgrades.RollSpeed or 0) * Meta.UpgradeById.RollSpeed.Step
	cooldown *= 1 - math.min(0.6, Meta.Bonus(stats, gear, "RollSpeed"))
	for id, seconds in active do
		local potion = Meta.PotionById[id]
		if potion and potion.Kind == "Speed" and seconds > 0 then
			cooldown *= 1 - potion.Amount
		end
	end
	cooldown *= 1 - (eventSpeed or 0)
	return math.max(0.4, math.floor(cooldown * 100 + 0.5) / 100)
end

-- Next level's cost, or nil at max level.
function Meta.UpgradeCost(id: string, level: number): number?
	local upgrade = Meta.UpgradeById[id]
	if upgrade == nil then
		return nil
	end
	return upgrade.Costs[level + 1]
end

-- Daily streak -------------------------------------------------------------------------------

function Meta.DayNumber(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- Whether today's reward can be claimed, and which streak day (1-7) it would be.
function Meta.DailyStatus(daily: { Day: number, Streak: number }, today: number): (boolean, number)
	if daily.Day == today then
		return false, daily.Streak
	end
	if daily.Day == today - 1 then
		return true, daily.Streak % #Meta.Daily + 1
	end
	return true, 1
end

-- "+25 Shards · 🍀x1" for labels.
function Meta.Describe(bundle: Bundle): string
	local parts = {}
	if bundle.Shards and bundle.Shards > 0 then
		table.insert(parts, `💎{bundle.Shards}`)
	end
	if bundle.Potions then
		for _, potion in Meta.Potions do
			local count = bundle.Potions[potion.Id]
			if count and count > 0 then
				table.insert(parts, `{potion.Icon}x{count}`)
			end
		end
	end
	for id in bundle.Artifacts or {} do
		local artifact = Items.ArtifactById[id]
		if artifact then
			table.insert(parts, `{artifact.Icon} {artifact.Name}`)
		end
	end
	local packs = Packs.Describe(bundle.Packs)
	if packs ~= "" then
		table.insert(parts, packs)
	end
	return table.concat(parts, "  ")
end

return Meta
