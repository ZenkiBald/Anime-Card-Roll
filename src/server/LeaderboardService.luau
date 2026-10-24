--!strict
-- Leaderboards. Rolls, Level and Tower floor show in the player list (leaderstats); three boards stand
-- in town at the map's Leaderboards marker: most rolls, rarest card owned (fusions count) and the fastest
-- Nightmare clear of the last boss in Bosses.luau. A fourth, the highest Infinite Tower floor, stands
-- beside the tower gate (World.luau's BoardSpot). Scores go to OrderedDataStores once a minute,
-- then each board redraws its top 8. Without DataStore access (Studio with API access off) the
-- boards just say there are no scores yet.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bosses = require(Shared.Bosses)
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)

local Deck = require(Shared.Deck)
local Borders = require(Shared.Borders)

local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)

local LeaderboardService = {}

local REFRESH_SECONDS = 60
local ROWS = 8
local STORE_SUFFIX = if Config.TestMode then "_Test_1" else "_1" -- test scores stay off the live boards

type Board = {
	Id: string,
	Title: string,
	Sub: string,
	Color: Color3,
	Ascending: boolean, -- true when lower is better (times)
	At: string?, -- stands at this part in workspace.Hub instead of in the row at the Leaderboards marker
	Score: (data: any) -> number?, -- the save's score, nil when it has none
	Show: (value: number) -> (string, Color3?),
}

local function commas(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if s:sub(1, 1) == "," then s:sub(2) else s
end

local cardIndex = {} -- [cardId] = position in Cards.List, packed into the rarest-card score
for i, card in Cards.List do
	cardIndex[card.Id] = i
end

local lastBoss = Bosses.List[#Bosses.List]
local fastestKey = Bosses.FightKey(lastBoss.Id, "Nightmare")

local BOARDS: { Board } = {
	{
		Id = "Rolls",
		Title = "MOST ROLLS",
		Sub = "All-time rolls",
		Color = Color3.fromRGB(255, 196, 46),
		Ascending = false,
		Score = function(data)
			return data.TotalRolls
		end,
		Show = function(value)
			return commas(value), nil
		end,
	},
	{
		Id = "Rarest",
		Title = "RAREST CARD",
		Sub = "Best border, then the rarest pull",
		Color = Color3.fromRGB(220, 90, 255),
		Ascending = false,
		-- The rarest card (Deck.Rarest: best border, then least likely): border index x 1000 + the
		-- card's list position, so the board can show which card it is.
		Score = function(data)
			local id, border = Deck.Rarest(data.Cards)
			if id == nil then
				return nil
			end
			return Borders.Index(border) * 1000 + (cardIndex[id] or 0)
		end,
		Show = function(value)
			local border = Borders.Order[value // 1000]
			local card = Cards.List[value % 1000]
			if border == nil or card == nil then
				return "?", nil
			end
			return `{Borders.Get(border).Name} · {card.Name}`, Borders.Get(border).Color
		end,
	},
	{
		Id = `Fastest_{lastBoss.Id}`,
		Title = "FASTEST CLEAR",
		Sub = `{lastBoss.Name} · Nightmare`,
		Color = lastBoss.Accent,
		Ascending = true,
		Score = function(data)
			local time = data.Progress.BestTime[fastestKey]
			return if time then math.floor(time * 10 + 0.5) else nil
		end,
		Show = function(value)
			local seconds = value / 10
			return string.format("%d:%04.1f", seconds // 60, seconds % 60), nil
		end,
	},
	{
		Id = "TowerFloor",
		Title = "HIGHEST FLOOR",
		Sub = "Infinite Tower · best run",
		Color = Color3.fromRGB(90, 230, 220),
		Ascending = false,
		At = "BoardSpot",
		Score = function(data)
			return if data.Tower.Floor > 0 then data.Tower.Floor else nil
		end,
		Show = function(value)
			return `Floor {commas(value)}`, nil
		end,
	},
}

-- Player list ----------------------------------------------------------------------------------
-- Besides leaderstats, every player carries attributes for the in-game server list (UI/PlayerList):
-- Fav / FavFusion / FavBorder (their favourite card, else their rarest), Power (active Deck Power),
-- Rolls and Level.

local function addStats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Rolls", "Level", "Floor" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

local function updateStats()
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		local folder = player:FindFirstChild("leaderstats")
		if profile and folder then
			(folder :: any).Rolls.Value = profile.Data.TotalRolls;
			(folder :: any).Level.Value = profile.Data.Level;
			(folder :: any).Floor.Value = profile.Data.Tower.Floor
			local data = profile.Data
			local fav = data.Settings.Favorite
			if fav == nil or fav == "" or data.Cards[fav] == nil then
				-- No favourite yet: the rarest card owned.
				fav = Deck.Rarest(data.Cards) or ""
			end
			local entry = data.Cards[fav]
			player:SetAttribute("Fav", fav)
			player:SetAttribute("FavFusion", entry and entry.Fusion or 0)
			player:SetAttribute("FavBorder", entry and Borders.Best(entry.Borders) or "Normal")
			player:SetAttribute("Power", Deck.Power(DeckService.Active(data), data.Cards))
			player:SetAttribute("Rolls", data.TotalRolls)
			player:SetAttribute("Level", data.Level)
		end
	end
end

-- Boards in town ---------------------------------------------------------------------------------

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(210, 220, 235), Color3.fromRGB(230, 150, 90) }

-- One board: a dark panel on a stone plinth with a glowing top trim; returns its row labels.
local function buildBoard(parent: Instance, frame: CFrame, board: Board)
	local panel = part({
		Name = board.Id,
		Size = Vector3.new(10, 11, 0.6),
		CFrame = frame * CFrame.new(0, 7.5, 0),
		Color = Color3.fromRGB(34, 24, 56),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	part({
		Name = "Trim",
		Size = Vector3.new(10.4, 0.4, 0.8),
		CFrame = frame * CFrame.new(0, 13.2, 0),
		Color = board.Color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	part({
		Name = "Plinth",
		Size = Vector3.new(10.6, 2, 1.6),
		CFrame = frame * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(96, 90, 110),
		Material = Enum.Material.Cobblestone,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = panel
	local title = label(gui, {
		Text = board.Title,
		Font = Enum.Font.GothamBlack,
		TextColor3 = board.Color,
		Position = UDim2.fromScale(0.05, 0.025),
		Size = UDim2.fromScale(0.9, 0.1),
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(16, 8, 30)
	stroke.Parent = title
	label(gui, {
		Text = board.Sub,
		TextColor3 = Color3.fromRGB(200, 190, 235),
		Position = UDim2.fromScale(0.1, 0.125),
		Size = UDim2.fromScale(0.8, 0.055),
	})
	local rows = {}
	for i = 1, ROWS do
		local y = 0.2 + (i - 1) * 0.097
		-- Alternate row strips so names line up with their scores.
		local strip = Instance.new("Frame")
		strip.Position = UDim2.fromScale(0.03, y - 0.008)
		strip.Size = UDim2.fromScale(0.94, 0.09)
		strip.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(60, 44, 100) else Color3.fromRGB(46, 34, 78)
		strip.BorderSizePixel = 0
		strip.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = strip
		local rank = label(gui, {
			Text = `{i}`,
			Font = Enum.Font.GothamBlack,
			TextColor3 = MEDALS[i] or Color3.fromRGB(190, 180, 220),
			Position = UDim2.fromScale(0.05, y),
			Size = UDim2.fromScale(0.08, 0.075),
		})
		local name = label(gui, {
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.14, y),
			Size = UDim2.fromScale(0.42, 0.076),
		})
		local value = label(gui, {
			Text = "",
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.54, y),
			Size = UDim2.fromScale(0.41, 0.076),
		})
		rows[i] = { Rank = rank, Name = name, Value = value }
	end
	local empty = label(gui, {
		Text = "No scores yet: be the first!",
		TextColor3 = Color3.fromRGB(190, 180, 220),
		Position = UDim2.fromScale(0.1, 0.45),
		Size = UDim2.fromScale(0.8, 0.07),
		Visible = false,
	})
	return { Rows = rows, Empty = empty }
end

local names = {} -- [userId] = display name, cached

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.DisplayName else nil
	if name == nil and userId > 0 then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok then result else nil
	end
	name = name or `Player {math.abs(userId)}`
	names[userId] = name
	return name
end

local function refreshBoard(board: Board, store: OrderedDataStore, view)
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		local score = profile and board.Score(profile.Data)
		if score then
			pcall(function()
				store:SetAsync(tostring(player.UserId), score)
			end)
		end
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(board.Ascending, ROWS):GetCurrentPage()
	end)
	local entries = if ok then page else {}
	for i, row in view.Rows do
		local entry = entries[i]
		row.Rank.Visible = entry ~= nil
		if entry then
			local text, color = board.Show(entry.value)
			row.Name.Text = nameFor(tonumber(entry.key) or 0)
			row.Value.Text = text
			row.Value.TextColor3 = color or Color3.new(1, 1, 1)
		else
			row.Name.Text = ""
			row.Value.Text = ""
		end
	end
	view.Empty.Visible = #entries == 0
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(addStats)
	for _, player in Players:GetPlayers() do
		addStats(player)
	end
	task.spawn(function()
		while true do
			updateStats()
			task.wait(2)
		end
	end)

	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	local marker = markers and markers:FindFirstChild("Leaderboards")
	local hub = workspace:FindFirstChild("Hub")
	local row = {}
	for _, board in BOARDS do
		if board.At == nil then
			table.insert(row, board)
		end
	end
	local views = {} -- [Board] = its rows
	if marker and marker:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = "Leaderboards"
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for i, board in row do
			-- Side by side, first board on the left as you face them (the marker's right is the viewer's left).
			local offset = ((#row + 1) / 2 - i) * 11
			views[board] = buildBoard(model, marker.CFrame * CFrame.new(offset, 0, 0), board)
		end
		model.Parent = hub or workspace
	else
		warn("[Leaderboards] Map has no Leaderboards marker: no boards in town")
	end
	for _, board in BOARDS do
		local spot = board.At and hub and hub:FindFirstChild(board.At, true)
		if spot and spot:IsA("BasePart") then
			local model = Instance.new("Model")
			model.Name = `Board_{board.Id}`
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			views[board] = buildBoard(model, spot.CFrame, board)
			model.Parent = hub
		end
	end

	task.spawn(function()
		task.wait(5) -- let the first saves load
		while true do
			for _, board in BOARDS do
				local view = views[board]
				if view then
					local store = DataStoreService:GetOrderedDataStore(`LB_{board.Id}{STORE_SUFFIX}`)
					refreshBoard(board, store, view)
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
