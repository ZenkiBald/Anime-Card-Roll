-- Collection eligibility and natural weather must be deterministic, not client clock dependent.
do
	local C,W=MODULES.Collections,MODULES.Weather
	check(not C.Unlocked("galactic",{}) and C.Unlocked("galactic",{["kurogane:Normal"]=true}),"collection unlock follows earned boss progress")
	local pool=C.Pool("chakra",{})
	local family=true
	for _,card in pool do family=family and C.CardFamily[card.Id]=="chakra" end
	check(family and #pool>0,"Chakra pack has only its familiar characters and Supports before boss unlocks")
	local unlocked=C.Pool("chakra",{["rimeveil:Normal"]=true})
	local boss=false
	for _,card in unlocked do if card.Id=="rimeveil_card" then boss=true end end
	check(boss,"unlocked boss cards remain available beside any selected collection")
	check(#C.Pool("invalid",{})==#C.Pool("normal",{}),"invalid collection falls back to the normal pool")
	local drift,previous=false,nil
	local eclipses=0
	for slot=1900000,1901000 do
		local e=W.Event(slot)
		local offset=e.Starts-slot*900
		drift=drift or (previous~=nil and offset~=previous)
		previous=offset
		if e.Id=="eclipse" then eclipses+=1 end
		if e.Id~="clear" then
			local state=W.At(e.Starts+1)
			check(state.Id==e.Id and state.Key==W.At(e.Starts+1).Key,"natural weather agrees for identical server time")
			-- Only one sample needs the boundary assertions; keep test output compact.
			check(W.At(e.Starts-1).Id=="clear" and W.At(e.Ends).Id=="clear","weather eligibility uses exact active boundaries")
			break
		end
	end
	for slot=1900000,1901000 do local e=W.Event(slot);if e.Id=="eclipse" then eclipses+=1 end;if W.Event(slot+1).Starts%900~=e.Starts%900 then drift=true end end
	check(drift and eclipses>0 and eclipses<100,"rare weathers drift across the day and remain uncommon")
	local summon={Id="eclipse",Key="test",Starts=100,Ends=280,Summoned=true}
	check(W.At(110,summon).Id=="eclipse" and W.At(280,summon).Key~="test","local summons override only until they end")
	check(W.Pick(0)=="rain" and W.Pick(.999)=="eclipse" and W.SigilCost("eclipse")==25,"Orb odds and Eclipse crafting use authored data")

end

-- Sky finds are distinct authored probabilities, shared across all roll sources at a real-time pace.
do
	local C,R,W=MODULES.Cards,MODULES.CelestialRolls,MODULES.Weather
	local gate={}
	check(R.Take(gate,"sky",100) and not R.Take(gate,"sky",100) and not R.Take(gate,"sky",100.99),"manual / AUTO / pack requests cannot duplicate a sky search")
	check(R.Take(gate,"sky",101) and R.Take(gate,"sky",10000) and not R.Take(gate,"sky",10000),"sky searches refill once per second and never bank idle attempts")
	local normal=C.Pool({["kurogane:Normal"]=true,["rimeveil:Normal"]=true,["vex:Normal"]=true,["tenrai:Normal"]=true})
	local total=0
	for _,card in normal do total+=card.Weight end
	local minBlood,maxLimit=math.huge,0
	for _,sky in W.List do
		if sky.Id=="clear" then continue end
		local seen,last,stats={},0,0
		local pool=C.WeatherPool(sky.Id)
		local mass=0
		for _,card in pool do
			local atk=C.Stat(card,card.Main,0,"Normal")
			check(not seen[card.SkyOneIn] and card.SkyOneIn>last and atk>stats,"rarer sky cards have unique odds and stronger stats: "..card.Name)
			seen[card.SkyOneIn]=true;last=card.SkyOneIn;stats=atk
			local stronger=true
			for _,other in normal do
				if other.Type~="Attack" then continue end
				local matched=table.clone(other);matched.Weight=total/card.SkyOneIn
				stronger=stronger and atk>C.Stat(matched,matched.Main,0,"Normal")
			end
			check(stronger,"sky card outstats a normal / boss card at the same rarity: "..card.Name)
			mass+=1/card.SkyOneIn
			if sky.Id=="rain" then maxLimit=math.max(maxLimit,card.SkyOneIn) end
			if sky.Id=="eclipse" then minBlood=math.min(minBlood,card.SkyOneIn) end
		end
		check(mass<.01 and R.Pick(pool,.99999)==nil,"most eligible sky searches remain ordinary rolls: "..sky.Name)
		local counts={};local rng=Random.new(429);local n=500000
		for _=1,n do local found=R.Pick(pool,rng:NextNumber());if found then counts[found.Id]=(counts[found.Id] or 0)+1 end end
		local matches=true
		for _,card in pool do local chance=1/card.SkyOneIn;matches=matches and math.abs((counts[card.Id] or 0)-n*chance)<5*math.sqrt(n*chance*(1-chance)) end
		check(matches,"sampled per-card sky odds match their displayed rarity: "..sky.Name)
	end
	check(maxLimit==1000 and minBlood==4000,"Blood Moon is a rarer chase than the 600-1000 Limitbreak range")
end

do
	local Cards,Weather,Engine=MODULES.Cards,MODULES.Weather,MODULES.BattleEngine
	for _,sky in Weather.List do
		if sky.Id=="clear" then continue end
		local pool=Cards.WeatherPool(sky.Id)
		local sameSeries=#pool==4
		for _,card in pool do
			sameSeries=sameSeries and card.Type=="Attack" and card.Title==sky.Series and card.Support==nil
			check(card.Main>600 and card.HP==2*card.Main,"Celestial stats exceed the normal/boss base line: "..card.Name)
		end
		check(sameSeries,"one anime and four Attack cards per sky: "..sky.Name)
	end
	local clean=true
	for _,card in Cards.Pool({["kurogane:Normal"]=true}) do clean=clean and not card.Weather end
	check(clean,"normal roll pools never contain an out-of-weather event card")
	local battle=Engine.new({Units={{Id="A1",CardId="celestial_thunder_gojo",Stars=0,Border="Normal"}},BossId="kurogane",Difficulty="Normal",Guards={},WeatherId="clear",Rng=Random.new(3)})
	local unit=battle.ById.A1
	local main,hp=unit.Main,unit.MaxHP
	unit.HP=math.floor(hp/2)
	local ratio=unit.HP/unit.MaxHP
	battle:SetWeather("thunder")
	check(math.abs(unit.Main/main-1.2)<.002 and math.abs(unit.MaxHP/hp-1.2)<.002,"matching active sky adds 20% actual Attack and HP")
	check(math.abs(unit.HP/unit.MaxHP-ratio)<.002,"a sky transition preserves HP percentage instead of healing the card")
	battle:SetWeather("clear")
	check(unit.Main==main and unit.MaxHP==hp,"event battle stats return to normal when the sky ends")
	local near=MODULES.Goals.Closest({Cards={rook={Copies=99,Stars=0,BorderCopies={Normal=99}}},Rolls=45,Shards=0,Weather={Id="clear",Next={Starts=120}},Now=0})
	check(#near==3 and near[1].Kind=="Fusion" and near[1].Progress==.99,"HUD selects the nearest three distinct progress targets")
end

do
 local C=MODULES.Cards
 local gojo,yhwach=C.Get("celestial_thunder_gojo"),C.Get("celestial_blizzard_yhwach")
 check(C.Rarity(gojo.Id)==C.Rarity(yhwach.Id) and C.Stat(yhwach,yhwach.Main,0,"Normal")>C.Stat(gojo,gojo.Main,0,"Normal"),"Soulfall Almighty outstats Cursed Night Gojo even at equal rarity")
 local high=C.Get("celestial_eclipse_akaza")
 check(C.Stat(high,high.Main,0,"Normal")>C.Stat(yhwach,yhwach.Main,0,"Normal"),"Blood Moon starts above Soulfall's strongest card")
end
