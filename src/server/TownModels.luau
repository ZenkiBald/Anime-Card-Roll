--!nonstrict
-- Original service NPCs made from simple Roblox parts; bosses keep their existing models.
local TownModels = {}
local SKIN = Color3.fromRGB(225,183,146)
local DARK = Color3.fromRGB(34,29,36)
local GOLD = Color3.fromRGB(208,169,83)
local LOOKS = {
	sage = { Coat = Color3.fromRGB(57,113,89), Trim = Color3.fromRGB(221,208,164), Hair = Color3.fromRGB(205,206,194) },
	fuser = { Coat = Color3.fromRGB(53,70,93), Trim = Color3.fromRGB(180,112,62), Hair = Color3.fromRGB(50,34,33) },
	traitmaster = { Coat = Color3.fromRGB(31,93,101), Trim = Color3.fromRGB(185,211,204), Hair = Color3.fromRGB(27,36,46) },
	fortune = { Coat = Color3.fromRGB(100,52,132), Trim = Color3.fromRGB(220,176,79), Hair = Color3.fromRGB(37,28,62) },
}

local function piece(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function TownModels.Has(id) return LOOKS[id] ~= nil end
function TownModels.Height(_id) return 6.4 end

local function costume(id)
	local look = assert(LOOKS[id])
	local model = Instance.new("Model")
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local function p(name,size,cf,color,material,shape) return piece(model,name,size,cf,color,material,shape) end
	local root = p("Root",Vector3.one,CFrame.new(0,3.2,0),SKIN)
	root.Transparency = 1
	model.PrimaryPart = root
	for _,x in {-0.54,0.54} do
		p("Boot",Vector3.new(.92,.55,1.12),CFrame.new(x,.35,-.04),DARK)
		p("Leg",Vector3.new(.92,1.65,1),CFrame.new(x,1.35,0),look.Coat:Lerp(DARK,.35))
	end
	p("Coat",Vector3.new(2.15,2.35,1.15),CFrame.new(0,3.2,0),look.Coat)
	p("Hem",Vector3.new(2.2,.25,1.19),CFrame.new(0,2.12,0),look.Trim)
	p("Belt",Vector3.new(2.22,.26,1.22),CFrame.new(0,2.7,0),look.Trim)
	p("Buckle",Vector3.new(.36,.34,.12),CFrame.new(0,2.7,-.66),GOLD,Enum.Material.Metal)
	p("Collar",Vector3.new(.68,.52,.12),CFrame.new(0,4.15,-.62),look.Trim)
	for i,x in {-1.55,1.55} do
		local cf = CFrame.new(x,3.1,-.08) * CFrame.Angles(math.rad(if i==1 then -9 else -18),0,math.rad(if i==1 then -8 else 8))
		p("Sleeve",Vector3.new(.9,1.6,1),cf,look.Coat)
		p("Cuff",Vector3.new(.94,.25,1.04),cf*CFrame.new(0,-.64,0),look.Trim)
		p("Hand",Vector3.new(.78,.62,.84),cf*CFrame.new(0,-1,0),SKIN)
	end
	p("Neck",Vector3.new(.64,.45,.64),CFrame.new(0,4.5,0),SKIN)
	p("Head",Vector3.new(1.5,1.4,1.4),CFrame.new(0,5.12,0),SKIN)
	p("Hair",Vector3.new(1.57,.49,1.46),CFrame.new(0,5.71,.03),look.Hair)
	for _,x in {-.79,.79} do p("SideHair",Vector3.new(.13,.6,1.2),CFrame.new(x,5.31,.14),look.Hair) end
	for _,x in {-.34,.34} do
		p("Eye",Vector3.new(.11,.16,.035),CFrame.new(x,5.13,-.715),DARK)
		p("Brow",Vector3.new(.27,.055,.04),CFrame.new(x,5.4,-.72),look.Hair)
	end
	p("Smile",Vector3.new(.32,.055,.04),CFrame.new(0,4.82,-.72),Color3.fromRGB(129,75,63))
	if id == "sage" then
		p("HatBrim",Vector3.new(.14,3.2,3.2),CFrame.new(0,5.92,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(211,184,116),nil,Enum.PartType.Cylinder)
		p("HatCrown",Vector3.new(.62,1.6,1.6),CFrame.new(0,6.2,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(190,161,93),nil,Enum.PartType.Cylinder)
		p("GuideBook",Vector3.new(.88,1.16,.25),CFrame.new(-1.65,2.5,-.75)*CFrame.Angles(0,0,-.3),Color3.fromRGB(51,91,69))
		p("BookPages",Vector3.new(.72,1.04,.27),CFrame.new(-1.65,2.5,-.76)*CFrame.Angles(0,0,-.3),Color3.fromRGB(232,221,183))
	elseif id == "fuser" then
		p("Apron",Vector3.new(1.65,1.85,.13),CFrame.new(0,2.86,-.65),look.Trim)
		p("Pocket",Vector3.new(.86,.58,.12),CFrame.new(0,2.65,-.75),look.Trim:Lerp(DARK,.22))
		p("GoggleStrap",Vector3.new(1.58,.17,1.43),CFrame.new(0,5.55,0),DARK)
		for _,x in {-.37,.37} do p("Goggle",Vector3.new(.5,.34,.18),CFrame.new(x,5.58,-.77),Color3.fromRGB(104,208,223),Enum.Material.Glass) end
		p("HammerHandle",Vector3.new(.18,1.55,.18),CFrame.new(1.75,2.26,-.65)*CFrame.Angles(0,0,.2),Color3.fromRGB(91,56,37),Enum.Material.Wood)
		p("HammerHead",Vector3.new(.94,.5,.52),CFrame.new(1.61,2.97,-.65),Color3.fromRGB(118,131,142),Enum.Material.Metal)
	elseif id == "traitmaster" then
		p("Scarf",Vector3.new(2.25,.4,1.24),CFrame.new(0,4.17,0),look.Trim)
		p("ScarfTail",Vector3.new(.4,1.85,.13),CFrame.new(-.58,3.38,-.7),look.Trim)
		p("HairKnot",Vector3.new(.7,.65,.7),CFrame.new(0,6.05,.35),look.Hair,nil,Enum.PartType.Ball)
		p("HairStreak",Vector3.new(.2,.55,.13),CFrame.new(.26,5.7,-.71),Color3.fromRGB(194,213,211))
		p("FocusStaff",Vector3.new(.16,4.6,.16),CFrame.new(-1.86,2.6,-.48),Color3.fromRGB(77,57,44),Enum.Material.Wood)
		p("FocusCrystal",Vector3.new(.62,.94,.62),CFrame.new(-1.86,5.1,-.48)*CFrame.Angles(0,0,.35),Color3.fromRGB(95,216,203),Enum.Material.Glass)
	else
		p("Skirt",Vector3.new(2.32,1.25,1.42),CFrame.new(0,1.95,.05),look.Coat)
		p("HeadWrap",Vector3.new(1.68,.62,1.54),CFrame.new(0,5.68,0),look.Coat)
		p("HeadJewel",Vector3.new(.3,.4,.16),CFrame.new(0,5.61,-.83),GOLD,Enum.Material.Metal)
		for _,x in {-.85,.85} do p("Earring",Vector3.new(.18,.34,.18),CFrame.new(x,4.9,-.02),GOLD,Enum.Material.Metal) end
		for i=1,3 do p("FortuneCard",Vector3.new(.5,.72,.08),CFrame.new(1.65+(i-2)*.19,2.6,-.8)*CFrame.Angles(0,0,(i-2)*.3),Color3.fromRGB(219,198,130)) end
	end
	return model
end

function TownModels.Build(id)
	local look=assert(LOOKS[id])
	local desc=Instance.new("HumanoidDescription")
	desc.HeadColor=SKIN; desc.LeftArmColor=look.Coat; desc.RightArmColor=look.Coat
	desc.TorsoColor=look.Coat; desc.LeftLegColor=look.Coat:Lerp(DARK,.35); desc.RightLegColor=desc.LeftLegColor
	desc.BodyTypeScale=0; desc.ProportionScale=0
	local ok,rig=pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(desc,Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok then
		-- A temporary avatar-service outage must not remove the town's service prompts.
		warn("[TownModels] Avatar rig unavailable; using service fallback: " .. tostring(rig))
		return costume(id)
	end
	rig.Name=id; rig.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
	local root=rig:FindFirstChild("HumanoidRootPart")
	rig.PrimaryPart=root
	local humanoid=rig:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed=0; humanoid.AutoRotate=false
	if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator",humanoid) end
	rig:SetAttribute("TownRig",true)
	rig:SetAttribute("IdleAnimation","rbxassetid://507766666")
	for _,inst in rig:GetDescendants() do
		if inst:IsA("BaseScript") then inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored=inst==root; inst.CanCollide=false; inst.CanTouch=false; inst.CanQuery=false; inst.Massless=true
			if inst.Name:find("Hand") then inst.Color=SKIN elseif inst.Name:find("Foot") then inst.Color=DARK end
		end
	end
	-- Reuse original themed tools / clothes as welded accessories on the real articulated body.
	local props=costume(id)
	local keep={HatBrim=true,HatCrown=true,GuideBook=true,BookPages=true,Apron=true,Pocket=true,
		GoggleStrap=true,Goggle=true,HammerHandle=true,HammerHead=true,Scarf=true,ScarfTail=true,
		FocusStaff=true,FocusCrystal=true,HeadWrap=true,HeadJewel=true,Earring=true,FortuneCard=true,Belt=true,Buckle=true}
	local head=rig:FindFirstChild("Head")
	local torso=rig:FindFirstChild("UpperTorso")
	for _,piece in props:GetChildren() do
		if piece:IsA("BasePart") and keep[piece.Name] then
			local target=if piece.Position.Y>=4.7 then head else torso
			piece.CFrame=root.CFrame*CFrame.new(0,-3.2,0)*piece.CFrame
			piece.Anchored=false; piece.Massless=true; piece.Parent=rig
			local weld=Instance.new("WeldConstraint"); weld.Part0=target; weld.Part1=piece; weld.Parent=piece
		end
	end
	props:Destroy()
	-- Rounded hair silhouette, rather than a rectangular brick over the head.
	for i=1,3 do
		local hair=piece(rig,"HairLock",Vector3.new(.75,.7,.85),head.CFrame*CFrame.new((i-2)*.42,.55,.08),look.Hair,nil,Enum.PartType.Ball)
		hair.Anchored=false; hair.Massless=true
		local weld=Instance.new("WeldConstraint"); weld.Part0=head; weld.Part1=hair; weld.Parent=hair
	end
	return rig
end

return TownModels
