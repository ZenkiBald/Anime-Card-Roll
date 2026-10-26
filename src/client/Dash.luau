--!nonstrict
-- Movement extras, on the player's own character (which the client already moves, so the server
-- doesn't need a say):
--   Dash: Q (or the DASH touch button, or X on a gamepad) bursts the character forward the way it's
--     moving (or facing), with a light trail, a whoosh and a quick camera kick. Two charges: dash twice
--     in a row (a double dash), then both come back COOLDOWN after the last one.
--   Double jump: jump again in mid-air (Space / the jump button / A) for a second jump with a ring of
--     light under the feet. It comes back on landing.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Sfx = require(script.Parent.UI.Sfx)
local State = require(script.Parent.State)

local Dash = {}

local SPEED = 90 -- studs per second during the burst
local SECONDS = 0.18 -- burst length (about 16 studs)
local COOLDOWN = 1.2 -- after the last dash, both charges are back
local CHARGES = 2 -- dashes in a row (double dash)
local CHAIN_GAP = 0.15 -- the second dash can't fire on the same press
local AIR_JUMP_POWER = 55 -- upward speed of the double jump
local AIR_JUMP_DELAY = 0.12 -- in the air this long before the double jump is ready (holding jump doesn't fire it)

local lastDash = -math.huge
local charges = CHARGES
local airJumpReady = false
local airJumped = false
local blocked: () -> boolean = function()
	return false
end

local function burst(root: BasePart, direction: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = math.huge
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis -- leaves falling and jumping alone
	push.PlaneVelocity = Vector2.new(direction.X, direction.Z) * SPEED
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Parent = root

	-- A short white-to-violet streak behind the character.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.25
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 92, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root

	task.delay(SECONDS, function()
		push:Destroy()
		attachment:Destroy()
	end)
	task.delay(SECONDS + 0.3, function()
		trail:Destroy()
		top:Destroy()
		bottom:Destroy()
	end)
end

local function onDash(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastDash >= COOLDOWN then
		charges = CHARGES
	end
	if State.InBattle or blocked() or charges <= 0 or now - lastDash < CHAIN_GAP then
		return Enum.ContextActionResult.Sink
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or humanoid.Health <= 0 or humanoid.Sit then
		return Enum.ContextActionResult.Sink
	end
	local move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if move.Magnitude < 0.1 then
		move = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if move.Magnitude < 0.1 then
		return Enum.ContextActionResult.Sink
	end
	lastDash = now
	charges -= 1
	burst(root, move.Unit)
	Sfx.Play("Whoosh", if charges == 0 then 1.55 else 1.35) -- the second dash sounds a little higher
	local camera = Workspace.CurrentCamera
	local fov = camera.FieldOfView
	Kit.tween(camera, 0.08, { FieldOfView = fov + 8 }).Completed:Connect(function()
		Kit.tween(camera, 0.3, { FieldOfView = fov })
	end)
	return Enum.ContextActionResult.Sink
end

-- A ring of light that spreads under the feet and fades (the double jump's kick-off).
local function jumpRing(root: BasePart)
	local ring = Instance.new("Part")
	ring.Name = "JumpRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(176, 92, 255)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	Kit.tween(ring, 0.35, { Size = Vector3.new(0.2, 9, 9), Transparency = 1 })
	task.delay(0.4, function()
		ring:Destroy()
	end)
end

local function onJumpRequest()
	if not airJumpReady or airJumped or State.InBattle or blocked() then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end
	airJumped = true
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, AIR_JUMP_POWER, velocity.Z)
	jumpRing(root)
	Sfx.Play("Whoosh", 1.7)
end

-- The double jump is ready a moment after leaving the ground, and comes back on landing.
local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	airJumpReady, airJumped = false, false
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Seated then
			airJumpReady, airJumped = false, false
		elseif new == Enum.HumanoidStateType.Freefall and not airJumpReady then
			task.delay(AIR_JUMP_DELAY, function()
				if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
					airJumpReady = true
				end
			end)
		end
	end)
end

-- `isBlocked` says when dashing and the double jump are off (e.g. while the title screen is up).
function Dash.Start(isBlocked: (() -> boolean)?)
	if isBlocked then
		blocked = isBlocked
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
	UserInputService.JumpRequest:Connect(onJumpRequest)
	Dash.SetBattleMode(false)
end

-- Unbind the touch action during fights; dashing is already disabled there.
function Dash.SetBattleMode(on: boolean)
	ContextActionService:UnbindAction("Dash")
	if not on then
		ContextActionService:BindAction("Dash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("Dash", "DASH")
	end
end

return Dash
