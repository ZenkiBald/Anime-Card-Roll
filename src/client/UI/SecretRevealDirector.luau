--!nonstrict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Assets = require(script.Parent.VfxAssets)
local Sfx = require(script.Parent.Sfx)
local Director = {}
local cosmetic = Random.new()

-- The ray and speed-line images have visible pixels at their edges. Crop to the viewport so
-- those edges fall outside the screen, including in the small centre-stage and Quick layouts.
local function screenImage(stage, name, layer)
	local screen = stage:FindFirstAncestorOfClass("ScreenGui")
	local canvas = screen:FindFirstChild("Reveal") or screen
	local image = Assets.image(canvas, name, 1, layer)
	image.ScaleType = Enum.ScaleType.Crop
	return image
end

function Director.SecretSession(owner)
	local release = Sfx.HoldSecretAmbience()
	local connection = owner.Destroying:Once(release)
	return function()
		connection:Disconnect()
		release()
	end
end

function Director.Flash(stage, color, duration)
	local flash = screenImage(stage, "StarGlint", 50)
	flash.Name = "SecretFlash"
	flash.ImageColor3 = color
	flash.ImageTransparency = 0.24
	TweenService:Create(flash, TweenInfo.new(duration), { ImageTransparency = 1 }):Play()
	Debris:AddItem(flash, duration + 0.02)
end

function Director.Hold(stage, border, color, duration)
	if border == "Normal" then return function() end end
	local rays = screenImage(stage, "SunburstRays", 2)
	rays.ImageColor3 = color
	rays.ImageTransparency = 0.78
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
		local sprite = if name == "SpeedLines" then screenImage(stage, name, 31) else Assets.image(stage, name, 0.45, 31)
		if name == "SpeedLines" then sprite.ImageTransparency = 0.65 end
		if name == "StarGlint" then sprite.Position = UDim2.fromScale(0.76, 0.22) end
		TweenService:Create(sprite, TweenInfo.new(0.34), { ImageTransparency = 1 }):Play()
		Debris:AddItem(sprite, 0.36)
	end
	if border == "Secret" then Sfx.Resonance() end
	if border == "Rainbow" or border == "Secret" then Sfx.Play("ChoirSwell") end
end
return Director
