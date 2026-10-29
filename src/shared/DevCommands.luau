--!strict
-- Pure argument checks for owner test tools. Authorization and rate limits stay on the server.
local Cards=require(script.Parent.Cards)
local Borders=require(script.Parent.Borders)
local Packs=require(script.Parent.Packs)
local Weather=require(script.Parent.Weather)
local Config=require(script.Parent.Config)
local Commands={}
function Commands.Number(value: any,low: number,high: number): number?
	local n=tonumber(value)
	if not n or n~=n or n==math.huge or n==-math.huge or n<low or n>high then return nil end
	return n
end
function Commands.Validate(action: any,value: any): any?
	if action=="GrantCard" and type(value)=="table" then
		local count=Commands.Number(value.Count,1,10000)
		if type(value.CardId)~="string" or not Cards.Get(value.CardId) or type(value.Border)~="string" or not Borders.ById[value.Border] or not count then return nil end
		return {CardId=value.CardId,Border=value.Border,Count=math.floor(count)}
	elseif action=="GrantResource" and type(value)=="table" then
		local amount=Commands.Number(value.Amount,1,1000000)
		if not amount or (value.Kind~="TraitShards" and value.Kind~="Fragments") then return nil end
		return {Kind=value.Kind,Amount=math.floor(amount)}
	elseif action=="GrantPack" and type(value)=="table" then
		local count=Commands.Number(value.Count,1,10000)
		local pack=if type(value.Id)=="string" then Packs.ById[value.Id] else nil
		if not pack or pack.Element or not count then return nil end
		return {Id=value.Id,Count=math.floor(count)}
	elseif action=="SetWeather" and type(value)=="table" then
		local seconds=Commands.Number(value.Seconds,30,900)
		if type(value.Id)~="string" or not Weather.ById[value.Id] or not seconds then return nil end
		return {Id=value.Id,Seconds=math.floor(seconds)}
	elseif action=="SetLevel" then
		local level=Commands.Number(value,1,100)
		return if level then {Level=math.floor(level)} else nil
	elseif action=="SetLuck" then
		local luck=Commands.Number(value,1,Config.Roll.DevLuckMax)
		return if luck then {Luck=luck} else nil
	elseif action=="GiveSkyItems" or action=="ClearBossCooldowns" or action=="ClearDevLuck" then
		return {}
	end
	return nil
end
return Commands
