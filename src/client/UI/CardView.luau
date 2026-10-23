--!nonstrict
-- Draws a card: rarity frame, a sunburst portrait with the character's 3D chibi art
-- (CardArt.luau, from Card.Look), name ribbon, stars and stats. Cards not found yet show the
-- character as a dark silhouette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local CardArt = require(Shared.CardArt)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Effects = require(script.Parent.Effects)
local BorderFx = require(script.Parent.BorderFx)

local CardView = {}

export type Options = {
	Owned: boolean?,
	Stars: number?,
	Fusion: number?, -- times fused: the card shows its new rarity and stats
	Compact: boolean?, -- small grid tile: hides title and stats
	Animate: boolean?, -- the figure sways (big reveals and detail views only)
	Border: string?, -- Borders.luau id: Gold / Rainbow / Secret frame (and its small stat bonus)
}

local SILHOUETTE = Color3.fromRGB(14, 10, 24)

local function starText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end

-- The character's art: an uploaded illustration (Card.Image) if there is one, otherwise the
-- 3D chibi figure in a ViewportFrame; nil when the card has neither.
function CardView.Art(cardId: string, owned: boolean, animate: boolean?): GuiObject?
	local card = Cards.Get(cardId)
	if card == nil then
		return nil
	end
	if card.Image then
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
	if card.Look == nil then
		return nil
	end
	local viewport = Kit.new("ViewportFrame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 165, 190),
		LightColor = Color3.fromRGB(255, 246, 236),
		LightDirection = Vector3.new(-0.5, -1, 0.7),
		ImageColor3 = if owned then Color3.new(1, 1, 1) else SILHOUETTE,
		ImageTransparency = if owned then 0 else 0.1,
		ZIndex = 2,
	})
	local model = CardArt.Build(card.Look)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = CardArt.FieldOfView
	camera.CFrame = CardArt.CameraCFrame
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if animate then
		local base = model:GetPivot()
		local start = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if viewport.Parent == nil then
				connection:Disconnect()
				return
			end
			local t = os.clock() - start
			model:PivotTo(base * CFrame.new(0, math.sin(t * 2.2) * 0.06, 0) * CFrame.Angles(0, math.sin(t * 0.9) * 0.35, 0))
		end)
	end
	return viewport
end

-- Returns the card Frame. Size/position it from outside; it keeps a 0.72 width:height ratio.
function CardView.new(cardId: string, opts: Options?): Frame
	local options = opts or {}
	local card = Cards.Get(cardId)
	assert(card, `Unknown card {cardId}`)
	local rarity = Cards.FusedRarity(card, options.Fusion) -- fused cards wear their new rarity
	local tier = Rarity.Get(rarity)
	local owned = options.Owned ~= false
	local stars = options.Stars or 0
	local compact = options.Compact == true

	local frame = Kit.new("Frame", {
		Name = "Card_" .. card.Id,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, {
		Kit.corner(UDim.new(0.07, 0)),
		Kit.aspect(0.72, Enum.DominantAxis.Height),
		Kit.gradient(
			ColorSequence.new(tier.Dark:Lerp(Color3.new(1, 1, 1), 0.14), tier.Dark:Lerp(Color3.new(0, 0, 0), 0.45)),
			90
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

	-- Thin inner border.
	Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.955),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Kit.corner(UDim.new(0.06, 0)), Kit.stroke(tier.Color, 1, 0.55) })

	-- Portrait.
	local portraitHeight = if compact then 0.7 else 0.6
	local portrait = Kit.new("Frame", {
		Name = "Portrait",
		Position = UDim2.fromScale(0.06, 0.045),
		Size = UDim2.fromScale(0.88, portraitHeight),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = frame,
	}, {
		Kit.corner(UDim.new(0.08, 0)),
		Kit.gradient(
			ColorSequence.new(
				if owned then card.Accent:Lerp(Color3.new(1, 1, 1), 0.15) else Color3.fromRGB(44, 42, 58),
				if owned then tier.Dark else Color3.fromRGB(16, 14, 24)
			),
			120
		),
	})

	-- Sunburst behind the character.
	local burst = Kit.new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(1.6, 1.6),
		BackgroundTransparency = 1,
		Parent = portrait,
	}, { Kit.aspect(1, Enum.DominantAxis.Width) })
	for i = 1, 8 do
		Kit.new("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.09, 1),
			Rotation = (i - 1) * 22.5,
			BackgroundColor3 = tier.Color,
			BackgroundTransparency = if owned then 0.82 else 0.94,
			BorderSizePixel = 0,
			Parent = burst,
		})
	end
	Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundColor3 = tier.Color,
		BackgroundTransparency = if owned then 0.72 else 0.92,
		Parent = portrait,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
	})

	local art = CardView.Art(card.Id, owned, options.Animate)
	if art then
		art.Parent = portrait
	end
	if art == nil or not owned then
		Kit.label({
			Name = "Glyph",
			Text = if owned then card.Glyph else "?",
			Font = Theme.Font.Display,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = if owned then 0.05 else 0.25,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.6, if art then 0.36 else 0.5),
			ZIndex = 3,
			Parent = portrait,
		}, 120)
	end

	-- Type badge (top-left) and rarity mark (top-right).
	local typeBadge = Kit.new("Frame", {
		Name = "TypeBadge",
		Position = UDim2.fromScale(0.04, 0.04),
		Size = UDim2.fromScale(0.22, 0.22),
		BackgroundColor3 = if card.Type == "Attack" then Theme.Color.Attack else Theme.Color.Support,
		ZIndex = 4,
		Parent = portrait,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
		Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.3),
	})
	Kit.label({
		Text = if card.Type == "Attack" then "⚔️" else "✨",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = 5,
		Parent = typeBadge,
	}, 22)

	if compact then
		Kit.new("Frame", {
			Name = "Gem",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.12),
			Size = UDim2.fromScale(0.13, 0.13),
			Rotation = 45,
			BackgroundColor3 = tier.Color,
			ZIndex = 4,
			Parent = portrait,
		}, {
			Kit.aspect(1, Enum.DominantAxis.Width),
			Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.2),
		})
	else
		local pill = Kit.new("Frame", {
			Name = "RarityPill",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.96, 0.04),
			Size = UDim2.fromScale(0.5, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.3,
			ZIndex = 4,
			Parent = portrait,
		}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(tier.Color, 1.5, 0.2) })
		Kit.label({
			Text = string.upper(rarity),
			Font = Theme.Font.Heavy,
			TextColor3 = tier.Color,
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			ZIndex = 5,
			Parent = pill,
		}, 16)
	end
	-- Fused cards carry a flame tag under the rarity mark.
	if (options.Fusion or 0) > 0 and owned then
		local tag = Kit.new("Frame", {
			Name = "Fused",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.96, if compact then 0.22 else 0.18),
			Size = UDim2.fromScale(if compact then 0.42 else 0.4, if compact then 0.13 else 0.1),
			BackgroundColor3 = Color3.fromRGB(255, 138, 61),
			ZIndex = 4,
			Parent = portrait,
		}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.2) })
		local fusedLabel = Kit.label({
			Text = if options.Fusion == 1 then "FUSED" else `FUSED x{options.Fusion}`,
			Font = Theme.Font.Heavy,
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			ZIndex = 5,
			Parent = tag,
		}, 16)
		Kit.textStroke(Color3.fromRGB(110, 40, 0), 1.5, 0).Parent = fusedLabel
	end

	-- Stars along the bottom of the portrait.
	if owned then
		local starLabel = Kit.label({
			Name = "Stars",
			Text = starText(stars),
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Gold,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(0.8, 0.13),
			ZIndex = 4,
			Parent = portrait,
		}, 22)
		Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = starLabel
	end

	-- Name ribbon.
	local nameTop = portraitHeight + 0.06
	local ribbon = Kit.new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromScale(0.04, nameTop),
		Size = UDim2.fromScale(0.92, if compact then 0.17 else 0.12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.gradient(
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, tier.Dark),
				ColorSequenceKeypoint.new(0.5, if owned then tier.Color:Lerp(tier.Dark, 0.35) else Color3.fromRGB(50, 48, 64)),
				ColorSequenceKeypoint.new(1, tier.Dark),
			}),
			0
		),
	})
	local nameLabel = Kit.label({
		Name = "CardName",
		Text = if owned or not compact then card.Name else "???",
		Font = Theme.Font.Heavy,
		TextColor3 = if owned then Theme.Color.Text else Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.78),
		Parent = ribbon,
	}, if compact then 18 else 30)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.35).Parent = nameLabel

	if not compact then
		Kit.label({
			Name = "CardTitle",
			Text = card.Title,
			Font = Theme.Font.Medium,
			TextColor3 = Theme.Color.Muted,
			Position = UDim2.fromScale(0.06, nameTop + 0.13),
			Size = UDim2.fromScale(0.88, 0.065),
			Parent = frame,
		}, 20)
		local main = Cards.Stat(card, card.Main, stars, options.Fusion, options.Border)
		local stats = if card.Type == "Attack"
			then `⚔️ {Kit.commas(main)}   ❤️ {Kit.commas(Cards.Stat(card, card.HP or 0, stars, options.Fusion, options.Border))}   ⚡ {card.SPD}`
			else `✨ {Kit.commas(main)} PWR   ⚡ {card.SPD}`
		local chip = Kit.new("Frame", {
			Name = "Stats",
			Position = UDim2.fromScale(0.08, nameTop + 0.205),
			Size = UDim2.fromScale(0.84, 0.075),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			Parent = frame,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.label({
			Text = stats,
			Font = Theme.Font.Bold,
			TextColor3 = Theme.Color.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.92, 0.8),
			Parent = chip,
		}, 20)
	end

	-- Uploaded rarity frame art, over everything but the foil, then the border (Gold / Rainbow / Secret).
	Skin.Frame(frame, rarity, 7)
	if owned then
		BorderFx.Apply(frame, options.Border, {
			Corner = UDim.new(0.07, 0),
			ZIndex = 8,
			Spin = options.Animate,
			Tag = not compact,
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
		}, { Kit.corner(UDim.new(0.07, 0)) })
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
		Kit.gradient(ColorSequence.new(Color3.fromRGB(60, 40, 110), Color3.fromRGB(16, 12, 34)), 135),
	})
	local stroke = Kit.stroke(Color3.fromRGB(200, 180, 255), 4, 0.2)
	stroke.Name = "BackStroke"
	stroke.Parent = frame
	Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.91),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Kit.corner(UDim.new(0.06, 0)), Kit.stroke(Color3.fromRGB(200, 180, 255), 1.5, 0.5) })
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
		Kit.stroke(Color3.fromRGB(230, 220, 255), 2, 0.3),
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
