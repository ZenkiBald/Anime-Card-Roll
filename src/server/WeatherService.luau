--!nonstrict
-- Server-local summons override a deterministic shared natural schedule. No client supplies time or odds.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Weather=require(ReplicatedStorage.Shared.Weather)
local DataService=require(script.Parent.DataService)
local RateLimit=require(script.Parent.RateLimit)
local Service={}
local limiter=RateLimit.new(2,4)
local rng=Random.new()
local override=nil
local cooldownEnds=0
local extended={}
local extendedOrder={}
function Service.State()
	local now=workspace:GetServerTimeNow()
	local state=Weather.At(now,override)
	state.CooldownEnds=cooldownEnds
	state.Anchored=extended[state.Key]==true
	return state
end
function Service.Luck(): number return Service.State().Luck end
-- Called only by the authorized, rate-limited Dev remote; never a player weather action.
function Service.DevSet(id: string,seconds: number)
	local now=workspace:GetServerTimeNow()
	if id=="clear" then
		-- Suppress a natural event too, so Quiet Skies can actually be previewed.
		override={Id="clear",Key=`dev:{now}`,Starts=now,Ends=now+seconds,Summoned=false}
	else
		override={Id=id,Key=`dev:{now}`,Starts=now,Ends=now+seconds,Summoned=false}
	end
	cooldownEnds=0
end
function Service.Inventory(data)
	return {Fragments=data.Celestial.Fragments,Inventory=table.clone(data.Celestial.Inventory)}
end
local function publish()
	local state=Service.State()
	ReplicatedStorage:SetAttribute("WeatherId",state.Id)
	ReplicatedStorage:SetAttribute("WeatherEnds",state.Ends)
	ReplicatedStorage:SetAttribute("WeatherLuck",state.Luck)
	ReplicatedStorage.Remotes.WeatherState:FireAllClients(state)
end
function Service.Handle(player,action,id)
	if not limiter:Allow(player) then return {Ok=false,Reason="TooFast"} end
	local profile=DataService.Get(player)
	if not profile then return {Ok=false,Reason="Loading"} end
	local data=profile.Data
	local stock=data.Celestial.Inventory
	local now=workspace:GetServerTimeNow()
	local state=Service.State()
	if action=="Craft" then
		local cost=if type(id)=="string" then Weather.SigilCost(id) else nil
		if not cost then return {Ok=false,Reason="BadRequest"} end
		if data.Celestial.Fragments<cost then return {Ok=false,Reason="NoFragments"} end
		data.Celestial.Fragments-=cost
		stock[`sigil:{id}`]=(stock[`sigil:{id}`] or 0)+1
	elseif action=="Use" then
		if type(id)~="string" or (stock[id] or 0)<1 then return {Ok=false,Reason="NoItem"} end
		if id=="hourglass" then
			if state.Id=="clear" or extended[state.Key] then return {Ok=false,Reason="CannotExtend"} end
			extended[state.Key]=true
			table.insert(extendedOrder,state.Key)
			if #extendedOrder>64 then extended[table.remove(extendedOrder,1)]=nil end
			override=table.clone(state)
			override.Ends+=120
			if state.Summoned then cooldownEnds=override.Ends+300 end
		else
			if state.Id=="eclipse" then return {Ok=false,Reason="EclipseActive"} end
			if now<cooldownEnds or state.Summoned then return {Ok=false,Reason="Cooldown"} end
			local weather=if id=="orb" then Weather.Pick(rng:NextNumber()) else string.match(id,"^sigil:(.+)$")
			if not weather or not Weather.SigilCost(weather) then return {Ok=false,Reason="BadRequest"} end
			override={Id=weather,Key=`summon:{game.JobId}:{now}`,Starts=now,Ends=now+180,Summoned=true}
			cooldownEnds=override.Ends+300
			local announced=Service.State()
			announced.Announcement=`{player.DisplayName} summoned {Weather.ById[weather].Name}!`
			ReplicatedStorage.Remotes.WeatherState:FireAllClients(announced)
		end
		stock[id]-=1
		publish()
	elseif action~="Get" then return {Ok=false,Reason="BadRequest"} end
	return {Ok=true,State=Service.State(),Stock=Service.Inventory(data)}
end
function Service.Start()
	ReplicatedStorage.Remotes.Weather.OnServerInvoke=Service.Handle
	-- Refresh forecasts and natural transitions even when nobody requests a roll.
	task.spawn(function() while true do publish();task.wait(1) end end)
end
return Service
