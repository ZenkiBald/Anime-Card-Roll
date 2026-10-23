--!nonstrict
-- FUSION (talk to Hoshi the Fusion Master in town): Config.FusionCopies copies of one card fuse it one
-- rarity up, again and again up to Secret (Awakening node 5: +25 Trait Shards and +0.05x luck each). Left: your cards with their copy progress, ready ones
-- first. Right: the picked card now and after fusing, and the FUSE button. The server does the fusing
-- (FusionService); this screen asks and plays the fusion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Rarity = require(Shared.Rarity)
local Config = require(Shared.Config)
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

local Fusion = {}

local FIRE = Color3.fromRGB(255, 138, 61)
local FIRE_DEEP = Color3.fromRGB(190, 60, 20)

local REASONS = {
	NotEnough = "Not enough copies yet",
	MaxRarity = "Already Secret: it can't fuse further",
	NotOwned = "You don't own that card",
	TooFast = "One fusion at a time",
	Loading = "Still loading",
}

local modal
local grid: ScrollingFrame
local detail: Frame
local hintLabel: TextLabel
local selectedId: string? = nil
local busy = false -- true while a fusion is in flight or its animation is on screen
local fusionToken = 0 -- bumped by each fusion and by closing the panel, so a stale animation can't unlock a newer one
local fusionStage: Frame? = nil
local hintToken = 0

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

local function canFuse(card, entry): boolean
	return (entry.Fusion or 0) < Cards.MaxFusion(card) and entry.Copies >= Config.FusionCopies
end

-- Owned cards that can still fuse, ready ones first, then the closest to their next fusion.
local function cardsByProgress()
	local list = {}
	for id, entry in State.Cards do
		local card = Cards.Get(id)
		if card then
			table.insert(list, { Card = card, Entry = entry })
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = canFuse(a.Card, a.Entry), canFuse(b.Card, b.Entry)
		if ra ~= rb then
			return ra
		end
		if a.Entry.Copies ~= b.Entry.Copies then
			return a.Entry.Copies > b.Entry.Copies
		end
		return a.Card.Id < b.Card.Id
	end)
	return list
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function statLine(card, stars: number, fusion: number): string
	local main = Kit.commas(Cards.Stat(card, card.Main, stars, fusion))
	local text = if card.Type == "Attack" then `⚔️ {main}  ❤️ {Kit.commas(Cards.Stat(card, card.HP or 0, stars, fusion))}` else `✨ {main} PWR`
	return `{text}\n<b>{Kit.commas(Cards.Power(card, stars, fusion))}</b> power`
end

local drawGrid -- forward declaration

-- The big fusion moment: the old card shakes and shrinks into a flash, the fused card bursts out.
-- Ends the fusion on screen (if it's still the current one) and unlocks the FUSE button. Before this
-- existed, `busy` only cleared on "Tap to continue": an error in the animation, or closing the panel at
-- the wrong moment, left fusion locked for the rest of the session.
local function endFusion(token: number)
	if token ~= fusionToken then
		return
	end
	if fusionStage then
		fusionStage:Destroy()
		fusionStage = nil
	end
	busy = false
	if modal.IsOpen then
		drawGrid()
	end
end

local function playFusion(cardId: string, before, after, token: number)
	local card = Cards.Get(cardId)
	local rarity = Cards.FusedRarity(card, after.Fusion)
	local tier = Rarity.Get(rarity)
	local stage = Kit.new("Frame", {
		Name = "FusionStage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 6, 22),
		BackgroundTransparency = 0.15,
		ZIndex = 40,
		Active = true,
		ClipsDescendants = true, -- keeps the light rays inside the box
		Parent = detail,
	}, { Kit.corner(UDim.new(0, 18)) })
	fusionStage = stage
	local old = CardView.new(cardId, { Owned = true, Stars = before.Stars, Fusion = before.Fusion, Compact = true })
	old.AnchorPoint = Vector2.new(0.5, 0.5)
	old.Position = UDim2.fromScale(0.5, 0.45)
	old.Size = UDim2.fromScale(0.5, 0.55)
	old.ZIndex = 41
	old.Parent = stage
	local oldScale = Kit.new("UIScale", { Scale = 1, Parent = old })
	Sfx.Play("Riser")
	Effects.Shake(old, 6, 0.9)
	Effects.Sparks(stage, FIRE, 24, 1)
	task.wait(0.9)
	Kit.tween(oldScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.25)
	old:Destroy()
	Effects.Flash(stage, tier.Color, 0.6, 0)
	Sfx.Sting(rarity)
	local rays = Effects.Rays(stage, tier.Color, if Theme.FxLow then 6 else 12)
	rays.ZIndex = 41
	local fused = CardView.new(cardId, { Owned = true, Stars = after.Stars, Fusion = after.Fusion, Animate = true })
	fused.AnchorPoint = Vector2.new(0.5, 0.5)
	fused.Position = UDim2.fromScale(0.5, 0.44)
	fused.Size = UDim2.fromScale(0.62, 0.68)
	fused.ZIndex = 42
	fused.Parent = stage
	local fusedScale = Kit.new("UIScale", { Scale = 0.3, Parent = fused })
	Kit.tween(fusedScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Effects.Sparks(stage, tier.Color, 36, 1.2)
	if Rarity.AtLeast(rarity, "Legendary") then
		Effects.Shimmer(fused, 2)
	end
	local title = Kit.label({
		Text = `FUSED! {string.upper(rarity)}`,
		Font = Theme.Font.Display,
		TextColor3 = tier.Color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.9, 0.09),
		ZIndex = 43,
		Parent = stage,
	}, 40)
	Kit.textStroke(Color3.fromRGB(20, 8, 40), 3, 0).Parent = title
	local tap = Kit.label({
		Text = "Tap to continue",
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.6, 0.05),
		ZIndex = 43,
		Parent = stage,
	}, 18)
	task.wait(0.8)
	local closer = Kit.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 44,
		Parent = stage,
	})
	closer.Activated:Connect(function()
		endFusion(token)
	end)
	tap.TextTransparency = 0
end

local function fuse(cardId: string)
	if busy then
		return
	end
	busy = true
	local before = table.clone(State.Cards[cardId])
	local ok, result = pcall(function()
		return Remotes.Fuse:InvokeServer(cardId)
	end)
	if not ok or result == nil or not result.Ok then
		busy = false
		hint(if ok and result then REASONS[result.Reason] or "Fusion failed" else "Fusion failed, try again")
		return
	end
	State.ApplyCard(cardId, result.Card)
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	-- Awakening node 5: Trait Shards now, and permanent base luck.
	local granted = result.Granted and result.Granted.TraitShards or Awaken.FusionTraitShards
	hint(`✴️ AWAKENING 5: +🧬{granted} Trait Shards · +{Awaken.FusionLuck}x permanent luck`)
	fusionToken += 1
	local token = fusionToken
	local played, err = pcall(playFusion, cardId, before, result.Card, token)
	if not played then
		warn(`[Fusion] animation failed: {err}`)
		endFusion(token)
	end
end

local function drawDetail()
	clear(detail)
	local entry = selectedId and State.Cards[selectedId]
	local card = selectedId and Cards.Get(selectedId)
	if entry == nil or card == nil then
		Kit.label({
			Text = "Pick a card on the left.\n100 copies of the same card fuse it into the next rarity, with that rarity's power.",
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.3),
			Parent = detail,
		}, 22)
		return
	end
	local fusion = entry.Fusion or 0
	local maxed = fusion >= Cards.MaxFusion(card)

	-- Now -> after fusing, side by side.
	local cardsRow = Kit.new("Frame", {
		Position = UDim2.fromScale(0, 0.02),
		Size = UDim2.fromScale(1, 0.54),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	local function placeCard(view: Frame, x: number)
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(x, 0.5)
		view.Size = UDim2.fromScale(0.4, 0.98)
		view.Parent = cardsRow
	end
	placeCard(CardView.new(card.Id, { Owned = true, Stars = entry.Stars, Fusion = fusion, Compact = true, Border = Borders.Best(entry.Borders) }), if maxed then 0.5 else 0.25)
	if not maxed then
		local arrow = Kit.label({
			Text = "▶",
			Font = Theme.Font.Heavy,
			TextColor3 = FIRE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.12, 0.22),
			Parent = cardsRow,
		}, 56)
		Kit.textStroke(FIRE_DEEP, 2, 0).Parent = arrow
		placeCard(CardView.new(card.Id, { Owned = true, Stars = entry.Stars, Fusion = fusion + 1, Compact = true, Border = Borders.Best(entry.Borders) }), 0.75)
	end

	-- Stats now and after.
	local statsRow = Kit.new("Frame", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.16),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	local function statTile(x: number, width: number, rarity: string, text: string)
		local tile = Kit.tile({ Position = UDim2.fromScale(x, 0), Size = UDim2.fromScale(width, 1), Parent = statsRow }, Rarity.Get(rarity).Color)
		Kit.label({
			Text = string.upper(rarity),
			Font = Theme.Font.Display,
			TextColor3 = Rarity.Get(rarity).Color,
			Position = UDim2.new(0, 0, 0, 4),
			Size = UDim2.new(1, 0, 0.3, 0),
			Parent = tile,
		}, 18)
		Kit.label({
			Text = text,
			RichText = true,
			Font = Theme.Font.Heavy,
			Position = UDim2.new(0.05, 0, 0.34, 0),
			Size = UDim2.new(0.9, 0, 0.6, 0),
			Parent = tile,
		}, 17)
	end
	if maxed then
		statTile(0.25, 0.5, Cards.FusedRarity(card, fusion), statLine(card, entry.Stars, fusion))
	else
		statTile(0.02, 0.44, Cards.FusedRarity(card, fusion), statLine(card, entry.Stars, fusion))
		statTile(0.54, 0.44, Cards.FusedRarity(card, fusion + 1), statLine(card, entry.Stars, fusion + 1))
	end

	-- Copies bar.
	local copies = math.min(entry.Copies, Config.FusionCopies)
	local track = Kit.new("Frame", {
		Position = UDim2.fromScale(0.04, 0.77),
		Size = UDim2.fromScale(0.92, 0.055),
		BackgroundColor3 = Color3.fromRGB(14, 8, 30),
		Parent = detail,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.Color.TileEdge, 1.5, 0.5) })
	Kit.new("Frame", {
		Size = UDim2.fromScale(if maxed then 1 else copies / Config.FusionCopies, 1),
		BackgroundColor3 = FIRE,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)), Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 200, 90), FIRE), 0) })
	local barText = Kit.label({
		Text = if maxed then "MAX RARITY" else `{Kit.commas(entry.Copies)} / {Config.FusionCopies} copies`,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		ZIndex = 2,
		Parent = track,
	}, 20)
	Kit.textStroke(Color3.fromRGB(20, 8, 40), 2, 0).Parent = barText

	-- FUSE.
	local ready = canFuse(card, entry)
	local button = Kit.button(
		if maxed then "MAX RARITY" elseif ready then "🔥 FUSE!" else `NEED {Config.FusionCopies - entry.Copies} MORE`,
		FIRE,
		FIRE_DEEP,
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.fromScale(0.6, 0.11),
			Parent = detail,
		}
	)
	Kit.dim(button, not ready)
	if ready then
		local pulse = Kit.new("UIScale", { Scale = 1, Parent = button.Label })
		TweenService:Create(pulse, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
	end
	button.Activated:Connect(function()
		if ready then
			fuse(card.Id)
		else
			hint(if maxed then REASONS.MaxRarity else "Roll more copies of this card")
		end
	end)
end

function drawGrid()
	clear(grid)
	local list = cardsByProgress()
	if selectedId == nil or State.Cards[selectedId] == nil then
		selectedId = if list[1] then list[1].Card.Id else nil
	end
	for i, item in list do
		local card, entry = item.Card, item.Entry
		local cell = Kit.new("Frame", { LayoutOrder = i, BackgroundTransparency = 1, Parent = grid })
		local tile = CardTile.new(card.Id, {
			Owned = true,
			Stars = entry.Stars,
			Fusion = entry.Fusion,
			Border = Borders.Best(entry.Borders),
			Selected = card.Id == selectedId,
		})
		tile.Size = UDim2.new(1, 0, 1, -22)
		tile.Parent = cell
		local maxed = (entry.Fusion or 0) >= Cards.MaxFusion(card)
		local track = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundColor3 = Color3.fromRGB(14, 8, 30),
			Parent = cell,
		}, { Kit.corner(UDim.new(1, 0)) })
		Kit.new("Frame", {
			Size = UDim2.fromScale(if maxed then 1 else math.min(entry.Copies / Config.FusionCopies, 1), 1),
			BackgroundColor3 = if canFuse(card, entry) then Theme.Color.Gold else FIRE,
			Parent = track,
		}, { Kit.corner(UDim.new(1, 0)) })
		local text = Kit.label({
			Text = if maxed then "MAX" elseif canFuse(card, entry) then "READY!" else `{entry.Copies}/{Config.FusionCopies}`,
			Font = Theme.Font.Heavy,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = track,
		}, 14)
		Kit.textStroke(Color3.fromRGB(20, 8, 40), 1.5, 0).Parent = text
		tile.Activated:Connect(function()
			selectedId = card.Id
			drawGrid()
		end)
	end
	drawDetail()
end

function Fusion.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "FusionGui", "FUSION", Vector2.new(0.88, 0.86), Vector2.new(1040, 680))
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = FIRE,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.45, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	grid = Kit.new("ScrollingFrame", {
		Name = "Cards",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = FIRE,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 126),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})
	detail = Kit.new("Frame", {
		Name = "Detail",
		Position = UDim2.fromScale(0.52, 0),
		Size = UDim2.fromScale(0.48, 1),
		BackgroundColor3 = Color3.fromRGB(16, 9, 38),
		BackgroundTransparency = 0.25,
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(FIRE, 2, 0.4), Kit.padding(10) })
	modal.OnOpen = function()
		if not busy then
			drawGrid()
		end
	end
	-- Closing mid-animation ends it: the card is already fused on the server.
	modal.OnClose = function()
		if busy and fusionStage then
			endFusion(fusionToken)
		end
	end
end

function Fusion.Open()
	if State.InBattle then
		return
	end
	modal:Open()
end

-- How many owned cards are ready to fuse (for hints).
function Fusion.ReadyCount(): number
	local n = 0
	for id, entry in State.Cards do
		local card = Cards.Get(id)
		if card and canFuse(card, entry) then
			n += 1
		end
	end
	return n
end

return Fusion
