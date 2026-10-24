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
local Borders = require(Shared.Borders)
local Foils = require(Shared.Foils)
local RollBoost = require(Shared.RollBoost)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local State = require(script.Parent.Parent.State)
local JuicyButton = require(script.Parent.Components.JuicyButton)
local IconBadge = require(script.Parent.Components.IconBadge)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))

local Hud = {}

local gui: ScreenGui
local dock: Frame
local menu: Frame
local rollButton: any -- children are read by name
local autoButton: any
local quickButton: any
local cooldownBar: any
local topBar: any -- children read by name
local currency = {} -- [key] = chip (children read by name)
local shownValues = {} -- [key] = last number shown, to pop the chip when it changes
local hiddenBy = { Battle = false, Reveal = false }
local boostRow: Frame
local hintLabel: TextLabel
local feed: Frame
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

local function rollButtonFace(button: TextButton, title: string, sub: string, color: Color3, deep: Color3, skin: string, seal: boolean?)
	-- Urushi lacquer plate (bevelled: a light top edge, a darker base) with a double trim in the button's
	-- colour and a glowing line along the bottom; the title in that colour. `seal`: the ROLL button, a
	-- Vermilion seal face with a thick Tamahagane steel border. JuicyButton gives the sheen and spring.
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Text = ""
	Kit.corner(UDim.new(0, 4)).Parent = button
	if seal then
		-- A vermilion wax seal: warm wax face, a 2 px hot rim.
		Kit.gradient(ColorSequence.new(UITheme.Colors.VermilionHover, UITheme.Colors.VermilionWax:Lerp(UITheme.Colors.VermilionDeep, 0.45)), 90).Parent = button
		local rim = Instance.new("UIStroke")
		rim.Name = "Steel"
		rim.Thickness = 2
		rim.Color = UITheme.Colors.VermilionHover
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Parent = button
	else
		-- Recessed Urushi with a Tamahagane bezel; the button's colour only lights the bezel when it's on.
		Kit.gradient(ColorSequence.new(UITheme.Colors.UrushiInset, UITheme.Colors.UrushiBase), 90).Parent = button
		Kit.stroke(UITheme.Colors.TamahaganeSlate, 1.5, 0).Parent = button
	end
	Kit.new("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		Parent = button,
	}, { Kit.corner(UDim.new(0, 3)), Kit.stroke(if seal then UITheme.Colors.VermilionDeep else UITheme.Colors.TamahaganeRust, 1, 0.3) })
	Kit.new("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 4, 0, 1),
		Size = UDim2.new(1, -8, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		Parent = button,
	})
	Kit.new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(0.84, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = button,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	Skin.Apply(button, skin) -- uploaded button art replaces the gradient, outline and gloss
	local titleLabel = Kit.label({
		Name = "Title",
		Text = title,
		Font = Theme.Font.Display,
		TextColor3 = if seal then UITheme.Colors.WashiParchment else color:Lerp(UITheme.Colors.WashiParchment, 0.55),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.fromScale(0.86, 0.44),
		Parent = button,
	}, 40)
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
	local iconLabel = Kit.label({
		Name = "Icon",
		Text = icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.62, 0.52),
		Parent = button,
	}, 40)
	Skin.Icon(iconLabel, iconKey or text) -- uploaded icon art replaces the emoji
	local label = Kit.label({
		Name = "Label",
		Text = text,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.9, 0.24),
		Parent = button,
	}, 14)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.4).Parent = label
	local badge = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.9, 0.1),
		Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = Theme.Color.Danger,
		Visible = false,
		ZIndex = 4,
		Parent = button,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
		Kit.stroke(Color3.new(1, 1, 1), 1.5, 0),
	})
	Kit.label({
		Name = "Count",
		Text = "!",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = 5,
		Parent = badge,
	}, 14)
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
		Parent = topBar,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.gradient(ColorSequence.new(UITheme.Colors.UrushiRaised, UITheme.Colors.UrushiBlack), 90),
		Kit.stroke(UITheme.Colors.Tamahagane, 2, 0),
	})
	chip.BackgroundTransparency = Theme.Glass.Frame
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
	-- The icon in an occult badge (diamond plate, steel bezel, glow in the chip's colour), hanging off
	-- the chip's left edge.
	IconBadge.new({
		Name = "Icon",
		IconAsset = if iconKey and Skin.Icons[iconKey] then Skin.Icons[iconKey] else emoji,
		GlowColor = edge,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(1.45, 0, 1.45, 0),
		DominantAxis = Enum.DominantAxis.Height,
		ZIndex = 3,
		Parent = chip,
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
	boostRow.Visible = not hidden
	levelBar.Visible = not hidden
	eventPill.Visible = not hidden
	raidPill.Visible = raidWanted and not hidden
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
		Size = UDim2.fromScale(0.29, 0.84),
		Parent = bar,
	})
	rollButtonFace(autoButton, "AUTO", "OFF", Theme.Color.Auto, Theme.Color.AutoDeep, "AutoButton")
	lockOverlay(autoButton, "AutoRoll")

	rollButton = Kit.new("TextButton", {
		Name = "Roll",
		LayoutOrder = 2,
		Size = UDim2.fromScale(0.37, 1),
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
		Size = UDim2.fromScale(0.29, 0.84),
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
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -3),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = row,
	}, {
		Kit.corner(UDim.new(0, 3)),
		Kit.stroke(UITheme.Colors.Tamahagane, 1, 0),
	})
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
		Position = UDim2.fromScale(0, 0.22),
		Size = UDim2.fromScale(1, 0.56),
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
		Size = UDim2.new(0, 500, 0, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 22),
		}),
		Kit.new("UIScale", { Name = "Fit", Scale = 1 }),
	})
	currencyChip("Shards", 1, "Shard", "💎", Color3.fromRGB(196, 140, 255), 160)
	currencyChip("TraitShards", 2, nil, "🧬", Color3.fromRGB(80, 230, 200), 130)
	local luckChip = currencyChip("Rolls", 3, nil, "🎲", Theme.Color.Gold, 150)
	Kit.label({
		Name = "Odds",
		Text = "🍀 1x · ODDS ›",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(190, 255, 210),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 10, 1, -2),
		Size = UDim2.new(0.7, 0, 0, 16),
		ZIndex = 3,
		Parent = luckChip,
	}, 14)
	Kit.textStroke(Color3.fromRGB(10, 40, 20), 1.5, 0).Parent = luckChip.Odds
	Kit.pressable(luckChip)
	luckChip.Activated:Connect(handlers.OnOdds)
	-- Narrow phone screens: shrink the bar to fit between Roblox's top-left buttons and the edge.
	local function fitTopBar()
		local width = gui.AbsoluteSize.X
		topBar.Fit.Scale = math.clamp((width - 150) / 560, 0.5, 1)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTopBar)
	fitTopBar()

	-- Running potions: square tiles (icon + time left) in the bottom-right corner, filling right to
	-- left, above the jump button on touch screens.
	local touch = game:GetService("UserInputService").TouchEnabled
	boostRow = Kit.new("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, if touch then -130 else -12),
		Size = UDim2.fromOffset(4 * 70, 2 * 70),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(6, 6),
			FillDirectionMaxCells = 4,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			StartCorner = Enum.StartCorner.BottomRight,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	hintLabel = Kit.label({
		Name = "Hint",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, -0.62, -18),
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
		CellSize = UDim2.fromOffset(74, 74),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	menuButton("BATTLE", "⚔️", 1, Theme.Color.Roll, handlers.OnBattle)
	menuButton("BAG", "🎒", 2, Theme.Color.Quick, handlers.OnBag)
	menuButton("SQUAD", "🃏", 3, Theme.Color.Neon, handlers.OnSquad, "DECK")
	menuButton("QUESTS", "📜", 4, Theme.Color.Gold, handlers.OnQuests, "GIFTS")
	menuButton("TRAVEL", "🧭", 5, Theme.Color.Support, handlers.OnTravel)
	menuButton("STORE", "👑", 6, Color3.fromRGB(255, 196, 46), handlers.OnStore)
	if handlers.OnDev then
		menuButton("DEV", "🛠️", 7, Theme.Color.Danger, handlers.OnDev)
	end
	local menuRows = if handlers.OnDev then 4 else 3

	-- Scale the left column with the screen (a phone held sideways is ~0.6).
	local function layoutLeft()
		local size = gui.AbsoluteSize
		fitScale = math.clamp(math.min(size.X / 1100, size.Y / 640), 0.6, 1)
		local cell = math.floor(74 * fitScale)
		local pad = math.floor(8 * fitScale)
		local top = math.floor(64 * fitScale)
		questSlot.Size = UDim2.fromOffset(math.floor(300 * fitScale), math.floor(56 * fitScale))
		questSlot.Position = UDim2.fromOffset(12, top)
		local menuTop = if questActive then top + questSlot.Size.Y.Offset + pad + 4 else top
		grid.CellSize = UDim2.fromOffset(cell, cell)
		grid.CellPadding = UDim2.fromOffset(pad, pad)
		menu.Size = UDim2.fromOffset(2 * cell + pad, menuRows * cell + (menuRows - 1) * pad)
		menu.Position = UDim2.fromOffset(12, menuTop)
	end
	layoutLeftFn = layoutLeft
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLeft)
	layoutLeft()

	-- MOUNT, beside the roll console: a small dark tile (G rides / gets off). The SETTINGS gear sits in
	-- the server list's header (UI/PlayerList).
	local touchOnly = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
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
	Kit.label({
		Text = "🐾",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.6, 0.56),
		Parent = petsButton,
	}, 22)
	Kit.label({
		Text = if touchOnly then "MOUNT" else "MOUNT·G",
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
		Parent = gui,
	}, {
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(150, 120), MaxSize = Vector2.new(280, 360) }),
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})

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
	Kit.label({
		Name = "Text",
		Text = "",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.62),
		ZIndex = 21,
		Parent = toast,
	}, 24)

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
		local scale = math.clamp((gui.AbsoluteSize.X - 150) / 600, 0.55, 1)
		levelBar.Fit.Scale = scale
		levelBar.Position = UDim2.new(0.5, 0, 0, 8 + 72 * scale) -- under the top bar's ODDS label
		eventPill.Position = UDim2.new(0.5, 0, 0, 8 + 104 * scale)
		raidPill.Position = UDim2.new(0.5, 0, 0, 8 + 104 * scale + 34)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBars)
	fitBars()

	-- Potion timers, badges and the event pill tick once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			Hud.RefreshBoosts()
			Hud.RefreshBadges()
			Hud.RefreshEvent()
			Hud.RefreshRaid()
		end
	end)

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
	if event then
		text.Text = `{event.Icon} <b>{event.Name}</b> · {event.Text} · {string.format("%d:%02d", left // 60, math.floor(left % 60))}`
		eventPill.UIStroke.Color = event.Color
		eventPill.UIStroke.Transparency = 0
		eventPill.BackgroundColor3 = event.Color:Lerp(Color3.new(0, 0, 0), 0.55)
		eventPill.Size = UDim2.fromOffset(440, 28)
	else
		local index = math.floor(workspace:GetServerTimeNow() / Meta.EventEvery) % #Meta.Events + 1
		local nextEvent = Meta.Events[index]
		text.Text = `Next: {nextEvent.Icon} <b>{nextEvent.Name}</b> in {string.format("%d:%02d", untilNext // 60, math.floor(untilNext % 60))}`
		eventPill.UIStroke.Color = Color3.new(1, 1, 1)
		eventPill.UIStroke.Transparency = 0.5
		eventPill.BackgroundColor3 = Color3.fromRGB(8, 11, 17)
		eventPill.Size = UDim2.fromOffset(320, 26)
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
	local text = raidPill.Text
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
	local total = { Shards = 0, Potions = {} }
	local luckUps = 0
	for _, up in ups do
		total.Shards += up.Reward.Shards or 0
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

function Hud.Refresh()
	local s = State.Summary
	setCurrency("Shards", Kit.commas(s.Shards or 0), s.Shards or 0)
	local traitShards = s.TraitShards or State.Meta.TraitShards or 0
	setCurrency("TraitShards", Kit.commas(traitShards), traitShards)
	Hud.RefreshMomentum()
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

-- Tiles for running potions: the potion's icon and its time left.
function Hud.RefreshBoosts()
	local wanted = {}
	for i, potion in Meta.Potions do
		local left = State.PotionLeft(potion.Id)
		if left > 0 then
			wanted[potion.Id] = { Potion = potion, Left = left, Order = i }
		end
	end
	for _, tile in boostRow:GetChildren() do
		if tile:IsA("GuiObject") and wanted[tile.Name] == nil then
			tile:Destroy()
		end
	end
	for id, info in wanted do
		local tile = boostRow:FindFirstChild(id)
		if tile == nil then
			tile = Kit.new("Frame", {
				Name = id,
				LayoutOrder = info.Order,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = boostRow,
			}, {
				Kit.corner(UDim.new(0.2, 0)),
				Kit.gradient(ColorSequence.new(info.Potion.Color:Lerp(Theme.Color.Panel, 0.5), Theme.Color.Panel), 90),
				Kit.stroke(info.Potion.Color, 2, 0),
			})
			Kit.label({
				Name = "Icon",
				Text = info.Potion.Icon,
				Font = Theme.Font.Heavy,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.06),
				Size = UDim2.fromScale(0.7, 0.55),
				Parent = tile,
			}, 32)
			local text = Kit.label({
				Name = "Text",
				Text = "",
				Font = Theme.Font.Display,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.96),
				Size = UDim2.fromScale(0.92, 0.32),
				Parent = tile,
			}, 16)
			Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = text
			local scale = Kit.new("UIScale", { Scale = 0.3, Parent = tile })
			Kit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		local seconds = math.ceil(info.Left)
		tile.Text.Text = if seconds >= 3600
			then string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
			else string.format("%d:%02d", seconds // 60, seconds % 60)
		tile.Text.TextColor3 = if seconds <= 15 then Theme.Color.Danger else Theme.Color.Text
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

-- During a fight the roll dock and menu hide; the Auto Roll feed moves to the top-right
-- corner, clear of the cards, so Auto Roll results still show.
function Hud.SetBattleMode(on: boolean)
	hiddenBy.Battle = on
	applyHidden()
	if on then
		feed.AnchorPoint = Vector2.new(1, 0)
		feed.Position = UDim2.new(1, -12, 0.08, 0)
		feed.Size = UDim2.fromScale(0.18, 0.36)
	else
		feed.AnchorPoint = Vector2.new(1, 0.5)
		feed.Position = UDim2.new(1, -12, FEED_Y, 0)
		feed.Size = UDim2.fromScale(0.22, 0.34)
	end
end

-- The whole HUD off (behind the title screen) or back on.
function Hud.SetVisible(on: boolean)
	gui.Enabled = on
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
		surgeMeter.Position = UDim2.fromScale(0, 0.22)
		return
	end
	task.spawn(function()
		while shivering and surgeMeter.Parent do
			surgeMeter.Position = UDim2.new(0, math.random(-1, 1), 0.22, math.random(-1, 1))
			task.wait(0.05)
		end
		surgeMeter.Position = UDim2.fromScale(0, 0.22)
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
	rollButton.Title.Text = if sealed then "UNLEASH SURGE!" else "ROLL"
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
	toast.Text.Text = `🎁 {text}`
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
		BackgroundTransparency = 0.25,
		Parent = feed,
	}, {
		Kit.corner(UDim.new(0.4, 0)),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
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
	for i = 1, #entries - 7 do
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

function Hud.Announce(playerName: string, cardId: string, borderId: string?, foilId: string?)
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
		then `[SERVER] {playerName} rolled a <b>SECRET BORDER</b> {card.Name}!`
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
