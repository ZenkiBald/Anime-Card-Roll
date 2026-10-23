-- Builds workspace.Map from ServerStorage.MapKit on top of the generated terrain. Re-running replaces
-- the Map folder. Args: { Part = "terrain" | "town" | "ember" | "frost" | "abyss" | "storm" | "markers" | "all" }
local args = ... or {}
local which = args.Part or "all"
local kit = game.ServerStorage.MapKit
local T = workspace.Terrain
local rng = Random.new(args.Seed or 7)

local TOWN = Vector3.new(0, 0, 0)
local EMBER = Vector3.new(-430, 0, 150)
local FROST = Vector3.new(30, 0, -500)
local ABYSS = Vector3.new(450, 0, 170)
local LAKE = Vector3.new(-60, 0, 290)
local STORM = Vector3.new(-50, 0, 545)
local ROADS = {
	{ Vector2.new(-20, 30), Vector2.new(-160, 90), Vector2.new(-300, 120), Vector2.new(-400, 150) },
	{ Vector2.new(0, -40), Vector2.new(20, -180), Vector2.new(0, -290), Vector2.new(30, -400) },
	{ Vector2.new(30, 20), Vector2.new(170, 60), Vector2.new(320, 140), Vector2.new(410, 165) },
	{ Vector2.new(-60, 398), Vector2.new(-57, 440), Vector2.new(-52, 490), Vector2.new(-50, 585) },
}

local map = workspace:FindFirstChild("Map")
if not map then
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
end
local function folder(name)
	local f = map:FindFirstChild(name)
	if f and args.Rebuild ~= false then
		f:Destroy()
		f = nil
	end
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
	end
	return f
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { T }
local function groundY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	return if hit then hit.Position.Y else 0, hit
end
local function isWater(x, z)
	local _, hit = groundY(x, z)
	return hit and hit.Material == Enum.Material.Water
end
local function roadDist(x, z)
	local p = Vector2.new(x, z)
	local best = math.huge
	for _, line in ROADS do
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			best = math.min(best, (p - (a + ab * t)).Magnitude)
		end
	end
	return best
end

-- Clones a kit model, scales it, turns it to `yaw` degrees (or to face `face`) and sets it on the ground.
local function place(name, x, z, opts, parent)
	opts = opts or {}
	local template = kit:FindFirstChild(name)
	if not template then
		warn("no kit model " .. name)
		return nil
	end
	local m = template:Clone()
	if opts.Scale and opts.Scale ~= 1 then
		m:ScaleTo(m:GetScale() * opts.Scale)
	end
	local yaw = opts.Yaw or rng:NextNumber(0, 360)
	if opts.Face then
		local d = Vector3.new(opts.Face.X - x, 0, opts.Face.Z - z)
		yaw = math.deg(math.atan2(-d.X, -d.Z)) + (opts.YawOffset or 0)
	end
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw), 0) * m:GetPivot().Rotation)
	local cf, size = m:GetBoundingBox()
	local y = opts.Y or groundY(x, z)
	local bottom = cf.Position.Y - size.Y / 2
	m:PivotTo(m:GetPivot() + Vector3.new(x - cf.Position.X, y - bottom - (opts.Sink or 0.4) + (opts.Lift or 0), z - cf.Position.Z))
	if opts.Color then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = opts.Color
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			elseif d:IsA("SurfaceAppearance") or d:IsA("Texture") or d:IsA("Decal") then
				d:Destroy()
			end
		end
	end
	if opts.Neon then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Material = Enum.Material.Neon
			end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if opts.NoCollide then
				d.CanCollide = false
			end
		end
	end
	m.Parent = parent
	return m
end

local function marker(parent, name, cframe, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size or Vector3.new(4, 4, 4)
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function sign(parent, text, sub, color, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 80)
	gui.StudsOffset = Vector3.new(0, offset or 6, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.6)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = text
	t.Parent = gui
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(30, 10, 60)
	st.Thickness = 3
	st.Parent = t
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Position = UDim2.fromScale(0, 0.6)
	s.Size = UDim2.fromScale(1, 0.4)
	s.Font = Enum.Font.FredokaOne
	s.TextScaled = true
	s.TextColor3 = color
	s.Text = sub
	s.Parent = gui
	local st2 = st:Clone()
	st2.Thickness = 2
	st2.Parent = s
end

-- A spot on a ring around `center`, at `deg` degrees (0 = +X, 90 = +Z).
local function ring(center, radius, deg)
	local a = math.rad(deg)
	return center.X + math.cos(a) * radius, center.Z + math.sin(a) * radius
end

-- Scatter `count` models in a ring band, away from roads, water and `avoid` circles.
local function scatter(parent, names, count, center, rMin, rMax, opts, avoid)
	local placed, tries = 0, 0
	while placed < count and tries < count * 30 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber((rMin / rMax) ^ 2, 1)) * rMax
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local ok = roadDist(x, z) > (opts.RoadGap or 18) and not isWater(x, z) and math.abs(x) < 640 and math.abs(z) < 640
		if ok and avoid then
			for _, c in avoid do
				if (Vector2.new(x, z) - Vector2.new(c[1].X, c[1].Z)).Magnitude < c[2] then
					ok = false
					break
				end
			end
		end
		if ok then
			local o = table.clone(opts)
			o.Scale = (opts.Scale or 1) * rng:NextNumber(opts.MinScale or 0.85, opts.MaxScale or 1.15)
			place(names[rng:NextInteger(1, #names)], x, z, o, parent)
			placed += 1
			if placed % 8 == 0 then
				task.wait()
			end
		end
	end
	return placed
end

local log = {}

if which == "terrain" or which == "all" then
	-- Island in the lake for the big bridge, and a koi pond in Ember Village.
	T:FillCylinder(CFrame.new(LAKE.X, -6, LAKE.Z + 4), 12, 22, Enum.Material.Sand)
	T:FillCylinder(CFrame.new(LAKE.X, -2, LAKE.Z + 4), 6, 18, Enum.Material.Grass)
	local pond = Vector3.new(-372, 0, 214)
	local py = groundY(pond.X, pond.Z)
	T:FillCylinder(CFrame.new(pond.X, py - 3, pond.Z), 8, 15, Enum.Material.Air)
	T:FillCylinder(CFrame.new(pond.X, py - 5, pond.Z), 4, 15, Enum.Material.Water)
	T:FillCylinder(CFrame.new(pond.X, py - 7.5, pond.Z), 1, 17, Enum.Material.Mud)
	table.insert(log, "terrain extras done")
end

if which == "town" or which == "all" then
	local town = folder("Town")
	local g = groundY(0, 0)
	place("Fountain", 0, 0, { Scale = 1.4, Yaw = 0 }, town)
	local houses = { { "HouseTiled", 50 }, { "HouseShoji", 128 }, { "HouseRed", 205 }, { "HouseTiled", 238 }, { "HouseShoji", 310 }, { "HouseRed", 342 } }
	for _, h in houses do
		local x, z = ring(TOWN, 86, h[2])
		place(h[1], x, z, { Face = TOWN, Sink = 0.2 }, town)
	end
	for _, deg in { 30, 70, 110, 146, 182, 222, 256, 296, 326, 358 } do
		local x, z = ring(TOWN, 62, deg)
		place(if deg % 3 == 0 then "SakuraBig" else "Sakura", x, z, { Scale = 0.32 }, town)
	end
	for deg = 0, 359, 30 do
		local near = false
		for _, road in { 18, 158, 276 } do
			if math.abs((deg - road + 180) % 360 - 180) < 14 then
				near = true
			end
		end
		if not near then
			local x, z = ring(TOWN, 50, deg)
			place("LanternStone", x, z, { Scale = 2.2, Face = TOWN }, town)
		end
	end
	-- Gates where the roads leave town, with a sign for the zone.
	local gates = {
		{ 158, "EMBER VILLAGE", "World 1  ·  Kurogane", Color3.fromRGB(255, 150, 80) },
		{ 276, "FROSTFANG PEAKS", "World 2  ·  Rimeveil", Color3.fromRGB(150, 220, 255) },
		{ 18, "NEON ABYSS", "World 3  ·  Vex", Color3.fromRGB(230, 110, 255) },
	}
	for _, gate in gates do
		local x, z = ring(TOWN, 70, gate[1])
		local torii = place("ToriiRed", x, z, { Scale = 1.5, Face = TOWN, Sink = 0.3 }, town)
		if torii then
			local cf, size = torii:GetBoundingBox()
			local anchor = marker(torii, "SignAnchor", CFrame.new(cf.Position + Vector3.new(0, size.Y / 2, 0)))
			sign(anchor, gate[2], gate[3], gate[4], 4)
		end
	end
	-- Lake island and bridge.
	place("SakuraBig", LAKE.X, LAKE.Z + 4, { Scale = 0.45 }, town)
	place("LanternStone", LAKE.X + 8, LAKE.Z - 6, { Scale = 2 }, town)
	place("BridgeBig", LAKE.X, LAKE.Z - 70, { Yaw = 0, Y = -7 }, town)
	local avoidZones = { { LAKE, 135 }, { EMBER, 230 }, { FROST, 300 }, { ABYSS, 270 }, { STORM, 200 } }
	local trees = scatter(town, { "TreeGreen" }, 36, TOWN, 125, 430, { Scale = 0.55, RoadGap = 20 }, avoidZones)
		+ scatter(town, { "TreeBlob" }, 36, TOWN, 110, 430, { Scale = 1.4, RoadGap = 16 }, avoidZones)
	local bushes = scatter(town, { "BushPink", "BushFlower" }, 40, TOWN, 58, 200, { Scale = 1.4, RoadGap = 12 }, { { LAKE, 120 } })
	-- Lanterns along the roads.
	local lamps = 0
	for _, line in ROADS do
		for i = 1, #line - 1 do
			local a, b = line[i], line[i + 1]
			local len = (b - a).Magnitude
			local dir = (b - a).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			for s = 20, len, 44 do
				local p = a + dir * s + side * (if (s // 44) % 2 == 0 then 13 else -13)
				if (Vector2.new(p.X, p.Y)).Magnitude > 75 then
					place("LanternPaper", p.X, p.Y, { Scale = 1.7 }, town)
					lamps += 1
				end
			end
		end
	end
	table.insert(log, `town: {trees} trees, {bushes} bushes, {lamps} road lanterns`)
end

local markers = map:FindFirstChild("Markers")
if not markers then
	markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = map
end
local function setMarker(name, cframe, size)
	local old = markers:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return marker(markers, name, cframe, size)
end

-- A portal spot: the gate art stands at `pos` facing the town; returns the opening's CFrame.
local function portalFrame(pos, facing)
	local y = groundY(pos.X, pos.Z)
	return CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(facing.X, y, facing.Z))
end

if which == "ember" or which == "all" then
	local ember = folder("EmberVillage")
	local square = Vector3.new(-410, 0, 150)
	local houses = { { "HouseRed", 20 }, { "HouseShoji", 118 }, { "HouseRed", 160 }, { "HouseRed", 215 }, { "HouseShoji", 250 }, { "HouseRed", 300 } }
	for _, h in houses do
		local x, z = ring(square, 64, h[2])
		if roadDist(x, z) > 16 then
			place(h[1], x, z, { Face = square, Sink = 0.3 }, ember)
		end
	end
	for deg = 0, 359, 40 do
		local x, z = ring(square, 34, deg)
		place("LanternStone", x, z, { Scale = 2, Face = square }, ember)
	end
	local maples = scatter(ember, { "MapleRed" }, 48, EMBER, 70, 215, { Scale = 0.5, RoadGap = 14 }, { { square, 92 }, { Vector3.new(-372, 0, 214), 22 } })
	scatter(ember, { "LanternPaper" }, 14, square, 40, 110, { Scale = 1.7, RoadGap = 6 })
	place("BridgeKoi", -372, 214, { Yaw = 30, Sink = 2.2 }, ember)
	-- Portal: a stone torii at the far side of the square, the boss in front.
	local frame = portalFrame(Vector3.new(-505, 0, 140), square)
	local gate = place("ToriiStone", frame.Position.X, frame.Position.Z, { Scale = 1.7, Face = square, Sink = 0.3 }, ember)
	local cf, size = gate:GetBoundingBox()
	setMarker("Portal_kurogane", frame * CFrame.new(0, size.Y * 0.42, 0), Vector3.new(size.X * 0.62, size.Y * 0.78, 0.6))
	setMarker("Boss_kurogane", frame * CFrame.new(0, 0, -16))
	setMarker("Zone_EmberVillage", CFrame.new(EMBER.X, groundY(EMBER.X, EMBER.Z), EMBER.Z), Vector3.new(4, 4, 4)):SetAttribute("Radius", 230)
	table.insert(log, `ember: {maples} maples`)
end

if which == "frost" or which == "all" then
	local frost = folder("FrostfangPeaks")
	local pines = scatter(frost, { "PineStylized", "PineStylized", "PineSnow" }, 44, FROST, 40, 330, { Scale = 0.75, RoadGap = 14 })
	local ice = scatter(frost, { "IceCluster" }, 14, FROST, 30, 180, { Scale = 3.2, RoadGap = 14, MinScale = 0.7, MaxScale = 1.5 })
	scatter(frost, { "Rock" }, 18, FROST, 40, 260, { Scale = 3, Color = Color3.fromRGB(150, 170, 200), RoadGap = 10 })
	local frame = portalFrame(Vector3.new(30, 0, -590), Vector3.new(30, 0, -400))
	local gate = place("PortalArch", frame.Position.X, frame.Position.Z, { Scale = 2.6, Face = Vector3.new(30, 0, -400), Sink = 0.5 }, frost)
	local cf, size = gate:GetBoundingBox()
	setMarker("Portal_rimeveil", frame * CFrame.new(0, size.Y * 0.36, 0), Vector3.new(size.X * 0.5, size.Y * 0.66, 0.6))
	setMarker("Boss_rimeveil", frame * CFrame.new(0, 0, -18))
	for _, side in { -1, 1 } do
		local p = frame * CFrame.new(side * 22, 0, -4)
		place("IceCluster", p.X, p.Z, { Scale = 5 }, frost)
	end
	setMarker("Zone_FrostfangPeaks", CFrame.new(FROST.X, groundY(FROST.X, FROST.Z), FROST.Z)):SetAttribute("Radius", 260)
	table.insert(log, `frost: {pines} pines, {ice} ice`)
end

if which == "abyss" or which == "all" then
	local abyss = folder("NeonAbyss")
	local violet = Color3.fromRGB(190, 70, 255)
	local crystals = scatter(abyss, { "CrystalViolet" }, 16, ABYSS, 30, 190, { Scale = 0.9, MinScale = 0.6, MaxScale = 1.6, RoadGap = 12 })
	scatter(abyss, { "CrystalSmall" }, 24, ABYSS, 20, 200, { Scale = 3, Color = violet, Neon = true, RoadGap = 10 })
	scatter(abyss, { "DeadTree" }, 12, ABYSS, 60, 230, { Scale = 0.32, Color = Color3.fromRGB(46, 30, 66), RoadGap = 14 })
	scatter(abyss, { "Rock" }, 16, ABYSS, 40, 230, { Scale = 3.5, Color = Color3.fromRGB(40, 30, 60), RoadGap = 10 })
	-- Floating relics drifting over the basin (HubFx spins parts marked Spin).
	for i = 1, 6 do
		local x, z = ring(ABYSS, rng:NextNumber(50, 150), i * 60 + rng:NextNumber(-20, 20))
		local m = place("AbyssIsland", x, z, { Scale = rng:NextNumber(0.8, 1.6), Lift = rng:NextNumber(26, 60), NoCollide = true }, abyss)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d:SetAttribute("Spin", true)
				end
			end
		end
	end
	-- Portal: a ring of violet crystals with a relic floating above the opening.
	local frame = portalFrame(Vector3.new(520, 0, 200), Vector3.new(410, 0, 165))
	for _, side in { -1, 1 } do
		local p = frame * CFrame.new(side * 11, 0, 0)
		place("CrystalViolet", p.X, p.Z, { Scale = 1.6, Face = frame.Position, Sink = 1 }, abyss)
	end
	local top = frame * CFrame.new(0, 0, 0)
	local relic = place("AbyssIsland", top.X, top.Z, { Scale = 1.1, Lift = 30, NoCollide = true }, abyss)
	setMarker("Portal_vex", frame * CFrame.new(0, 12, 0), Vector3.new(12, 22, 0.6))
	setMarker("Boss_vex", frame * CFrame.new(0, 0, -16))
	-- A few violet lights (kept low: lights cost on phones).
	local lit = 0
	for _, m in abyss:GetChildren() do
		if m.Name == "CrystalViolet" and lit < 6 then
			local light = Instance.new("PointLight")
			light.Color = violet
			light.Range = 28
			light.Brightness = 2
			light.Parent = m:FindFirstChildWhichIsA("BasePart", true)
			lit += 1
		end
	end
	setMarker("Zone_NeonAbyss", CFrame.new(ABYSS.X, groundY(ABYSS.X, ABYSS.Z), ABYSS.Z)):SetAttribute("Radius", 250)
	table.insert(log, `abyss: {crystals} crystals`)
end

if which == "storm" or which == "all" then
	local storm = folder("StormspireIsle")
	local stone = Color3.fromRGB(66, 72, 98)
	local volt = Color3.fromRGB(255, 226, 90)
	-- Town trees that stood where the plateau and its road now are.
	local town = map:FindFirstChild("Town")
	local removed = 0
	if town then
		for _, m in town:GetChildren() do
			if m:IsA("Model") and (m.Name == "TreeGreen" or m.Name == "TreeBlob") then
				local p = m:GetPivot().Position
				if (Vector2.new(p.X, p.Z) - Vector2.new(STORM.X, STORM.Z)).Magnitude < 200 or roadDist(p.X, p.Z) < 20 then
					m:Destroy()
					removed += 1
				end
			end
		end
	end
	-- A second bridge from the lake island to the south shore, where the Stormspire road starts.
	place("BridgeBig", LAKE.X, LAKE.Z + 67, { Yaw = 180, Y = -7 }, storm)
	local trees = scatter(storm, { "DeadTree" }, 9, STORM, 30, 110, { Scale = 0.28, Color = Color3.fromRGB(46, 50, 68), RoadGap = 14 })
	scatter(storm, { "Rock" }, 24, STORM, 15, 120, { Scale = 3.6, Color = stone, RoadGap = 10 })
	local crystals = scatter(storm, { "CrystalSmall" }, 20, STORM, 20, 115, { Scale = 3, Color = volt, Neon = true, RoadGap = 10 })
	scatter(storm, { "LanternStone" }, 8, STORM, 20, 90, { Scale = 2.2, Color = stone, RoadGap = 6 })
	-- Storm clouds hanging over the isle (plain balls: no collision, no shadow).
	local clouds = Instance.new("Model")
	clouds.Name = "Clouds"
	clouds.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for i = 1, 10 do
		local x, z = ring(STORM, rng:NextNumber(0, 150), i * 36 + rng:NextNumber(-15, 15))
		local size = rng:NextNumber(60, 110)
		local cloud = Instance.new("Part")
		cloud.Name = "Cloud"
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(size, size, size)
		cloud.CFrame = CFrame.new(x, 150 + rng:NextNumber(0, 40), z)
		cloud.Color = Color3.fromRGB(58, 62, 84)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CanTouch = false
		cloud.CastShadow = false
		cloud.Parent = clouds
	end
	clouds.Parent = storm
	-- Portal: two storm-stone pillars banded with light under a glowing lintel, the boss in front.
	local frame = portalFrame(Vector3.new(-50, 0, 612), Vector3.new(-50, 0, 450))
	local gate = Instance.new("Model")
	gate.Name = "StormGate"
	gate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local function block(name, size, cf, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Parent = gate
		return p
	end
	-- Tall enough that the world sign (World.luau hangs it just above the opening) shows under the lintel.
	for _, side in { -1, 1 } do
		block("Pillar", Vector3.new(6, 42, 6), frame * CFrame.new(side * 10, 20, 0), stone, Enum.Material.Slate)
		for k = 1, 4 do
			block("Band", Vector3.new(6.4, 0.8, 6.4), frame * CFrame.new(side * 10, k * 8, 0), volt, Enum.Material.Neon)
		end
		block("Cap", Vector3.new(8, 3, 8), frame * CFrame.new(side * 10, 42, 0) * CFrame.Angles(0, math.rad(45), 0), stone, Enum.Material.Slate)
	end
	block("Lintel", Vector3.new(30, 4, 5), frame * CFrame.new(0, 40, 0), stone, Enum.Material.Slate)
	block("LintelGlow", Vector3.new(28, 1, 5.4), frame * CFrame.new(0, 37.5, 0), volt, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = volt
	light.Range = 40
	light.Brightness = 2
	light.Parent = gate:FindFirstChild("LintelGlow")
	gate.Parent = storm
	setMarker("Portal_tenrai", frame * CFrame.new(0, 13, 0), Vector3.new(13, 24, 0.6)):SetAttribute("SignLift", 22) -- sign over the lintel and caps
	setMarker("Boss_tenrai", frame * CFrame.new(0, 0, -16))
	-- A few lights in the crystals (kept low: lights cost on phones).
	local lit = 0
	for _, m in storm:GetChildren() do
		if m.Name == "CrystalSmall" and lit < 4 then
			local glow = Instance.new("PointLight")
			glow.Color = volt
			glow.Range = 22
			glow.Brightness = 1.5
			glow.Parent = m:FindFirstChildWhichIsA("BasePart", true)
			lit += 1
		end
	end
	setMarker("Zone_StormspireIsle", CFrame.new(STORM.X, groundY(STORM.X, STORM.Z), STORM.Z)):SetAttribute("Radius", 200)
	-- A gate out of town towards the lake bridges, with the zone's sign (replaced on a re-run).
	if town then
		local old = town:FindFirstChild("ToriiStorm")
		if old then
			old:Destroy()
		end
		local x, z = ring(TOWN, 70, 104)
		local torii = place("ToriiRed", x, z, { Scale = 1.5, Face = TOWN, Sink = 0.3 }, town)
		if torii then
			torii.Name = "ToriiStorm"
			local cf, size = torii:GetBoundingBox()
			local anchor = marker(torii, "SignAnchor", CFrame.new(cf.Position + Vector3.new(0, size.Y / 2, 0)))
			sign(anchor, "STORMSPIRE ISLE", "World 4  ·  Tenrai", volt, 4)
		end
	end
	table.insert(log, `storm: removed {removed} town trees, {trees} dead trees, {crystals} crystals`)
end

if which == "markers" or which == "all" or which == "town" then
	-- Southwest of the fountain, facing it: the camera behind stays clear of the south food stall.
	local g = groundY(-17, 22)
	setMarker("Spawn", CFrame.lookAt(Vector3.new(-17, g + 0.5, 22), Vector3.new(0, g + 0.5, 0)), Vector3.new(8, 1, 8))
	local sg = groundY(18, 20)
	setMarker("Sage", CFrame.lookAt(Vector3.new(18, sg, 20), Vector3.new(0, sg, 30)))
	-- Hoshi the Fusion Master: east side of the plaza, between the stall and Kenji, facing the fountain.
	local fg = groundY(36, -2)
	setMarker("Fusion", CFrame.lookAt(Vector3.new(36, fg, -2), Vector3.new(0, fg, 4)))
	-- The three leaderboards (LeaderboardService): west side of the plaza, facing the fountain.
	local lg = groundY(-40, 2)
	setMarker("Leaderboards", CFrame.lookAt(Vector3.new(-40, lg, 2), Vector3.new(0, lg, 6)))
	setMarker("Zone_Town", CFrame.new(0, groundY(0, 0), 0)):SetAttribute("Radius", 200)
	table.insert(log, "markers done")
end

local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
table.insert(log, `map parts: {parts}`)
return table.concat(log, "\n")
