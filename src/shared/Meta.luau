--!strict
-- Long-term progression, shared so the screens show exactly what the server pays:
-- potions, Shard upgrades, Index completion rewards, daily streak, playtime gifts, roll milestones,
-- daily quests, levels and stat points.
-- Everything here is earned in game. Robux passes and the Luck Totem live in MonetizationConfig.luau
-- (see CLAUDE.md's paid random items rule before adding anything sold that changes odds).

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)
local Packs = require(script.Parent.Packs)

export type Bundle = {
	Fragments: number?,
	Celestial: {[string]:number}?,
	Title: string?,
	Shards: number?,
	Potions: { [string]: number }?,
	Artifacts: { [string]: number }?, -- relics (Items.Artifacts ids)
	TowerArtifacts: { [string]: boolean }?, -- artifacts (Items.TowerArtifacts ids), always on
	Packs: { [string]: number }?, -- Roll Packs (Packs.luau ids)
	TraitShards: number?, -- the Trait Master's currency (Traits.RollCost per roll)
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

Meta.ShardExchange=20 -- retired general currency converts to the dedicated reroll currency
function Meta.RetireShards(bundle: Bundle): Bundle
	if not bundle.Shards or bundle.Shards<=0 then return bundle end
	local converted=table.clone(bundle)
	converted.TraitShards=(converted.TraitShards or 0)+math.ceil(bundle.Shards/Meta.ShardExchange)
	converted.Shards=nil
	return converted
end

Meta.Potions = {
	{
		Id = "luck",
		Name = "Luck Potion I",
		Icon = "🍀",
		Color = Color3.fromRGB(86, 214, 138),
		Kind = "Luck",
		Amount = 2.5,
		Seconds = 300,
		Price = 40,
		Text = "+1.5x luck for 5 min",
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
		Name = "Luck Potion II",
		Icon = "🌟",
		Color = Color3.fromRGB(255, 196, 46),
		Kind = "Luck",
		Amount = 4,
		Seconds = 600,
		Price = 150,
		Text = "+3x luck for 10 min",
	},
	{
		Id = "mythic",
		Name = "Luck Potion III",
		Icon = "🔮",
		Color = Color3.fromRGB(255, 58, 92),
		Kind = "Luck",
		Amount = 7,
		Seconds = 900,
		Price = 600,
		Text = "+6x luck for 15 min",
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

-- Finding every card (boss cards aside) at a border pays permanent luck plus a bundle, once. Keyed by
-- border id ("Normal" = Base: every card found at all).
Meta.IndexRewards = {
	Normal = { Luck = 0.05, Reward = { Shards = 200, Potions = { luck = 2 } } },
	Gold = { Luck = 0.1, Reward = { Shards = 1000, Potions = { superluck = 2 } } },
	Rainbow = { Luck = 0.2, Reward = { Shards = 5000, Potions = { mythic = 2 } } },
	Secret = { Luck = 0.4, Reward = { Shards = 25000, Potions = { mythic = 5 } } },
} :: { [string]: IndexReward }

-- Daily login streak: claim once per day; missing a day restarts at day 1; day 7 loops back.
Meta.Daily = {
	{ Shards = 20 },
	{ Potions = { luck = 1 } },
	{ Shards = 50, Packs = { ["10"] = 1 } },
	{ Potions = { speed = 2 } },
	{ Shards = 100, Potions = { luck = 1 }, TraitShards = 10 },
	{ Potions = { superluck = 1 } },
	{ Shards = 250, Potions = { mythic = 1 }, Packs = { ["10"] = 3 } },
} :: { Bundle }

-- Free gifts for time spent in this server session.
Meta.Playtime = {
	{ Minutes = 3, Reward = { Shards = 10 } },
	{ Minutes = 6, Reward = { Potions = { luck = 1 } } },
	{ Minutes = 10, Reward = { Shards = 25 } },
	{ Minutes = 15, Reward = { Potions = { speed = 1 }, TraitShards = 5 } },
	{ Minutes = 25, Reward = { Shards = 60, Potions = { luck = 1 } } },
	{ Minutes = 40, Reward = { Potions = { superluck = 1 }, TraitShards = 10 } },
	{ Minutes = 60, Reward = { Shards = 150, Potions = { superluck = 1 } } },
	{ Minutes = 90, Reward = { Potions = { mythic = 1 }, TraitShards = 15 } },
	{ Minutes = 120, Reward = { Shards = 400, Potions = { superluck = 2 } } },
	{ Minutes = 150, Reward = { Shards = 600, Potions = { mythic = 1 }, TraitShards = 25 } },
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
	{ Id = "epic", Text = "Pull a Gold border or better", Stat = "EpicPulls", Goal = 1, Reward = { Shards = 50 } },
	{ Id = "boss1", Text = "Beat any boss", Stat = "BossWins", Goal = 1, Reward = { Shards = 40 } },
	{ Id = "boss3", Text = "Beat 3 bosses", Stat = "BossWins", Goal = 3, Reward = { Shards = 40, Potions = { speed = 1 }, TraitShards = 5 } },
	{ Id = "hard", Text = "Beat a boss on Hard or Nightmare", Stat = "HardWins", Goal = 1, Reward = { Potions = { superluck = 1 } } },
	{ Id = "fuse", Text = "Fuse a card", Stat = "Fusions", Goal = 1, Reward = { Shards = 80 } },
	{ Id = "gifts", Text = "Claim 2 playtime gifts", Stat = "Gifts", Goal = 2, Reward = { Shards = 25 } },
	{ Id = "potion", Text = "Use a potion", Stat = "Potions", Goal = 1, Reward = { Shards = 20 } },
	{ Id = "tower", Text = "Climb 2 Infinite Tower floors", Stat = "TowerFloors", Goal = 2, Reward = { Shards = 50, TraitShards = 5 } },
	{ Id = "trait", Text = "Roll 3 traits at the Trait Master", Stat = "TraitRolls", Goal = 3, Reward = { TraitShards = 15 } },
	{ Id = "streak", Text = "Reach a 100-roll Momentum chain", Stat = "Momentum100", Goal = 1, Reward = { Shards = 60, TraitShards = 5 } },
	{ Id = "raid", Text = "Fight 2 raid runs", Stat = "RaidRuns", Goal = 2, Reward = { Shards = 60, Potions = { luck = 1 }, TraitShards = 10 } },
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
	{ Id = "Luck", Name = "Luck", Icon = "🍀", Color = Color3.fromRGB(86, 214, 138), Per = 0.05, Max = 40, Text = "+0.05x base luck" },
	{ Id = "RollSpeed", Name = "Roll Speed", Icon = "⚡", Color = Color3.fromRGB(80, 180, 255), Per = 0.01, Max = 30, Text = "-1% roll cooldown" },
	-- 2026-10-30: Training is the floor, relics / artifacts the endgame: Border Chance 1% a point (30% max),
	-- Luck 0.05x a point (2x max).
	{ Id = "Border", Name = "Border Chance", Icon = "🌈", Color = Color3.fromRGB(255, 120, 220), Per = 0.01, Max = 30, Text = "+1% Gold / Rainbow / Secret border chance" },
	{ Id = "ShardGain", Name = "Trait Shard Gain", Icon = "💎", Color = Color3.fromRGB(196, 140, 255), Per = 0.03, Max = 30, Text = "+3% earned Trait Shards" },
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
	for _, value in (stats or {}) :: { [string]: number } do
		spent += value
	end
	return spent
end

-- One bounded transaction for +1, a typed amount or MAX; the server decides what fits.
function Meta.StatSpend(stats: { [string]: number }, level: number, id: any, amount: any): (number, string?)
	local stat = if type(id) == "string" then Meta.StatById[id] else nil
	if not stat then return 0, "BadRequest" end
	if amount ~= "max" and (type(amount) ~= "number" or amount ~= amount or amount == math.huge
		or amount < 1 or amount % 1 ~= 0 or amount > 1000000) then return 0, "BadRequest" end
	local free = math.max(0, Meta.StatPoints(level) - Meta.StatsSpent(stats))
	local room = math.max(0, stat.Max - (stats[id] or 0))
	if room == 0 then return 0, "MaxLevel" end
	if free == 0 then return 0, "NoPoints" end
	return math.min(free, room, if amount == "max" then room else amount), nil
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
		{ Label = "🧬x20", Weight = 8, Reward = { TraitShards = 20 }, Color = Color3.fromRGB(80, 230, 200) },
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
-- artifacts, plus every 10 levels, plus `extra` (Awakening fusion luck and the Momentum chain).
function Meta.BaseLuck(
	upgrades: { [string]: number },
	indexClaimed: { [string]: boolean },
	stats: { [string]: number }?,
	level: number?,
	gear: Items.Gear?,
	extra: number?
): number
	local luck = 1
		+ (upgrades.Luck or 0) * Meta.UpgradeById.Luck.Step
		+ Meta.Bonus(stats, gear, "Luck")
		+ math.floor((level or 1) / 10) * Meta.LevelLuck
		+ (extra or 0)
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

-- Potion and sky bonuses add to earned luck; server events, Raid Luck and Totems multiply it.
function Meta.TotalLuck(base: number, potionLuck: number, eventLuck: number?, weatherLuck: number?): number
	return math.max(1,(base+math.max(0,potionLuck-1)+(weatherLuck or 0))*(eventLuck or 1))
end

-- `boost`: extra speed from the Momentum chain (0.5 = 50% faster) and the Fast Roll pass's cut.
function Meta.Cooldown(
	upgrades: { [string]: number },
	active: { [string]: number },
	eventSpeed: number?,
	stats: { [string]: number }?,
	gear: Items.Gear?,
	boost: { Momentum: number?, Pass: number? }?
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
	if boost then
		cooldown /= 1 + (boost.Momentum or 0)
		cooldown *= 1 - (boost.Pass or 0)
	end
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
	bundle=Meta.RetireShards(bundle)
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
	for id in (bundle.Artifacts or {}) :: { [string]: number } do
		local relic = Items.ArtifactById[id]
		if relic then
			table.insert(parts, `{relic.Icon} {relic.Name}`)
		end
	end
	for id in (bundle.TowerArtifacts or {}) :: { [string]: boolean } do
		local artifact = Items.TowerArtifactById[id]
		if artifact then
			table.insert(parts, `{artifact.Icon} {artifact.Name}`)
		end
	end
	if bundle.TraitShards and bundle.TraitShards > 0 then
		table.insert(parts, `🧬{bundle.TraitShards}`)
	end
	local packs = Packs.Describe(bundle.Packs)
	if bundle.Title then table.insert(parts,`Title: {bundle.Title}`) end
	if bundle.Fragments and bundle.Fragments>0 then table.insert(parts,`{bundle.Fragments} Celestial Fragments`) end
	for id,count in (bundle.Celestial or {}) :: {[string]:number} do
		local name=if id=="orb" then "Celestial Orb" elseif id=="hourglass" then "Celestial Hourglass" else "Weather Sigil"
		table.insert(parts,`{count}x {name}`)
	end
	if packs ~= "" then
		table.insert(parts, packs)
	end
	return table.concat(parts, "  ")
end

-- While you were away: time offline (since the save's LastSeen) pays a Roll Pack per PackEvery seconds and
-- ShardsPerMinute Shards a minute, counted up to CapSeconds (8 h) and only after MinSeconds (10 min) away,
-- so rejoining quickly earns nothing. Pure, so tests check it.
Meta.Offline = { MinSeconds = 600, CapSeconds = 8 * 3600, PackEvery = 1800, ShardsPerMinute = 2 }

export type OfflineReward = { Seconds: number, Shards: number, Packs: { [string]: number }? }

function Meta.OfflineReward(seconds: number): OfflineReward?
	local o = Meta.Offline
	if seconds ~= seconds or seconds < o.MinSeconds then
		return nil
	end
	local counted = math.min(seconds, o.CapSeconds)
	local packs = math.floor(counted / o.PackEvery)
	return {
		Seconds = counted,
		Shards = math.floor(counted / 60) * o.ShardsPerMinute,
		Packs = if packs > 0 then { ["10"] = packs } else nil,
	}
end

-- Earned weather supplies, alongside existing rewards. There is no weather cash shop in v1.
Meta.Daily[1].Fragments=3
Meta.Daily[7].Celestial={hourglass=1,orb=1}
Meta.Playtime[3].Reward.Celestial={orb=1}
Meta.Milestones[2].Reward.Fragments=5
Meta.Milestones[1].Reward.Title="First Light"
Meta.QuestById.boss1.Reward.Fragments=2
Meta.QuestById.hard.Reward.Fragments=5
Meta.Wheel.Prizes[8].Reward.Fragments=3
Meta.Wheel.Prizes[9].Reward.Celestial={orb=1}
for _,prize in Meta.Wheel.Prizes do
	if prize.Reward.Shards and prize.Label~="JACKPOT" then
		prize.Label=`{math.ceil(prize.Reward.Shards/Meta.ShardExchange)} Trait Shards`
	end
end
return Meta
