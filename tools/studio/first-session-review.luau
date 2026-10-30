-- Temporary Script during Studio Play only. Never run in Edit or publish this harness.
-- Services see an independent in-memory profile; ProfileStore retains its original Data table.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsRunning(), "Studio Play only")
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Server = game.ServerScriptService.Server
local Data = require(Server.DataService)
local Config = require(Shared.Config)
local Migration = require(Server.SaveMigration)
local Http = game:GetService("HttpService")
local player = assert(Players:GetPlayers()[1], "Start Play first")
local original = { Get=Data.Get, WaitFor=Data.WaitFor, Playtime=Data.Playtime,
	SessionSeconds=Data.SessionSeconds, TestMode=Config.TestMode, Unlocks=Config.Unlocks.Enabled }
local baseline = assert(Data.WaitFor(player, 20), "Wait for the original profile")
local cardsBefore, decksBefore = Http:JSONEncode(baseline.Data.Cards), Http:JSONEncode(baseline.Data.Decks)
local fresh = { Data=Data.Template() }
Migration.Migrate(fresh.Data)
local started = os.clock()
Data.Get = function(who)
	-- Persistent leaderboard writers must keep reading the original score, never the test progress.
	local caller = debug.info(2, "s")
	if who == player and not string.find(caller, "LeaderboardService", 1, true) then return fresh end
	return original.Get(who)
end
Data.WaitFor = function(who, timeout)
	if who == player then return fresh end
	return original.WaitFor(who, timeout)
end
Data.Playtime = function(who)
	if who == player then return os.clock() - started end
	return original.Playtime(who)
end
Data.SessionSeconds = function(who)
	if who == player then return os.clock() - started end
	return original.SessionSeconds(who)
end
Config.TestMode = false
Config.Unlocks.Enabled = true
local function control(name, callback)
	local bindable = Instance.new("BindableFunction")
	bindable.Name = name
	bindable.OnInvoke = callback
	bindable.Parent = script
end
control("Seed", function(data)
	fresh.Data = data or Data.Template()
	Migration.Migrate(fresh.Data)
	started = os.clock()
	return true
end)
control("Snapshot", function() return Http:JSONEncode(fresh.Data) end)
control("Restore", function()
	Data.Get = original.Get; Data.WaitFor = original.WaitFor
	Data.Playtime = original.Playtime; Data.SessionSeconds = original.SessionSeconds
	Config.TestMode = original.TestMode; Config.Unlocks.Enabled = original.Unlocks
	local restored = original.Get(player) == baseline
	local cardsKept = Http:JSONEncode(baseline.Data.Cards) == cardsBefore
	local decksKept = Http:JSONEncode(baseline.Data.Decks) == decksBefore
	print("[FreshPlaytest] Restore", restored, "Original cards", cardsKept, "Original decks", decksKept)
	return { Restored=restored, OriginalCards=cardsKept, OriginalDecks=decksKept }
end)
script:SetAttribute("Ready", true)
print("[FreshPlaytest] In-memory profile ready; invoke Restore before stopping Play")
