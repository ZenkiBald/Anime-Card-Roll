--!nonstrict
-- Bright world-space flex card, with a bounded three-layer aura and one shared UI animation loop.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Kit = require(script.Parent.UI.Kit)
local RollCard = require(script.Parent.UI.RollCard)
local VectorStyle = require(script.Parent.UI.VectorStyle)
local Theme = require(script.Parent.UI.Theme)

local Showcase = {}
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local STARS = "rbxasset://textures/particles/sparkles_main.dds"

local function label(parent, name, text, y, height, cap, color)
	local item = Kit.label({ Name = name, Text = text, Font = Enum.Font.FredokaOne,
		Position = UDim2.fromScale(0,y), Size = UDim2.fromScale(1,height),
		Parent = parent }, cap)
	item.TextColor3 = color
	return item
end

local function emitter(parent, name, texture, color, rate)
	local p = Instance.new("ParticleEmitter")
	p.Name = name
	p.Texture = texture
	p.Color = color
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Rate = rate
	p.Lifetime = NumberRange.new(.8,1.3)
	p.Speed = NumberRange.new(1,2)
	p.SpreadAngle = Vector2.new(180,180)
	p.Size = NumberSequence.new(.4,0)
	p.Transparency = NumberSequence.new(.15,1)
	p.Parent = parent
	return p
end

function Showcase.new(root: BasePart, cardId: string, borderId: string, elementColor: Color3, parent: Instance)
	local card = assert(Cards.Get(cardId))
	local border = Borders.Get(borderId)
	local part = Instance.new("Part")
	part.Name = "ShowcaseFlexCard"
	part.Size = Vector3.new(3.8,5.4,.12)
	part.Color = elementColor:Lerp(Color3.new(0,0,0), .65)
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(3.2,2.6,2.8) * CFrame.Angles(0,math.rad(-15),math.rad(6))
	part.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "ShowcaseArt"
		surface.Face = face
		surface.CanvasSize = Vector2.new(380,540)
		surface.LightInfluence = 0
		surface.Brightness = 2
		surface.AlwaysOnTop = false
		surface.MaxDistance = 120
		surface.Parent = part
		local art = RollCard.new(cardId,borderId)
		art:FindFirstChildOfClass("UIAspectRatioConstraint"):Destroy()
		art.Parent = surface
	end

	local colors = ColorSequence.new(elementColor, if borderId == "Normal" then elementColor:Lerp(Color3.new(1,1,1),.7) else border.Color)
	local core = emitter(part, "CoreGlow", SMOKE, colors, 18)
	core.Size = NumberSequence.new(3.5,5)
	core.Transparency = NumberSequence.new(.45,1)
	core.LockedToPart = true
	core.Shape = Enum.ParticleEmitterShape.Box
	core.RotSpeed = NumberRange.new(-20,20)
	local edge = Instance.new("Attachment")
	edge.Name = "EnergyOrigin"
	edge.Position = Vector3.new(0,-2.4,0)
	edge.Parent = part
	local wisps = emitter(edge, "EnergyWisps", if card.Element == "Flame" or card.Element == "Cosmic" then FIRE else SMOKE, colors, 35)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.SpreadAngle = Vector2.new(30,60)
	wisps.Speed = NumberRange.new(4,7)
	wisps.Acceleration = Vector3.new(0,2,0)
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0,.6), NumberSequenceKeypoint.new(.35,1.4), NumberSequenceKeypoint.new(1,0) })
	wisps.Transparency = NumberSequence.new(.35,1)
	wisps.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	local crisp = emitter(part, "ThemeParticles", if card.Element == "Flame" then FIRE else STARS, colors, 25)
	crisp.Shape = Enum.ParticleEmitterShape.Box
	crisp.Speed = NumberRange.new(.6,2)
	crisp.Acceleration = Vector3.new(0,1.5,0)
	crisp.RotSpeed = NumberRange.new(-100,100)
	local light = Instance.new("PointLight")
	light.Name = "ShowcaseLight"
	light.Color = elementColor
	light.Brightness = 3
	light.Range = 14
	light.Shadows = false
	light.Parent = part

	local gui = Instance.new("BillboardGui")
	gui.Name = "ShowcaseFlexLabel"
	gui.StudsOffset = Vector3.new(0,3.8,0)
	gui.Size = UDim2.fromOffset(220,75)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = part
	local tier = label(gui,"Tier",if borderId == "Secret" then "★ SECRET ★" else `{string.upper(border.Name)} · {border.Multiplier}x`,0,.28,19,border.Color)
	if borderId == "Rainbow" or borderId == "Secret" then
		tier.TextColor3 = Color3.new(1,1,1)
		local gradient = Kit.gradient(border.Gradient,0)
		gradient.Parent = tier
		VectorStyle.Spin(gradient,tier,70)
	end
	label(gui,"CardName",string.upper(card.Name),.29,.37,21,Color3.new(1,1,1))
	label(gui,"Rarity",`1 in {Kit.commas(Cards.Rarity(cardId,borderId))}`,.68,.3,18,if borderId == "Gold" then Color3.fromRGB(255,224,90) else Color3.fromRGB(119,255,162))
	local result = { Part = part, Emitters = { core,wisps,crisp }, Light = light }
	Showcase.Quality(result,1)
	return result
end

-- Full aura for the local player / nearest few; reduced rates elsewhere and on low effects.
function Showcase.Quality(showcase, weight: number)
	local scale = weight * (if Theme.FxLow then .25 else 1)
	for i, p in showcase.Emitters do
		p.Rate = ({18,35,25})[i] * scale
		p.Enabled = scale > 0
	end
	showcase.Light.Enabled = weight == 1 and not Theme.FxLow
	showcase.Part.ShowcaseFlexLabel.Enabled = weight > 0
end

return Showcase
