-- Edit mode only. Polishes the existing town; never rebuilds the map or changes Terrain.
-- Run once after map.luau. Re-running is a no-op. { Restore = true } restores the saved
-- fountain / three stalls / markers and removes only this pass's decorations.
local args = ... or {}
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before polishing the town")
local map = assert(workspace:FindFirstChild("Map"), "Open the real game place")
local town = assert(map:FindFirstChild("Town"), "Missing Town")
local markers = assert(map:FindFirstChild("Markers"), "Missing Markers")
local storage = game:GetService("ServerStorage")
local backupName = "TownPolishBackup_20261026"
local backup = storage:FindFirstChild(backupName)

if args.Restore then
	assert(backup, "No town-polish backup in this place")
	for _, record in backup:GetChildren() do
		local target = record:FindFirstChild("Target")
		local parent = record:FindFirstChild("OriginalParent")
		local snapshot = record:FindFirstChild("Snapshot")
		if target and parent and snapshot then
			assert(parent.Value, "A backup's original parent was removed; stop and inspect it")
			if target.Value then target.Value:Destroy() end
			local restored = snapshot:Clone()
			restored.Name = record:GetAttribute("OriginalName")
			restored.Parent = parent.Value
		end
	end
	local decor = town:FindFirstChild("PlazaPolish")
	if decor then decor:Destroy() end
	backup:Destroy()
	return "Original town restored. Stop / restart Play to rebuild the NPCs."
end

if town:FindFirstChild("PlazaPolish") then
	return "Town polish is already applied; no changes made."
end
assert(not backup, "An unfinished pass has a backup; restore it before re-running")
local fountain = assert(town:FindFirstChild("Fountain"), "Missing fountain")
local stalls = {}
for _, model in town:GetChildren() do
	if model.Name == "FoodStall" and model:IsA("Model") then table.insert(stalls, model) end
end
assert(#stalls == 3, "Expected the existing three stalls; inspect this map before changing it")
table.sort(stalls, function(a, b) return a:GetPivot().X < b:GetPivot().X end)
for _, name in { "Spawn", "Sage", "Fusion", "Wheel", "Leaderboards" } do
	assert(markers:FindFirstChild(name), "Missing marker " .. name)
end
local flowerTemplate
for _, child in town:GetChildren() do
	if child.Name == "BushFlower" and child:IsA("Model") then flowerTemplate = child; break end
end
assert(flowerTemplate, "Missing existing flower model")

-- All changed assets are small; large houses, terrain and world zones are untouched.
backup = Instance.new("Folder")
backup.Name = backupName
backup.Parent = storage
local function preserve(key, original)
	local record = Instance.new("Folder")
	record.Name = key
	record:SetAttribute("OriginalName", original.Name)
	local snapshot = original:Clone()
	snapshot.Name = "Snapshot"
	snapshot.Parent = record
	for name, value in { Target = original, OriginalParent = original.Parent } do
		local ref = Instance.new("ObjectValue")
		ref.Name = name
		ref.Value = value
		ref.Parent = record
	end
	record.Parent = backup
end
preserve("Fountain", fountain)
preserve("Markers", markers)
for i, stall in stalls do preserve("Stall" .. i, stall) end

local decor = Instance.new("Folder")
decor.Name = "PlazaPolish"
decor:SetAttribute("Version", 1)
decor.Parent = town
local stone = Color3.fromRGB(119, 124, 119)
local lightStone = Color3.fromRGB(167, 169, 153)
local wood = Color3.fromRGB(105, 66, 45)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 100, z), Vector3.new(0, -200, 0), params)
	assert(hit, "Missing ground in the plaza")
	return hit.Position.Y
end
local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function marker(name, x, z)
	local m = markers:FindFirstChild(name)
	if not m then
		m = Instance.new("Part")
		m.Name = name
		m.Size = Vector3.new(2, 1, 2)
		m.Anchored = true
		m.Transparency = 1
		m.CanCollide = false
		m.CanTouch = false
		m.CanQuery = false
		m.Parent = markers
	end
	local pos = Vector3.new(x, ground(x, z), z)
	m.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	return m.CFrame
end

-- Server World / NpcRange read the same markers on each start. No runtime-only NPC moves.
marker("Tower", -37, -25)
marker("Sage", -29, 24)
marker("Fusion", 30, -30)
marker("TraitMaster", 43, -12)
marker("Wheel", 32, 30)
-- The three boards stay on the west edge; give the tower board its own northern space.
marker("Leaderboards", -46, 8)

local stallSpots = { Vector2.new(-40, 30), Vector2.new(37, -39), Vector2.new(43, 38) }
for i, model in stalls do
	local pos = stallSpots[i]
	local old = model:GetPivot()
	local oldYaw = math.atan2(-old.X, -old.Z)
	local newYaw = math.atan2(-pos.X, -pos.Y)
	model:PivotTo(CFrame.new(old.Position) * CFrame.Angles(0, newYaw - oldYaw, 0) * old.Rotation)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(pos.X - cf.X, ground(pos.X, pos.Y) - 0.2 - (cf.Y - size.Y / 2), pos.Y - cf.Z))
end

for _, p in fountain:GetDescendants() do
	if p:IsA("BasePart") then
		if p.Name == "Bush" then
			p.Color = Color3.fromRGB(77, 131, 78)
		elseif p.Material == Enum.Material.Neon then
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(76, 155, 161)
		elseif p:IsA("MeshPart") and p.Transparency == 0 then
			p.Material = Enum.Material.Slate
			p.Color = Color3.fromRGB(133, 139, 135)
		end
	end
end

-- Thin inlays follow the existing cobblestone, with no extra collision step or terrain writes.
for i = 0, 39 do
	local a = i * math.pi * 2 / 40
	local x, z = math.cos(a) * 22.5, math.sin(a) * 22.5
	part(decor, "FountainBorder", Vector3.new(1.4, 0.22, 3.45),
		CFrame.new(x, ground(x, z) - 0.06, z) * CFrame.Angles(0, -a, 0),
		if i % 5 == 0 then lightStone else stone)
end
for _, name in { "Sage", "Fusion", "TraitMaster", "Wheel", "Tower" } do
	local cf = markers[name].CFrame
	local direction = Vector3.new(cf.X, 0, cf.Z).Unit
	local distance = Vector2.new(cf.X, cf.Z).Magnitude
	local finish = distance - (if name == "Tower" then 5 else 3)
	for d = 26, finish, 3.4 do
		local at = direction * d
		part(decor, "ServicePaver", Vector3.new(6, 0.18, 3),
			CFrame.lookAt(Vector3.new(at.X, ground(at.X, at.Z) - 0.035, at.Z), Vector3.new(0, ground(at.X, at.Z) - 0.035, 0)), lightStone)
	end
end

local function bench(x, z)
	local y = ground(x, z)
	local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(0, y, 0))
	local model = Instance.new("Model")
	model.Name = "GardenBench"
	for _, dx in { -3.1, 3.1 } do
		part(model, "StoneFoot", Vector3.new(0.8, 1.5, 2.5), cf * CFrame.new(dx, 0.75, 0), stone, nil, true)
		part(model, "BackPost", Vector3.new(0.4, 2.8, 0.4), cf * CFrame.new(dx, 2.3, 0.95), wood, Enum.Material.Wood, true)
	end
	for _, dz in { -0.75, 0, 0.75 } do
		part(model, "SeatSlat", Vector3.new(9, 0.35, 0.65), cf * CFrame.new(0, 1.65, dz), wood, Enum.Material.Wood, true)
	end
	for _, dy in { 2.55, 3.25 } do
		part(model, "BackSlat", Vector3.new(9, 0.5, 0.3), cf * CFrame.new(0, dy, 1), wood, Enum.Material.Wood, true)
	end
	for _, dx in { -6.8, 6.8 } do
		local at = cf * CFrame.new(dx, 0, 0)
		part(model, "Planter", Vector3.new(3.8, 1.4, 3.8), at * CFrame.new(0, 0.7, 0), stone, nil, true)
		part(model, "Soil", Vector3.new(3.3, 0.15, 3.3), at * CFrame.new(0, 1.43, 0), Color3.fromRGB(70, 57, 42), Enum.Material.Ground)
		local flowers = flowerTemplate:Clone()
		local _, size = flowers:GetBoundingBox()
		flowers:ScaleTo(flowers:GetScale() * 3.5 / math.max(size.X, size.Z))
		local bounds, scaled = flowers:GetBoundingBox()
		flowers:PivotTo(flowers:GetPivot() + Vector3.new(at.X - bounds.X, y + 1.4 - (bounds.Y - scaled.Y / 2), at.Z - bounds.Z))
		for _, p in flowers:GetDescendants() do
			if p:IsA("BasePart") then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
		end
		flowers.Parent = model
	end
	model.Parent = decor
end
bench(13, 34)
bench(-13, -34)
backup:SetAttribute("Complete", true)
return "Town polish applied. Backup: ServerStorage." .. backupName .. "; save the place from Studio."
