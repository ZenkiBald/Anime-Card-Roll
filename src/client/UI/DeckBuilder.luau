--!nonstrict
-- DECK (the SQUAD panel's first tab), in two halves.
--   Left, FORMATION: 4v4 SQUAD: four paired rows, the frontline Attack card of slot N on the left and
--   the backline Support card of slot N on the right, joined by its Slot Link (🔗; a pulsing BOND ACTIVE
--   when the pair is one of Elements.Bonds). Footer: Deck Power, the Cost Challenge pill (✓ READY, or a
--   neutral "over the cap": it only matters for the Cost Challenge), active synergies and bonds, and
--   AUTO-BUILD (COUNTER-BUILD when opened for a fight) / CLEAR / PRESET ▾, plus ▲ ▼ ✕ for the picked slot.
--   Right, CARD VAULT: filter chips (★5, GOLD, RAINBOW, SECRET borders), Type / Sort / Element dropdowns,
--   the owned cards grid (search in the panel header), and the inspector for the picked card: name,
--   archetype, element, both trait slots, the Awakening track, EQUIP TO SLOT and VISIT TRAIT MASTER
--   (closes the panel and lays a guide line to Kenshin in town).
-- Tap a slot to pick where cards go; tap a card to inspect it, then use the explicit EQUIP / REMOVE button.
-- Every change goes to the server (DeckService), which validates it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local CardInfo = require(Shared.CardInfo)
local Borders = require(Shared.Borders)
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Elements = require(Shared.Elements)
local Awaken = require(Shared.Awaken)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))
local Modal = require(script.Parent.Modal)
local CardTile = require(script.Parent.CardTile)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)
local ElementGuide = require(script.Parent.ElementGuide)
local Waypoint = require(script.Parent.Waypoint)
local CardTooltip = require(script.Parent.CardTooltip)
local Index = require(script.Parent.Index)
local ElementUi = require(script.Parent.ElementUi)
local MetaClient = require(script.Parent.Parent.MetaClient)
local Avatars = require(script.Parent.Parent.Avatars)
local State = require(script.Parent.Parent.State)

local DeckBuilder = {}

local CRIMSON = Color3.fromRGB(255, 70, 90)
local C = UITheme.Colors
local CYAN = C.SpiritCyan -- the backline and its spirit tethers (soft spirit blue, not electric cyan)
local ROW_COLORS = { Attack = CRIMSON, Support = CYAN }

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
local synergyStrip: Frame -- the active synergies and bonds as small tags
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
local inspectBorder: string? = nil -- which of its borders (each border it has copies at is its own vault tile)
local FIRE_GOLD = Color3.fromRGB(255, 170, 60) -- Hoshi's waypoint
local working = nil -- the deck being edited (mirrors the active preset)
local search = ""
local typeBy = "All"
local sortBy = "Rating"
local elementBy = "Any"
local chips = { Gold = false, Rainbow = false, Secret = false }
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

-- Makes the card fight at `border` (the server keeps the pick; its best border clears it).
local function playAs(id: string, border: string): boolean
	local own = entry(id)
	if own == nil or Deck.PlayBorder(own) == border then
		return true
	end
	local ok, result = pcall(function()
		return Remotes.Deck:InvokeServer("PlayAs", State.Decks.Active, { Card = id, Border = border })
	end)
	if ok and result and result.Ok then
		own.Play = result.Play
		State.ApplyCard(id, own)
		return true
	end
	hint("Couldn't switch the border, try again")
	return false
end

-- Puts the card in at `border` (default: the border it fights at), switches its border if it's in at
-- another one, or takes it out if it's in at this one.
local function equip(id: string, border: string?)
	local card = Cards.Get(id)
	if card == nil then
		return
	end
	local fromRow, fromIndex = findInDeck(id)
	local want = border or Deck.PlayBorder(entry(id))
	if fromRow and Deck.PlayBorder(entry(id)) ~= want then
		if playAs(id, want) then
			Sfx.Play("Click", 1.2)
			hint(`{card.Name} now fights as {Borders.Get(want).Name}`)
			refresh()
		end
		return
	end
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
	if not playAs(id, want) then
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
		-- A sunken well with a rust inner edge.
		Kit.new("Frame", {
			Name = "Well",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundColor3 = C.UrushiInset,
			Parent = plate,
		}, { Kit.corner(UDim.new(0, 3)), Kit.stroke(C.TamahaganeRust, 1.5, 0) })
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
		Border = if own then Deck.PlayBorder(own) else nil,
		Spin = true,
	})
	CardTooltip.Attach(tile, function()
		local now = entry(id)
		return id, if now then Deck.PlayBorder(now) else nil
	end)
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, 26, 0.5, 0)
	tile.Size = UDim2.new(0.28, 0, 0.84, 0)
	Kit.aspect(1).Parent = tile -- the biggest square that fits
	tile.Parent = plate
	-- The adjacent text carries the name; thumbnail-sized text is unreadable on a phone.
	for _, name in { "CardName", "Rarity" } do
		local label = tile:FindFirstChild(name)
		if label and label:IsA("GuiObject") then
			label.Visible = false
		end
	end
	tile.Activated:Connect(function()
		plate:SetAttribute("Tap", ((plate:GetAttribute("Tap") or 0) :: number) + 1)
	end)
	local border = Borders.Get(if own then Deck.PlayBorder(own) else nil)
	local info = Kit.new("Frame", {
		Name = "Info",
		Position = UDim2.new(0.28, 32, 0, 0),
		Size = UDim2.new(0.72, -38, 1, 0),
		BackgroundTransparency = 1,
		Parent = plate,
	})
	local compact = workspace.CurrentCamera.ViewportSize.Y < 540
	text({ Text = string.upper(card.Name), Font = Theme.Font.Display, TextColor3 = border.Color, Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, if compact then 0.5 else 0.3), Parent = info }, 17)
	text({ Text = if card.Type == "Support" then CardInfo.Job(card) else `HP {Kit.commas(Cards.Stat(card, card.HP or 0, if own then own.Stars else 0, if own then Deck.PlayBorder(own) else "Normal", if own then Awaken.Level(own) else 0))}`, Visible = not compact, Font = Theme.Font.Bold, TextColor3 = Theme.Color.Muted, Position = UDim2.fromScale(0, 0.39), Size = UDim2.fromScale(1, 0.22), Parent = info }, 12)
	-- Element and role badges, then the card's power.
	ElementUi.Badge(card.Element, {
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(0.34, 0.34),
		DominantAxis = Enum.DominantAxis.Height,
		ZIndex = 4,
		Parent = info,
	})
	local powerText = text({
		Text = CardInfo.Headline(card, if own then own.Stars else 0, if own then Deck.PlayBorder(own) else "Normal", if own then Awaken.Level(own) else 0),
		Position = UDim2.fromScale(0, 0.66),
		Size = UDim2.fromScale(1, 0.26),
		Parent = info,
	}, 14)
	-- Keep the concrete stat clear of the element badge at any plate size.
	local function placeBadges()
		local h = Kit.logicalSize(info).Y * 0.34
		powerText.Position = UDim2.new(0, h + 6, 0.66, 0)
		powerText.Size = UDim2.new(1, -(h + 6), 0.26, 0)
	end
	info:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeBadges)
	placeBadges()
end

-- The link between slot N's two cards: the Support card's Slot Link, and BOND ACTIVE when they're a bond.
local function drawLink(link: Frame, index: number)
	clear(link)
	local attackId, supportId = working.Attack[index] or "", working.Support[index] or ""
	local support = Cards.Get(supportId)
	local linked = attackId ~= "" and support ~= nil and support.Support ~= nil
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
	-- The spirit tether: a lit spirit-blue line with a soft halo when the Support links its Attack card
	-- (gold for a bond), a dim steel thread when it doesn't.
	local tetherColor = if bond then Theme.Color.Gold elseif linked then CYAN else C.TamahaganeSlate
	local y = if bond then 0.32 else 0.4
	if linked or bond then
		Kit.new("Frame", {
			Name = "Halo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.new(1, 0, 0, 10),
			BorderSizePixel = 0,
			BackgroundColor3 = tetherColor,
			BackgroundTransparency = 0.8,
			ZIndex = 0,
			Parent = link,
		}, {
			Kit.corner(UDim.new(1, 0)),
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.3) }),
			}),
		})
	end
	Kit.new("Frame", {
		Name = "Beam",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.new(1, 0, 0, if linked or bond then 3 else 1),
		BorderSizePixel = 0,
		BackgroundColor3 = tetherColor,
		BackgroundTransparency = if linked or bond then 0 else 0.3,
		ZIndex = 0,
		Parent = link,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) }),
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
			Text = `PAIR {index}`,
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

-- Every border a card has copies at is its own vault tile: { Card, Border, Copies at that border }.
local function sortRating(item)
	local card, own = item.Card, State.Cards[item.Card.Id]
	if card.Type == "Support" then return Cards.SupportScore(card, if own then own.Stars else 0, item.Border, if own then Awaken.Level(own) else 0) end
	return Deck.PowerAt(card.Id, State.Cards, item.Border)
end
local SORTS = {
	Rating = function(a, b)
		return sortRating(a) > sortRating(b)
	end,
	Border = function(a, b)
		return Borders.Index(a.Border) > Borders.Index(b.Border)
	end,
	["Copy bonus"] = function(a, b)
		return (entry(a.Card.Id) and entry(a.Card.Id).Stars or 0) > (entry(b.Card.Id) and entry(b.Card.Id).Stars or 0)
	end,
	Copies = function(a, b)
		return a.Copies > b.Copies
	end,
	Name = function(a, b)
		return a.Card.Name < b.Card.Name
	end,
}

local function passesChips(own, border: string): boolean
	local wantBorder = chips.Gold or chips.Rainbow or chips.Secret
	if not wantBorder then
		return true
	end
	return (chips.Gold and border == "Gold") or (chips.Rainbow and border == "Rainbow") or (chips.Secret and border == "Secret") or false
end

local function drawGrid()
	clear(grid)
	local list = {}
	for id, own in State.Cards do
		local card = Cards.Get(id)
		if card and (typeBy == "All" or card.Type == typeBy) then
			local matchesSearch = search == "" or string.find(string.lower(card.Name), search, 1, true) ~= nil
			local matchesElement = elementBy == "Any" or card.Element == elementBy
			if matchesSearch and matchesElement then
				local copies = own.BorderCopies or {}
				for _, border in Deck.OwnedBorders(own) do
					if passesChips(own, border) then
						table.insert(list, { Card = card, Border = border, Copies = copies[border] or own.Copies or 1 })
					end
				end
			end
		end
	end
	local compare = SORTS[sortBy] or SORTS.Rating
	table.sort(list, function(a, b)
		local before, after = compare(a, b), compare(b, a)
		if before ~= after then
			return before
		end
		if a.Card.Id ~= b.Card.Id then
			return a.Card.Id < b.Card.Id
		end
		return Borders.Index(a.Border) > Borders.Index(b.Border)
	end)
	for i, item in list do
		local card, border = item.Card, item.Border
		local own = entry(card.Id)
		local playing = Deck.PlayBorder(own) == border
		local tile = CardTile.new(card.Id, {
			Owned = true,
			Stars = own.Stars,
			Border = border,
			Copies = item.Copies, -- copies at this border
			Power = Deck.PowerAt(card.Id, State.Cards, border),
			Stats = true,
			Awaken = Awaken.Level(own),
			Fusable = item.Copies >= Config.FusionCopies and Borders.Next(border) ~= nil,
			InDeck = playing and findInDeck(card.Id) ~= nil,
			Selected = card.Id == inspectId and border == (inspectBorder or Deck.PlayBorder(own)),
		})
		tile.LayoutOrder = i
		tile.Parent = grid
		CardTooltip.Attach(tile, function()
			return card.Id, border
		end)
		tile.Activated:Connect(function()
			inspectId, inspectBorder = card.Id, border
			CardTooltip.Close()
			Sfx.Play("Click", 1)
			refresh()
		end)
	end
	emptyLabel.Visible = #list == 0
	emptyLabel.Text = if search ~= "" then "No cards match your search"
		elseif next(State.Cards) == nil then "No cards yet. Keep rolling!"
		else "No cards match these filters"
end

local function sizeGrid()
	local width = Kit.logicalSize(grid).X - 12
	if width <= 0 then
		return
	end
	-- Fewer, larger tiles on phones: long epithets need two full lines after Modal's UIScale.
	local count = math.clamp(math.floor(width / 120), 3, 7)
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
	local collapsed = workspace.CurrentCamera.ViewportSize.Y < 540 and (card == nil or own == nil)
	local reserve = if collapsed then 0 else 180
	inspector.Size = UDim2.new(1, 0, 0, reserve)
	inspector.Visible = not collapsed
	grid.Size = UDim2.new(1, 0, 1, -74 - reserve - 38)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -reserve - 12)
	if card == nil or own == nil then
		text({
			Text = "Start with AUTO-BUILD. Tap any card to compare it, then VIEW SKILLS for its effects and border upgrades.",
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
	local playing = Deck.PlayBorder(own)
	local owns = Deck.OwnedBorders(own)
	local best = if inspectBorder and table.find(owns, inspectBorder) then inspectBorder else playing
	local border = Borders.Get(best)
	local element = Elements.Get(card.Element)
	local left = Kit.new("Frame", { Name = "Facts", Size = UDim2.new(0.58, -8, 1, 0), BackgroundTransparency = 1, Parent = inspector })
	text({ Text = string.upper(card.Name), Font = Theme.Font.Display, TextColor3 = border.Color, Size = UDim2.new(1, -56, 0, 22), Parent = left }, 20)
	-- Element and role badges beside the name.
	ElementUi.Badge(card.Element, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, -2), Size = UDim2.fromOffset(26, 26), Parent = left })
	if card.Type == "Attack" then ElementUi.RoleBadge(card.Role, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(26, 26), Parent = left }) end
	text({
		-- The battle numbers first (the tooltip has the title, element and role), then the tier.
		Text = `{Kit.statsText(card, own.Stars, best, Awaken.Level(own), true)}   <font color="#{border.Color:ToHex()}">{Borders.Label(best)} · rarity {Kit.commas(Cards.Rarity(card.Id, best))}</font>`,
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = left,
	}, 13)
	-- Traits: slot 1, and slot 2 once Awakening node 4 is open.
	-- Show its job and real Basic / Skill values first; advanced progression stays in VIEW SKILLS.
	local basic, skill = Cards.Ability(card, "Basic") or Cards.Ability(card, "Passive"), Cards.Ability(card, "Skill")
	local description = if basic then CardInfo.Describe(card, basic, own.Stars, best, Awaken.Level(own)) else CardInfo.Job(card)
	text({ Name = "BasicEffect", Text = description, TextWrapped = true, TextColor3 = Theme.Color.Support, Position = UDim2.fromOffset(0, 43), Size = UDim2.new(1, 0, 0, 38), Parent = left }, 14)
	text({ Text = if skill then `SKILL every {skill.Every or 3} actions · base action {string.format("%.1f", Config.Battle.TurnSeconds * 100 / card.SPD)}s` elseif card.Type == "Support" then "PASSIVE · matching Attack slot only" else `ACTS EVERY {math.floor(Config.Battle.TurnSeconds * 100 / card.SPD * 10 + 0.5) / 10}s · blue bar = next action`, TextColor3 = Theme.Color.Muted, Position = UDim2.fromOffset(0, 83), Size = UDim2.new(1, 0, 0, 18), Parent = left }, 12)
	text({ Text = `{CardInfo.CopyBonus(own.Stars)} · {own.Copies} pulled`, TextColor3 = Theme.Color.Gold, Position = UDim2.fromOffset(0, 103), Size = UDim2.new(1, 0, 0, 18), Parent = left }, 13)
	-- Copies at every border (each is its own card in the vault) and the border it fights at.
	local piles = {}
	for _, b in owns do
		local info = Borders.Get(b)
		table.insert(piles, `<font color="#{info.Color:ToHex()}">{info.Name} x{Kit.commas((own.BorderCopies or {})[b] or 0)}</font>`)
	end
	text({
		Text = `COPIES  {table.concat(piles, " · ")}   <font color="#8A94AC">fights as {Borders.Get(playing).Name}</font>`,
		RichText = true,
		Position = UDim2.fromOffset(0, 123),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = left,
	}, 13)

	-- Actions.
	local actions = Kit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.42, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = inspector,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local inRow, inIndex = findInDeck(card.Id)
	local index = slotFor(card.Id)
	local label = if inRow and playing ~= best then `FIGHT AS {string.upper(border.Name)}`
		elseif inRow then `REMOVE FROM SLOT {inIndex}`
		elseif index then (if working[card.Type][index] ~= "" then `REPLACE SLOT {index}` else `EQUIP TO SLOT {index}`)
		else "PICK A SLOT FIRST"
	-- Quick actions: [ EQUIP ] across the top, then [ FUSE ] (copies at this border toward 100; it warps
	-- you to Hoshi, where fusing happens) and [ ROLL TRAITS ] (warps you to Kenshin), then the avatar.
	local primary = Kit.button(label, if inRow and playing == best then Theme.Color.Danger else ROW_COLORS[card.Type], Color3.fromRGB(10, 40, 60), {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = actions,
	})
	Kit.dim(primary, not inRow and index == nil)
	primary.Activated:Connect(function()
		equip(card.Id, best)
	end)
	local pair = Kit.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = actions,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local pile = (own.BorderCopies or {})[best] or 0
	local nextBorder = Borders.Next(best)
	local fusable = nextBorder ~= nil and pile >= Config.FusionCopies
	local fuseText = if nextBorder == nil then "TOP BORDER"
		elseif fusable then `FUSE → {string.upper(Borders.Get(nextBorder).Name)}`
		else `FUSE {math.min(pile, Config.FusionCopies)}/{Config.FusionCopies}`
	local fuse = Kit.button(fuseText, if fusable then C.VermilionHover else C.TamahaganeSlate, if fusable then C.VermilionWax else C.UrushiBase, {
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -3, 1, 0),
		Parent = pair,
	})
	Kit.dim(fuse, nextBorder == nil)
	local master = Kit.button("ROLL TRAITS", Color3.fromRGB(80, 230, 200), Color3.fromRGB(10, 50, 44), {
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -3, 1, 0),
		Parent = pair,
	})
	fuse.Activated:Connect(function()
		if nextBorder == nil then
			return
		end
		if not fusable then
			hint(`{Config.FusionCopies - pile} more {border.Name} copies to fuse into {Borders.Get(nextBorder).Name}`)
			return
		end
		modal:Close()
		if Waypoint.To("fuser", "🔥 HOSHI · FUSION MASTER", FIRE_GOLD) then
			hint("Follow the line to Hoshi in town to fuse")
		end
	end)
	-- EQUIP AS AVATAR: your character wears this card's element aura (plus fire footsteps on Rainbow,
	-- celestial motes on Secret) while walking. Tap again to take it off.
	local worn = State.Meta.Avatar == card.Id
	local avatar = Kit.button(if worn then "✓ WORN AS AVATAR" else "EQUIP AS AVATAR", if element then element.Color else CYAN, Color3.fromRGB(20, 26, 40), {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = actions,
	})
	local details = Kit.button("VIEW SKILLS / BONUSES", C.TamahaganeSlate, C.UrushiBase, {
		Name = "ViewSkills", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 30), Parent = actions,
	})
	details.Activated:Connect(function()
		CardTooltip.Close()
		Index.Inspect(card.Id, best, modal.Body)
	end)
	avatar.Activated:Connect(function()
		local want = if State.Meta.Avatar == card.Id then "" else card.Id
		-- Predict: the aura changes on the character this frame; the server's AuraReplication settles it.
		Avatars.Predict(want, best)
		Sfx.Play("Upgrade", 1.2)
		local result = MetaClient.Call("SetAvatar", want)
		if result and result.Ok then
			hint(if want ~= "" then `{card.Name} is now your avatar aura` else "Avatar aura off")
			drawInspector()
		else
			Avatars.Revert()
			hint("Couldn't change your avatar, try again")
		end
	end)
	master.Activated:Connect(function()
		modal:Close()
		if Waypoint.To("traitmaster", "🧬 KENSHIN · TRAIT MASTER", Color3.fromRGB(80, 230, 200)) then
			hint("Follow the line to Kenshin, beside Hoshi in town")
		end
	end)
end

-- Footer and refresh -------------------------------------------------------------------------------------

-- The Cost Challenge meter: a sunken track filling to the cap. Neutral steel when over (the cap only
-- matters for the optional Cost Challenge; every other fight is fine).
local function drawCost()
	clear(costPill)
	local cost = Deck.Cost(working, State.Cards)
	local cap = Config.Deck.CostCap
	local ok = cost <= cap
	Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(math.clamp(cost / cap, 0, 1), 1),
		BackgroundColor3 = if ok then CYAN else C.TamahaganeEdge,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = costPill,
	}, { Kit.corner(UDim.new(0, 3)) })
	text({
		Text = if ok then `COST <b>{cost}</b> / {cap}  ·  COST CHALLENGE READY` else `COST <b>{cost}</b> / {cap}  ·  over the Cost Challenge cap`,
		TextColor3 = if ok then C.WashiParchment else C.WashiGhost,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = costPill,
	}, 14)
end

-- A small synergy / bond tag: raised Urushi, a steel bezel, the element icon and parchment text.
local function tag(order: number, label: string, color: Color3)
	local frame = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.UrushiRaised,
		Parent = synergyStrip,
	}, {
		Kit.corner(UDim.new(0, 3)),
		Kit.stroke(C.TamahaganeSlate, 1, 0),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	text({
		Text = label,
		TextColor3 = C.WashiParchment,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextScaled = false,
		TextSize = 13,
		Parent = frame,
	}, 13)
	-- A thin line in the element's colour along the tag's bottom.
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -6, 1, 0),
		Size = UDim2.new(1, 12, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = frame,
	})
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
	powerLabel.Text = `{Kit.commas(Deck.Power(working, State.Cards))} <font size="13" color="#{C.WashiGhost:ToHex()}">ATTACK RATING</font>`
	drawCost()
	clear(synergyStrip)
	local count = 0
	for _, active in Elements.ActiveSynergies(Deck.Elements(working)) do
		local element = Elements.Get(active.Synergy.Element)
		local tier = table.find(active.Synergy.Tiers, active.Tier) or 1
		count += 1
		tag(count, `{element.Icon} {string.upper(active.Synergy.Name)} {roman(tier)}`, element.Color)
	end
	local ids = {}
	for _, row in Deck.Rows do
		for _, id in working[row] do
			if id ~= "" then
				table.insert(ids, id)
			end
		end
	end
	for _, bond in Elements.ActiveBonds(ids) do
		count += 1
		tag(count, `🤝 {string.upper(bond.Name)}`, Theme.Color.Gold)
	end
	if count == 0 then
		text({
			Text = "No synergy yet: 2 cards of one element switch one on (tap for the guide)",
			TextColor3 = C.WashiGhost,
			Font = Theme.Font.Bold,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextScaled = false,
			TextSize = 13,
			Parent = synergyStrip,
		}, 13)
	end
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
	text({ Text = "YOUR TEAM · 4 ATTACK + 4 SUPPORT", Font = Theme.Font.Display, Size = UDim2.new(1, 0, 0, 24), Parent = left }, 20)
	text({ Name = "TeamGuide", Text = "Only Attack cards fight. Supports have no damage or HP.\nMatching numbers pair cards: each Support modifies one attacker.", TextColor3 = Theme.Color.Muted, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34), Parent = left }, 13)
	Controls.Header(left, "ATTACK · Damage + HP", CRIMSON, { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(0.44, 0, 0, 28) })
	Controls.Header(left, "SUPPORT · PASSIVE", CYAN, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 68), Size = UDim2.new(0.44, 0, 0, 28) })

	local rowsArea = Kit.new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -104 - 112),
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
						inspectId, inspectBorder = id, nil -- the border it fights at
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
	powerLabel = text({ Text = "", Font = Theme.Font.Display, TextColor3 = C.WashiParchment, Size = UDim2.new(0.36, 0, 0, 30), Parent = footer }, 26)
	costPill = Kit.new("Frame", {
		Name = "Cost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.68, 0, 0, 2),
		Size = UDim2.new(0.62, 0, 0, 26),
		BackgroundColor3 = C.UrushiInset,
		ClipsDescendants = true,
		Parent = footer,
	}, { Kit.corner(UDim.new(0, 4)), Kit.stroke(C.TamahaganeSlate, 1.5, 0) })
	synergyStrip = Kit.new("Frame", {
		Name = "Synergies",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = footer,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
	})
	-- Tapping the strip opens the elements guide (a button over it, outside its list layout).
	Kit.new("TextButton", {
		Name = "Explain",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Parent = footer,
	}).Activated:Connect(ElementGuide.Open)

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
	-- AUTO-BUILD is the call to action (a vermilion seal); CLEAR is recessed steel.
	autoButton = Kit.button("AUTO-BUILD", C.VermilionHover, C.VermilionWax, { LayoutOrder = 1, Size = UDim2.new(0.28, 0, 1, 0), Parent = actions })
	autoButton.Activated:Connect(function()
		if call("AutoBuild", State.Decks.Active, target) then
			-- The server fights every auto-built card at its best border: drop their border picks here too.
			local built = State.ActiveDeck()
			for _, row in Deck.Rows do
				for _, id in (if built then built[row] else {}) do
					local own = State.Cards[id]
					if own then
						own.Play = nil
					end
				end
			end
			loadWorking()
			refresh()
			Sfx.Play("Upgrade", 1.1)
			hint(if target then "Rebuilt to counter this fight's elements" else "Filled with your strongest cards")
		end
	end)
	local clearButton = Kit.button("CLEAR", C.TamahaganeSlate, C.UrushiBase, { LayoutOrder = 2, Size = UDim2.new(0.16, 0, 1, 0), Parent = actions })
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
	Controls.Option(dropdowns, "Sort", { "Rating", "Border", "Copy bonus", "Copies", "Name" }, 2, function(value)
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
		Size = UDim2.new(1, 0, 1, -74 - 178),
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
		Size = UDim2.new(1, 0, 0, 140), -- name, stats, two traits, Awakening, copies per border
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
		Position = UDim2.new(0.5, 0, 1, -152),
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
		Index.CloseDetail()
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
