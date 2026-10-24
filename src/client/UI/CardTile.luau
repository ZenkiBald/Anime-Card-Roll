--!nonstrict
-- Square card tile for the deck and Index grids: full art framed only by its border (the tier: Base /
-- Gold / Rainbow / Secret) and an element glow, a small star count, copies and a big power number. No
-- rarity badges: the frame says the tier. Size it from outside (grid cell or slot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Borders = require(Shared.Borders)
local Elements = require(Shared.Elements)
local Cards = require(Shared.Cards)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local BorderFx = require(script.Parent.BorderFx)
local ElementUi = require(script.Parent.ElementUi)

local CardTile = {}

export type Options = {
	Owned: boolean?,
	Stars: number?,
	Copies: number?,
	Power: number?, -- shown big along the bottom
	InDeck: boolean?,
	Selected: boolean?,
	Spin: boolean?, -- spin a Secret card's prismatic border (only for a few tiles at once)
	Border: string?, -- the card's best border (Borders.luau): the tier and its frame
}

local function outlined(label: TextLabel, thickness: number?)
	Kit.textStroke(Color3.fromRGB(6, 7, 11), thickness or 2, 0).Parent = label
	return label
end

function CardTile.new(cardId: string, opts: Options?): TextButton
	local options = opts or {}
	local card = Cards.Get(cardId)
	assert(card, `Unknown card {cardId}`)
	local borderId = if options.Owned ~= false then options.Border or "Normal" else "Normal"
	local tier = Borders.Get(borderId)
	local element = Elements.Get(card.Element)
	local glow = if element then element.Color else Theme.Color.Neon
	local owned = options.Owned ~= false

	local button = Kit.new("TextButton", {
		Name = cardId,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Text = "",
	}, {
		Kit.corner(UDim.new(0.12, 0)),
		Kit.gradient(
			ColorSequence.new(
				if owned then card.Accent:Lerp(Color3.new(0, 0, 0), 0.25) else Color3.fromRGB(26, 30, 42),
				if owned then glow:Lerp(Color3.new(0, 0, 0), 0.82) else Color3.fromRGB(11, 13, 20)
			),
			120
		),
	})
	-- The frame: the border's colours (a plain element-tinted edge on Base); BorderFx draws the full
	-- Gold / Rainbow / Secret frame on top.
	local stroke = Kit.stroke(Color3.new(1, 1, 1), if borderId == "Normal" then 1.2 else 2.5, 0)
	local strokeGradient = Kit.gradient(if borderId == "Normal" then ColorSequence.new(glow:Lerp(Theme.Color.Line, 0.45)) else tier.Gradient, 45)
	strokeGradient.Parent = stroke
	stroke.Parent = button
	if borderId == "Secret" and options.Spin then
		Effects.Spin(strokeGradient, 100)
	end
	-- Element glow rising from the bottom edge.
	Kit.new("Frame", {
		Name = "ElementGlow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.55),
		BackgroundColor3 = glow,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = button,
	}, {
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, if owned then 0.6 else 0.9) }),
		}),
	})

	-- Light rays behind the character.
	local rays = Kit.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.3, 1.3),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = button,
	}, { Kit.aspect(1, Enum.DominantAxis.Width) })
	for i = 1, 6 do
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.08, 0.72),
			Rotation = (i - 1) * 30,
			BackgroundColor3 = if borderId == "Normal" then glow else tier.Color,
			BackgroundTransparency = if owned then 0.86 else 0.96,
			BorderSizePixel = 0,
			Parent = rays,
		})
	end

	-- The character (3D figure now, uploaded illustration later).
	local art = CardView.Art(cardId, owned, false)
	if art then
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromScale(1, 1)
		art.Parent = button
	else
		-- No illustration yet: the element-lit bust (with its own "?" when not found).
		local bust = CardView.Portrait(cardId, owned, false)
		bust.AnchorPoint = Vector2.new(0.5, 0.5)
		bust.Position = UDim2.fromScale(0.5, 0.44)
		bust.Size = UDim2.fromScale(0.74, 0.62)
		bust.Parent = button
	end
	if not owned and art then
		outlined(Kit.label({
			Text = "?",
			Font = Theme.Font.Display,
			TextColor3 = Color3.fromRGB(194, 204, 225),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.5, 0.36),
			ZIndex = 4,
			Parent = button,
		}, 60), 3)
	end

	-- Dark fade along the bottom so the number reads on any art.
	Kit.new("Frame", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.42),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = button,
	}, {
		Kit.corner(UDim.new(0.25, 0)),
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
		}),
	})

	-- The card's border frame over the art (uploaded frame art per border when Skin.KitArt is on).
	Skin.Frame(button, borderId, 4)
	if owned then
		BorderFx.Apply(button, options.Border, { Corner = UDim.new(0.12, 0), ZIndex = 5, Spin = options.Spin })
	end

	local bottomText = if owned then (if options.Power then Kit.commas(options.Power) else card.Name) else "???"
	outlined(Kit.label({
		Name = "Power",
		Text = bottomText,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromScale(0.94, 0.17),
		ZIndex = 5,
		Parent = button,
	}, 22), 2)

	-- Stars (top-left): the only badge; the border says the tier.
	if owned and (options.Stars or 0) > 0 then
		local pill = Kit.new("Frame", {
			Name = "Stars",
			Position = UDim2.fromScale(0.05, 0.06),
			Size = UDim2.fromScale(0.3, 0.17),
			BackgroundColor3 = Color3.fromRGB(8, 10, 15),
			BackgroundTransparency = 0.25,
			ZIndex = 5,
			Parent = button,
		}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Theme.Color.Gold, 1.5, 0.3) })
		outlined(Kit.label({
			Text = `★{options.Stars}`,
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.8),
			ZIndex = 6,
			Parent = pill,
		}, 18), 1.5)
	end

	-- Element badge (top-right): shown even before the card is found, for planning.
	ElementUi.Badge(card.Element, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.95, 0.05),
		Size = UDim2.fromScale(0.2, 0.2),
		Parent = button,
	})

	if owned and options.Copies then
		outlined(Kit.label({
			Name = "Copies",
			Text = `x{options.Copies}`,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.95, 0.27),
			Size = UDim2.fromScale(0.34, 0.16),
			ZIndex = 5,
			Parent = button,
		}, 20), 2)
	end

	if options.InDeck then
		local check = Kit.new("Frame", {
			Name = "InDeck",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 0.8, 0),
			Size = UDim2.fromScale(0.22, 0.22),
			BackgroundColor3 = Theme.Color.Quick,
			ZIndex = 6,
			Parent = button,
		}, {
			Kit.corner(UDim.new(1, 0)),
			Kit.aspect(1, Enum.DominantAxis.Width),
			Kit.stroke(Color3.new(1, 1, 1), 2, 0),
		})
		outlined(Kit.label({
			Text = "✓",
			Font = Theme.Font.Heavy,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.75, 0.75),
			ZIndex = 7,
			Parent = check,
		}, 22), 1.5)
	end

	if options.Selected then
		local ring = Kit.new("Frame", {
			Name = "Selected",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.Gold,
			BackgroundTransparency = 0.85,
			ZIndex = 8,
			Parent = button,
		}, { Kit.corner(UDim.new(0.12, 0)) })
		Kit.stroke(Theme.Color.Gold, 4, 0).Parent = ring
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
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.75),
		BackgroundTransparency = 0.2,
		Text = "",
	}, { Kit.corner(UDim.new(0.12, 0)) })
	Kit.stroke(if selected then Theme.Color.Gold else color, if selected then 4 else 2, if selected then 0 else 0.5).Parent = button
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
