--!nonstrict
-- Draws a card, full-art: the character's 2D illustration (Card.Image) fills the card, framed only by its
-- border (the tier: Base / Gold / Rainbow / Secret) and an element glow, with stars, the big name, the
-- headline ability, tags and DMG / HP on top of it. No rarity badges: the frame says the tier, and the
-- rarity number chip (Cards.Rarity: how many pulls it takes, e.g. "48,579") says how rare it is.
-- Cards without an illustration yet show an element-lit bust (CardView.Portrait, used by every card
-- slot); cards not found yet show a dark silhouette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity) -- trait tier colours only
local Cards = require(Shared.Cards)

local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local Elements = require(Shared.Elements)
local Foils = require(Shared.Foils)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local BorderFx = require(script.Parent.BorderFx)
local ElementUi = require(script.Parent.ElementUi)

local CardView = {}

export type Options = {
	Owned: boolean?,
	Stars: number?,
	Compact: boolean?, -- small grid tile: hides title and stats
	Animate: boolean?, -- the figure sways (big reveals and detail views only)
	Border: string?, -- Borders.luau id: the tier (frame and stat multiplier)
	Trait: string?, -- Traits.luau id: shown as the first tag chip, in its tier colour
	Foil: string?, -- Foils.luau id: shown as a tag chip when it isn't Standard
}

local SILHOUETTE = Color3.fromRGB(46, 44, 62)

local function starText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end

-- The character's 2D illustration (Card.Image) as an ImageLabel; nil until the card has one (callers
-- show the card's glyph instead). `animate` is kept for callers; images don't sway.
function CardView.Art(cardId: string, owned: boolean, _animate: boolean?): GuiObject?
	local card = Cards.Get(cardId)
	if card == nil or card.Image == nil then
		return nil
	end
	return Kit.new("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = card.Image,
		ScaleType = Enum.ScaleType.Crop,
		ImageColor3 = if owned then Color3.new(1, 1, 1) else SILHOUETTE,
		ZIndex = 2,
	})
end

-- Element glow behind portraits: amber Flame, ice Frost, gold Storm, warm Light, violet Void, teal Cosmic.
local GLOW = {
	Flame = Color3.fromRGB(255, 130, 40),
	Frost = Color3.fromRGB(80, 190, 255),
	Storm = Color3.fromRGB(255, 205, 60),
	Light = Color3.fromRGB(255, 232, 150),
	Void = Color3.fromRGB(150, 70, 255),
	Cosmic = Color3.fromRGB(40, 230, 210),
}

function CardView.Glow(cardId: string): Color3
	local card = Cards.Get(cardId)
	return card and GLOW[card.Element] or Color3.fromRGB(150, 150, 170)
end

-- Until a card has its illustration: a procedural portrait that is different for every card. Three
-- layers, back to front, all plain Frames (cheap on phones, about 20 per portrait):
--   1. the element's background pattern (flame tongues, a snowflake, a lightning zig-zag, sun rays, void
--      rings, an eclipse with a four-point star),
--   2. a layered diamond emblem behind the head (element colour, the card's Accent inside) and the role's
--      weapon silhouette (Striker blade, Hexer staff and orb, Mender lotus cross, Warder shield),
--   3. a rim-lit bust whose hair crest (spikes, topknot, long hair, hood) and pattern angle come from a hash
--      of the card id, so two cards with the same element and role still look apart.
-- Not found yet: the same shapes in flat grey, so the role still reads.
local function hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

local function bar(parent: Instance, name: string, x: number, y: number, w: number, h: number, rotation: number, color: Color3, transparency: number, z: number, round: UDim?): Frame
	return Kit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rotation,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, if round then { Kit.corner(round) } else nil)
end

local function ring(parent: Instance, name: string, x: number, y: number, size: number, color: Color3, thickness: number, transparency: number, z: number): Frame
	return Kit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Width), Kit.stroke(color, thickness, transparency) })
end

-- Layer 1: the element's pattern.
local PATTERNS = {
	Flame = function(holder, color, spin)
		for k, x in { 0.24, 0.5, 0.76 } do
			bar(holder, "Tongue", x, 0.62 - (if k == 2 then 0.12 else 0), 0.16, if k == 2 then 0.62 else 0.46, 45 + spin * 0.2, color, 0.62, 1, UDim.new(0.2, 0))
		end
	end,
	Frost = function(holder, color, spin)
		for k = 0, 2 do
			bar(holder, "Arm", 0.5, 0.44, 0.05, 0.92, k * 60 + spin, color, 0.6, 1)
		end
		for k = 0, 5 do
			local a = math.rad(k * 60 + spin)
			bar(holder, "Tip", 0.5 + 0.36 * math.sin(a), 0.44 - 0.36 * math.cos(a), 0.09, 0.07, 45, color, 0.45, 1)
		end
	end,
	Storm = function(holder, color, spin)
		local tilt = spin * 0.15
		bar(holder, "Bolt", 0.62, 0.2, 0.07, 0.42, 28 + tilt, color, 0.45, 1)
		bar(holder, "Bolt", 0.46, 0.46, 0.07, 0.36, -52 + tilt, color, 0.45, 1)
		bar(holder, "Bolt", 0.36, 0.74, 0.07, 0.42, 28 + tilt, color, 0.45, 1)
	end,
	Light = function(holder, color, spin)
		for k = 0, 7 do
			bar(holder, "Ray", 0.5, 0.44, 0.04, 1.3, k * 22.5 + spin, color, 0.72, 1)
		end
		ring(holder, "Sun", 0.5, 0.44, 0.62, color, 2, 0.45, 1)
	end,
	Void = function(holder, color, _spin)
		ring(holder, "Ring", 0.5, 0.44, 0.95, color, 2, 0.55, 1)
		ring(holder, "Ring", 0.5, 0.44, 0.7, color, 2, 0.4, 1)
		ring(holder, "Ring", 0.5, 0.44, 0.45, color, 1.5, 0.25, 1)
	end,
	Cosmic = function(holder, color, spin)
		ring(holder, "Eclipse", 0.5, 0.44, 0.86, color, 3, 0.3, 1)
		bar(holder, "Star", 0.5, 0.44, 0.06, 1.1, spin, color, 0.5, 1)
		bar(holder, "Star", 0.5, 0.44, 0.06, 1.1, spin + 90, color, 0.5, 1)
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45 + spin)
			bar(holder, "Mote", 0.5 + 0.4 * math.sin(a), 0.44 - 0.4 * math.cos(a), 0.06, 0.06, 45, color, 0.2, 1, UDim.new(1, 0))
		end
	end,
}

-- Layer 2b: the role's weapon (or tool), drawn behind the bust so its silhouette frames the figure.
local WEAPONS = {
	Striker = function(holder, color, metal)
		bar(holder, "Blade", 0.68, 0.46, 0.07, 0.86, 32, metal, 0.05, 2, UDim.new(0.5, 0))
		bar(holder, "Guard", 0.56, 0.69, 0.24, 0.05, 32, color, 0.05, 2)
		bar(holder, "Grip", 0.51, 0.78, 0.07, 0.18, 32, color:Lerp(Color3.new(0, 0, 0), 0.4), 0.05, 2)
	end,
	Hexer = function(holder, color, metal)
		bar(holder, "Staff", 0.2, 0.55, 0.05, 0.9, -8, metal, 0.1, 2)
		local orb = bar(holder, "Orb", 0.24, 0.13, 0.2, 0.2, 0, color, 0.05, 2, UDim.new(1, 0))
		Kit.aspect(1, Enum.DominantAxis.Width).Parent = orb
		ring(holder, "Halo", 0.24, 0.13, 0.32, color, 1.5, 0.3, 2)
	end,
	Mender = function(holder, color, _metal)
		bar(holder, "Cross", 0.8, 0.26, 0.08, 0.3, 0, color, 0.05, 2, UDim.new(0.5, 0))
		bar(holder, "Cross", 0.8, 0.26, 0.24, 0.1, 0, color, 0.05, 2, UDim.new(0.5, 0))
		for k = 0, 3 do
			bar(holder, "Petal", 0.8, 0.26, 0.09, 0.26, k * 45 + 22, color, 0.55, 2, UDim.new(1, 0))
		end
	end,
	Warder = function(holder, color, metal)
		local shield = bar(holder, "Shield", 0.5, 0.86, 0.58, 0.4, 0, metal:Lerp(color, 0.35), 0.1, 4, UDim.new(0.3, 0))
		Kit.stroke(color, 2, 0.1).Parent = shield
		bar(holder, "Boss", 0.5, 0.84, 0.12, 0.12, 45, color, 0, 4)
	end,
}

-- Layer 3: the hair crest on the head, by hash.
local CRESTS = {
	function(holder, color) -- spikes
		for k, x in { 0.4, 0.5, 0.6 } do
			bar(holder, "Spike", x, 0.25 - (if k == 2 then 0.03 else 0), 0.08, 0.14, (k - 2) * 25, color, 0.15, 4)
		end
	end,
	function(holder, color) -- topknot
		local knot = bar(holder, "Topknot", 0.5, 0.21, 0.12, 0.12, 0, color, 0.15, 4, UDim.new(1, 0))
		Kit.aspect(1, Enum.DominantAxis.Width).Parent = knot
	end,
	function(holder, color) -- long hair, behind the head
		bar(holder, "Hair", 0.5, 0.52, 0.44, 0.42, 0, color, 0.25, 2, UDim.new(0.4, 0))
	end,
	function(holder, color) -- hood
		bar(holder, "Hood", 0.5, 0.42, 0.5, 0.5, 0, color, 0.35, 2, UDim.new(0.5, 0))
	end,
}

local function bust(card, owned: boolean): Frame
	local glow = GLOW[card.Element] or card.Accent
	local holder = Kit.new("Frame", {
		Name = "Bust",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	local h = hash(card.Id)
	local spin = (h % 7) * 9 - 27 -- -27 .. +27 degrees: each card's pattern sits at its own angle
	local tone = if owned then glow else SILHOUETTE:Lerp(Color3.new(1, 1, 1), 0.12)
	local accent = if owned then card.Accent or glow else SILHOUETTE
	local metal = if owned then Color3.fromRGB(196, 202, 214):Lerp(glow, 0.25) else SILHOUETTE:Lerp(Color3.new(1, 1, 1), 0.08)

	local pattern = PATTERNS[card.Element]
	if pattern then
		pattern(holder, tone, spin)
	end
	-- The layered diamond emblem: element outer, the card's own Accent inside.
	local outer = bar(holder, "Emblem", 0.5, 0.42, 0.62, 0.62, 45, tone:Lerp(Color3.new(0, 0, 0), 0.55), if owned then 0.3 else 0.5, 1)
	Kit.aspect(1, Enum.DominantAxis.Width).Parent = outer
	Kit.stroke(tone, 2, if owned then 0.1 else 0.5).Parent = outer
	local inner = bar(holder, "EmblemCore", 0.5, 0.42, 0.4, 0.4, 45, accent, if owned then 0.45 else 0.6, 1)
	Kit.aspect(1, Enum.DominantAxis.Width).Parent = inner
	local weapon = WEAPONS[card.Role]
	if weapon then
		weapon(holder, tone, metal)
	end

	-- The rim-lit bust (bright at the top, deep at the base, a pale rim).
	local top = if owned then glow:Lerp(Color3.new(1, 1, 1), 0.1) else SILHOUETTE
	local bottom = if owned then glow:Lerp(Color3.new(0, 0, 0), 0.62) else SILHOUETTE:Lerp(Color3.new(0, 0, 0), 0.3)
	local rim = if owned then glow:Lerp(Color3.new(1, 1, 1), 0.55) else Color3.fromRGB(70, 66, 90)
	local function piece(name: string, anchorY: number, y: number, w: number, hh: number, round: UDim, aspect: boolean?)
		local part = Kit.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, anchorY),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(w, hh),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if owned then 0.15 else 0.1,
			ZIndex = 3,
			Parent = holder,
		}, {
			Kit.corner(round),
			Kit.stroke(rim, 1.5, if owned then 0.35 else 0.6),
			Kit.gradient(ColorSequence.new(top, bottom), 90),
		})
		if aspect then
			Kit.aspect(1, Enum.DominantAxis.Width).Parent = part
		end
		return part
	end
	local hairColor = if owned then accent:Lerp(Color3.new(0, 0, 0), 0.35) else SILHOUETTE:Lerp(Color3.new(0, 0, 0), 0.2)
	local crest = CRESTS[(h // 7) % #CRESTS + 1]
	piece("Shoulders", 1, 1.04, 0.86, 0.36, UDim.new(0.45, 0))
	piece("Head", 0.5, 0.44, 0.36, 0.36, UDim.new(1, 0), true)
	crest(holder, hairColor)
	return holder
end

-- A portrait for any card slot: the element glow, then the illustration or the bust. Fills its parent.
-- `background` = false leaves the glow out (full cards draw their own sunburst).
function CardView.Portrait(cardId: string, owned: boolean, background: boolean?): Frame
	local card = Cards.Get(cardId)
	local frame = Kit.new("Frame", {
		Name = "PortraitArt",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 18),
		BackgroundTransparency = if background == false then 1 else 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, { Kit.corner(UDim.new(0.14, 0)) })
	if card == nil then
		return frame
	end
	if background ~= false then
		Kit.new("Frame", {
			Name = "Glow",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = if owned then CardView.Glow(cardId) else Color3.fromRGB(40, 38, 56),
			ZIndex = 2,
			Parent = frame,
		}, {
			Kit.corner(UDim.new(0.14, 0)),
			Kit.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(20, 20, 30)),
				Transparency = NumberSequence.new(0.1, 0.4),
			}),
		})
	end
	local art = CardView.Art(cardId, owned)
	local inner = art or bust(card, owned)
	inner.Parent = frame
	if not owned then
		Kit.label({
			Name = "Unknown",
			Text = "?",
			Font = Theme.Font.Display,
			TextColor3 = Color3.fromRGB(194, 204, 225),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(0.5, 0.3),
			ZIndex = 5,
			Parent = frame,
		}, 80)
	end
	return frame
end

-- A sharp bevelled metal edge in the border tier's colour: light on the top-left, dark on the
-- bottom-right. `border` is a Borders.luau id ("Normal" = Base).
function CardView.Bevel(target: GuiObject, border: string?, thickness: number?)
	local color = Borders.Get(border).Color
	local stroke = Kit.stroke(Color3.new(1, 1, 1), thickness or 2.5, 0)
	stroke.Name = "Bevel"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Kit.new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.7)),
			ColorSequenceKeypoint.new(0.45, color),
			ColorSequenceKeypoint.new(0.55, color:Lerp(Color3.new(0, 0, 0), 0.45)),
			ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(1, 1, 1), 0.25)),
		}),
		Parent = stroke,
	})
	stroke.Parent = target
	return stroke
end

-- "130.01K" / "1.25M" for the stat footer.
local function short(n: number): string
	if n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.2fK", n / 1e3)
	end
	return Kit.commas(n)
end

-- The ability that headlines the card: its Ultimate, else its Skill, else its Basic.
local function headline(card)
	return Cards.Ability(card, "Ultimate") or Cards.Ability(card, "Skill") or Cards.Ability(card, "Basic")
end

local SLOT_ICON = { Ultimate = "💥", Skill = "⚡", Basic = "🗡️", Passive = "🍃", Aura = "✨", Signature = "👑" }

-- A small rounded chip (rarity, border, stars, tags): `width` is a share of the row.
local function chip(parent: Instance, order: number, text: string, color: Color3, width: number, textColor: Color3?)
	local frame = Kit.new("Frame", {
		Name = "Chip",
		LayoutOrder = order,
		Size = UDim2.fromScale(width, 1),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Color3.new(0, 0, 0), 1.5, 0.45) })
	local label = Kit.label({
		Text = text,
		Font = Theme.Font.Heavy,
		TextColor3 = textColor or Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.78),
		ZIndex = 6,
		Parent = frame,
	}, 18)
	if textColor == nil then
		Kit.textStroke(Color3.new(0, 0, 0), 1.2, 0.3).Parent = label
	end
	return frame
end

local function row(parent: Instance, name: string, y: number, height: number, wraps: boolean?): Frame
	return Kit.new("Frame", {
		Name = name,
		Position = UDim2.fromScale(0.04, y),
		Size = UDim2.fromScale(0.92, height),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.015, 0),
			Wraps = wraps == true,
		}),
	})
end

-- A dark fade over the art so text on it stays readable (top or bottom of the card).
local function shade(parent: Instance, top: boolean, height: number)
	Kit.new("Frame", {
		Name = if top then "TopShade" else "BottomShade",
		AnchorPoint = Vector2.new(0, if top then 0 else 1),
		Position = UDim2.fromScale(0, if top then 0 else 1),
		Size = UDim2.fromScale(1, height),
		BackgroundColor3 = Color3.fromRGB(6, 4, 14),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = parent,
	}, {
		Kit.new("UIGradient", {
			Rotation = if top then 90 else -90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.55, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- Returns the card Frame. Size/position it from outside; it keeps a 0.72 width:height ratio.
-- Full-art layout: the character fills the card; chips (rarity, border, stars, fusion) and the big
-- name sit on top, the headline ability bar, tag chips and the DMG / HP footer at the bottom.
-- Compact (grid tiles) keeps the art, the rarity chip, stars and the name.
function CardView.new(cardId: string, opts: Options?): Frame
	local options = opts or {}
	local card = Cards.Get(cardId)
	assert(card, `Unknown card {cardId}`)
	local owned = options.Owned ~= false
	local stars = options.Stars or 0
	local compact = options.Compact == true
	local border = if owned then options.Border or "Normal" else "Normal"
	local element = Elements.Get(card.Element)
	local glowColor = if element then element.Color else Theme.Color.Neon
	-- The tier's colours (the element's on a Base card) drive the frame, the sunburst and the halo.
	local tier = { Color = if border == "Normal" then glowColor else Borders.Get(border).Color, Dark = glowColor:Lerp(Color3.new(0, 0, 0), 0.75) }

	local frame = Kit.new("Frame", {
		Name = "Card_" .. card.Id,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, {
		Kit.corner(UDim.new(0.05, 0)),
		Kit.aspect(0.72, Enum.DominantAxis.Height),
		Kit.gradient(
			ColorSequence.new(
				if owned then card.Accent:Lerp(tier.Dark, 0.35) else Color3.fromRGB(44, 42, 58),
				if owned then tier.Dark:Lerp(Color3.new(0, 0, 0), 0.4) else Color3.fromRGB(12, 10, 20)
			),
			120
		),
	})

	-- The border frame: its gradient (prismatic for Secret); a thin element-tinted edge on Base.
	local stroke = Kit.stroke(Color3.new(1, 1, 1), if border == "Normal" then 1.2 else (if compact then 2.5 else 4), 0)
	stroke.Name = "RarityStroke"
	local strokeGradient = Kit.gradient(if border == "Normal" then ColorSequence.new(glowColor:Lerp(Theme.Color.Line, 0.4)) else Borders.Get(border).Gradient, 45)
	strokeGradient.Name = "RarityGradient"
	strokeGradient.Parent = stroke
	stroke.Parent = frame
	if border == "Secret" and options.Animate then
		Effects.Spin(strokeGradient, 120)
	end

	-- The art fills the card: sunburst and halo in the rarity colour, the character over them.
	local portrait = Kit.new("Frame", {
		Name = "Portrait",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = frame,
	}, { Kit.corner(UDim.new(0.05, 0)) })
	local burst = Kit.new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.9, 1.9),
		BackgroundTransparency = 1,
		Parent = portrait,
	}, { Kit.aspect(1, Enum.DominantAxis.Width) })
	for i = 1, 10 do
		Kit.new("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.07, 1),
			Rotation = (i - 1) * 18,
			BackgroundColor3 = tier.Color,
			BackgroundTransparency = if owned then 0.84 else 0.95,
			BorderSizePixel = 0,
			Parent = burst,
		})
	end
	Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.95, 0.95),
		BackgroundColor3 = tier.Color,
		BackgroundTransparency = if owned then 0.74 else 0.92,
		Parent = portrait,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
	})
	-- The illustration fills the whole card; until it exists, the element-lit bust stands in the middle.
	local art = CardView.Portrait(card.Id, owned, false)
	if card.Image == nil then
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.4)
		art.Size = UDim2.fromScale(0.72, 0.5)
	end
	art.Parent = portrait
	shade(frame, true, if compact then 0.3 else 0.3)
	shade(frame, false, if compact then 0.38 else 0.48)

	-- Element glow rising from the bottom edge.
	Kit.new("Frame", {
		Name = "ElementGlow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = glowColor,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	}, {
		Kit.corner(UDim.new(0.05, 0)),
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, if owned then 0.55 else 0.9) }),
		}),
	})

	-- Only the stars along the top: the frame already says the tier.
	local chips = row(frame, "Chips", 0.025, if compact then 0.1 else 0.06)
	if owned and stars > 0 and not compact then -- compact cards show ★★★★★ at the bottom instead
		chip(chips, 1, `★{stars}`, Color3.fromRGB(16, 19, 28), 0.16, Theme.Color.Gold)
	end
	-- The rarity number: how many pulls this card at this border takes (Cards.Rarity), in the border's colour.
	local rarity = if owned then Cards.Rarity(card.Id, border) else 0
	if rarity > 0 then
		local rarityChip = chip(chips, 2, Kit.commas(rarity), Color3.fromRGB(10, 12, 19), if compact then 0.42 else 0.3, tier.Color:Lerp(Color3.new(1, 1, 1), 0.25))
		rarityChip.Name = "Rarity"
	end

	-- Element badge: top-right on compact tiles, beside the name on full cards.
	ElementUi.Badge(card.Element, {
		AnchorPoint = Vector2.new(1, 0),
		Position = if compact then UDim2.fromScale(0.95, 0.025) else UDim2.fromScale(0.96, 0.1),
		Size = if compact then UDim2.fromScale(0.2, 0.2) else UDim2.fromScale(0.14, 0.14),
		Parent = frame,
	})

	-- The name, big, under the chips (at the bottom on compact tiles).
	local nameLabel = Kit.label({
		Name = "CardName",
		Text = if owned or not compact then card.Name else "???",
		Font = Theme.Font.Display,
		TextColor3 = if owned then Color3.new(1, 1, 1) else Theme.Color.Muted,
		TextXAlignment = if compact then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		Position = if compact then UDim2.fromScale(0.07, 0.79) else UDim2.fromScale(0.05, 0.095),
		Size = if compact then UDim2.fromScale(0.86, 0.16) else UDim2.fromScale(0.75, 0.095),
		ZIndex = 5,
		Parent = frame,
	}, if compact then 14 else 40)
	if compact then
		-- Long names ("Frostcrown Prince") wrap onto two lines and scale between 9 and 14 instead
		-- of clipping mid-word.
		nameLabel:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 9
	end
	Kit.textStroke(Color3.new(0, 0, 0), if compact then 1.5 else 2.5, 0.05).Parent = nameLabel

	if compact then
		if owned then
			local starLabel = Kit.label({
				Name = "Stars",
				Text = starText(stars),
				Font = Theme.Font.Heavy,
				TextColor3 = Theme.Color.Gold,
				Position = UDim2.fromScale(0.1, 0.7),
				Size = UDim2.fromScale(0.8, 0.09),
				ZIndex = 5,
				Parent = frame,
			}, 16)
			Kit.textStroke(Color3.new(0, 0, 0), 1.2, 0.2).Parent = starLabel
		end
	else
		Kit.label({
			Name = "CardTitle",
			Text = if owned then card.Title else "Not found yet",
			Font = Theme.Font.Bold,
			TextColor3 = Color3.fromRGB(210, 222, 244),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.05, 0.19),
			Size = UDim2.fromScale(0.78, 0.045),
			ZIndex = 5,
			Parent = frame,
		}, 18)

		local ability = headline(card)
		if owned and ability then
			-- The headline ability on a dark glass bar.
			local bar = Kit.new("Frame", {
				Name = "AbilityBar",
				Position = UDim2.fromScale(0.04, 0.655),
				Size = UDim2.fromScale(0.92, 0.085),
				BackgroundColor3 = Color3.fromRGB(11, 15, 23),
				BackgroundTransparency = 0.25,
				ZIndex = 5,
				Parent = frame,
			}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(tier.Color:Lerp(Color3.new(1, 1, 1), 0.3), 1.5, 0.45) })
			Kit.label({
				Text = SLOT_ICON[ability.Slot] or "✦",
				Font = Theme.Font.Heavy,
				Position = UDim2.fromScale(0.03, 0.12),
				Size = UDim2.fromScale(0.12, 0.76),
				ZIndex = 6,
				Parent = bar,
			}, 28)
			local abilityName = Kit.label({
				Text = ability.Name,
				Font = Theme.Font.Display,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromScale(0.17, 0.14),
				Size = UDim2.fromScale(0.78, 0.72),
				ZIndex = 6,
				Parent = bar,
			}, 30)
			Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = abilityName

			-- Tag chips: the card's trait (in its tier colour), its role and its always-on abilities.
			local tags = row(frame, "Tags", 0.755, 0.13, true)
			local tagList = {}
			local trait = Traits.Get(options.Trait)
			if trait then
				table.insert(tagList, { `{trait.Icon} {trait.Name}`, Rarity.Get(trait.Tier).Color })
			end
			local foil = Foils.Get(options.Foil)
			if options.Foil and options.Foil ~= "standard" then
				table.insert(tagList, { `{foil.Icon} {foil.Name}`, foil.Color })
			end
			if element then
				table.insert(tagList, { `{element.Icon} {element.Name}`, element.Color })
			end
			table.insert(tagList, { if card.Type == "Attack" then "⚔️ Attack" else "✨ Support", Color3.fromRGB(218, 230, 253) })
			for _, a in card.Abilities do
				if (a.Slot == "Passive" or a.Slot == "Aura" or a.Slot == "Signature") and #tagList < 4 then
					table.insert(tagList, { `{SLOT_ICON[a.Slot]} {a.Name}`, Color3.fromRGB(218, 230, 253) })
				end
			end
			for i, tagInfo in tagList do
				local tag = chip(tags, i, tagInfo[1], tagInfo[2], 0.45, Color3.fromRGB(10, 12, 19))
				tag.Size = UDim2.new(0.45, 0, 0.44, 0)
			end
		end

		-- Footer: DMG (ATK) and HP for Attack cards, PWR and SPD for Support cards.
		if owned then
			local main = Cards.Stat(card, card.Main, stars, options.Border)
			local leftText, leftColor, rightText, rightColor
			if card.Type == "Attack" then
				leftText, leftColor = `DMG {short(main)}`, Color3.fromRGB(255, 70, 70)
				rightText = `HP {short(Cards.Stat(card, card.HP or 0, stars, options.Border))}`
				rightColor = Color3.fromRGB(90, 230, 110)
			else
				leftText, leftColor = `PWR {short(main)}`, Color3.fromRGB(110, 200, 255)
				rightText, rightColor = `SPD {card.SPD}`, Color3.fromRGB(255, 220, 110)
			end
			for i, info in { { leftText, leftColor }, { rightText, rightColor } } do
				local stat = Kit.label({
					Name = if i == 1 then "StatLeft" else "StatRight",
					Text = info[1],
					Font = Theme.Font.Display,
					TextColor3 = info[2],
					TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
					Position = UDim2.fromScale(if i == 1 then 0.05 else 0.5, 0.9),
					Size = UDim2.fromScale(0.45, 0.075),
					ZIndex = 5,
					Parent = frame,
				}, 30)
				Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = stat
			end
		end
	end

	-- Uploaded frame art per border (when Skin.KitArt is on), then the border's own frame.
	Skin.Frame(frame, border, 7)
	if owned then
		BorderFx.Apply(frame, options.Border, {
			Corner = UDim.new(0.05, 0),
			ZIndex = 8,
			Spin = options.Animate,
			Tag = false, -- the border has its own chip at the top now
			Thickness = if compact then 3 else nil,
		})
	end

	-- Foil layer used by the shimmer (Rainbow and Secret borders).
	if Borders.Index(border) >= Borders.Index("Rainbow") and owned then
		local shine = Kit.new("Frame", {
			Name = "Shine",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ZIndex = 8,
			Parent = frame,
		}, { Kit.corner(UDim.new(0.05, 0)) })
		Kit.new("UIGradient", {
			Name = "ShineGradient",
			Rotation = 25,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Offset = Vector2.new(-1, 0),
			Parent = shine,
		})
	end

	return frame
end

-- The face-down card shown before a reveal.
function CardView.back(): Frame
	local frame = Kit.new("Frame", {
		Name = "CardBack",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, {
		Kit.corner(UDim.new(0.07, 0)),
		Kit.aspect(0.72, Enum.DominantAxis.Height),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(21, 27, 42), Color3.fromRGB(6, 8, 13)), 135),
	})
	local stroke = Kit.stroke(Color3.fromRGB(197, 207, 229), 4, 0.2)
	stroke.Name = "BackStroke"
	stroke.Parent = frame
	Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.91),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Kit.corner(UDim.new(0.06, 0)), Kit.stroke(Color3.fromRGB(197, 207, 229), 1.5, 0.5) })
	Kit.new("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(176, 92, 255),
		BackgroundTransparency = 0.55,
		Parent = frame,
	}, {
		Kit.corner(UDim.new(0.12, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
		Kit.stroke(Color3.fromRGB(219, 230, 254), 2, 0.3),
	})
	Kit.label({
		Name = "Mark",
		Text = "?",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.3),
		Parent = frame,
	}, 120)
	return frame
end

return CardView
