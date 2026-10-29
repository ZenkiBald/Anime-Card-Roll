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
	check(W.PackTrials(1000)==100*W.PackTrials(10),"condensed and bulk packs have equivalent weather opportunities")
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
