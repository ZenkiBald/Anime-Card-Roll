--!nonstrict
-- DECK (the SQUAD panel's first tab), in two halves.
--   Left, FORMATION: 4v4 SQUAD: four paired rows, the frontline Attack card of slot N on the left and
--   the backline Support card of slot N on the right, joined by its Slot Link (🔗; a pulsing BOND ACTIVE
--   when the pair is one of Elements.Bonds). Footer: Deck Power, the Cost Challenge pill (✓ VALID /
--   ⚠️ EXCEEDS LIMIT), active synergies and bonds, and AUTO-BUILD (COUNTER-BUILD when opened for a
--   fight) / CLEAR / PRESET ▾, plus ▲ ▼ ✕ for the picked slot.
--   Right, CARD VAULT: filter chips (★5, GOLD, RAINBOW, SECRET borders), Type / Sort / Element dropdowns,
--   the owned cards grid (search in the panel header), and the inspector for the picked card: name,
--   archetype, element, both trait slots, the Awakening track, EQUIP TO SLOT and VISIT TRAIT MASTER
--   (closes the panel and lays a guide line to Kenshin in town).
-- Tap a slot to pick where cards go; tap a card to inspect it (tap it again, or EQUIP, to put it in).
-- Every change goes to the server (DeckService), which validates it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Rarity = require(Shared.Rarity)
local Elements = require(Shared.Elements)
local Traits = require(Shared.Traits)
local Awaken = require(Shared.Awaken)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardTile = require(script.Parent.CardTile)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)
local ElementGuide = require(script.Parent.ElementGuide)
local Waypoint = require(script.Parent.Waypoint)
local State = require(script.Parent.Parent.State)

local DeckBuilder = {}

local CRIMSON = Color3.fromRGB(255, 70, 90)
local CYAN = Color3.fromRGB(60, 220, 255)
local ROW_COLORS = { Attack = CRIMSON, Support = CYAN }
local GOOD = Color3.fromRGB(70, 224, 150)
local BAD = Color3.fromRGB(255, 70, 90)

local REASONS = {
	Duplicate = "That card is already in the deck",
	WrongType = "That slot takes the other card type",
	NotOwned = "You don't own that card",
	TooFast = "Slow down a little",
	Loading = "Still loading your cards",
}

local modal
local rowFrames = {} -- [i] = { Attack = plate, Support = plate, Link = frame }
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local emptyLabel: TextLabel
local hintLabel: TextLabel
local powerLabel: TextLabel
local costPill: any -- children read by name
local synergyLabel: TextLabel
local slotTools: Frame
local autoButton: TextButton
local backButton: TextButton
local presetHolder: Frame
local presetButton: any = nil
local presetCount = 0
local typeButton: any
local inspector: Frame
local pulseToken = 0

local returnTo: (() -> ())? = nil
local target: string? = nil -- the fight the deck screen was opened for (boss id, Tower.Id, Raid.Id)
local selected = nil -- { Row, Index }: the picked slot
local inspectId: string? = nil -- the card in the inspector
local working = nil -- the deck being edited (mirrors the active preset)
local search = ""
local typeBy = "All"
local sortBy = "Power"
local elementBy = "Any"
local chips = { Star5 = false, Gold = false, Rainbow = false, Secret = false }
local hintToken = 0
local refreshQueued = false

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

local refresh -- below

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

-- Where card `id` would go: the picked slot of its row, else the first empty one.
local function slotFor(id: string): number?
	local card = Cards.Get(id)
	if card == nil then
		return nil
	end
	if selected and selected.Row == card.Type then
		return selected.Index
	end
	return firstEmpty(card.Type)
end

-- Puts the card in (or takes it out if it's in already).
local function equip(id: string)
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
	local index = slotFor(id)
	if index == nil then
		hint(`Your {string.lower(card.Type)} line is full: tap a slot to replace it`)
		return
	end
	working[card.Type][index] = id
	local nextEmpty = firstEmpty(card.Type)
	selected = if nextEmpty then { Row = card.Type, Index = nextEmpty } else nil
	Sfx.Play("Click", 1.2)
	save()
end

local function moveSelected(step: number)
	if selected == nil then
		return
	end
	local slots = working[selected.Row]
	local to = selected.Index + step
	if to < 1 or to > Config.Deck.Slots or slots[selected.Index] == "" then
		return
	end
	slots[selected.Index], slots[to] = slots[to], slots[selected.Index]
	selected.Index = to
	save()
end

local function removeSelected()
	if selected and working[selected.Row][selected.Index] ~= "" then
		working[selected.Row][selected.Index] = ""
		save()
	end
end

local function roman(n: number): string
	return ({ "I", "II", "III", "IV", "V" })[n] or tostring(n)
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A plain label with sensible defaults.
local function text(props: { [string]: any }, size: number): TextLabel
	local defaults = { Font = Theme.Font.Heavy, TextXAlignment = Enum.TextXAlignment.Left, RichText = true }
	for key, value in props do
		defaults[key] = value
	end
	return Kit.label(defaults, size)
end

-- Formation -----------------------------------------------------------------------------------------

-- One slot plate: number badge, mini card, name, archetype, element and power (or an empty slot).
local function drawPlate(plate: any, row: string, index: number) -- children read by name
	clear(plate)
	local id = working[row][index]
	local isSelected = selected ~= nil and selected.Row == row and selected.Index == index
	local color = ROW_COLORS[row]
	plate.UIStroke.Color = if isSelected then color else Theme.Color.Line
	plate.UIStroke.Thickness = if isSelected then 2 else 1.2
	local badge = Kit.new("Frame", {
		Name = "Slot",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55),
		ZIndex = 4,
		Parent = plate,
	}, { Kit.corner(UDim.new(0, 3)), Kit.stroke(color, 1.2, 0) })
	text({ Text = tostring(index), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = badge }, 12)
	if id == "" then
		text({
			Text = if isSelected then "▶ TAP A CARD IN THE VAULT" else "+ EMPTY SLOT",
			TextColor3 = if isSelected then color else Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -28, 0.4, 0),
			Parent = plate,
		}, 14)
		return
	end
	local card = Cards.Get(id)
	local own = entry(id)
	local tile = CardTile.new(id, {
		Owned = true,
		Stars = if own then own.Stars else 0,
		Fusion = if own then own.Fusion else nil,
		Border = if own then Borders.Best(own.Borders) else nil,
		Spin = true,
	})
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, 26, 0.5, 0)
	tile.Size = UDim2.new(0.28, 0, 0.84, 0)
	Kit.aspect(1).Parent = tile -- the biggest square that fits
	tile.Parent = plate
	tile.Activated:Connect(function()
		plate:SetAttribute("Tap", ((plate:GetAttribute("Tap") or 0) :: number) + 1)
	end)
	local rarity = Cards.FusedRarity(card, own and own.Fusion)
	local element = Elements.Get(card.Element)
	local info = Kit.new("Frame", {
		Name = "Info",
		Position = UDim2.new(0.28, 32, 0, 0),
		Size = UDim2.new(0.72, -38, 1, 0),
		BackgroundTransparency = 1,
		Parent = plate,
	})
	text({ Text = string.upper(card.Name), Font = Theme.Font.Display, TextColor3 = Rarity.Get(rarity).Color, Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.3), Parent = info }, 17)
	text({ Text = card.Title or "", Font = Theme.Font.Bold, TextColor3 = Theme.Color.Muted, Position = UDim2.fromScale(0, 0.39), Size = UDim2.fromScale(1, 0.22), Parent = info }, 12)
	text({
		Text = `{if element then `<font color="#{element.Color:ToHex()}">{element.Icon}</font>  ` else ""}<font color="#FFC42E">⚡ {Kit.commas(Deck.CardPower(id, State.Cards))}</font>`,
		Position = UDim2.fromScale(0, 0.66),
		Size = UDim2.fromScale(1, 0.26),
		Parent = info,
	}, 14)
end

-- The link between slot N's two cards: the Support card's Slot Link, and BOND ACTIVE when they're a bond.
local function drawLink(link: Frame, index: number)
	clear(link)
	local attackId, supportId = working.Attack[index] or "", working.Support[index] or ""
	local support = Cards.Get(supportId)
	local linked = attackId ~= "" and support ~= nil and support.Link ~= nil
	local bond = nil
	if attackId ~= "" and supportId ~= "" then
		for _, candidate in Elements.ActiveBonds({ attackId, supportId }) do
			bond = candidate
		end
	end
	local icon = text({
		Text = "🔗",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = if linked then 0 else 0.65,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if bond then 0.32 else 0.4),
		Size = UDim2.fromScale(0.9, 0.34),
		Parent = link,
	}, 22)
	Kit.new("Frame", {
		Name = "Beam",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if bond then 0.32 else 0.4),
		Size = UDim2.new(1, 0, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = CYAN,
		BackgroundTransparency = if linked then 0.2 else 0.85,
		ZIndex = 0,
		Parent = link,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0.2) }),
		}),
	})
	icon.ZIndex = 2
	if bond then
		local pill = Kit.new("Frame", {
			Name = "Bond",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.new(1, 4, 0.3, 0),
			BackgroundColor3 = Color3.fromRGB(40, 30, 8),
			Parent = link,
		}, { Kit.corner(UDim.new(0, 3)), Kit.stroke(Theme.Color.Gold, 1.2, 0) })
		local label = text({ Text = "BOND ACTIVE", TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = pill }, 10)
		-- A slow pulse while the screen is open.
		local token = pulseToken
		task.spawn(function()
			while token == pulseToken and pill.Parent do
				Kit.tween(pill.UIStroke, 0.6, { Transparency = 0.7 })
				Kit.tween(label, 0.6, { TextTransparency = 0.35 })
				task.wait(0.6)
				if token ~= pulseToken or pill.Parent == nil then
					break
				end
				Kit.tween(pill.UIStroke, 0.6, { Transparency = 0 })
				Kit.tween(label, 0.6, { TextTransparency = 0 })
				task.wait(0.6)
			end
		end)
	elseif linked and support then
		text({
			Text = support.Link.Name,
			TextColor3 = CYAN,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.new(1, 6, 0.24, 0),
			Parent = link,
		}, 9)
	end
end

local function drawFormation()
	pulseToken += 1
	for i, refs in rowFrames do
		drawPlate(refs.Attack, "Attack", i)
		drawPlate(refs.Support, "Support", i)
		drawLink(refs.Link, i)
	end
	slotTools.Visible = selected ~= nil and working[selected.Row][selected.Index] ~= ""
end

-- Vault ------------------------------------------------------------------------------------------------

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
	Copies = function(a, b)
		return (entry(a.Id) and entry(a.Id).Copies or 0) > (entry(b.Id) and entry(b.Id).Copies or 0)
	end,
	Name = function(a, b)
		return a.Name < b.Name
	end,
}

local function passesChips(own): boolean
	if chips.Star5 and (own.Stars or 0) < 5 then
		return false
	end
	local wantBorder = chips.Gold or chips.Rainbow or chips.Secret
	if not wantBorder then
		return true
	end
	local found = own.Borders or {}
	return (chips.Gold and found.Gold == true) or (chips.Rainbow and found.Rainbow == true) or (chips.Secret and found.Secret == true)
end

local function drawGrid()
	clear(grid)
	local list = {}
	for id, own in State.Cards do
		local card = Cards.Get(id)
		if card and (typeBy == "All" or card.Type == typeBy) then
			local matchesSearch = search == "" or string.find(string.lower(card.Name), search, 1, true) ~= nil
			local matchesElement = elementBy == "Any" or card.Element == elementBy
			if matchesSearch and matchesElement and passesChips(own) then
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
			Selected = card.Id == inspectId,
		})
		tile.LayoutOrder = i
		tile.Parent = grid
		tile.Activated:Connect(function()
			if inspectId == card.Id then
				equip(card.Id) -- a second tap puts it in (or takes it out)
			else
				inspectId = card.Id
				Sfx.Play("Click", 1)
				refresh()
			end
		end)
	end
	emptyLabel.Visible = #list == 0
	emptyLabel.Text = if search ~= "" then "No cards match your search"
		elseif next(State.Cards) == nil then "No cards yet. Keep rolling!"
		else "No cards match these filters"
end

local function sizeGrid()
	local width = grid.AbsoluteSize.X - 12
	if width <= 0 then
		return
	end
	local count = math.clamp(math.floor(width / 96), 3, 8)
	local gap = 8
	local cell = math.floor((width - gap * (count - 1)) / count)
	gridLayout.CellPadding = UDim2.fromOffset(gap, gap)
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
end

-- The inspector: the picked card's details, traits, Awakening and actions.
local function drawInspector()
	clear(inspector)
	local id = inspectId
	local card = id and Cards.Get(id)
	local own = id and entry(id)
	if card == nil or own == nil then
		text({
			Text = "Tap a card to inspect it. Tap it again to put it in your squad.",
			TextColor3 = Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.4),
			Parent = inspector,
		}, 15)
		return
	end
	local rarity = Cards.FusedRarity(card, own.Fusion)
	local element = Elements.Get(card.Element)
	local left = Kit.new("Frame", { Size = UDim2.new(0.58, -8, 1, 0), BackgroundTransparency = 1, Parent = inspector })
	text({ Text = string.upper(card.Name), Font = Theme.Font.Display, TextColor3 = Rarity.Get(rarity).Color, Size = UDim2.new(1, 0, 0, 22), Parent = left }, 20)
	text({
		Text = `{card.Title or ""}  ·  {rarity} {card.Type}{if element then `  ·  <font color="#{element.Color:ToHex()}">{element.Icon} {element.Name}</font>` else ""}`,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = left,
	}, 13)
	-- Traits: slot 1, and slot 2 once Awakening node 4 is open.
	local level = Awaken.Level(own)
	local function traitLine(slot: number, traitId: string?, y: number)
		local open = slot == 1 or level >= Traits.Slot2Node
		local trait = Traits.Get(traitId)
		local value = if not open
			then `<font color="#8A94AC">🔒 Locked: unlocks at {Awaken.Nodes[Traits.Slot2Node].Copies} dupes</font>`
			elseif trait then `<font color="#{Rarity.Get(trait.Tier).Color:ToHex()}">{trait.Icon} {trait.Name}</font>`
			else `<font color="#8A94AC">None yet</font>`
		text({ Text = `TRAIT {slot}  {value}`, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 18), Parent = left }, 14)
	end
	traitLine(1, own.Trait, 48)
	traitLine(2, own.Trait2, 70)
	-- Awakening: five pips, one per node.
	local pips = {}
	for node = 1, #Awaken.Nodes do
		table.insert(pips, if level >= node then `<font color="#3CDCFF">[●]</font>` else `<font color="#5A6480">[○]</font>`)
	end
	local copies = if (own.Fusion or 0) > 0 then "FUSED" else `{math.min(own.Copies, Config.FusionCopies)}/{Config.FusionCopies} dupes`
	text({ Text = `AWAKENING  {table.concat(pips, "")}  <font color="#8A94AC">({copies})</font>`, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 18), Parent = left }, 14)

	-- Actions.
	local actions = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.42, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = inspector,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local inRow, inIndex = findInDeck(card.Id)
	local index = slotFor(card.Id)
	local label = if inRow then `REMOVE FROM SLOT {inIndex}`
		elseif index then (if working[card.Type][index] ~= "" then `REPLACE SLOT {index}` else `EQUIP TO SLOT {index}`)
		else "PICK A SLOT FIRST"
	local primary = Kit.button(label, if inRow then Theme.Color.Danger else ROW_COLORS[card.Type], Color3.fromRGB(10, 40, 60), {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = actions,
	})
	Kit.dim(primary, not inRow and index == nil)
	primary.Activated:Connect(function()
		equip(card.Id)
	end)
	local master = Kit.button("VISIT TRAIT MASTER", Color3.fromRGB(80, 230, 200), Color3.fromRGB(10, 50, 44), {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = actions,
	})
	master.Activated:Connect(function()
		modal:Close()
		if Waypoint.To("traitmaster", "🧬 KENSHIN · TRAIT MASTER", Color3.fromRGB(80, 230, 200)) then
			hint("Follow the line to Kenshin, beside Hoshi in town")
		end
	end)
end

-- Footer and refresh -------------------------------------------------------------------------------------

local function drawCost()
	clear(costPill)
	local cost = Deck.Cost(working)
	local ok = cost <= Config.Deck.CostCap
	local color = if ok then GOOD else BAD
	costPill.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.78)
	costPill.UIStroke.Color = color
	text({
		Text = if ok then `✓ COST: {cost}/{Config.Deck.CostCap} VALID` else `⚠️ COST: {cost}/{Config.Deck.CostCap} EXCEEDS LIMIT`,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.2),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = costPill,
	}, 14)
end

local function drawPresets()
	local count = math.max(Config.Deck.Presets, #State.Decks.Presets)
	if presetButton == nil or count ~= presetCount then
		if presetButton then
			presetButton:Destroy()
		end
		presetCount = count
		local names = {}
		for i = 1, count do
			table.insert(names, `PRESET {i}`)
		end
		presetButton = Controls.Option(presetHolder, "Deck", names, 3, function(value)
			local number = tonumber(string.match(value, "%d+"))
			if number and number ~= State.Decks.Active then
				call("Select", number)
			end
		end)
		presetButton.Size = UDim2.new(1, 0, 1, 0)
	end
	presetButton.Value.Text = `PRESET {State.Decks.Active}`
end

local function drawFooter()
	powerLabel.Text = `⚡ {Kit.commas(Deck.Power(working, State.Cards))}`
	drawCost()
	local parts = {}
	for _, active in Elements.ActiveSynergies(Deck.Elements(working)) do
		local element = Elements.Get(active.Synergy.Element)
		local tier = table.find(active.Synergy.Tiers, active.Tier) or 1
		table.insert(parts, `<font color="#{element.Color:ToHex()}">{element.Icon} {active.Synergy.Name} {roman(tier)}</font>`)
	end
	local ids = {}
	for _, row in Deck.Rows do
		for _, id in working[row] do
			if id ~= "" then
				table.insert(ids, id)
			end
		end
	end
	local bonds = {}
	for _, bond in Elements.ActiveBonds(ids) do
		table.insert(bonds, `<font color="#FFC42E">🤝 {bond.Name}</font>`)
	end
	synergyLabel.Text = (if #parts > 0 then `Active Synergies: {table.concat(parts, ", ")}` else `<font color="#8A94AC">No synergy yet: 2 cards of one element switch one on</font>`)
		.. (if #bonds > 0 then `   ·   Bonds: {table.concat(bonds, ", ")}` else "")
	local auto: any = autoButton
	auto.Label.Text = if target then "COUNTER-BUILD" else "AUTO-BUILD"
	backButton.Visible = returnTo ~= nil
	drawPresets()
end

function refresh()
	if not modal.IsOpen or working == nil then
		return
	end
	drawFormation()
	drawGrid()
	drawInspector()
	drawFooter()
	if typeButton then
		typeButton.Value.Text = typeBy
	end
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

-- Init -------------------------------------------------------------------------------------------------------

local function pane(props: { [string]: any }): Frame
	local frame = Controls.Tile("Frame", props)
	frame.BackgroundTransparency = Theme.Glass.Frame
	return frame
end

-- `host`: the SQUAD panel (Modal.Tabbed); the deck screen is its DECK tab.
function DeckBuilder.Init(playerGui: Instance, host: any?)
	modal = if host then host:Page("DECK") else Modal.new(playerGui, "DeckGui", "Deck", Vector2.new(0.96, 0.9), Vector2.new(1300, 780))

	Controls.Search(modal.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, -2),
		Size = UDim2.fromOffset(200, 32),
	}, function(value)
		search = value
		refresh()
	end)

	-- LEFT: the formation --------------------------------------------------------------------------------
	local left = pane({ Name = "Formation", Size = UDim2.new(0.48, -6, 1, 0), Parent = modal.Body })
	Kit.padding(10).Parent = left
	text({ Text = "FORMATION: 4v4 SQUAD", Font = Theme.Font.Display, Size = UDim2.new(1, 0, 0, 24), Parent = left }, 22)
	Controls.Header(left, "Frontline attackers", CRIMSON, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0.44, 0, 0, 28) })
	Controls.Header(left, "Backline supports", CYAN, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.new(0.44, 0, 0, 28) })

	local rowsArea = Kit.new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66 - 112),
		BackgroundTransparency = 1,
		Parent = left,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	for i = 1, Config.Deck.Slots do
		local row = Kit.new("Frame", {
			Name = `Row{i}`,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 1 / Config.Deck.Slots, -5),
			BackgroundTransparency = 1,
			Parent = rowsArea,
		})
		local refs = {}
		for side, deckRow in { Attack = "Attack", Support = "Support" } do
			local plate = Controls.Tile("TextButton", {
				Name = deckRow,
				Position = if side == "Attack" then UDim2.new() else UDim2.new(0.56, 0, 0, 0),
				Size = UDim2.new(0.44, 0, 1, 0),
				ClipsDescendants = true,
				Parent = row,
			})
			local function pick()
				local isSelected = selected ~= nil and selected.Row == deckRow and selected.Index == i
				selected = if isSelected then nil else { Row = deckRow, Index = i }
				local id = working[deckRow][i]
				if not isSelected then
					if id ~= "" then
						inspectId = id
					end
					typeBy = deckRow -- the vault shows what this slot takes
				end
				Sfx.Play("Click", 1)
				refresh()
			end
			plate.Activated:Connect(pick)
			plate:GetAttributeChangedSignal("Tap"):Connect(pick) -- the mini card inside forwards its taps
			refs[deckRow] = plate
		end
		refs.Link = Kit.new("Frame", {
			Name = "Link",
			Position = UDim2.new(0.44, 0, 0, 0),
			Size = UDim2.new(0.12, 0, 1, 0),
			BackgroundTransparency = 1,
			Parent = row,
		})
		rowFrames[i] = refs
	end

	-- Formation footer: power, the cost pill, synergies, then the action buttons.
	local footer = Kit.new("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 106),
		BackgroundTransparency = 1,
		ZIndex = 3, -- the preset list opens upward over the rows
		Parent = left,
	})
	powerLabel = text({ Text = "", Font = Theme.Font.Display, TextColor3 = Theme.Color.Gold, Size = UDim2.new(0.34, 0, 0, 30), Parent = footer }, 24)
	costPill = Kit.new("Frame", {
		Name = "Cost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.62, 0, 0, 2),
		Size = UDim2.new(0.62, 0, 0, 26),
		BackgroundColor3 = GOOD,
		Parent = footer,
	}, { Kit.corner(UDim.new(0, 4)), Kit.stroke(GOOD, 1.2, 0) })
	synergyLabel = text({ Text = "", Font = Theme.Font.Bold, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 18), Parent = footer }, 13)
	Kit.new("TextButton", { Name = "Explain", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = synergyLabel }).Activated:Connect(ElementGuide.Open)

	local actions = Kit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = footer,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	backButton = Kit.button("< BOSS", Theme.Color.Roll, Theme.Color.RollDeep, { LayoutOrder = 0, Size = UDim2.new(0.14, 0, 1, 0), Parent = actions })
	backButton.Activated:Connect(function()
		local back = returnTo
		returnTo = nil
		if back then
			back()
		end
	end)
	autoButton = Kit.button("AUTO-BUILD", Theme.Color.Quick, Theme.Color.QuickDeep, { LayoutOrder = 1, Size = UDim2.new(0.28, 0, 1, 0), Parent = actions })
	autoButton.Activated:Connect(function()
		if call("AutoBuild", State.Decks.Active, target) then
			Sfx.Play("Upgrade", 1.1)
			hint(if target then "Rebuilt to counter this fight's elements" else "Filled with your strongest cards")
		end
	end)
	local clearButton = Kit.button("CLEAR", Theme.Color.Danger, Color3.fromRGB(60, 10, 20), { LayoutOrder = 2, Size = UDim2.new(0.16, 0, 1, 0), Parent = actions })
	clearButton.Activated:Connect(function()
		working = Deck.Empty()
		selected = { Row = "Attack", Index = 1 }
		hint("Squad cleared")
		save()
	end)
	presetHolder = Kit.new("Frame", { Name = "Preset", LayoutOrder = 3, Size = UDim2.new(0.22, 0, 1, 0), BackgroundTransparency = 1, Parent = actions })
	slotTools = Kit.new("Frame", {
		Name = "SlotTools",
		LayoutOrder = 4,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = actions,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	Controls.Icon(slotTools, "▲", Controls.Purple, 1, function()
		moveSelected(-1)
	end).Size = UDim2.new(0, 30, 1, 0)
	Controls.Icon(slotTools, "▼", Controls.Purple, 2, function()
		moveSelected(1)
	end).Size = UDim2.new(0, 30, 1, 0)
	Controls.Icon(slotTools, "✕", Theme.Color.Danger, 3, removeSelected).Size = UDim2.new(0, 30, 1, 0)

	-- RIGHT: the card vault ----------------------------------------------------------------------------
	local right = pane({ Name = "Vault", Position = UDim2.new(0.48, 6, 0, 0), Size = UDim2.new(0.52, -6, 1, 0), Parent = modal.Body })
	Kit.padding(10).Parent = right
	text({ Text = "CARD VAULT", Font = Theme.Font.Display, Size = UDim2.new(0.4, 0, 0, 24), Parent = right }, 22)
	local dropdowns = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.62, 0, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = right,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	typeButton = Controls.Option(dropdowns, "Type", { "All", "Attack", "Support" }, 1, function(value)
		typeBy = value
		refresh()
	end)
	Controls.Option(dropdowns, "Sort", { "Power", "Rarity", "Stars", "Copies", "Name" }, 2, function(value)
		sortBy = value
		refresh()
	end)
	local elementNames = { "Any" }
	for _, element in Elements.List do
		table.insert(elementNames, element.Id)
	end
	Controls.Option(dropdowns, "Element", elementNames, 3, function(value)
		elementBy = value
		refresh()
	end)
	local chipRow = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Parent = right,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	for i, chip in {
		{ "Star5", "★5", Theme.Color.Gold },
		{ "Gold", "GOLD", Borders.Get("Gold").Color },
		{ "Rainbow", "RAINBOW", Color3.fromRGB(255, 120, 220) },
		{ "Secret", "SECRET", Borders.Get("Secret").Color },
	} do
		Controls.Chip(chipRow, chip[2], chip[3], i, function(on)
			chips[chip[1]] = on
			refresh()
		end)
	end

	grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74 - 132),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = CYAN,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, { Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6) }) })
	gridLayout = Kit.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, Parent = grid })
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeGrid)
	emptyLabel = text({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.8, 0.06),
		Visible = false,
		Parent = right,
	}, 20)

	inspector = Controls.Tile("Frame", {
		Name = "Inspector",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 124),
		Parent = right,
	}, CYAN:Lerp(Theme.Color.Line, 0.5))
	Kit.padding(10).Parent = inspector

	hintLabel = text({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -136),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 10,
		Parent = right,
	}, 20)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.3).Parent = hintLabel

	modal.OnOpen = function()
		loadWorking()
		selected = nil
		local index = firstEmpty("Attack")
		if index then
			selected = { Row = "Attack", Index = index }
		end
		refresh()
		if Deck.Count(working, "Attack") + Deck.Count(working, "Support") == 0 then
			hint("Tap a card, then EQUIP, or press AUTO-BUILD")
		end
	end
	modal.OnClose = function()
		pulseToken += 1 -- stops the BOND ACTIVE pulses
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
