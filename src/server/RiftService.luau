--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Draft = require(ReplicatedStorage.Shared.RiftDraft)
local DataService = require(script.Parent.DataService)
local BattleService = require(script.Parent.BattleService)
local RateLimit = require(script.Parent.RateLimit)

local Service = {}
local limiter = RateLimit.new(4,6)
local rng = Random.new()

local function snapshot(data, ok: boolean, reason: string?): {[string]: any}
	local cards = {}
	local run = data.RiftDraft.Run
	if run and run.Phase=="Won" then
		for _, id in run.Team do cards[id]=DataService.CardState(data.Cards[id]) end
	end
	return {Ok=ok, Reason=reason, Book=data.RiftDraft, Cards=cards,
		HasTitle=data.Titles[Draft.Title]==true, Worn=data.Settings.Title==Draft.Title}
end

function Service.Start()
	ReplicatedStorage.Remotes.RiftDraft.OnServerInvoke = function(player: Player, action: unknown, value: unknown, revision: unknown): {[string]:any}
		if not limiter:Allow(player) then return {Ok=false, Reason="TooFast"} end
		local profile = DataService.Get(player)
		if not profile then return {Ok=false, Reason="Loading"} end
		local data = profile.Data
		if action=="Get" then return snapshot(data,true,nil) end
		if BattleService.InBattle(player) then return {Ok=false, Reason="InBattle"} end
		if type(revision)~="number" or type(action)~="string" then return {Ok=false, Reason="BadAction"} end
		if action=="Start" then
			if type(value)~="number" then return {Ok=false, Reason="BadAction"} end
		elseif action=="Play" or action=="Pick" then
			if type(value)~="string" or #value>40 then return {Ok=false, Reason="BadAction"} end
		elseif (action~="Retire" and action~="Wear") or value~=nil then return {Ok=false, Reason="BadAction"} end
		local ok, reason = Draft.Command(data,action,value,revision,rng)
		return snapshot(data,ok,reason)
	end
end
return Service
