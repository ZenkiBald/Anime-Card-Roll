--!nonstrict
-- The BAG's ROLLS tab: reward rolls saved from boss and tower wins (the roll bank, Rewards.luau), one row
-- per rarity floor with OPEN 1 / OPEN 10 / OPEN ALL. Each saved roll keeps its boss luck; the player's
-- luck when they open it multiplies on top (capped like every roll), so it pays to open them under a
-- luck potion or a LUCKY STORM. Opened cards fan out over the page with RewardReveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Rewards = require(Shared.Rewards)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local RewardReveal = require(script.Parent.RewardReveal)
local RollBank = require(script.Parent.RollBank)
local State = require(script.Parent.Parent.State)

local BagRolls = {}

local page: Frame
local list: ScrollingFrame
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

-- The opened cards over the whole page, then a DONE button.
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
		Position = UDim2.new(0, 12, 0, 40),
		Size = UDim2.new(1, -24, 1, -110),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = cover,
	})
	local done = Kit.button("DONE", Theme.Color.Quick, Theme.Color.QuickDeep, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(180, 48),
		Visible = false,
		ZIndex = 22,
		Parent = cover,
	})
	done.Activated:Connect(function()
		cover:Destroy()
		revealing = false
		BagRolls.Refresh()
	end)
	RewardReveal.Play(area, result, function()
		if done.Parent then
			done.Visible = true
		end
	end)
end

local function open(floor: string, count: number)
	if revealing then
		return
	end
	local result, message = RollBank.Open(floor, count)
	if result == nil then
		hint(message or "Couldn't open them")
		return
	end
	Sfx.Play("Whoosh", 0.9)
	reveal(result)
end

local function row(group, order: number)
	local tier = Rarity.Get(group.Floor)
	local tile = Kit.tile({ Name = group.Floor, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 92), Parent = list }, tier.Color)
	local name = Kit.label({
		Text = `🎟️ {string.upper(group.Floor)}+  ×{Kit.commas(group.Count)}`,
		Font = Theme.Font.Display,
		TextColor3 = tier.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(0.5, 0, 0, 38),
		Parent = tile,
	}, 34)
	Kit.textStroke(Color3.fromRGB(20, 8, 40), 2, 0).Parent = name
	local total = Rewards.TotalLuck(group.BestLuck, State.Luck())
	Kit.label({
		Text = string.format(
			'Every card %s or better  ·  boss luck up to <b>%.2fx</b>  ·  with your luck now <font color="#56D68A"><b>%.2fx</b></font>',
			group.Floor,
			group.BestLuck,
			total
		),
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 16, 0, 54),
		Size = UDim2.new(0.6, 0, 0, 22),
		Parent = tile,
	}, 16)
	local buttons = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.38, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = tile,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local choices = { { "OPEN 1", 1 } }
	if group.Count > 1 then
		table.insert(choices, { "OPEN 10", 10 })
	end
	if group.Count > 10 then
		table.insert(choices, { if group.Count > Rewards.MaxOpen then `OPEN {Rewards.MaxOpen}` else "OPEN ALL", Rewards.MaxOpen })
	elseif group.Count > 1 and group.Count < 10 then
		choices[2] = { "OPEN ALL", group.Count }
	end
	for i, choice in choices do
		local button = Kit.button(choice[1], if i == #choices then Theme.Color.Gold else Theme.Color.Auto, if i == #choices then Color3.fromRGB(150, 100, 10) else Theme.Color.AutoDeep, {
			LayoutOrder = i,
			Size = UDim2.new(1 / #choices, -6, 1, 0),
			Parent = buttons,
		})
		button.Activated:Connect(function()
			open(group.Floor, choice[2])
		end)
	end
end

function BagRolls.Refresh()
	if page == nil or not page.Visible or revealing then
		return
	end
	clear(list)
	local groups = Rewards.BankGroups(State.RollBank or {})
	header.Text = string.format(
		'Saved reward rolls: <b>%s</b>   ·   Your luck now <font color="#56D68A"><b>%.2fx</b></font> (potions and LUCKY STORM count)',
		Kit.commas(Rewards.BankCount(State.RollBank)),
		State.Luck()
	)
	if #groups == 0 then
		Kit.label({
			Text = "No saved rolls yet.\nBeat bosses and Infinite Tower floors: their reward rolls are saved here to open whenever you like.",
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 120),
			Parent = list,
		}, 20)
		return
	end
	for i, group in groups do
		row(group, i)
	end
end

function BagRolls.Init(rollPage: Frame, hintFn: (string) -> ())
	page = rollPage
	hint = hintFn
	header = Kit.label({
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = page,
	}, 17)
	list = Kit.new("ScrollingFrame", {
		Name = "Groups",
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = page,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	State.Changed:Connect(function(kind)
		if kind == "bank" or kind == "all" or kind == "meta" then
			BagRolls.Refresh()
		end
	end)
end

return BagRolls
