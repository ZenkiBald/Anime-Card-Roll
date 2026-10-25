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

local HubFx = {}

local TIPS = {
	"Attack cards deal the damage and take every boss hit. Keep them alive!",
	"Support cards can't be hit. They heal, shield and buff from the back row.",
	"Every Support card casts its Basic the moment a fight starts.",
	"A card glowing gold has a full Ultimate. Tap it, or switch on AUTO ULT.",
	"Red marker over your cards? A big boss move lands in a moment.",
	"Beat a boss to fire a burst of reward rolls with boosted luck.",
	"Your first clear of each fight adds a bonus card above the reward floor.",
	"Clear Normal to open Hard, and Hard to open Nightmare.",
	"Galactic Emperor's Crystal Spear freezes a card: it skips its next action.",
	"Mirror Flower Overlord's Hollow Veil shrugs off Basic hits. Break it with Skills and Ultimates.",
	"Duplicates add stars: +5% stats each, up to 5 stars.",
	"After 5 stars every copy counts: bring 100 to Hoshi and he fuses the card into the next rarity!",
	"Find every card of a rarity in the INDEX for permanent luck and a prize.",
	"Luck Potions stack time, not power: the strongest running potion counts.",
	"Come back every day: the daily streak in QUESTS gets better until day 7.",
	"Spend Shards in SQUAD > UPGRADES on faster rolls and more base luck.",
	"Stay a while! Playtime gifts unlock the longer you play this session.",
	"Long reveal? Tap SKIP to jump straight to the card.",
	"The Infinite Tower never ends: every floor is a new foe, and every 10th a Guardian, and from floor 50 a rare relic can drop.",
	"Kenshin the Trait Master, beside Hoshi, rolls traits for Trait Shards. Bosses, the tower and raids pay them.",
	"Every 20 copies of a card open an Awakening node: stats, Skill damage, a stronger bond, then a second trait slot.",
	"Every 25th roll is an Overcharge Surge: wait for the gold ring, then tap ROLL for three cards at once (a tap before it lights only gets the plain surge).",
	"Fill a boss's Stagger bar with counter elements: it can't act, drops its DEF and takes +50% from Ultimates.",
	"Hoshi condenses ten Roll Packs into a Big Roll Pack, and infuses Mega Packs with an element.",
	"Every boss fights with three guards. Tap an enemy to focus fire: take out the Mender before it heals!",
	"A Warder taunts your cards and shields its leader. Kill it, or tap the leader to hit past it.",
	"You win the moment the leader falls, even with guards still standing.",
}

local animated = {} -- [Model] = { Base, Phase }
local spinners = {} -- [BasePart] = { Base, Phase }
local turners = {} -- [Model] = { Base, Speed }: Madame Fortuna's wheel, turning about its face
local tipIndex = 0
local bubble: any = nil -- Kenji's speech bubble (children read by name)
local bubbleToken = 0

local function track(inst: Instance)
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

local function refreshSigns(hub: Instance)
	local cleared = State.Progress.Cleared or {}
	for _, boss in Bosses.List do
		local area = hub:FindFirstChild(`World{boss.World}`)
		local glow = area and area:FindFirstChild("GateGlow")
		local sign = glow and glow:FindFirstChild("Sign")
		local sub = sign and sign:FindFirstChild("Sub")
		if sub and sub:IsA("TextLabel") then
			if Bosses.IsUnlocked(cleared, boss.Id, "Normal") then
				local done = 0
				for _, difficulty in Bosses.DifficultyOrder do
					if cleared[Bosses.FightKey(boss.Id, difficulty)] then
						done += 1
					end
				end
				sub.Text = `{boss.Name} · {done}/{#Bosses.DifficultyOrder} cleared`
				sub.TextColor3 = boss.Accent
			else
				sub.Text = `LOCKED · {Bosses.UnlockHint(boss.Id, "Normal")}`
				sub.TextColor3 = Color3.fromRGB(170, 166, 190)
			end
		end
	end
	local gate = hub:FindFirstChild("TowerGate")
	local anchor = gate and gate:FindFirstChild("SignAnchor")
	local sign = anchor and anchor:FindFirstChild("Sign")
	local sub = sign and sign:FindFirstChild("Sub")
	if sub and sub:IsA("TextLabel") and State.Tower.Best > 0 then
		sub.Text = `Best run: floor {State.Tower.Best} · this run: floor {State.Tower.Run + 1}`
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

-- Portal and gate signs (tagged FadeSign by World) fade in as you walk up: solid within FADE_NEAR studs,
-- gone at the BillboardGui's MaxDistance. Each label's 1 px shadow keeps its text in step.
local FADE_NEAR = 28

local function fadeSigns()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	for _, gui in CollectionService:GetTagged("FadeSign") do
		if not gui:IsA("BillboardGui") then
			continue
		end
		local anchor = gui.Adornee or gui.Parent
		local position = if anchor and anchor:IsA("BasePart")
			then anchor.Position
			elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition
			else nil
		if position == nil then
			continue
		end
		-- A sign fades over the last 40% of its range (or from FADE_NEAR, whichever is nearer).
		local far = math.max(gui.MaxDistance, 2)
		local near = math.min(FADE_NEAR, far * 0.6)
		local fade = math.clamp(((position - eye).Magnitude - near) / (far - near), 0, 1)
		for _, label in gui:GetChildren() do
			if label:IsA("TextLabel") then
				label.TextTransparency = fade
				local shadow = label:FindFirstChild("Shadow")
				if shadow and shadow:IsA("TextLabel") then
					shadow.Text = label.Text
					shadow.TextTransparency = 0.45 + 0.55 * fade
				end
			end
		end
	end
end

function HubFx.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			fadeSigns()
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
