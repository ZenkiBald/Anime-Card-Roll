--!nonstrict
-- PETS: rideable mounts. A tile per mount with its model turning in a ViewportFrame (one model each),
-- its speed and RIDE / RIDING / locked. G (or the HUD paw) rides the last mount or gets off. The server
-- does the riding (MountService); this plays the sitting pose while the character is mounted.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mounts = require(Shared.Mounts)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local Pets = {}

local SIT = { -- Roblox's own sitting animations
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}

local modal
local grid: Frame
local hint: (string) -> () = function() end
local tiles = {} -- [mountId] = refs
local spinning = {} -- { model, base } turning in the previews
local sitTrack: AnimationTrack? = nil

local function riding(): string?
	local character = Players.LocalPlayer.Character
	return character and character:GetAttribute("Mount")
end

local function unlocked(mount): boolean
	return Mounts.Unlocked(mount, (State.Progress and State.Progress.Cleared) or {})
end

function Pets.Ride(id: string?)
	if State.InBattle then
		return
	end
	if id then
		State.Mount = id
		Sfx.Play("Whoosh", 1.2)
	end
	Remotes.Mount:FireServer(id)
end

-- G: ride the last mount (or the first one you have), or get off.
function Pets.ToggleRide()
	if riding() then
		Pets.Ride(nil)
		return
	end
	local mount = Mounts.Get(State.Mount or "")
	if mount == nil or not unlocked(mount) then
		mount = Mounts.List[1]
	end
	Pets.Ride(mount.Id)
	hint(`Riding {mount.Name}  ·  G to get off`)
end

local function refresh()
	if not modal or not modal.IsOpen then
		return
	end
	local current = riding()
	for id, refs in tiles do
		local mount = Mounts.Get(id)
		local open = unlocked(mount)
		Kit.dimTile(refs.Tile, not open)
		refs.Lock.Visible = not open
		refs.Button.Visible = open
		refs.Button.Label.Text = if current == id then "GET OFF" else "RIDE"
		refs.Tile.UIStroke.Thickness = if current == id then 4 else 2.5
		refs.Tile.UIStroke.Color = if current == id then Theme.Color.Gold else mount.Accent
	end
end

local function preview(parent: Instance, mount)
	local kit = ReplicatedStorage:FindFirstChild("MountKit")
	local template = kit and kit:FindFirstChild(mount.Model)
	local viewport = Kit.new("ViewportFrame", {
		Name = "Preview",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.92, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 180, 210),
		LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = parent,
	})
	if template == nil then
		Kit.label({ Text = "🐾", Size = UDim2.fromScale(1, 1), Parent = viewport }, 60)
		return
	end
	-- Centre the model on the origin, turned to face forward; the camera looks at it from the front-left.
	local model = template:Clone()
	local box, size = model:GetBoundingBox()
	model:PivotTo(CFrame.Angles(0, math.rad(mount.Yaw or 0), 0) * box:Inverse() * model:GetPivot())
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local reach = math.max(size.X, size.Y, size.Z)
	-- Flat mounts (the Void Ray) are seen from higher up so their back shows.
	local high = if size.Y < reach * 0.3 then 1.4 else 0.55
	camera.CFrame = CFrame.lookAt(Vector3.new(reach * 1.1, reach * high, -reach * 1.5), Vector3.new(0, -size.Y * 0.05, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(spinning, { Model = model, Base = model:GetPivot() })
end

local function tile(mount, order: number)
	local frame = Kit.tile({ Name = mount.Id, LayoutOrder = order, Parent = grid }, mount.Accent)
	-- Soft disc of the mount's colour behind the model.
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.8, 0.42),
		BackgroundColor3 = mount.Accent,
		BackgroundTransparency = 0.8,
		Parent = frame,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height) })
	preview(frame, mount)
	local name = Kit.label({
		Text = mount.Name,
		Font = Theme.Font.Display,
		Position = UDim2.fromScale(0.05, 0.55),
		Size = UDim2.fromScale(0.9, 0.1),
		Parent = frame,
	}, 24)
	Kit.textStroke(Color3.fromRGB(30, 12, 70), 2, 0).Parent = name
	Kit.label({
		Text = `⚡ Speed {mount.Speed}`,
		Font = Theme.Font.Heavy,
		TextColor3 = mount.Accent:Lerp(Color3.new(1, 1, 1), 0.4),
		Position = UDim2.fromScale(0.05, 0.655),
		Size = UDim2.fromScale(0.9, 0.065),
		Parent = frame,
	}, 17)
	Kit.label({
		Text = mount.Text,
		Font = Theme.Font.Bold,
		TextColor3 = Color3.fromRGB(214, 200, 255),
		Position = UDim2.fromScale(0.06, 0.725),
		Size = UDim2.fromScale(0.88, 0.09),
		Parent = frame,
	}, 14)
	local button = Kit.button("RIDE", mount.Accent, mount.Accent:Lerp(Color3.new(0, 0, 0), 0.45), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.84, 0, 0.11, 0),
		ZIndex = 6,
		Parent = frame,
	})
	button.Activated:Connect(function()
		if riding() == mount.Id then
			Pets.Ride(nil)
		else
			Pets.Ride(mount.Id)
			Effects.Sparks(frame, mount.Accent, 14, 0.8)
		end
		task.delay(0.3, refresh)
	end)
	local lock = Kit.label({
		Text = `🔒 {Mounts.UnlockText(mount)}`,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.9, 0, 0.08, 0),
		ZIndex = 6,
		Parent = frame,
	}, 15)
	tiles[mount.Id] = { Tile = frame, Button = button, Lock = lock }
end

-- Sitting pose while mounted (our own character's animations replicate to everyone).
local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil then
		return
	end
	local function update()
		if sitTrack then
			sitTrack:Stop(0.2)
			sitTrack = nil
		end
		if character:GetAttribute("Mount") then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local animation = Instance.new("Animation")
				animation.AnimationId = SIT[humanoid.RigType] or SIT[Enum.HumanoidRigType.R15]
				local track = animator:LoadAnimation(animation)
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.2)
				sitTrack = track
			end
		end
		refresh()
	end
	character:GetAttributeChangedSignal("Mount"):Connect(update)
	update()
end

function Pets.Init(playerGui: Instance, showHint: (string) -> ())
	hint = showHint
	modal = Modal.new(playerGui, "PetsGui", "PETS", Vector2.new(0.86, 0.78), Vector2.new(1020, 560))
	Kit.label({
		Text = "Ride to get around faster  ·  G rides / gets off  ·  each world's boss unlocks a new mount",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(214, 200, 255),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = modal.Body,
	}, 16)
	grid = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	for i, mount in Mounts.List do
		tile(mount, i)
		tiles[mount.Id].Tile.Size = UDim2.new(1 / #Mounts.List, -10, 1, 0)
	end
	modal.OnOpen = refresh
	State.Changed:Connect(refresh)

	-- Previews turn slowly, only while the panel is open.
	RunService.RenderStepped:Connect(function()
		if not modal.IsOpen then
			return
		end
		local angle = os.clock() * 0.6
		for _, item in spinning do
			item.Model:PivotTo(CFrame.Angles(0, angle, 0) * item.Base)
		end
	end)

	-- Load every mount's mesh and texture now, so a mount shows the moment you get on it.
	task.spawn(function()
		local kit = ReplicatedStorage:WaitForChild("MountKit", 20)
		if kit then
			pcall(ContentProvider.PreloadAsync, ContentProvider, kit:GetDescendants())
		end
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

function Pets.Toggle()
	modal:Toggle()
end

return Pets
