--!strict
-- Sets up the world at server start.
-- The real map (terrain, town, the three zones) is built in Studio and saved in the place under
-- workspace.Map; its Markers folder says where things go: Spawn, Sage, Fusion, Wheel, Tower, and per boss Portal_<id>
-- (the portal opening) and Boss_<id> (where the boss stands). This script adds the live parts
-- there: the glowing portal, its sign, the boss NPC with its prompt, Kenji, Hoshi the Fusion Master
-- and the spawn.
-- A place without a Map (e.g. one built with `rojo build`) gets the old small hub made of parts.
-- Either way the live parts go in workspace.Hub, which HubFx animates on the client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Bosses)
local BossModels = require(ReplicatedStorage.Shared.BossModels)
local Meta = require(ReplicatedStorage.Shared.Meta)
local NpcRange = require(script.Parent.NpcRange)

local World = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders point along X; stand them up

-- Where each world's portal stands (north of the altar), facing the centre.
local PORTALS = {
	Vector3.new(-34, 0, -44),
	Vector3.new(0, 0, -56),
	Vector3.new(34, 0, -44),
}

local THEMES = {
	Embers = { Floor = Color3.fromRGB(52, 30, 30), Stone = Color3.fromRGB(44, 30, 34), Glow = Color3.fromRGB(255, 140, 70) },
	Snow = { Floor = Color3.fromRGB(196, 214, 232), Stone = Color3.fromRGB(70, 90, 120), Glow = Color3.fromRGB(150, 230, 255) },
	Motes = { Floor = Color3.fromRGB(24, 16, 36), Stone = Color3.fromRGB(36, 26, 52), Glow = Color3.fromRGB(230, 90, 255) },
	Rain = { Floor = Color3.fromRGB(44, 48, 66), Stone = Color3.fromRGB(56, 60, 82), Glow = Color3.fromRGB(255, 226, 90) },
}

local function sign(parent: BasePart, offset: number, title: string, sub: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = parent
	local top = Instance.new("TextLabel")
	top.Name = "Title"
	top.BackgroundTransparency = 1
	top.Size = UDim2.fromScale(1, 0.58)
	top.Font = Enum.Font.GothamBlack
	top.TextScaled = true
	top.TextColor3 = Color3.new(1, 1, 1)
	top.TextStrokeTransparency = 0.3
	top.Text = title
	top.Parent = gui
	local bottom = Instance.new("TextLabel")
	bottom.Name = "Sub"
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromScale(0, 0.6)
	bottom.Size = UDim2.fromScale(1, 0.4)
	bottom.Font = Enum.Font.GothamMedium
	bottom.TextScaled = true
	bottom.TextColor3 = color
	bottom.TextStrokeTransparency = 0.4
	bottom.Text = sub
	bottom.Parent = gui
end

-- An NPC figure with a prompt. Clients animate figures marked with the Bob attribute.
local function npc(id: string, pivot: CFrame, parent: Instance, action: string, objectText: string): Model
	local model = BossModels.Build(id)
	model:PivotTo(pivot)
	model:SetAttribute("Bob", true)
	model:SetAttribute("BaseCFrame", pivot)
	local root = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- E is the Auto Roll shortcut
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	model.Parent = parent
	NpcRange.Set(id, pivot.Position) -- its services only work beside it
	return model
end

local function buildWorld(hub: Instance, boss: Bosses.Boss, position: Vector3)
	local theme = THEMES[boss.Particles] or THEMES.Embers
	local area = Instance.new("Folder")
	area.Name = `World{boss.World}`
	area.Parent = hub
	local frame = CFrame.lookAt(position, Vector3.new(0, position.Y, 0)) -- -Z faces the altar

	part({
		Name = "Platform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 22, 22),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * FLAT,
		Color = theme.Floor,
		Material = Enum.Material.SmoothPlastic,
		Parent = area,
	})
	part({
		Name = "PlatformRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, 23, 23),
		CFrame = CFrame.new(position + Vector3.new(0, 0.45, 0)) * FLAT,
		Color = boss.Accent,
		Material = Enum.Material.Neon,
		Parent = area,
	})

	-- Gate with a glowing portal behind the boss.
	for _, x in { -6.5, 6.5 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(2, 15, 2),
			CFrame = frame * CFrame.new(x, 8.5, 5),
			Color = theme.Stone,
			Material = Enum.Material.SmoothPlastic,
			Parent = area,
		})
	end
	part({
		Name = "GateBeam",
		Size = Vector3.new(17, 1.6, 2.6),
		CFrame = frame * CFrame.new(0, 16.6, 5),
		Color = theme.Stone,
		Material = Enum.Material.SmoothPlastic,
		Parent = area,
	})
	local beamGlow = part({
		Name = "GateGlow",
		Size = Vector3.new(17.2, 0.4, 2.8),
		CFrame = frame * CFrame.new(0, 15.7, 5),
		Color = boss.Accent,
		Material = Enum.Material.Neon,
		Parent = area,
	})
	part({
		Name = "Portal",
		Size = Vector3.new(11, 14, 0.4),
		CFrame = frame * CFrame.new(0, 8, 5),
		Color = theme.Glow,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		Parent = area,
	})
	sign(beamGlow, 4.5, `WORLD {boss.World} · {string.upper(boss.WorldName)}`, `{boss.Name}, {boss.Title}`, boss.Accent)

	-- Themed props.
	if boss.Particles == "Embers" then
		for i, x in { -9, 9 } do
			part({
				Name = `LanternPost{i}`,
				Size = Vector3.new(0.6, 6, 0.6),
				CFrame = frame * CFrame.new(x, 4, -6),
				Color = theme.Stone,
				Parent = area,
			})
			part({
				Name = `Lantern{i}`,
				Size = Vector3.new(1.4, 1.8, 1.4),
				CFrame = frame * CFrame.new(x, 7.6, -6),
				Color = theme.Glow,
				Material = Enum.Material.Neon,
				Parent = area,
			})
		end
	elseif boss.Particles == "Snow" then
		for i, spot in { Vector3.new(-9, 0, -4), Vector3.new(9, 0, -3), Vector3.new(-8, 0, 7), Vector3.new(8, 0, 7) } do
			local height = 4 + (i % 2) * 3
			part({
				Name = `Crystal{i}`,
				Size = Vector3.new(1.6, height, 1.6),
				CFrame = frame * CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(i * 30), math.rad(12 - i * 6)),
				Color = theme.Glow,
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				Parent = area,
			})
		end
	else
		for i = 1, 6 do
			local angle = (i - 1) / 6 * math.pi * 2
			local cube = part({
				Name = `Shard{i}`,
				Size = Vector3.new(1.2, 1.2, 1.2),
				CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 9, 5 + (i % 3) * 2, math.sin(angle) * 9))
					* CFrame.Angles(math.rad(45), math.rad(i * 20), math.rad(45)),
				Color = theme.Glow,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = area,
			})
			cube:SetAttribute("Spin", true)
		end
	end

	-- Glowing path from the altar.
	local direction = (position - Vector3.new(0, position.Y, 0)).Unit
	for i = 1, 4 do
		local at = direction * (24 + i * 4)
		part({
			Name = "PathTile",
			Size = Vector3.new(3, 0.2, 2),
			CFrame = CFrame.lookAt(Vector3.new(at.X, 0.1, at.Z), Vector3.new(0, 0.1, 0)),
			Color = boss.Accent,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			Parent = area,
		})
	end

	-- The boss, standing guard in front of its portal.
	local height = BossModels.Height(boss.Id)
	local model = npc(boss.Id, frame * CFrame.new(0, 1 + height / 2, -3), area, "Challenge", `{boss.Name}, {boss.Title}`)
	local prompt = (model.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:SetAttribute("BossId", boss.Id)
	end
end

local function spawnAt(hub: Instance, cframe: CFrame)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field bubble
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = cframe
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Parent = hub
end

local function sageAt(hub: Instance, pivot: CFrame)
	local sage = npc("sage", pivot, hub, "Talk", "Kenji, Card Sage")
	local sagePrompt = (sage.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if sagePrompt then
		sagePrompt:SetAttribute("Npc", "sage")
	end
	sign(sage.PrimaryPart :: BasePart, 5, "KENJI", "Card Sage", Color3.fromRGB(255, 214, 120))
end

-- Hoshi the Fusion Master behind a small fusion altar: a stone dais, a glowing ring and two
-- spinning shards (HubFx spins parts marked Spin). `ground` stands on the floor, facing -Z.
local FUSE_ORANGE = Color3.fromRGB(255, 138, 61)
local FUSE_PURPLE = Color3.fromRGB(190, 120, 255)

local function fuserAt(hub: Instance, ground: CFrame)
	local station = Instance.new("Model") -- one piece for streaming
	station.Name = "FusionStation"
	station.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	station.Parent = hub
	local altar = ground * CFrame.new(0, 0, -4.5)
	part({
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 7, 7),
		CFrame = altar * CFrame.new(0, 0.6, 0) * FLAT,
		Color = Color3.fromRGB(58, 48, 74),
		Material = Enum.Material.Slate,
		Parent = station,
	})
	part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 7.4, 7.4),
		CFrame = altar * CFrame.new(0, 1.15, 0) * FLAT,
		Color = FUSE_ORANGE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = station,
	})
	for i, color in { FUSE_ORANGE, FUSE_PURPLE } do
		local shard = part({
			Name = `Shard{i}`,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = altar * CFrame.new(if i == 1 then -1.2 else 1.2, 3.4 + i * 0.6, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = station,
		})
		shard:SetAttribute("Spin", true)
	end
	local light = Instance.new("PointLight")
	light.Color = FUSE_ORANGE
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = station:FindFirstChild("Ring")

	local height = BossModels.Height("fuser")
	local fuser = npc("fuser", ground * CFrame.new(0, height / 2, 0), hub, "Fuse cards", "Hoshi, Fusion Master")
	local prompt = (fuser.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:SetAttribute("Npc", "fuser")
	end
	sign(fuser.PrimaryPart :: BasePart, 6, "HOSHI", "Fusion Master", FUSE_ORANGE)
end

-- Kenshin the Trait Master beside Hoshi: his prompt opens the TRAITS panel (Trait Shards buy traits).
local TRAIT_TEAL = Color3.fromRGB(80, 230, 200)

local function traitMasterAt(hub: Instance, ground: CFrame)
	local height = BossModels.Height("traitmaster")
	local master = npc("traitmaster", ground * CFrame.new(0, height / 2, 0), hub, "Roll traits", "Kenshin, Trait Master")
	local prompt = (master.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:SetAttribute("Npc", "traitmaster")
	end
	sign(master.PrimaryPart :: BasePart, 6, "KENSHIN", "Trait Master", TRAIT_TEAL)
end

-- Madame Fortuna's booth: a big Lucky Wheel on a stand (its spokes in the prize colours, turned slowly
-- by HubFx through the Turn attribute), a gold pointer, and Fortuna beside it; her prompt opens the
-- wheel. `ground` stands on the floor, facing -Z (towards the players).
local WHEEL_GOLD = Color3.fromRGB(255, 210, 70)

local function fortuneAt(hub: Instance, ground: CFrame)
	local booth = Instance.new("Model")
	booth.Name = "FortuneBooth"
	booth.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	booth.Parent = hub
	part({
		Name = "Stage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = ground * CFrame.new(0, 0.5, 1) * FLAT,
		Color = Color3.fromRGB(70, 30, 80),
		Material = Enum.Material.Slate,
		Parent = booth,
	})
	part({ -- a gold band round the stage's edge, under its top
		Name = "StageRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 14.4, 14.4),
		CFrame = ground * CFrame.new(0, 0.8, 1) * FLAT,
		Color = WHEEL_GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = booth,
	})
	local center = ground * CFrame.new(2.5, 8.5, 3)
	for _, x in { -5.3, 5.3 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 8.5, 0.8),
			CFrame = center * CFrame.new(x, -3.6, 0.6),
			Color = Color3.fromRGB(90, 40, 30),
			Material = Enum.Material.Wood,
			Parent = booth,
		})
	end
	local pointer = Instance.new("WedgePart")
	pointer.Name = "Pointer"
	pointer.Anchored = true
	pointer.Size = Vector3.new(0.4, 1.4, 1.2)
	pointer.CFrame = center * CFrame.new(0, 5.6, -0.6) * CFrame.Angles(math.rad(180), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	pointer.Color = WHEEL_GOLD
	pointer.Material = Enum.Material.Neon
	pointer.Parent = booth

	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	local face = center * CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them to face -Z
	local hubPart = part({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 1.6, 1.6),
		CFrame = face,
		Color = WHEEL_GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = wheel,
	})
	part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 10, 10),
		CFrame = face * CFrame.new(0.1, 0, 0),
		Color = Color3.fromRGB(40, 18, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = wheel,
	})
	part({ -- behind the disc, so only a gold ring shows round its edge
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 10.8, 10.8),
		CFrame = face * CFrame.new(-0.05, 0, 0),
		Color = WHEEL_GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = wheel,
	})
	-- One pie slice per prize on the disc's face, each made of two wedges (apex at the hub).
	local prizes = Meta.Wheel.Prizes
	local radius = 4.9
	local halfWidth = radius * math.tan(math.pi / #prizes)
	for i, prize in prizes do
		local angle = (i - 0.5) / #prizes * math.pi * 2
		local out = Vector3.new(-math.sin(angle), math.cos(angle), 0)
		local across = Vector3.new(math.cos(angle), math.sin(angle), 0)
		for _, side in { 1, -1 } do
			local tangent = across * side
			local wedge = Instance.new("WedgePart")
			wedge.Name = `Slice{i}`
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.Size = Vector3.new(0.15, radius, halfWidth)
			local at = out * radius / 2 + tangent * halfWidth / 2 + Vector3.new(0, 0, -0.42)
			wedge.CFrame = center * CFrame.fromMatrix(at, Vector3.new(0, 0, -side), -out, -tangent)
			wedge.Color = prize.Color
			wedge.Material = Enum.Material.SmoothPlastic
			wedge.Parent = wheel
		end
	end
	wheel.PrimaryPart = hubPart
	wheel:SetAttribute("Turn", 0.5) -- radians a second
	wheel.Parent = booth
	local light = Instance.new("PointLight")
	light.Color = WHEEL_GOLD
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = hubPart
	local signAnchor = part({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = center * CFrame.new(0, 6.5, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = booth,
	})
	sign(signAnchor, 2.5, "LUCKY WHEEL", `A free spin every {Meta.Wheel.SpinEvery // 60} min`, WHEEL_GOLD)

	local height = BossModels.Height("fortune")
	local fortune = npc("fortune", ground * CFrame.new(-4, 1 + height / 2, -1), hub, "Spin the wheel", "Madame Fortuna")
	local prompt = (fortune.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:SetAttribute("Npc", "wheel")
	end
end

-- The Infinite Tower's gate: a slim stone spire of four tiers that turn a little each step, neon bands
-- between them, a crystal spinning at the top (HubFx spins parts marked Spin) and a glowing doorway
-- whose prompt opens the tower screen. LeaderboardService hangs the highest-floor board on the
-- BoardSpot beside it. `ground` stands on the floor, facing -Z (towards the players).
local TOWER_TEAL = Color3.fromRGB(90, 230, 220)
local TOWER_STONE = Color3.fromRGB(52, 46, 78)

local function towerAt(hub: Instance, ground: CFrame)
	local gate = Instance.new("Model")
	gate.Name = "TowerGate"
	gate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	gate.Parent = hub
	part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 15, 15),
		CFrame = ground * CFrame.new(0, 0.5, 3) * FLAT,
		Color = Color3.fromRGB(70, 64, 92),
		Material = Enum.Material.Slate,
		Parent = gate,
	})
	part({
		Name = "BaseRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 15.4, 15.4),
		CFrame = ground * CFrame.new(0, 0.8, 3) * FLAT,
		Color = TOWER_TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = gate,
	})
	local y = 1
	local tiers = { { 10, 9 }, { 8.4, 8 }, { 6.8, 7 }, { 5.2, 6 } } -- width, height
	for i, tier in tiers do
		local width, height = tier[1], tier[2]
		local turn = CFrame.Angles(0, math.rad((i - 1) * 12), 0) -- the bottom tier sits square behind the door
		part({
			Name = `Tier{i}`,
			Size = Vector3.new(width, height, width),
			CFrame = ground * CFrame.new(0, y + height / 2, 3) * turn,
			Color = TOWER_STONE,
			Material = Enum.Material.Slate,
			Parent = gate,
		})
		y += height
		part({
			Name = `Band{i}`,
			Size = Vector3.new(width + 0.6, 0.5, width + 0.6),
			CFrame = ground * CFrame.new(0, y - 0.25, 3) * turn,
			Color = TOWER_TEAL,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = gate,
		})
	end
	local crystal = part({
		Name = "Crystal",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = ground * CFrame.new(0, y + 3, 3) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = TOWER_TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = gate,
	})
	crystal:SetAttribute("Spin", true)
	local door = part({
		Name = "Door",
		Size = Vector3.new(4.4, 6.5, 0.3),
		CFrame = ground * CFrame.new(0, 1 + 3.25, 3 - 5.05),
		Color = TOWER_TEAL,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = gate,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Climb the tower"
	prompt.ObjectText = "Infinite Tower"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Npc", "tower")
	prompt.Parent = door
	local signAnchor = part({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = ground * CFrame.new(0, y + 6, 3),
		Transparency = 1,
		CanCollide = false,
		Parent = gate,
	})
	sign(signAnchor, 2, "INFINITE TOWER", "Endless floors · rare artifacts", TOWER_TEAL)
	part({
		Name = "BoardSpot",
		Size = Vector3.new(1, 1, 1),
		CFrame = ground * CFrame.new(14, 0, 2) * CFrame.Angles(0, math.rad(-20), 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = gate,
	})
end

-- Rising sparks and embers from `source` (its whole volume): small, bright, slow, few.
local function embers(source: BasePart, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Embers"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 90, 40))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 1.2, 0)
	emitter.Drag = 0.4
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = source
	return emitter
end

-- Town at night: a warm light inside the street lanterns (the nearest MAX_LANTERN_LIGHTS to the plaza,
-- no shadows, so phones stay smooth) and embers rising from the fountain.
local MAX_LANTERN_LIGHTS = 24
local LANTERN_COLOR = Color3.fromRGB(255, 150, 60)

local function townLights(town: Instance)
	local fountain = town:FindFirstChild("Fountain")
	local center = if fountain and fountain:IsA("Model") then fountain:GetPivot().Position else Vector3.zero
	local lanterns = {}
	for _, child in town:GetChildren() do
		if child:IsA("Model") and child.Name:match("^Lantern") then
			table.insert(lanterns, { Model = child, Distance = (child:GetPivot().Position - center).Magnitude })
		end
	end
	table.sort(lanterns, function(a, b)
		return a.Distance < b.Distance
	end)
	for i = 1, math.min(#lanterns, MAX_LANTERN_LIGHTS) do
		local model = lanterns[i].Model
		local cf, size = model:GetBoundingBox()
		local glow = part({
			Name = "LanternGlow",
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.2, 0)),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		glow.CanQuery = false
		glow.CanTouch = false
		glow.CastShadow = false
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 14
		light.Color = LANTERN_COLOR
		light.Shadows = false
		light.Parent = glow
	end
	if fountain and fountain:IsA("Model") then
		local cf, size = fountain:GetBoundingBox()
		local source = part({
			Name = "FountainEmbers",
			Size = Vector3.new(size.X * 0.7, 0.4, size.Z * 0.7),
			CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)),
			Transparency = 1,
			CanCollide = false,
			Parent = fountain,
		})
		source.CanQuery = false
		source.CanTouch = false
		embers(source, LANTERN_COLOR, 7)
	end
end

-- The live parts of one world at the map's markers: a glowing portal filling the gate's opening,
-- the world sign above it, and the boss standing guard.
local function mapWorld(hub: Instance, boss: Bosses.Boss, portalMarker: BasePart, bossMarker: BasePart)
	local theme = THEMES[boss.Particles] or THEMES.Embers
	local area = Instance.new("Model") -- a Model so streaming sends it as one piece
	area.Name = `World{boss.World}`
	area.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	area.Parent = hub
	local portal = part({
		Name = "Portal",
		Size = portalMarker.Size,
		CFrame = portalMarker.CFrame,
		Color = theme.Glow,
		Material = Enum.Material.Neon,
		Transparency = 0.55, -- a glowing veil you can see the gate through
		CanCollide = false,
		Parent = area,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(theme.Glow, boss.Accent)
	swirl.LightEmission = 1
	swirl.Rate = 8
	swirl.Lifetime = NumberRange.new(1.5, 2.5)
	swirl.Speed = NumberRange.new(1, 3)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	swirl.Parent = portal
	embers(portal, theme.Glow, 5)
	-- HubFx finds the sign on the part named GateGlow. A SignLift attribute on the marker raises it
	-- (for gates with a tall lintel over the opening).
	local lift = portalMarker:GetAttribute("SignLift")
	local glow = part({
		Name = "GateGlow",
		Size = Vector3.new(1, 1, 1),
		CFrame = portalMarker.CFrame * CFrame.new(0, portalMarker.Size.Y / 2 + 2 + (if type(lift) == "number" then lift else 0), 0),
		Transparency = 1,
		CanCollide = false,
		Parent = area,
	})
	sign(glow, 5, `WORLD {boss.World} · {string.upper(boss.WorldName)}`, `{boss.Name}, {boss.Title}`, boss.Accent)

	local height = BossModels.Height(boss.Id)
	local stand = bossMarker.CFrame
	local model = npc(boss.Id, stand * CFrame.new(0, height / 2, 0), area, "Challenge", `{boss.Name}, {boss.Title}`)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local prompt = (model.PrimaryPart :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:SetAttribute("BossId", boss.Id)
	end
end

local function buildFromMap(map: Instance, markers: Instance)
	local town = map:FindFirstChild("Town")
	if town then
		townLights(town)
	end
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	for _, boss in Bosses.List do
		local portalMarker = markers:FindFirstChild(`Portal_{boss.Id}`)
		local bossMarker = markers:FindFirstChild(`Boss_{boss.Id}`)
		if portalMarker and portalMarker:IsA("BasePart") and bossMarker and bossMarker:IsA("BasePart") then
			mapWorld(hub, boss, portalMarker, bossMarker)
		else
			warn(`[World] Map has no Portal_{boss.Id} / Boss_{boss.Id} marker`)
		end
	end
	local sage = markers:FindFirstChild("Sage")
	if sage and sage:IsA("BasePart") then
		local sageHeight = BossModels.Height("sage")
		sageAt(hub, sage.CFrame * CFrame.new(0, sageHeight / 2, 0))
	end
	local fusion = markers:FindFirstChild("Fusion")
	if fusion and fusion:IsA("BasePart") then
		fuserAt(hub, fusion.CFrame)
		-- Kenshin stands at a TraitMaster marker, else 12 studs to Hoshi's right.
		local traitMarker = markers:FindFirstChild("TraitMaster")
		traitMasterAt(hub, if traitMarker and traitMarker:IsA("BasePart") then traitMarker.CFrame else fusion.CFrame * CFrame.new(12, 0, 0))
	else
		warn("[World] Map has no Fusion marker (the Fusion Master stands there)")
	end
	local spawn = markers:FindFirstChild("Spawn")
	local spawnCFrame = if spawn and spawn:IsA("BasePart") then spawn.CFrame else CFrame.new(0, 5, 0)
	spawnAt(hub, spawnCFrame)
	-- Madame Fortuna stands at the Wheel marker; without one, a short walk to the spawn's left,
	-- facing it (move her by adding a Wheel marker in Studio).
	local wheelMarker = markers:FindFirstChild("Wheel")
	if wheelMarker and wheelMarker:IsA("BasePart") then
		fortuneAt(hub, wheelMarker.CFrame)
	else
		local spot = spawnCFrame * CFrame.new(-20, -0.5, -6)
		fortuneAt(hub, CFrame.lookAt(spot.Position, Vector3.new(spawnCFrame.X, spot.Y, spawnCFrame.Z)))
	end
	-- The Infinite Tower's gate at the Tower marker; without one, mirrored to the spawn's right.
	local towerMarker = markers:FindFirstChild("Tower")
	if towerMarker and towerMarker:IsA("BasePart") then
		towerAt(hub, towerMarker.CFrame)
	else
		local spot = spawnCFrame * CFrame.new(24, -0.5, -6)
		towerAt(hub, CFrame.lookAt(spot.Position, Vector3.new(spawnCFrame.X, spot.Y, spawnCFrame.Z)))
	end
	hub.Parent = workspace

	-- Zone circles for ZoneFx (music and lighting per zone). Published to ReplicatedStorage because
	-- with streaming on, a client doesn't have the marker parts of zones far away.
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	for _, marker in markers:GetChildren() do
		local name = marker.Name:match("^Zone_(.+)$")
		if name and marker:IsA("BasePart") then
			local zone = Instance.new("Configuration")
			zone.Name = name
			zone:SetAttribute("Center", marker.Position)
			zone:SetAttribute("Radius", marker:GetAttribute("Radius") or 200)
			zone.Parent = zones
		end
	end
	zones.Parent = ReplicatedStorage
	-- Lighting, sky and terrain colours are saved with the map; zones re-tint them on the client.
end

function World.Build()
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	if map and markers then
		buildFromMap(map, markers)
		return
	end

	local hub = Instance.new("Folder")
	hub.Name = "Hub"

	part({
		Name = "Ground",
		Size = Vector3.new(400, 2, 400),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(26, 24, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = hub,
	})

	-- Round altar the player spawns on.
	part({
		Name = "Altar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 44, 44),
		CFrame = CFrame.new(0, 0.6, 0) * FLAT,
		Color = Color3.fromRGB(40, 36, 64),
		Material = Enum.Material.SmoothPlastic,
		Parent = hub,
	})
	part({
		Name = "AltarRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 46, 46),
		CFrame = CFrame.new(0, 0.55, 0) * FLAT,
		Color = Color3.fromRGB(176, 92, 255),
		Material = Enum.Material.Neon,
		Parent = hub,
	})

	-- Six glowing pillars, one per rarity colour above Common.
	local pillarColors = {
		Color3.fromRGB(86, 214, 138),
		Color3.fromRGB(64, 156, 255),
		Color3.fromRGB(176, 92, 255),
		Color3.fromRGB(255, 196, 46),
		Color3.fromRGB(255, 58, 92),
		Color3.fromRGB(240, 236, 255),
	}
	for i, color in pillarColors do
		local angle = math.rad((i - 1) * 60)
		local position = Vector3.new(math.cos(angle) * 30, 6, math.sin(angle) * 30)
		part({
			Name = `Pillar{i}`,
			Size = Vector3.new(2.4, 12, 2.4),
			CFrame = CFrame.new(position),
			Color = Color3.fromRGB(34, 30, 54),
			Material = Enum.Material.SmoothPlastic,
			Parent = hub,
		})
		part({
			Name = `PillarGlow{i}`,
			Size = Vector3.new(2.6, 0.6, 2.6),
			CFrame = CFrame.new(position + Vector3.new(0, 6.3, 0)),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = hub,
		})
	end

	for i, boss in Bosses.List do
		local position = PORTALS[i] or Vector3.new(-34 + (i - 1) * 34, 0, -56 - (i - 3) * 14)
		buildWorld(hub, boss, position)
	end

	-- The Card Sage: a friendly NPC on the altar who gives tips.
	local sageHeight = BossModels.Height("sage")
	sageAt(hub, CFrame.lookAt(Vector3.new(11, 1.2 + sageHeight / 2, 8), Vector3.new(0, 1.2 + sageHeight / 2, 0)))
	fuserAt(hub, CFrame.lookAt(Vector3.new(-14, 1.2, 8), Vector3.new(0, 1.2, 0)))
	traitMasterAt(hub, CFrame.lookAt(Vector3.new(-22, 1.2, 14), Vector3.new(0, 1.2, 0)))
	fortuneAt(hub, CFrame.lookAt(Vector3.new(0, 1.2, 20), Vector3.new(0, 1.2, 0)))
	towerAt(hub, CFrame.lookAt(Vector3.new(30, 1.2, 18), Vector3.new(0, 1.2, 0)))
	spawnAt(hub, CFrame.new(0, 1.4, 0))

	hub.Parent = workspace

	-- Evening sky, soft fog.
	Lighting.ClockTime = 18.2
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 60, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 96, 150)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(150, 120, 200)
	atmosphere.Decay = Color3.fromRGB(60, 40, 90)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

return World
