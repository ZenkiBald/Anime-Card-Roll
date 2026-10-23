--!nonstrict
-- Every roll happens here, on the server. The client only asks and then animates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Odds = require(Shared.Odds)
local Rewards = require(Shared.Rewards)
local Bosses = require(Shared.Bosses)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local BattleService = require(script.Parent.BattleService)
local MetaService = require(script.Parent.MetaService)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)
local Items = require(Shared.Items)

local RollService = {}

local rng = Random.new()

local lastRoll = {} -- [Player] = os.clock() of their last roll
local autoGeneration = {} -- [Player] = number; bumping it stops the running Auto Roll loop
local autoActive = {} -- [Player] = true while Auto Roll is running

local COOLDOWN_TOLERANCE = 0.1 -- forgive small network timing differences

-- The player's own luck: base (1x + Lucky Charm + Index rewards, or the dev panel's value)
-- times the strongest running luck potion, capped at Config.Roll.LuckCap.
local function luckFor(player: Player, data): number
	return MetaService.Luck(player, data)
end

local function cooldownFor(data): number
	return MetaService.Cooldown(data)
end

local function isUnlocked(player: Player, data, feature: string): boolean
	if not Config.Unlocks.Enabled then
		return true
	end
	local rule = Config.Unlocks[feature]
	return data.TotalRolls >= rule.Rolls and DataService.Playtime(player) >= rule.Seconds
end

-- Everything the client needs to draw the HUD.
local function summary(player: Player, data)
	return {
		TotalRolls = data.TotalRolls,
		Shards = data.Shards,
		Pity = { Epic = data.Pity.Epic, Legendary = data.Pity.Legendary },
		Luck = luckFor(player, data),
		Cooldown = cooldownFor(data),
		AutoStop = data.Settings.AutoStop,
		AutoActive = autoActive[player] == true,
		Playtime = DataService.Playtime(player),
		Unlocked = {
			QuickRoll = isUnlocked(player, data, "QuickRoll"),
			AutoRoll = isUnlocked(player, data, "AutoRoll"),
		},
	}
end

local function fullState(player: Player, data)
	local cards = {}
	for id, entry in data.Cards do
		cards[id] = { Copies = entry.Copies, Stars = entry.Stars, Fusion = entry.Fusion, Borders = entry.Borders }
	end
	return {
		Ok = true,
		Cards = cards,
		Summary = summary(player, data),
		Decks = DeckService.State(data),
		Progress = data.Progress,
		Battle = { AutoUlt = data.Settings.AutoUlt, Speed = data.Settings.BattleSpeed },
		Mount = data.Settings.Mount,
		Meta = MetaService.State(player, data),
		TestMode = Config.TestMode,
	}
end

-- One roll: pick rarity (with luck, floor + pity), pick card, apply duplicates, update pity.
-- Duplicates add stars up to the max, then pile up as copies for the Fusion Master (FusionService).
-- luck / minFloor default to the player's own luck and no floor (boss reward rolls pass both).
local function doRoll(player: Player, profile, luck: number?, minFloor: string?)
	local data = profile.Data

	local pityFloor = Odds.PityFloor(data.Pity)
	local floor = Odds.HigherFloor(pityFloor, minFloor)
	local chances = Odds.Chances(luck or luckFor(player, data), floor)
	local tier = Odds.PickTier(chances, rng)
	local pool = Cards.ByRarity[tier]
	local card = pool[rng:NextInteger(1, #pool)]

	Odds.UpdatePity(data.Pity, tier)
	data.TotalRolls += 1
	MetaService.Track(player, "Rolls")
	if Rarity.AtLeast(tier, "Epic") then
		MetaService.Track(player, "EpicPulls")
	end

	local entry = data.Cards[card.Id]
	local outcome = "New"
	if entry == nil then
		entry = { Copies = 1, Stars = 0 }
		data.Cards[card.Id] = entry
	elseif entry.Stars < Config.MaxStars then
		entry.Copies += 1
		entry.Stars += 1
		outcome = "Star"
	else
		entry.Copies += 1
		outcome = "Copy"
	end
	MetaService.AddXP(player, data, Meta.XP.Roll + (if outcome == "New" then Meta.XP.NewCard else 0))

	-- Every pull also rolls a border (Border Chance stat makes the special ones likelier). The card
	-- keeps each border it has found and wears the best.
	local border = Borders.Pick(rng:NextNumber(), Meta.Bonus(data.Stats, data.Gear, "Border"))
	local newBorder = false
	if border ~= "Normal" then
		entry.Borders = entry.Borders or {}
		newBorder = entry.Borders[border] ~= true
		entry.Borders[border] = true
	end

	if Rarity.AtLeast(tier, Config.AnnounceFrom) or Borders.Index(border) >= Borders.Index("Rainbow") then
		Remotes.Announce:FireAllClients(player.DisplayName, card.Id, border)
	end

	return {
		Ok = true,
		CardId = card.Id,
		Rarity = tier,
		Outcome = outcome, -- "New" | "Star" | "Copy" (toward fusion)
		Stars = entry.Stars,
		Copies = entry.Copies,
		Fusion = entry.Fusion,
		Border = border, -- the border this pull rolled
		NewBorder = newBorder, -- first time this card got it
		Borders = entry.Borders, -- every border the card has found
		PityTriggered = pityFloor ~= nil and floor == pityFloor and floor ~= minFloor,
		Summary = summary(player, data),
		Quests = MetaService.QuestState(player, data), -- roll quests tick with every roll
	}
end

-- Boss reward rolls for a win at difficulty score d: 3 + 2d rolls with boss luck and a rarity
-- floor, plus one card above the floor on a first clear (Rewards.luau has the numbers).
function RollService.RewardRolls(player: Player, d: number, firstClear: boolean)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local reward = Rewards.For(d)
	local luck = Rewards.TotalLuck(reward.Luck, luckFor(player, profile.Data))
	local results = {}
	local function add(floor: string, bonus: boolean)
		local result = doRoll(player, profile, luck, floor)
		result.Summary = nil
		result.Bonus = bonus or nil
		table.insert(results, result)
	end
	for _ = 1, reward.Rolls do
		add(reward.Floor, false)
	end
	if firstClear then
		add(reward.Bonus, true)
	end
	-- Every win pays Shards, may drop a potion, and rolls for an accessory and an artifact (Items.luau:
	-- better odds and rarer gear on harder fights).
	local bundle = { Shards = reward.Shards, Potions = {} }
	if rng:NextNumber() < Config.Rewards.PotionChance then
		bundle.Potions[reward.Potion] = 1
	end
	local drops = Items.RollDrops(d, rng)
	bundle.Accessories = drops.Accessories
	bundle.Artifacts = drops.Artifacts
	bundle = MetaService.Grant(profile.Data, bundle) -- the screen shows the Shard Gain bonus too
	return {
		Results = results,
		Luck = luck,
		Floor = reward.Floor,
		Bundle = bundle,
		Summary = summary(player, profile.Data),
		Meta = MetaService.State(player, profile.Data),
	}
end

local function cooldownLeft(player: Player): number
	local last = lastRoll[player]
	local profile = DataService.Get(player)
	if last == nil or profile == nil then
		return 0
	end
	return cooldownFor(profile.Data) - (os.clock() - last)
end

local function stopAuto(player: Player)
	autoGeneration[player] = (autoGeneration[player] or 0) + 1
	autoActive[player] = nil
end

local function startAuto(player: Player)
	stopAuto(player) -- ends any loop that is still winding down
	local generation = autoGeneration[player]
	autoActive[player] = true

	task.spawn(function()
		while autoGeneration[player] == generation and player.Parent == Players do
			local wait = cooldownLeft(player)
			if wait > 0 then
				task.wait(wait)
			end
			if autoGeneration[player] ~= generation then
				break
			end

			local profile = DataService.Get(player)
			if profile == nil then
				break
			end

			lastRoll[player] = os.clock()
			local result = doRoll(player, profile)

			local stopAt = profile.Data.Settings.AutoStop
			-- A NEW Rainbow or Secret border always stops Auto Roll, so its reveal can play.
			local bigBorder = result.NewBorder and Borders.Index(result.Border) >= Borders.Index("Rainbow")
			local hitStop = (stopAt ~= "Never" and Rarity.AtLeast(result.Rarity, stopAt)) or bigBorder
			if hitStop then
				stopAuto(player)
				result.Summary.AutoActive = false
			end
			result.Stopped = hitStop
			Remotes.AutoResult:FireClient(player, result)

			if hitStop then
				break
			end
		end
		if autoGeneration[player] == generation then
			autoActive[player] = nil
		end
	end)
end

function RollService.Start()
	Remotes.GetState.OnServerInvoke = function(player: Player)
		local profile = DataService.WaitFor(player, 20)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		return fullState(player, profile.Data)
	end

	Remotes.Roll.OnServerInvoke = function(player: Player, mode: unknown)
		if mode ~= "Full" and mode ~= "Quick" then
			return { Ok = false, Reason = "BadRequest" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if autoActive[player] then
			return { Ok = false, Reason = "AutoActive" }
		end
		if mode == "Quick" and not isUnlocked(player, profile.Data, "QuickRoll") then
			return { Ok = false, Reason = "Locked" }
		end
		local left = cooldownLeft(player)
		if left > COOLDOWN_TOLERANCE then
			return { Ok = false, Reason = "Cooldown", Wait = left }
		end
		lastRoll[player] = os.clock()
		return doRoll(player, profile)
	end

	Remotes.SetAuto.OnServerEvent:Connect(function(player: Player, on: unknown, autoStop: unknown)
		local profile = DataService.Get(player)
		if profile == nil then
			return
		end
		if type(autoStop) == "string" and table.find(Config.AutoStopOptions, autoStop) then
			profile.Data.Settings.AutoStop = autoStop
		end
		if on == true then
			if not isUnlocked(player, profile.Data, "AutoRoll") then
				Remotes.AutoResult:FireClient(player, { Ok = false, Stopped = true, Reason = "Locked" })
				return
			end
			if not autoActive[player] then
				startAuto(player)
			end
		elseif on == false then
			stopAuto(player)
		end
	end)

	-- Test-phase tools. The server refuses all of them once Config.TestMode is false.
	Remotes.Dev.OnServerInvoke = function(player: Player, action: unknown, value: unknown)
		if not Config.TestMode then
			return { Ok = false, Reason = "Disabled" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if action == "SetLuck" then
			local luck = tonumber(value) or 1
			MetaService.SetDevLuck(player, math.clamp(luck, 1, Config.Roll.LuckCap))
		elseif action == "GrantAll" or action == "GrantStarter" then
			-- GrantStarter: just the Commons and Uncommons, i.e. the first ~14.6k deck.
			for _, card in Cards.List do
				local include = action == "GrantAll" or not Rarity.AtLeast(card.Rarity, "Rare")
				if include and profile.Data.Cards[card.Id] == nil then
					profile.Data.Cards[card.Id] = { Copies = 1, Stars = 0 }
				end
			end
		elseif action == "MaxStars" then
			for _, entry in profile.Data.Cards do
				if entry.Stars < Config.MaxStars then
					entry.Copies += Config.MaxStars - entry.Stars
					entry.Stars = Config.MaxStars
				end
			end
		elseif action == "FillCopies" then
			-- Every owned card that can still fuse gets enough copies for its next fusion.
			for id, entry in profile.Data.Cards do
				local card = Cards.Get(id)
				if card and (entry.Fusion or 0) < Cards.MaxFusion(card) then
					entry.Copies = math.max(entry.Copies, Config.FusionCopies)
				end
			end
		elseif action == "StartEvent" then
			-- Runs an event now for its usual length (value = event id).
			if type(value) ~= "string" or Meta.EventById[value] == nil then
				return { Ok = false, Reason = "BadRequest" }
			end
			MetaService.ForceEvent(value, Meta.EventSeconds)
		elseif action == "GiveBorders" then
			-- Spreads borders over owned cards so every frame can be seen: each gets Gold, every second
			-- one Rainbow, every fourth Secret.
			local i = 0
			for _, card in Cards.List do
				local entry = profile.Data.Cards[card.Id]
				if entry then
					i += 1
					entry.Borders = entry.Borders or {}
					entry.Borders.Gold = true
					entry.Borders.Rainbow = entry.Borders.Rainbow or i % 2 == 0
					entry.Borders.Secret = entry.Borders.Secret or i % 4 == 0
				end
			end
		elseif action == "GiveItems" then
			-- One of every artifact and two of every accessory, to try the BAG.
			local bundle = { Artifacts = {}, Accessories = {} }
			for _, artifact in Items.Artifacts do
				bundle.Artifacts[artifact.Id] = 1
			end
			for _, accessory in Items.Accessories do
				bundle.Accessories[accessory.Id] = 2
			end
			MetaService.Grant(profile.Data, bundle)
		elseif action == "GiveSpins" then
			profile.Data.Wheel.Spins = Meta.Wheel.MaxSpins
		elseif action == "AddXP" then
			MetaService.AddXP(player, profile.Data, 3000)
		elseif action == "UnlockFights" then
			-- Marks every fight cleared (no rewards), so every world and difficulty opens.
			for _, boss in Bosses.List do
				for _, difficulty in Bosses.DifficultyOrder do
					if boss.Difficulties[difficulty] then
						profile.Data.Progress.Cleared[Bosses.FightKey(boss.Id, difficulty)] = true
					end
				end
			end
		elseif action == "GiveLoot" then
			-- 1,000 Shards and 3 of every potion, to try the shop and boosts.
			local potions = {}
			for _, potion in Meta.Potions do
				potions[potion.Id] = 3
			end
			MetaService.Grant(profile.Data, { Shards = 1000, Potions = potions })
		elseif action == "Reset" then
			stopAuto(player)
			BattleService.Stop(player)
			DataService.Reset(player)
			MetaService.ResetSession(player)
			MetaService.SetDevLuck(player, nil)
			lastRoll[player] = nil
		else
			return { Ok = false, Reason = "BadRequest" }
		end
		return fullState(player, profile.Data)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		stopAuto(player)
		lastRoll[player] = nil
		autoGeneration[player] = nil
	end)
end

return RollService
