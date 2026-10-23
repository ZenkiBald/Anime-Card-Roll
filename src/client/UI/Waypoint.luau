--!nonstrict
-- A guide line to a town NPC: a neon beam from your character to the NPC's spot (the server publishes
-- each NPC's spot as ReplicatedStorage attribute NpcSpot_<id>) and a marker over it with the name and
-- how far it is. It clears when you get there, after a couple of minutes, or when another one starts.
-- All local: one invisible anchored part, two attachments and a beam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local Waypoint = {}

local ARRIVE = 14 -- studs: close enough, the marker goes
local LIFETIME = 150 -- seconds

local marker: Part? = nil
local token = 0

function Waypoint.Clear()
	token += 1
	if marker then
		marker:Destroy()
		marker = nil
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = root and root:FindFirstChild("WaypointFrom")
	if from then
		from:Destroy()
	end
end

-- Guides the player to NPC `id` (NpcRange ids: "traitmaster", "fuser", "fortune", "sage"). Returns false
-- when that NPC has no spot in this place.
function Waypoint.To(id: string, label: string, color: Color3?): boolean
	local spot = ReplicatedStorage:GetAttribute(`NpcSpot_{id}`)
	if typeof(spot) ~= "Vector3" then
		return false
	end
	Waypoint.Clear()
	local tint = color or Theme.Color.Neon
	local part = Instance.new("Part")
	part.Name = "Waypoint"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = spot + Vector3.new(0, 2, 0)
	local to = Instance.new("Attachment")
	to.Parent = part
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(190, 44)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.LightInfluence = 0
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundColor3 = Theme.Color.Panel
	text.BackgroundTransparency = 0.2
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Theme.Font.Heavy
	text.TextScaled = true
	text.TextColor3 = tint
	text.Text = label
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = tint
	stroke.Thickness = 1.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = text
	local beam = Instance.new("Beam")
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(tint)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	beam.Parent = part
	part.Parent = Workspace
	marker = part

	token += 1
	local mine = token
	local started = os.clock()
	task.spawn(function()
		while mine == token and os.clock() - started < LIFETIME do
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				-- The beam starts at the character (made again after a respawn).
				local from = root:FindFirstChild("WaypointFrom")
				if from == nil then
					from = Instance.new("Attachment")
					from.Name = "WaypointFrom"
					from.Parent = root
				end
				beam.Attachment0 = from
				local distance = (root.Position - spot).Magnitude
				if distance < ARRIVE then
					break
				end
				text.Text = `{label}  ·  {math.floor(distance)} m`
			end
			task.wait(0.25)
		end
		if mine == token then
			Waypoint.Clear()
		end
	end)
	return true
end

return Waypoint
