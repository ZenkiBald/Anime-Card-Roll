--!nonstrict
-- The client's copy of the player's data. The server is the source of truth;
-- this mirrors what it last sent so the UI can draw without asking again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meta"))

local State = {
	Cards = {}, -- [cardId] = { Copies, Stars }
	Summary = {
		TotalRolls = 0,
		Shards = 0,
		Pity = { Epic = 0, Legendary = 0 },
		Luck = 1,
		AutoStop = "Legendary",
		AutoActive = false,
		Playtime = 0,
		Unlocked = { QuickRoll = true, AutoRoll = true },
	},
	Decks = { Active = 1, Presets = {} }, -- presets: { Attack = {4 ids}, Support = {4 ids} }, "" = empty
	Progress = { Cleared = {}, BestTime = {} },
	Tower = 0, -- highest Infinite Tower floor cleared
	RollBank = {}, -- saved reward rolls: Rewards.TicketKey -> count
	Battle = { AutoUlt = false, Speed = 1 },
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
	},
	MetaAt = os.clock(), -- when Meta arrived; timers count down from here
	InBattle = false,
	TestMode = false,
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
	if full.Tower then
		State.Tower = full.Tower
	end
	if full.RollBank then
		State.RollBank = full.RollBank
	end
	if full.Mount then
		State.Mount = full.Mount -- the mount ridden last (PETS remembers it)
	end
	if full.Meta then
		State.Meta = full.Meta
		State.MetaAt = os.clock()
	end
	State.TestMode = full.TestMode == true
	changed:Fire("all")
end

-- Progression update from the server; also refreshes the HUD numbers it changes.
function State.ApplyMeta(meta)
	State.Meta = meta
	State.MetaAt = os.clock()
	State.Summary.Shards = meta.Shards
	State.Summary.Luck = meta.Luck
	State.Summary.Cooldown = meta.Cooldown
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

-- Luck right now (base x the strongest running potion x the event), matching what the server uses.
function State.Luck(): number
	local event = State.Event()
	return Meta.TotalLuck(State.Meta.BaseLuck or 1, Meta.PotionLuck(liveActive()), event and event.Luck)
end

function State.Cooldown(): number
	local event = State.Event()
	return Meta.Cooldown(State.Meta.Upgrades or {}, liveActive(), event and event.Speed, State.Meta.Stats, State.Meta.Gear)
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
		State.Cards[result.CardId] = { Copies = result.Copies, Stars = result.Stars, Fusion = result.Fusion, Borders = result.Borders }
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
	State.Cards[cardId] = { Copies = entry.Copies, Stars = entry.Stars, Fusion = entry.Fusion, Borders = entry.Borders }
	changed:Fire("cards")
end

function State.ApplyDecks(decks)
	State.Decks = decks
	changed:Fire("decks")
end

function State.ApplyProgress(progress)
	State.Progress = progress
	changed:Fire("progress")
end

function State.ApplyBank(bank)
	State.RollBank = bank or {}
	changed:Fire("bank")
end

function State.ApplyTower(floor: number)
	State.Tower = floor
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
