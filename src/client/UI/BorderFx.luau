--!nonstrict
-- Draws a card's border (Borders.luau) over a card or tile: a thick gradient frame inside its edge
-- (gold, rainbow, or the black prismatic Secret one, which spins when `Spin` is on), a soft outer glow
-- for Rainbow and Secret, and optionally a ribbon tag ("RAINBOW") across the top. Normal draws nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Borders = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Borders"))

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)

local BorderFx = {}

export type Options = {
	Thickness: number?, -- frame width in pixels
	Corner: UDim?, -- the card's corner radius
	ZIndex: number?,
	Spin: boolean?, -- turn the Rainbow / Secret gradient (only a few cards at once: it runs every frame)
	Tag: boolean?, -- the border's name across the top
}

local THICKNESS = { Gold = 4, Rainbow = 5, Secret = 6 }

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
	local thickness = options.Thickness or THICKNESS[borderId] or 4
	local zIndex = options.ZIndex or 9
	local frame = Kit.new("Frame", {
		Name = "BorderFx",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		-- Inset by the stroke so tiles that clip their children still show all of it.
		Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = target,
	}, { Kit.corner(options.Corner or UDim.new(0.07, 0)) })
	local stroke = Kit.stroke(Color3.new(1, 1, 1), thickness, 0)
	stroke.Parent = frame
	local gradient = Kit.gradient(border.Gradient, 45)
	gradient.Parent = stroke
	if options.Spin and borderId ~= "Gold" then
		Effects.Spin(gradient, if borderId == "Secret" then 150 else 90)
	end
	-- Rainbow and Secret also glow softly around the card.
	if borderId ~= "Gold" then
		local glow = Kit.new("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, thickness * 2, 1, thickness * 2),
			BackgroundTransparency = 1,
			ZIndex = zIndex,
			Parent = frame,
		}, { Kit.corner(options.Corner or UDim.new(0.07, 0)) })
		local glowStroke = Kit.stroke(border.Color, thickness, 0.55)
		glowStroke.Parent = glow
		Kit.gradient(border.Gradient, 135).Parent = glowStroke
	end
	if options.Tag then
		BorderFx.Tag(target, borderId).ZIndex = zIndex + 3
	end
	return frame
end

return BorderFx
