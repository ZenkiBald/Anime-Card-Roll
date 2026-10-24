--!strict
-- Name tags over every player's head: their name, level and their rarest card (fusions
-- count) in that rarity's colour, on a dark pill. Replaces Roblox's own name display. Refreshed every
-- few seconds from the save, so a new pull or level shows up for everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Deck = require(Shared.Deck)

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
		Font = Enum.Font.GothamBlack,
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
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0.05, 0.12),
		Size = UDim2.fromScale(0.9, 0.76),
	})
	gui.Parent = root
	return gui
end

-- The rarest card (best border, then least likely) and its border.
local function rarest(data): (string?, string?)
	local id, border = Deck.Rarest(data.Cards)
	local card = id and Cards.Get(id)
	return if card then card.Name else nil, if card then border else nil
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
	-- Sit just above the top of the avatar, hats and tall accessories included (the head alone left the
	-- tag behind big hats).
	local box, size = (character :: Model):GetBoundingBox()
	local top = box.Position.Y + size.Y / 2 - (root :: BasePart).Position.Y
	gui.StudsOffsetWorldSpace = Vector3.new(0, math.clamp(top, 2, 12) + 1.4, 0)
	local data = profile.Data
	local card, rarity = rarest(data)
	-- A favourite card, when the player has picked one, stands in for the rarest.
	local favorite = Cards.Get(data.Settings.Favorite or "")
	if favorite and data.Cards[favorite.Id] then
		card, rarity = favorite.Name, Borders.Best(data.Cards[favorite.Id].Borders)
	end
	local parts = { `<font color="#FFC42E">Lv {data.Level}</font>` }
	if (data.Settings.Title or "") ~= "" then
		table.insert(parts, `<font color="#50E6C8">« {data.Settings.Title} »</font>`)
	end
	if card and rarity then
		table.insert(parts, `<font color="#{Borders.Get(rarity).Color:ToHex()}">{string.upper(Borders.Get(rarity).Name)}</font> {card}`)
	else
		table.insert(parts, "New roller")
	end
	-- VIP (MonetizationService sets the attribute): a golden name with a crown.
	local vip = player:GetAttribute("VIP") == true
	gui.PlayerName.Text = if vip then `👑 {player.DisplayName}` else player.DisplayName
	gui.PlayerName.TextColor3 = if vip then Color3.fromRGB(255, 205, 60) else Color3.new(1, 1, 1)
	gui.Pill.Info.Text = table.concat(parts, "  ·  ")
	gui.Pill.Edge.Color = if rarity then Borders.Get(rarity).Color else Color3.fromRGB(150, 110, 255)
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
