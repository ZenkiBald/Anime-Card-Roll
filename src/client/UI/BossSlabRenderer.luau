--!nonstrict
-- Project a hit onto the figure currently standing in that enemy slot.
local Cards = require(game:GetService("ReplicatedStorage").Shared.Cards)
local Kit = require(script.Parent.Kit)
local Renderer = {}
local portraits = {
	ashigaru = "ibuki", embermonk = "yume", ironclad = "rook",
	frostarcher = "kaito", snowmaiden = "amaya", glaciergolem = "tetsu",
	shade = "tsubasa", nullwitch = "kaede", voidknight = "hayate",
	thunderhawk = "suzu", stormpriest = "hana", raiju = "tomo",
}

function Renderer.Portrait(id, parent)
	local card = Cards.ForBoss(id) or Cards.Get(portraits[id] or "")
	return Kit.new("ImageLabel", { Name = "EnemyPortrait", Image = if card then card.Image else "",
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Parent = parent })
end

-- The same painted face serves the physical slab and the screen-space battle fallback.
function Renderer.Face(id, parent, color)
	local face = Kit.new("CanvasGroup", { Name = "EnemyFace", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 16, 28), BorderSizePixel = 0, Parent = parent })
	local portrait = Renderer.Portrait(id, face)
	local rim = Kit.new("Frame", { Name = "TierRim", AnchorPoint = Vector2.new(.5,.5),
		Position = UDim2.fromScale(.5,.5), Size = UDim2.fromScale(.98,.985), BackgroundTransparency = 1, Parent = face },
		{ Kit.corner(UDim.new(.045,0)), Kit.stroke(color, 3, 0) })
	return face, portrait, rim.UIStroke
end

function Renderer.Build(id, height, color)
	local model = Instance.new("Model")
	model.Name = id
	local slab = Instance.new("Part")
	slab.Name = "CardSlab"
	slab.Size = Vector3.new(height * .72, height, .16)
	slab.Anchored = true
	slab.CanCollide, slab.CanTouch, slab.CanQuery, slab.CastShadow = false, false, false, false
	slab.Material = Enum.Material.Neon
	slab.Color = color
	slab.Parent = model
	model.PrimaryPart = slab
	local surface = Instance.new("SurfaceGui")
	surface.Name = "CardArt"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(324, 450)
	surface.LightInfluence = 0
	surface.Brightness = 1.35
	surface.Parent = slab
	local face = Renderer.Face(id, surface, color)
	return model, face
end

function Renderer.Shatter(part)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "DefeatBurst"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(part.Color, Color3.new(1,1,1))
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(.16,.32)
	sparks.Speed = NumberRange.new(4,8)
	sparks.SpreadAngle = Vector2.new(180,180)
	sparks.Size = NumberSequence.new(.45,0)
	sparks.Parent = part
	sparks:Emit(12)
	game:GetService("Debris"):AddItem(sparks,.4)
end

function Renderer.Preview(id, props, color)
	local holder = Kit.new("Frame", props)
	holder.BackgroundTransparency = 1
	Kit.aspect(.72, Enum.DominantAxis.Height).Parent = holder
	local _, portrait, rim = Renderer.Face(id, holder, color)
	local scale = Kit.new("UIScale", {Parent=holder})
	local view = {Frame=holder}
	function view:SetTint(tint) rim.Color = tint end
	function view:Flash(tint, seconds)
		portrait.ImageColor3 = tint
		Kit.tween(portrait, seconds or .25, { ImageColor3 = Color3.new(1,1,1) })
	end
	function view:Kick() scale.Scale=.96; Kit.tween(scale,.17,{Scale=1}) end
	function view:Lunge() scale.Scale=1.07; Kit.tween(scale,.2,{Scale=1}) end
	return view
end
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
