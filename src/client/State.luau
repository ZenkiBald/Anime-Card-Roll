--!nonstrict
-- The client's copy of the player's data. The server is the source of truth;
-- this mirrors what it last sent so the UI can draw without asking again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meta"))
local Raid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Raid"))
local Tower = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tower"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local State = {
	Cards = {}, -- [cardId] = DataService.CardState: Copies, Stars, Fusion, Borders, Foils, Awaken, Trait, Trait2, Pending
	Summary = {
		TotalRolls = 0,
		Shards = 0,
		Luck = 1,
		AutoActive = false,
		Playtime = 0,
		Unlocked = { QuickRoll = true, AutoRoll = true },
		Momentum = nil :: any, -- { Count, Speed, Luck, Paused } (RollService)
		UntilSurge = 25,
		SurgeProgress = 0, -- 0-24: rolls into the current Overcharge Surge cycle (TotalRolls % 25)
		IsSurgeRoll = false, -- the last roll was a surge
	},
	Decks = { Active = 1, Presets = {} }, -- presets: { Attack = {4 ids}, Support = {4 ids} }, "" = empty
	Progress = { Cleared = {}, BestTime = {} },
	Tower = { Best = 0, Run = 0, Pagoda = 0 }, -- Infinite Tower best run and run now, Pagoda floors cleared
	Packs = {}, -- Roll Packs held: Packs.luau id -> count
	Battle = { AutoUlt = false, Speed = 1 },
	Store = { Passes = {}, Restricted = true, Mock = false }, -- MonetizationService.State
	Raid = nil, -- the server's raid (RaidService.Public): window, pool, top hitters; nil until it arrives
	-- Long-term progression (MetaService.State): potions, upgrades, Index claims, daily, gifts, milestones,
	-- daily quests ({ Day, ResetIn, List = { { Id, Progress, Claimed } } }), level and stat points.
	Meta = {
		Quests = { Day = 0, ResetIn = 0, List = {} },
		Level = { Level = 1, XP = 0, Need = 80 },
		Wheel = { Spins = 0, Progress = 0 },
		Stats = {},
		StatPoints = 0,
		Shards = 0,
		TotalRolls = 0,
		Inventory = {},
		Active = {},
		Upgrades = {},
		IndexClaimed = {},
		IndexComplete = {},
		Daily = { CanClaim = false, Day = 1, Streak = 0 },
		SessionSeconds = 0,
		GiftsClaimed = {},
		Milestones = {},
		BaseLuck = 1,
		Luck = 1,
		Cooldown = 1.2,
		TraitShards = 0,
		Gear = { Artifacts = {}, Worn = {} } :: any,
		Favorite = nil :: any,
		Avatar = nil :: any,
		QuickRoll = false,
		Volume = nil :: any,
	},
	MetaAt = os.clock(), -- when Meta arrived; timers count down from here
	InBattle = false,
	BattleHidden = false,
	TestMode = false,
	Dev = false, -- may use the DEV panel (DevAccess on the server)
	Mount = "pup",
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- fires (kind: "all" | "roll" | "decks" | "progress" | "meta", result?)

function State.ApplyFull(full)
	State.Cards = full.Cards or {}
	if full.Summary then
		State.Summary = full.Summary
	end
	if full.Decks then
		State.Decks = full.Decks
	end
	if full.Progress then
		State.Progress = full.Progress
	end
	if full.Battle then
		State.Battle = full.Battle
	end
	if type(full.Tower) == "table" then
		State.Tower = full.Tower
	end
	if full.Packs then
		State.Packs = full.Packs
	end
	if full.Mount then
		State.Mount = full.Mount -- the mount ridden last (PETS remembers it)
	end
	if full.Meta then
		State.Meta = full.Meta
		State.MetaAt = os.clock()
	end
	State.TestMode = full.TestMode == true
	State.Dev = full.Dev == true
	changed:Fire("all")
end

-- Progression update from the server; also refreshes the HUD numbers it changes.
function State.ApplyMeta(meta)
	State.Meta = meta
	State.MetaAt = os.clock()
	State.Summary.Shards = meta.Shards
	State.Summary.Luck = meta.Luck
	State.Summary.Cooldown = meta.Cooldown
	if meta.TraitShards then
		State.Summary.TraitShards = meta.TraitShards
	end
	if meta.Packs then
		State.Packs = meta.Packs
	end
	changed:Fire("meta")
end

-- Seconds left on a running potion, counted down locally between server updates.
function State.PotionLeft(id: string): number
	local seconds = State.Meta.Active[id]
	if seconds == nil then
		return 0
	end
	return math.max(0, seconds - (os.clock() - State.MetaAt))
end

local function liveActive()
	local active = {}
	for id in State.Meta.Active or {} do
		active[id] = State.PotionLeft(id)
	end
	return active
end

-- The server event running now (same clock and override as the server), with seconds left on it
-- and seconds until the next one.
function State.Event()
	local id = ReplicatedStorage:GetAttribute("DevEvent")
	local ends = ReplicatedStorage:GetAttribute("DevEventEnds")
	local override = if type(id) == "string" and type(ends) == "number" then { Id = id, Ends = ends } else nil
	return Meta.EventAt(workspace:GetServerTimeNow(), override)
end

-- Raid Luck right now (x2 for a while after the server clears a raid).
function State.RaidLuck(): number
	local ends = ReplicatedStorage:GetAttribute("RaidLuckEnds")
	return Raid.LuckAt(workspace:GetServerTimeNow(), if type(ends) == "number" then ends else nil)
end

-- A Server Luck Totem's luck right now.
function State.TotemLuck(): number
	local ends = ReplicatedStorage:GetAttribute("TotemLuckEnds")
	return if type(ends) == "number" and ends > workspace:GetServerTimeNow() then MonetizationConfig.Totem.Luck else 1
end

-- Whether a pass perk is on for this player (random perks only where paid random items are allowed).
function State.Perk(key: string, random: boolean?): boolean
	return State.Store.Passes[key] == true and (not random or not State.Store.Restricted)
end

-- Luck right now (base x the strongest running potion x the event x Raid Luck x Totem x VIP), matching
-- the server.
function State.Luck(): number
	local event = State.Event()
	local vip = if State.Perk("VIP", true) then MonetizationConfig.VipLuck else 1
	local eventLuck = (event and event.Luck or 1) * State.RaidLuck() * State.TotemLuck() * vip
	return Meta.TotalLuck(State.Meta.BaseLuck or 1, Meta.PotionLuck(liveActive()), eventLuck)
end

-- Today's tower mutator (the test tools can pick one; same as the server).
function State.Mutator(): Tower.Mutator
	local id = ReplicatedStorage:GetAttribute("DevMutator")
	return Tower.MutatorToday(Meta.DayNumber(os.time()), if State.TestMode and type(id) == "string" then id else nil)
end

function State.Cooldown(): number
	local event = State.Event()
	-- The Momentum chain and the Fast Roll pass, the same as the server.
	local momentum = State.Summary.Momentum
	local boost = {
		Momentum = if momentum then momentum.Speed else 0,
		Pass = if State.Perk("FastRoll") then MonetizationConfig.FastRollCut else 0,
	}
	return Meta.Cooldown(State.Meta.Upgrades or {}, liveActive(), event and event.Speed, State.Meta.Stats, State.Meta.Gear, boost)
end

-- Level progress from the Progress remote or the latest Meta.
function State.ApplyLevel(level)
	State.Meta.Level = { Level = level.Level, XP = level.XP, Need = level.Need }
	changed:Fire("level")
end

function State.SessionSeconds(): number
	return (State.Meta.SessionSeconds or 0) + (os.clock() - State.MetaAt)
end

-- Total rolls, kept current between progression updates.
function State.Rolls(): number
	return math.max(State.Summary.TotalRolls or 0, State.Meta.TotalRolls or 0)
end

function State.ApplyRoll(result)
	if result.CardId then
		local old = State.Cards[result.CardId] or {}
		State.Cards[result.CardId] = {
			Copies = result.Copies,
			Stars = result.Stars,
			Fusion = old.Fusion,
			Borders = result.Borders,
			BorderCopies = result.BorderCopies,
			Foils = result.Foils,
			Awaken = result.Awaken,
			Mastery = result.Mastery or old.Mastery,
			Trait2Unlocked = result.Trait2Unlocked or old.Trait2Unlocked,
			Trait = result.CardTrait,
			Trait2 = old.Trait2,
			Pending = old.Pending,
			Play = old.Play,
		}
	end
	for _, extra in result.Extra or {} do
		State.ApplyRoll(extra) -- surge / Triple Roll cards
	end
	if result.Quests then
		State.Meta.Quests = result.Quests
	end
	if result.Summary then
		State.Summary = result.Summary
	end
	changed:Fire("roll", result)
end

-- A card's entry after a fusion (from FusionService).
function State.ApplyCard(cardId: string, entry)
	State.Cards[cardId] = entry
	changed:Fire("cards")
end

function State.ApplyStore(store)
	State.Store = store
	changed:Fire("store")
end

function State.ApplyDecks(decks)
	State.Decks = decks
	changed:Fire("decks")
end

function State.ApplyProgress(progress)
	State.Progress = progress
	changed:Fire("progress")
end

function State.ApplyPacks(packs)
	State.Packs = packs or {}
	changed:Fire("packs")
end

function State.ApplyRaid(raid)
	State.Raid = raid
	changed:Fire("raid")
end

function State.ApplyTower(tower: { Best: number, Run: number, Pagoda: number })
	State.Tower = tower
	changed:Fire("progress")
end

function State.ActiveDeck()
	return State.Decks.Presets[State.Decks.Active]
end

function State.Owned(): number
	local n = 0
	for _ in State.Cards do
		n += 1
	end
	return n
end

return State
