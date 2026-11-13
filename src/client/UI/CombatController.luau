--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Assets = require(script.Parent.VfxAssets)
local Combat = {}
function Combat.Hit(surface: Instance?, impact: boolean?, color: Color3)
	if not surface then return end
	local name = if impact then "HitImpactVFX" else "SlashVFX"
	local old = surface:FindFirstChild(name)
	if old then old:Destroy() end
	local sprite = Assets.image(surface, name, 0.85, 48)
	sprite.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.65)
	sprite.Rotation = math.random(-24, 24)
	TweenService:Create(sprite, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(1.1, 1.1), ImageTransparency = 1 }):Play()
	Debris:AddItem(sprite, 0.26)
end
return Combat
