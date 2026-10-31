--!nonstrict
-- PROFILE: tap anyone in the server list (or yourself) to see them: their favourite card big on the
-- left; name, level and stat tiles (Deck Power, rolls, tower floor, bosses cleared, Index, playtime);
-- their strongest cards and the deck they fight with. The server answers for players in this server
-- (ProfileService); on your own profile CHANGE FAVOURITE opens the Index.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardView = require(script.Parent.CardView)
local CardTile = require(script.Parent.CardTile)

local Profile = {}

local modal
local left: Frame
local right: ScrollingFrame
local openIndex: (() -> ())? = nil
local token = 0

local function short(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return Kit.commas(n)
end

local function playtime(seconds: number): string
	local hours = seconds // 3600
	return if hours > 0 then `{hours}h {(seconds % 3600) // 60}m` else `{seconds // 60}m`
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function line(order: number, text: string, color: Color3, size: number, font: Enum.Font?): TextLabel
	local label = Kit.label({
		LayoutOrder = order,
		Text = text,
		RichText = true,
		Font = font or Theme.Font.Heavy,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 6),
		Parent = right,
	}, size)
	return label
end

-- A row of small card tiles (strongest cards, the deck); `false` entries are empty deck slots.
local function cardRow(order: number, cards, cellWidth: number)
	local row = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, math.floor(cellWidth / 0.8)),
		BackgroundTransparency = 1,
		Parent = right,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	for i, info in cards do
		if info then
			local tile = CardTile.new(info.Id, { Owned = true, Stars = info.Stars, Border = info.Border })
			tile.LayoutOrder = i
			tile.Size = UDim2.new(0, cellWidth, 1, 0)
			tile.Parent = row
		else
			Kit.new("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(0, cellWidth, 1, 0),
				BackgroundColor3 = Theme.Color.PanelLight,
				BackgroundTransparency = 0.5,
				Parent = row,
			}, { Kit.corner(UDim.new(0.12, 0)) })
		end
	end
	return row
end

local function draw(data, isMe: boolean)
	clear(left)
	clear(right)
	-- Favourite card, big and alive.
	if data.Favorite then
		local view = CardView.new(data.Favorite.Id, {
			Owned = true,
			Stars = data.Favorite.Stars,
			Border = data.Favorite.Border,
			Trait = data.Favorite.Trait,
			StatMultiplier = data.Favorite.StatMultiplier,
			Animate = true,
		})
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.fromScale(0.5, 0)
		view.Size = UDim2.new(1, 0, 1, if isMe then -54 else 0)
		view.Parent = left
	end
	if isMe and openIndex then
		local change = Kit.button("CHANGE FAVOURITE", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(0.9, 0, 0, 46),
			Parent = left,
		})
		change.Activated:Connect(function()
			modal:Close()
			openIndex()
		end)
	end

	local name = line(1, data.DisplayName, Theme.Color.Text, 34, Theme.Font.Display)
	Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = name
	local title = if (data.Title or "") ~= "" then `   ·   <font color="#50E6C8">« {data.Title} »</font>` else ""
	line(2, `@{data.Name}   ·   <font color="#FFC42E">Level {data.Level}</font>{title}`, Theme.Color.Muted, 18)

	-- Stat tiles, three to a row.
	local stats = Kit.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = right,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 66),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tiles = {
		{ "DECK POWER", short(data.Power), Color3.fromRGB(255, 110, 90) },
		{ "ROLLS", short(data.Rolls), Theme.Color.Gold },
		{ "TOWER FLOOR", if data.Floor > 0 then tostring(data.Floor) else "-", Color3.fromRGB(90, 230, 220) },
		{ "BOSSES", `{data.Cleared}/{data.Fights}`, Theme.Color.Roll },
		{ "INDEX", `{data.Found}/{data.Total}`, Theme.Color.Auto },
		{ "PLAYTIME", playtime(data.Playtime), Theme.Color.Quick },
	}
	for i, info in tiles do
		local tile = Kit.tile({ LayoutOrder = i, Parent = stats }, info[3])
		Kit.label({
			Text = info[1],
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			Position = UDim2.new(0, 8, 0, 6),
			Size = UDim2.new(1, -16, 0, 16),
			Parent = tile,
		}, 14)
		local value = Kit.label({
			Text = info[2],
			Font = Theme.Font.Display,
			TextColor3 = info[3],
			Position = UDim2.new(0, 8, 0, 24),
			Size = UDim2.new(1, -16, 0, 34),
			Parent = tile,
		}, 30)
		Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.1).Parent = value
	end

	if #data.Top > 0 then
		line(4, "STRONGEST CARDS", Theme.Color.Gold, 18, Theme.Font.Display)
		cardRow(5, data.Top, 78)
	end
	if data.Deck and #data.Deck > 0 then
		line(6, "DECK · 4 ATTACK + 4 SUPPORT", Theme.Color.Support, 18, Theme.Font.Display)
		cardRow(7, data.Deck, 62)
	end
end

-- Opens the profile of `player` (asks the server; shows a loading line meanwhile).
function Profile.Open(player: Player)
	token += 1
	local mine = token
	clear(left)
	clear(right)
	line(1, `Loading {player.DisplayName}...`, Theme.Color.Muted, 20)
	modal.TitleLabel.Text = if player == Players.LocalPlayer then "MY PROFILE" else "PROFILE"
	modal:Open()
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Profile:InvokeServer(player.UserId)
		end)
		if mine ~= token or not modal.IsOpen then
			return
		end
		if ok and data and data.Ok then
			draw(data, player == Players.LocalPlayer)
		else
			clear(right)
			line(1, "Couldn't load that profile (they may have left).", Theme.Color.Danger, 18)
		end
	end)
end

function Profile.Init(playerGui: Instance, openIndexFn: (() -> ())?)
	openIndex = openIndexFn
	modal = Modal.new(playerGui, "ProfileGui", "PROFILE", Vector2.new(0.8, 0.84), Vector2.new(940, 620))
	left = Kit.new("Frame", {
		Name = "Favorite",
		Size = UDim2.fromScale(0.34, 1),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	right = Kit.new("ScrollingFrame", {
		Name = "Info",
		Position = UDim2.fromScale(0.37, 0),
		Size = UDim2.fromScale(0.63, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})
end

return Profile
