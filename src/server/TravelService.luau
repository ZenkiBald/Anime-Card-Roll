--!strict
-- Fast travel: the HUD's TRAVEL panel asks to jump to the town or to one of the boss zones.
-- The server picks the spot (in front of that zone's boss, or the spawn for the town) from the
-- map's Markers and moves the character; it refuses during a fight and when asked too often.
-- Destinations are "Town" or a boss id, so a new boss in Bosses.luau is a new stop for free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Bosses)
local RateLimit = require(script.Parent.RateLimit)
local BattleService = require(script.Parent.BattleService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TravelService = {}

local limiter = RateLimit.new(0.5, 2) -- a jump every 2 s, two in a row
local ARRIVE_DISTANCE = 16 -- studs in front of the boss, on the side away from its portal
local ROOT_HEIGHT = 3.5 -- HumanoidRootPart centre above the ground

local function markerPart(markers: Instance, name: string): BasePart?
	local marker = markers:FindFirstChild(name)
	return if marker and marker:IsA("BasePart") then marker else nil
end

-- Where `destination` puts the character (facing the boss), or nil when the map has no marker for it.
local function spotFor(destination: string): CFrame?
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	if markers == nil then
		return nil
	end
	if destination == "Town" then
		local spawn = markerPart(markers, "Spawn")
		return if spawn then spawn.CFrame + Vector3.new(0, ROOT_HEIGHT, 0) else nil
	end
	if Bosses.Get(destination) == nil then
		return nil
	end
	local bossMarker = markerPart(markers, `Boss_{destination}`)
	if bossMarker == nil then
		return nil
	end
	local bossAt = bossMarker.Position
	local portal = markerPart(markers, `Portal_{destination}`)
	local away = if portal then Vector3.new(bossAt.X - portal.Position.X, 0, bossAt.Z - portal.Position.Z) else Vector3.zero
	if away.Magnitude < 0.5 then
		away = Vector3.new(bossMarker.CFrame.LookVector.X, 0, bossMarker.CFrame.LookVector.Z)
	end
	local spot = bossAt + away.Unit * ARRIVE_DISTANCE
	-- Stand on whatever solid ground is there (terrain or a floor), not on a roof or the portal veil.
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local hub = workspace:FindFirstChild("Hub")
	params.FilterDescendantsInstances = if hub then { hub } else {}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(spot.X, bossAt.Y + 25, spot.Z), Vector3.new(0, -80, 0), params)
	local ground = if hit then hit.Position.Y else bossAt.Y
	local feet = Vector3.new(spot.X, ground + ROOT_HEIGHT, spot.Z)
	return CFrame.lookAt(feet, Vector3.new(bossAt.X, feet.Y, bossAt.Z))
end

local function travel(player: Player, destination: unknown)
	if type(destination) ~= "string" or #destination > 40 then
		return
	end
	if not limiter:Allow(player) or BattleService.InBattle(player) then
		return
	end
	local spot = spotFor(destination)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if spot == nil or character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	-- StreamingEnabled: send the destination to this player first, so they don't land in an empty world.
	pcall(function()
		player:RequestStreamAroundAsync(spot.Position, 5)
	end)
	if player.Character ~= character or player.Parent ~= Players or BattleService.InBattle(player) then
		return -- respawned, left or started a fight while the area loaded
	end
	humanoid.Sit = false
	character:PivotTo(spot)
end

function TravelService.Start()
	Remotes.Travel.OnServerEvent:Connect(travel)
end

-- Where a destination lands you (used to check the spots from Studio's command bar).
TravelService.SpotFor = spotFor

return TravelService
