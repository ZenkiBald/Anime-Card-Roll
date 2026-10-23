--!strict
-- Card character art: a chibi figure built from plain parts (no meshes, textures or uploads),
-- drawn on the card in a ViewportFrame. Each card's look is data (Card.Look in Cards.luau):
-- colours, a hair style, something on the head, a prop and an optional aura.
-- Figures stand on y = 0 and face -Z.

local Cards = require(script.Parent.Cards)

type Look = Cards.Look

local CardArt = {}

local DARK = Color3.fromRGB(34, 28, 40)
local WHITE = Color3.fromRGB(250, 250, 255)
local METAL = Color3.fromRGB(205, 210, 222)
local NEON = Enum.Material.Neon

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

local function ball(model: Model, name: string, diameter: number, at: Vector3, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.one * diameter, CFrame.new(at), color, material, Enum.PartType.Ball)
end

-- A round disc facing the camera (cylinder turned to point along Z).
local FACING = CFrame.Angles(0, math.rad(90), 0)
local function disc(model: Model, name: string, diameter: number, at: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = part(model, name, Vector3.new(0.05, diameter, diameter), CFrame.new(at) * FACING, color, material, Enum.PartType.Cylinder)
	p.Transparency = transparency or 0
	return p
end

-- A flat disc lying level (cylinder turned to point up).
local LEVEL = CFrame.Angles(0, 0, math.rad(90))
local function plate(model: Model, name: string, thickness: number, diameter: number, at: Vector3, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.new(thickness, diameter, diameter), CFrame.new(at) * LEVEL, color, material, Enum.PartType.Cylinder)
end

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local HEAD = Vector3.new(0, 2.95, 0)

local function body(model: Model, look: Look)
	-- Legs and shoes.
	for _, x in { -0.3, 0.3 } do
		part(model, "Leg", Vector3.new(0.52, 0.8, 0.58), CFrame.new(x, 0.42, 0), look.Outfit2)
		part(model, "Shoe", Vector3.new(0.58, 0.24, 0.74), CFrame.new(x, 0.12, -0.06), DARK)
	end
	-- Torso with a belt and a chest mark.
	part(model, "Torso", Vector3.new(1.3, 1.15, 0.8), CFrame.new(0, 1.38, 0), look.Outfit)
	part(model, "Belt", Vector3.new(1.34, 0.18, 0.84), CFrame.new(0, 0.9, 0), look.Trim)
	part(model, "Chest", Vector3.new(0.42, 0.42, 0.05), CFrame.new(0, 1.6, -0.42) * rot(0, 0, 45), look.Trim)
	-- Arms and hands.
	for _, side in { -1, 1 } do
		part(model, "Arm", Vector3.new(0.42, 0.95, 0.48), CFrame.new(side * 0.86, 1.4, 0) * rot(0, 0, side * 12), look.Outfit2)
		ball(model, "Hand", 0.46, Vector3.new(side * 0.98, 0.88, 0), look.Skin)
	end
	-- Big head with anime eyes, blush and a small mouth.
	ball(model, "Head", 2.1, HEAD, look.Skin)
	for i, x in { -0.4, 0.4 } do
		disc(model, "EyeWhite", 0.5, Vector3.new(x, 2.86, -0.99), WHITE)
		local glowing = look.GlowEye == true and i == 1
		disc(model, "Iris", 0.37, Vector3.new(x, 2.84, -1.02), if glowing then Color3.fromRGB(255, 200, 60) else look.Eyes, if glowing then NEON else nil)
		disc(model, "Pupil", 0.17, Vector3.new(x, 2.82, -1.04), DARK)
		disc(model, "Shine", 0.12, Vector3.new(x + 0.08, 2.96, -1.06), WHITE, NEON)
		disc(model, "Blush", 0.26, Vector3.new(x * 1.55, 2.58, -0.8), Color3.fromRGB(255, 140, 160), nil, 0.45)
	end
	part(model, "Mouth", Vector3.new(0.2, 0.05, 0.04), CFrame.new(0, 2.42, -1.0), Color3.fromRGB(150, 60, 70))
end

local function fringe(model: Model, look: Look)
	for i, x in { -0.45, 0, 0.45 } do
		part(model, "Fringe", Vector3.new(0.42, 0.55, 0.3), CFrame.new(x, 3.62, -0.86) * rot(-18, 0, (i - 2) * -14), look.Hair)
	end
end

local STYLES: { [string]: (Model, Look) -> () } = {
	Spiky = function(model, look)
		local spikes: { CFrame } = {
			CFrame.new(0, 4.2, 0.1),
			CFrame.new(-0.62, 4.02, 0.2) * rot(0, 0, 32),
			CFrame.new(0.62, 4.02, 0.2) * rot(0, 0, -32),
			CFrame.new(-1.0, 3.6, 0.3) * rot(0, 0, 58),
			CFrame.new(1.0, 3.6, 0.3) * rot(0, 0, -58),
			CFrame.new(0, 3.75, 0.95) * rot(-52, 0, 0),
		}
		for _, spike in spikes do
			part(model, "Spike", Vector3.new(0.42, 1.05, 0.42), spike * rot(0, 45, 0), look.Hair)
		end
		fringe(model, look)
	end,
	Long = function(model, look)
		part(model, "Back", Vector3.new(1.9, 2.4, 0.45), CFrame.new(0, 2.45, 0.78), look.Hair)
		for _, side in { -1, 1 } do
			part(model, "Lock", Vector3.new(0.42, 1.8, 0.45), CFrame.new(side * 1.0, 2.4, -0.15) * rot(0, 0, side * -4), look.Hair)
		end
		fringe(model, look)
	end,
	Bob = function(model, look)
		for _, side in { -1, 1 } do
			part(model, "Side", Vector3.new(0.5, 1.3, 1.5), CFrame.new(side * 0.95, 2.72, 0.08), look.Hair)
		end
		fringe(model, look)
	end,
	Ponytail = function(model, look)
		part(model, "Tail", Vector3.new(0.52, 1.6, 0.52), CFrame.new(0, 2.95, 1.32) * rot(28, 0, 0), look.Hair)
		ball(model, "Tie", 0.4, Vector3.new(0, 3.62, 1.12), look.Trim)
		fringe(model, look)
	end,
	Twin = function(model, look)
		for _, side in { -1, 1 } do
			part(model, "Tail", Vector3.new(0.5, 1.7, 0.5), CFrame.new(side * 1.3, 2.6, 0.2) * rot(0, 0, side * 16), look.Hair)
			ball(model, "Tie", 0.36, Vector3.new(side * 1.12, 3.42, 0.2), look.Trim)
		end
		fringe(model, look)
	end,
	Swept = function(model, look)
		part(model, "Sweep", Vector3.new(1.3, 0.5, 1.7), CFrame.new(-0.45, 3.78, -0.25) * rot(0, 0, 18), look.Hair)
		part(model, "Lock", Vector3.new(0.42, 1.3, 0.45), CFrame.new(-1.0, 2.7, -0.2), look.Hair)
		part(model, "Back", Vector3.new(1.6, 0.9, 0.4), CFrame.new(0.2, 3.1, 0.95) * rot(-20, 0, -10), look.Hair)
	end,
	Short = function(model, look)
		fringe(model, look)
	end,
}

local HEADWEAR: { [string]: (Model, Look) -> () } = {
	Headband = function(model, look)
		plate(model, "Band", 0.26, 2.2, Vector3.new(0, 3.28, 0), look.Trim)
		part(model, "Knot", Vector3.new(0.2, 0.7, 0.12), CFrame.new(0.25, 3.0, 1.12) * rot(0, 0, -25), look.Trim)
	end,
	Witch = function(model, look)
		plate(model, "Brim", 0.14, 3.3, Vector3.new(0, 3.98, 0), DARK)
		plate(model, "Band", 0.22, 1.75, Vector3.new(0, 4.15, 0), look.Trim, NEON)
		local base = CFrame.new(0, 4.1, 0.05) * rot(-12, 0, 0)
		for i, size in { 1.7, 1.25, 0.85, 0.45 } do
			part(model, "Cone", Vector3.new(0.5, size, size), base * CFrame.new(0, i * 0.42, 0) * LEVEL, DARK, nil, Enum.PartType.Cylinder)
		end
		ball(model, "Star", 0.3, (base * CFrame.new(0, 2.05, 0)).Position, look.Trim, NEON)
	end,
	Crown = function(model, look)
		plate(model, "Ring", 0.2, 1.3, Vector3.new(0, 4.05, 0), look.Trim, NEON)
		for i = 1, 5 do
			local angle = (i - 1) / 5 * math.pi * 2
			part(model, "Spike", Vector3.new(0.18, 0.5, 0.18), CFrame.new(math.cos(angle) * 0.55, 4.35, math.sin(angle) * 0.55), look.Trim, NEON)
		end
	end,
	Halo = function(model, look)
		for i = 1, 12 do
			local angle = (i - 1) / 12 * math.pi * 2
			part(model, "Halo", Vector3.new(0.2, 0.12, 0.2), CFrame.new(math.cos(angle) * 0.85, 4.55, math.sin(angle) * 0.85), look.Trim, NEON)
		end
	end,
	Horns = function(model, look)
		for _, side in { -1, 1 } do
			part(model, "Horn", Vector3.new(0.26, 0.95, 0.26), CFrame.new(side * 0.58, 4.12, 0) * rot(0, 0, side * -24), DARK)
			part(model, "Tip", Vector3.new(0.2, 0.3, 0.2), CFrame.new(side * 0.78, 4.55, 0) * rot(0, 0, side * -24), look.Trim, NEON)
		end
	end,
	Helmet = function(model, look)
		ball(model, "Helmet", 2.3, Vector3.new(0, 3.25, 0.1), METAL, Enum.Material.Metal)
		part(model, "Crest", Vector3.new(0.2, 0.6, 1.5), CFrame.new(0, 4.35, 0.1), look.Trim)
	end,
	Hood = function(model, look)
		ball(model, "Hood", 2.4, Vector3.new(0, 3.15, 0.3), look.Outfit)
	end,
	Straw = function(model, look)
		plate(model, "Brim", 0.14, 3.5, Vector3.new(0, 4.0, 0), Color3.fromRGB(196, 158, 92))
		plate(model, "Top", 0.45, 1.5, Vector3.new(0, 4.25, 0), Color3.fromRGB(176, 140, 80))
		plate(model, "Band", 0.14, 1.56, Vector3.new(0, 4.1, 0), look.Trim)
	end,
	Flower = function(model, look)
		for i, offset in { Vector3.new(0, 0, 0), Vector3.new(0.28, 0.12, 0.05), Vector3.new(0.1, -0.25, 0.05) } do
			ball(model, `Petal{i}`, 0.36, Vector3.new(0.85, 3.62, -0.42) + offset, Color3.fromRGB(255, 150, 200), NEON)
		end
	end,
	Glasses = function(model, look)
		for _, x in { -0.4, 0.4 } do
			disc(model, "Lens", 0.62, Vector3.new(x, 2.86, -1.09), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, 0.6)
		end
		part(model, "Bridge", Vector3.new(0.3, 0.06, 0.04), CFrame.new(0, 2.92, -1.1), DARK)
	end,
	Mask = function(model, look)
		part(model, "Mask", Vector3.new(1.62, 0.52, 0.5), CFrame.new(0, 2.45, -0.74), look.Trim)
	end,
}

local function hold(at: Vector3, tilt: number): CFrame
	return CFrame.new(at) * rot(0, 0, tilt)
end

local PROPS: { [string]: (Model, Look, Color3) -> () } = {
	Fists = function(model, look, color)
		for _, side in { -1, 1 } do
			ball(model, "Fist", 0.66, Vector3.new(side * 0.72, 1.55, -0.62), look.Skin)
			part(model, "Wrap", Vector3.new(0.5, 0.2, 0.5), CFrame.new(side * 0.72, 1.3, -0.62), WHITE)
		end
	end,
	Kunai = function(model, look, color)
		for _, side in { -1, 1 } do
			local grip = hold(Vector3.new(side * 0.98, 1.25, -0.45), side * -35)
			part(model, "Blade", Vector3.new(0.1, 0.75, 0.05), grip * CFrame.new(0, 0.55, 0), METAL, Enum.Material.Metal)
			part(model, "Ring", Vector3.new(0.18, 0.18, 0.05), grip * CFrame.new(0, -0.1, 0), color, NEON)
		end
	end,
	Sword = function(model, look, color)
		local grip = hold(Vector3.new(1.12, 1.05, -0.2), -24)
		part(model, "Blade", Vector3.new(0.16, 2.7, 0.06), grip * CFrame.new(0, 1.6, 0), METAL, Enum.Material.Metal)
		part(model, "Edge", Vector3.new(0.05, 2.6, 0.07), grip * CFrame.new(0.07, 1.6, 0), color, NEON)
		part(model, "Guard", Vector3.new(0.55, 0.12, 0.2), grip * CFrame.new(0, 0.25, 0), color)
		part(model, "Hilt", Vector3.new(0.12, 0.5, 0.12), grip, DARK)
	end,
	Katana = function(model, look, color)
		local grip = hold(Vector3.new(1.1, 1.0, -0.2), -30)
		part(model, "Blade", Vector3.new(0.12, 2.9, 0.05), grip * CFrame.new(0, 1.7, 0) * rot(0, 0, -3), METAL, Enum.Material.Metal)
		part(model, "Tsuba", Vector3.new(0.4, 0.08, 0.4), grip * CFrame.new(0, 0.25, 0), color, NEON)
		part(model, "Hilt", Vector3.new(0.12, 0.6, 0.12), grip, DARK)
		part(model, "Sheath", Vector3.new(0.16, 2.4, 0.16), CFrame.new(-0.75, 1.0, 0.45) * rot(20, 0, 60), DARK)
	end,
	Lance = function(model, look, color)
		local grip = hold(Vector3.new(1.12, 2.0, -0.15), -8)
		part(model, "Shaft", Vector3.new(0.14, 4.2, 0.14), grip, color)
		part(model, "Tip", Vector3.new(0.34, 0.9, 0.12), grip * CFrame.new(0, 2.5, 0) * rot(0, 0, 45), METAL, Enum.Material.Metal)
		part(model, "Tassel", Vector3.new(0.3, 0.3, 0.1), grip * CFrame.new(0, 1.95, 0), color, NEON)
	end,
	Bow = function(model, look, color)
		for i = -2, 2 do
			local angle = i * 22
			local at = Vector3.new(-1.25 - math.cos(math.rad(angle)) * 0.4 + 0.4, 1.9 + math.sin(math.rad(angle)) * 1.1, -0.4)
			part(model, "Limb", Vector3.new(0.14, 0.62, 0.14), CFrame.new(at) * rot(0, 0, angle), color)
		end
		part(model, "String", Vector3.new(0.03, 2.3, 0.03), CFrame.new(-0.9, 1.9, -0.4), WHITE, NEON)
	end,
	Staff = function(model, look, color)
		local grip = hold(Vector3.new(1.12, 1.8, -0.1), -6)
		part(model, "Shaft", Vector3.new(0.13, 3.6, 0.13), grip, Color3.fromRGB(120, 86, 60))
		ball(model, "Gem", 0.58, (grip * CFrame.new(0, 1.95, 0)).Position, color, NEON)
	end,
	Shield = function(model, look, color)
		disc(model, "Shield", 1.7, Vector3.new(-0.95, 1.4, -0.62), color)
		disc(model, "Rim", 1.85, Vector3.new(-0.95, 1.4, -0.58), DARK)
		ball(model, "Boss", 0.4, Vector3.new(-0.95, 1.4, -0.68), METAL, Enum.Material.Metal)
	end,
	TowerShield = function(model, look, color)
		part(model, "Shield", Vector3.new(1.35, 2.1, 0.25), CFrame.new(-0.95, 1.45, -0.7), METAL, Enum.Material.Metal)
		part(model, "CrossV", Vector3.new(0.18, 1.7, 0.27), CFrame.new(-0.95, 1.45, -0.72), color, NEON)
		part(model, "CrossH", Vector3.new(1.0, 0.18, 0.27), CFrame.new(-0.95, 1.7, -0.72), color, NEON)
	end,
	Drum = function(model, look, color)
		part(model, "Drum", Vector3.new(0.85, 1.15, 1.15), CFrame.new(0, 0.95, -0.85), color, nil, Enum.PartType.Cylinder)
		for _, side in { -1, 1 } do
			part(model, "Stick", Vector3.new(0.08, 0.9, 0.08), CFrame.new(side * 0.75, 1.45, -0.65) * rot(-30, 0, side * 30), Color3.fromRGB(200, 160, 110))
		end
	end,
	Fan = function(model, look, color)
		for i = -3, 3 do
			part(model, "Rib", Vector3.new(0.12, 0.95, 0.04), CFrame.new(1.0, 1.7, -0.62) * rot(0, 0, i * 16) * CFrame.new(0, 0.45, 0), color, if i % 2 == 0 then NEON else nil)
		end
	end,
	Book = function(model, look, color)
		part(model, "Book", Vector3.new(0.9, 1.05, 0.2), CFrame.new(1.05, 1.75, -0.62) * rot(0, -20, 0), DARK)
		part(model, "Page", Vector3.new(0.75, 0.9, 0.05), CFrame.new(1.02, 1.75, -0.74) * rot(0, -20, 0), color, NEON)
	end,
	Orb = function(model, look, color)
		ball(model, "Orb", 0.85, Vector3.new(1.15, 2.2, -0.55), color, NEON)
		ball(model, "Core", 0.4, Vector3.new(1.15, 2.2, -0.95), WHITE, NEON)
	end,
	Clock = function(model, look, color)
		disc(model, "Face", 1.3, Vector3.new(1.15, 2.2, -0.45), WHITE)
		disc(model, "Rim", 1.45, Vector3.new(1.15, 2.2, -0.42), color)
		part(model, "Hour", Vector3.new(0.08, 0.35, 0.04), CFrame.new(1.15, 2.35, -0.5), DARK)
		part(model, "Minute", Vector3.new(0.06, 0.5, 0.04), CFrame.new(1.28, 2.2, -0.5) * rot(0, 0, -60), DARK)
	end,
	Sun = function(model, look, color)
		local grip = hold(Vector3.new(1.12, 1.8, -0.1), -6)
		part(model, "Shaft", Vector3.new(0.13, 3.6, 0.13), grip, Color3.fromRGB(240, 220, 160))
		local top = (grip * CFrame.new(0, 2.0, 0)).Position
		ball(model, "Sun", 0.62, top, color, NEON)
		for i = 1, 6 do
			part(model, "Ray", Vector3.new(0.1, 0.5, 0.05), CFrame.new(top) * rot(0, 0, i * 60) * CFrame.new(0, 0.55, 0), color, NEON)
		end
	end,
	Blade = function(model, look, color)
		local grip = hold(Vector3.new(1.12, 1.05, -0.2), -24)
		part(model, "Blade", Vector3.new(0.3, 3.0, 0.08), grip * CFrame.new(0, 1.75, 0), Color3.fromRGB(28, 22, 40))
		part(model, "Edge", Vector3.new(0.06, 2.9, 0.09), grip * CFrame.new(0.15, 1.75, 0), color, NEON)
		part(model, "Guard", Vector3.new(0.7, 0.14, 0.22), grip * CFrame.new(0, 0.25, 0), color, NEON)
		part(model, "Hilt", Vector3.new(0.12, 0.5, 0.12), grip, DARK)
	end,
}

-- Builds the figure for a look. Its PrimaryPart is an invisible root at the waist.
function CardArt.Build(look: Look): Model
	local model = Instance.new("Model")
	model.Name = "CardArt"
	local root = part(model, "Root", Vector3.one, CFrame.new(0, 1.5, 0), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root

	body(model, look)
	if look.Style ~= "Bald" then
		ball(model, "HairCap", 2.24, Vector3.new(0, 3.2, 0.14), look.Hair)
	end
	local style = STYLES[look.Style]
	if style then
		style(model, look)
	end
	local headwear = look.Head and HEADWEAR[look.Head]
	if headwear then
		headwear(model, look)
	end
	local prop = look.Prop and PROPS[look.Prop]
	if prop then
		prop(model, look, look.PropColor or look.Trim)
	end
	if look.Aura then
		for i = 1, 14 do
			local angle = (i - 1) / 14 * math.pi * 2
			part(
				model,
				"Aura",
				Vector3.new(0.22, 0.22, 0.22),
				CFrame.new(math.cos(angle) * 1.9, 2.4 + math.sin(angle) * 1.9, 1.1) * rot(0, 0, math.deg(angle)),
				look.Aura,
				NEON
			)
		end
	end
	return model
end

-- Where the card camera sits for every figure (whole chibi body and prop in view).
CardArt.CameraCFrame = CFrame.lookAt(Vector3.new(1.1, 2.6, -7.4), Vector3.new(0, 2.25, 0))
CardArt.FieldOfView = 40

return CardArt
