--!nonstrict
-- The game's base light: moody twilight with bloom on neon trims and aura glows, a little contrast and
-- a cold haze. Runs once on each client at start; ZoneFx then shifts it per zone (its moods tween from
-- these values and back). Effects already in the place are reused, not duplicated.
-- Lighting.Technology can't be set by a game script (Studio only): tools/studio/lighting.luau sets it
-- to Future in the place file. The pcall below is just in case Roblox ever opens it up.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

LightingSetup.Lighting = {
	TimeOfDay = "18:45:00",
	Brightness = 1.8,
	OutdoorAmbient = Color3.fromRGB(45, 50, 75),
	Ambient = Color3.fromRGB(20, 25, 40),
	ShadowSoftness = 0.2,
	GlobalShadows = true,
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.6,
}

LightingSetup.Grade = {
	Contrast = 0.18,
	Saturation = -0.05,
	TintColor = Color3.fromRGB(245, 240, 255),
	Brightness = 0,
}

LightingSetup.Bloom = {
	Intensity = 0.65,
	Size = 24,
	Threshold = 1.8,
}

LightingSetup.Atmosphere = {
	Density = 0.32,
	Offset = 0.25,
	Color = Color3.fromRGB(30, 35, 55),
	Decay = Color3.fromRGB(15, 18, 30),
	Glare = 0.4,
	Haze = 1.5,
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
