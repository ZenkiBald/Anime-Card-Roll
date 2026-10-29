--!nonstrict
-- Stages a fight in 3D at the boss's own spot in its world (ReplicatedStorage.Arenas, set by World;
-- the server moves the streaming focus there for the fight): the leader where its NPC stands, its three
-- guards as smaller figures to its left, right and front, two braziers in the world's colour, and a low
-- cinematic camera looking up at the leader with depth of field. The leader is a View with the same
-- calls as ModelView (Kick / Lunge / Flash / SetTint), so the battle screen drives it the same way.
-- Each guard is tied to the leader by a pulsing link beam in its role's colour (Warder blue shield link,
-- Mender green mend, Striker red, Hexer violet); the link fades when the guard falls.
-- Everything here is client-side and goes away in Arena.Stop().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossModels = require(Shared.BossModels)
local arenaHidden = false
local compactMode = false

local Kit = require(script.Parent.Kit)
local ZoneFx = require(script.Parent.Parent.ZoneFx)

local Arena = {}

local GUARD_SCALE = 0.55
-- Where guards stand, in the leader's frame (it faces -Z): left, right, and the third in front-right, a
-- little off-centre so it never hides the leader. Every guard's tile hangs over its head: the third used to
-- stand far in front with its tile under its feet, and the squad dock covered it (playtest 2026-10-26).
local GUARD_SPOTS = { Vector3.new(-12, 0, -3), Vector3.new(12, 0, -3), Vector3.new(7, 0, -6) }
-- The leader towers over its guards and fills about half the screen's height (camera below).
local LEADER_SCALE = 1.45
local TweenService = game:GetService("TweenService")
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
local shake = { Power = 0, Until = 0 } -- camera shake on boss skills and crits (studs of jitter)

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
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	figures[id] = {
		Model = model,
		Base = base,
		Height = height,
		Highlight = highlight,
		Tint = tint,
		Kick = 0,
		Lunge = 0,
		Down = 0, -- 0 standing .. 1 toppled (eases toward DownGoal)
		DownGoal = 0,
		Parts = parts, -- faded out as it falls
		Faded = 0,
		Phase = math.random() * 10,
	}
	return figures[id]
end

-- Role colours for the guard -> leader links.
local LINK_COLORS = {
	Warder = Color3.fromRGB(110, 190, 255),
	Mender = Color3.fromRGB(90, 255, 160),
	Striker = Color3.fromRGB(255, 90, 80),
	Hexer = Color3.fromRGB(200, 110, 255),
}

-- A Beam from a guard's chest to the leader's: two Attachments and a plain (untextured) beam that
-- breathes in width. Cleaned up with the figures' folder.
local function link(guard, leader, role: string?)
	local from, to = guard.Model.PrimaryPart, leader.Model.PrimaryPart
	if from == nil or to == nil then
		return nil
	end
	local color = LINK_COLORS[role or ""] or Color3.new(1, 1, 1)
	local a0 = Instance.new("Attachment")
	a0.Name = "LinkFrom"
	a0.Position = Vector3.new(0, guard.Height * 0.1, 0)
	a0.Parent = from
	local a1 = Instance.new("Attachment")
	a1.Name = "LinkTo"
	a1.Position = Vector3.new(0, leader.Height * 0.05, 0)
	a1.Parent = to
	local beam = Instance.new("Beam")
	beam.Name = "GuardLink"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.CurveSize0, beam.CurveSize1 = 2, -2
	beam.Width0, beam.Width1 = 0.35, 0.5
	beam.Segments = 12
	beam.Parent = from
	TweenService:Create(beam, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Width0 = 0.6, Width1 = 0.9 }):Play()
	return beam
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
	return { Fill = fill, Gui = gui }
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
	arenaHidden = false
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
	local hub = Workspace:FindFirstChild("Hub")
	local world = hub and hub:FindFirstChild("World" .. tostring(boss.World))
	local npc = world and world:FindFirstChild(boss.Id)
	-- An imported rig can have collidable torso parts even while hidden for the cinematic.
	if npc then table.insert(ignore, npc) end
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
		local fig = figure(guard.Id, guard.GuardId, onGround(offset), GUARD_SCALE, nil)
		fig.Link = link(fig, leader, guard.Role)
		local lift = fig.Height / 2 + 2.4
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
		if arenaHidden then return end
		local t = os.clock() - start
		local eye = eyeBase + side * math.sin(t * 0.18) * 4
		if os.clock() < shake.Until then
			local p = shake.Power * math.clamp((shake.Until - os.clock()) / 0.35, 0, 1)
			eye += Vector3.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, (math.random() - 0.5) * p)
		end
		camera.CFrame = CFrame.lookAt(eye, focus)
		for _, f in figures do
			f.Kick *= math.exp(-dt * 9)
			f.Lunge *= math.exp(-dt * 7)
			-- A defeated figure topples back and sinks over ~0.35 s, fading out as it goes.
			if f.Down ~= f.DownGoal then
				local step = dt / 0.35
				f.Down = if f.DownGoal > f.Down then math.min(f.DownGoal, f.Down + step) else math.max(f.DownGoal, f.Down - step)
				local fade = f.Down * 0.85
				if math.abs(fade - f.Faded) > 0.01 or f.Down == f.DownGoal then
					f.Faded = fade
					for _, part in f.Parts do
						part.LocalTransparencyModifier = fade
					end
				end
			end
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

-- Effects (all client-side, plain neon Parts tweened and destroyed: about three per attack, no textures).

local function fxPart(name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	part.Parent = folder
	return part
end

local function fade(part: BasePart, seconds: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	local tween = TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

-- Where a figure's chest is (the beam's end), or nil.
local function chest(id: string): Vector3?
	local f = figures[id]
	if f == nil or f.Model.Parent == nil then
		return nil
	end
	return f.Model:GetPivot().Position + Vector3.new(0, f.Height * 0.1, 0)
end

-- A point a few studs in front of the camera under a screen position (viewport pixels).
local function fromScreen(at: Vector2, depth: number): Vector3
	local ray = Workspace.CurrentCamera:ViewportPointToRay(at.X, at.Y)
	return ray.Origin + ray.Direction * depth
end

-- An impact: a neon flash that swells and fades, plus two crossing slashes facing the camera.
function Arena.Impact(id: string, color: Color3, big: boolean?)
	local at = chest(id)
	if folder == nil or at == nil then
		return
	end
	local f = figures[id]
	local size = f.Height * (if big then 0.5 else 0.3)
	local flash = fxPart("Impact", Vector3.one * size * 0.4, CFrame.new(at), color, Enum.PartType.Ball)
	flash.Transparency = 0.2
	fade(flash, 0.28, Vector3.one * size)
	local face = CFrame.lookAt(at, Workspace.CurrentCamera.CFrame.Position)
	for i, angle in { 35, -30 } do
		local cut = fxPart("Slash", Vector3.new(0.25, 0.25, 0.1), face * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(0, 0, -0.5), color:Lerp(Color3.new(1, 1, 1), 0.5))
		task.delay((i - 1) * 0.05, function()
			if cut.Parent then
				fade(cut, 0.22, Vector3.new(size * 1.6, 0.18, 0.1))
			end
		end)
	end
end

-- A beam from a card slot on screen (viewport pixels) to a figure: a glowing bolt flies there and bursts.
function Arena.Beam(from: Vector2, toId: string, color: Color3, thick: number?, big: boolean?)
	local target = chest(toId)
	if folder == nil or target == nil then
		return
	end
	local start = fromScreen(from, 6)
	local width = (thick or 6) / 20
	local bolt = fxPart("Beam", Vector3.new(width, width, 2.5), CFrame.lookAt(start, target), color)
	local tween = TweenService:Create(bolt, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.lookAt(target, target + (target - start).Unit),
		Size = Vector3.new(width, width, 5),
	})
	tween.Completed:Connect(function()
		bolt:Destroy()
		Arena.Impact(toId, color, big)
	end)
	tween:Play()
end

-- The other way: a figure's strike flying at a card slot on screen (boss and guard attacks).
function Arena.Strike(fromId: string, to: Vector2, color: Color3)
	local start = chest(fromId)
	if folder == nil or start == nil then
		return
	end
	local finish = fromScreen(to, 6)
	local bolt = fxPart("Strike", Vector3.new(0.35, 0.35, 3), CFrame.lookAt(start, finish), color)
	local tween = TweenService:Create(bolt, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.lookAt(finish, finish + (finish - start).Unit),
	})
	tween.Completed:Connect(function()
		fade(bolt, 0.12)
	end)
	tween:Play()
end

-- A guard lunges at the squad as it attacks (the leader's lunge is View:Lunge).
function Arena.Lunge(id: string)
	local f = figures[id]
	if f then
		f.Lunge = 1
	end
end

-- Shakes the battle camera (boss skills, crits). Overlapping shakes keep the strongest.
function Arena.Shake(power: number, seconds: number)
	if folder == nil then
		return
	end
	local now = os.clock()
	if now >= shake.Until or power >= shake.Power then
		shake.Power = power
	end
	shake.Until = math.max(shake.Until, now + seconds)
end

-- A guard (or the leader) recoils from a hit.
function Arena.Hit(id: string, crit: boolean?)
	local f = figures[id]
	if f and id ~= "Boss" then
		f.Kick = math.min(1.6, f.Kick + (if crit then 1.1 else 0.5))
		-- A white hit-flash, then back to the guard's tint.
		f.Highlight.FillColor = Color3.new(1, 1, 1)
		f.Highlight.FillTransparency = if crit then 0.1 else 0.3
		Kit.tween(f.Highlight, 0.25, { FillTransparency = 0.65 })
		task.delay(0.12, function()
			if f.DownGoal == 0 then
				f.Highlight.FillColor = f.Tint or Color3.new(1, 1, 1)
			end
		end)
	end
end

-- A guard (or the leader, at the end) topples and fades in a dark red, or stands back up when revived.
function Arena.SetDown(id: string, down: boolean)
	local f = figures[id]
	if f then
		local goal = if down then 1 else 0
		if f.DownGoal ~= goal then
			f.DownGoal = goal
			if f.Link then
				f.Link.Enabled = not down -- a fallen guard's link snaps
			end
			if down then
				f.Highlight.FillColor = Color3.fromRGB(120, 14, 24)
				f.Highlight.FillTransparency = 0.2
				f.Highlight.OutlineColor = Color3.fromRGB(60, 0, 10)
				Kit.tween(f.Highlight, 0.35, { FillTransparency = 0.55 })
				Arena.Impact(id, Color3.fromRGB(150, 20, 40), true)
			else
				f.Highlight.FillColor = f.Tint or Color3.new(1, 1, 1)
				f.Highlight.FillTransparency = if f.Tint then 0.65 else 1
				f.Highlight.OutlineColor = f.Tint or Color3.new(0, 0, 0)
			end
		end
	end
end

function Arena.SetLeaderHp(ratio: number)
	if plate then
		Kit.tween(plate.Fill, 0.15, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
	end
end

function Arena.SetCompact(on: boolean)
	compactMode = on
	if plate then
		plate.Gui.Enabled = not on and not arenaHidden -- the screen's boss bar already carries the name and HP
	end
end

function Arena.Active(): boolean
	return folder ~= nil
end

function Arena.SetHidden(on: boolean)
	arenaHidden = on
	if folder then folder.Parent = if on then nil else Workspace end
	for _, g in guis do g.Enabled = not on end
	if plate then plate.Gui.Enabled = not on and not compactMode end
	if dof then dof.Enabled = not on end
	local camera = Workspace.CurrentCamera
	camera.CameraType = if on then Enum.CameraType.Custom else if folder then Enum.CameraType.Scriptable else Enum.CameraType.Custom
	camera.FieldOfView = if on or not folder then 70 else 50
	if on and Players.LocalPlayer.Character then camera.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end
	if savedBloom then
		savedBloom.Effect.Intensity = if on then savedBloom.Intensity else math.min(savedBloom.Intensity, FIGHT_BLOOM.Intensity)
		savedBloom.Effect.Threshold = if on then savedBloom.Threshold else math.max(savedBloom.Threshold, FIGHT_BLOOM.Threshold)
	end
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
	shake.Power, shake.Until = 0, 0
	if folder then
		folder:Destroy()
		folder = nil
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

return Arena
