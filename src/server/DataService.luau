--!nonstrict
-- Player saves through ProfileStore (session-locked, auto-saving).
-- In Studio without API access, ProfileStore falls back to an in-memory mock,
-- so the game still runs; data just won't persist between test sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.ProfileStore)
local Config = require(ReplicatedStorage.Shared.Config)
local Deck = require(ReplicatedStorage.Shared.Deck)

local presets = {}
for i = 1, Config.Deck.Presets do
	presets[i] = Deck.Empty()
end

local TEMPLATE = {
	DataVersion = 1,
	-- [cardId] = { Copies, Stars, Fusion?, Borders?, Foils? (found foil ids), Awaken? (highest Awakening
	-- node), Trait? (slot 1), Trait2? (slot 2), Pending? ({ Slot, Traits } an unchosen Trait Master roll) }
	Cards = {},
	TotalRolls = 0,
	Shards = 0,
	TraitShards = 0, -- the Trait Master's currency
	Playtime = 0, -- seconds, saved when the player leaves
	-- Favorite: the card shown as the player's picture in the server list and on their name tag ("" = none).
	Settings = { AutoStop = Config.DefaultAutoStop, AutoUlt = false, BattleSpeed = 1, Music = 1, Effects = 1, Mount = "pup", Favorite = "", Title = "", Avatar = "" },
	Decks = { Active = 1, Presets = presets }, -- each preset: { Attack = {4 ids}, Support = {4 ids} }, "" = empty
	Progress = { Cleared = {}, BestTime = {} }, -- keyed by Bosses.FightKey, e.g. "kurogane:Normal"
	-- Long-term progression (Meta.luau): potions owned / seconds left running (ticks only while online),
	-- Shard upgrade levels, claimed Index rarities, daily streak, claimed roll milestones ("50", "100", ...).
	Potions = { Inventory = {}, Active = {} },
	Upgrades = { RollSpeed = 0, Luck = 0 },
	IndexClaimed = {},
	Daily = { Day = 0, Streak = 0 },
	Milestones = {},
	-- Daily quests: progress per quest id for Day (reset when the day changes), and the claimed ones.
	Quests = { Day = 0, Progress = {}, Claimed = {} },
	-- Player level (Meta.XPToNext) and XP toward the next one.
	Level = 1,
	XP = 0,
	-- Stat points spent, by Meta.Stats id (one point per level past 1).
	Stats = {},
	-- Boss drops (Items.luau): artifacts owned (id -> level) and the ones worn, accessories owned but
	-- not worn (id -> count) and the one each card wears (cardId -> accessory id).
	Gear = { Artifacts = {}, Worn = {} },
	-- Lucky Wheel: banked free spins and seconds played toward the next one.
	Wheel = { Spins = 1, Progress = 0 },
	-- Infinite Tower (Tower.luau): the highest floor cleared; the next fight is Floor + 1.
	Tower = { Floor = 0 },
	-- Roll Packs from boss and tower wins (Packs.luau id -> count), opened from the BAG.
	Packs = {},
	-- Redeem codes already used (CODES, Codes.luau): CODE -> true.
	Codes = {},
	-- Passes bought in Studio / test mode while their id is still 0 (MonetizationService): key -> true.
	MockPasses = {},
	-- Kenji's questline (Tutorial.luau): the open quest, flags noted by the services, supplies given.
	Tutorial = { Step = 1, Flags = {}, Supplied = {} },
	-- Titles earned (name -> true); the worn one is Settings.Title.
	Titles = {},
	-- Developer product receipts already paid out (PurchaseId -> os.time()), so a retry never pays twice.
	Purchases = {},
}

-- Test saves live in their own store so launch data starts clean.
local STORE_NAME = if Config.TestMode then "PlayerData_Test_1" else "PlayerData_1"

local PlayerStore = ProfileStore.New(STORE_NAME, TEMPLATE)

local DataService = {}

local profiles = {} -- [Player] = Profile
-- Messages to a save from another server or while its player was away (ProfileStore MessageAsync), e.g. a
-- raid payout for a hitter who left before the raid ended. Set by Main.server (MetaService grants them).
local messageHandler: ((player: Player, profile: any, message: any) -> ())? = nil

function DataService.SetMessageHandler(fn)
	messageHandler = fn
end

-- Queues a message for a player's save, online or not; it's handled the next time their profile loads
-- (or right away if it's loaded on any server). Yields; returns whether it was stored.
function DataService.SendMessage(userId: number, message): boolean
	local ok, stored = pcall(function()
		return PlayerStore:MessageAsync(`{userId}`, message)
	end)
	if not ok then
		warn(`[DataService] message for {userId} failed: {stored}`)
	end
	return ok and stored == true
end
local sessionStart = {} -- [Player] = os.clock() when the profile loaded

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- What the client gets for one owned card.
function DataService.CardState(entry)
	return {
		Copies = entry.Copies,
		Stars = entry.Stars,
		Fusion = entry.Fusion,
		Borders = entry.Borders,
		BorderCopies = entry.BorderCopies,
		Foils = entry.Foils,
		Awaken = entry.Awaken,
		Trait = entry.Trait,
		Trait2 = entry.Trait2,
		Pending = entry.Pending,
	}
end

function DataService.Template()
	return deepCopy(TEMPLATE)
end

function DataService.Get(player: Player)
	return profiles[player]
end

-- Waits until the player's profile has loaded (or they leave / time runs out).
function DataService.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 20)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Saved playtime plus this session so far.
function DataService.Playtime(player: Player): number
	local profile = profiles[player]
	if profile == nil then
		return 0
	end
	local start = sessionStart[player]
	local live = if start then os.clock() - start else 0
	return profile.Data.Playtime + live
end

-- Seconds since this server session's profile loaded (playtime gifts count this).
function DataService.SessionSeconds(player: Player): number
	local start = sessionStart[player]
	return if start then os.clock() - start else 0
end

-- Wipes the player's data back to the template (test phase only).
function DataService.Reset(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	local fresh = DataService.Template()
	for key in profile.Data do
		profile.Data[key] = nil
	end
	for key, value in fresh do
		profile.Data[key] = value
	end
	sessionStart[player] = os.clock()
end

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Only happens when the server is shutting down or the player left.
		if player.Parent == Players then
			player:Kick("Could not load your data - please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fill in fields added to TEMPLATE after this save was made
	-- Card accessories were removed: any the player had (in the bag or worn) are refunded as Shards.
	local gear = profile.Data.Gear
	if type(gear.Accessories) == "table" or type(gear.Cards) == "table" then
		local count = 0
		for _, n in gear.Accessories or {} do
			count += if type(n) == "number" then n else 0
		end
		for _ in gear.Cards or {} do
			count += 1
		end
		profile.Data.Shards += count * 150
		gear.Accessories = nil
		gear.Cards = nil
	end
	profile.Data.Pity = nil -- rolls are pure luck now
	-- Borders became the tiers (no card rarities): each card gets per-border copy counts. Its old copies
	-- are Base copies, minus one for each special border it had found; an old rarity fusion becomes one
	-- Gold copy. Old Auto Roll stops (rarities) go back to the default.
	for _, entry in profile.Data.Cards do
		if type(entry) == "table" and entry.BorderCopies == nil then
			local copies = { Normal = 0 }
			local special = 0
			for id, has in entry.Borders or {} do
				if has and id ~= "Normal" then
					copies[id] = 1
					special += 1
				end
			end
			local fused = entry.Fusion or 0
			if fused > 0 then
				copies.Gold = (copies.Gold or 0) + fused
				entry.Borders = entry.Borders or {}
				entry.Borders.Gold = true
				entry.Copies += fused
			end
			copies.Normal = math.max(0, (entry.Copies or 1) - special - fused)
			entry.BorderCopies = copies
		end
	end
	if not table.find(Config.AutoStopOptions, profile.Data.Settings.AutoStop) then
		profile.Data.Settings.AutoStop = Config.DefaultAutoStop
	end
	-- Saves from the short-lived roll bank (rarity tickets) get their tickets back as Roll Packs.
	local bank = profile.Data.RollBank
	if type(bank) == "table" then
		local tickets = 0
		for _, count in bank do
			tickets += if type(count) == "number" then count else 0
		end
		if tickets > 0 then
			profile.Data.Packs["10"] = (profile.Data.Packs["10"] or 0) + math.ceil(tickets / 10)
		end
		profile.Data.RollBank = nil
	end

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		sessionStart[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server - please rejoin.")
		end
	end)

	if player.Parent == Players then
		profiles[player] = profile
		sessionStart[player] = os.clock()
		profile:MessageHandler(function(message, processed)
			if messageHandler then
				local ok, err = pcall(messageHandler, player, profile, message)
				if not ok then
					warn(`[DataService] message handler failed: {err}`)
					return -- left in the queue, tried again next load
				end
			end
			processed()
		end)
	else
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	local start = sessionStart[player]
	if start then
		profile.Data.Playtime += os.clock() - start
	end
	profile:EndSession()
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return DataService
