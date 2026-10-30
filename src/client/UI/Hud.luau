--!nonstrict
-- Main screen: the three roll buttons bottom-middle, three currency chips top centre (Shards, Trait
-- Shards, Rolls with the luck / ODDS line), the menu on the left: six direct buttons (BATTLE, BAG, SQUAD,
-- QUESTS, TRAVEL, STORE; red badges when something waits) under Kenji's quest tracker. Fusion, alchemy,
-- the Lucky Wheel and trait rolls have no button: they live with their NPCs in town.
-- the SETTINGS gear top right (the server list, UI/PlayerList, sits beside it), the Auto Roll feed on the
-- right, running potions as tiles in the bottom-right corner, the server announcement banner and reward
-- toasts. The left column scales with the screen so it fits a phone held sideways.
-- The bottom-left corner stays clear for Roblox's mobile thumbstick; on touch screens the potion
-- tiles sit above the jump button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Borders = require(Shared.Borders)
local Foils = require(Shared.Foils)
local RollBoost = require(Shared.RollBoost)
local Goals = require(Shared.Goals)
local Collections = require(Shared.Collections)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local HudArt = require(script.Parent.HudArt)
local BagArt = require(script.Parent.BagArt)
local RewardLine = require(script.Parent.RewardLine)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local State = require(script.Parent.Parent.State)
local JuicyButton = require(script.Parent.Components.JuicyButton)
local UIArt = require(script.Parent.UIArt)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))

local Hud = {}
local ready = false -- StoreState can arrive while Init is still building the currency chips.

local gui: ScreenGui
local dock: Frame
local activeCollection: TextLabel
local menu: Frame
local rollButton: any -- children are read by name
local autoButton: any
local quickButton: any
local cooldownBar: any
local topBar: any -- children read by name
local currency = {} -- [key] = chip (children read by name)
local shownValues = {} -- [key] = last number shown, to pop the chip when it changes
local hiddenBy = { Battle = false, Reveal = false }
local progressRows={}
local boostRow: Frame
local boostTip, boostTipTitle, boostTipText
local hoveredBoost: string? = nil
local hintLabel: TextLabel
local feed: Frame
local feedHeader: TextLabel
local banner: any
local bannerLabel: TextLabel
local toast: any
local petsButton: any -- the MOUNT tile beside the roll console
local levelBar: any -- children read by name
local eventPill: any
local raidPill: any -- under the event pill while a raid is live (tap to join) or Raid Luck runs
local raidWanted = false
local momentumLabel: TextLabel -- above ROLL: the Momentum chain and the next Overcharge Surge
local momentumFill: Frame -- the 2 px bar under it: Momentum toward RollBoost.Momentum.Max
local surgeMeter: any -- under it (children read by name): the Overcharge Surge cycle, SurgeProgress 0-24
local goalReady, goalTicks = false, 0 -- the Next Goal can be done now: it pulses (the 1 s tick)
local goalPill: any -- above the Momentum header (children read by name): the Next Goal tracker (Goals.Next)
local goalWanted = false
local surgeFill: any
local surgeCount: TextLabel
local surgeToken = 0
local setShiver: (on: boolean) -> () -- below: the imminent-surge jitter
local menuButtons = {} -- [name] = button (children read by name): categories and their items
local questSlot: Frame -- Kenji's tracker (UI/Tutorial puts its banner in here)
local questActive = false
local fitScale = 1 -- the left column's scale (layoutLeft)
local locks = {} -- [feature] = overlay frame
local feedOrder = 0
local FEED_Y = 0.6 -- the Auto Roll feed's centre: below the server list, above the potion tiles
local bannerToken = 0
local hintToken = 0
local toastToken = 0

local function compactHud(): boolean
	return gui.AbsoluteSize.Y > 0 and gui.AbsoluteSize.Y < 540
end

local function rollButtonFace(button: TextButton, title: string, sub: string, color: Color3, deep: Color3, skin: string, seal: boolean?)
	-- Urushi lacquer plate (bevelled: a light top edge, a darker base) with a double trim in the button's
	-- colour and a glowing line along the bottom; the title in that colour. `seal`: the ROLL button, a
	-- Vermilion seal face with a thick Tamahagane steel border. JuicyButton gives the sheen and spring.
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Text = ""
	Kit.surface(button, color, deep)
	local titleLabel = Kit.label({
		Name = "Title",
		Text = title,
		Font = if seal then Theme.Font.Display else Theme.Font.Heavy,
		TextColor3 = if seal then UITheme.Colors.WashiParchment else color:Lerp(UITheme.Colors.WashiParchment, 0.55),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.fromScale(0.86, 0.44),
		Parent = button,
	}, if seal then 42 else 24)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = titleLabel
	Kit.label({
		Name = "Sub",
		Text = sub,
		Font = Theme.Font.Heavy,
		TextColor3 = UITheme.Colors.WashiParchment,
		TextTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.8, 0.26),
		Parent = button,
	}, 20)
	if not seal and UIArt.Enabled then
		UIArt.Icon(button, title, { Position = UDim2.fromScale(0.08, 0.22), Size = UDim2.fromScale(0.2, 0.34), ZIndex = 2 })
		titleLabel.Position = UDim2.fromScale(0.61, 0.17)
		titleLabel.Size = UDim2.fromScale(0.66, 0.34)
	end
	JuicyButton.Apply(button, { SheenColor = color:Lerp(Color3.new(1, 1, 1), 0.45) })
end

local function lockOverlay(button: TextButton, feature: string)
	local overlay = Kit.new("Frame", {
		Name = "Lock",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { Kit.corner(UDim.new(0.28, 0)) })
	Kit.label({
		Name = "Text",
		Text = "LOCKED",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.6),
		ZIndex = 6,
		Parent = overlay,
	}, 20)
	locks[feature] = overlay
end

-- Square menu button: emoji icon, small caption, red badge for things to claim.
local MENU_COLORS = {
	BATTLE = { Color3.fromRGB(255, 78, 103), Color3.fromRGB(137, 18, 49) },
	SQUAD = { Color3.fromRGB(80, 155, 255), Color3.fromRGB(32, 58, 176) },
	BAG = { Color3.fromRGB(188, 100, 255), Color3.fromRGB(89, 35, 164) },
	QUESTS = { Color3.fromRGB(66, 234, 143), Color3.fromRGB(13, 115, 79) },
	TRAVEL = { Color3.fromRGB(63, 230, 255), Color3.fromRGB(12, 108, 162) },
	STORE = { Color3.fromRGB(255, 220, 73), Color3.fromRGB(180, 99, 15) },
	DEV = { Color3.fromRGB(255, 145, 72), Color3.fromRGB(159, 58, 25) },
}
local function menuButton(text: string, icon: string, order: number, color: Color3, onClick: () -> (), iconKey: string?, parent: Instance?)
	local button = Kit.new("TextButton", {
		Name = text,
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = parent or menu,
	}, {
		Kit.corner(UDim.new(0.26, 0)),
		Kit.gradient(ColorSequence.new(Theme.Color.TileTop, Theme.Color.Panel), 90),
		Kit.stroke(color, 1.2, 0.25),
	})
	Skin.Apply(button, "MenuButton")
	local palette = MENU_COLORS[string.upper(text)]
	if palette then Kit.surface(button, palette[1], palette[2]) end
	Kit.new("ImageLabel", {
		Name="Icon", Image=HudArt.Get(string.upper(text)) or "", BackgroundTransparency=1,
		AnchorPoint=Vector2.new(0,.5), Position=UDim2.new(0,8,.5,0), Size=UDim2.fromOffset(34,34),
		ScaleType=Enum.ScaleType.Fit, ZIndex=3, Parent=button,
	})
	local label = Kit.label({
		Name = "Label",
		Text = text,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.new(1, -57, 0.6, 0),
		Parent = button,
	}, 20)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.4).Parent = label
	local badge = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(235, 50, 65),
		Visible = false,
		ZIndex = 4,
		Parent = button,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
		Kit.stroke(Color3.new(1, 1, 1), 1.5, 0),
	})
	local badgeDecor = badge:FindFirstChild("VectorDecor")
	if badgeDecor then badgeDecor:Destroy() end
	local badgeGradient = badge:FindFirstChildOfClass("UIGradient")
	if badgeGradient then badgeGradient:Destroy() end
	badge.BackgroundColor3 = Color3.fromRGB(235, 50, 65)
	local countLabel = Kit.label({
		Name = "Count",
		Text = "!",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = 5,
		Parent = badge,
	}, 17)
	local countStroke = countLabel:FindFirstChildOfClass("UIStroke")
	if countStroke then countStroke.Thickness = 1.2 end
	Kit.pressable(button)
	button.Activated:Connect(onClick)
	menuButtons[text] = button
	return button
end

-- Currency chip for the top bar: a dark glass plate with a thin neon edge, a big icon hanging off its
-- left edge and a big number. `iconKey` is a Skin.Icons key; `emoji` is used when there's no icon art.
local function currencyChip(key: string, order: number, iconKey: string?, emoji: string, edge: Color3, width: number)
	local chip = Kit.new("TextButton", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(0, width, 1, -8),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = topBar:FindFirstChild("Chips"),
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.gradient(ColorSequence.new(UITheme.Colors.UrushiRaised, UITheme.Colors.UrushiBlack), 90),
		Kit.stroke(UITheme.Colors.Tamahagane, 2, 0),
	})
	chip.BackgroundTransparency = 0
	-- The chip's colour as a thin inner line, so the steel edge still says which currency it is.
	Kit.new("Frame", {
		Name = "Tint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 8, 1, -2),
		Size = UDim2.new(1, -40, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = edge,
		BackgroundTransparency = 0.3,
		Parent = chip,
	})
	-- Gloss line along the top.
	Kit.new("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 24, 0, 1),
		Size = UDim2.new(1, -30, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Parent = chip,
	})
	-- Plain transparent artwork leaves the currency value clear of a surrounding badge.
	Kit.new("ImageLabel", {
		Name="Icon", Image=HudArt.Get(key) or "", BackgroundTransparency=1,
		AnchorPoint=Vector2.new(.5,.5), Position=UDim2.new(0,20,.5,0), Size=UDim2.fromOffset(34,34),
		ScaleType=Enum.ScaleType.Fit, ZIndex=3, Parent=chip,
	})
	local value = Kit.label({
		Name = "Value",
		Text = "0",
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 42, 0.08, 0),
		Size = UDim2.new(1, -52, 0.84, 0),
		ZIndex = 2,
		Parent = chip,
	}, 30)
	Kit.textStroke(Color3.fromRGB(10, 12, 19), 2.5, 0).Parent = value
	Kit.new("UIScale", { Name = "Pop", Scale = 1, Parent = chip })
	chip.BackgroundTransparency = 0
	chip.UIStroke.Transparency = 0
	chip.Gloss.Visible = false
	chip.Tint.Visible = false
	currency[key] = chip
	return chip
end

-- Sets a chip's number and pops it when the number went up.
local function setCurrency(key: string, text: string, number: number)
	local chip = currency[key]
	chip.Value.Text = text
	local before = shownValues[key]
	shownValues[key] = number
	if before ~= nil and number > before then
		chip.Pop.Scale = 1.18
		Kit.tween(chip.Pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local layoutLeftFn: (() -> ())? = nil

local function applyHidden()
	local hidden = hiddenBy.Battle or hiddenBy.Reveal
	dock.Visible = not hidden
	menu.Visible = not hidden
	questSlot.Visible = questActive and not hidden
	topBar.Visible = not hidden
	for _,bar in progressRows do bar.Visible=not hidden and bar:GetAttribute("HasGoal")==true end
	boostRow.Visible = not hidden
	if hidden and boostTip then boostTip.Visible=false; hoveredBoost=nil end
	levelBar.Visible = not hidden
	eventPill.Visible = not hidden
	raidPill.Visible = raidWanted and not hidden
	goalPill.Visible = goalWanted and not hidden
	feed.Visible = not hidden
	-- The RECENT PULLS label only shows over pulls, never as a lone heading.
	local pulls = 0
	for _, child in feed:GetChildren() do
		if child:IsA("GuiObject") then
			pulls += 1
		end
	end
	feedHeader.Visible = pulls > 0 and not hidden
end

-- The hub feed is shorter on phones; applyHidden keeps it out of fights and full reveals.
local function placeFeed()
	if feed == nil or gui == nil then
		return
	end
	local sky=State.Weather
	local preview=Config.CelestialCardsReady and (sky.Id~="clear" or sky.Forecast)
	local short=compactHud()
	local skyBottom=if preview then (if short then 188 else 52+238*math.min(1,gui.AbsoluteSize.X*.25/330)) else (if short then 128 else 156)
	local top=math.max(gui.AbsoluteSize.Y*.3,skyBottom+28)
	feed.AnchorPoint=Vector2.new(1,0)
	feed.Position=UDim2.new(1,-12,0,top)
	feed.Size=UDim2.new(.2,0,0,if short then 32 else 70)
	if feedHeader then feedHeader.Position=UDim2.new(1,-18,0,top-19) end
end

export type Handlers = {
	OnRoll: () -> (),
	OnQuick: () -> (),
	OnAuto: () -> (),
	OnBattle: () -> (),
	OnBag: () -> (),
	OnSquad: () -> (),
	OnQuests: () -> (),
	OnTravel: () -> (),
	OnStore: () -> (),
	OnOdds: () -> (),
	OnPets: () -> (),
	OnRaid: () -> (),
	OnDev: (() -> ())?,
}

function Hud.Init(playerGui: Instance, handlers: Handlers)
	gui = Kit.screenGui("HudGui", 5, playerGui)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Bottom dock: buttons row, with potions, stats and hint stacked above it -----------
	dock = Kit.new("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromScale(0.56, 0.15),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(300, 64), MaxSize = Vector2.new(620, 112) }),
	})
	activeCollection=Kit.label({Name="ActiveCollection",Text="",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,-52),Size=UDim2.new(1,0,0,18),Parent=dock},13)
	local bar = Kit.new("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = dock,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.025, 0),
		}),
	})

	autoButton = Kit.new("TextButton", {
		Name = "AutoRoll",
		LayoutOrder = 1,
		Size = UDim2.fromScale(0.27, 0.78),
		Parent = bar,
	})
	rollButtonFace(autoButton, "AUTO", "OFF", Theme.Color.Auto, Theme.Color.AutoDeep, "AutoButton")
	lockOverlay(autoButton, "AutoRoll")

	rollButton = Kit.new("TextButton", {
		Name = "Roll",
		LayoutOrder = 2,
		Size = UDim2.fromScale(0.41, 1), -- the one big button: AUTO and QUICK are smaller toggles beside it
		Parent = bar,
	})
	rollButtonFace(rollButton, "ROLL", `{Config.Roll.Cooldown}s`, UITheme.Colors.VermilionSeal, UITheme.Colors.VermilionDeep, "RollButton", true)
	-- The cooldown sweep: a CanvasGroup track, so the fill clips to its rounded ends with no bleed.
	cooldownBar = Kit.new("CanvasGroup", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.12, 0, 1, -6),
		Size = UDim2.new(0.76, 0, 0, 5),
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0.3,
		Parent = rollButton,
	}, { Kit.corner(UDim.new(1, 0)) })
	Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = UITheme.Colors.WashiParchment,
		Parent = cooldownBar,
	})

	quickButton = Kit.new("TextButton", {
		Name = "QuickRoll",
		LayoutOrder = 3,
		Size = UDim2.fromScale(0.27, 0.78),
		Parent = bar,
	})
	-- QUICK is a toggle: on, ROLL plays the short reveal (faster rolling); the roll itself is the same.
	rollButtonFace(quickButton, "QUICK", "OFF", Theme.Color.Quick, Theme.Color.QuickDeep, "QuickButton")
	lockOverlay(quickButton, "QuickRoll")

	rollButton.Activated:Connect(handlers.OnRoll)
	quickButton.Activated:Connect(handlers.OnQuick)
	autoButton.Activated:Connect(handlers.OnAuto)

	-- Above the roll console: the Momentum header (Auto Roll never stops: it rolls until switched off) ---
	local row = Kit.new("Frame", {
		Name = "InfoRow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -4),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundTransparency = 1,
		Parent = dock,
	})
	-- Urushi mini-header on top of the roll console: Momentum text, and a 2 px bar filling to the cap.
	local momentumHeader = Kit.new("Frame", {
		Name = "MomentumHeader",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0.36, 0, 0, 22),
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = row,
	}, {
		Kit.corner(UDim.new(0, 3)),
		Kit.stroke(UITheme.Colors.Tamahagane, 1, 0),
	})
	-- The Next Goal pill, above the Momentum header: the reward closest to landing (a fusion, an Awakening
	-- node, a roll milestone or a Shard upgrade) with a bar filling toward it, updated on every roll.
	goalPill = Kit.new("Frame", {
		Name = "NextGoal",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -76),
		Size = UDim2.fromOffset(260, 22),
		BackgroundColor3 = UITheme.Colors.UrushiInset,
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		Visible = false,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(UITheme.Colors.TamahaganeSlate, 1, 0),
	})
	Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UITheme.Colors.SurgeGold,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = goalPill,
	}, { Kit.corner(UDim.new(1, 0)) })
	local goalText = Kit.label({
		Name = "Text",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = UITheme.Colors.WashiParchment,
		TextWrapped = false,
		Position = UDim2.new(0, 8, 0, 1),
		Size = UDim2.new(1, -16, 1, -2),
		ZIndex = 2,
		Parent = goalPill,
	}, 13)
	goalText:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 9
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.3).Parent = goalText
	momentumFill = Kit.new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = momentumHeader,
	})
	local shimmer = Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 40)),
		}),
		Offset = Vector2.new(-0.5, 0),
		Parent = momentumFill,
	})
	game:GetService("TweenService")
		:Create(shimmer, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.5, 0) })
		:Play()
	momentumLabel = Kit.label({
		Name = "Momentum",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Text,
		Position = UDim2.new(0, 6, 0, 2),
		Size = UDim2.new(1, -12, 1, -5),
		Parent = momentumHeader,
	}, 14)
	-- The Surge talisman (an ofuda strip): a sunken track over the 25-roll cycle (TotalRolls % 25) that
	-- charges spirit blue, turns void purple and shivers when the surge is close, and seals in gold leaf
	-- when the next roll is the surge (Hud.RefreshMomentum).
	surgeMeter = Kit.new("CanvasGroup", {
		Name = "SurgeMeter",
		Position = UDim2.fromScale(0.38, 0.22),
		Size = UDim2.fromScale(0.62, 0.56),
		BackgroundColor3 = UITheme.Colors.UrushiInset,
		BackgroundTransparency = 0,
		Parent = row,
	}, { Kit.corner(UDim.new(0, 3)) })
	local meterEdge = Instance.new("UIStroke")
	meterEdge.Thickness = 1.5
	meterEdge.Color = UITheme.Colors.TamahaganeSlate
	meterEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	meterEdge.Parent = surgeMeter
	surgeFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = surgeMeter,
	}, { Kit.gradient(ColorSequence.new(UITheme.Colors.SpiritCyan, UITheme.Colors.SpiritCyan), 0) })
	surgeCount = Kit.label({
		Name = "Count",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = UITheme.Colors.WashiParchment,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = surgeMeter,
	}, 14)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.2).Parent = surgeCount
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = momentumLabel
	momentumLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		Hud.RefreshMomentum()
	end)

	-- Top bar: Shards, Trait Shards and total rolls (with luck under it: tap for the odds) -------
	topBar = Kit.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 270, 0, 44),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Kit.new("UIScale", { Name = "Fit", Scale = 1 }),
	})
	Skin.Apply(topBar, "Panel")
	Kit.new("Frame", { Name = "Chips", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = topBar }, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12),
		}),
	})
	currencyChip("TraitShards", 2, nil, "🧬", Theme.Color.Gold, 110)
	local luckChip = currencyChip("Rolls", 3, nil, "🎲", Theme.Color.Gold, 120)
	Kit.label({
		Name = "Odds",
		Text = "🍀 1x · ODDS ›",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(190, 255, 210),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 10, 1, -2),
		Size = UDim2.new(0.9, 0, 0, 20),
		ZIndex = 3,
		Parent = luckChip,
	}, 17)
	Kit.textStroke(Color3.fromRGB(10, 40, 20), 1.5, 0).Parent = luckChip.Odds
	Kit.pressable(luckChip)
	luckChip.Activated:Connect(handlers.OnOdds)
	-- Narrow phone screens: shrink the bar to fit between Roblox's top-left buttons and the edge.
	-- It sits between the left column (Kenji's tracker) and the server list, about 210 px each.
	local function fitTopBar()
		local width = gui.AbsoluteSize.X
		topBar.Fit.Scale = math.min(math.clamp((width - 420) / 520, 0.5, 1), if compactHud() then 0.68 else 1)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTopBar)
	fitTopBar()

	-- Active potions and worn gear: inspect here, use items in BAG.
	boostRow = Kit.new("Frame", {
		Name="Boosts",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-18),
		Size=UDim2.fromOffset(216,104),BackgroundTransparency=1,Parent=gui,
	},{Kit.new("UIGridLayout",{CellSize=UDim2.fromOffset(48,48),CellPadding=UDim2.fromOffset(6,6),FillDirectionMaxCells=4,
		HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Bottom,
		StartCorner=Enum.StartCorner.BottomRight,SortOrder=Enum.SortOrder.LayoutOrder})})
	local boostScale=Kit.new("UIScale",{Parent=boostRow})
	local boostGrid=boostRow:FindFirstChildOfClass("UIGridLayout")
	boostTip=Kit.new("Frame",{Name="BoostTooltip",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,16),Size=UDim2.fromOffset(270,112),
		Visible=false,BackgroundColor3=Theme.Color.Panel,ZIndex=45,Parent=gui},{Kit.corner(),Kit.stroke(Theme.Color.Line,2,0)})
	boostTipTitle=Kit.label({Text="",Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-20,0,25),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=46,Parent=boostTip},18)
	boostTipText=Kit.label({Text="",Position=UDim2.fromOffset(10,34),Size=UDim2.new(1,-20,1,-40),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=46,Parent=boostTip},15)
	local function fitBoosts()
		local short=gui.AbsoluteSize.Y<540
		boostScale.Scale=1
		boostRow.Position=UDim2.new(1,if short then -112 else -18,1,if short then -92 else -18)
		boostRow.Size=UDim2.fromOffset(if short then 284 else 216,if short then 32 else 104)
		boostGrid.FillDirectionMaxCells=if short then 8 else 4
		boostGrid.CellSize=UDim2.fromOffset(if short then 32 else 48,if short then 32 else 48)
		boostGrid.CellPadding=UDim2.fromOffset(if short then 4 else 6,if short then 4 else 6)
		local bottom=if short then 92 else 18
		local top=gui.AbsoluteSize.Y-bottom-(if short then 32 else 104)
		boostTip.Position=UDim2.new(1,if short then -112 else -18,0,math.max(8,top-120))
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoosts)
	fitBoosts()

	hintLabel = Kit.label({
		Name = "Hint",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, -0.62, -42), -- above the Next Goal pill
		Size = UDim2.fromScale(1, 0.3),
		Parent = dock,
	}, 22)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = hintLabel

	-- Left column: Kenji's tracker, then the menu (six buttons in 2 columns, + DEV), scaled to the screen --
	questSlot = Kit.new("Frame", {
		Name = "Quest",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(300, 56),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	menu = Kit.new("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(156, 236),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local grid = Kit.new("UIGridLayout", {
		FillDirectionMaxCells = 1,
		CellSize = UDim2.fromOffset(174, 46),
		CellPadding = UDim2.fromOffset(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	menuButton("BATTLE", "⚔️", 1, Theme.Color.Roll, handlers.OnBattle)
	menuButton("BAG", "🎒", 3, Theme.Color.Quick, handlers.OnBag)
	menuButton("SQUAD", "🃏", 2, Theme.Color.Neon, handlers.OnSquad, "DECK")
	menuButton("QUESTS", "📜", 4, Theme.Color.Gold, handlers.OnQuests, "GIFTS")
	menuButton("TRAVEL", "🧭", 5, Theme.Color.Support, handlers.OnTravel)
	menuButton("STORE", "👑", 6, Color3.fromRGB(255, 196, 46), handlers.OnStore)
	if handlers.OnDev then
		menuButton("DEV", "🛠️", 7, Theme.Color.Danger, handlers.OnDev)
	end
	local menuRows = if handlers.OnDev then 7 else 6

	-- Scale the left column with the screen (a phone held sideways is ~0.6).
	local function layoutLeft()
		local size = gui.AbsoluteSize
		fitScale = math.clamp(math.min(size.X / 1100, size.Y / 640), 0.6, 1)
		local cell = math.floor(44 * fitScale)
		local width = math.floor(174 * fitScale)
		local pad = math.floor(6 * fitScale)
		local top = math.floor(56 * fitScale)
		questSlot.Size = UDim2.fromOffset(math.floor(280 * fitScale), math.floor(66 * fitScale))
		questSlot.Position = UDim2.fromOffset(12, top)
		local menuTop = if questActive then top + questSlot.Size.Y.Offset + pad + 4 else top
		grid.CellSize = UDim2.fromOffset(width, cell)
		grid.CellPadding = UDim2.fromOffset(0, pad)
		menu.Size = UDim2.fromOffset(width, menuRows * cell + (menuRows - 1) * pad)
		menu.Position = UDim2.fromOffset(12, menuTop)
	end
	layoutLeftFn = layoutLeft
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLeft)
	layoutLeft()

	-- MOUNT, beside the roll console: a small dark tile (G rides / gets off). The SETTINGS gear sits in
	-- the server list's header (UI/PlayerList).
	petsButton = Kit.new("TextButton", {
		Name = "Mount",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 10, 1, 0),
		Size = UDim2.fromOffset(58, 58),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = dock,
	}, {
		Kit.corner(UDim.new(0, 4)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(28, 33, 48), Color3.fromRGB(11, 13, 21)), 90),
		Kit.stroke(Theme.Color.Line, 1.2, 0),
	})
	local mountIcon = Kit.label({
		Text = "🐎", -- kept when there's no MOUNT illustration
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.6, 0.56),
		Parent = petsButton,
	}, 22)
	Skin.Icon(mountIcon, "MOUNT")
	Skin.Apply(petsButton, "MenuButton")
	Kit.label({
		Text = "MOUNT", -- "MOUNT·G" didn't fit the tile; G still rides
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.96, 0.28),
		Parent = petsButton,
	}, 12)
	petsButton.MouseEnter:Connect(function()
		petsButton.UIStroke.Color = Theme.Color.Neon
	end)
	petsButton.MouseLeave:Connect(function()
		petsButton.UIStroke.Color = Theme.Color.Line
	end)
	Kit.pressable(petsButton)
	petsButton.Activated:Connect(handlers.OnPets)

	-- Auto Roll feed (right side) ------------------------------------------------------------
	feed = Kit.new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, FEED_Y, 0),
		Size = UDim2.fromScale(0.22, 0.34),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = gui,
	}, {
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(150, 56), MaxSize = Vector2.new(280, 360) }),
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})

	-- Short (phone) screens: the feed sits higher and shorter, under the folded server list and clear of
	-- the jump / DASH buttons.
	feedHeader = Kit.label({
		Name = "FeedHeader", Text = "RECENT PULLS", Font = Theme.Font.Heavy, TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0.3, -20), Size = UDim2.fromOffset(180, 16), Parent = gui,
	}, 12)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeFeed)
	placeFeed()
	feed.ChildAdded:Connect(applyHidden)
	feed.ChildRemoved:Connect(applyHidden)

	-- Server announcement banner (top centre, below Roblox's top bar) --------------------------
	banner = Kit.new("Frame", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.fromScale(0.55, 0.075),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false, -- shown only while sliding in and out, so no edge peeks below the top bar
		Parent = gui,
	}, {
		Kit.corner(UDim.new(0.4, 0)),
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(260, 34), MaxSize = Vector2.new(720, 60) }),
	})
	Kit.new("UIGradient", { Name = "Gradient", Rotation = 0, Parent = banner })
	bannerLabel = Kit.label({
		Name = "Text",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.66),
		Parent = banner,
	}, 24)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = bannerLabel

	-- Reward toast (top centre, under the banner) ----------------------------------------------
	toast = Kit.new("Frame", {
		Name = "Reward",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromScale(0.4, 0.07),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.stroke(Theme.Color.Gold, 2, 0),
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(240, 36), MaxSize = Vector2.new(520, 56) }),
	})
	Kit.new("UIScale", { Name = "Scale", Scale = 1, Parent = toast })
	RewardLine.new({
		Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.72),
		ZIndex = 21, Parent = toast,
	}, "", 24)

	-- Level bar under the top bar: LV badge + XP fill + numbers -------------------------------------
	levelBar = Kit.new("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(400, 24),
		BackgroundColor3 = Color3.fromRGB(8, 11, 17),
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(Theme.Color.Gold, 2, 0.15),
		Kit.new("UIScale", { Name = "Fit", Scale = 1 }),
	})
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(0, 0, 1, -6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = levelBar,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 150, 40)), 0),
	})
	fill:SetAttribute("Max", 400 - 6)
	local xpText = Kit.label({
		Name = "Text",
		Text = "",
		Font = Theme.Font.Heavy,
		Position = UDim2.fromOffset(40, 2),
		Size = UDim2.new(1, -48, 1, -4),
		ZIndex = 3,
		Parent = levelBar,
	}, 15)
	Kit.textStroke(Color3.fromRGB(30, 12, 0), 1.5, 0).Parent = xpText
	local badge = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = levelBar,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 120, 20)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2.5, 0),
	})
	local levelNumber = Kit.label({
		Name = "Number",
		Text = "1",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.8, 0.62),
		ZIndex = 5,
		Parent = badge,
	}, 26)
	Kit.textStroke(Color3.fromRGB(90, 40, 0), 2, 0).Parent = levelNumber
	Kit.label({
		Text = "LV",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.6, 0.26),
		ZIndex = 5,
		Parent = badge,
	}, 11)

	-- Event pill under the level bar: the running event and its timer, or when the next one starts.
	eventPill = Kit.new("Frame", {
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(300, 26),
		BackgroundColor3 = Color3.fromRGB(8, 11, 17),
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.4),
		Kit.new("UIScale", { Name = "Pop", Scale = 1 }),
	})
	local eventText = Kit.label({
		Name = "Text",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		Position = UDim2.fromScale(0.04, 0.12),
		Size = UDim2.fromScale(0.92, 0.76),
		Parent = eventPill,
	}, 16)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = eventText

	-- Raid pill: the live raid (tap to join) or Raid Luck after a clear.
	raidPill = Kit.new("TextButton", {
		Name = "Raid",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 144),
		Size = UDim2.fromOffset(420, 28),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(110, 20, 50),
		BackgroundTransparency = 0.1,
		Text = "",
		Visible = false,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(Color3.fromRGB(255, 80, 120), 2, 0),
		Kit.new("UIScale", { Name = "Pop", Scale = 1 }),
	})
	local raidText = Kit.label({
		Name = "Text",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		Position = UDim2.fromScale(0.04, 0.12),
		Size = UDim2.fromScale(0.92, 0.76),
		Parent = raidPill,
	}, 16)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = raidText
	raidPill.Activated:Connect(function()
		if State.Raid and State.Raid.Open then
			handlers.OnRaid()
		end
	end)
	Kit.pressable(raidPill)

	-- Narrow phones: the level bar and event pill shrink with the top bar.
	local function fitBars()
		local compact = compactHud()
		levelBar.Fit.Scale = if compact then 0.55 else 0.65
		levelBar.AnchorPoint = Vector2.new(0, 1)
		levelBar.Position = UDim2.new(0, 30, 1, -22)
		eventPill.Position = UDim2.new(0.5, 0, 0, if compact then 48 else 62)
		raidPill.Position = UDim2.new(0.5, 0, 0, if compact then 84 else 96)
		toast.Position = UDim2.new(0.5, 0, 0, if compact then 142 else 140)
		dock.Size = UDim2.fromScale(if compact then 0.5 else 0.56, 0.15)
		local limits = dock:FindFirstChildOfClass("UISizeConstraint")
		if limits then
			limits.MinSize = Vector2.new(300, if compact then 46 else 64)
			limits.MaxSize = Vector2.new(if compact then 480 else 620, if compact then 54 else 88)
		end
		momentumHeader.Size = UDim2.new(0.36, 0, 0, if compact then 16 else 22)
		goalPill.Position = if compact then UDim2.new(0.5, -150, 1, -102) else UDim2.new(0, 18, 1, -76)
		goalPill.Size = UDim2.fromOffset(if compact then 300 else 300, if compact then 18 else 26)
		if compact then
			goalPill.Position=UDim2.new(0,146,1,-104)
			goalPill.Size=UDim2.fromOffset(math.clamp(gui.AbsoluteSize.X-550,120,220),18)
		end
		for i,bar in progressRows do
			bar.Position=goalPill.Position+UDim2.fromOffset(0,-goalPill.Size.Y.Offset-4-(i-1)*24)
			bar.Size=UDim2.fromOffset(goalPill.Size.X.Offset,20)
		end
		petsButton.Size = UDim2.fromOffset(if compact then 44 else 58, if compact then 44 else 58)
		Hud.RefreshEvent()
	end
	for i=1,2 do
		local bar=Kit.new("Frame",{Name=`NearGoal{i}`,AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-76-i*24),Size=UDim2.fromOffset(300,20),BackgroundColor3=Theme.Color.Panel,Parent=gui},{Kit.corner()})
		Kit.new("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=Theme.Color.Quick,BackgroundTransparency=.35,Parent=bar},{Kit.corner()})
		Kit.label({Name="Text",Text="",Size=UDim2.fromScale(1,1),Parent=bar},13)
		progressRows[i]=bar
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBars)
	fitBars()

	-- Potion timers, badges and the event pill tick once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			Hud.RefreshBoosts()
			Hud.RefreshGoal()
			placeFeed()
			Hud.RefreshBadges()
			Hud.RefreshEvent()
			Hud.RefreshRaid()
			-- A goal you can claim now keeps breathing until you do (every 3 s, so it isn't noisy).
			goalTicks += 1
			if goalReady and goalPill.Visible and goalTicks % 3 == 0 then
				task.spawn(Effects.Pulse, goalPill:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = goalPill }), 1, 0.35, 0.05)
			end
		end
	end)

	ready = true
	Hud.Refresh()
end

-- Level bar from State.Meta.Level.
function Hud.RefreshLevel()
	local level = State.Meta.Level or { Level = 1, XP = 0, Need = 80 }
	local ratio = if level.Need > 0 then math.clamp(level.XP / level.Need, 0, 1) else 1
	levelBar.Badge.Number.Text = tostring(level.Level)
	levelBar.Text.Text = `{Kit.commas(level.XP)} / {Kit.commas(level.Need)} XP`
	Kit.tween(levelBar.Fill, 0.3, { Size = UDim2.new(0, math.max(8, ratio * levelBar.Fill:GetAttribute("Max")), 1, -6) })
end

local lastEventId = nil

-- The event pill (running event + time left, or the next one).
function Hud.RefreshEvent()
	local event, left, untilNext = State.Event()
	local text = eventPill.Text
	local compact=compactHud()
	local compactWidth=math.clamp(gui.AbsoluteSize.X-510,190,250)
	eventPill.Position=if compact then UDim2.new(0,146,0,48) else UDim2.new(.5,0,0,62)
	eventPill.AnchorPoint=Vector2.new(if compact then 0 else .5,0)
	if event then
		text.Text = `{event.Icon} <b>{event.Name}</b> · {event.Text} · {string.format("%d:%02d", left // 60, math.floor(left % 60))}`
		eventPill.UIStroke.Color = event.Color
		eventPill.UIStroke.Transparency = 0
		eventPill.BackgroundColor3 = event.Color:Lerp(Color3.new(0, 0, 0), 0.55)
		eventPill.Size = UDim2.fromOffset(if compact then compactWidth else 440, if compact then 30 else 28)
	else
		local index = math.floor(workspace:GetServerTimeNow() / Meta.EventEvery) % #Meta.Events + 1
		local nextEvent = Meta.Events[index]
		-- Between events the pill also names the week's Featured Card (x3 as likely to pull).
		local featured = Cards.Get(Cards.FeaturedAt(workspace:GetServerTimeNow()))
		text.Text = `Next: {nextEvent.Icon} <b>{nextEvent.Name}</b> in {string.format("%d:%02d", untilNext // 60, math.floor(untilNext % 60))}`
			.. (if featured then (if compactHud() then "\n" else "   ·   ") .. `<font color="#FFD700">⭐ FEATURED <b>{string.upper(featured.Name)}</b> x{Cards.FeaturedBoost}</font>` else "")
		eventPill.UIStroke.Color = UITheme.Colors.TamahaganeSlate
		eventPill.UIStroke.Transparency = 0
		eventPill.BackgroundColor3 = UITheme.Colors.UrushiBase
		eventPill.Size = UDim2.fromOffset(if compact then compactWidth elseif featured then 470 else 320, if compact then 30 else 26)
	end
	-- An event just started: pop the pill and say so.
	local id = event and event.Id
	if id ~= lastEventId then
		if event then
			eventPill.Pop.Scale = 1.4
			Kit.tween(eventPill.Pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			Effects.Sparks(eventPill, event.Color, 16, 1)
			Hud.Hint(`{event.Icon} {event.Name} started! {event.Text}`)
		end
		lastEventId = id
		Hud.Refresh() -- luck / cooldown numbers change with the event
	end
end

local lastRaidOpen = false

-- The raid pill: LIVE with the pool left and time (tap to join), or Raid Luck's timer, or hidden.
function Hud.RefreshRaid()
	local raid = State.Raid
	local now = workspace:GetServerTimeNow()
	local open = raid ~= nil and raid.Open and now < raid.Ends
	local luckEnds = ReplicatedStorage:GetAttribute("RaidLuckEnds")
	local luck = type(luckEnds) == "number" and luckEnds > now
	local text = raidPill:FindFirstChild("Text") :: TextLabel -- TextButton.Text is the button's string property
	if open then
		local left = if raid.Max > 0 then math.floor((1 - raid.Dealt / raid.Max) * 100 + 0.5) else 100
		local seconds = math.floor(raid.Ends - now)
		text.Text = `⚔️ <b>RAID LIVE</b> · {raid.Name} {left}% · {string.format("%d:%02d", seconds // 60, seconds % 60)} · TAP TO JOIN`
		raidPill.BackgroundColor3 = Color3.fromRGB(110, 20, 50)
		raidPill.UIStroke.Color = Color3.fromRGB(255, 80, 120)
	elseif luck then
		local seconds = math.floor(luckEnds - now)
		text.Text = `🍀 <b>RAID LUCK x2</b> for everyone · {string.format("%d:%02d", seconds // 60, seconds % 60)}`
		raidPill.BackgroundColor3 = Color3.fromRGB(20, 80, 50)
		raidPill.UIStroke.Color = Color3.fromRGB(120, 255, 170)
	end
	-- A Server Luck Totem shows here too when nothing else does.
	local totemEnds = ReplicatedStorage:GetAttribute("TotemLuckEnds")
	local totem = type(totemEnds) == "number" and totemEnds > now
	if totem and not open and not luck then
		local seconds = math.floor(totemEnds - now)
		local buyer = ReplicatedStorage:GetAttribute("TotemBuyer")
		text.Text = `🗿 <b>LUCK TOTEM x2</b> from {if type(buyer) == "string" then buyer else "a player"} · {string.format("%d:%02d", seconds // 60, seconds % 60)}`
		raidPill.BackgroundColor3 = Color3.fromRGB(30, 70, 60)
		raidPill.UIStroke.Color = Color3.fromRGB(110, 255, 160)
	end
	raidWanted = open or luck or totem
	if open and not lastRaidOpen then
		raidPill.Pop.Scale = 1.4
		Kit.tween(raidPill.Pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Effects.Sparks(raidPill, Color3.fromRGB(255, 80, 120), 16, 1)
		Hud.Hint(`⚔️ A server raid opened: {raid.Name}! Tap the raid bar to join.`)
	end
	lastRaidOpen = open
	applyHidden()
end

-- LEVEL UP: a gold burst in the middle of the screen with the reward.
function Hud.LevelUp(ups)
	local last = ups[#ups]
	local holder = Kit.new("Frame", {
		Name = "LevelUp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = gui,
	})
	local rays = Effects.Rays(holder, Theme.Color.Gold, 10)
	rays.ZIndex = 30
	local title = Kit.label({
		Text = "LEVEL UP!",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(1, 0.34),
		ZIndex = 32,
		Parent = holder,
	}, 64)
	Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 245, 170), Color3.fromRGB(255, 160, 40)), 90).Parent = title
	Kit.textStroke(Color3.fromRGB(90, 30, 0), 4, 0).Parent = title
	local level = Kit.label({
		Text = `LV {last.Level}`,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.6, 0.24),
		ZIndex = 32,
		Parent = holder,
	}, 44)
	Kit.textStroke(Color3.fromRGB(15, 19, 30), 3, 0).Parent = level
	-- Everything those levels paid, added up into one line.
	local total = { Shards = 0, TraitShards=0, Potions = {} }
	local luckUps = 0
	for _, up in ups do
		total.Shards += up.Reward.Shards or 0
		total.TraitShards += up.Reward.TraitShards or 0
		for id, count in up.Reward.Potions or {} do
			total.Potions[id] = (total.Potions[id] or 0) + count
		end
		if up.Luck then
			luckUps += 1
		end
	end
	local rewardText = Meta.Describe(total) .. `   +{#ups} stat point{if #ups > 1 then "s" else ""}`
	if luckUps > 0 then
		rewardText ..= `   +{luckUps * Meta.LevelLuck}x luck forever`
	end
	local reward = Kit.label({
		Text = rewardText,
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(1, 0.16),
		ZIndex = 32,
		Parent = holder,
	}, 24)
	Kit.textStroke(Color3.new(0, 0, 0), 2, 0).Parent = reward
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = holder })
	Kit.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Effects.Sparks(holder, Theme.Color.Gold, 30, 1.2)
	levelBar.Badge.Size = UDim2.fromOffset(60, 60)
	Kit.tween(levelBar.Badge, 0.4, { Size = UDim2.fromOffset(46, 46) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		Kit.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		holder:Destroy()
	end)
end

-- The Next Goal pill (Goals.Next): text, the bar, and a gold edge when it can be done now.
local lastGoalText = ""
function Hud.RefreshGoal()
	if goalPill == nil then
		return
	end
	local nearest=Goals.Closest({Cards=State.Cards,Rolls=State.Rolls(),Claimed=State.Meta.Milestones,Shards=0,Weather=State.Weather,Now=workspace:GetServerTimeNow(),Tower=State.Tower})
	local goal=nearest[1]
	for i,bar in progressRows do
		local item=nearest[i+1]
		bar:SetAttribute("HasGoal",item~=nil)
		bar.Visible=item~=nil and not hiddenBy.Battle and not hiddenBy.Reveal
		if item then bar.Text.Text=item.Text;bar.Fill.Size=UDim2.fromScale(item.Progress,1) end
	end
	goalWanted = goal ~= nil
	goalPill.Visible = goalWanted and not hiddenBy.Battle and not hiddenBy.Reveal
	if goal == nil then
		return
	end
	goalPill.Text.Text = goal.Text
	goalPill.Text.TextColor3 = if goal.Ready then UITheme.Colors.SurgeGold else UITheme.Colors.WashiParchment
	goalPill.UIStroke.Color = if goal.Ready then UITheme.Colors.SurgeGold else UITheme.Colors.TamahaganeSlate
	goalPill.Fill.BackgroundColor3 = if goal.Kind == "Fusion" then UITheme.Colors.VermilionHover
		elseif goal.Kind == "Awakening" then UITheme.Colors.SpiritCyan
		else UITheme.Colors.SurgeGold
	Kit.tween(goalPill.Fill, 0.25, { Size = UDim2.fromScale(math.clamp(goal.Progress, 0.04, 1), 1) })
	goalReady = goal.Ready
	if goal.Text ~= lastGoalText and goal.Ready then
		task.spawn(Effects.Pulse, goalPill:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = goalPill }), 1, 0.3, 0.06)
	end
	lastGoalText = goal.Text
end

function Hud.Refresh()
	if not ready then return end
	local s = State.Summary
	activeCollection.Text="ACTIVE PACK: " .. (Collections.ById[s.SelectedCollection or "normal"] or Collections.ById.normal).Name
	local traitShards = s.TraitShards or State.Meta.TraitShards or 0
	setCurrency("TraitShards", Kit.commas(traitShards), traitShards)
	Hud.RefreshMomentum()
	Hud.RefreshGoal()
	setCurrency("Rolls", Kit.commas(s.TotalRolls), s.TotalRolls)
	currency.Rolls.Odds.Text = `🍀 {string.format("%.2f", State.Luck())}x · ODDS ›`
	rollButton.Sub.Text = string.format("%.2gs", State.Cooldown())
	Hud.SetAuto(s.AutoActive)
	Hud.SetQuick(State.Meta.QuickRoll == true)
	Hud.RefreshLevel()

	for feature, overlay in locks do
		local unlocked = s.Unlocked[feature]
		overlay.Visible = not unlocked
		if not unlocked then
			local rule = Config.Unlocks[feature]
			local rollsLeft = math.max(0, rule.Rolls - s.TotalRolls)
			local secondsLeft = math.floor(math.max(0, rule.Seconds - s.Playtime))
			overlay.Text.Text = if rollsLeft > 0
				then `{rollsLeft} rolls`
				else string.format("%d:%02d", secondsLeft // 60, secondsLeft % 60)
		end
	end
	Hud.RefreshBoosts()
	Hud.RefreshBadges()
end

-- Keep tiles stable while timers tick so a hover is never interrupted by a roll.
function Hud.RefreshBoosts()
	if not boostRow then return end
	local wanted={}
	for i,potion in Meta.Potions do
		local left=State.PotionLeft(potion.Id)
		if left>0 then
			local key=`Potion:{potion.Id}`
			wanted[key]={Name=potion.Name,Text=potion.Text.."\nLuck potions: the strongest active tier counts.",Color=potion.Color,Left=left,Order=i,
				Image=BagArt.Get(key) or BagArt.Get("Artifact:hourglass")}
		end
	end
	local gear=State.Meta.Gear or Items.Empty()
	for i,id in gear.Worn or {} do
		local item=Items.ArtifactById[id]
		if item then
			wanted[`Artifact:{id}`]={Name=item.Name,Text=Items.ArtifactText(item,(gear.Artifacts or {})[id] or 1).."\nWorn relic · remove in BAG",Color=Theme.Color.Gold,Order=10+i,Image=BagArt.Get(`Artifact:{id}`)}
		end
	end
	for i,item in Items.TowerArtifacts do
		if (gear.TowerArtifacts or {})[item.Id] then
			wanted[`TowerArtifact:{item.Id}`]={Name=item.Name,Text=Items.TowerArtifactText(item).."\nAlways active",Color=Theme.Color.Gold,Order=20+i,Image=BagArt.Get(`TowerArtifact:{item.Id}`)}
		end
	end
	for _,tile in boostRow:GetChildren() do
		if tile:IsA("GuiObject") and not wanted[tile.Name] then
			if hoveredBoost==tile.Name then hoveredBoost=nil;boostTip.Visible=false end
			tile:Destroy()
		end
	end
	for id,info in wanted do
		local tile=boostRow:FindFirstChild(id)
		if not tile then
			tile=Kit.new("TextButton",{Name=id,Text="",LayoutOrder=info.Order,BackgroundColor3=Theme.Color.Panel,Parent=boostRow},
				{Kit.corner(),Kit.stroke(info.Color,2,0),Kit.gradient(ColorSequence.new(info.Color:Lerp(Theme.Color.Panel,.5),Theme.Color.Panel),90)})
			Kit.new("ImageLabel",{Name="Icon",Image=info.Image or "",BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Position=UDim2.fromScale(.08,.02),Size=UDim2.fromScale(.84,.78),Parent=tile})
			Kit.label({Name="Caption",Text="",Font=Theme.Font.Display,Position=UDim2.fromScale(.02,.71),Size=UDim2.fromScale(.96,.27),Parent=tile},13)
			local function inspect()
				hoveredBoost=id;boostTip.Visible=boostRow.Visible
				boostTipTitle.Text=tile:GetAttribute("ItemName") or ""
				boostTipText.Text=tile:GetAttribute("Details") or ""
			end
			tile.MouseEnter:Connect(inspect)
			tile.MouseLeave:Connect(function() if hoveredBoost==id then hoveredBoost=nil;boostTip.Visible=false end end)
			tile.Activated:Connect(function() if hoveredBoost==id and boostTip.Visible then hoveredBoost=nil;boostTip.Visible=false else inspect() end end)
		end
		local caption="WORN"
		if info.Left then
			local seconds=math.ceil(info.Left)
			caption=string.format("%d:%02d",seconds//60,seconds%60)
		end
		tile.Caption.Text=caption
		tile:SetAttribute("ItemName",info.Name)
		tile:SetAttribute("Details",info.Text..(if info.Left then `\n{caption} remaining` else ""))
		if hoveredBoost==id then boostTipText.Text=tile:GetAttribute("Details") end
	end
end

-- Red badge counts: things to claim in GIFTS / INDEX, potions owned in the BAG, unspent STATS points.
local function showBadge(button, count: number)
	button.Badge.Visible = count > 0
	button.Badge.Count.Text = if count > 9 then "9+" else tostring(count)
end

-- A menu button's red badge (BAG, SQUAD, QUESTS).
function Hud.SetBadge(name: string, count: number)
	local button = menuButtons[name]
	if button then
		showBadge(button, count)
	end
end

-- Kenji's questline running: the tracker slot shows above the menu (UI/Tutorial fills it).
function Hud.QuestSlot(): Frame
	return questSlot
end

function Hud.SetQuestActive(on: boolean)
	if questActive == on then
		return
	end
	questActive = on
	applyHidden()
	if layoutLeftFn then
		layoutLeftFn()
	end
end

local badgeSource = nil -- set by Main: () -> { [menuName] = count }

function Hud.SetBadgeSource(source)
	badgeSource = source
end

function Hud.RefreshBadges()
	if badgeSource then
		for name, count in badgeSource() do
			Hud.SetBadge(name, count)
		end
	end
end

-- Rolls continue during fights; their feed waits offscreen so it cannot cover enemy targets.
function Hud.SetBattleMode(on: boolean)
	hiddenBy.Battle = on
	applyHidden()
	placeFeed()
end

-- The whole HUD off (behind the title screen) or back on.
local hudVisible, panelOpen = true, false
function Hud.SetVisible(on: boolean)
	hudVisible = on
	gui.Enabled = hudVisible and not panelOpen
end

-- While a panel is open the HUD steps away entirely, so nothing shows through or over it.
function Hud.SetPanelOpen(on: boolean)
	panelOpen = on
	gui.Enabled = hudVisible and not panelOpen
end

-- Full card reveals take the whole screen: the dock, menu and top bar step aside.
function Hud.SetRevealMode(on: boolean)
	hiddenBy.Reveal = on
	applyHidden()
end

-- The QUICK toggle's face (ON: ROLL plays the short reveal).
function Hud.SetQuick(on: boolean)
	quickButton.Sub.Text = if on then "ON" else "OFF"
	quickButton.UIStroke.Color = if on then Theme.Color.Quick else UITheme.Colors.TamahaganeSlate
	quickButton.UIStroke.Thickness = if on then 2 else 1.5
end

function Hud.SetAuto(on: boolean)
	autoButton.Sub.Text = if on then "ON" else "OFF"
	autoButton.UIStroke.Color = if on then Theme.Color.Auto else UITheme.Colors.TamahaganeSlate
	autoButton.UIStroke.Thickness = if on then 2 else 1.5
	local dimmed = on
	rollButton.Title.TextTransparency = if dimmed then 0.6 else 0
	quickButton.Title.TextTransparency = if dimmed then 0.6 else 0
end

function Hud.StartCooldown(seconds: number)
	local fill = cooldownBar.Fill
	fill.Size = UDim2.fromScale(0, 1)
	Kit.tween(fill, seconds, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	-- The next roll is an Overcharge Surge: once the cooldown is back, the perfect window opens.
	surgeToken += 1
	local token = surgeToken
	if (State.Summary.UntilSurge or 0) == 1 and not State.Summary.AutoActive then
		task.delay(seconds, function()
			if token ~= surgeToken then
				return
			end
			local window = RollBoost.Surge.PerfectWindow
			fill.BackgroundColor3 = Theme.Color.Gold
			Hud.Hint(`⚡ SURGE READY: TAP ROLL NOW! ({window}s)`)
			Effects.Sparks(rollButton, Theme.Color.Gold, 14, 0.8)
			Kit.tween(fill, window, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
			task.delay(window, function()
				if token == surgeToken then
					fill.BackgroundColor3 = UITheme.Colors.WashiParchment
					fill.Size = UDim2.fromScale(1, 1)
				end
			end)
		end)
	else
		fill.BackgroundColor3 = UITheme.Colors.WashiParchment
	end
end

-- The talisman shivers (a 1 px jitter) while the surge is imminent; one loop at a time, off on low effects.
local shivering = false
function setShiver(on: boolean)
	if on == shivering then
		return
	end
	shivering = on
	if not on or Theme.FxLow then
		surgeMeter.Position = UDim2.fromScale(0.38, 0.22)
		return
	end
	task.spawn(function()
		while shivering and surgeMeter.Parent do
			surgeMeter.Position = UDim2.new(0.38, math.random(-1, 1), 0.22, math.random(-1, 1))
			task.wait(0.05)
		end
		surgeMeter.Position = UDim2.fromScale(0.38, 0.22)
	end)
end

-- Momentum and the next surge, over the roll buttons.
function Hud.RefreshMomentum()
	local s = State.Summary
	local m = s.Momentum or { Count = 0, Speed = 0, Luck = 0 }
	-- The meter binds to SurgeProgress (0-24): 24 = the next roll is the surge.
	local every = RollBoost.Surge.Every
	local progress = s.SurgeProgress or RollBoost.SurgeProgress(s.TotalRolls or 0)
	local ratio = progress / (every - 1)
	-- Three states: charging (spirit blue), imminent (void purple, shivering), sealed (gold leaf).
	local sealed = progress == every - 1
	local imminent = not sealed and progress >= every - 5
	local fillColor = if sealed then UITheme.Colors.SurgeGold elseif imminent then UITheme.Colors.VoidSurge else UITheme.Colors.SpiritCyan
	Kit.tween(surgeFill, 0.2, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }) -- full when the surge is next
	surgeFill.UIGradient.Color = ColorSequence.new(fillColor:Lerp(UITheme.Colors.UrushiBase, 0.35), fillColor)
	surgeCount.Text = if sealed
		then `OVERCHARGE SURGE SEALED ({RollBoost.Surge.BorderMult}x ODDS)`
		else `SURGE {progress}/{every}`
	surgeCount.TextColor3 = if sealed then UITheme.Colors.UrushiBase else UITheme.Colors.WashiParchment
	surgeMeter.UIStroke.Color = if sealed then UITheme.Colors.SurgeGold elseif imminent then UITheme.Colors.VoidSurge else UITheme.Colors.TamahaganeSlate
	rollButton.Title.Text = if sealed then "UNLEASH SURGE!" elseif State.Perk("TripleRoll", true) then "ROLL ×3" else "ROLL"
	setShiver(imminent)
	Kit.tween(momentumFill, 0.3, { Size = UDim2.new(math.clamp(m.Count / RollBoost.Momentum.Max, 0, 1), 0, 0, 2) })
	-- Momentum only: the Surge meter under it already counts down to the next surge.
	local paused = if m.Paused then " (paused)" else ""
	if momentumLabel.AbsoluteSize.X > 0 and momentumLabel.AbsoluteSize.X < 300 then
		momentumLabel.Text = if m.Count > 0
			then `🔥 <b>{m.Count}</b>{paused}  +{math.floor(m.Speed * 100 + 0.5)}% +{string.format("%.2f", m.Luck)}x`
			else "🔥 Keep rolling for Momentum"
	elseif m.Count > 0 then
		momentumLabel.Text = `🔥 MOMENTUM <b>{m.Count}</b>{paused}  +{math.floor(m.Speed * 100 + 0.5)}% speed  +{string.format("%.2f", m.Luck)}x luck`
	else
		momentumLabel.Text = "🔥 Keep rolling to build Momentum"
	end
end

function Hud.Hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	Kit.tween(hintLabel, 0.15, { TextTransparency = 0 })
	task.delay(1.6, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- "+💎25  🍀x1" popping in at the top of the screen.
function Hud.Reward(text: string)
	if text == "" then
		return
	end
	toastToken += 1
	local token = toastToken
	RewardLine.Set(toast.Text, text)
	toast.Visible = true
	toast.Scale.Scale = 0.4
	Kit.tween(toast.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Effects.Sparks(toast, Theme.Color.Gold, 10, 1.2)
	task.delay(2.6, function()
		if token == toastToken then
			Kit.tween(toast.Scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
				if token == toastToken then
					toast.Visible = false
				end
			end)
		end
	end)
end

function Hud.FeedAdd(result)
	local card = Cards.Get(result.CardId)
	if card == nil then
		return
	end
	local tier = Borders.RevealTier(result.Border)
	feedOrder += 1
	local suffix = if result.Outcome == "New"
		then " <font color='#FFC42E'>NEW</font>"
		elseif result.Outcome == "Star" then ` ★{result.Stars}`
		else ""
	local entry = Kit.new("Frame", {
		Name = "Entry",
		LayoutOrder = feedOrder,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.12,
		Parent = feed,
	}, {
		Kit.corner(UDim.new(0.4, 0)),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	Skin.Apply(entry, "Panel")
	Kit.new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = tier.Color,
		Parent = entry,
	}, { Kit.corner(UDim.new(1, 0)) })
	local hex = tier.Color:ToHex()
	local text = Kit.label({
		Text = `<font color="#{hex}">{tier.Name}</font> {card.Name}{suffix}`,
		RichText = true,
		Font = Theme.Font.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 14, 0.15, 0),
		Size = UDim2.new(1, -14, 0.7, 0),
		Parent = entry,
	}, 16)

	-- Keep the latest seven.
	local entries = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #entries - (if compactHud() then 2 else 3) do
		entries[i]:Destroy()
	end

	task.delay(8, function()
		if entry.Parent then
			Kit.tween(entry, 0.4, { BackgroundTransparency = 1 })
			Kit.tween(text, 0.4, { TextTransparency = 1 }).Completed:Wait()
			entry:Destroy()
		end
	end)
end

-- `global`: the pull happened on another server (GlobalAnnounce: Secret borders reach every server).
function Hud.Announce(playerName: string, cardId: string, borderId: string?, foilId: string?, global: boolean?)
	local card = Cards.Get(cardId)
	if card == nil then
		return
	end
	local border = Borders.Get(borderId)
	local secret = borderId == "Secret"
	bannerToken += 1
	local token = bannerToken
	-- A Secret border gets the gold server banner; others wear their border's colours.
	banner.Gradient.Color = if secret
		then ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(200, 130, 20))
		else border.Gradient
	banner.BackgroundColor3 = Color3.new(1, 1, 1)
	local what = `{string.upper(border.Name)} BORDER`
	if foilId == "demon" then
		what = `{string.upper(Foils.Get(foilId).Name)} {what}`
	end
	bannerLabel.Text = if secret
		then `[{if global then "GLOBAL" else "SERVER"}] {playerName} rolled a <b>SECRET BORDER</b> {card.Name}!`
		else `{playerName} rolled a <b>{what}</b> {card.Name}, {card.Title}!`
	bannerLabel.TextColor3 = if secret then Color3.fromRGB(40, 24, 0) else Color3.new(1, 1, 1)
	banner.Visible = true
	Kit.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, 72) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		if token == bannerToken then
			Kit.tween(banner, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Connect(function()
				if token == bannerToken then
					banner.Visible = false
				end
			end)
		end
	end)
end

return Hud
