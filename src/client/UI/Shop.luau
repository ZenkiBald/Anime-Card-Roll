--!nonstrict
-- Shard Shop: permanent upgrades (faster rolls, more base luck). Potions are bought in the BAG. The
-- server checks every purchase (MetaService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Shop = {}

local modal
local balance: TextLabel
local hintLabel: TextLabel
local rows = {} -- [upgradeId] = refs
local hintToken = 0

local COLORS = {
	RollSpeed = Color3.fromRGB(80, 180, 255),
	Luck = Color3.fromRGB(86, 214, 138),
}

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

-- "1.2s -> 1.1s" / "1.25x -> 1.30x"
local function effectText(upgrade, level: number): string
	if upgrade.Id == "RollSpeed" then
		local now = Config.Roll.Cooldown - level * upgrade.Step
		local nextValue = now - upgrade.Step
		return if level >= #upgrade.Costs
			then string.format("Roll cooldown %.1fs (max)", now)
			else string.format("Roll cooldown %.1fs  →  %.1fs", now, nextValue)
	end
	local now = level * upgrade.Step
	return if level >= #upgrade.Costs
		then string.format("+%.2fx base luck (max)", now)
		else string.format("+%.2fx base luck  →  +%.2fx", now, now + upgrade.Step)
end

function Shop.Refresh()
	if not modal or not modal.IsOpen then
		return
	end
	local shards = State.Summary.Shards or 0
	balance.Text = `💎 {Kit.commas(shards)} Shards`
	for id, refs in rows do
		local upgrade = Meta.UpgradeById[id]
		local level = State.Meta.Upgrades[id] or 0
		local cost = Meta.UpgradeCost(id, level)
		refs.Level.Text = `LEVEL {level} / {#upgrade.Costs}`
		refs.Effect.Text = effectText(upgrade, level)
		for i, pip in refs.Pips do
			pip.BackgroundColor3 = if i <= level then COLORS[id] else Theme.Color.Backdrop
		end
		if cost then
			refs.Buy.Label.Text = `UPGRADE  💎{Kit.commas(cost)}`
			Kit.dim(refs.Buy, shards < cost)
		else
			refs.Buy.Label.Text = "MAXED"
			Kit.dim(refs.Buy, true)
		end
	end
end

local function upgradeRow(parent: Instance, upgrade, order: number)
	local color = COLORS[upgrade.Id] or Theme.Color.Accent
	local row = Kit.tile({ Name = upgrade.Id, LayoutOrder = order, Size = UDim2.new(1, -4, 0, 104), Parent = parent }, color)
	local icon = Kit.new("Frame", {
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.gradient(ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.3)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2.5, 0.2),
	})
	Kit.label({
		Text = upgrade.Icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Parent = icon,
	}, 48)
	local name = Kit.label({
		Text = upgrade.Name,
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 100, 0, 10),
		Size = UDim2.new(0.5, 0, 0, 26),
		Parent = row,
	}, 26)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = name
	local level = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 100, 0, 38),
		Size = UDim2.new(0.3, 0, 0, 16),
		Parent = row,
	}, 14)
	local effect = Kit.label({
		Text = "",
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 100, 0, 56),
		Size = UDim2.new(0.5, 0, 0, 18),
		Parent = row,
	}, 16)
	local pipFrame = Kit.new("Frame", {
		Position = UDim2.new(0, 100, 0, 80),
		Size = UDim2.new(0.5, 0, 0, 12),
		BackgroundTransparency = 1,
		Parent = row,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local pips = {}
	for i = 1, #upgrade.Costs do
		pips[i] = Kit.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #upgrade.Costs, -4, 1, 0),
			BackgroundColor3 = Theme.Color.Backdrop,
			Parent = pipFrame,
		}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 1, 0.75) })
	end
	local buy = Kit.button("UPGRADE", color, color:Lerp(Color3.new(0, 0, 0), 0.45), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0, 52),
		Parent = row,
	})
	buy.Activated:Connect(function()
		local result = MetaClient.Call("BuyUpgrade", upgrade.Id)
		if result.Ok then
			Sfx.Play("Upgrade")
			Effects.Sparks(row, color, 18, 0.8)
			hint(`{upgrade.Name} upgraded!`)
		else
			hint(MetaClient.Message(result))
		end
		Shop.Refresh()
	end)
	rows[upgrade.Id] = { Level = level, Effect = effect, Pips = pips, Buy = buy }
end

-- `host`: the SQUAD panel (Modal.Tabbed); the Shard upgrades are the right half of its UPGRADES tab.
function Shop.Init(playerGui: Instance, host: any?)
	modal = if host then host:Page("UPGRADES", "Right", "Shard upgrades") else Modal.new(playerGui, "ShopGui", "SHARD SHOP", Vector2.new(0.66, 0.78), Vector2.new(760, 540))

	balance = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Color3.fromRGB(212, 224, 247),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 4),
		Size = UDim2.new(0.34, 0, 0, 26),
		Parent = modal.Header,
	}, 24)
	Kit.textStroke(Color3.fromRGB(17, 22, 34), 2, 0).Parent = balance
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 32),
		Size = UDim2.new(0.4, 0, 0, 20),
		Parent = modal.Header,
	}, 16)

	local list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})
	for i, upgrade in Meta.Upgrades do
		upgradeRow(list, upgrade, i)
	end
	Kit.label({
		LayoutOrder = 10,
		Text = "Earn Shards from boss wins, daily quests, gifts, the daily streak and Index rewards. Potions are in the BAG.",
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = list,
	}, 14)

	modal.OnOpen = Shop.Refresh
	State.Changed:Connect(Shop.Refresh)
end

function Shop.Toggle()
	modal:Toggle()
end

return Shop
