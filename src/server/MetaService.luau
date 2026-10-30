--!nonstrict
-- Long-term progression on the server: potions (use, buy, timers), Shard upgrades, Index
-- completion rewards, the daily streak, playtime gifts and roll milestones. Meta.luau has the numbers;
-- every claim and purchase is checked here. Also daily quests (progress counted through Track),
-- stat points, and the SETTINGS volume choices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Packs = require(Shared.Packs)
local Raid = require(Shared.Raid)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)
local NpcRange = require(script.Parent.NpcRange)
local MonetizationService = require(script.Parent.MonetizationService)
local Momentum = require(script.Parent.Momentum)
local AvatarService = require(script.Parent.AvatarService)
local WeatherService = require(script.Parent.WeatherService)
local Weather = require(Shared.Weather)
local RevealPolicy=require(Shared.RevealPolicy)
local RewardBundle=require(Shared.RewardBundle)

local MetaService = {}

local limiter = RateLimit.new(6, 12)
local getLimiter = RateLimit.new(2, 6) -- "Get" (read only) builds the whole Meta state
local wheelRng = Random.new()
local giftsClaimed = {} -- [Player] = { [index] = true } for this server session

-- Adds a reward bundle to a save (Shards boosted by the Shard Gain stat, and with `player` by the VIP
-- pass: Shards always, Trait Shards where paid random items are allowed). Returns the bundle actually
-- given, so screens show the boosted amount.
function MetaService.Grant(data, bundle: Meta.Bundle, player: Player?)
	bundle=Meta.RetireShards(bundle)
	if bundle.Title then
		data.Titles=data.Titles or {}
		data.Titles[bundle.Title]=true
	end
	data.Celestial=data.Celestial or {Fragments=0,Inventory={}}
	if bundle.Fragments then data.Celestial.Fragments+=math.max(0,math.floor(bundle.Fragments)) end
	for id,count in (bundle.Celestial or {}) :: {[string]:number} do
		if id=="orb" or id=="hourglass" or Weather.SigilCost(string.match(id,"^sigil:(.+)$") or "") then
			data.Celestial.Inventory[id]=(data.Celestial.Inventory[id] or 0)+math.max(0,math.floor(count))
		end
	end

	if bundle.TraitShards and bundle.TraitShards > 0 then
		local traitShards = math.floor(bundle.TraitShards * (1 + Meta.Bonus(data.Stats,data.Gear,"ShardGain") + MonetizationService.ShardBonus(player) + MonetizationService.TraitShardBonus(player)) + 0.5)
		data.TraitShards = (data.TraitShards or 0) + traitShards
		if traitShards ~= bundle.TraitShards then
			bundle = table.clone(bundle)
			bundle.TraitShards = traitShards
		end
	end
	-- Artifacts (always on): owned once.
	for id, owned in (bundle.TowerArtifacts or {}) :: { [string]: boolean } do
		if owned and Items.TowerArtifactById[id] then
			data.Gear.TowerArtifacts = data.Gear.TowerArtifacts or {}
			data.Gear.TowerArtifacts[id] = true
		end
	end
	-- Relics: new ones arrive at level 1, duplicates level up a specialty; past max (or with none) they melt.
	for id, count in (bundle.Artifacts or {}) :: { [string]: number } do
		local artifact = Items.ArtifactById[id]
		if artifact and count > 0 then
			for _ = 1, count do
				local level = data.Gear.Artifacts[id]
				if level == nil then
					data.Gear.Artifacts[id] = 1
				elseif Items.CanLevel(artifact, level) then
					data.Gear.Artifacts[id] = level + 1
				else
					data.TraitShards += math.ceil((Items.MeltShards[artifact.Rarity] or 100)/Meta.ShardExchange)
				end
			end
		end
	end
	if bundle.Potions then
		for id, count in bundle.Potions do
			if Meta.PotionById[id] and count > 0 then
				data.Potions.Inventory[id] = (data.Potions.Inventory[id] or 0) + count
			end
		end
	end
	for id, count in (bundle.Packs or {}) :: { [string]: number } do
		if Packs.ById[id] and count > 0 then
			data.Packs[id] = (data.Packs[id] or 0) + count
		end
	end
	return bundle
end

local devLuck = {} -- [Player] = base luck set from the dev panel (test phase only)

function MetaService.SetDevLuck(player: Player, luck: number?)
	devLuck[player] = luck
end

-- Base luck: 1x + Lucky Charm + Index rewards + Luck stat points + levels (or the dev panel's value).
function MetaService.BaseLuck(player: Player, data): number
	if devLuck[player] then
		return devLuck[player]
	end
	-- Extra: the Momentum chain. (Fusions give no luck: the 4x card is the reward; user's call 2026-10-24.)
	local _, momentumLuck = Momentum.Bonus(player)
	return Meta.BaseLuck(data.Upgrades, data.IndexClaimed, data.Stats, data.Level, data.Gear, momentumLuck)
end

-- Server events -----------------------------------------------------------------------------------
-- The schedule follows the clock (Meta.EventAt). The test tools can force one: the override lives in
-- ReplicatedStorage attributes so clients see it too.

function MetaService.Event(): Meta.GameEvent?
	local id = ReplicatedStorage:GetAttribute("DevEvent")
	local ends = ReplicatedStorage:GetAttribute("DevEventEnds")
	local override = if type(id) == "string" and type(ends) == "number" then { Id = id, Ends = ends } else nil
	return (Meta.EventAt(workspace:GetServerTimeNow(), override))
end

function MetaService.ForceEvent(id: string, seconds: number)
	ReplicatedStorage:SetAttribute("DevEvent", id)
	ReplicatedStorage:SetAttribute("DevEventEnds", workspace:GetServerTimeNow() + seconds)
end

-- Levels ------------------------------------------------------------------------------------------

-- Adds XP (doubled during DOUBLE XP), levels up as often as it fills, pays each level's reward and
-- tells the client (Progress remote) so it can show the level-up.
function MetaService.AddXP(player: Player, data, amount: number)
	local event = MetaService.Event()
	local gain = Meta.Bonus(data.Stats, data.Gear, "XPGain") + MonetizationService.XPBonus(player)
	amount = math.floor(amount * (if event and event.XP then event.XP else 1) * (1 + gain))
	if amount <= 0 or data.Level >= Meta.MaxLevel then
		return
	end
	data.XP += amount
	local ups = {}
	while data.Level < Meta.MaxLevel and data.XP >= Meta.XPToNext(data.Level) do
		data.XP -= Meta.XPToNext(data.Level)
		data.Level += 1
		local reward = Meta.LevelReward(data.Level)
		MetaService.Grant(data, reward, player)
		table.insert(ups, { Level = data.Level, Reward = reward, Luck = data.Level % 10 == 0 })
	end
	if data.Level >= Meta.MaxLevel then
		data.XP = 0
	end
	Remotes.Progress:FireClient(player, {
		Level = data.Level,
		XP = data.XP,
		Need = Meta.XPToNext(data.Level),
		Ups = if #ups > 0 then ups else nil,
		Meta = if #ups > 0 then MetaService.State(player, data) else nil,
	})
end

-- Daily quests ----------------------------------------------------------------------------------

-- Starts a fresh quest day when the date has changed.
local function questDay(data): number
	local today = Meta.DayNumber(os.time())
	if data.Quests.Day ~= today then
		data.Quests.Day = today
		data.Quests.Progress = {}
		data.Quests.Claimed = {}
	end
	return today
end

-- Counts `amount` toward today's quests that track `stat` (called by the roll, battle, fusion and
-- gift code on the server).
function MetaService.Track(player: Player, stat: string, amount: number?)
	local profile = DataService.Get(player)
	if profile == nil then
		return
	end
	local data = profile.Data
	local today = questDay(data)
	for _, id in Meta.QuestsFor(today, player.UserId) do
		local quest = Meta.QuestById[id]
		if quest and quest.Stat == stat then
			data.Quests.Progress[id] = math.min(quest.Goal, (data.Quests.Progress[id] or 0) + (amount or 1))
		end
	end
end

-- Today's quests for the client: ids with progress and claimed flags (text and rewards are in Meta).
function MetaService.QuestState(player: Player, data)
	local today = questDay(data)
	local list = {}
	for _, id in Meta.QuestsFor(today, player.UserId) do
		table.insert(list, { Id = id, Progress = data.Quests.Progress[id] or 0, Claimed = data.Quests.Claimed[id] == true })
	end
	return { Day = today, ResetIn = 86400 - os.time() % 86400, List = list }
end

-- Raid Luck: x2 for the whole server for a while after a cleared raid (RaidService sets the attribute).
function MetaService.RaidLuck(): number
	local ends = ReplicatedStorage:GetAttribute("RaidLuckEnds")
	return Raid.LuckAt(workspace:GetServerTimeNow(), if type(ends) == "number" then ends else nil)
end

-- Server-wide luck on top of events: Raid Luck after a cleared raid, and a Luck Totem.
function MetaService.ServerLuck(): number
	return MetaService.RaidLuck() * MonetizationService.TotemLuck()
end

-- The player's own luck: base x the strongest running luck potion x the event x server luck x VIP, capped.
function MetaService.Luck(player: Player, data): number
	local event = MetaService.Event()
	local eventLuck = (event and event.Luck or 1) * MetaService.ServerLuck() * MonetizationService.VipLuck(player)
	return Meta.TotalLuck(MetaService.BaseLuck(player, data), Meta.PotionLuck(data.Potions.Active), eventLuck,WeatherService.Luck())
end

-- `player` (optional) adds the Momentum chain's speed and the Fast Roll pass.
function MetaService.Cooldown(data, player: Player?): number
	local event = MetaService.Event()
	local boost = nil
	if player then
		boost = { Momentum = (Momentum.Bonus(player)), Pass = MonetizationService.CooldownCut(player) }
	end
	return Meta.Cooldown(data.Upgrades, data.Potions.Active, event and event.Speed, data.Stats, data.Gear, boost)
end

-- Every card (boss cards aside) found at `border` ("Normal" = owned at all).
local function indexComplete(data, border: string): boolean
	for _, card in Cards.List do
		if card.Boss == nil and card.Weather==nil then
			local entry = data.Cards[card.Id]
			if entry == nil or (border ~= "Normal" and not (entry.Borders and entry.Borders[border])) then
				return false
			end
		end
	end
	return true
end

-- Everything the progression screens need.
function MetaService.State(player: Player, data)
	local today = Meta.DayNumber(os.time())
	local canClaim, streakDay = Meta.DailyStatus(data.Daily, today)
	local complete = {}
	for _, border in Borders.Order do
		complete[border] = indexComplete(data, border)
	end
	local claimedGifts = {}
	for index in giftsClaimed[player] or {} do
		table.insert(claimedGifts, index)
	end
	return {
		Shards = data.Shards,
		Celestial = data.Celestial,
		TotalRolls = data.TotalRolls,
		Inventory = data.Potions.Inventory,
		Active = data.Potions.Active,
		Upgrades = data.Upgrades,
		IndexClaimed = data.IndexClaimed,
		IndexComplete = complete,
		Daily = { CanClaim = canClaim, Day = streakDay, Streak = data.Daily.Streak },
		SessionSeconds = DataService.SessionSeconds(player),
		GiftsClaimed = claimedGifts,
		Milestones = data.Milestones,
		BaseLuck = MetaService.BaseLuck(player, data),
		Luck = MetaService.Luck(player, data),
		Cooldown = MetaService.Cooldown(data, player),
		TraitShards = data.TraitShards or 0,
		Momentum = Momentum.State(player),
		Volume = { Music = data.Settings.Music, Effects = data.Settings.Effects },
		Quests = MetaService.QuestState(player, data),
		Level = { Level = data.Level, XP = data.XP, Need = Meta.XPToNext(data.Level) },
		Stats = data.Stats,
		StatPoints = Meta.StatPoints(data.Level) - Meta.StatsSpent(data.Stats),
		Gear = data.Gear,
		Wheel = { Spins = data.Wheel.Spins, Progress = data.Wheel.Progress },
		Favorite = data.Settings.Favorite,
		Avatar = data.Settings.Avatar, -- the card worn as an avatar aura ("" = none)
		QuickRoll = data.Settings.QuickRoll == true, -- ROLL plays the short reveal
		RevealMinimum=RevealPolicy.Read(data.Settings).RevealMinimum,
		RevealStyle=RevealPolicy.Read(data.Settings).RevealStyle,
		RevealDuplicates=RevealPolicy.Read(data.Settings).RevealDuplicates,
		Packs = data.Packs, -- gifts, quests and milestones can grant Roll Packs
	}
end

-- Clears this session's playtime gifts (test-data reset).
function MetaService.ResetSession(player: Player)
	giftsClaimed[player] = nil
end

local function validIndex(value: unknown, list): boolean
	return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= #list
end

local function handle(player: Player, data, action: unknown, arg: unknown)
	if action=="SetRevealMinimum" or action=="SetRevealStyle" or action=="SetRevealDuplicates" then
		local key=string.sub(action,4)
		if key~="RevealDuplicates" and type(arg)~="string" then return false,"BadRequest" end
		if (key=="RevealMinimum" and not table.find(RevealPolicy.Minimums,arg)) or (key=="RevealStyle" and not table.find(RevealPolicy.Styles,arg)) or (key=="RevealDuplicates" and type(arg)~="boolean") then return false,"BadRequest" end
		data.Settings[key]=arg
		return true
	end
	if action=="ClaimAll" then
		if arg~=nil and arg~="Rewards" and arg~="Index" then return false,"BadRequest" end
		local bundle,count={},0
		local function collect(name,id)
			local ok,_,paid=handle(player,data,name,id)
			if ok then count+=1;RewardBundle.Merge(bundle,paid) end
		end
		if arg~="Index" then
			collect("ClaimDaily")
			for i in Meta.Playtime do collect("ClaimGift",i) end
			for i in Meta.Milestones do collect("ClaimMilestone",i) end
			for _,id in Meta.QuestsFor(questDay(data),player.UserId) do collect("ClaimQuest",id) end
		end
		for _,id in Borders.Order do collect("ClaimIndex",id) end
		return true,nil,bundle,{Claimed=count}
	end
	if action=="BuyPotion" or action=="BuyUpgrade" then return false,"Retired" end
	if action == "UsePotion" then
		local potion = type(arg) == "string" and Meta.PotionById[arg]
		if not potion then
			return false, "BadRequest"
		end
		local owned = data.Potions.Inventory[potion.Id] or 0
		if owned <= 0 then
			return false, "NoPotion"
		end
		local running = data.Potions.Active[potion.Id] or 0
		if running + potion.Seconds > Meta.MaxPotionSeconds then
			return false, "PotionFull"
		end
		data.Potions.Inventory[potion.Id] = owned - 1
		data.Potions.Active[potion.Id] = running + potion.Seconds
		MetaService.Track(player, "Potions")
		return true
	elseif action == "BuyPotion" then
		local potion = type(arg) == "string" and Meta.PotionById[arg]
		if not potion then
			return false, "BadRequest"
		end
		if data.Shards < potion.Price then
			return false, "NoShards"
		end
		data.Shards -= potion.Price
		MetaService.Grant(data, { Potions = { [potion.Id] = 1 } }, player)
		return true
	elseif action == "BuyUpgrade" then
		local upgrade = type(arg) == "string" and Meta.UpgradeById[arg]
		if not upgrade then
			return false, "BadRequest"
		end
		local level = data.Upgrades[upgrade.Id] or 0
		local cost = Meta.UpgradeCost(upgrade.Id, level)
		if cost == nil then
			return false, "MaxLevel"
		end
		if data.Shards < cost then
			return false, "NoShards"
		end
		data.Shards -= cost
		data.Upgrades[upgrade.Id] = level + 1
		return true
	elseif action == "ClaimDaily" then
		local today = Meta.DayNumber(os.time())
		local canClaim, streakDay = Meta.DailyStatus(data.Daily, today)
		if not canClaim then
			return false, "Claimed"
		end
		data.Daily.Day = today
		data.Daily.Streak = streakDay
		return true, nil, MetaService.Grant(data, Meta.Daily[streakDay], player)
	elseif action == "ClaimGift" then
		if not validIndex(arg, Meta.Playtime) then
			return false, "BadRequest"
		end
		local index = arg :: number
		local gift = Meta.Playtime[index]
		local claimed = giftsClaimed[player] or {}
		if claimed[index] then
			return false, "Claimed"
		end
		if DataService.SessionSeconds(player) < gift.Minutes * 60 then
			return false, "NotYet"
		end
		claimed[index] = true
		giftsClaimed[player] = claimed
		MetaService.Track(player, "Gifts")
		return true, nil, MetaService.Grant(data, gift.Reward, player)
	elseif action == "ClaimMilestone" then
		if not validIndex(arg, Meta.Milestones) then
			return false, "BadRequest"
		end
		local milestone = Meta.Milestones[arg :: number]
		local key = tostring(milestone.Rolls)
		if data.Milestones[key] then
			return false, "Claimed"
		end
		if data.TotalRolls < milestone.Rolls then
			return false, "NotYet"
		end
		data.Milestones[key] = true
		return true, nil, MetaService.Grant(data, milestone.Reward, player)
	elseif action == "ClaimIndex" then
		local reward = type(arg) == "string" and Meta.IndexRewards[arg]
		if not reward then
			return false, "BadRequest"
		end
		local rarity = arg :: string
		if data.IndexClaimed[rarity] then
			return false, "Claimed"
		end
		if not indexComplete(data, rarity) then
			return false, "NotYet"
		end
		data.IndexClaimed[rarity] = true
		return true, nil, MetaService.Grant(data, reward.Reward, player)
	elseif action == "SetMusic" or action == "SetEffects" then
		if type(arg) ~= "number" or table.find(Config.VolumeSteps, arg) == nil then
			return false, "BadRequest"
		end
		data.Settings[if action == "SetMusic" then "Music" else "Effects"] = arg
		return true
	elseif action == "SetFavorite" then
		-- An owned card becomes the player's picture (server list, name tag); "" clears it.
		if arg ~= "" and (type(arg) ~= "string" or data.Cards[arg] == nil) then
			return false, "BadRequest"
		end
		data.Settings.Favorite = arg
		return true
	elseif action == "SetQuickRoll" then
		-- The QUICK toggle: ROLL plays the short reveal instead of the full one (a client look; the roll is
		-- the same either way).
		if type(arg) ~= "boolean" then
			return false, "BadRequest"
		end
		data.Settings.QuickRoll = arg
		return true
	elseif action == "SetAvatar" then
		-- Wear an owned card as your look in town (its element aura; Rainbow / Secret borders add a
		-- walking trail): AvatarService puts it on the character and replicates it. "" takes it off.
		if arg ~= "" and (type(arg) ~= "string" or data.Cards[arg] == nil) then
			return false, "BadRequest"
		end
		data.Settings.Avatar = arg
		AvatarService.Apply(player, true) -- every client redraws now, not on a polling loop
		return true
	elseif action == "ClaimQuest" then
		local quest = type(arg) == "string" and Meta.QuestById[arg]
		if not quest then
			return false, "BadRequest"
		end
		local today = questDay(data)
		if not table.find(Meta.QuestsFor(today, player.UserId), quest.Id) then
			return false, "BadRequest" -- not one of today's quests
		end
		if data.Quests.Claimed[quest.Id] then
			return false, "Claimed"
		end
		if (data.Quests.Progress[quest.Id] or 0) < quest.Goal then
			return false, "NotYet"
		end
		data.Quests.Claimed[quest.Id] = true
		MetaService.AddXP(player, data, Meta.XP.Quest)
		return true, nil, MetaService.Grant(data, quest.Reward, player)
	elseif action == "SpinWheel" then
		if not NpcRange.Near(player, "fortune") then
			return false, "TooFar" -- the wheel spins beside Madame Fortuna
		end
		if data.Wheel.Spins <= 0 then
			return false, "NoSpins"
		end
		data.Wheel.Spins -= 1
		local index = Meta.WheelPick(wheelRng:NextNumber())
		local prize = Meta.Wheel.Prizes[index]
		-- The prize index goes back as the "reason" so the wheel can stop on it.
		return true, index, MetaService.Grant(data, prize.Reward, player)
	elseif action == "SpendStat" then
		local stat = type(arg) == "string" and Meta.StatById[arg]
		if not stat then
			return false, "BadRequest"
		end
		if Meta.StatPoints(data.Level) - Meta.StatsSpent(data.Stats) <= 0 then
			return false, "NoPoints"
		end
		local current = data.Stats[stat.Id] or 0
		if current >= stat.Max then
			return false, "MaxLevel"
		end
		data.Stats[stat.Id] = current + 1
		return true
	elseif action == "WearArtifact" then
		local id = type(arg) == "string" and Items.ArtifactById[arg] and arg
		if not id or data.Gear.Artifacts[id] == nil then
			return false, "BadRequest"
		end
		if table.find(data.Gear.Worn, id) then
			return false, "AlreadyWorn"
		end
		if #data.Gear.Worn >= Items.ArtifactSlots then
			return false, "SlotsFull"
		end
		table.insert(data.Gear.Worn, id)
		return true
	elseif action == "RemoveArtifact" then
		local index = type(arg) == "string" and table.find(data.Gear.Worn, arg)
		if not index then
			return false, "BadRequest"
		end
		table.remove(data.Gear.Worn, index)
		return true
	elseif action == "ResetStats" then
		local cost = math.ceil(Meta.StatResetCost(data.Stats)/Meta.ShardExchange)
		if cost == 0 then
			return false, "NothingToReset"
		end
		if data.TraitShards < cost then
			return false, "NoTraitShards"
		end
		data.TraitShards -= cost
		data.Stats = {}
		return true
	end
	return false, "BadRequest"
end

function MetaService.Request(player: Player, action: unknown, arg: unknown)
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if action == "Get" then
			if not getLimiter:Allow(player) then
				return { Ok = false, Reason = "TooFast" }
			end
			return { Ok = true, Meta = MetaService.State(player, profile.Data) }
		end
		if not limiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		local ok, reason, granted, extra = handle(player, profile.Data, action, arg)
		return { Ok = ok, Reason = reason, Granted = granted, Extra = extra, Meta = MetaService.State(player, profile.Data) }
	end

function MetaService.Start()
	Remotes.Meta.OnServerInvoke=MetaService.Request
	-- Once a second, for everyone in the game: running potions tick down, the Lucky Wheel fills toward
	-- the next free spin, and every full minute pays XP.
	task.spawn(function()
		local seconds = 0
		while true do
			task.wait(1)
			seconds += 1
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					local data = profile.Data
					local active = data.Potions.Active
					for id, left in active do
						if left <= 1 then
							active[id] = nil
						else
							active[id] = left - 1
						end
					end
					local wheel = data.Wheel
					if wheel.Spins < Meta.Wheel.MaxSpins then
						wheel.Progress += 1
						if wheel.Progress >= Meta.Wheel.SpinEvery then
							wheel.Progress = 0
							wheel.Spins += 1
						end
					end
					if seconds % 60 == 0 then
						MetaService.AddXP(player, data, Meta.XP.Minute)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		giftsClaimed[player] = nil
		devLuck[player] = nil
	end)
end

return MetaService
