--!strict
-- Project a hit onto the figure currently standing in that enemy slot.
local Renderer = {}
function Renderer.Surface(model: Model, height: number): BillboardGui?
	local part = model.PrimaryPart
	if not part then return nil end
	local existing = part:FindFirstChild("CardHitSurface")
	if existing and existing:IsA("BillboardGui") then return existing end
	local surface = Instance.new("BillboardGui")
	surface.Name = "CardHitSurface"
	surface.Adornee = part
	surface.Size = UDim2.fromScale(height * 0.78, height * 0.78)
	surface.StudsOffsetWorldSpace = model:GetPivot().Position - part.Position + Vector3.new(0, height * 0.1, 0)
	surface.AlwaysOnTop = true
	surface.LightInfluence = 0
	surface.Parent = part
	return surface
end
return Renderer
