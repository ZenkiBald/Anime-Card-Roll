--!nonstrict
-- Client entry point: loads the player's state, builds the screens and wires the buttons.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Skin = require(UI.Skin)
local Hud = require(UI.Hud)
local Reveal = require(UI.Reveal)
local Index = require(UI.Index)
local Bag = require(UI.Bag)
local StatsPanel = require(UI.Stats)
local Shop = require(UI.Shop)
local Gifts = require(UI.Gifts)
local Travel = require(UI.Travel)
local Settings = require(UI.Settings)
local Fusion = require(UI.Fusion)
local Title = require(UI.Title)
local Pets = require(UI.Pets)
local Wheel = require(UI.Wheel)
local Dash = require(script.Parent.Dash)
local Followers = require(script.Parent.Followers)
local OddsPanel = require(UI.OddsPanel)
local DevPanel = require(UI.DevPanel)
local DeckBuilder = require(UI.DeckBuilder)
local BossScreen = require(UI.BossScreen)
local Battle = require(UI.Battle)
local State = require(script.Parent.State)
local HubFx = require(script.Parent.HubFx)
local ZoneFx = require(script.Parent.ZoneFx)
local Sfx = require(UI.Sfx)
local MetaClient = require(script.Parent.MetaClient)
local Meta = require(Shared.Meta)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The backpack isn't used in this game.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Phones and tablets start on lighter effects; SETTINGS switches.
Theme.FxLow = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The title screen covers the loading; PLAY unlocks at the end of this script.
Title.Show(playerGui)

-- Load state (the server waits for the save to load).
local function loadState()
	for _ = 1, 10 do
		local ok, result = pcall(function()
			return Remotes.GetState:InvokeServer()
		end)
		if ok and result and result.Ok then
			State.ApplyFull(result)
			return true
		end
		task.wait(1)
	end
	return false
end
if not loadState() then
	warn("Could not load player state")
end

-- Roll handling ----------------------------------------------------------------
local busy = false -- true while a request is in flight or a full reveal is showing
local lastRollAt = 0 -- os.clock() of our last accepted roll
local autoWanted = false -- what the player last asked Auto Roll to be

local REASONS = {
	Cooldown = "Rolling too fast",
	Locked = "Locked for now",
	AutoActive = "Turn off Auto Roll first",
	Loading = "Still loading your cards",
}

local function requestRoll(mode: string)
	if State.InBattle or Title.IsOpen() then
		return
	end
	if busy or Reveal.IsBusy() or State.Summary.AutoActive then
		if State.Summary.AutoActive then
			Hud.Hint(REASONS.AutoActive)
		end
		return
	end
	busy = true
	Sfx.Play("Whoosh", if mode == "Full" then 0.9 else 1.15)
	-- If a reveal was tapped away early, wait out the rest of the cooldown instead of being refused.
	local wait = State.Cooldown() - (os.clock() - lastRollAt)
	if wait > 0 then
		task.wait(wait)
	end
	local ok, result = pcall(function()
		return Remotes.Roll:InvokeServer(mode)
	end)
	if not ok or not result or not result.Ok then
		busy = false
		local reason = if ok and result then result.Reason else nil
		Hud.Hint(REASONS[reason] or "Roll failed, try again")
		return
	end

	lastRollAt = os.clock()
	State.ApplyRoll(result)
	Hud.StartCooldown(State.Cooldown())

	if mode == "Full" then
		Reveal.Full(result, function()
			busy = false
		end)
	else
		Reveal.Quick(result)
		Hud.FeedAdd(result)
		task.delay(State.Cooldown(), function()
			busy = false
		end)
	end
end

local function toggleAuto()
	local on = not State.Summary.AutoActive
	autoWanted = on
	State.Summary.AutoActive = on -- optimistic; the server confirms with each result
	Hud.SetAuto(on)
	Remotes.SetAuto:FireServer(on, State.Summary.AutoStop)
	if on then
		Hud.Hint("Auto Roll on")
	end
end

local function cycleAutoStop()
	local options = Config.AutoStopOptions
	local index = table.find(options, State.Summary.AutoStop) or 1
	State.Summary.AutoStop = options[index % #options + 1]
	-- Tell the server without changing whether Auto Roll is running.
	Remotes.SetAuto:FireServer(nil, State.Summary.AutoStop)
	Hud.Refresh()
end

Remotes.AutoResult.OnClientEvent:Connect(function(result)
	if result.Ok == false then
		autoWanted = false
		State.Summary.AutoActive = false
		Hud.SetAuto(false)
		Hud.Hint(REASONS[result.Reason] or "Auto Roll stopped")
		return
	end
	if result.Stopped then
		autoWanted = false
	end
	-- A result already on its way when the player switched Auto Roll off must not switch it back on.
	result.Summary.AutoActive = autoWanted
	lastRollAt = os.clock()
	State.ApplyRoll(result)
	Hud.StartCooldown(State.Cooldown())
	Hud.FeedAdd(result)
	if State.InBattle then
		return -- during a fight Auto Roll results only go to the feed
	end
	if result.Stopped then
		Hud.Hint(`Auto Roll stopped: {result.Rarity}!`)
		Reveal.Full(result)
	else
		Reveal.Quick(result)
	end
end)

Remotes.Announce.OnClientEvent:Connect(function(playerName: string, cardId: string, borderId: string?)
	Hud.Announce(playerName, cardId, borderId)
end)

-- Build screens -------------------------------------------------------------------
Reveal.Init(playerGui)
OddsPanel.Init(playerGui)
Index.Init(playerGui, OddsPanel.Toggle)
Bag.Init(playerGui)
StatsPanel.Init(playerGui)
Shop.Init(playerGui)
Gifts.Init(playerGui)
Travel.Init(playerGui, function(text)
	Hud.Hint(text)
end)
Settings.Init(playerGui)
Fusion.Init(playerGui)
Pets.Init(playerGui, function(text)
	Hud.Hint(text)
end)
Wheel.Init(playerGui)
Dash.Start(Title.IsOpen)
Followers.Start()
DeckBuilder.Init(playerGui)
BossScreen.Init(playerGui, {
	EditDeck = function()
		DeckBuilder.Open(function()
			BossScreen.Open()
		end)
	end,
	Fight = Battle.Start,
})
if State.TestMode then
	DevPanel.Init(playerGui)
end

-- Character controls (and the mobile thumbstick) are off while a fight is on screen.
local controls = nil
task.spawn(function()
	local ok, result = pcall(function()
		-- Roblox's default PlayerModule is added at runtime, so it isn't in the sourcemap.
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return (require :: any)(playerModule):GetControls()
	end)
	if ok then
		controls = result
	end
end)

Battle.Init(playerGui, {
	OnStart = function()
		Hud.SetBattleMode(true)
		Sfx.SetMusicOverride("Battle")
		if controls then
			controls:Disable()
		end
	end,
	OnEnd = function()
		Hud.SetBattleMode(false)
		Sfx.SetMusicOverride(nil)
		if controls then
			controls:Enable()
		end
	end,
})

-- Hub NPCs: bosses open the boss screen, Kenji the Card Sage gives tips, Hoshi fuses, Madame Fortuna spins the
-- wheel, and the tower gate opens the boss screen's TOWER tab.
HubFx.Start()
-- Music and lighting follow the zone you walk into.
ZoneFx.Start()
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if State.InBattle then
		return
	end
	local bossId = prompt:GetAttribute("BossId")
	if type(bossId) == "string" then
		BossScreen.Open(bossId)
	elseif prompt:GetAttribute("Npc") == "sage" then
		HubFx.SageTalk(prompt)
	elseif prompt:GetAttribute("Npc") == "fuser" then
		Fusion.Open()
	elseif prompt:GetAttribute("Npc") == "wheel" then
		Wheel.Open()
	elseif prompt:GetAttribute("Npc") == "tower" then
		BossScreen.OpenTower()
	end
end)

Hud.Init(playerGui, {
	OnRoll = function()
		requestRoll("Full")
	end,
	OnQuick = function()
		requestRoll("Quick")
	end,
	OnAuto = toggleAuto,
	OnAutoStop = cycleAutoStop,
	OnDeck = DeckBuilder.Toggle,
	OnBattle = BossScreen.Toggle,
	OnIndex = Index.Toggle,
	OnBag = Bag.Toggle,
	OnStats = StatsPanel.Toggle,
	OnShop = Shop.Toggle,
	OnGifts = Gifts.Toggle,
	OnOdds = OddsPanel.Toggle,
	OnTravel = Travel.Toggle,
	OnSettings = Settings.Toggle,
	OnPets = Pets.Toggle,
	OnDev = if State.TestMode then DevPanel.Toggle else nil,
})

State.Changed:Connect(function()
	Hud.Refresh()
end)
Reveal.OnBusy = Hud.SetRevealMode

-- Red badges: rewards ready in GIFTS and INDEX, potions to use in the BAG, stat points to spend.
Hud.SetBadgeSource(function()
	return {
		GIFTS = MetaClient.GiftsClaimable(),
		INDEX = MetaClient.IndexClaimable(),
		BAG = MetaClient.PotionCount(),
		STATS = State.Meta.StatPoints or 0,
	}
end)
Hud.RefreshBadges()

-- XP and level-ups from the server: the bar moves, and a level-up gets its celebration.
Remotes.Progress.OnClientEvent:Connect(function(progress)
	if progress.Meta then
		State.ApplyMeta(progress.Meta)
	end
	State.ApplyLevel(progress)
	Hud.RefreshLevel()
	if progress.Ups then
		Sfx.Play("Upgrade")
		Sfx.Sting("Epic", true)
		Hud.LevelUp(progress.Ups)
	end
end)

-- Anything granted (gifts, Index, daily) pops a reward toast.
MetaClient.OnGranted = function(bundle)
	Hud.Reward(Meta.Describe(bundle))
end

-- Test phase: report UI skin images that don't load (wrong id or still in moderation).
if State.TestMode then
	task.spawn(function()
		local failed = Skin.Verify(playerGui)
		if #failed > 0 then
			warn(`[Skin] {#failed} UI image(s) failed to load:\n  ` .. table.concat(failed, "\n  "))
			Hud.Hint(`{#failed} UI images didn't load: see Output`)
		end
	end)
end

-- Everything's built: PLAY unlocks (the HUD waits behind it). After it, welcome back: point at the
-- daily reward.
Hud.SetVisible(not Title.IsOpen())
Title.Ready(function()
	Hud.SetVisible(true)
	if State.Meta.Daily and State.Meta.Daily.CanClaim then
		task.delay(0.8, function()
			Hud.Hint(`Daily reward ready: day {State.Meta.Daily.Day} of 7. Open GIFTS!`)
		end)
	end
end)

-- Keyboard shortcuts on PC: R = Roll, T = Quick Roll, E = Auto Roll, G = ride / get off (Q is Dash).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or Title.IsOpen() then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		requestRoll("Full")
	elseif input.KeyCode == Enum.KeyCode.T then
		requestRoll("Quick")
	elseif input.KeyCode == Enum.KeyCode.E then
		toggleAuto()
	elseif input.KeyCode == Enum.KeyCode.G then
		Pets.ToggleRide()
	end
end)

-- Refresh unlock countdowns once a second when the unlock rules are on.
if Config.Unlocks.Enabled then
	task.spawn(function()
		while true do
			task.wait(1)
			State.Summary.Playtime += 1
			Hud.Refresh()
		end
	end)
end

