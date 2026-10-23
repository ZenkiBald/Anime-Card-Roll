--!nonstrict
-- Follower pets: every character with a "Pet" attribute (set by MountService) has a small copy of
-- that mount trotting after it, hopping and turning to face the way it goes. Drawn on each client
-- (anchored, no collision, no physics), only for characters within range, and hidden while their
-- owner rides. Cheap on phones: one model per nearby player, moved once a frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mounts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Mounts"))

local Followers = {}

local SCALE = 0.42 -- of the ridden size
local RANGE = 140 -- studs from the camera
local BEHIND = 5 -- studs behind and to the side of the owner
local SIDE = 3.5

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
	local box, size = model:GetBoundingBox()
	-- Pivot at the model's base centre so placing it on the ground is one PivotTo.
	model.WorldPivot = box * CFrame.new(0, -size.Y / 2, 0)
	model.Parent = folder
	pets[character] = {
		Id = id,
		Model = model,
		Float = (mount.Float or 0) * SCALE + (if mount.Float then 1.5 else 0),
		CFrame = nil,
		Phase = math.random() * 10,
	}
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(position: Vector3, ignore): number?
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
	return hit and hit.Position.Y
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
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
				-- Aim for a spot behind and beside the owner; ease toward it.
				local goal = root.CFrame * CFrame.new(SIDE, 0, BEHIND)
				local current = pet.CFrame or goal
				local alpha = 1 - math.exp(-dt * 6)
				local position = current.Position:Lerp(goal.Position, alpha)
				local moved = position - current.Position
				local flat = Vector3.new(moved.X, 0, moved.Z)
				local look = if flat.Magnitude > 0.02 then flat.Unit else current.LookVector
				local ground = groundBelow(position, { character, folder }) or (root.Position.Y - 3)
				pet.CFrame = CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z))
				-- A little hop while it moves, a slow bob when it stands still.
				local speed = flat.Magnitude / math.max(dt, 1e-3)
				pet.Phase += dt * (if speed > 1 then 12 else 2)
				local hop = if speed > 1 then math.abs(math.sin(pet.Phase)) * 0.6 else math.sin(pet.Phase) * 0.12
				pet.Model:PivotTo(CFrame.new(position.X, ground + pet.Float + hop, position.Z) * pet.CFrame.Rotation)
			end
		end
	end
	for character in pets do
		if not seen[character] then
			clear(character)
		end
	end
end

function Followers.Start()
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = Workspace
	RunService.RenderStepped:Connect(step)
end

return Followers
