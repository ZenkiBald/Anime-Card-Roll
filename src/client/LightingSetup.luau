--!nonstrict
-- The game's base light: a bright, clear afternoon (the town's look), warm sun, soft blue sky haze and a
-- light bloom that only catches neon trims and aura glows. Runs once on each client at start; ZoneFx then
-- gives each world its own theme (its moods tween from these values and back to them in town). Effects
-- already in the place are reused, not duplicated.
-- Lighting.Technology can't be set by a game script (Studio only): tools/studio/lighting.luau sets it
-- to Future in the place file. The pcall below is just in case Roblox ever opens it up.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

LightingSetup.Lighting = {
	TimeOfDay = "14:00:00",
	Brightness = 3,
	OutdoorAmbient = Color3.fromRGB(140, 140, 150),
	Ambient = Color3.fromRGB(90, 90, 100),
	ExposureCompensation = 0,
	ShadowSoftness = 0.3,
	GlobalShadows = true,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
}

LightingSetup.Grade = {
	Contrast = 0.08,
	Saturation = 0.12,
	TintColor = Color3.fromRGB(255, 250, 240),
	Brightness = 0,
}

LightingSetup.Bloom = {
	Intensity = 0.4,
	Size = 24,
	Threshold = 2.4,
}

LightingSetup.Atmosphere = {
	Density = 0.25,
	Offset = 0.1,
	Color = Color3.fromRGB(199, 210, 225),
	Decay = Color3.fromRGB(106, 130, 160),
	Glare = 0.2,
	Haze = 0.8,
}

-- The first effect of a class already in Lighting, else a new one.
local function effect(className: string, name: string): Instance
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function apply(inst: Instance, props)
	for prop, value in props do
		pcall(function()
			(inst :: any)[prop] = value
		end)
	end
end

function LightingSetup.Apply()
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	apply(Lighting, LightingSetup.Lighting)
	apply(effect("ColorCorrectionEffect", "Grade"), LightingSetup.Grade)
	apply(effect("BloomEffect", "Bloom"), LightingSetup.Bloom)
	apply(effect("Atmosphere", "Atmosphere"), LightingSetup.Atmosphere)
end

return LightingSetup
