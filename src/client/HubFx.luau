--!nonstrict
-- Hub life, all client-side: NPC figures breathe and sway, void shards spin, Kenji the
-- Card Sage gives tips when you talk to him, and each portal sign shows whether it's open for you
-- (the Infinite Tower's sign shows your best floor).
-- On spawn the camera turns to look the way the spawn faces (Roblox starts it facing -Z).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared.Bosses)

local State = require(script.Parent.State)
local Theme = require(script.Parent.UI.Theme)

local HubFx = {}

local TIPS = {
	"Attack cards deal the damage and take every boss hit. Keep them alive!",
	"Support cards can't be hit. They heal, shield and buff from the back row.",
	"Each Support helps the Attack card in its matching numbered slot; it does not attack.",
	"A card glowing gold has a full Ultimate. Tap it, or switch on AUTO ULT.",
	"Red marker over your cards? A big boss move lands in a moment.",
	"Beat a boss to fire a burst of reward rolls with boosted luck.",
	"Your first clear of each fight adds a bonus card above the reward floor.",
	"Clear Normal to open Hard, and Hard to open Nightmare.",
	"Galactic Emperor's Crystal Spear freezes a card: it skips its next action.",
	"Mirror Flower Overlord's Hollow Veil shrugs off Basic hits. Break it with Skills and Ultimates.",
	"Duplicates give fusion copies, never bonus DMG or HP.",
	"Bring 100 copies of one border to Hoshi to fuse a copy of the next border. Every duplicate adds +0.5% stats.",
	"Find every card of a rarity in the INDEX for permanent luck and a prize.",
	"Luck Potions stack time, not power: the strongest running potion counts.",
	"Come back every day: the daily streak in QUESTS gets better until day 7.",
	"Spend Shards in SQUAD > UPGRADES on faster rolls and more base luck.",
	"Stay a while! Playtime gifts unlock the longer you play this session.",
	"Long reveal? Tap SKIP to jump straight to the card.",
	"The Infinite Tower never ends: every floor is a new foe, and every 10th a Guardian, and from floor 50 a rare relic can drop.",
	"Kenshin the Trait Master, beside Hoshi, rolls traits for Trait Shards. Bosses, the tower and raids pay them.",
	"Win different story boss challenges with a card to earn battle mastery. Duplicate copies are for border fusion.",
	"Every 25th roll is an Overcharge Surge: wait for the gold ring, then tap ROLL for three cards at once (a tap before it lights only gets the plain surge).",
	"Fill a boss's Shield bar to break it: it's stunned for 6 s and takes 1.5x damage. Hold your Ultimates for it.",
	"When a boss's big move flashes a CLASH ring, tap it (or press Space) to parry: 75% less damage and a counter.",
	"Hoshi condenses ten Roll Packs into a Big Roll Pack, and infuses Mega Packs with an element.",
	"Every boss fights with three guards. Tap an enemy to focus fire: take out the Mender before it heals!",
	"A Warder taunts your cards and shields its leader. Kill it, or tap the leader to hit past it.",
	"You win the moment the leader falls, even with guards still standing.",
}

local animated = {} -- [Model] = { Base, Phase }
local spinners = {} -- [BasePart] = { Base, Phase }
local turners = {} -- [Model] = { Base, Speed }: Madame Fortuna's wheel, turning about its face
local townFx = {} -- the two new tower emitters; bounded independently of the skyline parts
local townLights={}
local tipIndex = 0
local bubble: any = nil -- Kenji's speech bubble (children read by name)
local bubbleToken = 0

local function track(inst: Instance)
	if inst:IsA("PointLight") and inst:GetAttribute("TownLightRange") then townLights[inst]={Brightness=inst.Brightness,Range=inst:GetAttribute("TownLightRange")} end
	if inst:IsA("ParticleEmitter") and inst:GetAttribute("TownFxRange") then
		townFx[inst]={Rate=inst.Rate,Range=inst:GetAttribute("TownFxRange")}
	end
	if inst:IsA("Model") and inst:GetAttribute("TownRig") and not animated[inst] then
		local humanoid=inst:FindFirstChildOfClass("Humanoid")
		local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local idle=Instance.new("Animation")
			idle.AnimationId=inst:GetAttribute("IdleAnimation")
			pcall(function()
				local track=animator:LoadAnimation(idle)
				track.Looped=true; track.Priority=Enum.AnimationPriority.Idle; track:Play()
			end)
			idle:Destroy()
		end
	end
	if inst:IsA("Model") and inst:GetAttribute("Bob") then
		local base = inst:GetAttribute("BaseCFrame")
		if typeof(base) == "CFrame" then
			animated[inst] = { Base = base, Phase = math.random() * 10 }
		end
	elseif inst:IsA("BasePart") and inst:GetAttribute("Spin") then
		spinners[inst] = { Base = inst.CFrame, Phase = math.random() * 10 }
	elseif inst:IsA("Model") and type(inst:GetAttribute("Turn")) == "number" then
		turners[inst] = { Base = inst:GetPivot(), Speed = inst:GetAttribute("Turn") }
	end
end

local function setSub(anchor, value, color)
	if not anchor then return end
	for _,gui in anchor:GetChildren() do
		if gui:IsA("SurfaceGui") or gui:IsA("BillboardGui") then
			local sub=gui:FindFirstChild("Sub",true)
			if sub and sub:IsA("TextLabel") then
				sub.Text=value
				if color then sub.TextColor3=color end
			end
		end
	end
end

local function refreshSigns(hub: Instance)
	local cleared = State.Progress.Cleared or {}
	for _,boss in Bosses.List do
		local area=hub:FindFirstChild("World" .. tostring(boss.World))
		local anchor=area and area:FindFirstChild("GateGlow")
		if Bosses.IsUnlocked(cleared,boss.Id,"Normal") then
			local done=0
			for _,difficulty in Bosses.DifficultyOrder do
				if cleared[Bosses.FightKey(boss.Id,difficulty)] then done+=1 end
			end
			setSub(anchor,boss.Name .. " · " .. tostring(done) .. "/" .. tostring(#Bosses.DifficultyOrder) .. " cleared",boss.Accent)
		else
			setSub(anchor,"LOCKED · " .. Bosses.UnlockHint(boss.Id,"Normal"),Color3.fromRGB(180,181,192))
		end
	end
	local gate=hub:FindFirstChild("TowerGate")
	if gate and State.Tower.Best > 0 then
		setSub(gate:FindFirstChild("SignAnchor"),"Best: " .. tostring(State.Tower.Best) .. " · Next: floor " .. tostring(State.Tower.Run+1))
	end
end

-- Kenji's speech bubble with the next tip.
function HubFx.SageTalk(prompt: ProximityPrompt)
	local root = prompt.Parent
	if root == nil or not root:IsA("BasePart") then
		return
	end
	tipIndex = tipIndex % #TIPS + 1
	bubbleToken += 1
	local token = bubbleToken
	if bubble == nil or bubble.Parent == nil then
		bubble = Instance.new("BillboardGui")
		bubble.Name = "TipBubble"
		bubble.Size = UDim2.fromOffset(300, 90)
		bubble.StudsOffset = Vector3.new(0, 7, 0)
		bubble.MaxDistance = 60
		bubble.LightInfluence = 0
		local frame = Instance.new("Frame")
		frame.Name = "Bubble"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(24, 21, 40)
		frame.BackgroundTransparency = 0.1
		frame.Parent = bubble
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 214, 120)
		stroke.Thickness = 2
		stroke.Parent = frame
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.05, 0.08)
		text.Size = UDim2.fromScale(0.9, 0.84)
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.fromRGB(231, 243, 255)
		text.TextScaled = true
		text.TextWrapped = true
		text.Parent = frame
	end
	bubble.Parent = root
	local frame = bubble:FindFirstChild("Bubble")
	local label = frame and frame:FindFirstChild("Text")
	if label then
		label.Text = TIPS[tipIndex]
	end
	task.delay(7, function()
		if token == bubbleToken and bubble then
			bubble.Parent = nil
		end
	end)
end

-- Puts the camera behind the character, looking where it faces (after a spawn or a fast travel).
function HubFx.CameraBehind(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end
	task.wait(0.1) -- let the camera module take a new character first
	local look = root.CFrame.LookVector
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(focus - look * 12 + Vector3.new(0, 3.5, 0), focus)
end

-- Physical plaques and compact NPC plates fade over the final 20% of their visibility range.

-- While a panel, a fight or a reveal is up, world signs and players' name tags hide, so no plate reads
-- through a panel or bleeds into the top HUD. `reason` keys stack (Modal / Battle / Reveal).
local hiddenBy: { [string]: boolean? } = {}
local function worldHidden(): boolean
	return next(hiddenBy) ~= nil
end

local function applyNameTags()
	local hide = worldHidden()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local tag = root and root:FindFirstChild("NameTag")
		if tag and tag:IsA("BillboardGui") then
			tag.Enabled = not hide
		end
	end
end

function HubFx.SetWorldLabelsHidden(reason: string, on: boolean)
	hiddenBy[reason] = if on then true else nil
	applyNameTags()
end

local function fadeSigns()
	local camera=Workspace.CurrentCamera
	if not camera then return end
	local hide=worldHidden()
	local lights={}
	for light,info in townLights do
		if not light.Parent then townLights[light]=nil;continue end
		local anchor=light.Parent
		local distance=if anchor:IsA("BasePart") then (anchor.Position-camera.CFrame.Position).Magnitude else math.huge
		light.Enabled=false
		if not hide and not Theme.FxLow and distance<info.Range then table.insert(lights,{Light=light,Distance=distance}) end
	end
	table.sort(lights,function(a,b) return a.Distance<b.Distance end)
	for i=1,math.min(6,#lights) do lights[i].Light.Enabled=true end
	for emitter,info in townFx do
		if not emitter.Parent then townFx[emitter]=nil; continue end
		local anchor=emitter.Parent
		emitter.Enabled=not hide and anchor:IsA("BasePart") and (anchor.Position-camera.CFrame.Position).Magnitude<info.Range
		emitter.Rate=info.Rate*(if Theme.FxLow then .25 else 1)
	end
	local signs=CollectionService:GetTagged("FadeSign")
	local occupied={}
	local function distanceTo(gui)
		local anchor=gui.Adornee or gui.Parent
		return if anchor and anchor:IsA("BasePart") then (anchor.Position-camera.CFrame.Position).Magnitude else math.huge
	end
	table.sort(signs,function(a,b) return distanceTo(a)<distanceTo(b) end)
	for _,gui in signs do
		if not (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) then continue end
		gui.Enabled=not hide
		if hide then continue end
		local anchor=gui.Adornee or gui.Parent
		local position=if anchor and anchor:IsA("BasePart") then anchor.Position elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition else nil
		if not position then continue end
		local distance=(position-camera.CFrame.Position).Magnitude
		local far=math.max(gui.MaxDistance,2)
		local fade=math.clamp((distance-far*.8)/(far*.2),0,1)
		if gui:IsA("BillboardGui") and gui:GetAttribute("NearTitle") then
			local pos,onScreen=camera:WorldToViewportPoint(position+gui.StudsOffsetWorldSpace)
			local scale=math.clamp(camera.ViewportSize.Y/520,.72,1)
			gui.Size=UDim2.fromOffset(178*scale,48*scale)
			local box={ X=pos.X-89*scale, Y=pos.Y-24*scale, W=178*scale, H=48*scale }
			local blocked=not onScreen or distance>far or box.Y<math.min(114,camera.ViewportSize.Y*.23)
			for _,other in occupied do
				if box.X<other.X+other.W+5 and box.X+box.W+5>other.X and box.Y<other.Y+other.H+5 and box.Y+box.H+5>other.Y then blocked=true; break end
			end
			if blocked then gui.Enabled=false; continue end
			table.insert(occupied,box)
		end
		if gui:IsA("BillboardGui") and gui:GetAttribute("Destination") then
			local scale=math.clamp(1-distance/800,.68,1)*math.clamp(camera.ViewportSize.Y/600,.8,1)
			gui.Size=UDim2.fromOffset(290*scale,72*scale)
		end
		local plate=gui:FindFirstChild("Plate")
		if plate and plate:IsA("CanvasGroup") then
			plate.GroupTransparency=fade
			local nearTitle=gui:GetAttribute("NearTitle")
			if type(nearTitle)=="string" then
				local limit=gui:GetAttribute("DetailRange") or 38
				local near=distance <= limit+(if gui:GetAttribute("ShowingDetail") then 4 else -4)
				gui:SetAttribute("ShowingDetail",near)
				local title=plate:FindFirstChild("Title")
				local sub=plate:FindFirstChild("Sub")
				if title then
					title.Text=if near then nearTitle else gui:GetAttribute("ShortTitle") or nearTitle
					title.Position=UDim2.fromScale(.04,if near then .03 else .14)
					title.Size=UDim2.fromScale(.92,if near then .51 else .7)
				end
				if sub then sub.Visible=near end
			end
		else
			for _,label in gui:GetDescendants() do
				if label:IsA("TextLabel") then label.TextTransparency=fade end
			end
		end
	end
end

function HubFx.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			fadeSigns()
			if worldHidden() then
				applyNameTags() -- tags of players who spawn while it's hidden
			end
		end
	end)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(HubFx.CameraBehind)
	if player.Character then
		task.spawn(HubFx.CameraBehind, player.Character)
	end

	task.spawn(function()
		local hub = Workspace:WaitForChild("Hub", 30)
		if hub == nil then
			return
		end
		for _,inst in CollectionService:GetTagged("TownAmbientFx") do track(inst) end
		CollectionService:GetInstanceAddedSignal("TownAmbientFx"):Connect(track)
		for _, inst in hub:GetDescendants() do
			track(inst)
		end
		hub.DescendantAdded:Connect(function(inst)
			task.defer(track, inst)
			if inst.Name == "Sign" then
				task.defer(refreshSigns, hub) -- with streaming, portals arrive as you walk up to them
			end
		end)
		refreshSigns(hub)
		State.Changed:Connect(function(kind)
			if kind == "progress" or kind == "all" then
				refreshSigns(hub)
			end
		end)

		local camera = Workspace.CurrentCamera
		RunService.RenderStepped:Connect(function()
			if State.InBattle then
				return -- the battle screen covers the hub
			end
			local t = os.clock()
			local eye = camera.CFrame.Position
			for model, info in animated do
				if model.Parent == nil then
					animated[model] = nil
				elseif (info.Base.Position - eye).Magnitude < 160 then
					local p = t + info.Phase
					model:PivotTo(info.Base * CFrame.new(0, math.sin(p * 1.7) * 0.18, 0) * CFrame.Angles(0, math.sin(p * 0.5) * 0.12, 0))
				end
			end
			for part, info in spinners do
				if part.Parent == nil then
					spinners[part] = nil
				else
					local p = t + info.Phase
					part.CFrame = info.Base * CFrame.new(0, math.sin(p * 1.3) * 0.6, 0) * CFrame.Angles(p * 0.9, p * 1.2, 0)
				end
			end
			for model, info in turners do
				if model.Parent == nil then
					turners[model] = nil
				elseif (info.Base.Position - eye).Magnitude < 160 then
					model:PivotTo(info.Base * CFrame.Angles(t * info.Speed, 0, 0)) -- the hub cylinder's axis (X) is the wheel's face normal
				end
			end
		end)
	end)
end

return HubFx
