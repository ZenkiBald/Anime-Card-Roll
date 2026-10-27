--!nonstrict
-- Runtime town props at the existing markers. No Terrain / saved buildings are replaced.
local Signs = require(script.Parent.WorldSigns)
local Meta = require(game:GetService("ReplicatedStorage").Shared.Meta)
local Services = {}
local WOOD = Color3.fromRGB(94,60,43)
local EDGE = Color3.fromRGB(51,48,43)
local JADE = Color3.fromRGB(49,99,87)
local GOLD = Color3.fromRGB(198,162,79)
local STONE = Color3.fromRGB(135,139,128)

local function part(parent,name,size,cf,color,material,class)
	local p = Instance.new(class or "Part")
	p.Name=name; p.Size=size; p.CFrame=cf; p.Color=color
	p.Material=material or Enum.Material.SmoothPlastic
	p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
	p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end
local function model(parent,name)
	local m=Instance.new("Model"); m.Name=name; m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic; m.Parent=parent
	return m
end
local function roof(parent,cf,width,depth)
	-- Four overlapping slopes make a simple hip roof, with short raised corner tips.
	for i=0,3 do
		local w,d = if i%2==0 then width else depth, if i%2==0 then depth else width
		part(parent,"RoofSlope",Vector3.new(w,1.45,d/2),cf*CFrame.Angles(0,i*math.pi/2,0)*CFrame.new(0,.72,-d/4),JADE,Enum.Material.Slate,"WedgePart")
	end
	part(parent,"Eaves",Vector3.new(width+.28,.25,depth+.28),cf,EDGE,Enum.Material.Wood)
	for _,x in {-1,1} do for _,z in {-1,1} do
		part(parent,"RaisedRoofTip",Vector3.new(1.55,.18,.38),cf*CFrame.new(x*(width/2-.15),.23,z*(depth/2-.1))*CFrame.Angles(0,x*z*math.pi/4,z*.22),JADE,Enum.Material.Slate)
	end end
end
local function lantern(parent,cf)
	part(parent,"LanternPost",Vector3.new(.28,3.4,.28),cf*CFrame.new(0,1.7,0),WOOD,Enum.Material.Wood)
	part(parent,"Lantern",Vector3.new(.9,1.15,.9),cf*CFrame.new(0,3.55,0),Color3.fromRGB(250,215,145),Enum.Material.SmoothPlastic)
	part(parent,"LanternCap",Vector3.new(1.2,.2,1.2),cf*CFrame.new(0,4.22,0),EDGE,Enum.Material.Slate)
end
local function bench(parent,cf)
	part(parent,"Worktop",Vector3.new(6.6,.32,2.5),cf*CFrame.new(0,2.9,0),WOOD,Enum.Material.Wood)
	for _,x in {-2.6,2.6} do for _,z in {-.8,.8} do
		part(parent,"BenchLeg",Vector3.new(.32,2.7,.32),cf*CFrame.new(x,1.4,z),EDGE,Enum.Material.Wood)
	end end
	part(parent,"Shelf",Vector3.new(5.7,.2,2),cf*CFrame.new(0,.8,0),WOOD,Enum.Material.Wood)
end

function Services.Fusion(parent,ground)
	local m=model(parent,"FusionStation")
	local cf=ground*CFrame.new(0,0,-3.2)
	bench(m,cf)
	for i=1,3 do
		part(m,"FusionCard",Vector3.new(1.05,.12,1.5),cf*CFrame.new((i-2)*1.35,3.15,-.1)*CFrame.Angles(0,(i-2)*.15,0),if i==2 then JADE else GOLD,Enum.Material.Metal)
	end
	for i,color in {Color3.fromRGB(240,157,73),Color3.fromRGB(156,131,222)} do
		local crystal=part(m,"FusionCrystal",Vector3.new(.65,.8,.65),cf*CFrame.new(if i==1 then -2.5 else 2.5,3.6,0)*CFrame.Angles(.3,0,.4),color,Enum.Material.Glass)
		crystal:SetAttribute("Spin",true)
	end
	part(m,"PackBox",Vector3.new(1.6,.7,1.4),cf*CFrame.new(0,1.25,0),JADE,Enum.Material.Wood)
	return m
end

function Services.Traits(parent,ground)
	local m=model(parent,"TraitStation")
	local cf=ground*CFrame.new(0,0,-3.2)
	bench(m,cf)
	for i=1,3 do
		local scroll=part(m,"Scroll",Vector3.new(1.25,.35,.35),cf*CFrame.new((i-2)*1.6,3.25,.2),Color3.fromRGB(224,214,177))
		scroll.Shape=Enum.PartType.Cylinder
		part(m,"ScrollSeal",Vector3.new(.28,.12,.3),cf*CFrame.new((i-2)*1.6,3.44,.2),JADE)
		part(m,"TraitCrystal",Vector3.new(.45,.65,.45),cf*CFrame.new((i-2)*1.6,3.45,-.7)*CFrame.Angles(.2,0,.3),Color3.fromRGB(85,196,188),Enum.Material.Glass)
	end
	return m
end

function Services.Guide(parent,ground)
	local m=model(parent,"GuideStation")
	local cf=ground*CFrame.new(2.8,0,-1.5)
	part(m,"LecternFoot",Vector3.new(1.7,.3,1.7),cf*CFrame.new(0,.15,0),STONE,Enum.Material.Slate)
	part(m,"LecternPost",Vector3.new(.45,2.5,.45),cf*CFrame.new(0,1.45,0),WOOD,Enum.Material.Wood)
	local top=cf*CFrame.new(0,2.8,0)*CFrame.Angles(math.rad(18),0,0)
	part(m,"LecternTop",Vector3.new(2.2,.2,1.6),top,WOOD,Enum.Material.Wood)
	part(m,"GuidePages",Vector3.new(1.8,.09,1.3),top*CFrame.new(0,.16,0),Color3.fromRGB(228,218,184))
	part(m,"BookSpine",Vector3.new(.08,.13,1.35),top*CFrame.new(0,.2,0),JADE)
end

function Services.WheelCanopy(booth,ground)
	local cf=ground*CFrame.new(2.5,0,3)
	roof(booth,cf*CFrame.new(0,15,0),13.5,5)
	Signs.Plaque(booth,"SignAnchor",cf*CFrame.new(0,13.45,-3.4),Vector3.new(10.5,2.1,.4),"LUCKY WHEEL",`Free spin · every {Meta.Wheel.SpinEvery // 60} min`,GOLD)
end

function Services.Tower(parent,ground)
	local gate=model(parent,"TowerGate")
	local function p(name,size,x,y,z,color,material,class)
		return part(gate,name,size,ground*CFrame.new(x,y,z),color,material,class)
	end
	local foundation=p("Foundation",Vector3.new(14,1,12),0,.5,3,STONE,Enum.Material.Slate)
	foundation.CanCollide=true; foundation.CanQuery=true
	for i=1,3 do
		local step=p("Step",Vector3.new(8.5,.28*i,1.4),0,.14*i,-7.7+i*1.35,STONE,Enum.Material.Slate)
		step.CanCollide=true; step.CanQuery=true
	end
	local levels={{10,8,1,6.4},{7.8,6.6,9.2,4.4},{5.7,5.2,15.4,3.7}}
	for i,l in levels do
		local w,d,base,h=l[1],l[2],l[3],l[4]
		p("BackWall",Vector3.new(w,h,.3),0,base+h/2,3+d/2,Color3.fromRGB(212,203,171))
		for _,x in {-1,1} do
			p("SideWall",Vector3.new(.3,h,d),x*w/2,base+h/2,3,Color3.fromRGB(212,203,171))
			for _,z in {-1,1} do p("TimberPost",Vector3.new(.48,h+.2,.48),x*w/2,base+h/2,3+z*d/2,WOOD,Enum.Material.Wood) end
		end
		if i==1 then
			for _,x in {-1,1} do p("EntranceWall",Vector3.new(2.6,h,.3),x*3.65,base+h/2,3-d/2,Color3.fromRGB(212,203,171)) end
		else
			p("FrontWall",Vector3.new(w,h,.3),0,base+h/2,3-d/2,Color3.fromRGB(212,203,171))
			for _,x in {-1.4,1.4} do
				p("WindowFrame",Vector3.new(1.5,2,.16),x,base+h*.53,3-d/2-.2,WOOD,Enum.Material.Wood)
				p("WarmWindow",Vector3.new(1.12,1.65,.12),x,base+h*.53,3-d/2-.3,Color3.fromRGB(238,202,124),Enum.Material.Glass)
			end
		end
		p("TimberBeam",Vector3.new(w+.3,.45,d+.3),0,base+h-.12,3,WOOD,Enum.Material.Wood)
		roof(gate,ground*CFrame.new(0,base+h+.1,3),w+3.4,d+3)
	end
	p("FinialStem",Vector3.new(.24,2.4,.24),0,22,3,GOLD,Enum.Material.Metal)
	p("FinialGem",Vector3.new(.7,1,.7),0,23.3,3,Color3.fromRGB(99,206,180),Enum.Material.Glass)
	for _,x in {-5.8,5.8} do lantern(gate,ground*CFrame.new(x,0,-4.3)) end
	for _,x in {-2.35,2.35} do p("DoorFrame",Vector3.new(.28,6.1,.4),x,4,-1.2,JADE,Enum.Material.Wood) end
	p("DoorLintel",Vector3.new(4.9,.3,.5),0,7,-1.2,JADE,Enum.Material.Wood)
	local door=p("Door",Vector3.new(4.3,5.7,.12),0,3.95,-1.16,Color3.fromRGB(59,164,156),Enum.Material.Neon)
	door.Transparency=.35
	local prompt=Instance.new("ProximityPrompt")
	prompt.ActionText="Climb the tower"; prompt.ObjectText="Infinite Tower"
	prompt.KeyboardKeyCode=Enum.KeyCode.F; prompt.HoldDuration=0; prompt.MaxActivationDistance=16
	prompt.RequiresLineOfSight=false; prompt:SetAttribute("Npc","tower"); prompt.Parent=door
	Signs.Plaque(gate,"SignAnchor",ground*CFrame.new(0,7.8,-3.4),Vector3.new(10.5,2.2,.4),"INFINITE TOWER","Endless floors · rare relics",Color3.fromRGB(120,218,184))
	local board=p("BoardSpot",Vector3.one,14,0,2,STONE)
	board.Transparency=1
	board.CFrame=board.CFrame*CFrame.Angles(0,math.rad(-20),0)
	return gate
end

return Services
