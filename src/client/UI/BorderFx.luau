--!nonstrict
-- Shared rotating holographic rims for Gold, Rainbow and Secret cards. Normal draws nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Borders = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Borders"))

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local BorderFx = {}

export type Options = {
	Thickness: number?, -- frame width in pixels
	Corner: UDim?, -- the card's corner radius
	ZIndex: number?,
	Spin: boolean?, -- turn the Rainbow / Secret gradient (only a few cards at once: it runs every frame)
	Tag: boolean?, -- the border's name across the top
}

-- A small pill naming the border, in its gradient.
function BorderFx.Tag(parent: Instance, borderId: string, props: { [string]: any }?): Frame
	local border = Borders.Get(borderId)
	local tag = Kit.new("Frame", {
		Name = "BorderTag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.012),
		Size = UDim2.fromScale(0.56, 0.075),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.gradient(border.Gradient, 0),
		Kit.stroke(if borderId == "Secret" then Color3.fromRGB(230, 220, 255) else Color3.fromRGB(40, 16, 60), 2, 0),
	})
	if props then
		for key, value in props do
			tag[key] = value
		end
	end
	local label = Kit.label({
		Text = string.upper(border.Name),
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		ZIndex = 13,
		Parent = tag,
	}, 24)
	Kit.textStroke(Color3.fromRGB(30, 10, 50), 2, 0).Parent = label
	return tag
end

-- Puts the border on `target` (a card Frame or tile). Returns the frame it made, or nil for Normal.
function BorderFx.Apply(target: GuiObject, borderId: string?, opts: Options?): Frame?
	if borderId == nil or borderId == "Normal" or Borders.ById[borderId] == nil then
		return nil
	end
	local options = opts or {}
	local border = Borders.Get(borderId)
	local zIndex = options.ZIndex or 9
	local frame = Kit.rareBorder(target, borderId, border.Gradient, border.Color)
	if options.Tag then
		BorderFx.Tag(target, borderId).ZIndex = zIndex + 3
	end
	return frame
end

return BorderFx
