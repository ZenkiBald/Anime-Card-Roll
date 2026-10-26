--!nonstrict
-- Stages a fight in 3D at the boss's own spot in its world (ReplicatedStorage.Arenas, set by World;
-- the server moves the streaming focus there for the fight): the leader where its NPC stands, its three
-- guards as smaller figures to its left, right and front, two braziers in the world's colour, and a low
-- cinematic camera looking up at the leader with depth of field. The leader is a View with the same
-- calls as ModelView (Kick / Lunge / Flash / SetTint), so the battle screen drives it the same way.
-- Everything here is client-side and goes away in Arena.Stop().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossModels = require(Shared.BossModels)
local Bosses = require(Shared.Bosses)

local Kit = require(script.Parent.Kit)
local ZoneFx = require(script.Parent.Parent.ZoneFx)

local Arena = {}

local GUARD_SCALE = 0.55
-- Where guards stand, in the leader's frame (it faces -Z): left, right, in front. Wide enough that their
-- tiles don't overlap from the battle camera; the front guard's tile hangs under its feet (FRONT), so it
-- never covers the leader or its plate.
-- The front guard stands a little off-centre so it never hides the leader from the camera.
local GUARD_SPOTS = { Vector3.new(-12, 0, -3), Vector3.new(12, 0, -3), Vector3.new(6, 0, -11) }
-- The leader towers over its guards and fills about half the screen's height (camera below).
local LEADER_SCALE = 1.45
local FRONT = 3
-- During a fight the place's bloom is turned down (the braziers and neon blew out the middle of the
-- screen); Stop puts it back.
local FIGHT_BLOOM = { Intensity = 0.3, Threshold = 2.4 }
local savedBloom: { Effect: BloomEffect, Intensity: number, Threshold: number }? = nil

local folder: Folder? = nil
local guis = {} -- BillboardGuis made for this fight
local figures = {} -- [enemyId] = { Model, Base, Height, Highlight, Tint, Kick, Lunge, Down }
local hidden = {} -- the world's own boss NPC and portal parts (and emitters), hidden during the fight
local dof: DepthOfFieldEffect? = nil
local stepConnection: RBXScriptConnection? = nil
local plate = nil -- the leader's name + HP plate

local function ground(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 25, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else position
end

local function figure(id: string, modelId: string, at: CFrame, scale: number, tint: Color3?)
	local model = BossModels.Build(modelId)
	local height = BossModels.Height(modelId) * scale
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	local base = at * CFrame.new(0, height / 2, 0)
	model:PivotTo(base)
	model.Parent = folder
	local highlight = Instance.new("Highlight")
	highlight.FillColor = tint or Color3.new(1, 1, 1)
	highlight.FillTransparency = if tint then 0.65 else 1
	highlight.OutlineColor = tint or Color3.new(0, 0, 0)
	highlight.OutlineTransparency = if tint then 0.3 else 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	figures[id] = {
		Model = model,
		Base = base,
		Height = height,
		Highlight = highlight,
		Tint = tint,
		Kick = 0,
		Lunge = 0,
		Down = 0,
		Phase = math.random() * 10,
	}
	return figures[id]
end

local function billboard(name: string, adornee: BasePart, size: UDim2, lift: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(guis, gui)
	return gui
end

-- Two braziers behind the leader in the world's colour (two lights only: cheap on phones).
local function brazier(at: CFrame, color: Color3)
	local bowl = Instance.new("Part")
	bowl.Name = "Brazier"
	bowl.Anchored = true
	bowl.CanCollide = false
	bowl.CanQuery = false
	bowl.Size = Vector3.new(1.6, 4, 1.6)
	bowl.CFrame = at * CFrame.new(0, 2, 0)
	bowl.Color = Color3.fromRGB(40, 34, 40)
	bowl.Material = Enum.Material.Slate
	bowl.Parent = folder
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Anchored = true
	flame.CanCollide = false
	flame.CanQuery = false
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(1.4, 1.4, 1.4)
	flame.CFrame = at * CFrame.new(0, 4.5, 0)
	flame.Color = color
	flame.Material = Enum.Material.Neon
	flame.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = flame
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(color)
	embers.LightEmission = 1
	embers.Rate = 10
	embers.Lifetime = NumberRange.new(1, 2)
	embers.Speed = NumberRange.new(2, 4)
	embers.SpreadAngle = Vector2.new(20, 20)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	embers.Parent = flame
end

-- The leader's compact plate: name and HP bar, in world space over its head.
local function makePlate(leader, name: string, accent: Color3)
	local gui = billboard("LeaderPlate", leader.Model.PrimaryPart, UDim2.fromOffset(210, 38), leader.Height / 2 + 3.5)
	local frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { Kit.corner(UDim.new(0, 5)), Kit.stroke(accent, 1.5, 0.2) })
	local label = Kit.label({
		Text = string.upper(name),
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0, 16),
		Parent = frame,
	}, 14)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.3).Parent = label
	local track = Kit.new("Frame", {
		Position = UDim2.new(0, 6, 1, -14),
		Size = UDim2.new(1, -12, 0, 8),
		BackgroundColor3 = Color3.fromRGB(4, 4, 10),
		ClipsDescendants = true,
		Parent = frame,
	}, { Kit.corner(UDim.new(1, 0)) })
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(220, 50, 60)), 0),
	})
	return { Fill = fill }
end

local function hideNpc(boss)
	local hub = Workspace:FindFirstChild("Hub")
	local area = hub and hub:FindFirstChild(`World{boss.World}`)
	-- The NPC, and the world's portal veil (a 36-stud neon plane right behind the boss's spot, which
	-- would flood the fight's backdrop).
	for _, name in { boss.Id, "Portal" } do
		local thing = area and area:FindFirstChild(name)
		if thing then
			for _, part in { thing, table.unpack(thing:GetDescendants()) } do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
					table.insert(hidden, part)
				elseif part:IsA("ParticleEmitter") and part.Enabled then
					part.Enabled = false
					table.insert(hidden, part)
				end
			end
		end
	end
end

-- The leader as a View (same calls as ModelView).
local View = {}
View.__index = View

function View:Kick(strength: number?)
	self.Figure.Kick = math.min(1.6, self.Figure.Kick + (strength or 1))
end

function View:Lunge()
	self.Figure.Lunge = 1
end

function View:Flash(color: Color3, seconds: number?)
	local highlight = self.Figure.Highlight
	highlight.FillColor = color
	highlight.FillTransparency = 0.25
	Kit.tween(highlight, seconds or 0.25, { FillTransparency = if self.Tint then 0.65 else 1 })
	task.delay(seconds or 0.25, function()
		if self.Tint then
			highlight.FillColor = self.Tint
		end
	end)
end

function View:SetTint(color: Color3)
	self.Tint = color
	local highlight = self.Figure.Highlight
	highlight.FillColor = color
	Kit.tween(highlight, 0.4, { FillTransparency = 0.65 })
end

function View:SetTurn(_degrees: number) end

export type Staged = {
	View: any, -- the leader (ModelView-like)
	LeaderGui: BillboardGui, -- sized to the leader: the battle's boss holder goes in here
	GuardGuis: { BillboardGui }, -- over each guard: the battle's guard tiles go in here
}

-- Stages the fight; nil when the boss has no spot in this place (the battle screen then keeps its
-- 2D view). `guards` are the squad's guards in slot order (left, right, front).
function Arena.Start(boss, guards: { any }, tint: Color3?, name: string?): Staged?
	Arena.Stop()
	local arenas = ReplicatedStorage:FindFirstChild("Arenas")
	local spot = arenas and arenas:FindFirstChild(boss.Id)
	local stand = spot and spot:GetAttribute("Stand")
	if typeof(stand) ~= "CFrame" then
		return nil
	end
	local made = Instance.new("Folder")
	made.Name = "BattleArena"
	made.Parent = Workspace
	folder = made
	hideNpc(boss)
	ZoneFx.MoodAt(stand.Position)

	local ignore = { made }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	local function onGround(offset: Vector3): CFrame
		local at = stand * CFrame.new(offset)
		local floor = ground(at.Position, ignore)
		return CFrame.new(floor) * at.Rotation
	end

	local leader = figure("Boss", boss.Id, onGround(Vector3.zero), LEADER_SCALE, tint)
	-- Sized in studs to the leader, so the boss holder's rings, taps and damage numbers sit on it.
	local leaderGui = billboard("LeaderStage", leader.Model.PrimaryPart, UDim2.fromScale(leader.Height * 0.95, leader.Height * 0.95), 0)
	plate = makePlate(leader, name or boss.Name, boss.Accent) -- a tower echo / Colossus shows its own name

	local guardGuis = {}
	for i, guard in guards do
		local offset = GUARD_SPOTS[i]
		if offset == nil then
			break
		end
		local g = Bosses.GuardTypes[guard.GuardId]
		local color = if g then g.Color else Color3.fromRGB(255, 90, 90)
		local fig = figure(guard.Id, boss.Id, onGround(offset), GUARD_SCALE, color)
		local lift = if i == FRONT then -(fig.Height / 2 + 2.2) else fig.Height / 2 + 2.4
		guardGuis[i] = billboard(`Guard{i}`, fig.Model.PrimaryPart, UDim2.fromOffset(150, 84), lift)
	end

	brazier(onGround(Vector3.new(-13, 0, 6)), boss.Accent)
	brazier(onGround(Vector3.new(13, 0, 6)), boss.Accent)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		savedBloom = { Effect = bloom, Intensity = bloom.Intensity, Threshold = bloom.Threshold }
		bloom.Intensity = math.min(bloom.Intensity, FIGHT_BLOOM.Intensity)
		bloom.Threshold = math.max(bloom.Threshold, FIGHT_BLOOM.Threshold)
	end

	-- Low cinematic camera in front of the squad, looking up at the leader, drifting slowly.
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- Framed so the leader spans the band between the boss bar (top ~20%) and the squad dock (lower 22%).
	camera.FieldOfView = 50
	-- Leader's feet at ~66% of the screen and head at ~25%, guards' feet above the dock.
	local front = leader.Base * CFrame.new(0, -leader.Height / 2, 0)
	local focus = (front * CFrame.new(0, leader.Height * 0.4, 0)).Position
	local eyeBase = (front * CFrame.new(0, leader.Height * 0.3, -(leader.Height * 2.6))).Position
	local effect = Instance.new("DepthOfFieldEffect")
	effect.Name = "BattleFocus"
	effect.FocusDistance = (focus - eyeBase).Magnitude
	effect.InFocusRadius = 16
	effect.NearIntensity = 0.5
	effect.FarIntensity = 0.35
	effect.Parent = Lighting
	dof = effect

	local start = os.clock()
	local side = front.RightVector
	stepConnection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(eyeBase + side * math.sin(t * 0.18) * 4, focus)
		for _, f in figures do
			f.Kick *= math.exp(-dt * 9)
			f.Lunge *= math.exp(-dt * 7)
			local bob = math.sin((t + f.Phase) * 2.1) * f.Height * 0.012
			local recoil = CFrame.new(0, 0, f.Height * 0.06 * f.Kick) * CFrame.Angles(math.rad(-6 * f.Kick), 0, 0)
			local lunge = CFrame.new(0, 0, -f.Height * 0.15 * f.Lunge)
			local sink = CFrame.new(0, -f.Height * 0.35 * f.Down, 0) * CFrame.Angles(math.rad(-50 * f.Down), 0, 0)
			f.Model:PivotTo(f.Base * CFrame.new(0, bob, 0) * lunge * recoil * sink)
		end
	end)

	local view = setmetatable({ Figure = leader, Tint = tint, Frame = Instance.new("Frame") }, View)
	return { View = view, LeaderGui = leaderGui, GuardGuis = guardGuis }
end

-- A guard (or the leader) recoils from a hit.
function Arena.Hit(id: string, crit: boolean?)
	local f = figures[id]
	if f and id ~= "Boss" then
		f.Kick = math.min(1.6, f.Kick + (if crit then 1.1 else 0.5))
		f.Highlight.FillTransparency = 0.3
		Kit.tween(f.Highlight, 0.25, { FillTransparency = 0.65 })
	end
end

-- A guard falls (or stands back up when it isn't down any more).
function Arena.SetDown(id: string, down: boolean)
	local f = figures[id]
	if f then
		local goal = if down then 1 else 0
		if f.Down ~= goal then
			f.Down = goal
			f.Highlight.FillColor = if down then Color3.fromRGB(20, 18, 26) else (f.Tint or Color3.new(1, 1, 1))
		end
	end
end

function Arena.SetLeaderHp(ratio: number)
	if plate then
		Kit.tween(plate.Fill, 0.15, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
	end
end

function Arena.Active(): boolean
	return folder ~= nil
end

function Arena.Stop()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	for _, gui in guis do
		gui:Destroy()
	end
	table.clear(guis)
	table.clear(figures)
	for _, thing in hidden do
		if thing:IsA("ParticleEmitter") then
			thing.Enabled = true
		else
			thing.LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	if dof then
		dof:Destroy()
		dof = nil
	end
	if savedBloom then
		savedBloom.Effect.Intensity = savedBloom.Intensity
		savedBloom.Effect.Threshold = savedBloom.Threshold
		savedBloom = nil
	end
	plate = nil
	if folder then
		folder:Destroy()
		folder = nil
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

return Arena
