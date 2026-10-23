--!nonstrict
-- Live odds with the player's current luck and any pity guarantee applied.
-- Uses the same Odds module as the server, so the numbers always match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Odds = require(Shared.Odds)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local OddsPanel = {}

local modal
local rows = {} -- [rarity] = { Chance, OneIn }
local borderRows = {} -- [border id] = { Chance, OneIn }
local borderTitle: TextLabel
local luckLabel: TextLabel
local epicBar: Frame
local legendaryBar: Frame
local epicLabel: TextLabel
local legendaryLabel: TextLabel

local function pityBar(parent: Instance, y: number, color: Color3)
	local track = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 0, y + 22),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Theme.Color.PanelLight,
		Parent = parent,
	}, { Kit.corner(UDim.new(1, 0)) })
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	local label = Kit.label({
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 16,
		Text = "",
		Parent = parent,
	}, 16)
	return fill, label
end

local function refresh()
	local summary = State.Summary
	local floor = Odds.PityFloor(summary.Pity)
	local luck = State.Luck()
	local chances = Odds.Chances(luck, floor)
	for name, row in rows do
		row.Chance.Text = Odds.FormatPercent(chances[name])
		row.OneIn.Text = Odds.FormatOneIn(chances[name])
	end
	local floorText = if floor then `   ·   Next roll guaranteed {floor} or better` else ""
	luckLabel.Text = string.format("Luck %.2fx%s", luck, floorText)

	local boost = Meta.Bonus(State.Meta.Stats, State.Meta.Gear, "Border")
	local borderChances = Borders.Chances(boost)
	for id, row in borderRows do
		row.Chance.Text = Odds.FormatPercent(borderChances[id])
		row.OneIn.Text = if id == "Normal" then "" else Borders.OddsText(id, boost)
	end
	borderTitle.Text = if boost > 0
		then `BORDERS  <font color="#FF78DC">(+{math.floor(boost * 100 + 0.5)}% Border Chance)</font>`
		else "BORDERS"

	local epicLeft, legendaryLeft = Odds.PityRemaining(summary.Pity)
	epicLabel.Text = `Epic or better guaranteed within {epicLeft} rolls`
	legendaryLabel.Text = `Legendary or better guaranteed within {legendaryLeft} rolls`
	epicBar.Size = UDim2.fromScale(summary.Pity.Epic / Config.Pity.Epic, 1)
	legendaryBar.Size = UDim2.fromScale(summary.Pity.Legendary / Config.Pity.Legendary, 1)
end

function OddsPanel.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "OddsGui", "ODDS", Vector2.new(0.6, 0.86), Vector2.new(620, 640))

	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	luckLabel = Kit.label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Quick,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 17,
		Text = "",
		Parent = scroll,
	}, 17)

	for i = #Rarity.Order, 1, -1 do
		local name = Rarity.Order[i]
		local tier = Rarity.Get(name)
		local count = #(Cards.ByRarity[name] or {})
		local row = Kit.new("Frame", {
			Name = name,
			LayoutOrder = #Rarity.Order - i + 1,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroll,
		}, { Kit.corner(UDim.new(0, 10)) })
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = tier.Color,
			Parent = row,
		}, { Kit.corner(UDim.new(1, 0)) })
		Kit.label({
			Text = `<font color="#{tier.Color:ToHex()}">{string.upper(name)}</font>  <font color="#A8A2C8">{count} card{if count == 1
				then ""
				else "s"}</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 36, 0.2, 0),
			Size = UDim2.new(0.45, -36, 0.6, 0),
			Parent = row,
		}, 18)
		local chance = Kit.label({
			Name = "Chance",
			Text = "",
			Font = Theme.Font.Heavy,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.45, 0, 0.2, 0),
			Size = UDim2.new(0.25, 0, 0.6, 0),
			Parent = row,
		}, 18)
		local oneIn = Kit.label({
			Name = "OneIn",
			Text = "",
			Font = Theme.Font.Medium,
			TextColor3 = Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, 0, 0.2, 0),
			Size = UDim2.new(0.28, -6, 0.6, 0),
			Parent = row,
		}, 16)
		rows[name] = { Chance = chance, OneIn = oneIn }
	end

	-- Borders: rolled on every pull, separately from rarity (Border Chance stat raises them).
	borderTitle = Kit.label({
		LayoutOrder = 15,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		Text = "BORDERS",
		RichText = true,
		Parent = scroll,
	}, 22)
	for i = #Borders.List, 1, -1 do
		local border = Borders.List[i]
		local row = Kit.new("Frame", {
			Name = "Border" .. border.Id,
			LayoutOrder = 16 + (#Borders.List - i),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroll,
		}, { Kit.corner(UDim.new(0, 10)) })
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = row,
		}, { Kit.corner(UDim.new(0.3, 0)), Kit.gradient(border.Gradient, 45) })
		Kit.label({
			Text = `{string.upper(border.Name)}  <font color="#A8A2C8">+{math.floor(border.Bonus * 100 + 0.5)}% stats</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextColor3 = border.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 38, 0.2, 0),
			Size = UDim2.new(0.5, -38, 0.6, 0),
			Parent = row,
		}, 17)
		local chance = Kit.label({
			Name = "Chance",
			Text = "",
			Font = Theme.Font.Heavy,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.5, 0, 0.2, 0),
			Size = UDim2.new(0.22, 0, 0.6, 0),
			Parent = row,
		}, 17)
		local oneIn = Kit.label({
			Name = "OneIn",
			Text = "",
			Font = Theme.Font.Medium,
			TextColor3 = Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.72, 0, 0.2, 0),
			Size = UDim2.new(0.28, -6, 0.6, 0),
			Parent = row,
		}, 15)
		borderRows[border.Id] = { Chance = chance, OneIn = oneIn }
	end

	local pity = Kit.new("Frame", {
		Name = "Pity",
		LayoutOrder = 20,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		Parent = scroll,
	}, { Kit.new("UIPadding", { PaddingTop = UDim.new(0, 10) }) })
	epicBar, epicLabel = pityBar(pity, 0, Rarity.Get("Epic").Color)
	legendaryBar, legendaryLabel = pityBar(pity, 44, Rarity.Get("Legendary").Color)

	Kit.label({
		LayoutOrder = 30,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 14,
		Text = "Rolls are free. Each card within a rarity is equally likely. Every pull also rolls a border on its own; "
			.. "a card wears the best border it has found. Probabilities are rounded, so the displayed values may not add up to exactly 100%.",
		Parent = scroll,
	}, 14)

	modal.OnOpen = refresh
	State.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function OddsPanel.Toggle()
	modal:Toggle()
end

return OddsPanel
