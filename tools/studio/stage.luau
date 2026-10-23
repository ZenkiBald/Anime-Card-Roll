-- Loads Creator Store models into workspace.Staging in a labelled row so they can be compared in a
-- screenshot. Every script inside is deleted (free models can carry backdoors). Args:
-- { Ids = { "123", ... }, Origin = Vector3, Gap = number, Clear = bool }
local args = ...
local staging = workspace:FindFirstChild("Staging")
if args.Clear and staging then
	staging:Destroy()
	staging = nil
end
if not staging then
	staging = Instance.new("Folder")
	staging.Name = "Staging"
	staging.Parent = workspace
end
local out = {}
local x = 0
for _, id in args.Ids do
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if not ok or not objects or not objects[1] then
		table.insert(out, `{id}: load failed {tostring(objects)}`)
		continue
	end
	local model = objects[1]
	if not model:IsA("Model") then
		local wrap = Instance.new("Model")
		for _, o in objects do
			o.Parent = wrap
		end
		model = wrap
	end
	local scripts, parts, tris = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
		end
	end
	model.Name = `S_{id}`
	model:SetAttribute("AssetId", id)
	local cf, size = model:GetBoundingBox()
	x += size.X / 2
	local ground = args.Origin or Vector3.new(0, 2, 70)
	model:PivotTo(model:GetPivot() * cf:Inverse() * CFrame.new(ground + Vector3.new(x, size.Y / 2, 0)) * cf.Rotation)
	x += size.X / 2 + (args.Gap or 6)
	local tag = Instance.new("Part")
	tag.Name = "Tag"
	tag.Anchored = true
	tag.CanCollide = false
	tag.Transparency = 1
	tag.Size = Vector3.one
	tag.Position = ground + Vector3.new(x - size.X / 2 - (args.Gap or 6), size.Y + 3, 0)
	tag.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.Parent = tag
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 0)
	label.TextScaled = true
	label.Text = id
	label.Parent = gui
	model.Parent = staging
	table.insert(out, string.format("%s %q: %d parts, %d scripts removed, size %.0fx%.0fx%.0f", id, objects[1].Name, parts, scripts, size.X, size.Y, size.Z))
	task.wait()
end
return table.concat(out, "\n") .. string.format("\nrow length %.0f", x)
