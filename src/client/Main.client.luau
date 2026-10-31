--!nonstrict
-- Client entry point: loads the player's state, builds the screens and wires the buttons.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Borders = require(Shared.Borders)
local Cards = require(Shared.Cards)
local Odds = require(Shared.Odds)
local Deck = require(Shared.Deck)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = script.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Skin = require(UI.Skin)
local Hud = require(UI.Hud)
local Reveal = require(UI.Reveal)
local Index = require(UI.Index)
local Bag = require(UI.Bag)
local StatsPanel = require(UI.Stats)
local Gifts = require(UI.Gifts)
local CollectionsUi = require(UI.Collections)
local WeatherUi = require(UI.Weather)
local Journey = require(UI.Journey)
local Travel = require(UI.Travel)
local Settings = require(UI.Settings)
local Fusion = require(UI.Fusion)
local Title = require(UI.Title)
local Pets = require(UI.Pets)
local Wheel = require(UI.Wheel)
local PlayerList = require(UI.PlayerList)
local Profile = require(UI.Profile)
local TutorialUi = require(UI.Tutorial)
local Alchemy = require(UI.Alchemy)
local Modal = require(UI.Modal)
local Dash = require(script.Parent.Dash)
local Followers = require(script.Parent.Followers)
local Avatars = require(script.Parent.Avatars)
local CardTooltip = require(UI.CardTooltip)
local OddsPanel = require(UI.OddsPanel)
local DevPanel = require(UI.DevPanel)
local DeckBuilder = require(UI.DeckBuilder)
local ElementGuide = require(UI.ElementGuide)
local TraitMaster = require(UI.TraitMaster)
local Store = require(UI.Store)
local BossScreen = require(UI.BossScreen)
local Battle = require(UI.Battle)
local State = require(script.Parent.State)
local HubFx = require(script.Parent.HubFx)
local ZoneFx = require(script.Parent.ZoneFx)
local SkyFx = require(script.Parent.SkyFx)
local LightingSetup = require(script.Parent.LightingSetup)
local Sfx = require(UI.Sfx)
local MetaClient = require(script.Parent.MetaClient)
local Meta = require(Shared.Meta)
local Packs = require(Shared.Packs)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The backpack isn't used in this game.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Phones and tablets start on lighter effects; SETTINGS switches.
Theme.FxLow = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Twilight lighting, bloom, grade and haze (ZoneFx shifts it per zone from here).
LightingSetup.Apply()

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

local showExtras -- below

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
	-- If a reveal was tapped away early, wait out the rest of the cooldown instead of being refused. A tap
	-- made while the cooldown still runs is an Early input: it never counts as a perfect Overcharge Surge
	-- (that needs a clean tap after the surge ring lights up).
	local wait = State.Cooldown() - (os.clock() - lastRollAt)
	local early = wait > 0
	if early then
		task.wait(wait)
	end
	local ok, result = pcall(function()
		return Remotes.Roll:InvokeServer(mode, early)
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
	Hud.FeedAdd(result)
	showExtras(result)

	if not Reveal.Batch(result, function() busy = false end) then
		task.delay(State.Cooldown(), function()
			busy = false
		end)
	end
end

-- Surge and Triple Roll cards: the extras go to the feed, and a surge gets its callout.
function showExtras(result, automatic)
	for _, extra in result.Extra or {} do
		Hud.FeedAdd(extra)
	end
	if result.Surge == "Perfect" then
		Sfx.Sting("Epic", true)
		Hud.Hint(`⚡ PERFECT OVERCHARGE SURGE! {1 + #(result.Extra or {})} cards at 6x border odds`)
	elseif result.Surge == "Plain" then
		Hud.Hint("⚡ OVERCHARGE SURGE! 5x border odds (tap inside the surge window for a perfect one)")
	elseif result.TripleRoll and not automatic then
		Hud.Hint(`TRIPLE ROLL · {result.BatchCount or 3} cards{if (result.SkyCount or 0) > 0 then ` + {result.SkyCount} sky bonus` else ""}`)
	elseif (result.SkyCount or 0) > 0 then
		Hud.Hint(`SKY DISCOVERY · {result.SkyCount} bonus card{if result.SkyCount == 1 then "" else "s"}`)
	end
end

-- ROLL plays the full reveal, or the short one while QUICK is on (saved in Settings.QuickRoll).
local function rollMode(): string
	return if State.Meta.QuickRoll then "Quick" else "Full"
end

local function toggleQuick()
	local on = not State.Meta.QuickRoll
	State.Meta.QuickRoll = on -- optimistic; the server saves it
	Hud.SetQuick(on)
	Hud.Hint(if on then "⚡ QUICK ROLL on: rolls skip the long reveal" else "Quick Roll off")
	task.spawn(function()
		local result = MetaClient.Call("SetQuickRoll", on)
		if not result.Ok then
			State.Meta.QuickRoll = not on
			Hud.SetQuick(not on)
		end
	end)
end

local function toggleAuto()
	local on = not State.Summary.AutoActive
	autoWanted = on
	State.Summary.AutoActive = on -- optimistic; the server confirms with each result
	Hud.SetAuto(on)
	Remotes.SetAuto:FireServer(on)
	if on then
		Hud.Hint("Auto Roll on")
	end
end

Remotes.AutoResult.OnClientEvent:Connect(function(result)
	if result.SummaryOnly then
		-- e.g. the Momentum chain broke
		local active = State.Summary.AutoActive
		State.Summary = result.Summary
		State.Summary.AutoActive = active
		Hud.Refresh()
		return
	end
	if result.Ok == false then
		autoWanted = false
		State.Summary.AutoActive = false
		Hud.SetAuto(false)
		Hud.Hint(REASONS[result.Reason] or "Auto Roll stopped")
		return
	end
	-- A result already on its way when the player switched Auto Roll off must not switch it back on.
	result.Summary.AutoActive = autoWanted
	lastRollAt = os.clock()
	State.ApplyRoll(result)
	Hud.StartCooldown(State.Cooldown())
	Hud.FeedAdd(result)
	showExtras(result, true)
	if State.InBattle or Modal.AnyOpen() then
		return -- reading panels and hidden fights must not be interrupted by auto reveals
	end
	-- Auto Roll never stops: a Rainbow / Secret pull plays its full reveal (Reveal.Quick hands it over)
	-- while the server holds the next roll for it, then rolling carries on.
	Reveal.Batch(result)
end)

-- Pulls rarer than 1 in 10,000,000 (card x border, Cards.Rarity) also get a system line in the chat;
-- 1 in a billion and rarer get the highlighted BILLION-tier line.
local function chatAnnounce(playerName: string, cardId: string, borderId: string?, global: boolean?)
	local card = Cards.Get(cardId)
	local rarity = if card then Cards.Rarity(cardId, borderId) else 0
	if card == nil or rarity < Config.ChatAnnounceFrom then
		return
	end
	local border = Borders.Get(borderId)
	local name = string.gsub(playerName, "[<>&]", "")
	local where = if global then "[GLOBAL] " else "[SERVER] "
	local text = if rarity >= Config.ChatBillionFrom
		then `<font color="#FF4FD8"><b>{where}BILLION PULL! {name} rolled {string.upper(border.Name)} {card.Name} (1 in {Kit.commas(Odds.Round(rarity))})!</b></font>`
		else `<font color="#{border.Color:ToHex()}">{where}{name} rolled {border.Name} {card.Name} (1 in {Kit.commas(Odds.Round(rarity))})!</font>`
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(text)
		end
	end)
end

Remotes.Announce.OnClientEvent:Connect(function(playerName: string, cardId: string, borderId: string?, foilId: string?, global: boolean?)
	Hud.Announce(playerName, cardId, borderId, foilId, global)
	chatAnnounce(playerName, cardId, borderId, global)
end)

-- STORE: pass ownership and the Luck Totem (MonetizationService).
Remotes.StoreState.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	if message.Totem then
		Sfx.Sting("Mythic", true)
		Hud.Hint(`🗿 {message.Totem.Buyer} raised a Server Luck Totem: x2 luck for everyone!`)
		Hud.RefreshRaid()
		Hud.Refresh()
		return
	end
	State.ApplyStore(message)
	Hud.Refresh()
end)
task.spawn(function()
	local ok, store = pcall(function()
		return Remotes.Store:InvokeServer("State")
	end)
	if ok and type(store) == "table" and store.Ok then
		State.ApplyStore(store)
	end
end)

-- Build screens -------------------------------------------------------------------
-- Tabbed panels: SQUAD (deck, Index, upgrades = stat points + Shard upgrades), QUESTS (Kenji's path,
-- daily quests and gifts) and Hoshi's (fusion, pack alchemy: only from Hoshi in town).
local squadPanel = Modal.Tabbed(playerGui, "SquadGui", "SQUAD", Vector2.new(0.96, 0.92), Vector2.new(1300, 820), { "DECK", "INDEX", "UPGRADES" })
local questsPanel = Modal.Tabbed(playerGui, "QuestsGui", "QUESTS", Vector2.new(0.86, 0.88), Vector2.new(980, 740), { "GOALS", "KENJI'S PATH", "DAILY & GIFTS" })
local hoshiPanel = Modal.Tabbed(playerGui, "HoshiGui", "HOSHI · FUSION MASTER", Vector2.new(0.88, 0.88), Vector2.new(1040, 720), { "FUSION", "PACK ALCHEMY" })
Reveal.Init(playerGui)
OddsPanel.Init(playerGui)
Index.Init(playerGui, OddsPanel.Toggle, squadPanel)
Bag.Init(playerGui)
StatsPanel.Init(playerGui, squadPanel)
squadPanel:SetTabText("UPGRADES","TRAINING")
Gifts.Init(playerGui, questsPanel)
CollectionsUi.Init(playerGui)
Journey.Init(questsPanel, function(goal)
	if goal.Action == "Squad" then
		squadPanel:Show("DECK")
	else
		BossScreen.OpenGoal(goal.Action, goal.Boss, goal.Difficulty)
	end
end)
Travel.Init(playerGui, function(text)
	Hud.Hint(text)
end)
Settings.Init(playerGui)
Fusion.Init(playerGui, hoshiPanel)
Alchemy.Init(hoshiPanel)
Pets.Init(playerGui, function(text)
	Hud.Hint(text)
end)
Wheel.Init(playerGui)
PlayerList.SetHidden("Title", Title.IsOpen())
Profile.Init(playerGui, Index.Toggle)
PlayerList.Init(playerGui, Profile.Open, Settings.Toggle)
Dash.Start(Title.IsOpen)
Followers.Start()
Avatars.Start()
CardTooltip.Init(playerGui)
ElementGuide.Init(playerGui)
TraitMaster.Init(playerGui)
Store.Init(playerGui, OddsPanel.Toggle)
DeckBuilder.Init(playerGui, squadPanel)
BossScreen.Init(playerGui, {
	EditDeck = function(target)
		DeckBuilder.Open(function()
			BossScreen.Open()
		end, target)
	end,
	Fight = Battle.Start,
})
if State.Dev then
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
		Dash.SetBattleMode(true)
		HubFx.SetWorldLabelsHidden("Battle", true)
		PlayerList.SetHidden("Battle", true)
		Sfx.SetMusicOverride("Battle")
		if controls then
			controls:Disable()
		end
	end,
	OnEnd = function()
		Hud.SetBattleMode(false)
		Dash.SetBattleMode(false)
		HubFx.SetWorldLabelsHidden("Battle", false)
		PlayerList.SetHidden("Battle", false)
		Sfx.SetMusicOverride(nil)
		if controls then
			controls:Enable()
		end
	end,
})

-- Hub NPCs: bosses open the boss screen, Kenji the Card Sage gives tips, Hoshi fuses, Madame Fortuna spins the
-- wheel, and the tower gate opens the boss screen's TOWER tab.
HubFx.Start()
Modal.Changed:Connect(function(anyOpen: boolean)
	HubFx.SetWorldLabelsHidden("Modal", anyOpen)
	-- The HUD and server list step away behind a panel, and quick roll pops wait (the pulls still land).
	Hud.SetPanelOpen(anyOpen)
	PlayerList.SetHidden("Modal", anyOpen)
end)
Reveal.Muted = Modal.AnyOpen
-- Music and lighting follow the zone you walk into.
ZoneFx.Start()
SkyFx.Start()
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if State.InBattle then
		return
	end
	local bossId = prompt:GetAttribute("BossId")
	if type(bossId) == "string" then
		BossScreen.Open(bossId)
	elseif prompt:GetAttribute("Npc") == "sage" then
		-- While his questline runs, Kenji opens KENJI'S PATH; after it, he's back to tips.
		if not TutorialUi.Open() then
			HubFx.SageTalk(prompt)
		end
	elseif prompt:GetAttribute("Npc") == "fuser" then
		Fusion.Open()
	elseif prompt:GetAttribute("Npc") == "collector" then
		CollectionsUi.Open()
	elseif prompt:GetAttribute("Npc") == "traitmaster" then
		TraitMaster.Open()
	elseif prompt:GetAttribute("Npc") == "wheel" then
		Wheel.Open()
	elseif prompt:GetAttribute("Npc") == "tower" then
		BossScreen.OpenTower()
	end
end)

Hud.Init(playerGui, {
	OnRoll = function()
		requestRoll(rollMode())
	end,
	OnQuick = toggleQuick,
	OnAuto = toggleAuto,
	-- Six direct buttons. Fusion, alchemy, the wheel and traits are only at their NPCs in town.
	OnBattle = BossScreen.Toggle,
	OnBag = Bag.Toggle,
	OnSquad = function()
		if squadPanel.IsOpen then
			squadPanel:Close()
		else
			squadPanel:Show(squadPanel.Current)
		end
	end,
	OnQuests = function()
		if questsPanel.IsOpen then
			questsPanel:Close()
		else
			-- Keep the reason to build a team visible; Kenji's tracker still opens his own path.
			questsPanel:Show("GOALS")
		end
	end,
	OnTravel = Travel.Toggle,
	OnStore = Store.Toggle,
	OnOdds = OddsPanel.Toggle,
	OnPets = Pets.Toggle,
	OnRaid = BossScreen.OpenRaid,
	OnDev = if State.Dev then DevPanel.Toggle else nil, -- only for test tool users (DevAccess)
})

WeatherUi.Init(playerGui)

State.Changed:Connect(function(kind)
	if kind ~= "raid" then
		Hud.Refresh()
	end
end)

-- Nudges: AUTO-BUILD would make a deck at least this much stronger than the active one (a SQUAD badge and
-- one hint each time it becomes true), and a card reached the copies to fuse (one hint, fusing is at Hoshi).
local BETTER_DECK = 1.05
local function deckGain(): number
	local active = State.ActiveDeck()
	local now = if active then Deck.Power(active, State.Cards) else 0
	local best = Deck.BestPower(Deck.AutoBuild(State.Cards), State.Cards)
	return if now > 0 then best / now else (if best > 0 then math.huge else 1)
end
local betterDeck, fuseReady = false, 0
local function checkNudges(announce: boolean)
	local gain = deckGain()
	local better = gain >= BETTER_DECK
	local ready = Fusion.ReadyCount()
	if announce and better and not betterDeck then
		local pct = if gain == math.huge then "" else ` (+{math.floor((gain - 1) * 100 + 0.5)}% power)`
		Hud.Hint(`⚡ A stronger deck is ready{pct}: SQUAD > AUTO-BUILD`)
	elseif announce and ready > fuseReady then
		Hud.Hint(`🔥 {ready} card{if ready == 1 then "" else "s"} can fuse to the next border: see Hoshi in town`)
	end
	betterDeck, fuseReady = better, ready
end
State.Changed:Connect(function(kind)
	if kind == "roll" or kind == "cards" or kind == "decks" or kind == "all" then
		checkNudges(kind ~= "all")
		Hud.RefreshBadges()
	end
end)

-- Server raids: the live state (pool, timer, top hitters) and, when a raid ends, this player's payout.
Remotes.RaidState.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	if message.State then
		State.ApplyRaid(message.State)
		Hud.RefreshRaid()
	end
	local payout = message.Payout
	if payout then
		local reward = payout.Reward
		if reward then
			if reward.Packs then
				State.ApplyPacks(reward.Packs)
			end
			if reward.Meta then
				State.ApplyMeta(reward.Meta)
			end
			if reward.Summary then
				State.Summary = reward.Summary
			end
		end
		local loot = reward and reward.Bundle and Meta.Describe(reward.Bundle) or ""
		if reward and reward.NewPacks then
			loot = `{Packs.Describe(reward.NewPacks)}  {loot}`
		end
		if payout.Away then
			local minutes = math.floor(payout.Away / 60)
			Sfx.Play("Reward")
			loot = `Away {minutes // 60}h {minutes % 60}m · {loot}`
		elseif payout.Offline then
			Sfx.Play("Reward")
			Hud.Hint(`⚔️ While you were away, {payout.Name} was cleared: your share is in your BAG!`)
		elseif payout.Cleared then
			Sfx.Play("Victory")
			Hud.Hint(`⚔️ RAID CLEARED: {payout.Name}! You were #{payout.Rank} of {payout.Hitters}{if payout.Top then " (TOP HITTER!)" else ""}`)
		else
			Hud.Hint(`The raid on {payout.Name} ran out of time. You were #{payout.Rank} of {payout.Hitters}.`)
		end
		Hud.Reward(loot)
		Hud.RefreshBadges()
	end
end)
task.spawn(function()
	local ok, raid = pcall(function()
		return Remotes.RaidInfo:InvokeServer()
	end)
	if ok and type(raid) == "table" then
		State.ApplyRaid(raid)
		Hud.RefreshRaid()
	end
end)
Reveal.OnBusy = function(on: boolean)
	Hud.SetRevealMode(on)
	HubFx.SetWorldLabelsHidden("Reveal", on)
	PlayerList.SetHidden("Reveal", on)
end

-- Red badges: gifts and Kenji's quest ready in QUESTS, Index rewards, stat points and a stronger AUTO-BUILD in SQUAD, potions
-- and packs in the BAG.
Hud.SetBadgeSource(function()
	return {
		QUESTS = MetaClient.GiftsClaimable() + (if TutorialUi.Ready() then 1 else 0),
		SQUAD = MetaClient.IndexClaimable() + (State.Meta.StatPoints or 0) + (if betterDeck then 1 else 0),
		BAG = MetaClient.PotionCount() + MetaClient.PackCount(),
	}
end)
checkNudges(false)
Hud.RefreshBadges()

-- Kenji's questline: the tracker banner and KENJI'S PATH (rewards and his lines go through the HUD toasts).
TutorialUi.Init(playerGui, Hud.QuestSlot(), function(text, hint)
	if text ~= "" then
		Hud.Reward(text)
	end
	if hint then
		Hud.Hint(hint)
	end
end, function(active)
	Hud.SetQuestActive(active)
	Hud.RefreshBadges()
	questsPanel:SetTabText("KENJI'S PATH", if active then "KENJI'S PATH" else "KENJI'S PATH ✓")
end, questsPanel)


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
	PlayerList.SetHidden("Title", false)
	if State.Meta.Daily and State.Meta.Daily.CanClaim then
		task.delay(0.8, function()
			Hud.Hint(`Daily reward ready: day {State.Meta.Daily.Day} of 7. Open QUESTS!`)
		end)
	end
end)

-- Keyboard shortcuts on PC: R = Roll, T = Quick Roll on / off, E = Auto Roll, G = ride / get off (Q is Dash).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or Title.IsOpen() then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		requestRoll(rollMode())
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleQuick()
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

