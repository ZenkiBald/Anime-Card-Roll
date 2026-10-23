--!nonstrict
-- Kenji's first-session questline (Tutorial.luau has the quests). Progress is read from the save every
-- couple of seconds and pushed to the client (TutorialState) when it changes; events the save can't show
-- (a Trait Master roll, a pack condensed, a Stagger broken by a counter element) are noted as flags by
-- the services that see them (TutorialService.Note). CLAIM (Tutorial remote, "Claim") pays the open
-- quest, unlocks its title, and opens the next one (with its Supply, if any).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tutorial = require(Shared.Tutorial)
local Deck = require(Shared.Deck)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)

local TutorialService = {}

local limiter = RateLimit.new(2, 4)
local lastSent = {} -- [Player] = "step:count:ready" last pushed

local function save(data)
	local t = data.Tutorial
	if type(t) ~= "table" then
		t = { Step = 1, Flags = {}, Supplied = {} }
		data.Tutorial = t
	end
	t.Flags = t.Flags or {}
	t.Supplied = t.Supplied or {}
	return t
end

local function facts(data): Tutorial.Facts
	local deck = DeckService.Active(data)
	return {
		TotalRolls = data.TotalRolls,
		DeckCards = Deck.Count(deck, "Attack") + Deck.Count(deck, "Support"),
		Cleared = data.Progress.Cleared,
		Flags = save(data).Flags,
	}
end

-- The open quest's Supply, given once.
local function supply(data)
	local t = save(data)
	local quest = Tutorial.Steps[t.Step]
	if quest and quest.Supply and not t.Supplied[quest.Id] then
		t.Supplied[quest.Id] = true
		local have = data.Packs[quest.Supply.Pack] or 0
		if have < quest.Supply.Count then
			data.Packs[quest.Supply.Pack] = quest.Supply.Count
		end
	end
end

function TutorialService.State(data)
	local t = save(data)
	local f = facts(data)
	local count, goal = Tutorial.Progress(t.Step, f)
	return {
		Step = t.Step,
		Total = #Tutorial.Steps,
		Count = count,
		Goal = goal,
		Ready = Tutorial.Ready(t.Step, f),
		Done = Tutorial.Done(t.Step),
	}
end

local function push(player: Player, force: boolean?)
	local profile = DataService.Get(player)
	if profile == nil then
		return
	end
	local state = TutorialService.State(profile.Data)
	local key = `{state.Step}:{state.Count}:{tostring(state.Ready)}`
	if force or lastSent[player] ~= key then
		lastSent[player] = key
		Remotes.TutorialState:FireClient(player, state)
	end
end

-- Something a Flag quest counts happened (any time: a quest done early finishes as it opens).
function TutorialService.Note(player: Player, flag: string)
	local profile = DataService.Get(player)
	if profile == nil then
		return
	end
	local t = save(profile.Data)
	if not t.Flags[flag] then
		t.Flags[flag] = true
		push(player)
	end
end

local function claim(player: Player)
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	local data = profile.Data
	local t = save(data)
	local quest = Tutorial.Steps[t.Step]
	if quest == nil then
		return { Ok = false, Reason = "Done" }
	end
	if not Tutorial.Ready(t.Step, facts(data)) then
		return { Ok = false, Reason = "NotReady" }
	end
	local granted = MetaService.Grant(data, quest.Reward, player)
	if quest.Title then
		data.Titles = data.Titles or {}
		data.Titles[quest.Title] = true
		if (data.Settings.Title or "") == "" then
			data.Settings.Title = quest.Title -- the first title is worn straight away
		end
	end
	t.Step += 1
	supply(data)
	lastSent[player] = nil
	return {
		Ok = true,
		Claimed = quest.Id,
		Granted = granted,
		Title = quest.Title,
		State = TutorialService.State(data),
		Meta = MetaService.State(player, data),
	}
end

function TutorialService.Start()
	Remotes.Tutorial.OnServerInvoke = function(player: Player, action: unknown)
		if action == "State" then
			local profile = DataService.WaitFor(player, 20)
			if profile == nil then
				return { Ok = false, Reason = "Loading" }
			end
			supply(profile.Data)
			local state = TutorialService.State(profile.Data)
			state.Ok = true
			return state
		elseif action == "Claim" then
			if not limiter:Allow(player) then
				return { Ok = false, Reason = "TooFast" }
			end
			return claim(player)
		end
		return { Ok = false, Reason = "BadRequest" }
	end
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile and not Tutorial.Done(save(profile.Data).Step) then
					push(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
end

return TutorialService
