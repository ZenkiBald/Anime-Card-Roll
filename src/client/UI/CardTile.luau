--!nonstrict
-- Square card tile for the deck, Vault and Index grids, in the Dark Feudal look: an Urushi lacquer chassis
-- framed by its border tier (UITheme.BorderTiers: bronze 1 px, gold leaf 2 px, prismatic 2.5 px, void
-- 3 px; the border IS the tier), the art in the middle, and along the bottom the name and copies, then the
-- card's rarity number at its border (Cards.Rarity, a round number like 7,500,000) in the tier's colour.
-- No combat stats on the tile: they live in the inspector / skill sheet. A plain Attack / Support label
-- says which row it belongs in; the element sits top-right. Duplicates are for fusion; battle mastery is explained in the details.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Borders = require(Shared.Borders)
local Elements = require(Shared.Elements)
local Cards = require(Shared.Cards)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local BorderFx = require(script.Parent.BorderFx)
local ElementUi = require(script.Parent.ElementUi)

local CardTile = {}


local C = UITheme.Colors

export type Options = {
	Owned: boolean?,
	Stars: number?,
	Copies: number?,
	Power: number?, -- unused on the tile now (the rarity number is the big number); kept for callers
	InDeck: boolean?,
	Selected: boolean?,
	Spin: boolean?, -- spin a Secret card's border (only for a few tiles at once)
	Border: string?, -- the card's best border (Borders.luau): the tier and its frame
	Stats: boolean?, -- ignored: stats moved to the inspector / tooltip (kept so callers don't break)
	Awaken: number?, -- retained for callers; progression is shown in the detail sheet
	Fusable: boolean?, -- 100+ copies at this border and a border above it: a pulsing FUSE! seal
}

local function outlined(label: TextLabel, thickness: number?)
	Kit.textStroke(Color3.fromRGB(6, 7, 11), thickness or 2, 0).Parent = label
	return label
end

function CardTile.new(cardId: string, opts: Options?): TextButton
	local options = opts or {}
	local card = Cards.Get(cardId)
	assert(card, `Unknown card {cardId}`)
	local owned = options.Owned ~= false
	local borderId = if owned then options.Border or "Normal" else "Normal"
	local tier = Borders.Get(borderId)
	local frame = UITheme.BorderTiers[borderId] or UITheme.BorderTiers.Normal
	local element = Elements.Get(card.Element)
	local glow = if element then element.Color else C.TamahaganeEdge

	-- The chassis: Urushi lacquer, a breath of the element at the bottom.
	local button = Kit.new("TextButton", {
		Name = cardId,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Text = "",
	}, {
		Kit.corner(UDim.new(0, 6)),
		Kit.gradient(ColorSequence.new(C.UrushiRaised, if owned then C.UrushiBase:Lerp(glow, 0.12) else C.UrushiInset), 90),
	})
	-- The tier frame (bezel on the border): its colour and thickness; Rainbow prismatic, Secret void.
	local stroke = Kit.stroke(Color3.new(1, 1, 1), frame.Thickness, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local strokeGradient = Kit.gradient(
		if frame.Prismatic then tier.Gradient
			elseif frame.Core then ColorSequence.new({
				ColorSequenceKeypoint.new(0, frame.Color),
				ColorSequenceKeypoint.new(0.5, frame.Core),
				ColorSequenceKeypoint.new(1, frame.Color),
			})
			else ColorSequence.new(frame.Color),
		45
	)
	strokeGradient.Parent = stroke
	stroke.Parent = button
	if borderId == "Secret" and options.Spin then
		Effects.Spin(strokeGradient, 100)
	end
	-- An inner steel bezel just inside the tier frame.
	Kit.new("Frame", {
		Name = "Bezel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * frame.Thickness - 2, 1, -2 * frame.Thickness - 2),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = button,
	}, { Kit.corner(UDim.new(0, 5)), Kit.stroke(C.TamahaganeSlate, 1, 0.2) })
	-- Element aura rising behind the art.
	Kit.new("Frame", {
		Name = "ElementGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = if frame.Glow then frame.Color:Lerp(glow, 0.5) else glow,
		BackgroundTransparency = if owned then (if frame.Glow then 0.72 else 0.82) else 0.94,
		ZIndex = 1,
		Parent = button,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Width) })

	-- The art well (an uploaded illustration, else the element-lit bust).
	local art = CardView.Art(cardId, owned, false)
	if art then
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromScale(1, 1)
		art.Parent = button
	else
		local bust = CardView.Portrait(cardId, owned, false)
		bust.AnchorPoint = Vector2.new(0.5, 0.5)
		bust.Position = UDim2.fromScale(0.5, 0.36)
		bust.Size = UDim2.fromScale(0.66, 0.52)
		bust.Parent = button
	end
	if not owned and art then
		outlined(Kit.label({
			Text = "?",
			Font = Theme.Font.Display,
			TextColor3 = C.WashiGhost,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromScale(0.5, 0.36),
			ZIndex = 4,
			Parent = button,
		}, 60), 3)
	end

	-- Lacquer fade under the text so it reads on any art.
	Kit.new("Frame", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = C.UrushiInset,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = button,
	}, {
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(1, 0.05) }),
		}),
	})

	-- Uploaded frame art per border (Skin.KitArt), and the border's own frame effect on Gold and up.
	Skin.Frame(button, borderId, 4)
	if owned and borderId ~= "Normal" then
		BorderFx.Apply(button, options.Border, { Corner = UDim.new(0, 6), ZIndex = 5, Spin = options.Spin, Thickness = frame.Thickness })
	end

	-- Bottom: reserve enough height for long epithets to wrap, then the rarity number.
	local nameLabel = outlined(Kit.label({
		Name = "CardName",
		Text = if owned then string.upper(card.Name) else "???",
		Font = Theme.Font.Display,
		TextColor3 = if owned then C.WashiParchment else C.WashiGhost,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.fromScale(0.06, 0.54),
		Size = UDim2.fromScale(0.88, 0.31),
		ZIndex = 5,
		Parent = button,
	}, 14), 1.5)
	nameLabel:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 8
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = nameLabel })
	-- Copies at this border: top-left, under the stars.
	if owned and options.Copies then
		outlined(Kit.label({
			Name = "Copies",
			Text = `x{Kit.short(options.Copies)}`,
			Font = Theme.Font.Heavy,
			TextColor3 = if options.Fusable then C.SurgeGold else C.WashiGhost,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.07, 0.15),
			Size = UDim2.fromScale(0.42, 0.11),
			ZIndex = 6,
			Parent = button,
		}, 14), 1.2)
	end
	-- FUSE!: a vermilion wax seal over the art, pulsing, when this border has the copies to fuse (at Hoshi).
	if owned then
		local seal = Kit.new("Frame", {
			Name = "Fuse",
			Visible = options.Fusable == true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(0.56, 0.15),
			BackgroundColor3 = C.VermilionWax,
			ZIndex = 7,
			Parent = button,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		local rim = Kit.stroke(C.SurgeGold, 2, 0)
		rim.Parent = seal
		outlined(Kit.label({
			Text = "FUSE!",
			Font = Theme.Font.Display,
			TextColor3 = C.WashiParchment,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
			Parent = seal,
		}, 16), 1.2)

	end
	local rarity = if owned then Cards.Rarity(cardId, borderId) else 0
	outlined(Kit.label({
		Name = "Rarity",
		Text = if rarity > 0 then Kit.commas(rarity) else "",
		Font = Theme.Font.Display,
		TextColor3 = if borderId == "Normal" then C.WashiParchment else tier.Color:Lerp(Color3.new(1, 1, 1), 0.2),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromScale(0.92, 0.15),
		ZIndex = 5,
		Parent = button,
	}, 18), 2)

	-- Say which row it belongs in; the border already communicates the tier.
	Kit.label({
		Name = "CardType", Text = string.upper(card.Type), Font = Theme.Font.Bold,
		TextColor3 = if card.Type == "Support" then Color3.fromRGB(139, 221, 177) else Color3.fromRGB(255, 160, 140),
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.06, 0.03),
		Size = UDim2.fromScale(0.65, 0.12), ZIndex = 6, Parent = button,
	}, 11)

	-- Element and role (top-right): diamond IconBadges, shown before the card is found too (for planning).
	ElementUi.Badge(card.Element, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.03),
		Size = UDim2.fromScale(0.22, 0.22),
		ZIndex = 6,
		Parent = button,
	})

	-- In the deck: a small vermilion seal under the stars.
	if owned then
		local seal = Kit.new("Frame", {
			Name = "InDeck",
			Visible = options.InDeck == true,
			Position = UDim2.fromScale(0.06, 0.28),
			Size = UDim2.fromScale(0.18, 0.18),
			BackgroundColor3 = C.VermilionWax,
			ZIndex = 6,
			Parent = button,
		}, {
			Kit.corner(UDim.new(1, 0)),
			Kit.aspect(1, Enum.DominantAxis.Width),
			Kit.stroke(C.VermilionHover, 1.5, 0),
		})
		outlined(Kit.label({
			Text = "✓",
			Font = Theme.Font.Heavy,
			TextColor3 = C.WashiParchment,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.75, 0.75),
			ZIndex = 7,
			Parent = seal,
		}, 18), 1)
	end

	if owned then
		local ring = Kit.new("Frame", {
			Name = "Selected",
			Visible = options.Selected == true,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.WashiParchment,
			BackgroundTransparency = 0.9,
			ZIndex = 8,
			Parent = button,
		}, { Kit.corner(UDim.new(0, 6)) })
		Kit.stroke(Theme.Color.Neon, 3, 0).Parent = ring
	end

	Kit.pressable(button)
	return button
end

-- An empty deck slot: soft panel with a plus and the row's icon.
function CardTile.Empty(row: string, selected: boolean?): TextButton
	local color = if row == "Attack" then Theme.Color.Attack else Theme.Color.Quick
	local button = Kit.new("TextButton", {
		Name = "Empty",
		AutoButtonColor = false,
		BackgroundColor3 = C.UrushiInset,
		BackgroundTransparency = 0.1,
		Text = "",
	}, { Kit.corner(UDim.new(0, 6)) })
	Kit.stroke(if selected then Theme.Color.Neon else C.TamahaganeSlate, if selected then 3 else 1.5, 0).Parent = button
	outlined(Kit.label({
		Text = "+",
		Font = Theme.Font.Display,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.5, 0.45),
		Parent = button,
	}, 60), 2)
	Kit.label({
		Text = if selected then "PICK A CARD" else "EMPTY",
		Font = Theme.Font.Heavy,
		TextColor3 = if selected then Theme.Color.Gold else Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromScale(0.9, 0.16),
		Parent = button,
	}, 14)
	Kit.pressable(button)
	return button
end

return CardTile
