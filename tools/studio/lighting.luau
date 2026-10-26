-- Sets the place's saved Lighting to the bright town day (run once in Studio, then save / publish).
-- Lighting.Technology can only be set here, in Studio: game scripts can't write it. The other values
-- match src/client/LightingSetup.luau, which also applies them on every client at start.
local Lighting = game:GetService("Lighting")
Lighting.Technology = Enum.Technology.Future
Lighting.TimeOfDay = "14:00:00"
Lighting.Brightness = 3
Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
Lighting.Ambient = Color3.fromRGB(90, 90, 100)
Lighting.ExposureCompensation = 0
Lighting.ShadowSoftness = 0.3
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
grade.Contrast = 0.08
grade.Saturation = 0.12
grade.TintColor = Color3.fromRGB(255, 250, 240)
grade.Brightness = 0

local bloom = effect("BloomEffect", "Bloom")
bloom.Intensity = 0.4
bloom.Size = 24
bloom.Threshold = 2.4

local atmosphere = effect("Atmosphere", "Atmosphere")
atmosphere.Density = 0.25
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(199, 210, 225)
atmosphere.Decay = Color3.fromRGB(106, 130, 160)
atmosphere.Glare = 0.2
atmosphere.Haze = 0.8

return "Lighting set to Future, bright day"
