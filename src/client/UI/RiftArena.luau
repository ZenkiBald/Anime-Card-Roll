--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Cards)
local Draft = require(ReplicatedStorage.Shared.RiftDraft)
local Kit = require(script.Parent.Kit)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local Arena = {}
local modal, book, pending, retireConfirm, hasTitle, worn, inspecting
local page, headerActions, draw, send
local markRank
local C = Theme.Color
local styleColor = {Strike=C.Attack, Guard=C.Health, Trick=Color3.fromRGB(185,151,255)}
local errors = {TooFast="Give the last move a moment.", InBattle="Finish your current battle first.",
	Loading="Your save is still loading.", Stale="Your run has been refreshed.", Locked="Clear the previous rank first."}

local function label(parent,name,value,x,y,w,h,color,size,font)
	return Kit.label({Name=name, Text=value, TextColor3=color, Font=font or Theme.Font.Bold,
		TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.fromScale(x,y), Size=UDim2.fromScale(w,h),Parent=parent},size)
end

local function button(parent,name,title,x,y,w,h,color,callback)
	local b=Kit.button(title,color,color:Lerp(C.Backdrop,.65),{Name=name,Position=UDim2.fromScale(x,y),
		Size=UDim2.fromScale(w,h),Parent=parent})
	b.Activated:Connect(callback)
	return b
end

local function image(parent,id,x,y,w,h)
	return Kit.new("ImageLabel",{Name="Portrait",BackgroundColor3=C.TileBottom,Image=Cards.ById[id].Image,
		ScaleType=Enum.ScaleType.Crop,Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),Parent=parent},
		{Kit.corner(UDim.new(0,8))})
end

local function meter(parent,name,value,max,x,y,w,color)
	local back=Kit.new("Frame",{Name=name,Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,.022),
		BorderSizePixel=0,BackgroundColor3=C.Backdrop,Parent=parent},{Kit.corner()})
	Kit.new("Frame",{Name="Fill",Size=UDim2.fromScale(value/max,1),BorderSizePixel=0,
		BackgroundColor3=color,Parent=back},{Kit.corner()})
end

local function markCount(rank)
	local count=0
	for _,id in Draft.Roster do if (book.Marks[id] or 0)>=rank then count+=1 end end
	return count
end

local function gallery(id,title,sub)
	image(page,id,0,0,.3,.76)
	label(page,"Feature",title,0,.77,.30,.10,C.Text,24,Theme.Font.Display)
	label(page,"FeatureSub",sub,0,.87,.30,.11,C.Muted,15)
end

local function heading(title,subtitle)
	label(page,"Heading",title,.33,0,.66,.10,C.Text,28,Theme.Font.Display)
	label(page,"Description",subtitle,.33,.11,.66,.12,C.Muted,17,Theme.Font.Medium)
end

local function offer(slot,art,name,tag,details,caption,color,callback)
	local frame=Kit.new("Frame",{Name="Choice"..slot,BackgroundColor3=C.TileBottom,Position=UDim2.fromScale(.33+(slot-1)*.225,.26),
		Size=UDim2.fromScale(.213,.64),Parent=page},{Kit.corner(),Kit.stroke(color,1.5,.2)})
	image(frame,art,.03,.025,.94,.39)
	label(frame,"Tag",tag,.05,.42,.90,.085,color,13)
	label(frame,"Name",name,.05,.505,.90,.13,C.Text,20,Theme.Font.Display)
	label(frame,"Details",details,.05,.64,.90,.18,C.Text,15,Theme.Font.Medium)
	local b=button(frame,"Choose",caption,.04,.835,.92,.14,color,function() if callback then callback() end end)
	if not callback then Kit.dim(b,true) end
end

local function tip(value,color)
	label(page,"Hint",value,.33,.925,.66,.07,color or C.Muted,15)
end

local function showLobby()
	gallery("vex_card","Rift Draft","Borrow a trio. Clear three duels with one shared health bar.")
	heading("Choose a circuit","Earn a mark for each fighter on your winning team. Pick a fighter you still need to build your collection.")
	local arts={"kurogane_card","rimeveil_card","tenrai_card"}
	local rewards={"First mark per fighter earns their Base card.","First Silver mark per fighter earns their Gold card.","Clear Crown to earn the Rift Champion title."}
	for i,rank in Draft.Ranks do
		local open=i<=book.Unlocked
		local best=book.Best[rank]
		local score=if best then "  ·  Best "..best.Plays.." plays" else ""
		offer(i,arts[i],rank,markCount(i).."/"..#Draft.Roster.." MARKS"..score,rewards[i],
			if open then "DRAFT TEAM" else "CLEAR "..Draft.Ranks[i-1],if open then C.Gold else C.Muted,
			if open then function() send("Start",i) end else nil)
	end
	tip("Beat your best in fewer plays. Remaining HP breaks a tie. Your run saves after every move.")
end

local function showDraft(r)
	local boss=Cards.Get(Draft.Enemies[r.Route[1]].Card)
	gallery(boss.Id,boss.Name,"First opponent · "..Draft.Ranks[r.Rank].." circuit")
	local names={}
	for _,id in r.Team do table.insert(names,Cards.ById[id].Name) end
	heading("Pick fighter "..(#r.Team+1).." of 3",if #names==0 then "Pick a damage dealer, protector or trickster. All three picks are loan cards." else "Your team · "..table.concat(names,"  /  "))
	for i,id in r.Offers do
		local f=Draft.Fighters[id]
		local marked=(book.Marks[id] or 0)>=r.Rank
		offer(i,id,Cards.ById[id].Name,string.upper(f.Style).."  ·  "..f.Hit.." DMG",f.Text,
			"RECRUIT",styleColor[f.Style],function() send("Pick",id) end)
		if marked then
			local frame=page["Choice"..i]
			label(frame,"Marked","MARK EARNED",.05,.03,.86,.08,C.Gold,12)
		end
	end
	tip("Rotate all three fighters for +4 relay damage. The fighter you just played rests one turn.")
end

local function showFight(r)
	local card=Cards.Get(Draft.Enemies[r.Route[r.Room]].Card)
	local intent,incoming=Draft.Intent(r)
	image(page,card.Id,0,0,.30,.53)
	label(page,"BossRule",Draft.Enemies[r.Route[r.Room]].Rule,0,.535,.30,.134,C.Gold,16)
	label(page,"Enemy",card.Name,0,.675,.30,.09,C.Text,23,Theme.Font.Display)
	label(page,"EnemyHP","Boss HP   "..r.EnemyHP.." / "..r.MaxEnemy,0,.77,.30,.065,C.Attack,17)
	meter(page,"BossHealth",r.EnemyHP,r.MaxEnemy,0,.845,.29,C.Attack)
	label(page,"SquadHP","Squad HP   "..r.HP.." / "..Draft.MaxHP,0,.875,.30,.065,C.Health,18)
	meter(page,"SquadHealth",r.HP,Draft.MaxHP,0,.954,.29,C.Health)
	local detail=if intent=="Channel" then "A Trick interrupts this hit." elseif intent=="Guard" then "Armor absorbs 4 damage. A piercing move gets through." else "Block the hit or race to finish the boss."
	heading(intent.." incoming · "..incoming.." damage",Draft.Ranks[r.Rank].."  /  Duel "..r.Room.." of 3  /  Turn "..r.Turn.."\n"..detail)
	for i,id in r.Team do
		local f=Draft.Fighters[id]
		local p=Draft.Preview(r,id)
		local resting=r.Recent[1]==id
		local note=if p.Interrupt then "INTERRUPT" elseif p.Relay then "RELAY + BONUS" else string.upper(f.Style)
		local facts=if resting then "Ready again after another fighter plays."
			else p.Damage.." damage  ·  Take "..p.Hurt..(if p.Heal>0 then "  ·  Heal "..p.Heal else "")
		offer(i,id,Cards.ById[id].Name,if resting then "RECOVERING" else note,facts,if resting then "RESTING" else "PLAY",
			if resting then C.Muted else styleColor[f.Style],if resting then nil else function() send("Play",id) end)
	end
	if r.Last then
		local last=r.Last
		tip(Cards.ById[last.Card].Name.." dealt "..last.Damage..(if last.Interrupt then " · Interrupted" else "")..
			(if last.Relay then " · Relay" else "").."  /  Squad lost "..last.Hurt.." HP"..(if last.Heal>0 then ", healed "..last.Heal else ""),C.Gold)
	else tip("Play a different fighter each turn. Three distinct fighters in a row trigger a relay.") end
end

local function showRelics(r)
	local boss=Cards.Get(Draft.Enemies[r.Route[r.Room+1]].Card)
	gallery(boss.Id,boss.Name,"Next opponent · Duel "..(r.Room+1).." of 3")
	heading("Take a relic","You cleared duel "..r.Room..". Recover 8 HP and choose an effect for the rest of this run.")
	for i,id in r.Offers do
		local item=Draft.Relics[id]
		offer(i,item.Art,item.Name,"RUN RELIC",item.Text,"TAKE RELIC",C.Gold,function() send("Pick",id) end)
	end
end

local function showResult(r)
	local win=r.Phase=="Won"
	gallery(Draft.Enemies[r.Route[r.Room]].Card,if win then (if r.Record then "Personal best" else "Circuit cleared") else "Squad defeated",
		Draft.Ranks[r.Rank].." · "..r.Plays.." plays · "..r.HP.." HP left")
	heading(if win then "Your winning trio" else "Your drafted trio",if r.NewTitle then "Earned the Rift Champion title."
		elseif win then "Your fighter marks are saved. Best "..book.Best[Draft.Ranks[r.Rank]].Plays.." plays at this rank." else "The next draft offers a fresh team. Earlier marks stay in your collection.")
	for i,id in r.Team do
		local prize=(r.Prizes or {})[id]
		local status=if not win then "Duel "..r.Room.." reached" elseif prize==nil then "Already marked"
			elseif prize=="" then "Crown mark earned" else prize.." copy earned"
		offer(i,id,Cards.ById[id].Name,Draft.Ranks[r.Rank].." CIRCUIT",status,if win then "CLEARED" else "DEFEATED",if win then C.Gold else C.Muted,nil)
	end
	button(page,"Continue","CHOOSE NEXT CIRCUIT",.52,.916,.36,.08,C.Info,function() send("Retire") end)
end

draw=function()
	page:ClearAllChildren()
	headerActions:ClearAllChildren()
	if not book then
		heading("Opening the rift","Fetching your saved run.")
		return
	end
	local r=book.Run
	if hasTitle and (not r or r.Phase=="Won" or r.Phase=="Lost") then
		local b=button(headerActions,"Wear",if worn then "TITLE EQUIPPED" else "WEAR RIFT TITLE",0,0,1,1,C.Gold,function() if not worn then send("Wear") end end)
		Kit.dim(b,worn)
	end
	if not r then
		button(headerActions,"Marks",if markRank then "CIRCUITS" else "FIGHTER MARKS",-1.06,0,1,1,C.Info,function()
			markRank=if markRank then nil else book.Unlocked
			draw()
		end)
		if not markRank then showLobby();return end
		for i,rank in Draft.Ranks do
			button(page,"Rank"..i,rank,(i-1)*.18,0,.17,.10,if markRank==i then C.Gold else C.TileTop,function() markRank=i;draw() end)
		end
		label(page,"Count",markCount(markRank).."/"..#Draft.Roster.." fighter marks",.60,0,.39,.10,C.Gold,20)
		for i,id in Draft.Roster do
			local x=((i-1)%4)*.25
			local y=.15+math.floor((i-1)/4)*.28
			local earned=(book.Marks[id] or 0)>=markRank
			image(page,id,x,y,.104,.23)
			label(page,"Fighter",Cards.ById[id].Name,x+.11,y,.134,.13,C.Text,16)
			label(page,"Status",if earned then "CLEARED" else "TO EARN",x+.11,y+.14,.13,.06,if earned then C.Health else C.Muted,13)
		end
		return
	end
	if r.Phase=="Fight" and next(r.Relics) then
		local owned={}
		for id in r.Relics do table.insert(owned,id) end
		table.sort(owned)
		button(headerActions,"Inspect",if inspecting then "BACK TO DUEL" else "RELICS  ·  "..#owned,-1.06,0,1,1,C.Info,function() inspecting=not inspecting;draw() end)
		if inspecting then
			gallery(Draft.Enemies[r.Route[r.Room]].Card,"Run relics","These bonuses are already included on your moves.")
			heading("Equipped relics","Your turn waits while you inspect your build.")
			for i,id in owned do
				local item=Draft.Relics[id]
				offer(i,item.Art,item.Name,"EQUIPPED",item.Text,"ACTIVE",C.Gold,nil)
			end
			return
		end
	end
	if r.Phase=="Draft" then showDraft(r)
	elseif r.Phase=="Fight" then showFight(r)
	elseif r.Phase=="Relic" then showRelics(r)
	else showResult(r);return end
	button(headerActions,"Retire",if retireConfirm then "END THIS RUN?" else "END RUN",0,0,1,1,
		if retireConfirm then C.Danger else C.TileTop,function()
			if retireConfirm then send("Retire") else retireConfirm=true;draw() end
		end)
end

send=function(action,value)
	if pending then return end
	pending=true
	local ok,result=pcall(function()
		return ReplicatedStorage.Remotes.RiftDraft:InvokeServer(action,value,if book then book.Revision else nil)
	end)
	pending=false
	retireConfirm=false
	inspecting=false
	if ok and result.Book then
		book=result.Book
		hasTitle=result.HasTitle
		worn=result.Worn
	end
	if ok and result.Cards then for id,entry in result.Cards do State.ApplyCard(id,entry) end end
	if not modal.IsOpen then return end
	draw()
	if not ok or not result.Ok then
		local hint=page:FindFirstChild("Hint")
		if hint then hint:Destroy() end
		tip((ok and errors[result.Reason]) or "Could not complete that move. Try again.",C.Danger)
		if not book then button(page,"Retry","RETRY",.33,.35,.3,.12,C.Info,function() send("Get") end) end
	elseif action~="Get" then
		local r=book.Run
		Sfx.Play(if r and r.Phase=="Won" then "Victory" elseif r and r.Phase=="Lost" then "Defeat"
			elseif r and r.Phase=="Relic" then "Reward" elseif action=="Play" then "Hit" else "Flip")
		if action=="Play" and r and r.Phase=="Fight" then
			local art=page:FindFirstChild("Portrait")
			if art then art.ImageColor3=C.Attack;Kit.tween(art,.22,{ImageColor3=Color3.new(1,1,1)}) end
		end
	end
end

function Arena.Init(playerGui)
	modal=Modal.new(playerGui,"RiftGui","RIFT DRAFT",Vector2.new(.86,.85),Vector2.new(1040,640))
	page=Kit.new("Frame",{Name="Table",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Parent=modal.Body})
	headerActions=Kit.new("Frame",{Name="RunActions",Position=UDim2.new(1,-220,0,8),Size=UDim2.fromOffset(150,35),
		BackgroundTransparency=1,Parent=modal.Header})
	modal.OnOpen=function() retireConfirm=false;inspecting=false;markRank=nil;draw();send("Get") end
end
function Arena.Open() modal:Open() end
return Arena
