--!strict
-- Who may use the test tools (the DEV panel's Dev remote and mock Store purchases). Config.TestMode alone
-- isn't enough: a published game left in test mode would hand every player (and every exploit script)
-- free cards, luck and passes. Allowed only while Config.TestMode is on AND the player is in Studio, is
-- the game's owner (or holds rank Config.DevGroupRank+ in the owning group), or is listed in
-- Config.DevUserIds. Cached per player for the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DevAccess = {}

local cache: { [Player]: boolean } = {}

local function check(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.DevUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroupAsync, player, game.CreatorId)
	return ok and rank >= Config.DevGroupRank
end

function DevAccess.Allowed(player: Player): boolean
	if not Config.TestMode then
		return false
	end
	local known = cache[player]
	if known == nil then
		known = check(player)
		cache[player] = known
	end
	return known
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

return DevAccess
