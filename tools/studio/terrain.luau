-- Terrain for the big world. Call with { Rows = {first, last} } (chunk rows 0..CHUNKS-1), or { Clear = true }.
-- Layout (studs): spawn town at the origin, Ember Village west, Frostfang Peaks north (a snowy plateau
-- ringed by mountains), Neon Abyss east (a dark basin), a lake south, Stormspire Isle past the lake (a
-- storm-stone plateau ringed by spires), mountains around the edge. Stormspire alone: { Rows = {9, 11} }.
local args = ... or {}
local T = workspace.Terrain
local RES = 4
local HALF = 768 -- map spans -HALF..HALF on X and Z
local CHUNK = 32 -- voxels per chunk side (128 studs)
local CHUNKS = (HALF * 2) // (RES * CHUNK)

if args.Clear then
	T:Clear()
	return "cleared"
end

-- Bright, saturated anime palette for the terrain materials.
local COLORS = {
	Grass = Color3.fromRGB(104, 178, 72),
	LeafyGrass = Color3.fromRGB(200, 132, 40), -- Ember Village's autumn ground
	Ground = Color3.fromRGB(142, 98, 62),
	Mud = Color3.fromRGB(96, 74, 54),
	Sand = Color3.fromRGB(236, 214, 160),
	Rock = Color3.fromRGB(112, 110, 128),
	Snow = Color3.fromRGB(240, 246, 255),
	Glacier = Color3.fromRGB(160, 214, 255),
	Cobblestone = Color3.fromRGB(168, 156, 146),
	Pavement = Color3.fromRGB(186, 196, 214),
	Asphalt = Color3.fromRGB(52, 32, 84), -- Neon Abyss: violet-black floor
	Salt = Color3.fromRGB(104, 44, 170), -- sparkly violet patches
	Slate = Color3.fromRGB(88, 56, 132),
	Basalt = Color3.fromRGB(60, 36, 96),
	Limestone = Color3.fromRGB(66, 72, 98), -- Stormspire Isle: dark storm stone
	Concrete = Color3.fromRGB(104, 110, 132), -- Stormspire scree and its road
}
for name, color in COLORS do
	T:SetMaterialColor(Enum.Material[name], color)
end
T.WaterColor = Color3.fromRGB(40, 170, 220)
T.WaterTransparency = 0.55
T.WaterReflectance = 0.6
T.WaterWaveSize = 0.12
T.WaterWaveSpeed = 8

local TOWN = Vector2.new(0, 0)
local EMBER = Vector2.new(-430, 150)
local FROST = Vector2.new(30, -500)
local ABYSS = Vector2.new(450, 170)
local LAKE = Vector2.new(-60, 290)
local STORM = Vector2.new(-50, 545)

local ROADS = { -- polylines, town -> zone (Stormspire's starts at the south end of the lake bridge)
	{ Vector2.new(-20, 30), Vector2.new(-160, 90), Vector2.new(-300, 120), Vector2.new(-400, 150) },
	{ Vector2.new(0, -40), Vector2.new(20, -180), Vector2.new(0, -290), Vector2.new(30, -400) },
	{ Vector2.new(30, 20), Vector2.new(170, 60), Vector2.new(320, 140), Vector2.new(410, 165) },
	{ Vector2.new(-60, 398), Vector2.new(-57, 440), Vector2.new(-52, 490), Vector2.new(-50, 585) },
}
local ROAD_W = 9

local function smooth(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local function fbm(x, z, f, oct)
	local sum, amp, norm = 0, 1, 0
	for _ = 1, oct do
		sum += math.noise(x * f, z * f, 7.31) * amp
		norm += amp
		amp *= 0.5
		f *= 2
	end
	return sum / norm
end
local function ridge(x, z, f)
	local n = 1 - math.abs(fbm(x, z, f, 4))
	return n * n
end
local function segDist(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude, t
end
local function roadInfo(p)
	local best, bestRoad, bestT = math.huge, nil, 0
	for r, line in ROADS do
		for i = 1, #line - 1 do
			local d, t = segDist(p, line[i], line[i + 1])
			if d < best then
				best, bestRoad, bestT = d, r, (i - 1 + t) / (#line - 1)
			end
		end
	end
	return best, bestRoad, bestT
end

-- Ground height and surface material for a column.
local function column(x, z)
	local p = Vector2.new(x, z)
	local n = fbm(x, z, 1 / 160, 3)
	local h = 3 + n * 7
	local mat = Enum.Material.Grass

	local dEmber = (p - EMBER).Magnitude
	local dFrost = (p - FROST).Magnitude
	local dAbyss = (p - ABYSS).Magnitude
	local dTown = (p - TOWN).Magnitude
	local dLake = (p - LAKE).Magnitude

	-- Ember Village: gentle autumn hills.
	local wE = 1 - smooth(140, 230, dEmber)
	h = h + wE * (fbm(x, z, 1 / 60, 2) * 4 + 3)
	if wE > 0.4 then
		mat = if fbm(x, z, 1 / 30, 2) > 0.15 then Enum.Material.Ground else Enum.Material.LeafyGrass
	end

	-- Frostfang Peaks: a plateau at 56 with mountains behind and beside it (open towards town).
	local wF = 1 - smooth(120, 210, dFrost)
	h = h * (1 - wF) + 56 * wF + wF * fbm(x, z, 1 / 50, 2) * 3
	local toTown = (TOWN - FROST).Unit
	local facing = if dFrost > 1 then (p - FROST).Unit:Dot(toTown) else 0
	local ring = smooth(190, 250, dFrost) * (1 - smooth(330, 400, dFrost)) * (1 - smooth(0.1, 0.6, facing))
	h += ring * (45 + ridge(x, z, 1 / 220) * 95)
	local frostiness = math.max(wF, ring)
	if wF > 0.3 or (ring > 0.2 and h > 30) then
		mat = Enum.Material.Snow
	end

	-- Neon Abyss: a dark basin with ridges on its rim.
	local wA = 1 - smooth(130, 200, dAbyss)
	h = h * (1 - wA) + (-16 + fbm(x, z, 1 / 40, 2) * 3) * wA
	local rim = smooth(150, 200, dAbyss) * (1 - smooth(200, 260, dAbyss))
	h += rim * (14 + ridge(x, z, 1 / 70) * 26)
	if wA > 0.35 then
		mat = if fbm(x, z, 1 / 25, 2) > 0.2 then Enum.Material.Basalt else Enum.Material.Asphalt
	elseif rim > 0.3 then
		mat = Enum.Material.Basalt
	end

	-- Stormspire Isle: a dark storm-stone plateau at 16 past the lake, ringed by sharp spires except on the
	-- lake side, where the road climbs in from the bridge.
	local dStorm = (p - STORM).Magnitude
	local wS = 1 - smooth(85, 140, dStorm)
	h = h * (1 - wS) + (16 + fbm(x, z, 1 / 45, 2) * 3) * wS
	local toLake = (LAKE - STORM).Unit
	local facingS = if dStorm > 1 then (p - STORM).Unit:Dot(toLake) else 0
	local spires = smooth(85, 115, dStorm) * (1 - smooth(150, 190, dStorm)) * (1 - smooth(0.3, 0.7, facingS))
	h += spires * (10 + ridge(x, z, 1 / 36) ^ 3 * 75)
	if wS > 0.35 then
		local n = fbm(x, z, 1 / 22, 2)
		mat = if n > 0.25 then Enum.Material.Concrete elseif n > -0.2 then Enum.Material.Limestone else Enum.Material.Grass
	elseif spires > 0.2 and h > 18 then
		mat = Enum.Material.Limestone
	end

	-- Spawn town: flat, cobbled plaza in the middle.
	local wT = 1 - smooth(110, 170, dTown)
	h = h * (1 - wT) + 2 * wT
	if dTown < 52 then
		mat = Enum.Material.Cobblestone
	end

	-- Lake: a bowl filled with water to y = 0, sandy shore.
	local wL = 1 - smooth(70, 120, dLake)
	h = h * (1 - wL) + (-14 + fbm(x, z, 1 / 30, 2) * 3) * wL
	if wL > 0.05 and wL < 0.6 and h > -3 then
		mat = Enum.Material.Sand
	elseif wL >= 0.6 then
		mat = Enum.Material.Mud
	end

	-- Roads: flatten to the road's own height, cobbles in the middle.
	local d, r, t = roadInfo(p)
	if d < ROAD_W * 2.2 then
		local target = 2
		if r == 2 then
			target = 2 + smooth(0.45, 1, t) * 54 -- climbs to the Frostfang plateau
		elseif r == 3 then
			target = 2 - smooth(0.6, 1, t) * 18 -- dips into the Abyss
		elseif r == 1 then
			target = 2 + smooth(0.6, 1, t) * 3
		elseif r == 4 then
			target = 2 + smooth(0.1, 0.5, t) * 14 -- climbs onto the Stormspire plateau
		end
		local w = 1 - smooth(ROAD_W, ROAD_W * 2.2, d)
		h = h * (1 - w) + target * w
		if d < ROAD_W then
			mat = if r == 2 and t > 0.55 then Enum.Material.Snow
				elseif r == 3 and t > 0.7 then Enum.Material.Basalt
				elseif r == 4 then Enum.Material.Concrete
				else Enum.Material.Cobblestone
			if r == 2 and t > 0.55 then
				mat = Enum.Material.Pavement
			end
		end
	end

	-- Edge of the world: mountains.
	local edge = math.max(math.abs(x), math.abs(z))
	local wM = smooth(600, 740, edge)
	h += wM * (55 + ridge(x, z, 1 / 200) * 110)
	if wM > 0.3 then
		mat = if h > 140 then Enum.Material.Snow else Enum.Material.Rock
	end

	return h, mat, (frostiness > 0.5 or wF > 0.3)
end

local WATER_LEVEL = 0
local function inLake(x, z)
	return (Vector2.new(x, z) - LAKE).Magnitude < 125
end

local rows = args.Rows or { 0, CHUNKS - 1 }
local done = 0
for cz = rows[1], rows[2] do
	for cx = 0, CHUNKS - 1 do
		local x0 = -HALF + cx * CHUNK * RES
		local z0 = -HALF + cz * CHUNK * RES
		-- Heights per column (one sample per voxel column, at its centre), plus a slope check.
		local heights, mats = {}, {}
		local minH, maxH = math.huge, -math.huge
		for i = 0, CHUNK + 1 do
			heights[i] = {}
			mats[i] = {}
			for k = 0, CHUNK + 1 do
				local h, m = column(x0 + (i - 0.5) * RES, z0 + (k - 0.5) * RES)
				heights[i][k] = h
				mats[i][k] = m
				if i >= 1 and i <= CHUNK and k >= 1 and k <= CHUNK then
					minH = math.min(minH, h)
					maxH = math.max(maxH, h)
				end
			end
		end
		local yBottom = math.floor((math.min(minH, -16) - 12) / RES) * RES
		local yTop = math.ceil((math.max(maxH, WATER_LEVEL) + RES) / RES) * RES
		local ny = (yTop - yBottom) // RES
		local materials, occupancy = {}, {}
		for i = 1, CHUNK do
			local mx, ox = {}, {}
			materials[i], occupancy[i] = mx, ox
			for j = 1, ny do
				mx[j], ox[j] = {}, {}
			end
			for k = 1, CHUNK do
				local h = heights[i][k]
				local surface = mats[i][k]
				local slope = math.max(
					math.abs(heights[i + 1][k] - heights[i - 1][k]),
					math.abs(heights[i][k + 1] - heights[i][k - 1])
				) / (2 * RES)
				if slope > 0.9 and surface ~= Enum.Material.Cobblestone and surface ~= Enum.Material.Pavement then
					surface = if surface == Enum.Material.Snow and slope < 1.4 then Enum.Material.Glacier else Enum.Material.Rock
				end
				local wx, wz = x0 + (i - 0.5) * RES, z0 + (k - 0.5) * RES
				local lake = inLake(wx, wz)
				for j = 1, ny do
					local yb = yBottom + (j - 1) * RES
					local fill = math.clamp((h - yb) / RES, 0, 1)
					if fill > 0 then
						local m
						if h - yb > 10 then
							m = if surface == Enum.Material.Basalt or surface == Enum.Material.Asphalt or surface == Enum.Material.Salt then Enum.Material.Basalt else Enum.Material.Rock
						elseif h - yb > RES * 2.5 then
							m = if surface == Enum.Material.Grass or surface == Enum.Material.LeafyGrass then Enum.Material.Ground else surface
						else
							m = surface
						end
						mx[j][k] = m
						ox[j][k] = math.max(fill, 0.02)
					elseif lake and yb < WATER_LEVEL then
						mx[j][k] = Enum.Material.Water
						ox[j][k] = 1
					else
						mx[j][k] = Enum.Material.Air
						ox[j][k] = 0
					end
				end
			end
		end
		local region = Region3.new(Vector3.new(x0, yBottom, z0), Vector3.new(x0 + CHUNK * RES, yTop, z0 + CHUNK * RES))
		T:WriteVoxels(region, RES, materials, occupancy)
		done += 1
		task.wait()
	end
end
return `wrote {done} chunks (rows {rows[1]}-{rows[2]} of {CHUNKS})`
