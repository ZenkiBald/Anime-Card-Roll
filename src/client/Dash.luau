--!nonstrict
-- Dash: Q (or the DASH touch button, or X on a gamepad) bursts the character forward the way it's
-- moving (or facing), with a light trail, a whoosh and a quick camera kick. Movement only, on the
-- player's own character (which the client already moves), so the server doesn't need a say.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Sfx = require(script.Parent.UI.Sfx)
local State = require(script.Parent.State)

local Dash = {}

local SPEED = 90 -- studs per second during the burst
local SECONDS = 0.18 -- burst length (about 16 studs)
local COOLDOWN = 1.2

local lastDash = -math.huge
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
	if State.InBattle or blocked() or os.clock() - lastDash < COOLDOWN then
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
	lastDash = os.clock()
	burst(root, move.Unit)
	Sfx.Play("Whoosh", 1.35)
	local camera = Workspace.CurrentCamera
	local fov = camera.FieldOfView
	Kit.tween(camera, 0.08, { FieldOfView = fov + 8 }).Completed:Connect(function()
		Kit.tween(camera, 0.3, { FieldOfView = fov })
	end)
	return Enum.ContextActionResult.Sink
end

-- `isBlocked` says when dashing is off (e.g. while the title screen is up).
function Dash.Start(isBlocked: (() -> boolean)?)
	if isBlocked then
		blocked = isBlocked
	end
	ContextActionService:BindAction("Dash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Dash", "DASH") -- the touch button sits by the jump button
end

return Dash
