-- Sets the place's saved Lighting to the twilight look (run once in Studio, then save / publish).
-- Lighting.Technology can only be set here, in Studio: game scripts can't write it. The other values
-- match src/client/LightingSetup.luau, which also applies them on every client at start.
local Lighting = game:GetService("Lighting")
Lighting.Technology = Enum.Technology.Future
Lighting.TimeOfDay = "18:45:00"
Lighting.Brightness = 1.8
Lighting.OutdoorAmbient = Color3.fromRGB(45, 50, 75)
Lighting.Ambient = Color3.fromRGB(20, 25, 40)
Lighting.ShadowSoftness = 0.2
Lighting.GlobalShadows = true

local function effect(className, name)
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local grade = effect("ColorCorrectionEffect", "Grade")
grade.Contrast = 0.18
grade.Saturation = -0.05
grade.TintColor = Color3.fromRGB(245, 240, 255)
grade.Brightness = 0

local bloom = effect("BloomEffect", "Bloom")
bloom.Intensity = 0.65
bloom.Size = 24
bloom.Threshold = 1.8

local atmosphere = effect("Atmosphere", "Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(30, 35, 55)
atmosphere.Decay = Color3.fromRGB(15, 18, 30)
atmosphere.Glare = 0.4
atmosphere.Haze = 1.5

return "Lighting set to Future twilight"
