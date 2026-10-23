--!strict
-- Name tags over every player's head: their name, level and their rarest card (fusions
-- count) in that rarity's colour, on a dark pill. Replaces Roblox's own name display. Refreshed every
-- few seconds from the save, so a new pull or level shows up for everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Rarity = require(Shared.Rarity)

local DataService = require(script.Parent.DataService)

local NameTagService = {}

local REFRESH_SECONDS = 3

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(l :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(16, 8, 30)
	stroke.Thickness = 2
	stroke.Parent = l
	l.Parent = parent
	return l
end

-- The tag hangs on the HumanoidRootPart (the Head is swapped out while the avatar's look loads) and
-- refresh() keeps it just above the head.
local function build(character: Model, player: Player): BillboardGui?
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 58)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	label(gui, {
		Name = "PlayerName",
		Text = player.DisplayName,
		Font = Enum.Font.FredokaOne,
		Size = UDim2.fromScale(1, 0.5),
	})
	-- The pill with stars and the rarest card.
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.54)
	pill.Size = UDim2.fromScale(0.86, 0.42)
	pill.BackgroundColor3 = Color3.fromRGB(24, 14, 48)
	pill.BackgroundTransparency = 0.2
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Thickness = 1.5
	edge.Parent = pill
	label(pill, {
		Name = "Info",
		Text = "",
		RichText = true,
		Font = Enum.Font.BuilderSansExtraBold,
		Position = UDim2.fromScale(0.05, 0.12),
		Size = UDim2.fromScale(0.9, 0.76),
	})
	gui.Parent = root
	return gui
end

local function rarest(data): (string?, string?)
	local bestIndex, bestCard, bestRarity = 0, nil, nil
	for id, entry in data.Cards do
		local card = Cards.Get(id)
		if card then
			local rarity = Cards.FusedRarity(card, entry.Fusion)
			local index = Rarity.Index(rarity)
			if index > bestIndex then
				bestIndex, bestCard, bestRarity = index, card.Name, rarity
			end
		end
	end
	return bestCard, bestRarity
end

local function refresh(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tag = root and root:FindFirstChild("NameTag")
	local profile = DataService.Get(player)
	if tag == nil or not tag:IsA("BillboardGui") or profile == nil then
		return
	end
	local gui: any = tag
	-- Sit just above the top of the head, whatever the avatar's size.
	local head = (character :: Model):FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local top = head.Position.Y + head.Size.Y / 2 - (root :: BasePart).Position.Y
		gui.StudsOffsetWorldSpace = Vector3.new(0, top + 1.6, 0)
	end
	local data = profile.Data
	local card, rarity = rarest(data)
	local parts = { `<font color="#FFC42E">Lv {data.Level}</font>` }
	if card and rarity then
		table.insert(parts, `<font color="#{Rarity.Get(rarity).Color:ToHex()}">{string.upper(rarity)}</font> {card}`)
	else
		table.insert(parts, "New roller")
	end
	gui.PlayerName.Text = player.DisplayName
	gui.Pill.Info.Text = table.concat(parts, "  ·  ")
	gui.Pill.Edge.Color = if rarity then Rarity.Get(rarity).Color else Color3.fromRGB(150, 110, 255)
end

function NameTagService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			if build(character, player) then
				refresh(player)
			end
		end)
		if player.Character then
			task.spawn(function()
				if build(player.Character :: Model, player) then
					refresh(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return NameTagService
