--!nonstrict
-- Avatar auras: a character whose player wears a card as their avatar (EQUIP AS AVATAR in the DECK
-- inspector) glows in that card's element colour (a soft light and a few slow sparks). While walking, a
-- Rainbow-border avatar leaves fire footsteps and a Secret-border one sheds celestial motes. Drawn on each
-- client, only for characters near the camera: one light, one emitter and short-lived footstep parts each.
-- Where the look comes from, newest first: the local player's own prediction (Avatars.Predict, drawn the
-- moment EQUIP is tapped), the server's AuraReplication event (AvatarService fires it to everyone on a
-- change), then the character's AvatarElement / AvatarBorder attributes (for players already wearing one
-- when this client joined).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Elements = require(Shared.Elements)
local Cards = require(Shared.Cards)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Theme = require(script.Parent.UI.Theme)

local Avatars = {}

local RANGE = 120 -- studs from the camera
local STEP_EVERY = 0.28 -- seconds between fire footsteps
local CHECK_EVERY = 0.25

local folder: Folder
local auras = {} -- [character] = { Key, Attachment, Light, Sparks, Motes?, Border, NextStep, LeftFoot }
-- [character] = { Element = string?, Border = string } from the server event or a local prediction
-- (Element nil = no aura); wins over the attributes.
local overrides = {}

local function clear(character)
	local aura = auras[character]
	if aura then
		aura.Attachment:Destroy()
		auras[character] = nil
	end
end

local function build(character: Model, root: BasePart, element: string, border: string)
	clear(character)
	local info = Elements.Get(element)
	local color = if info then info.Color else Color3.new(1, 1, 1)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AvatarAura"
	attachment.Parent = root
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 9
	light.Shadows = false
	light.Parent = attachment
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(1, 1.6)
	sparks.Speed = NumberRange.new(1, 2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Rate = if Theme.FxLow then 3 else 6
	sparks.Parent = attachment
	local motes = nil
	if border == "Secret" then
		-- Celestial motes: white-gold stars that drift up and twinkle, only while walking.
		motes = Instance.new("ParticleEmitter")
		motes.Color = ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(170, 140, 255))
		motes.LightEmission = 1
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0) })
		motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		motes.Lifetime = NumberRange.new(1.4, 2.2)
		motes.Speed = NumberRange.new(0.5, 1.5)
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Acceleration = Vector3.new(0, 1.5, 0)
		motes.RotSpeed = NumberRange.new(-90, 90)
		motes.Rate = if Theme.FxLow then 8 else 18
		motes.Enabled = false
		motes.Parent = attachment
	end
	auras[character] = {
		Key = `{element}:{border}`,
		Attachment = attachment,
		Light = light,
		Sparks = sparks,
		Motes = motes,
		Border = border,
		Color = color,
		NextStep = 0,
		LeftFoot = false,
	}
end

-- A fire footstep: a small glowing ember disc where the foot lands, fading out in a second.
local function footstep(root: BasePart, humanoid: Humanoid, aura)
	local side = if aura.LeftFoot then -0.5 else 0.5
	aura.LeftFoot = not aura.LeftFoot
	local drop = humanoid.HipHeight + root.Size.Y / 2
	local spot = root.CFrame * CFrame.new(side, -drop + 0.05, 0)
	local part = Instance.new("Part")
	part.Name = "FireStep"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Cylinder
	part.Color = Color3.fromRGB(255, 130, 40)
	part.Size = Vector3.new(0.1, 0.9, 0.9)
	part.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = 0.15
	part.Parent = folder
	TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(0.1, 0.3, 0.3),
		Color = Color3.fromRGB(255, 60, 20),
	}):Play()
	Debris:AddItem(part, 1.1)
end

-- The aura a character should show: (element, border), element nil for none.
local function look(character: Model): (string?, string)
	local override = overrides[character]
	if override then
		return override.Element, override.Border
	end
	local element = character:GetAttribute("AvatarElement")
	local border = character:GetAttribute("AvatarBorder")
	return if type(element) == "string" then element else nil, if type(border) == "string" then border else "Normal"
end

local function override(character: Model?, cardId: string, border: string)
	if character == nil then
		return
	end
	local card = Cards.Get(cardId)
	overrides[character] = { Element = if card then card.Element else nil, Border = border }
	-- Redraw right away instead of on the next tick.
	local root = character:FindFirstChild("HumanoidRootPart")
	if card and root and root:IsA("BasePart") then
		build(character, root, card.Element, border)
	else
		clear(character)
	end
end

-- Client prediction: the local player's aura changes the moment EQUIP AS AVATAR is tapped (cardId "" =
-- take it off); the server's AuraReplication answer (or Avatars.Revert on a refusal) settles it.
function Avatars.Predict(cardId: string, border: string?)
	override(Players.LocalPlayer.Character, cardId, border or "Normal")
end

-- The server refused the equip: back to what the server last said.
function Avatars.Revert()
	local character = Players.LocalPlayer.Character
	if character then
		overrides[character] = nil
		clear(character)
	end
end

local function update(now: number)
	local camera = Workspace.CurrentCamera
	local seen = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root == nil or humanoid == nil then
			continue
		end
		local element, border = look(character)
		if element == nil then
			continue
		end
		if camera and (camera.CFrame.Position - root.Position).Magnitude > RANGE then
			continue
		end
		seen[character] = true
		local aura = auras[character]
		if aura == nil or aura.Key ~= `{element}:{border}` or aura.Attachment.Parent ~= root then
			build(character, root, element, border)
			aura = auras[character]
		end
		local walking = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Sit == false
		if aura.Motes then
			aura.Motes.Enabled = walking
		end
		if aura.Border == "Rainbow" and walking and now >= aura.NextStep then
			aura.NextStep = now + STEP_EVERY
			footstep(root, humanoid, aura)
		end
	end
	for character in auras do
		if not seen[character] then
			clear(character)
		end
	end
	for character in overrides do
		if character.Parent == nil then
			overrides[character] = nil -- respawned or left
		end
	end
end

function Avatars.Start()
	folder = Instance.new("Folder")
	folder.Name = "AvatarFx"
	folder.Parent = Workspace
	Remotes:WaitForChild("AuraReplication").OnClientEvent:Connect(function(character, cardId, border)
		if typeof(character) == "Instance" and character:IsA("Model") and type(cardId) == "string" and type(border) == "string" then
			override(character, cardId, border)
		end
	end)
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.07 -- footsteps need a finer step than the aura check
		local ok, err = pcall(update, now)
		if not ok then
			warn(`[Avatars] {err}`)
			nextCheck = now + CHECK_EVERY * 8
		end
	end)
end

return Avatars
