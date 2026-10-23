--!nonstrict
-- Which zone the player is walking in: the music crossfades and the light shifts from the twilight base
-- (ember dusk in Ember Village, cold blue dusk on Frostfang Peaks, violet night in the Neon Abyss, storm
-- dusk with lightning on Stormspire Isle), with sakura petals drifting in town and autumn leaves in Ember Village.
-- Zones come from ReplicatedStorage.Zones (World publishes them from the map's Zone_ markers);
-- a place without a map just plays the town music. Lighting changes here are local to this player.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.UI.Sfx)
local Theme = require(script.Parent.UI.Theme)
local State = require(script.Parent.State)

local ZoneFx = {}

-- Lighting per zone, on top of the twilight base (LightingSetup); anything not listed goes back to the
-- base. All dusk or night: warm ember dusk, cold blue dusk on the peaks (exposure down so snow and
-- Rimeveil don't blow out), violet night in the Abyss, storm dusk.
local MOODS = {
	EmberVillage = {
		Lighting = { ClockTime = 18.1, Brightness = 2, OutdoorAmbient = Color3.fromRGB(80, 55, 50) },
		Atmosphere = { Color = Color3.fromRGB(70, 45, 40), Decay = Color3.fromRGB(40, 20, 18), Density = 0.34, Haze = 1.7 },
		Grade = { TintColor = Color3.fromRGB(255, 236, 220), Saturation = 0.05 },
	},
	FrostfangPeaks = {
		Lighting = { ClockTime = 17.9, Brightness = 1.9, OutdoorAmbient = Color3.fromRGB(60, 70, 95), ExposureCompensation = -0.4 },
		Atmosphere = { Color = Color3.fromRGB(60, 72, 100), Decay = Color3.fromRGB(25, 32, 55), Density = 0.34, Haze = 1.4 },
		Grade = { TintColor = Color3.fromRGB(230, 240, 255), Saturation = -0.08, Contrast = 0.2 },
	},
	NeonAbyss = {
		Lighting = { ClockTime = 0.4, Brightness = 1.4, OutdoorAmbient = Color3.fromRGB(50, 35, 80), Ambient = Color3.fromRGB(35, 25, 60) },
		Atmosphere = { Color = Color3.fromRGB(50, 30, 85), Decay = Color3.fromRGB(20, 10, 40), Density = 0.42, Haze = 2 },
		Grade = { TintColor = Color3.fromRGB(235, 220, 255), Saturation = 0.1 },
	},
	-- Storm dusk: dim, cold and hazy; lightning (below) does the rest.
	StormspireIsle = {
		Lighting = { ClockTime = 17.6, Brightness = 1.6, OutdoorAmbient = Color3.fromRGB(55, 60, 80), ExposureCompensation = 0 },
		Atmosphere = { Color = Color3.fromRGB(45, 50, 70), Decay = Color3.fromRGB(20, 24, 40), Density = 0.42, Haze = 2.2 },
		Grade = { TintColor = Color3.fromRGB(215, 225, 255), Saturation = -0.12, Contrast = 0.2 },
	},
}

-- Zones where lightning strikes now and then: a bolt in the sky near you, a flash and thunder.
-- All local and short-lived (a few neon parts for a quarter of a second).
local LIGHTNING = { StormspireIsle = Color3.fromRGB(255, 240, 160) }

local saved = {} -- [instance] = { [property] = value } as the map saved them
local current: string? = nil

local function strike(color: Color3, near: Vector3)
	local angle = math.random() * math.pi * 2
	local distance = 60 + math.random() * 80
	local ground = near + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local bolt = Instance.new("Model")
	bolt.Name = "Lightning"
	local point = ground + Vector3.new(0, 160, 0)
	for _ = 1, 6 do
		local nextPoint = point + Vector3.new(math.random(-14, 14), -26, math.random(-14, 14))
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(1.2, 1.2, (nextPoint - point).Magnitude)
		part.CFrame = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
		part.Parent = bolt
		point = nextPoint
	end
	bolt.Parent = workspace
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grade then
		local before = grade.Brightness
		grade.Brightness = before + 0.35
		TweenService:Create(grade, TweenInfo.new(0.35), { Brightness = before }):Play()
	end
	task.delay(0.22, function()
		bolt:Destroy()
	end)
	task.delay(0.4 + distance / 250, Sfx.Play, "Thunder", 0.9 + math.random() * 0.2)
end

-- Every 6-14 s, a strike if you're in a stormy zone (and not in a fight).
local function lightningLoop()
	while true do
		task.wait(6 + math.random() * 8)
		local color = current and LIGHTNING[current]
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if color and root and not State.InBattle then
			strike(color, root.Position)
		end
	end
end

-- Zones where petals drift down around you: a small pool of pink flakes that flutter, sway and
-- start again above you when they reach the ground (local parts, no physics).
local PETALS = {
	Town = { Color3.fromRGB(255, 182, 210), Color3.fromRGB(255, 214, 230), Color3.fromRGB(250, 150, 190) },
	EmberVillage = { Color3.fromRGB(255, 140, 60), Color3.fromRGB(230, 80, 40), Color3.fromRGB(255, 190, 90) },
}
local petals = {} -- { Part, Offset, Fall, Sway, Spin, Phase }
local petalFolder: Folder? = nil

local function respawnPetal(petal, around: Vector3, colors, top: boolean)
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * 45
	petal.Offset = Vector3.new(math.cos(angle) * distance, if top then 26 + math.random() * 10 else math.random() * 36, math.sin(angle) * distance)
	petal.Base = around
	petal.Part.Color = colors[math.random(1, #colors)]
	petal.Fall = 2.5 + math.random() * 2
	petal.Sway = 1 + math.random() * 1.5
	petal.Spin = (math.random() - 0.5) * 6
	petal.Phase = math.random() * 10
end

local function petalStep(dt: number)
	local colors = current and PETALS[current]
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local want = if colors and root and not State.InBattle then (if Theme.FxLow then 14 else 36) else 0
	local folder = petalFolder
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Petals"
		folder.Parent = workspace
		petalFolder = folder
	end
	while #petals < want do
		local part = Instance.new("Part")
		part.Name = "Petal"
		part.Size = Vector3.new(0.55, 0.05, 0.38)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = folder
		local petal = { Part = part }
		respawnPetal(petal, root.Position, colors, false)
		table.insert(petals, petal)
	end
	while #petals > want do
		local last = table.remove(petals)
		if last then
			last.Part:Destroy()
		end
	end
	for _, petal in petals do
		petal.Phase += dt
		petal.Offset -= Vector3.new(0, petal.Fall * dt, 0)
		local world = petal.Base + petal.Offset
		-- Re-centre on the player when they wander off, and start again above once landed.
		if petal.Offset.Y < -4 or (Vector3.new(world.X, 0, world.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > 55 then
			respawnPetal(petal, root.Position, colors, true)
			world = petal.Base + petal.Offset
		end
		local sway = Vector3.new(math.sin(petal.Phase * 1.3) * petal.Sway, 0, math.cos(petal.Phase) * petal.Sway * 0.6)
		petal.Part.CFrame = CFrame.new(world + sway)
			* CFrame.Angles(math.sin(petal.Phase * 2) * 0.9, petal.Phase * petal.Spin, math.cos(petal.Phase * 1.7) * 0.7)
	end
end

local function targets()
	return {
		Lighting = Lighting,
		Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere"),
		Grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
	}
end

local function remember(inst: Instance, props)
	saved[inst] = saved[inst] or {}
	for prop in props do
		if saved[inst][prop] == nil then
			saved[inst][prop] = (inst :: any)[prop]
		end
	end
end

local function applyMood(zone: string)
	local mood = MOODS[zone] or {}
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	for key, inst in targets() do
		if inst == nil then
			continue
		end
		-- Everything any mood touches on this instance: zone values, or back to the saved ones.
		local props = {}
		for _, other in MOODS do
			for prop in other[key] or {} do
				props[prop] = true
			end
		end
		remember(inst, props)
		local goal = {}
		for prop in props do
			local value = mood[key] and mood[key][prop]
			goal[prop] = if value ~= nil then value else saved[inst][prop]
		end
		-- ClockTime wraps at 24, so tween the short way round by snapping at night.
		if goal.ClockTime and math.abs(goal.ClockTime - Lighting.ClockTime) > 12 then
			Lighting.ClockTime = goal.ClockTime
			goal.ClockTime = nil
		end
		TweenService:Create(inst, info, goal):Play()
	end
end

local function zoneAt(position: Vector3, zones: Instance): string
	local best, bestDistance = "Town", math.huge
	for _, zone in zones:GetChildren() do
		local center = zone:GetAttribute("Center")
		local radius = zone:GetAttribute("Radius") or 200
		if typeof(center) == "Vector3" then
			local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			-- The smallest zone you're inside wins (zones sit inside the town's wide circle).
			if distance < radius and radius < bestDistance and zone.Name ~= "Town" then
				best, bestDistance = zone.Name, radius
			end
		end
	end
	return best
end

function ZoneFx.Start()
	Sfx.SetZone("Town")
	task.spawn(lightningLoop)
	game:GetService("RunService").RenderStepped:Connect(petalStep)
	task.spawn(function()
		local zones = ReplicatedStorage:WaitForChild("Zones", 20)
		if zones == nil then
			return -- no map: town music only
		end
		local player = Players.LocalPlayer
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not State.InBattle then
				local zone = zoneAt(root.Position, zones)
				if zone ~= current then
					current = zone
					Sfx.SetZone(zone)
					applyMood(zone)
				end
			end
		end
	end)
end

function ZoneFx.Current(): string
	return current or "Town"
end

return ZoneFx
