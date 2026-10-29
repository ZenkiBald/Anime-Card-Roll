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

-- Sky finds: every pull searches the active sky once, at each card's authored 1 / SkyOneIn chance (luck
-- lifts it by 15% of its bonus); a bulk draw over N searches matches N single searches.
do
	local C,R,W=MODULES.Cards,MODULES.CelestialRolls,MODULES.Weather
	local normal=C.Pool({["kurogane:Normal"]=true,["rimeveil:Normal"]=true,["vex:Normal"]=true,["tenrai:Normal"]=true})
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
			-- Against every normal / boss Attack card that is no rarer than it.
			local stronger=true
			for _,other in normal do
				if other.Type=="Attack" and C.WeightTotal/other.Weight<=card.SkyOneIn then
					stronger=stronger and atk>C.Stat(other,other.Main,0,"Normal")
				end
			end
			check(stronger,"sky card outstats every normal / boss card that is no rarer: "..card.Name)
			mass+=1/card.SkyOneIn
			if sky.Id=="rain" then maxLimit=math.max(maxLimit,card.SkyOneIn) end
			if sky.Id=="eclipse" then minBlood=math.min(minBlood,card.SkyOneIn) end
		end
		check(mass<.01 and R.Pick(pool,.99999)==nil,"most sky searches remain ordinary rolls: "..sky.Name)
		local chances1,chances25=R.Chances(pool,1),R.Chances(pool,25)
		check(math.abs(chances1[1]-1/pool[1].SkyOneIn)<1e-12 and math.abs(chances25[1]/chances1[1]-(1+24*.15))<1e-9,"luck lifts sky odds by 15% of its bonus: "..sky.Name)
		local counts={};local rng=Random.new(429);local n=500000
		for _=1,n do local found=R.Pick(pool,rng:NextNumber());if found then counts[found.Id]=(counts[found.Id] or 0)+1 end end
		local bulk=R.Search(pool,n,1,Random.new(77))
		local matches=true
		for _,card in pool do
			local chance=1/card.SkyOneIn
			local sd=5*math.sqrt(n*chance*(1-chance))
			matches=matches and math.abs((counts[card.Id] or 0)-n*chance)<sd and math.abs((bulk[card] or 0)-n*chance)<sd
		end
		check(matches,"single and bulk sky searches both match the displayed odds: "..sky.Name)
	end
	check(maxLimit==3000 and minBlood==10000,"Blood Moon (1 in 10,000+) is a rarer chase than Limitbreak (1,500-3,000)")
	check(R.Chances(C.WeatherPool("eclipse"),1e9)[1]<.5,"absurd luck still can't make every search a find")
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
 local sukuna,yhwach=C.Get("celestial_thunder_sukuna"),C.Get("celestial_blizzard_yhwach")
 check(C.Rarity(sukuna.Id)==C.Rarity(yhwach.Id) and yhwach.Main==sukuna.Main and yhwach.Main==4300,"the two 1 in 8,000 sky cards (Yhwach, Sukuna) share 4,300 base ATK")
 for _,card in C.List do
 	if card.Weather and card.Weather~="rain" then
 		local skill,ult=C.Ability(card,"Skill"),C.Ability(card,"Ultimate")
 		local total=0
 		for _,e in ult.Effects do if e.Kind=="Damage" then total+=(e.Pct or 0)*(e.Hits or 1) end end
 		check(skill.Every==3 and total>=5-1e-9 and total<=6.5+1e-9,"sky Skills every 3 actions, Ultimates 500-650%: "..card.Name)
 	end
 end
 local high=C.Get("celestial_eclipse_akaza")
 check(C.Stat(high,high.Main,0,"Normal")>C.Stat(yhwach,yhwach.Main,0,"Normal"),"Blood Moon starts above Soulfall's strongest card")
end
