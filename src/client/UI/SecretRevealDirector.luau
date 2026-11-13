--!nonstrict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Assets = require(script.Parent.VfxAssets)
local Sfx = require(script.Parent.Sfx)
local Director = {}
local cosmetic = Random.new()

function Director.Hold(stage, border, color, duration)
	if border == "Normal" then return function() end end
	local rays = Assets.image(stage, "SunburstRays", 1.4, 1)
	rays.ImageColor3 = color
	rays.ImageTransparency = 0.45
	local circle = Assets.image(stage, "MagicCircle", 1.1, 2)
	circle.ImageColor3 = color
	circle.ImageTransparency = 0.28
	TweenService:Create(circle, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Rotation = 105 }):Play()
	local stop = Sfx.Anticipation(duration)
	local finished = false
	local connection
	local function finish()
		if finished then return end
		finished = true
		if connection then connection:Disconnect() end
		stop()
		circle:Destroy()
		rays:Destroy()
	end
	connection = stage.Destroying:Once(finish)
	return finish
end

-- A cosmetic misdirect on a real high-border pull, after the server has awarded the card.
function Director.Fakeout(border)
	return (border == "Rainbow" or border == "Secret") and cosmetic:NextInteger(1, 4) == 1
end

function Director.Crack(back)
	Assets.image(back, "CrackOverlay", 1, 40)
	Sfx.Play("GlassShatter")
end

function Director.Snap(stage, border)
	if border == "Normal" then return end
	for _, name in { "SpeedLines", "StarGlint" } do
		local sprite = Assets.image(stage, name, if name == "SpeedLines" then 1.35 else 0.45, 31)
		if name == "StarGlint" then sprite.Position = UDim2.fromScale(0.76, 0.22) end
		TweenService:Create(sprite, TweenInfo.new(0.34), { ImageTransparency = 1 }):Play()
		Debris:AddItem(sprite, 0.36)
	end
	if border == "Secret" then Sfx.Resonance() end
	if border == "Rainbow" or border == "Secret" then Sfx.Play("ChoirSwell") end
end
return Director
