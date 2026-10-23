--!nonstrict
-- Deck screen. Left: the Attack and Support slot columns, the deck's synergies and bonds (Elements.luau),
-- deck presets, Deck Power and Auto-build (COUNTER-BUILD when opened for a fight: weighed against that
-- squad's elements). Right: every owned card as an art tile with tabs, sort, filters and search.
-- Tap a card to put it in the deck (or take it out if it's already in). Tap a slot first to choose
-- which slot it goes in or replaces. Every change goes to the server, which validates it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Rarity = require(Shared.Rarity)
local Elements = require(Shared.Elements)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardTile = require(script.Parent.CardTile)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)
local ElementGuide = require(script.Parent.ElementGuide)
local State = require(script.Parent.Parent.State)

local DeckBuilder = {}

local modal
local columns = {} -- [row] = Frame holding the slot tiles
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local powerLabel: TextLabel
local presetLabel: TextLabel
local hintLabel: TextLabel
local slotTools: Frame
local backButton: TextButton
local tabSetters = {}
local emptyLabel: TextLabel
local returnTo: (() -> ())? = nil
local target: string? = nil -- the fight the deck screen was opened for (boss id, Tower.Id, Raid.Id)
local synergyLabel: TextLabel
local autoButton: TextButton

local tab = "Attack"
local sortBy = "Power"
local filterBy = "All"
local elementBy = "Any element"
local search = ""
local selected = nil -- { Row, Index } or nil
local working = nil -- the deck being edited (mirrors the active preset)
local hintToken = 0
local refreshQueued = false

local REASONS = {
	Duplicate = "That card is already in the deck",
	WrongType = "That slot takes the other card type",
	NotOwned = "You don't own that card",
	TooFast = "Slow down a little",
	Loading = "Still loading your cards",
}

local ROW_COLORS = { Attack = Theme.Color.Attack, Support = Theme.Color.Quick }

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.4, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function entry(id: string)
	return State.Cards[id]
end

local function findInDeck(id: string)
	for _, row in Deck.Rows do
		for i, slot in working[row] do
			if slot == id then
				return row, i
			end
		end
	end
	return nil, nil
end

local function call(action: string, preset: number, deck)
	local ok, result = pcall(function()
		return Remotes.Deck:InvokeServer(action, preset, deck)
	end)
	if ok and result then
		if result.Decks then
			State.ApplyDecks(result.Decks)
		end
		if not result.Ok then
			hint(REASONS[result.Reason] or "Couldn't save the deck")
		end
		return result.Ok
	end
	hint("Couldn't reach the server")
	return false
end

local refresh -- forward declaration

local function save()
	refresh()
	call("Save", State.Decks.Active, working)
end

local function firstEmpty(row: string): number?
	for i, id in working[row] do
		if id == "" then
			return i
		end
	end
	return nil
end

-- Tapping a card in the grid.
local function tapCard(id: string)
	local card = Cards.Get(id)
	if card == nil then
		return
	end
	local fromRow, fromIndex = findInDeck(id)
	if fromRow then
		working[fromRow][fromIndex] = ""
		selected = { Row = fromRow, Index = fromIndex }
		Sfx.Play("Click", 0.8)
		hint(`{card.Name} taken out`)
		save()
		return
	end
	local row = card.Type
	local index = nil
	if selected and selected.Row == row then
		index = selected.Index
	else
		index = firstEmpty(row)
	end
	if index == nil then
		hint(`Your {row} row is full: tap a slot to replace it`)
		return
	end
	working[row][index] = id
	local nextEmpty = firstEmpty(row)
	selected = if nextEmpty then { Row = row, Index = nextEmpty } else nil
	Sfx.Play("Click", 1.2)
	save()
end

local function moveSelected(step: number)
	if selected == nil then
		return
	end
	local slots = working[selected.Row]
	local target = selected.Index + step
	if target < 1 or target > Config.Deck.Slots or slots[selected.Index] == "" then
		return
	end
	slots[selected.Index], slots[target] = slots[target], slots[selected.Index]
	selected.Index = target
	save()
end

local function removeSelected()
	if selected and working[selected.Row][selected.Index] ~= "" then
		working[selected.Row][selected.Index] = ""
		save()
	end
end

-- Slots ---------------------------------------------------------------------------------------

local function drawSlots()
	for _, row in Deck.Rows do
		for _, child in columns[row]:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i = 1, Config.Deck.Slots do
			local id = working[row][i]
			local isSelected = selected ~= nil and selected.Row == row and selected.Index == i
			local tile
			if id ~= "" then
				local own = entry(id)
				tile = CardTile.new(id, {
					Owned = true,
					Stars = if own then own.Stars else 0,
					Fusion = if own then own.Fusion else nil,
					Border = if own then Borders.Best(own.Borders) else nil,
					Power = Deck.CardPower(id, State.Cards),
					Selected = isSelected,
					Spin = true,
				})
			else
				tile = CardTile.Empty(row, isSelected)
			end
			tile.LayoutOrder = i
			tile.Parent = columns[row]
			tile.Activated:Connect(function()
				if isSelected then
					selected = nil
				else
					selected = { Row = row, Index = i }
					if tab ~= row then
						tab = row
					end
				end
				refresh()
			end)
		end
	end
	slotTools.Visible = selected ~= nil and working[selected.Row][selected.Index] ~= ""
end

-- Grid ----------------------------------------------------------------------------------------

local SORTS = {
	Power = function(a, b)
		return Deck.CardPower(a.Id, State.Cards) > Deck.CardPower(b.Id, State.Cards)
	end,
	Rarity = function(a, b)
		local fa, fb = entry(a.Id) and entry(a.Id).Fusion, entry(b.Id) and entry(b.Id).Fusion
		return Rarity.Index(Cards.FusedRarity(a, fa)) > Rarity.Index(Cards.FusedRarity(b, fb))
	end,
	Stars = function(a, b)
		return (entry(a.Id) and entry(a.Id).Stars or 0) > (entry(b.Id) and entry(b.Id).Stars or 0)
	end,
	Name = function(a, b)
		return a.Name < b.Name
	end,
}

local function drawGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = {}
	for id in State.Cards do
		local card = Cards.Get(id)
		if card and card.Type == tab then
			local inDeck = findInDeck(id) ~= nil
			local matchesFilter = filterBy == "All" or (filterBy == "In deck" and inDeck) or (filterBy == "Not in deck" and not inDeck)
			local matchesSearch = search == "" or string.find(string.lower(card.Name), search, 1, true) ~= nil
			local matchesElement = elementBy == "Any element" or card.Element == elementBy
			if matchesFilter and matchesSearch and matchesElement then
				table.insert(list, card)
			end
		end
	end
	local compare = SORTS[sortBy] or SORTS.Power
	table.sort(list, function(a, b)
		local before, after = compare(a, b), compare(b, a)
		if before ~= after then
			return before
		end
		return a.Id < b.Id
	end)
	for i, card in list do
		local own = entry(card.Id)
		local tile = CardTile.new(card.Id, {
			Owned = true,
			Stars = own.Stars,
			Fusion = own.Fusion,
			Border = Borders.Best(own.Borders),
			Copies = own.Copies,
			Power = Deck.CardPower(card.Id, State.Cards),
			InDeck = findInDeck(card.Id) ~= nil,
		})
		tile.LayoutOrder = i
		tile.Parent = grid
		tile.Activated:Connect(function()
			tapCard(card.Id)
		end)
	end
	emptyLabel.Visible = #list == 0
	emptyLabel.Text = if search ~= "" then "No cards match your search"
		elseif filterBy ~= "All" then `No {tab} cards here`
		else `No {tab} cards yet. Keep rolling!`
end

local function sizeGrid()
	local width = grid.AbsoluteSize.X - 12
	if width <= 0 then
		return
	end
	local columnsCount = math.clamp(math.floor(width / 124), 2, 8)
	local gap = 10
	local cell = math.floor((width - gap * (columnsCount - 1)) / columnsCount)
	gridLayout.CellPadding = UDim2.fromOffset(gap, gap)
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
end

function refresh()
	if not modal.IsOpen or working == nil then
		return
	end
	drawSlots()
	drawGrid()
	for name, set in tabSetters do
		set(name == tab)
	end
	powerLabel.Text = `⚡ {Kit.commas(Deck.Power(working, State.Cards))}`
	-- Synergies and bonds this deck switches on.
	local parts = {}
	for _, active in Elements.ActiveSynergies(Deck.Elements(working)) do
		local element = Elements.Get(active.Synergy.Element)
		table.insert(parts, `<font color="#{element.Color:ToHex()}">{element.Icon} <b>{string.upper(active.Synergy.Name)}</b> {active.Count}</font>`)
	end
	local ids = {}
	for _, deckRow in Deck.Rows do
		for _, id in working[deckRow] do
			if id ~= "" then
				table.insert(ids, id)
			end
		end
	end
	for _, bond in Elements.ActiveBonds(ids) do
		table.insert(parts, `<font color="#FFBE78">🤝 <b>{string.upper(bond.Name)}</b></font>`)
	end
	-- Slot Links: each Support card's passive reaches the Attack card in its slot.
	local links = 0
	for i = 1, Config.Deck.Slots do
		local support = Cards.Get(working.Support[i] or "")
		if support and support.Link and (working.Attack[i] or "") ~= "" then
			links += 1
		end
	end
	if links > 0 then
		table.insert(parts, `<font color="#9BE8FF">🔗 <b>{links} LINK{if links == 1 then "" else "S"}</b></font>`)
	end
	local cost = Deck.Cost(working)
	table.insert(parts, `<font color="{if cost <= Config.Deck.CostCap then "#56D68A" else "#FF7846"}">COST <b>{cost}/{Config.Deck.CostCap}</b></font>`)
	synergyLabel.Text = if #parts > 1 then table.concat(parts, "  ·  ") else `2 cards of one element = a synergy · bonded pairs = a Dual Ultimate  ·  {parts[1]}`
	autoButton.Label.Text = if target then "COUNTER-BUILD" else "AUTO-BUILD"
	presetLabel.Text = `DECK {State.Decks.Active}`
	backButton.Visible = returnTo ~= nil
	task.defer(sizeGrid)
end

local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(0.5, function()
		refreshQueued = false
		refresh()
	end)
end

local function loadWorking()
	local preset = State.ActiveDeck()
	working = if preset then Deck.Copy(preset) else Deck.Empty()
end

function DeckBuilder.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "DeckGui", "Deck", Vector2.new(0.96, 0.9), Vector2.new(1300, 780))

	Controls.Search(modal.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, -10),
		Size = UDim2.fromOffset(200, 40),
	}, function(text)
		search = text
		refresh()
	end)

	-- Left: slot columns -------------------------------------------------------------
	local left = Kit.new("Frame", {
		Name = "Slots",
		Size = UDim2.new(0.32, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	local columnArea = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 1, -152),
		BackgroundTransparency = 1,
		Parent = left,
	})
	synergyLabel = Kit.label({
		Name = "Synergies",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		Position = UDim2.new(0, 0, 1, -148),
		Size = UDim2.new(1, 0, 0, 38),
		Parent = left,
	}, 16)
	Controls.Outlined(synergyLabel, 1.5)
	-- Tapping the strip explains elements, synergies and bonds.
	local synergyTap = Kit.new("TextButton", {
		Name = "SynergyTap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = synergyLabel,
	})
	synergyTap.Activated:Connect(ElementGuide.Open)
	for i, row in Deck.Rows do
		local column = Kit.new("Frame", {
			Name = row,
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 0),
			Size = UDim2.new(0.5, -6, 1, 0),
			BackgroundColor3 = ROW_COLORS[row]:Lerp(Color3.new(0, 0, 0), 0.72),
			BackgroundTransparency = 0.15,
			Parent = columnArea,
		}, {
			Kit.corner(UDim.new(0, 16)),
			Kit.stroke(ROW_COLORS[row], 3, 0),
		})
		Controls.Header(column, if row == "Attack" then "Attack" else "Support", ROW_COLORS[row], {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 36),
		})
		local slots = Kit.new("Frame", {
			Name = "Slots",
			Position = UDim2.fromOffset(8, 50),
			Size = UDim2.new(1, -16, 1, -58),
			BackgroundTransparency = 1,
			Parent = column,
		})
		-- One column of four: the column is tall and narrow, so this gives far bigger slots than 2 x 2.
		local layout = Kit.new("UIGridLayout", {
			CellSize = UDim2.new(1, 0, 0.25, -6),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = slots,
		})
		Kit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = layout })
		columns[row] = slots
	end

	-- Under the columns: selected-slot tools, presets, power, auto-build.
	local bottom = Kit.new("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundTransparency = 1,
		Parent = left,
	})
	slotTools = Kit.new("Frame", {
		Name = "SlotTools",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = bottom,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	Controls.Icon(slotTools, "◀", Controls.Purple, 1, function()
		moveSelected(-1)
	end)
	Controls.Icon(slotTools, "▶", Controls.Purple, 2, function()
		moveSelected(1)
	end)
	Controls.Icon(slotTools, "✕", Theme.Color.Danger, 3, removeSelected)

	local presetRow = Kit.new("Frame", {
		Name = "Presets",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = bottom,
	})
	Controls.Icon(presetRow, "◀", Controls.Purple, 1, function()
		local nextPreset = (State.Decks.Active - 2) % math.max(Config.Deck.Presets, #State.Decks.Presets) + 1
		call("Select", nextPreset)
	end).Position = UDim2.fromScale(0, 0)
	local rightArrow = Controls.Icon(presetRow, "▶", Controls.Purple, 2, function()
		local nextPreset = State.Decks.Active % math.max(Config.Deck.Presets, #State.Decks.Presets) + 1
		call("Select", nextPreset)
	end)
	rightArrow.AnchorPoint = Vector2.new(1, 0)
	rightArrow.Position = UDim2.fromScale(1, 0)
	presetLabel = Controls.Outlined(Kit.label({
		Text = "DECK 1",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.31, 0.5),
		Size = UDim2.new(0.3, 0, 1, 0),
		Parent = presetRow,
	}, 24), 2)
	powerLabel = Controls.Outlined(Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.65, 0.5),
		Size = UDim2.new(0.3, 0, 1, 0),
		Parent = presetRow,
	}, 24), 2)

	local actions = Kit.new("Frame", {
		Name = "Actions",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = bottom,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	backButton = Kit.button("< BOSS", Theme.Color.Roll, Theme.Color.RollDeep, {
		LayoutOrder = 0,
		Size = UDim2.new(0, 90, 1, 0),
		Parent = actions,
	})
	backButton.Activated:Connect(function()
		local back = returnTo
		returnTo = nil
		if back then
			back()
		end
	end)
	autoButton = Kit.button("AUTO-BUILD", Theme.Color.Quick, Theme.Color.QuickDeep, {
		LayoutOrder = 1,
		Size = UDim2.new(0, 160, 1, 0),
		Parent = actions,
	})
	autoButton.Activated:Connect(function()
		if call("AutoBuild", State.Decks.Active, target) then
			Sfx.Play("Upgrade", 1.1)
			hint(if target then "Rebuilt to counter this fight's elements" else "Filled with your strongest cards")
		end
	end)

	-- Right: the card grid -------------------------------------------------------------
	local right = Kit.new("Frame", {
		Name = "Collection",
		Position = UDim2.new(0.33, 8, 0, 0),
		Size = UDim2.new(0.67, -8, 1, 0),
		BackgroundColor3 = Color3.fromRGB(14, 8, 32),
		BackgroundTransparency = 0.3,
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(Color3.fromRGB(150, 110, 255), 2, 0.4) })

	local bar = Kit.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 50),
		BackgroundTransparency = 1,
		Parent = right,
	})
	local tabs = Kit.new("Frame", {
		Size = UDim2.new(0.45, 0, 0, 42),
		Position = UDim2.fromOffset(0, 4),
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i, row in Deck.Rows do
		local button, set = Controls.Tab(tabs, row, ROW_COLORS[row], i, 130)
		button.Activated:Connect(function()
			tab = row
			selected = nil
			refresh()
		end)
		tabSetters[row] = set
	end
	local options = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.55, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	Controls.Option(options, "Sort", { "Power", "Rarity", "Stars", "Name" }, 1, function(value)
		sortBy = value
		refresh()
	end)
	Controls.Option(options, "Filter", { "All", "Not in deck", "In deck" }, 2, function(value)
		filterBy = value
		refresh()
	end)
	local elementNames = { "Any element" }
	for _, element in Elements.List do
		table.insert(elementNames, element.Id)
	end
	Controls.Option(options, "Element", elementNames, 3, function(value)
		elementBy = value
		refresh()
	end)

	grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(170, 130, 255),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, { Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }) })
	gridLayout = Kit.new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = grid,
	})
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeGrid)
	emptyLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.08),
		Visible = false,
		Parent = right,
	}, 24)

	hintLabel = Controls.Outlined(Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.9, 0, 0, 26),
		ZIndex = 10,
		Parent = right,
	}, 22), 2)

	modal.OnOpen = function()
		loadWorking()
		selected = nil
		local index = firstEmpty("Attack")
		if index then
			selected = { Row = "Attack", Index = index }
		end
		refresh()
		if Deck.Count(working, "Attack") + Deck.Count(working, "Support") == 0 then
			hint("Tap cards to add them, or press AUTO-BUILD")
		end
	end

	State.Changed:Connect(function(kind)
		if not modal.IsOpen then
			return
		end
		if kind == "decks" or kind == "all" then
			loadWorking()
			refresh()
		else
			queueRefresh() -- e.g. Auto Roll results: redraw at most twice a second
		end
	end)
end

function DeckBuilder.Toggle()
	returnTo = nil
	target = nil
	modal:Toggle()
end

-- Opens the deck screen; `back` adds a button that returns to wherever it was opened from, and `fight`
-- (a boss id, Tower.Id or Raid.Id) turns AUTO-BUILD into COUNTER-BUILD for that fight.
function DeckBuilder.Open(back: (() -> ())?, fight: string?)
	returnTo = back
	target = fight
	modal:Open()
	refresh()
end

function DeckBuilder.Close()
	modal:Close()
end

return DeckBuilder
