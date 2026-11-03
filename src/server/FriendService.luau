--!strict
-- Friend luck (2026-11-03): each player's "FriendsHere" attribute is how many of their Roblox friends are in
-- this server; Meta.FriendLuck turns it into a luck multiplier (MetaService.Luck, State.Luck). Friendship is
-- asked once per pair when the second of the two joins (Player:IsFriendsWith is a web call, so it is
-- pcall'd and cached); a failed check counts as not friends. Leaving recounts everyone left.

local Players = game:GetService("Players")

local FriendService = {}

local friends: { [string]: boolean } = {} -- ["lowId:highId"] = true

local function pairKey(a: Player, b: Player): string
	local x, y = a.UserId, b.UserId
	if x > y then
		x, y = y, x
	end
	return `{x}:{y}`
end

local function recount(player: Player)
	if player.Parent ~= Players then
		return
	end
	local n = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and friends[pairKey(player, other)] then
			n += 1
		end
	end
	player:SetAttribute("FriendsHere", n)
end

local function joined(player: Player)
	player:SetAttribute("FriendsHere", 0)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local key = pairKey(player, other)
				if friends[key] == nil then
					local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
					friends[key] = ok and result == true
				end
				recount(player)
				recount(other)
			end)
		end
	end
end

function FriendService.Start()
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(leaving: Player)
		for key in friends do
			local a, b = string.match(key, "^(%-?%d+):(%-?%d+)$")
			if tonumber(a) == leaving.UserId or tonumber(b) == leaving.UserId then
				friends[key] = nil
			end
		end
		task.defer(function()
			for _, player in Players:GetPlayers() do
				recount(player)
			end
		end)
	end)
end

return FriendService
