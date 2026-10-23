--!strict
-- Town NPC services only work beside their NPC: Hoshi (fusion, pack alchemy), Kenshin (trait rolls) and
-- Madame Fortuna (the Lucky Wheel). World registers where each NPC stands as it builds them; the services
-- ask Near before they act, so a client can't fuse or spin from across the map. An NPC that was never
-- placed (no map, no marker) doesn't block anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcRange = {}

NpcRange.Range = 24 -- studs from the NPC's root (its prompt reaches 16; the rest is slack for lag)

local positions: { [string]: Vector3 } = {}

-- Also published as ReplicatedStorage attribute NpcSpot_<id> (streaming may not have the NPC on a
-- client yet), so the client can draw a waypoint to it (UI/Waypoint).
function NpcRange.Set(id: string, position: Vector3)
	positions[id] = position
	ReplicatedStorage:SetAttribute(`NpcSpot_{id}`, position)
end

function NpcRange.Near(player: Player, id: string): boolean
	local position: Vector3? = positions[id]
	if not position then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= NpcRange.Range
end

return NpcRange
