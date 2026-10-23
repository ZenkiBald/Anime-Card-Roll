--!strict
-- Riding pets: the Mount remote asks to ride a mount (its id) or to get off (nil). The server checks
-- the mount is unlocked for this save, clones its model from ReplicatedStorage.MountKit, welds it under
-- the character (massless, no collision), lifts the rider into the seat and sets the mount's speed.
-- The character's "Mount" attribute tells clients to play the sitting pose; "Pet" names the mount that
-- follows it on foot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mounts = require(ReplicatedStorage.Shared.Mounts)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)

local MountService = {}

local limiter = RateLimit.new(1, 3)

local function humanoidOf(character: Model?): Humanoid?
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Gets off: removes the model and puts walk speed, jump and hip height back.
local function dismount(character: Model)
	local model = character:FindFirstChild("Mount")
	if model then
		model:Destroy()
	end
	local humanoid = humanoidOf(character)
	if humanoid and character:GetAttribute("Mount") then
		humanoid.HipHeight = humanoid:GetAttribute("BaseHipHeight") or humanoid.HipHeight
		humanoid.WalkSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 16
		humanoid.JumpPower = humanoid:GetAttribute("BaseJumpPower") or 50
		humanoid.JumpHeight = humanoid:GetAttribute("BaseJumpHeight") or 7.2
	end
	character:SetAttribute("Mount", nil)
end

local function ride(character: Model, mount: Mounts.Mount)
	local humanoid = humanoidOf(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = ReplicatedStorage:FindFirstChild("MountKit") and (ReplicatedStorage :: any).MountKit:FindFirstChild(mount.Model)
	if humanoid == nil or root == nil or not root:IsA("BasePart") or template == nil or humanoid.Health <= 0 then
		return
	end
	dismount(character)
	if humanoid:GetAttribute("BaseHipHeight") == nil then
		humanoid:SetAttribute("BaseHipHeight", humanoid.HipHeight)
		humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower)
		humanoid:SetAttribute("BaseJumpHeight", humanoid.JumpHeight)
	end
	-- Seat is the rider's hip height above the ground (the same for every avatar); R6 legs count
	-- towards it, R15 legs are part of HipHeight.
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local hip = math.max(0, mount.Seat + (mount.Float or 0) - legs)

	-- Copy the model and place it relative to the root as it will be once lifted (the weld keeps that
	-- offset): its base on the ground (or Float above it), facing the rider's way.
	local model = template:Clone()
	model.Name = "Mount"
	local box, size = model:GetBoundingBox()
	local ground = -(hip + legs + root.Size.Y / 2)
	local target = root.CFrame
		* CFrame.new(0, ground + (mount.Float or 0) + size.Y / 2, -(mount.Forward or 0))
		* CFrame.Angles(0, math.rad(mount.Yaw or 0), 0)
	local flat = CFrame.new(box.Position) * (box - box.Position)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = target * flat:ToObjectSpace(part.CFrame)
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
	humanoid.HipHeight = hip
	humanoid.WalkSpeed = mount.Speed
	humanoid.JumpPower = mount.Jump
	humanoid.JumpHeight = 7.2 * (mount.Jump / 50) ^ 2
	character:SetAttribute("Mount", mount.Id)
end

local function request(player: Player, id: unknown)
	if not limiter:Allow(player) then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	if id == nil or id == false then
		dismount(character)
		return
	end
	if type(id) ~= "string" then
		return
	end
	local mount = Mounts.Get(id)
	local profile = DataService.Get(player)
	if mount == nil or profile == nil or not Mounts.Unlocked(mount, profile.Data.Progress.Cleared) then
		return
	end
	ride(character, mount)
	profile.Data.Settings.Mount = mount.Id
	character:SetAttribute("Pet", mount.Id)
end

-- The character's "Pet" attribute is the mount that trots after it while it's on foot (clients draw
-- it, see Followers.luau): the last one ridden, if still unlocked, else the free one.
local function setPet(player: Player, character: Model)
	local profile = DataService.WaitFor(player)
	if profile == nil or player.Character ~= character then
		return
	end
	local mount = Mounts.Get(profile.Data.Settings.Mount or "")
	if mount == nil or not Mounts.Unlocked(mount, profile.Data.Progress.Cleared) then
		mount = Mounts.List[1]
	end
	character:SetAttribute("Pet", mount.Id)
end

function MountService.Start()
	Remotes.Mount.OnServerEvent:Connect(request)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			setPet(player, character)
		end)
		if player.Character then
			task.spawn(setPet, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			dismount(player.Character)
		end
	end)
end

return MountService
