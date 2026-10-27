--!nonstrict
-- A 3D figure (boss or NPC) inside a ViewportFrame: idle breathing, slow turn, recoil when hit
-- and colour flashes. One model per view, so it stays cheap on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossModels = require(Shared.BossModels)

local Kit = require(script.Parent.Kit)

local ModelView = {}
ModelView.__index = ModelView

export type View = {
	Frame: ViewportFrame,
	Kick: (self: View, strength: number?) -> (),
	Lunge: (self: View) -> (),
	Flash: (self: View, color: Color3, seconds: number?) -> (),
	SetTint: (self: View, color: Color3) -> (),
	SetTurn: (self: View, degrees: number) -> (),
}

-- turn: degrees of slow left-right sway (0 = always face the camera); spin = full turns per minute.
function ModelView.new(id: string, props: { [string]: any }?, turn: number?, spin: number?)
	local self = setmetatable({}, ModelView)
	local viewport = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 170),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		ImageColor3 = Color3.new(1, 1, 1),
	})
	if props then
		for key, value in props do
			viewport[key] = value
		end
	end
	self.Frame = viewport
	self.Tint = Color3.new(1, 1, 1)
	self.Turn = turn or 8
	self.Spin = spin or 0
	self.KickAmount = 0
	self.LungeAmount = 0

	local height = BossModels.Height(id)
	local model = BossModels.Build(id)
	model.Parent = viewport
	self.Model = model
	self.Base = CFrame.new(0, height / 2, 0)
	model:PivotTo(self.Base)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local _,bounds = model:GetBoundingBox()
	local function fitCamera()
		local size = viewport.AbsoluteSize
		local aspect = if size.Y > 0 and size.X > 0 then size.X / size.Y else 0.72
		local tangent = math.tan(math.rad(camera.FieldOfView / 2))
		-- Tails / wings can be wider than the character is tall. Frame both axes plus depth.
		local distance = math.max(height * 2.15, math.max(bounds.Y, bounds.X / aspect) * 0.56 / tangent + bounds.Z / 2)
		camera.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.62, -distance), Vector3.new(0, height * 0.5, 0))
	end
	fitCamera()
	local fitConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
	viewport.Destroying:Once(function() fitConnection:Disconnect() end)

	local start = os.clock()
	local phase = math.random() * 10
	self.Connection = RunService.RenderStepped:Connect(function(dt)
		if viewport.Parent == nil then
			self.Connection:Disconnect()
			return
		end
		if not viewport.Visible then
			return
		end
		local t = os.clock() - start + phase
		self.KickAmount *= math.exp(-dt * 9)
		self.LungeAmount *= math.exp(-dt * 7)
		local bob = math.sin(t * 2.1) * height * 0.012
		local yaw = math.rad(self.Turn) * math.sin(t * 0.6) + (t - phase) * self.Spin * math.pi / 30
		local recoil = CFrame.new(0, 0, height * 0.06 * self.KickAmount) * CFrame.Angles(math.rad(-6 * self.KickAmount), 0, 0)
		local lunge = CFrame.new(0, 0, -height * 0.12 * self.LungeAmount)
		model:PivotTo(self.Base * CFrame.new(0, bob, 0) * lunge * recoil * CFrame.Angles(0, yaw, 0))
	end)
	return self
end

-- Knocked back by a hit.
function ModelView:Kick(strength: number?)
	self.KickAmount = math.min(1.6, self.KickAmount + (strength or 1))
end

-- Lunges toward the camera (the boss attacking).
function ModelView:Lunge()
	self.LungeAmount = 1
end

function ModelView:Flash(color: Color3, seconds: number?)
	self.Frame.ImageColor3 = color
	Kit.tween(self.Frame, seconds or 0.25, { ImageColor3 = self.Tint })
end

-- Resting colour (e.g. red when enraged).
function ModelView:SetTint(color: Color3)
	self.Tint = color
	Kit.tween(self.Frame, 0.4, { ImageColor3 = color })
end

function ModelView:SetTurn(degrees: number)
	self.Turn = degrees
end

return ModelView
