--!nonstrict
-- Follower pets: every character with a "Pet" attribute (set by MountService) has a small copy of
-- that mount floating over its right shoulder: it eases after the owner, bobs (sin(t x 4) x 0.4 studs),
-- banks into turns and leans forward when the owner runs. Drawn on each client (anchored, no collision,
-- no physics), only for characters within range, and hidden while their owner rides.
-- Ridden mounts sway with their stride: the MountJoint (MountService) gets a pitch / roll / heave
-- Transform from the rider's speed, plus a bank into turns, so a mount never moves like a rigid brick.
-- Cheap on phones: one model per nearby player, moved once a frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mounts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Mounts"))

local Followers = {}

local SCALE = 0.24 -- of the ridden size: shoulder-sized
local RANGE = 140 -- studs from the camera
local SHOULDER = Vector3.new(2.4, 2.4, 0.6) -- right, up, back from the owner's root
local BOB = 0.4 -- studs
local BOB_SPEED = 4

local folder: Folder
local pets = {} -- [character] = { Id, Model, Height, CFrame, Phase }

local function clear(character)
	local pet = pets[character]
	if pet then
		pet.Model:Destroy()
		pets[character] = nil
	end
end

local function build(character, id: string)
	clear(character)
	local mount = Mounts.Get(id)
	local kit = ReplicatedStorage:FindFirstChild("MountKit")
	local template = mount and kit and kit:FindFirstChild(mount.Model)
	if template == nil then
		return
	end
	local model = template:Clone()
	model:ScaleTo(model:GetScale() * SCALE)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	local box = model:GetBoundingBox()
	-- Pivot at the model's centre: it floats, so it turns about its middle.
	model.WorldPivot = box
	model.Parent = folder
	pets[character] = {
		Id = id,
		Model = model,
		Position = nil, -- eased position
		Yaw = nil, -- eased facing (radians)
		Bank = 0,
		Lean = 0,
		Phase = math.random() * 10,
	}
end

-- Ridden mounts: stride phase per character.
local strides = {} -- [character] = { Phase, Bank, LastYaw }

local function yawOf(cframe: CFrame): number
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function angleDelta(a: number, b: number): number
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function strideMount(character: Model, root: BasePart, dt: number)
	local mount = character:FindFirstChild("Mount")
	local mountRoot = mount and mount:FindFirstChild("MountRoot")
	local joint = mountRoot and mountRoot:FindFirstChild("MountJoint")
	if joint == nil or not joint:IsA("Motor6D") then
		return
	end
	local state = strides[character]
	if state == nil then
		state = { Phase = 0, Bank = 0, LastYaw = yawOf(root.CFrame) }
		strides[character] = state
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local run = math.clamp(speed / 30, 0, 1)
	state.Phase += dt * (4 + speed * 0.35)
	local yaw = yawOf(root.CFrame)
	local turn = angleDelta(yaw, state.LastYaw) / math.max(dt, 1e-3) -- radians a second
	state.LastYaw = yaw
	state.Bank += (math.clamp(-turn * 0.05, -0.18, 0.18) - state.Bank) * math.min(1, dt * 6)
	local pitch = math.sin(state.Phase * 2) * 0.07 * run
	local roll = math.sin(state.Phase) * 0.05 * run + state.Bank
	local heave = math.abs(math.sin(state.Phase)) * 0.35 * run + math.sin(state.Phase * 0.5) * 0.05
	joint.Transform = CFrame.new(0, heave, 0) * CFrame.Angles(pitch, 0, roll)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local now = time()
	local seen = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local id = character and character:GetAttribute("Pet")
		if root and id and character:GetAttribute("Mount") == nil and (root.Position - eye).Magnitude < RANGE then
			seen[character] = true
			local pet = pets[character]
			if pet == nil or pet.Id ~= id then
				build(character, id)
				pet = pets[character]
			end
			if pet then
				-- Over the right shoulder; ease toward it so it trails a little when the owner moves.
				local goal = (root.CFrame * CFrame.new(SHOULDER)).Position
				local alpha = 1 - math.exp(-dt * 8)
				local before = pet.Position or goal
				local position = before:Lerp(goal, alpha)
				local yaw = yawOf(root.CFrame)
				local lastYaw = pet.Yaw or yaw
				local newYaw = lastYaw + angleDelta(yaw, lastYaw) * (1 - math.exp(-dt * 6))
				local turn = angleDelta(newYaw, lastYaw) / math.max(dt, 1e-3)
				local flat = Vector3.new(position.X - before.X, 0, position.Z - before.Z)
				local speed = flat.Magnitude / math.max(dt, 1e-3)
				-- Bank into turns, lean forward with speed (both eased).
				pet.Bank += (math.clamp(-turn * 0.12, -0.45, 0.45) - pet.Bank) * math.min(1, dt * 5)
				pet.Lean += (math.clamp(speed / 40, 0, 1) * 0.3 - pet.Lean) * math.min(1, dt * 4)
				pet.Position = position
				pet.Yaw = newYaw
				local bob = math.sin(now * BOB_SPEED + pet.Phase) * BOB
				pet.Model:PivotTo(CFrame.new(position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, newYaw, 0) * CFrame.Angles(-pet.Lean, 0, pet.Bank))
			end
		end
	end
	for character in pets do
		if not seen[character] then
			clear(character)
		end
	end
end

-- Mount strides run before each physics step, where joint Transforms belong.
local function strideStep(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and character:GetAttribute("Mount") ~= nil and (root.Position - eye).Magnitude < RANGE then
			strideMount(character, root, dt)
		end
	end
	for character in strides do
		if character.Parent == nil or character:GetAttribute("Mount") == nil then
			strides[character] = nil
		end
	end
end

function Followers.Start()
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = Workspace
	RunService.RenderStepped:Connect(step)
	RunService.PreSimulation:Connect(strideStep)
end

return Followers
