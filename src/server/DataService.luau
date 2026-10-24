--!nonstrict
-- Player saves through ProfileStore (session-locked, auto-saving).
-- In Studio without API access, ProfileStore falls back to an in-memory mock,
-- so the game still runs; data just won't persist between test sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.ProfileStore)
local Config = require(ReplicatedStorage.Shared.Config)
local Deck = require(ReplicatedStorage.Shared.Deck)
local SaveMigration = require(script.Parent.SaveMigration)

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
	Settings = { AutoStop = Config.DefaultAutoStop, AutoUlt = false, BattleSpeed = 1, Music = 1, Effects = 1, Mount = "pup", Favorite = "", Title = "", Avatar = "", QuickRoll = false },
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
	-- Infinite Tower (Tower.luau): the best run (Floor, on the leaderboard) and the run going now (Run:
	-- floors cleared; the next fight is Run + 1). Live is the floor being fought: a save that loads with
	-- it set was left mid-fight, so SaveMigration ends that run.
	Tower = { Floor = 0, Run = 0 },
	-- The Hundred-Floor Pagoda: floors cleared (kept; the next fight is Floor + 1, done at 100).
	Pagoda = { Floor = 0 },
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
	-- Old saves are brought up to date (accessory refunds, border copies, roll bank ...): SaveMigration.
	SaveMigration.Migrate(profile.Data)

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
