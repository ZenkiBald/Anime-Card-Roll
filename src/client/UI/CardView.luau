--!nonstrict
-- Draws a card, full-art: the character's 2D illustration (Card.Image) fills the card on a sunburst in
-- the rarity colour, with chips, the big name, the headline ability, tags and DMG / HP on top of it.
-- Cards without an illustration yet show an element-lit bust (CardView.Portrait, used by every card
-- slot); cards not found yet show a dark silhouette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
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
	Fusion: number?, -- times fused: the card shows its new rarity and stats
	Compact: boolean?, -- small grid tile: hides title and stats
	Animate: boolean?, -- the figure sways (big reveals and detail views only)
	Border: string?, -- Borders.luau id: Gold / Rainbow / Secret frame (and its small stat bonus)
	Trait: string?, -- Traits.luau id: shown as the first tag chip, in its tier colour
	Foil: string?, -- Foils.luau id: shown as a tag chip when it isn't Standard
}

local SILHOUETTE = Color3.fromRGB(14, 10, 24)

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

-- Until a card has its illustration: a rim-lit bust silhouette over the element's icon, never letters.
local function bust(card, owned: boolean): Frame
	local glow = GLOW[card.Element] or card.Accent
	local holder = Kit.new("Frame", {
		Name = "Bust",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	local element = Elements.Get(card.Element)
	if element and owned then
		Kit.label({
			Name = "Mark",
			Text = element.Icon,
			Font = Theme.Font.Heavy,
			TextTransparency = 0.72,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.9, 0.62),
			ZIndex = 2,
			Parent = holder,
		}, 160)
	end
	local fill = if owned then Color3.fromRGB(18, 14, 30) else SILHOUETTE
	local rim = if owned then glow else Color3.fromRGB(60, 56, 80)
	local function piece(name: string, anchorY: number, y: number, w: number, h: number, round: UDim, aspect: boolean?)
		local part = Kit.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, anchorY),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = fill,
			ZIndex = 3,
			Parent = holder,
		}, {
			Kit.corner(round),
			Kit.stroke(rim, 2, if owned then 0.15 else 0.5),
			Kit.gradient(ColorSequence.new(if owned then fill:Lerp(glow, 0.35) else fill, fill), 90),
		})
		if aspect then
			Kit.aspect(1, Enum.DominantAxis.Width).Parent = part
		end
		return part
	end
	piece("Shoulders", 1, 1.04, 0.86, 0.36, UDim.new(0.45, 0))
	piece("Head", 0.5, 0.44, 0.36, 0.36, UDim.new(1, 0), true)
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

-- A sharp bevelled metal edge in the rarity colour: light on the top-left, dark on the bottom-right.
function CardView.Bevel(target: GuiObject, rarity: string, thickness: number?)
	local color = Rarity.Get(rarity).Color
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
	local rarity = Cards.FusedRarity(card, options.Fusion) -- fused cards wear their new rarity
	local tier = Rarity.Get(rarity)
	local owned = options.Owned ~= false
	local stars = options.Stars or 0
	local compact = options.Compact == true
	local border = options.Border or "Normal"

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

	-- Rarity frame: gradient stroke (prismatic for Secret).
	local stroke = Kit.stroke(Color3.new(1, 1, 1), if compact then 2.5 else 4, 0)
	stroke.Name = "RarityStroke"
	local strokeGradient = Kit.gradient(Rarity.Gradient(rarity), 45)
	strokeGradient.Name = "RarityGradient"
	strokeGradient.Parent = stroke
	stroke.Parent = frame
	if rarity == "Secret" and options.Animate then
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

	-- Chips along the top: rarity, border, stars, fusion.
	local chips = row(frame, "Chips", 0.025, if compact then 0.1 else 0.06)
	if compact then
		chip(chips, 1, string.upper(string.sub(rarity, 1, 1)), tier.Color, 0.2, Color3.fromRGB(16, 10, 30))
		if (options.Fusion or 0) > 0 and owned then
			chip(chips, 2, "🔥", Color3.fromRGB(255, 138, 61), 0.2)
		end
	else
		chip(chips, 1, rarity, tier.Color, 0.32, Color3.fromRGB(16, 10, 30))
		if owned and border ~= "Normal" then
			local b = Borders.Get(border)
			chip(chips, 2, b.Name, b.Color, 0.26, Color3.fromRGB(16, 10, 30))
		end
		if owned then
			chip(chips, 3, `★{stars}`, Color3.fromRGB(70, 70, 90), 0.16, if stars > 0 then Theme.Color.Gold else nil)
		end
		if (options.Fusion or 0) > 0 and owned then
			chip(chips, 4, if options.Fusion == 1 then "FUSED" else `FUSED x{options.Fusion}`, Color3.fromRGB(255, 138, 61), 0.26)
		end
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
		Position = if compact then UDim2.fromScale(0.05, 0.8) else UDim2.fromScale(0.05, 0.095),
		Size = if compact then UDim2.fromScale(0.9, 0.13) else UDim2.fromScale(0.75, 0.095),
		ZIndex = 5,
		Parent = frame,
	}, if compact then 22 else 40)
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
			local element = Elements.Get(card.Element)
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
			local main = Cards.Stat(card, card.Main, stars, options.Fusion, options.Border)
			local leftText, leftColor, rightText, rightColor
			if card.Type == "Attack" then
				leftText, leftColor = `DMG {short(main)}`, Color3.fromRGB(255, 70, 70)
				rightText = `HP {short(Cards.Stat(card, card.HP or 0, stars, options.Fusion, options.Border))}`
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

	-- Uploaded rarity frame art, over everything but the foil, then the border (Gold / Rainbow / Secret).
	Skin.Frame(frame, rarity, 7)
	if owned then
		BorderFx.Apply(frame, options.Border, {
			Corner = UDim.new(0.05, 0),
			ZIndex = 8,
			Spin = options.Animate,
			Tag = false, -- the border has its own chip at the top now
			Thickness = if compact then 3 else nil,
		})
	end

	-- Foil layer used by the shimmer (Legendary and up).
	if Rarity.AtLeast(rarity, "Legendary") and owned then
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
