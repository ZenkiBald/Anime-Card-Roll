local D=MODULES.RiftDraft
local rng=Random.new(91)
local function profile()
	return {RiftDraft=D.NewRecord(), Cards={}, Titles={}, Settings={Title=""}}
end
local function act(data,action,value)
	return D.Command(data,action,value,data.RiftDraft.Revision,rng)
end
local function fightState()
	return {Phase="Fight", Rank=1, Route={1,2,3}, Room=1, HP=25, MaxEnemy=40, EnemyHP=40, Turn=2, Recent={}, Relics={}, Burn=0,BurnTurns=0}
end
do
	local count=0
	local seen={}
	for _,id in D.Roster do
		local c=MODULES.Cards.Get(id)
		if c and c.Type=="Attack" and c.Image~="" and D.Fighters[id] and not seen[id] then count+=1 end
		seen[id]=true
	end
	check(count==12,"draft roster uses twelve distinct illustrated Attack cards")
	local r=fightState()
	check(D.Preview(r,"yume").Interrupt and D.Preview(r,"yume").Hurt==0 and D.Preview(r,"goro").Hurt==11,"Trick interrupts Channel while a plain strike takes the posted hit")
	r.Turn=3
	check(D.Preview(r,"hayate").Damage>D.Preview(r,"goro").Damage,"piercing the Guard intent changes the best attack")
	r.Recent={"rook","goro"}
	check(D.Preview(r,"suzu").Relay and D.Preview(r,"suzu").Damage>=10 and not D.Preview(r,"goro").Relay,"a three-fighter relay needs three different plays")
	r.Relics.spring=true
	check(D.Preview(r,"suzu").Heal==5,"Lotus Spring changes the value of rotating fighters")
	r.Route={2,3,4}; r.Turn=1
	check(D.Preview(r,"rook").Damage==8,"Galactic Emperor takes extra damage when a fighter blocks its hit")
	r.Route={3,2,4}; r.Turn=2
	check(D.Preview(r,"rook").Hurt==3 and D.Preview(r,"yume").Hurt==3,"Mirror guard reflection can be broken by a Trick or relay")
end
do
	local p=profile()
	check(not act(p,"Wear") and not act(p,"Start",3) and act(p,"Start",1),"Crown is locked while Bronze is freely available")
	local rev=p.RiftDraft.Revision
	local first=p.RiftDraft.Run.Offers[1]
	check(not act(p,"Start",1) and not act(p,"Pick","tenrai_card") and act(p,"Pick",first),"a live run cannot be overwritten and only offered fighters can be drafted")
	check(not D.Command(p,"Pick",first,rev,rng) and #p.RiftDraft.Run.Team==1,"replayed input cannot draft a second fighter")
	act(p,"Pick",p.RiftDraft.Run.Offers[2])
	act(p,"Pick",p.RiftDraft.Run.Offers[3])
	local r=p.RiftDraft.Run
	check(r.Phase=="Fight" and #r.Team==3 and not next(p.Cards),"borrowed fighters do not grant ownership")
	act(p,"Play",first)
	check(not act(p,"Play",first) and r.Plays==1 and not act(p,"Play","tenrai_card"),"resting and undrafted fighters cannot be played")
	local r0=p.RiftDraft.Revision
	check(act(p,"Retire") and not D.Command(p,"Start",1,r0,rng) and not p.RiftDraft.Run,"retiring clears the run and invalidates old choices")
end
-- Play the complete server state machine with three different decisions every run. Greedy policy
-- reads the same previews as a player and weighs damage, prevention, healing and survival.
local wins={0,0,0}
local played=0
for rank=1,3 do
	for sample=1,48 do
		local p=profile()
		p.RiftDraft.Unlocked=rank
		act(p,"Start",rank)
		local r=p.RiftDraft.Run
		local styles=if sample%2==0 then {2,1,3} else {1,3,2}
		for i=1,3 do act(p,"Pick",r.Offers[styles[i]]) end
		local turns=0
		while r.Phase=="Fight" or r.Phase=="Relic" do
			if r.Phase=="Relic" then
				act(p,"Pick",r.Offers[1+(sample%3)])
			else
				local best,score=nil,-math.huge
				for _,id in r.Team do
					if r.Recent[1]~=id then
						local v=D.Preview(r,id)
						local safe=r.HP+v.Heal-v.Hurt
						local value=v.Damage+v.Heal*.9-v.Hurt*.9+(if safe<=0 then -100 else 0)
						if value>score then best,score=id,value end
					end
				end
				if not act(p,"Play",best) then break end
				turns+=1
				if turns>100 then break end
			end
		end
		if r.Phase=="Won" then wins[rank]+=1 end
		if r.Phase=="Won" or r.Phase=="Lost" then played+=1 end
	end
end
print("   Rift Draft preview-driven wins in 48 runs per rank:",wins[1],wins[2],wins[3])
check(played==144 and wins[1]>=42 and wins[2]>=16 and wins[3]>=1,"all circuits terminate and can be cleared with balanced loan squads")
do
	local p=profile()
	local id="tomo"
	p.Cards[id]={Copies=7,Stars=0,BorderCopies={Normal=7},Trait="swift"}
	local function finish(rank)
		local r=fightState()
		r.Team={id,"hana","orin"}
		r.Room,r.EnemyHP,r.Plays,r.Rank=3,1,12,rank
		p.RiftDraft.Run=r
		return act(p,"Play",id)
	end
	check(finish(1) and p.RiftDraft.Best.Bronze.Plays==13 and p.RiftDraft.Unlocked==2 and p.Cards[id].Copies==8 and p.Cards[id].Trait=="swift","first clear grants all three Base copies and unlocks Silver")
	check(not act(p,"Play",id) and finish(1) and not p.RiftDraft.Run.Record and p.Cards[id].Copies==8,"repeating a Bronze victory does not pay the same marks twice")
	check(finish(2) and p.Cards[id].BorderCopies.Gold==1 and p.RiftDraft.Unlocked==3,"Silver pays one Gold copy per new mark")
	check(finish(3) and p.Titles[D.Title] and p.RiftDraft.Marks[id]==3 and p.Cards[id].Copies==9,"Crown completes the fighter record and unlocks its title")
	check(act(p,"Wear") and p.Settings.Title==D.Title,"earned Rift title is wearable on demand")
end
