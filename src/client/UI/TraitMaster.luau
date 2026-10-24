--!nonstrict
-- TRAIT MASTER (talk to Kenshin in town, or TRAIT MASTER in the Index card detail): Trait Shards buy
-- trait rolls (Traits.luau). Left: your cards. Right: the picked card, its trait slot(s), and the roll
-- buttons. A roll spins through trait names, lands, and asks KEEP OLD or APPLY NEW; a Legendary or Mythic
-- roll flashes gold / red and holds the buttons for a moment so it isn't tapped away. The server rolls
-- (TraitService) and keeps an unchosen roll as the card's Pending, so leaving never loses it.
-- AUTO ROLL: tick the traits you want (STOPS ON); AUTO rolls the chosen slot until one lands (up to
-- Traits.AutoMax rolls a tap) and applies it, or keeps the old trait when none did.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Rarity = require(Shared.Rarity)
local Traits = require(Shared.Traits)
local Awaken = require(Shared.Awaken)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardView = require(script.Parent.CardView)
local CardTile = require(script.Parent.CardTile)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local TraitMaster = {}

local TEAL = Color3.fromRGB(80, 230, 200)
local TEAL_DEEP = Color3.fromRGB(20, 110, 96)
local BIG_PAUSE = 1.5 -- seconds the buttons wait after a Legendary / Mythic roll

local REASONS = {
	TooFar = "Stand beside Kenshin to roll traits",
	NoTraitShards = "Not enough Trait Shards (bosses, the tower, raids, quests and gifts pay them)",
	SlotLocked = `Trait slot 2 opens at Awakening node {Traits.Slot2Node} ({Awaken.Nodes[Traits.Slot2Node].Copies} copies)`,
	Pending = "Choose KEEP or APPLY first",
	TooFast = "One roll at a time",
	NotOwned = "You don't own that card",
	Loading = "Still loading",
	NoTargets = "Tick at least one trait for AUTO ROLL to stop on",
	HasTarget = "That slot already has one of your ticked traits",
}

local modal
local grid: ScrollingFrame
local detail: Frame
local hintLabel: TextLabel
local selectedId: string? = nil
local busy = false
local hintToken = 0
local lockSlot = 1 -- LOCK & ROLL keeps this slot
local autoSlot = 1 -- AUTO ROLL rolls this slot
local targets: { [string]: boolean } = {} -- AUTO ROLL stops on these (for the session)
for _, trait in Traits.List do
	targets[trait.Id] = trait.Tier == "Mythic" -- the default: stop on a Mythic
end

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.6, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function traitText(id: string?): string
	local trait = Traits.Get(id)
	if trait == nil then
		return '<font color="#8C88A8">empty</font>'
	end
	return `<font color="#{Rarity.Get(trait.Tier).Color:ToHex()}"><b>{trait.Icon} {string.upper(trait.Name)}</b></font> ({trait.Tier}): {Traits.Text(trait.Id)}`
end

local function slotOpen(entry, slot: number): boolean
	return slot == 1 or Awaken.Level(entry) >= Traits.Slot2Node
end

local function line(parent: Instance, order: number, text: string, color: Color3, size: number, font: Enum.Font?): TextLabel
	return Kit.label({
		LayoutOrder = order,
		Text = text,
		RichText = true,
		Font = font or Theme.Font.Bold,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = size,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
		Parent = parent,
	}, size)
end

local drawGrid -- below

local function apply(result)
	if result.Card and result.CardId then
		State.ApplyCard(result.CardId, result.Card)
	end
	if result.TraitShards then
		State.Summary.TraitShards = result.TraitShards
	end
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
end

local function call(action: string, cardId: string, arg: any)
	local ok, result = pcall(function()
		return Remotes.TraitMaster:InvokeServer(action, cardId, arg)
	end)
	if not ok or result == nil then
		hint("Couldn't reach the Trait Master")
		return nil
	end
	if not result.Ok then
		if result.Card and result.CardId then
			apply(result)
		end
		hint(REASONS[result.Reason] or "Couldn't roll that")
		return nil
	end
	apply(result)
	return result
end

-- The roll: trait names flicker past, slowing down, and land on the rolled ones.
local function playRoll(stage: Frame, rolled: { string }, done: () -> ())
	clear(stage)
	local labels = {}
	for i = 1, #rolled do
		local label = Kit.label({
			Text = "",
			RichText = true,
			Font = Theme.Font.Display,
			Position = UDim2.fromScale(0, (i - 1) / #rolled),
			Size = UDim2.fromScale(1, 1 / #rolled),
			Parent = stage,
		}, 34)
		Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = label
		labels[i] = label
	end
	task.spawn(function()
		local delay = 0.04
		for _ = 1, 18 do
			for _, label in labels do
				local fake = Traits.List[math.random(1, #Traits.List)]
				label.Text = `{fake.Icon} {string.upper(fake.Name)}`
				label.TextColor3 = Rarity.Get(fake.Tier).Color
			end
			Sfx.Play("Click", 1.3)
			task.wait(delay)
			delay *= 1.12
		end
		local best = 0
		for i, id in rolled do
			local trait = Traits.Get(id)
			if trait then
				labels[i].Text = `{trait.Icon} {string.upper(trait.Name)}`
				labels[i].TextColor3 = Rarity.Get(trait.Tier).Color
				best = math.max(best, Traits.TierIndex(id))
			end
		end
		if best >= Traits.BigTier then
			local color = if best >= 4 then Color3.fromRGB(255, 60, 80) else Theme.Color.Gold
			Effects.Flash(stage, color, 0.6, 0.4)
			Effects.Sparks(stage, color, 30, 1.2)
			Sfx.Sting(if best >= 4 then "Mythic" else "Legendary", true)
			task.wait(BIG_PAUSE) -- a big roll holds the buttons so it can't be tapped away
		else
			Sfx.Play("Reward", 1.1)
		end
		done()
	end)
end

-- AUTO ROLL's run: the rolled traits race past (the last ones slower), then the hit lands big, or the
-- stage says nothing hit.
local function playAuto(stage: Frame, result, done: () -> ())
	clear(stage)
	local label = Kit.label({
		Text = "",
		RichText = true,
		Font = Theme.Font.Display,
		Size = UDim2.fromScale(1, 0.62),
		Parent = stage,
	}, 34)
	Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = label
	local count = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.32),
		Parent = stage,
	}, 18)
	task.spawn(function()
		local rolled = result.Rolled or {}
		local from = math.max(1, #rolled - 24) -- show the last two dozen at most
		for i = from, #rolled do
			local trait = Traits.Get(rolled[i])
			if trait then
				label.Text = `{trait.Icon} {string.upper(trait.Name)}`
				label.TextColor3 = Rarity.Get(trait.Tier).Color
			end
			count.Text = `ROLL {i} / {#rolled}`
			Sfx.Play("Click", 1.3)
			task.wait(if i > #rolled - 4 then 0.12 else 0.035)
		end
		local hit = Traits.Get(result.Hit)
		if hit then
			label.Text = `{hit.Icon} {string.upper(hit.Name)}!`
			label.TextColor3 = Rarity.Get(hit.Tier).Color
			count.Text = `Hit on roll {#rolled} · 🧬{result.Spent} spent · applied to slot {result.Slot}`
			local big = Traits.TierIndex(hit.Id) >= Traits.BigTier
			local color = if Traits.TierIndex(hit.Id) >= 4 then Color3.fromRGB(255, 60, 80) else Theme.Color.Gold
			Effects.Flash(stage, color, 0.6, 0.4)
			Effects.Sparks(stage, color, 30, 1.2)
			Sfx.Sting(if Traits.TierIndex(hit.Id) >= 4 then "Mythic" elseif big then "Legendary" else "Epic", true)
			task.wait(BIG_PAUSE)
		else
			count.Text = `No ticked trait in {#rolled} rolls · 🧬{result.Spent} spent · the old trait stays`
			Sfx.Play("Reward", 0.9)
			task.wait(0.6)
		end
		done()
	end)
end

local function drawDetail()
	clear(detail)
	local id = selectedId
	local entry = id and State.Cards[id]
	local card = id and Cards.Get(id)
	if entry == nil or card == nil then
		line(detail, 1, "Pick a card on the left.", Theme.Color.Muted, 18)
		return
	end
	local view = CardView.new(card.Id, {
		Owned = true,
		Stars = entry.Stars,
		Border = Borders.Best(entry.Borders),
		Trait = entry.Trait,
	})
	view.Position = UDim2.fromScale(0, 0)
	view.Size = UDim2.fromScale(0.36, 0.62)
	view.Parent = detail

	local info = Kit.new("Frame", {
		Position = UDim2.fromScale(0.39, 0),
		Size = UDim2.fromScale(0.61, 0.62),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
	line(info, 1, `🧬 <b>{Kit.commas(State.Summary.TraitShards or 0)}</b> Trait Shards`, TEAL, 22, Theme.Font.Display)
	line(info, 2, `SLOT 1   {traitText(entry.Trait)}`, Theme.Color.Text, 17, Theme.Font.Heavy)
	if slotOpen(entry, 2) then
		line(info, 3, `SLOT 2   {traitText(entry.Trait2)}`, Theme.Color.Text, 17, Theme.Font.Heavy)
	else
		local node = Awaken.Nodes[Traits.Slot2Node]
		line(info, 3, `SLOT 2   🔒 opens at {node.Copies} copies (Awakening node {node.Node}) · you have {entry.Copies}`, Theme.Color.Muted, 16)
	end
	line(
		info,
		4,
		`A roll is pure luck: Rare 75% · Epic 20% · Legendary 4.5% · Mythic 0.5%. You choose KEEP OLD or APPLY NEW, so a roll never makes a card worse.`,
		Theme.Color.Muted,
		14
	)
	-- AUTO ROLL's targets: tap a trait to tick it; AUTO stops when one lands.
	if not slotOpen(entry, 2) then
		autoSlot = 1
	end
	line(info, 5, `AUTO ROLL STOPS ON <font color="#8C88A8">(tap to tick · rolls slot {autoSlot})</font>`, TEAL, 15, Theme.Font.Heavy)
	local picks = Kit.new("Frame", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = info,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -4, 0, 26),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, trait in Traits.List do
		local color = Rarity.Get(trait.Tier).Color
		local on = targets[trait.Id] == true
		local pick = Kit.new("TextButton", {
			LayoutOrder = i,
			AutoButtonColor = false,
			Text = `{trait.Icon} {trait.Name}`,
			Font = Theme.Font.Heavy,
			TextScaled = true,
			TextColor3 = if on then Color3.fromRGB(12, 12, 18) else color,
			BackgroundColor3 = if on then color else Color3.fromRGB(14, 24, 30),
			Parent = picks,
		}, {
			Kit.corner(UDim.new(0.5, 0)),
			Kit.stroke(color, 1.5, if on then 0 else 0.4),
			Kit.new("UITextSizeConstraint", { MaxTextSize = 14 }),
			Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		})
		pick.Activated:Connect(function()
			if busy then
				return
			end
			targets[trait.Id] = not targets[trait.Id]
			drawDetail()
		end)
	end

	-- The stage: the roll animation, then the choice.
	local stage = Kit.new("Frame", {
		Name = "Stage",
		Position = UDim2.fromScale(0, 0.64),
		Size = UDim2.fromScale(1, 0.18),
		BackgroundColor3 = Color3.fromRGB(10, 26, 30),
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = detail,
	}, { Kit.corner(UDim.new(0, 14)), Kit.stroke(TEAL, 2, 0.3) })
	local buttons = Kit.new("Frame", {
		Position = UDim2.fromScale(0, 0.84),
		Size = UDim2.fromScale(1, 0.16),
		BackgroundTransparency = 1,
		Parent = detail,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	local function button(text: string, color: Color3, deep: Color3, order: number, width: number, onTap: () -> ())
		local b = Kit.button(text, color, deep, { LayoutOrder = order, Size = UDim2.new(width, -8, 0.9, 0), Parent = buttons })
		b.Activated:Connect(function()
			if not busy then
				onTap()
			end
		end)
		return b
	end

	local pending = entry.Pending
	if pending then
		-- A roll waiting for its choice.
		local slotTrait = if pending.Slot == 2 then entry.Trait2 else entry.Trait
		local labelText = `SLOT {pending.Slot} · now {traitText(slotTrait)}`
		line(stage, 1, labelText, Theme.Color.Muted, 14).Position = UDim2.fromOffset(10, 4)
		local shown = Kit.new("Frame", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -22), BackgroundTransparency = 1, Parent = stage })
		for i, rolledId in pending.Traits do
			local trait = Traits.Get(rolledId)
			if trait then
				local label = Kit.label({
					Text = `{trait.Icon} {string.upper(trait.Name)} · {Traits.Text(trait.Id)}`,
					Font = Theme.Font.Display,
					TextColor3 = Rarity.Get(trait.Tier).Color,
					Position = UDim2.fromScale(0, (i - 1) / #pending.Traits),
					Size = UDim2.fromScale(1, 1 / #pending.Traits),
					Parent = shown,
				}, 28)
				Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = label
			end
		end
		local function choose(pick: number)
			busy = true
			local result = call("Choose", id, pick)
			busy = false
			if result then
				if result.Applied then
					Sfx.Play("Upgrade", 1.2)
					hint(`Applied {(Traits.Get(result.Applied) :: any).Name}!`)
				else
					hint("Kept the old trait")
				end
				drawGrid()
			end
		end
		button("KEEP OLD", Theme.Color.PanelLight, Theme.Color.Panel, 1, 0.3, function()
			choose(0)
		end)
		if #pending.Traits == 1 then
			button("APPLY NEW", TEAL, TEAL_DEEP, 2, 0.4, function()
				choose(1)
			end)
		else
			button("APPLY TOP", TEAL, TEAL_DEEP, 2, 0.32, function()
				choose(1)
			end)
			button("APPLY BOTTOM", TEAL, TEAL_DEEP, 3, 0.36, function()
				choose(2)
			end)
		end
		return
	end

	line(stage, 1, "Roll a trait for this card.", Theme.Color.Muted, 16).Position = UDim2.fromOffset(12, 8)
	local function roll(action: string, arg: number)
		busy = true
		local result = call(action, id, arg)
		if result == nil then
			busy = false
			return
		end
		Sfx.Play("Whoosh", 1)
		playRoll(stage, result.Rolled or {}, function()
			busy = false
			if modal.IsOpen then
				drawDetail()
			end
		end)
	end
	button(`ROLL SLOT 1 · 🧬{Traits.RollCost}`, TEAL, TEAL_DEEP, 1, 0.22, function()
		roll("Roll", 1)
	end)
	local slot2 = button(`ROLL SLOT 2 · 🧬{Traits.RollCost}`, TEAL, TEAL_DEEP, 2, 0.22, function()
		roll("Roll", 2)
	end)
	local lock = button(`LOCK {lockSlot} & ROLL · 🧬{Traits.LockCost}`, Theme.Color.Gold, Color3.fromRGB(150, 100, 10), 3, 0.24, function()
		roll("LockRoll", lockSlot)
	end)
	-- AUTO ROLL: up to Traits.AutoMax rolls of the auto slot, stopping on a ticked trait.
	button(`AUTO SLOT {autoSlot} · up to {Traits.AutoMax}`, Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 30, 100), 4, 0.24, function()
		local list = {}
		for traitId, on in targets do
			if on then
				table.insert(list, traitId)
			end
		end
		if #list == 0 then
			hint(REASONS.NoTargets)
			return
		end
		busy = true
		local result = call("AutoRoll", id, { Slot = autoSlot, Targets = list })
		if result == nil then
			busy = false
			return
		end
		Sfx.Play("Whoosh", 1)
		playAuto(stage, result, function()
			busy = false
			if modal.IsOpen then
				drawGrid()
			end
		end)
	end)
	if not slotOpen(entry, 2) then
		Kit.dim(slot2, true)
		Kit.dim(lock, true)
	else
		-- Right-click / long tap isn't universal: one small button flips the lock and the auto slot.
		local flip = Kit.button("⇄", Theme.Color.PanelLight, Theme.Color.Panel, { LayoutOrder = 5, Size = UDim2.new(0.08, -8, 0.9, 0), Parent = buttons })
		flip.Activated:Connect(function()
			lockSlot = if lockSlot == 1 then 2 else 1
			autoSlot = if lockSlot == 1 then 2 else 1 -- AUTO rolls the slot LOCK & ROLL would roll
			drawDetail()
		end)
	end
end

function drawGrid()
	clear(grid)
	local list = {}
	for id, entry in State.Cards do
		local card = Cards.Get(id)
		if card then
			table.insert(list, { Card = card, Entry = entry })
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.Entry.Pending ~= nil, b.Entry.Pending ~= nil
		if pa ~= pb then
			return pa -- unchosen rolls first
		end
		-- Then the best border first (the tier), so the strongest copies sit on top.
		local ra, rb = Borders.Index(Borders.Best(a.Entry.Borders)), Borders.Index(Borders.Best(b.Entry.Borders))
		if ra ~= rb then
			return ra > rb
		end
		return a.Card.Id < b.Card.Id
	end)
	if selectedId == nil or State.Cards[selectedId] == nil then
		selectedId = if list[1] then list[1].Card.Id else nil
	end
	for i, item in list do
		local card, entry = item.Card, item.Entry
		local tile = CardTile.new(card.Id, {
			Owned = true,
			Stars = entry.Stars,
			Border = Borders.Best(entry.Borders),
			Selected = card.Id == selectedId,
		})
		tile.LayoutOrder = i
		tile.Parent = grid
		local trait = Traits.Get(entry.Trait)
		local tag = Kit.label({
			Text = if entry.Pending then "CHOOSE!" elseif trait then `{trait.Icon} {trait.Name}` else "no trait",
			Font = Theme.Font.Heavy,
			TextColor3 = if entry.Pending then Theme.Color.Gold elseif trait then Rarity.Get(trait.Tier).Color else Theme.Color.Muted,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(0.94, 0.16),
			ZIndex = 9,
			Parent = tile,
		}, 14)
		Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0).Parent = tag
		tile.Activated:Connect(function()
			if busy then
				return
			end
			selectedId = card.Id
			drawGrid()
		end)
	end
	drawDetail()
end

function TraitMaster.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "TraitMasterGui", "TRAIT MASTER", Vector2.new(0.88, 0.86), Vector2.new(1080, 680))
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = TEAL,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.5, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	grid = Kit.new("ScrollingFrame", {
		Name = "Cards",
		Size = UDim2.fromScale(0.42, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = TEAL,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 100),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})
	detail = Kit.new("Frame", {
		Name = "Detail",
		Position = UDim2.fromScale(0.44, 0),
		Size = UDim2.fromScale(0.56, 1),
		BackgroundColor3 = Color3.fromRGB(10, 22, 30),
		BackgroundTransparency = 0.25,
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(TEAL, 2, 0.4), Kit.padding(10) })
	modal.OnOpen = function()
		if not busy then
			drawGrid()
		end
	end
end

-- Opens the Trait Master, on `cardId` when given (the Index shortcut).
function TraitMaster.Open(cardId: string?)
	if State.InBattle then
		return
	end
	if cardId and State.Cards[cardId] then
		selectedId = cardId
	end
	if modal.IsOpen then
		drawGrid()
	else
		modal:Open()
	end
end

return TraitMaster
