--!strict
-- A flush, painted stone floor over the authored town clearing. The terrain still owns collision.
local Plaza = {}

local STONE = Color3.fromRGB(145, 131, 116)
local JOINT = Color3.fromRGB(111, 117, 106)
local JADE = Color3.fromRGB(76, 106, 98)
local BRASS = Color3.fromRGB(171, 143, 95)
local CANVAS = 1000
local RADIUS = 48

local function mark(face: SurfaceGui, x: number, y: number, w: number, h: number, color: Color3)
	local rect = Instance.new("Frame")
	rect.BorderSizePixel = 0
	rect.BackgroundColor3 = color
	rect.Position = UDim2.fromOffset(x, y)
	rect.Size = UDim2.fromOffset(w, h)
	rect.Parent = face
	return rect
end

local function halfChord(offset: number): number
	local radius = CANVAS / 2 - 12
	return math.sqrt(math.max(0, radius ^ 2 - (offset - CANVAS / 2) ^ 2))
end

local function paving(parent: Instance, centre: Vector3)
	local disk = Instance.new("Part")
	disk.Name = "PlazaPaving"
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(0.16, 2 * RADIUS, 2 * RADIUS)
	disk.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2)
	disk.Color = STONE
	disk.Material = Enum.Material.SmoothPlastic
	disk.Anchored = true
	disk.CanCollide = false
	disk.CanQuery = false
	disk.CanTouch = false
	disk.CastShadow = false
	local face = Instance.new("SurfaceGui")
	face.Name = "Flagstones"
	face.Face = Enum.NormalId.Right
	face.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	face.CanvasSize = Vector2.new(CANVAS, CANVAS)
	face.LightInfluence = 1
	face.MaxDistance = 220
	face.Active = false
	face.Parent = disk

	-- Lay up broad, staggered stones. Every joint ends inside the round border.
	local half = CANVAS / 2
	local course, width = 64, 130
	for row = 0, math.ceil(CANVAS / course) - 1 do
		local y = row * course
		local span = halfChord(y)
		if span > 0 then mark(face, half - span, y, 2 * span, 1.6, JOINT) end
		for x = 40 + (row % 2) * width / 2, CANVAS, width do
			local reach = halfChord(x)
			local top, bottom = math.max(y, half - reach), math.min(y + course, half + reach)
			if bottom > top then mark(face, x, top, 1.6, bottom - top, JOINT) end
		end
	end
	local ring = mark(face, 12, 12, CANVAS - 24, CANVAS - 24, JADE)
	ring.BackgroundTransparency = 1
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Color = JADE
	edge.Thickness = 4
	edge.Parent = ring
	disk.Parent = parent
end

function Plaza.Build(hub: Instance, town: Instance)
	local fountain = town:FindFirstChild("Fountain")
	if not fountain or not fountain:IsA("Model") then return end
	local trim = town:FindFirstChild("PlazaPolish")
	local centre = fountain:GetBoundingBox().Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace.Terrain}
	local hit = workspace:Raycast(centre + Vector3.yAxis * 24, -Vector3.yAxis * 80, params)
	if not hit or hit.Material ~= Enum.Material.Cobblestone then return end
	paving(hub, Vector3.new(centre.X, hit.Position.Y, centre.Z))

	local bowls = fountain:FindFirstChild("Fountain")
	if bowls then
		for _, mesh in bowls:GetDescendants() do
			if mesh:IsA("MeshPart") and mesh.Material == Enum.Material.Slate then
				mesh.Material = Enum.Material.SmoothPlastic
				mesh.Color = if mesh.Size.Y < 1 then JADE elseif mesh.Size.Y > 26 then Color3.fromRGB(151, 154, 143) else Color3.fromRGB(137, 147, 138)
			end
		end
	end
	if not trim then return end
	for _, part in trim:GetDescendants() do
		if not part:IsA("BasePart") or part.Material ~= Enum.Material.Slate then continue end
		if part.Name == "FountainBorder" or part.Name == "ServicePaver" then
			local accent = part.Color.R > 0.58
			part.Color = if part.Name == "ServicePaver" then Color3.fromRGB(178, 159, 127) elseif accent then BRASS else JADE
			-- Bring the existing thin inlays just above the new finish at their authored X/Z.
			if not part.CanCollide then part.Position += Vector3.yAxis * 0.12 end
		elseif part.Name == "Planter" or part.Name == "StoneFoot" then
			part.Color = JADE
		else
			continue
		end
		part.Material = Enum.Material.SmoothPlastic
	end
end

return Plaza
