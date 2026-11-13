--!nonstrict
-- Turn-based rules for loan cards. The server owns the run, offers, commands and prizes.
local Draft = {}
Draft.Version = 1
Draft.Ranks = {"Bronze", "Silver", "Crown"}
Draft.Title = "Rift Champion"
Draft.MaxHP = 42

-- Hit, block and heal values are specific to this mode, independent of collection strength.
Draft.Fighters = {
	tomo = {Style="Strike", Hit=7, Burn=2, Text="Burn for 2 on this play and the next."},
	goro = {Style="Strike", Hit=8, Finisher=5, Text="+5 damage against a boss at half HP or lower."},
	suzu = {Style="Strike", Hit=6, Relay=7, Text="+7 more damage when completing a relay."},
	hayate = {Style="Strike", Hit=7, Break=8, Text="+8 damage against Guard. Pierces its armor."},
	rook = {Style="Guard", Hit=4, Block=7, Counter=4, Text="Block 7. Return 4 damage when you block a hit."},
	tetsu = {Style="Guard", Hit=5, Block=6, Break=3, Text="Block 6. Pierce Guard for 3 more damage."},
	hana = {Style="Guard", Hit=4, Heal=5, Text="Restore 5 squad HP before the enemy acts."},
	aurelia = {Style="Guard", Hit=6, Block=4, Finisher=3, Text="Block 4. Deal 3 more below half enemy HP."},
	yume = {Style="Trick", Hit=5, Disrupt=true, Burn=1, Text="Interrupt Channel. Burn for 1 now and on the next play."},
	orin = {Style="Trick", Hit=6, Disrupt=true, Relay=3, Text="Interrupt Channel. Add 3 damage on a relay."},
	amane = {Style="Trick", Hit=5, Disrupt=true, Counter=4, Block=3, Text="Interrupt Channel. Block 3 and counter for 4."},
	luna = {Style="Trick", Hit=5, Disrupt=true, Heal=2, Text="Interrupt Channel and restore 2 squad HP."},
}
Draft.Roster = {"tomo","goro","suzu","hayate","rook","tetsu","hana","aurelia","yume","orin","amane","luna"}
Draft.Relics = {
	mirror={Name="Mirror Plate", Text="Return 5 more damage whenever you block a hit.", Art="ocular_seal"},
	spring={Name="Lotus Spring", Text="Restore 5 HP on every three-fighter relay.", Art="mitotic_seal"},
	edge={Name="Split Blade", Text="Every fighter pierces Guard and deals 3 extra damage against it.", Art="heavenly_pact"},
	echo={Name="Echo Drum", Text="Every relay deals 6 extra damage.", Art="thunderclap_form"},
	feather={Name="Crow Feather", Text="Interrupting Channel deals 9 extra damage.", Art="blink_kunai"},
	veil={Name="Sand Veil", Text="Every play blocks 3 extra damage.", Art="sand_gourd"},
}
local relics = {"mirror","spring","edge","echo","feather","veil"}
Draft.Enemies = {
	{Card="kurogane_card", Rule="Fury adds 3 to every third hit.", Pattern={"Strike","Channel","Guard","Strike"}},
	{Card="rimeveil_card", Rule="Blocking a hit shatters ice for 3 damage.", Pattern={"Guard","Strike","Channel","Channel"}},
	{Card="vex_card", Rule="Guard reflects 3 unless a Trick or relay breaks the mirror.", Pattern={"Channel","Guard","Strike","Guard"}},
	{Card="tenrai_card", Rule="Wounds deepen. Taking a hit costs 2 extra HP.", Pattern={"Strike","Channel","Strike","Guard"}},
}

function Draft.NewRecord()
	return {Version=Draft.Version, Revision=0, Unlocked=1, Marks={}, Best={}}
end

local function take(list, rng)
	return table.remove(list, rng:NextInteger(1,#list))
end

local function fighterOffers(run, rng)
	local offers = {}
	for _, style in {"Strike","Guard","Trick"} do
		local pool = {}
		for _, id in Draft.Roster do
			if Draft.Fighters[id].Style == style and not table.find(run.Team,id) then table.insert(pool,id) end
		end
		table.insert(offers,take(pool,rng))
	end
	return offers
end

local function beginRoom(r)
	r.Phase = "Fight"
	r.MaxEnemy = 18 + 8*r.Room + 5*(r.Rank-1)
	r.EnemyHP = r.MaxEnemy
	r.Turn = 1
	r.Recent = {}
	r.Burn, r.BurnTurns = 0,0
	r.Offers = {}
end

function Draft.Intent(r)
	local pattern = Draft.Enemies[r.Route[r.Room]].Pattern
	local move = pattern[(r.Turn-1) % #pattern+1]
	local fury = if r.Route[r.Room]==1 and r.Turn%3==0 then 3 else 0
	local damage = r.Room + 2*r.Rank-1 + fury + (if move=="Channel" then 9 elseif move=="Strike" then 4 else 1)
	return move,damage
end

-- Shared preview and resolution: the value on a move is the actual net result at this turn.
function Draft.Preview(r, id)
	local f = Draft.Fighters[id]
	local intent, incoming = Draft.Intent(r)
	local last, prior = r.Recent[1], r.Recent[2]
	local relay = prior ~= nil and last ~= id and prior ~= id and last ~= prior
	local hit = f.Hit
	local heal = f.Heal or 0
	local block = (f.Block or 0) + (if r.Relics.veil then 3 else 0)
	if relay then
		hit += 4 + (f.Relay or 0) + (if r.Relics.echo then 6 else 0)
		if r.Relics.spring then heal += 5 end
	end
	if r.EnemyHP*2 <= r.MaxEnemy then hit += f.Finisher or 0 end
	if intent == "Guard" then
		if f.Break or r.Relics.edge then hit += (f.Break or 0) + (if r.Relics.edge then 3 else 0)
		else hit = math.max(1,hit-4) end
	end
	local interrupt = intent=="Channel" and f.Disrupt==true
	if interrupt then
		incoming = 0
		if r.Relics.feather then hit += 9 end
	end
	local burn = math.max(f.Burn or 0,r.Burn)
	local counter = if incoming>0 and block>0 then (f.Counter or 0) + (if r.Relics.mirror then 5 else 0) else 0
	local enemy = r.Route[r.Room]
	if enemy==2 and incoming>0 and block>0 then counter+=3 end
	local hurt = math.max(0,incoming-block)
	if enemy==3 and intent=="Guard" and not relay and f.Style~="Trick" then hurt+=3 end
	if enemy==4 and hurt>0 then hurt+=2 end
	if hit+burn>=r.EnemyHP then hurt=0 end
	return {Damage=math.min(r.EnemyHP, hit+burn+(if hit+burn<r.EnemyHP then counter else 0)),
		Hurt=hurt, Heal=math.min(Draft.MaxHP-r.HP,heal), Relay=relay, Interrupt=interrupt}
end

local function wonRoom(r,rng)
	r.Phase="Relic"
	local pool = {}
	for _, id in relics do if not r.Relics[id] then table.insert(pool,id) end end
	r.Offers = {take(pool,rng),take(pool,rng),take(pool,rng)}
end

-- Called only on a terminal transition. New marks, inventory grants and rank unlock share the revision.
local function award(data, r)
	r.Prizes = {}
	local rank = Draft.Ranks[r.Rank]
	local previous = data.RiftDraft.Best[rank]
	if not previous or r.Plays < previous.Plays or (r.Plays==previous.Plays and r.HP>previous.HP) then
		data.RiftDraft.Best[rank]={Plays=r.Plays,HP=r.HP,Team=table.clone(r.Team)}
		r.Record=true
	end
	for _, id in r.Team do
		local old = data.RiftDraft.Marks[id] or 0
		if r.Rank > old then
			local card = data.Cards[id] or {Copies=0, Stars=0}
			card.Borders = card.Borders or {}
			card.BorderCopies = card.BorderCopies or {Normal=card.Copies}
			local earned = {}
			for tier = old+1, math.min(2,r.Rank) do
				local border = if tier==1 then "Normal" else "Gold"
				card.BorderCopies[border] = (card.BorderCopies[border] or 0)+1
				card.Borders[border] = true
				card.Copies += 1
				table.insert(earned, if tier==1 then "Base" else "Gold")
			end
			data.Cards[id]=card
			data.RiftDraft.Marks[id]=r.Rank
			r.Prizes[id] = table.concat(earned," + ")
		end
	end
	data.RiftDraft.Unlocked=math.max(data.RiftDraft.Unlocked,math.min(#Draft.Ranks,r.Rank+1))
	if r.Rank==3 and not data.Titles[Draft.Title] then
		data.Titles[Draft.Title]=true
		r.NewTitle=true
	end
end

-- No yields between validation, fight resolution and profile mutation.
function Draft.Command(data, action, value, revision, rng)
	local book=data.RiftDraft
	if revision~=book.Revision then return false,"Stale" end
	local r=book.Run
	if action=="Wear" then
		if value~=nil or not data.Titles[Draft.Title] then return false,"Locked" end
		data.Settings.Title=Draft.Title
	elseif action=="Start" then
		if r and r.Phase~="Won" and r.Phase~="Lost" then return false,"Busy" end
		if type(value)~="number" or value%1~=0 or value<1 or value>book.Unlocked then return false,"Locked" end
		local enemies={1,2,3,4}
		r={Phase="Draft", Rank=value, Room=1, HP=Draft.MaxHP, Team={}, Relics={}, Plays=0,
			Route={take(enemies,rng),take(enemies,rng),take(enemies,rng)}}
		r.Offers=fighterOffers(r,rng)
		book.Run=r
	elseif not r then return false,"NoRun"
	elseif action=="Retire" then
		book.Run=nil
	elseif action=="Pick" and r.Phase=="Draft" then
		if not table.find(r.Offers,value) then return false,"NotOffered" end
		table.insert(r.Team,value)
		if #r.Team==3 then beginRoom(r) else r.Offers=fighterOffers(r,rng) end
	elseif action=="Pick" and r.Phase=="Relic" then
		if not table.find(r.Offers,value) then return false,"NotOffered" end
		r.Relics[value]=true
		r.Room+=1
		r.HP=math.min(Draft.MaxHP,r.HP+8)
		beginRoom(r)
	elseif action=="Play" and r.Phase=="Fight" then
		if not table.find(r.Team,value) or r.Recent[1]==value then return false,"Resting" end
		local result=Draft.Preview(r,value)
		r.HP=math.max(0,r.HP+result.Heal-result.Hurt)
		r.EnemyHP-=result.Damage
		r.Plays+=1
		r.Last={Card=value, Damage=result.Damage, Hurt=result.Hurt, Heal=result.Heal, Relay=result.Relay, Interrupt=result.Interrupt}
		r.Recent={value,r.Recent[1]}
		local burn=Draft.Fighters[value].Burn
		if burn and burn>=r.Burn then r.Burn,r.BurnTurns=burn,2 end
		r.BurnTurns=math.max(0,r.BurnTurns-1)
		if r.BurnTurns==0 then r.Burn=0 end
		if r.HP==0 then r.Phase="Lost"
		elseif r.EnemyHP==0 then
			if r.Room==3 then
				r.Phase="Won"
				award(data,r)
			else wonRoom(r,rng) end
		else r.Turn+=1 end
	else return false,"BadAction" end
	book.Revision+=1
	return true
end
return Draft
