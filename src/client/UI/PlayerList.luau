--!nonstrict
-- The server list, top right (replaces Roblox's player list): everyone in the server, strongest deck
-- first, each with their favourite card as their picture (favourite one in the INDEX; until then it's
-- their rarest card), their Deck Power and total rolls. The ">" button folds it to just the header.
-- Tap a row (yourself too) to open that player's PROFILE.
-- The numbers come from player attributes the server sets every 2 s (LeaderboardService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Rarity = require(Shared.Rarity)
local Borders = require(Shared.Borders)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local CardView = require(script.Parent.CardView)

local PlayerList = {}

local ROW_HEIGHT = 58
local MAX_ROWS = 5

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local countLabel: TextLabel
local foldButton: TextButton
local rows = {} -- [Player] = { Frame, Portrait, Fav, Name, Power, Rolls }
local folded = false
local hiddenBy = {}
local onPick: ((Player) -> ())? = nil

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

-- The row's picture: the favourite card's art in a rarity-coloured frame.
local function setPortrait(row, cardId: string, fusion: number, border: string)
	local key = `{cardId}:{fusion}:{border}`
	if row.Fav == key then
		return
	end
	row.Fav = key
	for _, child in row.Portrait:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local card = Cards.Get(cardId)
	if card == nil then
		row.Portrait.BackgroundColor3 = Theme.Color.PanelLight
		row.Stroke.Color = Theme.Color.TileEdge
		return
	end
	local rarity = Cards.FusedRarity(card, fusion)
	row.Portrait.BackgroundColor3 = card.Accent
	row.Stroke.Color = if border ~= "Normal" and Borders.Get(border) then Borders.Get(border).Color else Rarity.Get(rarity).Color
	local art = CardView.Art(cardId, true, false)
	if art then
		art.Size = if card.Image then UDim2.fromScale(1, 1) else UDim2.fromScale(1.35, 1.35)
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = if card.Image then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.62)
		art.Parent = row.Portrait
	else
		Kit.label({ Text = card.Glyph, Font = Theme.Font.Display, Size = UDim2.fromScale(1, 1), Parent = row.Portrait }, 24)
	end
end

local function makeRow(player: Player)
	local me = player == Players.LocalPlayer
	local frame = Kit.new("TextButton", {
		Name = player.Name,
		Size = UDim2.new(1, -6, 0, ROW_HEIGHT - 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Parent = list,
	}, {
		Kit.corner(UDim.new(0, 12)),
		Kit.gradient(
			ColorSequence.new(
				if me then Color3.fromRGB(90, 60, 170) else Color3.fromRGB(52, 36, 104),
				if me then Color3.fromRGB(40, 24, 90) else Color3.fromRGB(22, 14, 50)
			),
			0
		),
		Kit.stroke(if me then Theme.Color.Gold else Theme.Color.TileEdge, if me then 2 else 1, if me then 0.2 else 0.5),
	})
	local portrait = Kit.new("Frame", {
		Name = "Portrait",
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.new(0, ROW_HEIGHT - 14, 0, ROW_HEIGHT - 14),
		BackgroundColor3 = Theme.Color.PanelLight,
		ClipsDescendants = true,
		Parent = frame,
	}, { Kit.corner(UDim.new(0, 10)) })
	local stroke = Kit.stroke(Theme.Color.TileEdge, 2, 0)
	stroke.Parent = portrait
	local name = Kit.label({
		Name = "PlayerName",
		Text = player.DisplayName,
		Font = Theme.Font.Display,
		TextColor3 = if me then Theme.Color.Gold else Color3.fromRGB(120, 255, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, ROW_HEIGHT - 2, 0, 3),
		Size = UDim2.new(1, -ROW_HEIGHT, 0.38, 0),
		Parent = frame,
	}, 18)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = name
	local power = Kit.label({
		Name = "Power",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(255, 110, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, ROW_HEIGHT - 2, 0.4, 0),
		Size = UDim2.new(1, -ROW_HEIGHT, 0.28, 0),
		Parent = frame,
	}, 14)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.3).Parent = power
	local rolls = Kit.label({
		Name = "Rolls",
		Text = "",
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, ROW_HEIGHT - 2, 0.68, 0),
		Size = UDim2.new(1, -ROW_HEIGHT, 0.26, 0),
		Parent = frame,
	}, 13)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.3).Parent = rolls
	Kit.pressable(frame)
	frame.Activated:Connect(function()
		if onPick then
			onPick(player)
		end
	end)
	local row = { Frame = frame, Portrait = portrait, Stroke = stroke, Fav = nil, Power = power, Rolls = rolls }
	rows[player] = row
	return row
end

function PlayerList.Refresh()
	if panel == nil then
		return
	end
	local players = Players:GetPlayers()
	for player, row in rows do
		if player.Parent ~= Players then
			row.Frame:Destroy()
			rows[player] = nil
		end
	end
	table.sort(players, function(a, b)
		local pa, pb = a:GetAttribute("Power") or 0, b:GetAttribute("Power") or 0
		if pa ~= pb then
			return pa > pb
		end
		return a.UserId < b.UserId
	end)
	for i, player in players do
		local row = rows[player] or makeRow(player)
		row.Frame.LayoutOrder = i
		local fav = player:GetAttribute("Fav")
		setPortrait(row, if type(fav) == "string" then fav else "", player:GetAttribute("FavFusion") or 0, player:GetAttribute("FavBorder") or "Normal")
		row.Power.Text = `{short(player:GetAttribute("Power") or 0)} Deck Power`
		row.Rolls.Text = `{short(player:GetAttribute("Rolls") or 0)} Rolls  ·  Lv {player:GetAttribute("Level") or 1}`
	end
	countLabel.Text = `SERVER · {#players}`
	local shown = math.min(#players, MAX_ROWS)
	list.Visible = not folded
	panel.Size = UDim2.new(0, panel.Size.X.Offset, 0, 32 + (if folded then 0 else shown * ROW_HEIGHT + 4))
	local fold: any = foldButton
	fold.Label.Text = if folded then "‹" else "›"
end

local function applyHidden()
	local hidden = false
	for _, on in hiddenBy do
		hidden = hidden or on
	end
	gui.Enabled = not hidden
end

-- Hides the list for a reason (Battle, Reveal, Title); it shows again when no reason is left.
function PlayerList.SetHidden(reason: string, on: boolean)
	hiddenBy[reason] = on or nil
	if gui then
		applyHidden()
	end
end

function PlayerList.Init(playerGui: Instance, pick: ((Player) -> ())?)
	onPick = pick
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- this list replaces it
	end)
	gui = Kit.screenGui("PlayerListGui", 5, playerGui)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	panel = Kit.new("Frame", {
		Name = "ServerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -80, 0, 6),
		Size = UDim2.fromOffset(250, 32),
		BackgroundColor3 = Color3.fromRGB(20, 12, 44),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(0, 14)),
		Kit.stroke(Theme.Color.TileEdge, 1.5, 0.4),
		Kit.new("UIScale", { Name = "Fit", Scale = 1 }),
	})
	countLabel = Kit.label({
		Name = "Count",
		Text = "SERVER",
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -56, 0, 24),
		Parent = panel,
	}, 18)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = countLabel
	foldButton = Kit.button("›", Theme.Color.PanelLight, Theme.Color.Panel, {
		Name = "Fold",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 3),
		Size = UDim2.fromOffset(38, 26),
		Parent = panel,
	})
	foldButton.Activated:Connect(function()
		folded = not folded
		PlayerList.Refresh()
	end)
	list = Kit.new("ScrollingFrame", {
		Name = "Players",
		Position = UDim2.new(0, 6, 0, 32),
		Size = UDim2.new(1, -8, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	-- Small screens: shrink it, and start folded on phones so it doesn't cover the world.
	local function fit()
		local height = gui.AbsoluteSize.Y
		local fitted: any = panel
		fitted.Fit.Scale = math.clamp(height / 900, 0.6, 1)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	folded = gui.AbsoluteSize.Y < 500
	applyHidden()

	Players.PlayerAdded:Connect(PlayerList.Refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(PlayerList.Refresh)
	end)
	PlayerList.Refresh()
	task.spawn(function()
		while true do
			task.wait(2)
			PlayerList.Refresh()
		end
	end)
end

return PlayerList
