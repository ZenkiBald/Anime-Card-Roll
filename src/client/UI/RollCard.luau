--!nonstrict
-- Art-first presentation for rolled cards. Inspectors / collection tiles keep their own details.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Kit = require(script.Parent.Kit)
local CardView = require(script.Parent.CardView)
local BorderFx = require(script.Parent.BorderFx)
local ElementUi = require(script.Parent.ElementUi)

local RollCard = {}

function RollCard.IsNew(result): boolean
	-- The Index tracks each border separately. Both flags come from the server's roll result.
	return result.Outcome == "New" or result.NewBorder == true
end

local function fade(parent, top)
	Kit.new("Frame", {
		Name = if top then "TopShade" else "BottomShade",
		AnchorPoint = Vector2.new(0, if top then 0 else 1),
		Position = UDim2.fromScale(0, if top then 0 else 1),
		Size = UDim2.fromScale(1, if top then .19 else .13),
		BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = .25,
		BorderSizePixel = 0, ZIndex = 3, Parent = parent,
	}, { Kit.new("UIGradient", { Rotation = 90, Transparency = if top then NumberSequence.new(0,1) else NumberSequence.new(1,0) }) })
end

local function outlined(props, cap)
	local label = Kit.label(props, cap)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Thickness = 2 end
	label:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 6
	return label
end

function RollCard.NewBadge(parent)
	local badge = Kit.new("Frame", {
		Name = "NewBadge", AnchorPoint = Vector2.new(.5,1),
		Position = UDim2.new(.5,0,0,-3), Size = UDim2.fromScale(.52,.13),
		BackgroundColor3 = Color3.fromRGB(255,218,66), ZIndex = 24, Parent = parent,
	}, { Kit.corner(), Kit.stroke(Color3.fromRGB(255,241,154), 2.5, 0) })
	Kit.surface(badge, Color3.fromRGB(255,235,115), Color3.fromRGB(222,143,17))
	outlined({ Name = "Label", Text = "NEW!", Font = Enum.Font.FredokaOne,
		Size = UDim2.fromScale(1,1), ZIndex = 25, Parent = badge }, 24)
	return badge
end

function RollCard.new(cardId: string, borderId: string?, isNew: boolean?): Frame
	local card = assert(Cards.Get(cardId), `Unknown card {cardId}`)
	local border = borderId or "Normal"
	local tier = Borders.Get(border)
	local frame = Kit.new("Frame", {
		Name = "RollCard_" .. cardId, Size = UDim2.fromScale(1,1),
		BackgroundColor3 = tier.Dark,
	}, { Kit.corner(), Kit.aspect(.72, Enum.DominantAxis.Height) })
	Kit.surface(frame, card.Accent, tier.Dark)
	frame.VectorDecor.Gloss.Visible = false
	local picture = Kit.new("Frame", { Name = "Portrait", Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = frame }, { Kit.corner() })
	local art = CardView.Art(cardId, true) or CardView.Portrait(cardId, true, false)
	art.Size = UDim2.fromScale(1,1)
	art.Parent = picture
	fade(picture, true)
	fade(picture, false)
	BorderFx.Apply(frame, border)
	outlined({ Name = "CardName", Text = string.upper(card.Name), Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(.08,.05),
		Size = UDim2.fromScale(.72,.14), ZIndex = 5, Parent = frame }, 34)
	ElementUi.Badge(card.Element, { AnchorPoint = Vector2.new(1,0), Position = UDim2.fromScale(.96,.035),
		Size = UDim2.fromScale(.16,.16), ZIndex = 6, Parent = frame })
	local rarity = outlined({ Name = "Rarity", Text = Kit.commas(Cards.Rarity(cardId,border)),
		Font = Enum.Font.FredokaOne, AnchorPoint = Vector2.new(.5,1),
		Position = UDim2.fromScale(.5,.95), Size = UDim2.fromScale(.88,.09), ZIndex = 5, Parent = frame }, 30)
	rarity.TextColor3 = if border == "Gold" then Color3.fromRGB(255,224,103) else Color3.fromRGB(144,255,222)
	if isNew then RollCard.NewBadge(frame) end
	return frame
end

return RollCard
