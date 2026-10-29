--!strict
-- Pure global schedule. Slot hashes vary both the weather and its start within each 15-minute slot.
local Weather = {}
Weather.SlotSeconds = 900
Weather.ForecastSeconds = 150
Weather.Seed = 731947
Weather.List = {
	{ Id="clear", Name="Quiet Skies", Luck=0, Seconds=0, Color=Color3.fromRGB(130,210,255) },
	{ Id="rain", Name="Limitbreak Skies", Series="Dragon Ball", Luck=0.5, Seconds=300, Color=Color3.fromRGB(75,170,255) },
	{ Id="blizzard", Name="Soulfall", Series="Bleach", Luck=1, Seconds=300, Color=Color3.fromRGB(160,235,255) },
	{ Id="thunder", Name="Cursed Night", Series="Jujutsu Kaisen", Luck=1, Seconds=300, Color=Color3.fromRGB(175,120,255) },
	{ Id="eclipse", Name="Blood Moon", Series="Demon Slayer", Luck=2, Seconds=180, Color=Color3.fromRGB(255,80,115) },
}
Weather.ById = {} :: {[string]: any}
for _, def in Weather.List do Weather.ById[def.Id]=def end
-- Mix twice: adjacent slots must not march through nearly identical values.
local function randomAt(slot: number, salt: number): number
	local n=(slot % 10000019)+Weather.Seed+salt*104729
	n=(n*48271)%2147483647; n=(n*48271)%2147483647; n=(n*48271)%2147483647
	return n/2147483647
end
function Weather.Event(slot: number): any
	local roll=randomAt(slot,1)
	local id=if roll<0.30 then "rain" elseif roll<0.50 then "blizzard" elseif roll<0.70 then "thunder" elseif roll<0.73 then "eclipse" else "clear"
	local start=slot*Weather.SlotSeconds+150+math.floor(randomAt(slot,2)*360)
	return { Id=id, Key=`natural:{slot}`, Starts=start, Ends=start+Weather.ById[id].Seconds, Summoned=false }
end
function Weather.At(now: number, override: any?): any
	local slot=math.floor(now/Weather.SlotSeconds)
	local event=Weather.Event(slot)
	local active=event.Id~="clear" and now>=event.Starts and now<event.Ends
	local state: any=if active then table.clone(event) else {Id="clear",Key=`clear:{slot}`,Starts=slot*900,Ends=(slot+1)*900, Summoned=false}
	if override and Weather.ById[override.Id] and now>=override.Starts and now<override.Ends then state=table.clone(override) end
	state.Luck=Weather.ById[state.Id].Luck
	for nextSlot=slot,slot+16 do
		local nextEvent=Weather.Event(nextSlot)
		if nextEvent.Id~="clear" and nextEvent.Starts>now then
			state.Next=nextEvent
			state.Forecast=nextEvent.Starts-now<=Weather.ForecastSeconds
			break
		end
	end
	return state
end
Weather.OrbOdds = { {Id="rain",Chance=0.45}, {Id="blizzard",Chance=0.25}, {Id="thunder",Chance=0.25}, {Id="eclipse",Chance=0.05} }
function Weather.Pick(roll: number): string
	for _, option in Weather.OrbOdds do roll-=option.Chance; if roll<0 then return option.Id end end
	return "eclipse"
end
function Weather.SigilCost(id: string): number?
	return if id=="clear" or not Weather.ById[id] then nil elseif id=="eclipse" then 25 else 10
end
Weather.Items={
	{Id="orb",Name="Celestial Orb",Text="Summon a random sky for 3 minutes on this server. Limitbreak Skies 45%, Soulfall 25%, Cursed Night 25%, Blood Moon 5%.",Art="Potion:mythic"},
	{Id="hourglass",Name="Celestial Hourglass",Text="Extend the active weather by 2 minutes. Only one extension per weather; cannot be used during Quiet Skies.",Art="Artifact:hourglass"},
} :: {any}
for _,def in Weather.List do
	if def.Id~="clear" then
		table.insert(Weather.Items,{Id=`sigil:{def.Id}`,Name=`{def.Name} Sigil`,Weather=def.Id,Text=`Summon {def.Name} for 3 minutes on this server. Craft with {Weather.SigilCost(def.Id)} Celestial Fragments.`,Art=if def.Id=="rain" then "Artifact:prism" elseif def.Id=="blizzard" then "Artifact:frostsigil" elseif def.Id=="thunder" then "Artifact:stormcrown" else "Artifact:voideye"})
	end
end
return Weather
