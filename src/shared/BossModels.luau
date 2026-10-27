--!strict
-- NPC figures, shared so the hub NPCs and the battle screen's 3D boss portrait are the same model:
-- a sanitized Creator Store model from ReplicatedStorage.BossKit when available, otherwise a blocky figure
-- built from plain parts.
-- Models stand on y = 0 and face -Z; their PrimaryPart is an invisible "Root" at the waist.

local BossModels = {}
local Bosses = require(script.Parent.Bosses)

export type Look = {
	Scale: number,
	Skin: Color3,
	Body: Color3,
	Arms: Color3,
	Legs: Color3,
	Trim: Color3, -- neon accents
	Eyes: Color3,
}

local LOOKS: { [string]: Look } = {
	kurogane = {
		Scale = 1.7,
		Skin = Color3.fromRGB(214, 170, 132),
		Body = Color3.fromRGB(64, 60, 70),
		Arms = Color3.fromRGB(52, 48, 58),
		Legs = Color3.fromRGB(34, 30, 38),
		Trim = Color3.fromRGB(255, 104, 56),
		Eyes = Color3.fromRGB(255, 150, 60),
	},
	rimeveil = {
		Scale = 1.75,
		Skin = Color3.fromRGB(214, 232, 248),
		Body = Color3.fromRGB(110, 180, 236),
		Arms = Color3.fromRGB(188, 222, 246),
		Legs = Color3.fromRGB(70, 140, 220),
		Trim = Color3.fromRGB(150, 236, 255),
		Eyes = Color3.fromRGB(140, 240, 255),
	},
	vex = {
		Scale = 1.85,
		Skin = Color3.fromRGB(70, 60, 92),
		Body = Color3.fromRGB(26, 22, 36),
		Arms = Color3.fromRGB(34, 28, 46),
		Legs = Color3.fromRGB(20, 16, 28),
		Trim = Color3.fromRGB(220, 70, 255),
		Eyes = Color3.fromRGB(255, 90, 240),
	},
	tenrai = {
		Scale = 1.9,
		Skin = Color3.fromRGB(176, 188, 222),
		Body = Color3.fromRGB(32, 36, 74),
		Arms = Color3.fromRGB(44, 50, 96),
		Legs = Color3.fromRGB(24, 26, 52),
		Trim = Color3.fromRGB(255, 222, 70),
		Eyes = Color3.fromRGB(255, 244, 150),
	},
	sage = {
		Scale = 1,
		Skin = Color3.fromRGB(226, 186, 150),
		Body = Color3.fromRGB(70, 150, 120),
		Arms = Color3.fromRGB(60, 130, 104),
		Legs = Color3.fromRGB(46, 70, 66),
		Trim = Color3.fromRGB(255, 214, 120),
		Eyes = Color3.fromRGB(40, 30, 30),
	},
	fortune = { -- Madame Fortuna, keeper of the Lucky Wheel
		Scale = 1.05,
		Skin = Color3.fromRGB(240, 204, 176),
		Body = Color3.fromRGB(150, 40, 110),
		Arms = Color3.fromRGB(120, 30, 96),
		Legs = Color3.fromRGB(70, 20, 70),
		Trim = Color3.fromRGB(255, 210, 70),
		Eyes = Color3.fromRGB(60, 20, 60),
	},
	traitmaster = { -- Kenshin the Trait Master
		Scale = 1.1,
		Skin = Color3.fromRGB(230, 192, 160),
		Body = Color3.fromRGB(30, 90, 96),
		Arms = Color3.fromRGB(24, 74, 80),
		Legs = Color3.fromRGB(20, 44, 52),
		Trim = Color3.fromRGB(80, 230, 200),
		Eyes = Color3.fromRGB(30, 30, 40),
	},
	fuser = {
		Scale = 1.15,
		Skin = Color3.fromRGB(236, 196, 164),
		Body = Color3.fromRGB(96, 52, 160),
		Arms = Color3.fromRGB(76, 40, 132),
		Legs = Color3.fromRGB(48, 28, 84),
		Trim = Color3.fromRGB(255, 138, 61),
		Eyes = Color3.fromRGB(40, 30, 30),
	},
}

local function add(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder on its end

-- The shared body: legs, torso, arms, rounded head and glowing eyes.
local function body(model: Model, look: Look, skirt: boolean)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	if skirt then
		add(model, "Skirt", v(2.6, 2.1, 1.7), at(0, 1.05, 0), look.Legs)
		add(model, "Hem", v(2.7, 0.18, 1.8), at(0, 0.12, 0), look.Trim, Enum.Material.Neon)
	else
		add(model, "LeftLeg", v(0.95, 2, 1), at(-0.5, 1, 0), look.Legs)
		add(model, "RightLeg", v(0.95, 2, 1), at(0.5, 1, 0), look.Legs)
	end
	add(model, "Torso", v(2, 2, 1), at(0, 3, 0), look.Body)
	add(model, "LeftArm", v(1, 2, 1), at(-1.5, 3, 0), look.Arms)
	add(model, "RightArm", v(1, 2, 1), at(1.5, 3, 0), look.Arms)
	add(model, "LeftHand", v(0.9, 0.5, 0.9), at(-1.5, 1.85, 0), look.Skin)
	add(model, "RightHand", v(0.9, 0.5, 0.9), at(1.5, 1.85, 0), look.Skin)
	add(model, "Head", v(1.3, 1.3, 1.3), at(0, 4.62, 0), look.Skin, nil, Enum.PartType.Ball)
	add(model, "LeftEye", v(0.26, 0.14, 0.05), at(-0.27, 4.68, -0.64), look.Eyes, Enum.Material.Neon)
	add(model, "RightEye", v(0.26, 0.14, 0.05), at(0.27, 4.68, -0.64), look.Eyes, Enum.Material.Neon)
end

local function kurogane(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, false)
	-- Red sash, open robe collar, straw hat, katana at the hip.
	add(model, "Sash", v(2.06, 0.34, 1.06), at(0, 2.2, 0), look.Trim, Enum.Material.Neon)
	add(model, "Collar", v(0.5, 1.4, 0.05), at(0, 3.4, -0.52) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(150, 40, 30))
	add(model, "HatBrim", v(0.18, 3.6, 3.6), at(0, 5.28, 0) * FLAT, Color3.fromRGB(196, 158, 92), nil, Enum.PartType.Cylinder)
	add(model, "HatTop", v(0.55, 1.5, 1.5), at(0, 5.6, 0) * FLAT, Color3.fromRGB(176, 140, 80), nil, Enum.PartType.Cylinder)
	add(model, "HatBand", v(0.16, 1.56, 1.56), at(0, 5.42, 0) * FLAT, look.Trim, Enum.Material.Neon, Enum.PartType.Cylinder)
	local hip = at(-1.15, 2.2, -0.3) * CFrame.Angles(math.rad(-65), 0, math.rad(-10))
	add(model, "Hilt", v(0.22, 0.22, 1.1), hip * CFrame.new(0, 0, 0.9 * s), Color3.fromRGB(30, 26, 30))
	add(model, "Guard", v(0.5, 0.5, 0.1), hip * CFrame.new(0, 0, 0.32 * s), look.Trim, Enum.Material.Neon)
	add(model, "Blade", v(0.12, 0.26, 3.4), hip * CFrame.new(0, 0, -1.4 * s), Color3.fromRGB(210, 214, 224), Enum.Material.Metal)
	add(model, "Edge", v(0.06, 0.06, 3.3), hip * CFrame.new(0, -0.14 * s, -1.4 * s), look.Trim, Enum.Material.Neon)
end

local function rimeveil(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, true)
	-- Long frost hair, ice crown, shoulder shards, a staff of ice.
	add(model, "Hair", v(1.5, 2.2, 0.5), at(0, 4.1, 0.55), Color3.fromRGB(230, 244, 255))
	add(model, "Fringe", v(1.45, 0.4, 1.3), at(0, 5.2, 0.02), Color3.fromRGB(230, 244, 255))
	for i, x in { -0.5, -0.25, 0, 0.25, 0.5 } do
		local height = if i == 3 then 1.1 elseif i == 2 or i == 4 then 0.8 else 0.55
		add(model, `Crown{i}`, v(0.16, height, 0.16), at(x, 5.4 + height / 2, -0.1), look.Trim, Enum.Material.Neon)
	end
	for _, side in { -1, 1 } do
		add(
			model,
			"Shard",
			v(0.4, 1.3, 0.4),
			at(side * 1.75, 4.35, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			look.Trim,
			Enum.Material.Neon
		)
	end
	add(model, "Staff", v(0.18, 5.2, 0.18), at(2.15, 2.6, -0.3), Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
	add(model, "StaffGem", v(0.6, 0.9, 0.6), at(2.15, 5.5, -0.3) * CFrame.Angles(0, math.rad(45), 0), look.Trim, Enum.Material.Neon)
end

local function vex(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, false)
	-- Armour trims, pauldrons, a long cape and a halo of void shards.
	add(model, "ChestTrim", v(0.18, 1.8, 0.05), at(0, 3, -0.52), look.Trim, Enum.Material.Neon)
	add(model, "BeltTrim", v(2.06, 0.14, 1.06), at(0, 2.1, 0), look.Trim, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		add(model, "Pauldron", v(1.5, 0.6, 1.4), at(side * 1.6, 4.1, 0), Color3.fromRGB(40, 32, 56))
		add(model, "PauldronGlow", v(1.52, 0.12, 1.42), at(side * 1.6, 3.82, 0), look.Trim, Enum.Material.Neon)
	end
	add(model, "Cape", v(2.3, 3.8, 0.14), at(0, 2.5, 0.62), Color3.fromRGB(60, 16, 84))
	add(model, "Visor", v(1.2, 0.22, 0.08), at(0, 4.68, -0.66), look.Trim, Enum.Material.Neon)
	for i = 1, 8 do
		local angle = (i - 1) / 8 * math.pi * 2
		add(
			model,
			`Halo{i}`,
			v(0.32, 0.32, 0.32),
			at(math.cos(angle) * 1.25, 4.9 + math.sin(angle) * 1.25, 0.9) * CFrame.Angles(0, 0, angle),
			look.Trim,
			Enum.Material.Neon
		)
	end
end

local function tenrai(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, false)
	-- Storm armour: glowing chest bolt, horned crown, a cape of storm cloud, a halo of thunder drums
	-- behind him and a lightning spear.
	add(model, "Bolt", v(0.2, 1.4, 0.05), at(0.1, 3.05, -0.52) * CFrame.Angles(0, 0, math.rad(18)), look.Trim, Enum.Material.Neon)
	add(model, "Belt", v(2.06, 0.2, 1.06), at(0, 2.1, 0), look.Trim, Enum.Material.Neon)
	add(model, "Hair", v(1.5, 0.8, 1.45), at(0, 5.2, 0.12), Color3.fromRGB(235, 240, 255))
	add(model, "Crown", v(1.42, 0.24, 1.42), at(0, 5.0, 0), look.Trim, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		add(model, "Horn", v(0.22, 1.3, 0.22), at(side * 0.55, 5.75, -0.1) * CFrame.Angles(0, 0, math.rad(side * -22)), look.Trim, Enum.Material.Neon)
		add(model, "Pauldron", v(1.4, 0.55, 1.3), at(side * 1.6, 4.05, 0), Color3.fromRGB(56, 62, 110))
	end
	add(model, "Cape", v(2.5, 4, 0.16), at(0, 2.6, 0.62), Color3.fromRGB(70, 74, 96))
	for i = 1, 6 do
		local angle = (i - 1) / 6 * math.pi * 2
		add(
			model,
			`Drum{i}`,
			v(0.35, 0.75, 0.75),
			at(math.cos(angle) * 1.9, 4.2 + math.sin(angle) * 1.9, 1.1) * CFrame.Angles(0, math.rad(90), 0),
			if i % 2 == 0 then look.Trim else Color3.fromRGB(150, 60, 50),
			if i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	add(model, "Spear", v(0.2, 6.2, 0.2), at(2.1, 3, -0.35), Color3.fromRGB(60, 64, 90), Enum.Material.Metal)
	add(model, "SpearTip", v(0.5, 1.3, 0.12), at(2.1, 6.6, -0.35) * CFrame.Angles(0, 0, math.rad(12)), look.Trim, Enum.Material.Neon)
end

local function sage(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, true)
	-- White beard, round hat, a glowing card in hand.
	add(model, "Beard", v(0.9, 0.9, 0.3), at(0, 4.05, -0.6), Color3.fromRGB(240, 240, 236))
	add(model, "Hat", v(0.5, 1.7, 1.7), at(0, 5.3, 0) * FLAT, Color3.fromRGB(60, 50, 40), nil, Enum.PartType.Cylinder)
	add(model, "HatBand", v(0.14, 1.74, 1.74), at(0, 5.12, 0) * FLAT, look.Trim, Enum.Material.Neon, Enum.PartType.Cylinder)
	add(model, "Card", v(0.7, 1, 0.06), at(1.5, 1.9, -0.6) * CFrame.Angles(0, 0, math.rad(-12)), look.Trim, Enum.Material.Neon)
end

local function fuser(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, true)
	-- Leather apron, wild white hair with fusion goggles, and a burning orb held out with two cards
	-- melting into it.
	add(model, "Apron", v(1.6, 2.6, 0.08), at(0, 2.2, -0.56), Color3.fromRGB(70, 44, 32))
	add(model, "ApronTrim", v(1.64, 0.14, 0.1), at(0, 3.45, -0.57), look.Trim, Enum.Material.Neon)
	add(model, "Hair", v(1.55, 0.7, 1.45), at(0, 5.25, 0.08), Color3.fromRGB(245, 245, 250))
	add(model, "Tuft", v(0.5, 0.6, 0.5), at(0.3, 5.7, 0.1) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(245, 245, 250))
	add(model, "GoggleBand", v(1.38, 0.2, 1.38), at(0, 5.0, 0), Color3.fromRGB(40, 30, 30))
	for _, side in { -1, 1 } do
		add(model, "Goggle", v(0.42, 0.42, 0.12), at(side * 0.3, 5.02, -0.68), look.Trim, Enum.Material.Neon)
	end
	add(model, "Orb", v(1.1, 1.1, 1.1), at(0, 2.5, -1.35), look.Trim, Enum.Material.Neon, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		add(
			model,
			"FuseCard",
			v(0.55, 0.8, 0.05),
			at(side * 0.8, 2.6, -1.3) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Color3.fromRGB(190, 120, 255),
			Enum.Material.Neon
		)
	end
end

local function fortune(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, true)
	-- Long dark hair under a headscarf with a coin band, a gold shawl, and a crystal ball held in
	-- both hands.
	local hair = Color3.fromRGB(46, 24, 52)
	add(model, "Hair", v(1.5, 2.4, 0.5), at(0, 3.95, 0.55), hair)
	for _, side in { -1, 1 } do
		add(model, "Lock", v(0.32, 1.6, 0.4), at(side * 0.62, 4.0, -0.25), hair)
	end
	add(model, "Scarf", v(1.48, 0.55, 1.42), at(0, 5.12, 0.02), look.Body)
	add(model, "ScarfTail", v(0.5, 1.4, 0.12), at(0.35, 4.6, 0.72) * CFrame.Angles(0, 0, math.rad(-10)), look.Body)
	for i = -2, 2 do
		local coin = at(i * 0.28, 4.88, -0.72) * CFrame.Angles(0, math.rad(90), 0)
		add(model, "Coin", v(0.06, 0.2, 0.2), coin, look.Trim, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	add(model, "Shawl", v(2.12, 0.5, 1.12), at(0, 3.8, 0), look.Trim)
	-- The ball floats a little in front of her, glowing from inside.
	add(model, "Ball", v(1.15, 1.15, 1.15), at(0, 2.5, -1.15), Color3.fromRGB(170, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
	add(model, "BallGlow", v(0.6, 0.6, 0.6), at(0, 2.5, -1.15), Color3.fromRGB(200, 120, 255), Enum.Material.Neon, Enum.PartType.Ball)
end

-- Kenshin the Trait Master: a long topknot, a glowing sash, and a floating trait sigil over an open
-- scroll.
local function traitmaster(model: Model, look: Look)
	local s = look.Scale
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	body(model, look, true)
	local hair = Color3.fromRGB(28, 24, 36)
	add(model, "Hair", v(1.45, 0.55, 1.4), at(0, 5.15, 0.06), hair)
	add(model, "Topknot", v(0.45, 0.9, 0.45), at(0, 5.75, 0.3), hair)
	add(model, "Sash", v(1.7, 0.3, 1.1), at(0, 2.75, 0) * CFrame.Angles(0, 0, math.rad(-8)), look.Trim, Enum.Material.Neon)
	add(model, "Scroll", v(1.5, 0.06, 0.9), at(0, 2.3, -1.2) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(240, 226, 190))
	add(model, "Sigil", v(0.7, 0.7, 0.7), at(0, 3.4, -1.3) * CFrame.Angles(math.rad(45), 0, math.rad(45)), look.Trim, Enum.Material.Neon)
end

local BUILDERS: { [string]: (Model, Look) -> () } = {
	traitmaster = traitmaster,
	kurogane = kurogane,
	rimeveil = rimeveil,
	vex = vex,
	tenrai = tenrai,
	sage = sage,
	fuser = fuser,
	fortune = fortune,
}

function BossModels.Has(id: string): boolean
	return LOOKS[id] ~= nil or Bosses.GuardTypes[id] ~= nil
end

function BossModels.Height(id: string): number
	local look = LOOKS[id]
	return (if look then look.Scale else 1) * 6
end

-- Sanitized figures in the Rojo-managed BossKit asset (named by id) replace
-- the block figures: scaled to the same height, standing on y = 0 facing -Z, with the same invisible
-- Root at the waist, so the hub NPCs and the battle view use them the same way.
local function fromKit(id: string, look: Look): Model?
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local kit = ReplicatedStorage:FindFirstChild("BossKit")
	local template = kit and kit:FindFirstChild(id)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.Name = id
	-- Defense in depth: model assets are visual data, never a way to distribute executable scripts.
	for _,inst in model:GetDescendants() do
		if inst:IsA("LuaSourceContainer") or inst:IsA("LayerCollector") or inst:IsA("RemoteEvent")
			or inst:IsA("RemoteFunction") or inst:IsA("PackageLink") or inst:IsA("Sound")
			or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
			inst:Destroy()
		elseif inst:IsA("Humanoid") then
			-- Retain clothing / rig appearance without the character controller restoring torso collisions.
			inst.EvaluateStateMachine=false
			inst.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
			inst.BreakJointsOnDeath=false
		end
	end
	-- A rig with a face (a Head with a Decal) is turned so the face looks along the pivot's front:
	-- inserted characters often come saved facing backwards.
	local head = model:FindFirstChild("Head", true)
	if not model:GetAttribute("CanonicalFacing") and head and head:IsA("BasePart") and head:FindFirstChildWhichIsA("Decal") then
		local facing = head.CFrame.LookVector * Vector3.new(1, 0, 1)
		if facing.Magnitude > 0.1 then
			model.PrimaryPart = nil
			local pivot = model:GetPivot()
			model.WorldPivot = CFrame.lookAt(pivot.Position, pivot.Position + facing.Unit)
		end
	end
	local height = look.Scale * 6
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / size.Y)
	local box, scaled = model:GetBoundingBox()
	-- Feet on y = 0, centred on the Y axis.
	model:PivotTo(CFrame.new(0, scaled.Y / 2, 0) * box:Inverse() * model:GetPivot())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local root = add(model, "Root", Vector3.new(1, 1, 1) * look.Scale, CFrame.new(0, height / 2, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root
	return model
end

-- Builds the figure for a boss id (or "sage" / "fuser"). Unknown ids get a plain figure.
function BossModels.Build(id: string): Model
	local guard = Bosses.GuardTypes[id]
	local look = LOOKS[id] or LOOKS.sage
	if guard then
		local colors = {
			{ Color3.fromRGB(45,35,39), Color3.fromRGB(176,55,43), Color3.fromRGB(235,190,151) },
			{ Color3.fromRGB(154,204,231), Color3.fromRGB(230,242,249), Color3.fromRGB(221,231,240) },
			{ Color3.fromRGB(49,32,66), Color3.fromRGB(112,61,142), Color3.fromRGB(190,176,196) },
			{ Color3.fromRGB(33,49,75), Color3.fromRGB(211,172,73), Color3.fromRGB(218,205,187) },
		}
		local palette = colors[guard.World]
		look = { Scale=1, Skin=palette[3], Body=palette[1], Arms=palette[1], Legs=palette[2], Trim=guard.Color, Eyes=guard.Color }
		local model = Instance.new("Model"); model.Name = guard.Name
		body(model, look, guard.Role == "Mender" or guard.Role == "Hexer")
		-- Classic Roblox faces and real hair silhouettes keep the retinue readable as characters.
		local head = model:FindFirstChild("Head") :: Part
		head.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Head; mesh.Parent = head
		local face = Instance.new("Decal"); face.Name="Face"; face.Texture="rbxasset://textures/face.png"; face.Face=Enum.NormalId.Front; face.Parent=head
		for _, name in {"LeftEye","RightEye"} do local eye=model:FindFirstChild(name);if eye then eye:Destroy() end end
		local root = add(model,"Root",Vector3.one,CFrame.new(0,3,0),look.Body); root.Transparency=1;model.PrimaryPart=root
		local hair = if guard.World == 1 then Color3.fromRGB(24,22,28) elseif guard.World == 2 then Color3.fromRGB(230,239,245) else Color3.fromRGB(35,30,42)
		add(model,"Hair",Vector3.new(1.45,0.4,1.4),CFrame.new(0,5.25,0),hair)
		add(model,"BackHair",Vector3.new(1.4,if guard.Role=="Mender" then 1.8 else 0.9,0.35),CFrame.new(0,if guard.Role=="Mender" then 4.25 else 4.65,0.65),hair)
		add(model,"Fringe",Vector3.new(0.5,0.65,0.2),CFrame.new(-0.4,4.95,-0.66)*CFrame.Angles(0,0,-0.3),hair)
		if guard.World == 1 then
			add(model,"ShinobiHeadband",Vector3.new(1.38,0.25,0.12),CFrame.new(0,4.99,-0.67),Color3.fromRGB(165,172,182),Enum.Material.Metal)
			add(model,"ClanSash",Vector3.new(2.1,0.25,1.08),CFrame.new(0,2.15,0),palette[2])
			add(model,"ClanFan",Vector3.new(0.6,0.6,0.12),CFrame.new(0,3.4,-0.56),palette[2],nil,Enum.PartType.Ball)
			add(model,"ClanFanHandle",Vector3.new(0.12,0.4,0.12),CFrame.new(0,3.03,-0.59),Color3.fromRGB(225,222,210))
			if guard.Role == "Mender" then add(model,"CrowCloak",Vector3.new(2.3,2.6,0.25),CFrame.new(0,2.8,0.7),hair) end
		elseif guard.World == 2 then
			for _,x in {-0.5,0,0.5} do add(model,"IceCrest",Vector3.new(0.22,0.9,0.22),CFrame.new(x,5.6,0),guard.Color,Enum.Material.Glass) end
			add(model,"BattleArmor",Vector3.new(2.15,1.2,0.25),CFrame.new(0,3.35,-0.6),palette[2])
		elseif guard.World == 3 then
			add(model,"VoidCape",Vector3.new(2.2,3,0.18),CFrame.new(0,3,0.65),palette[1])
			add(model,"VoidBlade",Vector3.new(0.15,3,0.25),CFrame.new(1.8,2.3,-0.4),Color3.fromRGB(200,210,225),Enum.Material.Metal)
		else
			add(model,"LeftHorn",Vector3.new(0.22,0.85,0.22),CFrame.new(-0.55,5.45,0)*CFrame.Angles(0,0,0.3),palette[2])
			add(model,"RightHorn",Vector3.new(0.22,0.85,0.22),CFrame.new(0.55,5.45,0)*CFrame.Angles(0,0,-0.3),palette[2])
			if guard.Role == "Striker" or guard.Role == "Mender" then
				add(model,"StormSpear",Vector3.new(0.16,4.5,0.16),CFrame.new(1.9,2.5,-0.4),Color3.fromRGB(130,139,155),Enum.Material.Metal)
				add(model,"SpearTip",Vector3.new(0.5,0.9,0.5),CFrame.new(1.9,5.15,-0.4)*CFrame.Angles(0,0,math.rad(45)),palette[2])
			end
		end
		if guard.Role == "Warder" then
			for _,x in {-1.5,1.5} do add(model,"Pauldron",Vector3.new(1.3,0.8,1.3),CFrame.new(x,3.9,0),palette[2]) end
		elseif guard.Role == "Mender" then
			add(model,"MedicinePack",Vector3.new(1.8,1.5,0.7),CFrame.new(0,3,0.9),palette[2])
		elseif guard.Role == "Hexer" then
			add(model,"FocusOrb",Vector3.new(0.6,0.6,0.6),CFrame.new(-1.5,1.7,-0.7),guard.Color,Enum.Material.Neon,Enum.PartType.Ball)
		else add(model,"ArmGuard",Vector3.new(1.08,1,1.1),CFrame.new(1.5,2.7,0),palette[2]) end
		return model
	end
	local made = fromKit(id, look)
	if made then
		return made
	end
	local model = Instance.new("Model")
	model.Name = id
	local root = add(model, "Root", Vector3.new(1, 1, 1) * look.Scale, CFrame.new(0, 3 * look.Scale, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root
	local build: (Model, Look) -> () = BUILDERS[id] or sage
	build(model, look)
	return model
end

return BossModels
