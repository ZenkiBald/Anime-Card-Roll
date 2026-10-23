--!nonstrict
-- The BAG's ARTIFACTS and ACCESSORIES tabs (Items.luau gear from boss wins).
--   ARTIFACTS: the 3 worn slots on top (tap REMOVE), then every artifact you own with its level and
--     bonus and a WEAR button.
--   ACCESSORIES: what's in the bag (WEAR opens a card picker), and which card wears what (REMOVE).
-- The server checks every change (MetaService WearArtifact / RemoveArtifact / WearAccessory /
-- RemoveAccessory); these pages redraw from State.Meta.Gear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local CardTile = require(script.Parent.CardTile)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local BagGear = {}

local artifactPage: Frame
local accessoryPage: Frame
local hint: (string) -> ()

local function gear()
	return State.Meta.Gear or Items.Empty()
end

local function rarityColor(rarity: string): Color3
	return Rarity.Get(rarity).Color
end

local function call(action: string, arg: any, okText: string?)
	local result = MetaClient.Call(action, arg)
	if result.Ok then
		Sfx.Play("Upgrade", 1.2)
		if okText then
			hint(okText)
		end
	else
		hint(MetaClient.Message(result))
	end
	BagGear.Refresh()
	return result.Ok
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Big icon bubble in the item's rarity colour.
local function iconBubble(parent: Instance, icon: string, color: Color3, props: { [string]: any })
	local bubble = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.aspect(1, Enum.DominantAxis.Height),
		Kit.gradient(ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.45)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2.5, 0.15),
	})
	for key, value in props do
		bubble[key] = value
	end
	Kit.label({
		Text = icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = (bubble.ZIndex or 1) + 1,
		Parent = bubble,
	}, 60)
	return bubble
end

local function text(parent: Instance, value: string, font: Enum.Font, color: Color3, props: { [string]: any }, maxSize: number)
	local label = Kit.label({
		Text = value,
		RichText = true,
		Font = font,
		TextColor3 = color,
		Parent = parent,
	}, maxSize)
	for key, v in props do
		label[key] = v
	end
	Kit.textStroke(Color3.fromRGB(16, 8, 30), 1.5, 0.1).Parent = label
	return label
end

local function scroller(parent: Instance, props: { [string]: any }, cell: Vector2): ScrollingFrame
	local scroll = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(170, 130, 255),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	for key, value in props do
		scroll[key] = value
	end
	return scroll
end

local function emptyNote(parent: Instance, message: string)
	local box = Kit.tile({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.42), Parent = parent }, Theme.Color.Accent)
	text(box, message, Theme.Font.Display, Theme.Color.Text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
	}, 24)
end

-- ARTIFACTS ----------------------------------------------------------------------------------------

local function artifactCard(parent: Instance, artifact, level: number, worn: boolean, order: number)
	local color = rarityColor(artifact.Rarity)
	local tile = Kit.tile({ LayoutOrder = order, Parent = parent }, color)
	iconBubble(tile, artifact.Icon, color, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.5, 0.36),
	})
	text(tile, artifact.Name, Theme.Font.Display, Theme.Color.Text, {
		Position = UDim2.fromScale(0.05, 0.43),
		Size = UDim2.fromScale(0.9, 0.11),
	}, 20)
	text(tile, `<font color="#{color:ToHex()}">{string.upper(artifact.Rarity)}</font>  ·  LV {level}/{Items.MaxLevel}`, Theme.Font.Heavy, Theme.Color.Gold, {
		Position = UDim2.fromScale(0.05, 0.55),
		Size = UDim2.fromScale(0.9, 0.08),
	}, 15)
	text(tile, Items.ArtifactText(artifact, level), Theme.Font.Heavy, Color3.fromRGB(150, 255, 190), {
		Position = UDim2.fromScale(0.05, 0.64),
		Size = UDim2.fromScale(0.9, 0.09),
	}, 17)
	local button = Kit.button(if worn then "WORN" else "WEAR", if worn then Theme.Color.PanelLight else Theme.Color.Quick, Theme.Color.QuickDeep, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.8, 0.17),
		Parent = tile,
	})
	Kit.dim(button, worn)
	button.Activated:Connect(function()
		if worn then
			hint("Already worn: remove it from a slot above")
			return
		end
		if call("WearArtifact", artifact.Id, `{artifact.Name} worn: {Items.ArtifactText(artifact, level)}`) then
			Effects.Sparks(tile, color, 16, 0.8)
		end
	end)
	return tile
end

local function wornSlot(parent: Instance, index: number, id: string?)
	local data = gear()
	local artifact = id and Items.ArtifactById[id]
	local color = if artifact then rarityColor(artifact.Rarity) else Theme.Color.Line
	local slot = Kit.tile({ LayoutOrder = index, Size = UDim2.new(1 / Items.ArtifactSlots, -10, 1, 0), Parent = parent }, color)
	if artifact == nil then
		text(slot, `SLOT {index}\n<font color="#A8A2C8">empty</font>`, Theme.Font.Display, Theme.Color.Muted, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.6),
		}, 22)
		return
	end
	local level = data.Artifacts[artifact.Id] or 1
	iconBubble(slot, artifact.Icon, color, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromScale(0.3, 0.72),
	})
	text(slot, artifact.Name, Theme.Font.Display, Theme.Color.Text, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.38, 0.1),
		Size = UDim2.fromScale(0.6, 0.26),
	}, 20)
	text(slot, Items.ArtifactText(artifact, level), Theme.Font.Heavy, Color3.fromRGB(150, 255, 190), {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.38, 0.38),
		Size = UDim2.fromScale(0.6, 0.2),
	}, 16)
	local remove = Kit.button("REMOVE", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
		Position = UDim2.fromScale(0.38, 0.62),
		Size = UDim2.fromScale(0.5, 0.28),
		Parent = slot,
	})
	remove.Activated:Connect(function()
		call("RemoveArtifact", artifact.Id, `{artifact.Name} put back in the bag`)
	end)
end

local function drawArtifacts()
	clear(artifactPage)
	local data = gear()
	local worn = data.Worn or {}
	text(artifactPage, `WORN  {#worn}/{Items.ArtifactSlots}`, Theme.Font.Display, Theme.Color.Gold, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
	}, 24)
	local slots = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundTransparency = 1,
		Parent = artifactPage,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i = 1, Items.ArtifactSlots do
		wornSlot(slots, i, worn[i])
	end

	local owned = {}
	for _, artifact in Items.Artifacts do
		if data.Artifacts[artifact.Id] then
			table.insert(owned, artifact)
		end
	end
	local area = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 0, 144),
		Size = UDim2.new(1, 0, 1, -144),
		BackgroundTransparency = 1,
		Parent = artifactPage,
	})
	if #owned == 0 then
		emptyNote(
			area,
			"No artifacts yet.\nThey drop from boss wins: rare on Normal, more often (and rarer ones) on Hard and Nightmare. A duplicate levels yours up."
		)
		return
	end
	-- Rarest first.
	table.sort(owned, function(a, b)
		local ra, rb = Rarity.Index(a.Rarity), Rarity.Index(b.Rarity)
		return if ra ~= rb then ra > rb else a.Name < b.Name
	end)
	local grid = scroller(area, { Size = UDim2.fromScale(1, 1) }, Vector2.new(170, 210))
	for i, artifact in owned do
		artifactCard(grid, artifact, data.Artifacts[artifact.Id], table.find(worn, artifact.Id) ~= nil, i)
	end
end

-- ACCESSORIES --------------------------------------------------------------------------------------

local picker: Frame? = nil

local function closePicker()
	if picker then
		picker:Destroy()
		picker = nil
	end
end

-- Pick which card wears `accessory`: every owned card as a tile, its current accessory shown on it.
local function openPicker(accessory)
	closePicker()
	local data = gear()
	local panel = Kit.tile({
		Name = "Picker",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = accessoryPage,
	}, rarityColor(accessory.Rarity), "TextButton")
	picker = panel
	text(panel, `Who wears the {accessory.Icon} {accessory.Name}?  <font color="#96FFBE">{Items.AccessoryText(accessory)}</font>`, Theme.Font.Display, Theme.Color.Text, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -150, 0, 30),
		ZIndex = 31,
	}, 22)
	local back = Kit.button("BACK", Theme.Color.PanelLight, Theme.Color.Panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(120, 40),
		ZIndex = 31,
		Parent = panel,
	})
	back.Activated:Connect(closePicker)
	local grid = scroller(panel, { Position = UDim2.new(0, 10, 0, 52), Size = UDim2.new(1, -20, 1, -62), ZIndex = 31 }, Vector2.new(116, 140))
	local owned = {}
	for _, card in Cards.List do
		if State.Cards[card.Id] then
			table.insert(owned, card)
		end
	end
	table.sort(owned, function(a, b)
		return Rarity.Index(a.Rarity) > Rarity.Index(b.Rarity)
	end)
	for i, card in owned do
		local entry = State.Cards[card.Id]
		local cell = Kit.new("Frame", { LayoutOrder = i, BackgroundTransparency = 1, ZIndex = 31, Parent = grid })
		local tile = CardTile.new(card.Id, {
			Owned = true,
			Stars = entry.Stars,
			Fusion = entry.Fusion,
			Border = Borders.Best(entry.Borders),
		})
		tile.Size = UDim2.new(1, 0, 1, -22)
		tile.Parent = cell
		local wearing = data.Cards[card.Id] and Items.AccessoryById[data.Cards[card.Id]]
		text(cell, if wearing then `{wearing.Icon} {wearing.Name}` else card.Name, Theme.Font.Heavy, if wearing then Theme.Color.Gold else Theme.Color.Text, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 18),
		}, 14)
		tile.Activated:Connect(function()
			if call("WearAccessory", { Card = card.Id, Item = accessory.Id }, `{card.Name} now wears the {accessory.Name}`) then
				closePicker()
				BagGear.Refresh()
			end
		end)
	end
end

local function accessoryCard(parent: Instance, accessory, count: number, order: number)
	local color = rarityColor(accessory.Rarity)
	local tile = Kit.tile({ LayoutOrder = order, Parent = parent }, color)
	iconBubble(tile, accessory.Icon, color, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.5, 0.36),
	})
	text(tile, `x{count}`, Theme.Font.Display, Theme.Color.Gold, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromScale(0.3, 0.12),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, 22)
	text(tile, accessory.Name, Theme.Font.Display, Theme.Color.Text, {
		Position = UDim2.fromScale(0.05, 0.43),
		Size = UDim2.fromScale(0.9, 0.11),
	}, 20)
	text(tile, string.upper(accessory.Rarity), Theme.Font.Heavy, color, {
		Position = UDim2.fromScale(0.05, 0.55),
		Size = UDim2.fromScale(0.9, 0.08),
	}, 15)
	text(tile, Items.AccessoryText(accessory), Theme.Font.Heavy, Color3.fromRGB(150, 255, 190), {
		Position = UDim2.fromScale(0.05, 0.64),
		Size = UDim2.fromScale(0.9, 0.12),
	}, 15)
	local wear = Kit.button("WEAR", Theme.Color.Quick, Theme.Color.QuickDeep, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.8, 0.17),
		Parent = tile,
	})
	wear.Activated:Connect(function()
		openPicker(accessory)
	end)
end

local function drawAccessories()
	closePicker()
	clear(accessoryPage)
	local data = gear()
	-- Left: in the bag. Right: worn by cards.
	local left = Kit.new("Frame", { Size = UDim2.fromScale(0.64, 1), BackgroundTransparency = 1, Parent = accessoryPage })
	local right = Kit.tile({ Position = UDim2.new(0.66, 0, 0, 0), Size = UDim2.fromScale(0.34, 1), Parent = accessoryPage }, Theme.Color.Accent)
	text(left, "IN THE BAG", Theme.Font.Display, Theme.Color.Gold, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
	}, 24)
	local inBag = {}
	for _, accessory in Items.Accessories do
		if (data.Accessories[accessory.Id] or 0) > 0 then
			table.insert(inBag, accessory)
		end
	end
	table.sort(inBag, function(a, b)
		return Rarity.Index(a.Rarity) > Rarity.Index(b.Rarity)
	end)
	local area = Kit.new("Frame", { Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, Parent = left })
	if #inBag == 0 then
		emptyNote(area, "No accessories in the bag.\nThey drop from boss wins (better ones on harder fights). Each card can wear one.")
	else
		local grid = scroller(area, { Size = UDim2.fromScale(1, 1) }, Vector2.new(160, 200))
		for i, accessory in inBag do
			accessoryCard(grid, accessory, data.Accessories[accessory.Id], i)
		end
	end

	text(right, "WORN BY CARDS", Theme.Font.Display, Theme.Color.Gold, {
		Position = UDim2.new(0, 10, 0, 8),
		Size = UDim2.new(1, -20, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 22)
	local list = Kit.new("ScrollingFrame", {
		Position = UDim2.new(0, 8, 0, 38),
		Size = UDim2.new(1, -16, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, { Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
	local order = 0
	for cardId, itemId in data.Cards do
		local card = Cards.Get(cardId)
		local accessory = Items.AccessoryById[itemId]
		if card and accessory then
			order += 1
			local row = Kit.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -4, 0, 52),
				BackgroundColor3 = Color3.fromRGB(16, 9, 38),
				BackgroundTransparency = 0.2,
				Parent = list,
			}, { Kit.corner(UDim.new(0, 10)), Kit.stroke(rarityColor(accessory.Rarity), 1.5, 0.3) })
			text(row, `{accessory.Icon} <b>{card.Name}</b>\n<font color="#A8A2C8">{accessory.Name}</font>`, Theme.Font.Heavy, Theme.Color.Text, {
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 8, 0.1, 0),
				Size = UDim2.new(1, -96, 0.8, 0),
			}, 16)
			local remove = Kit.button("REMOVE", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(84, 34),
				Parent = row,
			})
			remove.Activated:Connect(function()
				call("RemoveAccessory", cardId, `{accessory.Name} back in the bag`)
			end)
		end
	end
	if order == 0 then
		text(list, "No card wears one yet.\nTap WEAR on an accessory.", Theme.Font.Bold, Theme.Color.Muted, {
			Size = UDim2.new(1, 0, 0, 60),
		}, 16)
	end
end

-- Setup --------------------------------------------------------------------------------------------

function BagGear.Init(artifacts: Frame, accessories: Frame, showHint: (string) -> ())
	artifactPage = artifacts
	accessoryPage = accessories
	hint = showHint
end

-- Redraws both pages (cheap: only while the BAG is open, see Bag.luau).
function BagGear.Refresh()
	if artifactPage == nil then
		return
	end
	if artifactPage.Visible then
		drawArtifacts()
	end
	if accessoryPage.Visible and picker == nil then
		drawAccessories()
	end
end

return BagGear
