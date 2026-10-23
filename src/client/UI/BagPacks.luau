--!nonstrict
-- The BAG's PACKS tab: Roll Packs from boss wins and tower floors (Packs.luau), one tile per pack size
-- with how many you hold and OPEN. A pack is just rolls made at your luck when you open it, so opening
-- under a luck potion or a LUCKY STORM gives better cards. The pulls play over the page (PackOpen).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared.Packs)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local PackOpen = require(script.Parent.PackOpen)
local State = require(script.Parent.Parent.State)

local BagPacks = {}

local page: Frame
local grid: Frame
local header: TextLabel
local hint: (string) -> ()
local revealing = false

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The opened pack over the whole page, then a DONE button (and OPEN ANOTHER while there are more).
local function reveal(result)
	revealing = true
	local cover = Kit.new("Frame", {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 7, 30),
		BackgroundTransparency = 0.05,
		Active = true,
		ZIndex = 20,
		Parent = page,
	}, { Kit.corner(UDim.new(0, 18)) })
	local area = Kit.new("Frame", {
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(1, -24, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = cover,
	})
	local buttons = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(400, 48),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 22,
		Parent = cover,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local function close()
		cover:Destroy()
		revealing = false
		BagPacks.Refresh()
	end
	local done = Kit.button("DONE", Theme.Color.Quick, Theme.Color.QuickDeep, {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(170, 48),
		Parent = buttons,
	})
	done.Activated:Connect(close)
	local again = Kit.button("OPEN ANOTHER", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 48),
		Visible = (State.Packs[result.PackId] or 0) > 0,
		Parent = buttons,
	})
	again.Activated:Connect(function()
		close()
		BagPacks.Open(result.PackId)
	end)
	PackOpen.Play(area, result, function()
		if buttons.Parent then
			buttons.Visible = true
		end
	end)
end

function BagPacks.Open(packId: string)
	if revealing then
		return
	end
	local result, message = PackOpen.Open(packId)
	if result == nil then
		hint(message or "Couldn't open it")
		return
	end
	Sfx.Play("Whoosh", 0.9)
	reveal(result)
end

local function tile(pack, order: number)
	local count = State.Packs[pack.Id] or 0
	local card = Kit.tile({ Name = pack.Id, LayoutOrder = order, Size = UDim2.new(1 / #Packs.List, -14, 1, 0), Parent = grid }, pack.Color)
	Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.62, 0.4),
		BackgroundColor3 = pack.Color,
		BackgroundTransparency = 0.78,
		Parent = card,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height) })
	Kit.label({
		Name = "Icon",
		Text = pack.Icon,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.6, 0.34),
		Parent = card,
	}, 80)
	local countLabel = Kit.label({
		Name = "Count",
		Text = `x{Kit.commas(count)}`,
		Font = Theme.Font.Display,
		TextColor3 = if count > 0 then Theme.Color.Text else Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromScale(0.5, 0.12),
		Parent = card,
	}, 26)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = countLabel
	Kit.label({
		Name = "PackName",
		Text = string.upper(pack.Name),
		Font = Theme.Font.Display,
		TextColor3 = pack.Color,
		Position = UDim2.fromScale(0.05, 0.54),
		Size = UDim2.fromScale(0.9, 0.11),
		Parent = card,
	}, 24)
	Kit.label({
		Name = "Rolls",
		Text = `{Kit.commas(pack.Rolls)} rolls at your luck`,
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromScale(0.05, 0.66),
		Size = UDim2.fromScale(0.9, 0.08),
		Parent = card,
	}, 16)
	local open = Kit.button(if count > 0 then "OPEN" else "NONE YET", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromScale(0.8, 0.15),
		Parent = card,
	})
	Kit.dim(open, count == 0)
	open.Activated:Connect(function()
		if (State.Packs[pack.Id] or 0) > 0 then
			BagPacks.Open(pack.Id)
		else
			hint("Beat bosses and tower floors (every 5th) for packs")
		end
	end)
end

function BagPacks.Refresh()
	if page == nil or not page.Visible or revealing then
		return
	end
	clear(grid)
	header.Text = string.format(
		'Roll Packs: <b>%s</b>   ·   Your luck now <font color="#56D68A"><b>%.2fx</b></font>   ·   Open them during a luck potion or LUCKY STORM for better cards!',
		Kit.commas(Packs.Count(State.Packs)),
		State.Luck()
	)
	for i, pack in Packs.List do
		tile(pack, i)
	end
end

function BagPacks.Init(packPage: Frame, hintFn: (string) -> ())
	page = packPage
	hint = hintFn
	header = Kit.label({
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = page,
	}, 16)
	grid = Kit.new("Frame", {
		Name = "Grid",
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
		}),
	})
	State.Changed:Connect(function(kind)
		if kind == "packs" or kind == "all" or kind == "meta" then
			BagPacks.Refresh()
		end
	end)
end

return BagPacks
