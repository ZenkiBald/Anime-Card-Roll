--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Collections = require(ReplicatedStorage.Shared.Collections)
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)
local NpcRange = require(script.Parent.NpcRange)
local Service = {}
local limiter = RateLimit.new(2,4)
function Service.Handle(player,action,id)
	if not limiter:Allow(player) then return {Ok=false,Reason="TooFast"} end
	local profile=DataService.Get(player)
	if not profile then return {Ok=false,Reason="Loading"} end
	local data=profile.Data
	if action=="Select" then
		if typeof(ReplicatedStorage:GetAttribute("NpcSpot_collector"))~="Vector3" or not NpcRange.Near(player,"collector") then return {Ok=false,Reason="TooFar"} end
		if type(id)~="string" or not Collections.Unlocked(id,data.Progress.Cleared) then return {Ok=false,Reason="Locked"} end
		data.SelectedCollection=id
	elseif action~="Get" then return {Ok=false,Reason="BadRequest"} end
	return {Ok=true,Selected=data.SelectedCollection,Progress=data.Progress}
end
function Service.Start()
	ReplicatedStorage.Remotes.Collection.OnServerInvoke=Service.Handle
end
return Service
