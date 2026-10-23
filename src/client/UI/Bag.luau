--!nonstrict
-- BAG: everything you carry, in tabs. POTIONS: what you own, what's running (with timers), and USE /
-- BUY buttons. ARTIFACTS and ACCESSORIES (boss drops) live in BagGear.luau.
-- The server checks every use and purchase (MetaService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Controls = require(script.Parent.Controls)
local BagGear = require(script.Parent.BagGear)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Bag = {}
local Potions = Bag -- the POTIONS tab's code below refreshes through this

local modal
local pages = {} -- [tab] = Frame
local tabSetters = {} -- [tab] = function(on)
local currentTab = "POTIONS"
local summaryLabel: TextLabel
local hintLabel: TextLabel
local cards = {} -- [potionId] = { Owned, Timer, Use, Buy }
local hintToken = 0

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.2, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function clockText(seconds: number): string
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Potions.Refresh()
	if not modal or not modal.IsOpen then
		return
	end
	summaryLabel.Text = string.format(
		'Luck now <font color="#56D68A"><b>%.2fx</b></font>   ·   Roll cooldown <font color="#50B4FF"><b>%.2fs</b></font>   ·   💎 <b>%s</b> Shards',
		State.Luck(),
		State.Cooldown(),
		Kit.commas(State.Summary.Shards or 0)
	)
	for id, refs in cards do
		local potion = Meta.PotionById[id]
		local owned = State.Meta.Inventory[id] or 0
		local left = State.PotionLeft(id)
		refs.Owned.Text = `OWNED x{owned}`
		refs.Timer.Text = if left > 0 then `RUNNING  {clockText(left)}` else ""
		Kit.dim(refs.Use, owned == 0)
		refs.Buy.Label.Text = `BUY 💎{potion.Price}`
		Kit.dim(refs.Buy, (State.Summary.Shards or 0) < potion.Price)
		refs.Glow.Visible = left > 0
	end
end

local function potionCard(parent: Instance, potion, order: number)
	local card = Kit.tile({ Name = potion.Id, LayoutOrder = order, Parent = parent }, potion.Color)
	-- A soft glow of the potion's colour behind the bottle.
	local halo = Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.7, 0.4),
		BackgroundColor3 = potion.Color,
		BackgroundTransparency = 0.78,
		Parent = card,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height) })
	TweenService:Create(halo, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.88,
	}):Play()
	local glow = Kit.new("Frame", {
		Name = "Glow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = card,
	}, { Kit.corner(UDim.new(0, 16)) })
	local glowStroke = Kit.stroke(potion.Color, 4, 0)
	glowStroke.Parent = glow
	TweenService:Create(glowStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.7,
	}):Play()
	-- Bottle: a round flask with a neck, filled with the potion's colour.
	local bottle = Kit.new("Frame", {
		Name = "Bottle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.44, 0.34),
		BackgroundTransparency = 1,
		Parent = card,
	}, { Kit.aspect(0.8, Enum.DominantAxis.Height) })
	Kit.new("Frame", {
		Name = "Flask",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.78),
		BackgroundColor3 = potion.Color,
		Parent = bottle,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(potion.Color:Lerp(Color3.new(1, 1, 1), 0.35), potion.Color:Lerp(Color3.new(0, 0, 0), 0.25)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.4),
	})
	Kit.new("Frame", {
		Name = "Neck",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.36, 0.3),
		BackgroundColor3 = Color3.fromRGB(220, 230, 240),
		BackgroundTransparency = 0.3,
		Parent = bottle,
	}, { Kit.corner(UDim.new(0.3, 0)) })
	Kit.label({
		Name = "Icon",
		Text = potion.Icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.6, 0.45),
		Parent = bottle,
	}, 40)
	local name = Kit.label({
		Text = potion.Name,
		Font = Theme.Font.Display,
		Position = UDim2.fromScale(0.05, 0.41),
		Size = UDim2.fromScale(0.9, 0.11),
		Parent = card,
	}, 22)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = name
	Kit.label({
		Text = potion.Text,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromScale(0.05, 0.52),
		Size = UDim2.fromScale(0.9, 0.08),
		Parent = card,
	}, 15)
	local owned = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		Position = UDim2.fromScale(0.05, 0.6),
		Size = UDim2.fromScale(0.9, 0.085),
		Parent = card,
	}, 22)
	Kit.textStroke(Color3.fromRGB(70, 40, 0), 2, 0).Parent = owned
	local timer = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = potion.Color,
		Position = UDim2.fromScale(0.05, 0.68),
		Size = UDim2.fromScale(0.9, 0.07),
		Parent = card,
	}, 14)
	local use = Kit.button("USE", potion.Color, potion.Color:Lerp(Color3.new(0, 0, 0), 0.45), {
		Position = UDim2.fromScale(0.06, 0.78),
		Size = UDim2.fromScale(0.42, 0.16),
		Parent = card,
	})
	use.Activated:Connect(function()
		local result = MetaClient.Call("UsePotion", potion.Id)
		if result.Ok then
			Sfx.Play("Potion")
			Effects.Sparks(card, potion.Color, 16, 0.8)
			hint(`{potion.Name} running!`)
		else
			hint(MetaClient.Message(result))
		end
		Potions.Refresh()
	end)
	local buy = Kit.button("BUY", Theme.Color.Accent, Theme.Color.AccentDeep, {
		Position = UDim2.fromScale(0.52, 0.78),
		Size = UDim2.fromScale(0.42, 0.16),
		Parent = card,
	})
	buy.Activated:Connect(function()
		local result = MetaClient.Call("BuyPotion", potion.Id)
		if result.Ok then
			Sfx.Play("Reward", 1.2)
			hint(`Bought a {potion.Name}`)
		else
			hint(MetaClient.Message(result))
		end
		Potions.Refresh()
	end)
	cards[potion.Id] = { Owned = owned, Timer = timer, Use = use, Buy = buy, Glow = glow }
	return card
end

local TABS = {
	{ Name = "POTIONS", Color = Color3.fromRGB(86, 214, 138) },
	{ Name = "ARTIFACTS", Color = Color3.fromRGB(255, 196, 46) },
	{ Name = "ACCESSORIES", Color = Color3.fromRGB(176, 92, 255) },
}

local function showTab(name: string)
	currentTab = name
	for tab, page in pages do
		page.Visible = tab == name
	end
	for tab, set in tabSetters do
		set(tab == name)
	end
	Potions.Refresh()
	BagGear.Refresh()
end

local function gearPage(name: string): Frame
	return Kit.new("Frame", {
		Name = name,
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = modal.Body,
	})
end

function Bag.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "BagGui", "BAG", Vector2.new(0.8, 0.84), Vector2.new(900, 600))

	local tabRow = Kit.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(0.75, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i, tab in TABS do
		local button, set = Controls.Tab(tabRow, tab.Name, tab.Color, i, 170)
		tabSetters[tab.Name] = set
		button.Activated:Connect(function()
			showTab(tab.Name)
		end)
	end

	local potionPage = Kit.new("Frame", {
		Name = "POTIONS",
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	pages.POTIONS = potionPage
	pages.ARTIFACTS = gearPage("ARTIFACTS")
	pages.ACCESSORIES = gearPage("ACCESSORIES")
	BagGear.Init(pages.ARTIFACTS, pages.ACCESSORIES, function(text)
		hint(text)
	end)

	summaryLabel = Kit.label({
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = potionPage,
	}, 17)
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.4, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = modal.Header,
	}, 16)

	local grid = Kit.new("Frame", {
		Name = "Grid",
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = potionPage,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i, potion in Meta.Potions do
		local card = potionCard(grid, potion, i)
		card.Size = UDim2.new(1 / #Meta.Potions, -10, 1, 0)
	end
	Kit.label({
		Text = "Potions of the same kind add time (up to 1 hour). Luck potions don't stack with each other: the strongest one counts. Timers only run while you're in the game.",
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = potionPage,
	}, 13)

	modal.OnOpen = function()
		showTab(currentTab)
	end
	State.Changed:Connect(Potions.Refresh)
	-- Gear pages redraw when progression data changes (a boss drop, a test-tool grant) while open.
	State.Changed:Connect(function(kind)
		if modal.IsOpen and (kind == "meta" or kind == "all") then
			BagGear.Refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			Potions.Refresh()
		end
	end)
end

function Bag.Toggle()
	modal:Toggle()
end

return Bag
