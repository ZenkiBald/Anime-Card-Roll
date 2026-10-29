-- Edit only. Refines the existing Studio Assistant tower; never replaces the model with a new build.
-- Run once with {}. All original floors, markers and relocated scenery are backed up per model.
return function()
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
	local tower=assert(workspace:FindFirstChild("InfiniteTower"),"Existing InfiniteTower model is required")
	local markers=workspace.Map.Markers
	local function finishApproach()
		if tower:GetAttribute("ApproachDetailsVersion")==1 then return end
		local f=tower:FindFirstChild("TowerFloor1") or tower:FindFirstChild("TowerFloor_1")
		local foundation=f.Foundation
		local origin=foundation.CFrame*CFrame.new(0,-foundation.Size.Y/2,0)
		local function p(parent,name,size,cf,color,solid)
			local v=Instance.new("Part");v.Name=name;v.Size=size;v.CFrame=cf;v.Color=color
			v.Material=Enum.Material.Slate;v.Anchored=true;v.CanCollide=solid==true;v.CanQuery=solid==true;v.CanTouch=false;v.CastShadow=false;v.Parent=parent;return v
		end
		local core=f.Core
		local wallTop=origin:PointToObjectSpace(core.Position).Y+core.Size.Y/2
		local overhang=(foundation.Size.X/31)*39.5/2
		local y=wallTop+core.Size.Y*.24*.28
		for side=0,3 do
			local cf=origin*CFrame.Angles(0,side*math.pi/2,0)
			for _,sign in {-1,1} do
				p(f.ReferenceDetails,"GableRoof",Vector3.new(math.sqrt(52),.28,8),cf*CFrame.new(sign*3,y+2,-overhang*.8)*CFrame.Angles(0,0,-sign*math.atan2(4,6)),Color3.fromRGB(36,39,46))
			end
		end
		local approach=tower.TowerApproach
		for _,v in approach:GetChildren() do if v.Name=="EntranceStep" then v:Destroy() end end
		for i=1,8 do
			local top=foundation.Size.Y-.5*(8-i)
			local bottom=-2.4
			p(approach,"EntranceStep",Vector3.new(13,top-bottom,2.5),origin*CFrame.new(0,(top+bottom)/2,-foundation.Size.X/2-1.1-(8-i)*2.2),Color3.fromRGB(73,70,65),true)
		end
		local door=approach.Entrance
		door.CFrame=origin*CFrame.new(0,foundation.Size.Y+4.5,-foundation.Size.X/2-.3)
		tower:SetAttribute("EntranceCFrame",door.CFrame)
		-- Soft cloud cover hides the distant upper cap without changing Lighting / Atmosphere.
		local cover=p(approach,"UpperCloudBank",Vector3.new(75,.1,75),origin*CFrame.new(0,185,0),Color3.new(1,1,1))
		cover.Transparency=1
		local mist=Instance.new("ParticleEmitter");mist.Name="TowerMist";mist.Texture="rbxasset://textures/particles/smoke_main.dds"
		mist.Rate=3;mist.Lifetime=NumberRange.new(14,20);mist.Speed=NumberRange.new(.3,.6);mist.SpreadAngle=Vector2.new(180,180)
		mist.Size=NumberSequence.new(60,85);mist.Transparency=NumberSequence.new(.65,1);mist.Color=ColorSequence.new(Color3.fromRGB(135,143,159))
		mist:SetAttribute("TownFxRange",550);mist.Parent=cover
		for _,v in tower:GetDescendants() do
			if v:IsA("ParticleEmitter") then game:GetService("CollectionService"):AddTag(v,"TownAmbientFx")
			elseif v:IsA("PointLight") then v:SetAttribute("TownLightRange",75);game:GetService("CollectionService"):AddTag(v,"TownAmbientFx") end
		end
		tower:SetAttribute("ApproachDetailsVersion",1)
	end
	if tower:GetAttribute("ReferencePolishVersion")==1 then finishApproach();return "Already refined; approach checked" end
	local storage=game:GetService("ServerStorage")
	assert(not storage:FindFirstChild("TowerReferenceBackup_20261029"),"Backup already exists; inspect before applying again")
	local backup=Instance.new("Folder");backup.Name="TowerReferenceBackup_20261029";backup.Parent=storage
	local original=Instance.new("Model");original.Name="InfiniteTower";original.Parent=backup
	for _,f in tower:GetChildren() do f:Clone().Parent=original;task.wait() end
	for _,name in {"Tower","Zone_InfiniteTower"} do local m=markers:FindFirstChild(name);if m then m:Clone().Parent=backup end end
	local floors={}
	for _,f in tower:GetChildren() do
		local n=tonumber(f.Name:match("^TowerFloor_?(%d+)$"))
		if n and f:IsA("Model") then floors[n]=f end
	end
	assert(#floors==22,"Expected the existing 22 floors")
	local site=Vector3.new(-135,7.4,-95)
	local spawn=markers.Spawn.Position
	local facing=CFrame.lookAt(site,Vector3.new(spawn.X,site.Y,spawn.Z))
	local WOOD=Color3.fromRGB(43,29,24)
	local ROOF=Color3.fromRGB(29,33,40)
	local ORANGE=Color3.fromRGB(214,132,62)
	local function part(parent,name,size,cf,color,material,solid)
		local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
		p.Material=material or Enum.Material.Wood;p.Anchored=true
		p.CanCollide=solid==true;p.CanTouch=false;p.CanQuery=solid==true;p.CastShadow=solid==true
		p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
		return p
	end
	local function edge(parent,name,a,b,width,color,material)
		return part(parent,name,Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,material)
	end
	local baseWidth=floors[1].Foundation.Size.X*1.7
	local nextBottom=0
	for i,f in floors do
		local foundation=f.Foundation
		local width=baseWidth*(if i==1 then 1 else .6*.94^(i-2))
		f:ScaleTo(f:GetScale()*width/foundation.Size.X)
		foundation=f.Foundation
		-- All height calculations use named structural parts, never model bounds or decorations.
		local origin=CFrame.new(foundation.Position.X,foundation.Position.Y-foundation.Size.Y/2,foundation.Position.Z)
		local offset=facing*CFrame.new(0,nextBottom,0)*origin:Inverse()
		for _,p in f:GetDescendants() do if p:IsA("BasePart") then p.CFrame=offset*p.CFrame;p.Anchored=true;p.CanTouch=false end end
		local floorOrigin=facing*CFrame.new(0,nextBottom,0)
		local core=f.Core
		local height=core.Size.Y
		local center=floorOrigin:PointToObjectSpace(core.Position).Y
		local wallTop=center+height/2
		local half=core.Size.X/2
		local roofOld=f:FindFirstChild("RoofTrim") or f:FindFirstChild("RoofEaveLower")
		local overhang=if roofOld then roofOld.Size.X/2 else width*.64
		local decor=Instance.new("Folder");decor.Name="ReferenceDetails";decor.Parent=f
		-- Existing slabs / crossed lattice volumes are replaced only where a real facade / roof goes.
		for _,p in f:GetChildren() do
			if p:IsA("BasePart") and (p.Name:match("^Roof") or p.Name:match("^Vert") or p.Name:match("^Bar")) then p:Destroy() end
		end
		core.Size=Vector3.new(math.max(1,half*2-1.8),height,math.max(1,half*2-1.8))
		core.Color=WOOD;core.Material=Enum.Material.WoodPlanks
		local tint=if i==1 then Color3.fromRGB(170,130,90) else ORANGE
		local panels={f.WindowNS,f.WindowEW,f.WindowNS:Clone(),f.WindowEW:Clone()}
		for side=1,4 do
			local sideCf=floorOrigin*CFrame.Angles(0,(side-1)*math.pi/2,0)
			local panel=panels[side];panel.Name="RecessedWindow"..side
			panel.Size=Vector3.new(math.max(1,half*2-2),height*.64,.18)
			panel.CFrame=sideCf*CFrame.new(0,center,-half+.3)
			panel.Material=Enum.Material.Neon;panel.Color=tint;panel.CanCollide=false;panel.CastShadow=false;panel.Parent=decor
			-- Five timber posts across each wall; corner posts project beyond the recessed windows.
			for quarter=0,4 do
				local x=-half+quarter*half/2
				part(decor,"FacadePillar",Vector3.new(.9,height, .8),sideCf*CFrame.new(x,center,-half),WOOD)
			end
			for _,y in {center-height/2+.25,center+height/2-.25} do
				part(decor,"WallBeam",Vector3.new(half*2,.5,.85),sideCf*CFrame.new(0,y,-half),WOOD)
			end
			for grid=1,9 do
				part(decor,"WindowMullion",Vector3.new(.12,height*.64,.24),sideCf*CFrame.new(-half+grid*half/5,center,-half+.15),WOOD)
			end
			for _,y in {center-height*.18,center,center+height*.18} do
				part(decor,"WindowRail",Vector3.new(half*2-2,.1,.24),sideCf*CFrame.new(0,y,-half+.15),WOOD)
			end
		end
		-- Four faceted hip slopes per side, flatter toward the eaves, then a gentle upturned lip.
		local roofSpan=overhang-half*.43
		local rise=height*.24
		local inner=half*.43
		local ys={wallTop+rise,wallTop+rise*.50,wallTop+rise*.22,wallTop+rise*.10,wallTop+rise*.17}
		local roofPoints={}
		for segment=1,5 do roofPoints[segment]={R=inner+roofSpan*(segment-1)/4,Y=ys[segment]} end
		for side=0,3 do
			local sideCf=floorOrigin*CFrame.Angles(0,side*math.pi/2,0)
			for segment=1,4 do
				local a,b=roofPoints[segment],roofPoints[segment+1]
				local span=b.R-a.R;local dy=b.Y-a.Y
				local length=math.sqrt(span*span+dy*dy)
				local r=(a.R+b.R)/2
				local slope=part(decor,"CurvedRoofSlope",Vector3.new(b.R*2,.22,length+.10),
					sideCf*CFrame.new(0,(a.Y+b.Y)/2,-r)*CFrame.Angles(math.atan2(dy,span),0,0),ROOF,Enum.Material.Slate)
				slope:SetAttribute("RoofSegment",segment)
			end
			-- Narrow diagonal corner ridges follow the same curve instead of a single straight bar.
			for segment=1,4 do
				local a,b=roofPoints[segment],roofPoints[segment+1]
				edge(decor,"HipRidge",sideCf:PointToWorldSpace(Vector3.new(a.R,a.Y+.16,-a.R)),sideCf:PointToWorldSpace(Vector3.new(b.R,b.Y+.16,-b.R)),.20,Color3.fromRGB(62,66,73),Enum.Material.Slate)
			end
			local tip=sideCf:PointToWorldSpace(Vector3.new(overhang,ys[5],-overhang))
			edge(decor,"UpturnedCorner",tip,sideCf:PointToWorldSpace(Vector3.new(overhang+.7,ys[5]+.7,-overhang-.7)),.25,ROOF,Enum.Material.Slate)
			if i==1 then
				local y=wallTop+rise*.28
				local peak=Vector3.new(0,y+4,-overhang*.80)
				edge(decor,"GrandHallGable",sideCf:PointToWorldSpace(Vector3.new(-6,y,-overhang*.80)),sideCf:PointToWorldSpace(peak),.6,ROOF,Enum.Material.Slate)
				edge(decor,"GrandHallGable",sideCf:PointToWorldSpace(peak),sideCf:PointToWorldSpace(Vector3.new(6,y,-overhang*.80)),.6,ROOF,Enum.Material.Slate)
			end
		end
		-- A named top roof deck supports the next foundation; eave decorations never affect stacking.
		local topY=wallTop+rise+.15
		local top=part(decor,"TopRoof",Vector3.new(inner*2,.3,inner*2),floorOrigin*CFrame.new(0,topY,0),ROOF,Enum.Material.Slate)
		f:SetAttribute("FoundationBottom",nextBottom)
		f:SetAttribute("TopRoofHeight",nextBottom+topY+.15)
		nextBottom+=topY+.15
		for _,p in f:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored=true
				if p.Name~="Core" and p.Name~="Foundation" then p.CanCollide=false;p.CanQuery=false;p.CastShadow=false end
			elseif p:IsA("PointLight") then p.Brightness=.6;p.Range=math.min(7,p.Range);p.Shadows=false end
		end
		task.wait()
	end
	local siteParts=Instance.new("Folder");siteParts.Name="TowerApproach";siteParts.Parent=tower
	local plinth=part(siteParts,"GrandHallPlinth",Vector3.new(baseWidth+5,2,baseWidth+5),facing*CFrame.new(0,-1,0),Color3.fromRGB(62,59,56),Enum.Material.Slate,true)
	for i=1,5 do
		part(siteParts,"EntranceStep",Vector3.new(13, .4*i,2.6),facing*CFrame.new(0,-2+.2*i,-baseWidth/2-2-(5-i)*2.2),Color3.fromRGB(73,70,65),Enum.Material.Slate,true)
	end
	-- The first floor keeps its wall, but the front doorway / porch gives a clear playable entry.
	local door=part(siteParts,"Entrance",Vector3.new(7,9,.3),facing*CFrame.new(0,4.5,-baseWidth/2-.3),Color3.fromRGB(25,21,23),Enum.Material.Wood)
	local prompt=Instance.new("ProximityPrompt");prompt.Name="TowerPrompt";prompt.ActionText="Climb the tower";prompt.ObjectText="Infinite Tower"
	prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.HoldDuration=0;prompt.MaxActivationDistance=16;prompt.RequiresLineOfSight=false;prompt:SetAttribute("Npc","tower");prompt.Parent=door
	local mist=part(siteParts,"EmberVolume",Vector3.new(baseWidth+8,.1,baseWidth+8),facing*CFrame.new(0,.4,0),ORANGE)
	mist.Transparency=1
	local embers=Instance.new("ParticleEmitter");embers.Name="TowerEmbers";embers.Texture="rbxasset://textures/particles/sparkles_main.dds"
	embers.Color=ColorSequence.new(ORANGE,Color3.fromRGB(255,206,118));embers.LightEmission=1;embers.Rate=9
	embers.Speed=NumberRange.new(1.5,3);embers.Lifetime=NumberRange.new(2,4);embers.EmissionDirection=Enum.NormalId.Top
	embers.Size=NumberSequence.new(.12,0);embers.Transparency=NumberSequence.new(.25,1);embers:SetAttribute("TownFxRange",100);embers.Parent=mist
	local towerMarker=markers.Tower;towerMarker.CFrame=facing*CFrame.new(0,0,-baseWidth/2-.3)
	local zone=markers:FindFirstChild("Zone_InfiniteTower");zone.CFrame=CFrame.new(site);zone:SetAttribute("Radius",46)
	-- Rehome only small trees that intersect the new hall, retaining their original models / a backup.
	local trees={}
	for _,p in workspace:GetPartBoundsInBox(CFrame.new(site+Vector3.new(0,12,0)),Vector3.new(baseWidth+6,30,baseWidth+6)) do
		local m=p:FindFirstAncestorOfClass("Model")
		if m and m:IsDescendantOf(workspace.Map.Town) and m.Name:match("^Tree") then trees[m]=true end
	end
	local count=0
	for tree in trees do
		count+=1;local saved=tree:Clone();saved.Name=tree.Name;saved.Parent=backup
		tree:PivotTo(tree:GetPivot()+Vector3.new(-45,0,if count%2==0 then -40 else 40))
		task.wait()
	end
	tower:SetAttribute("ReferencePolishVersion",1)
	tower:SetAttribute("EntranceCFrame",door.CFrame)
	tower:SetAttribute("NightRadius",46)
	finishApproach()
	return {Floors=#floors,Height=nextBottom,BaseWidth=baseWidth,Site=tostring(site),TreesMoved=count,Backup=backup:GetFullName()}
end
