--!nonstrict
-- STATS: every level past 1 gives a stat point to put into Luck, Roll Speed, Border Chance, Shard Gain
-- or XP Gain (Meta.Stats). Each row shows what it gives now and what one more point adds; RESET takes
-- every point back for Shards. The server checks every point (MetaService "SpendStat" / "ResetStats").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meta"))

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local StatsPanel = {}

local modal
local pointsLabel: TextLabel
local hintLabel: TextLabel
local resetButton: any
local resetArmed = false
local armToken = 0
local rows = {} -- [statId] = refs
local hintToken = 0

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.2, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- "+0.40x base luck", "-12% roll cooldown", "+36% border chance" ...
local function effectText(stat, points: number): string
	local value = points * stat.Per
	if stat.Id == "Luck" then
		return string.format("+%.2fx base luck", value)
	elseif stat.Id == "RollSpeed" then
		local percent = math.floor(value * 100 + 0.5)
		return if percent == 0 then "0% roll cooldown" else string.format("-%d%% roll cooldown", percent)
	elseif stat.Id == "Border" then
		return string.format("+%d%% border chance", math.floor(value * 100 + 0.5))
	elseif stat.Id == "ShardGain" then
		return string.format("+%d%% Shards", math.floor(value * 100 + 0.5))
	end
	return string.format("+%d%% XP", math.floor(value * 100 + 0.5))
end

function StatsPanel.Refresh()
	if not modal or not modal.IsOpen then
		return
	end
	local stats = State.Meta.Stats or {}
	local free = State.Meta.StatPoints or 0
	pointsLabel.Text = `{free} POINT{if free == 1 then "" else "S"} TO SPEND`
	pointsLabel.TextColor3 = if free > 0 then Theme.Color.Gold else Theme.Color.Muted
	for _, stat in Meta.Stats do
		local refs = rows[stat.Id]
		local points = stats[stat.Id] or 0
		local maxed = points >= stat.Max
		refs.Count.Text = `{points} / {stat.Max}`
		refs.Effect.Text = if maxed then `{effectText(stat, points)}  (max)` else `{effectText(stat, points)}  →  {effectText(stat, points + 1)}`
		Kit.tween(refs.Fill, 0.25, { Size = UDim2.fromScale(math.max(0.02, points / stat.Max), 1) })
		refs.Add.Label.Text = if maxed then "MAX" else "+1"
		Kit.dim(refs.Add, maxed or free <= 0)
	end
	local cost = Meta.StatResetCost(stats)
	resetButton.Label.Text = if cost == 0 then "RESET" elseif resetArmed then "TAP AGAIN" else `RESET  💎{Kit.commas(cost)}`
	Kit.dim(resetButton, cost == 0)
end

local function statRow(parent: Instance, stat, order: number)
	local row = Kit.tile({ Name = stat.Id, LayoutOrder = order, Size = UDim2.new(1, -6, 0, 86), Parent = parent }, stat.Color)
	local bubble = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.gradient(ColorSequence.new(stat.Color:Lerp(Color3.new(1, 1, 1), 0.25), stat.Color:Lerp(Color3.new(0, 0, 0), 0.35)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2.5, 0.2),
	})
	Kit.label({
		Text = stat.Icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Parent = bubble,
	}, 40)
	local name = Kit.label({
		Text = string.upper(stat.Name),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 88, 0, 8),
		Size = UDim2.new(0.45, 0, 0, 28),
		Parent = row,
	}, 28)
	Kit.textStroke(Color3.fromRGB(20, 8, 44), 2, 0).Parent = name
	local count = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = stat.Color,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -140, 0, 8),
		Size = UDim2.new(0.2, 0, 0, 28),
		Parent = row,
	}, 26)
	Kit.textStroke(Color3.fromRGB(20, 8, 44), 2, 0).Parent = count
	local effect = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 88, 0, 38),
		Size = UDim2.new(1, -236, 0, 20),
		Parent = row,
	}, 18)
	local track = Kit.new("Frame", {
		Position = UDim2.new(0, 88, 0, 64),
		Size = UDim2.new(1, -236, 0, 12),
		BackgroundColor3 = Color3.fromRGB(14, 8, 30),
		Parent = row,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(stat.Color, 1.5, 0.5) })
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(0.02, 1),
		BackgroundColor3 = stat.Color,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	local add = Kit.button("+1", stat.Color, stat.Color:Lerp(Color3.new(0, 0, 0), 0.45), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(112, 56),
		Parent = row,
	})
	add.Activated:Connect(function()
		local result = MetaClient.Call("SpendStat", stat.Id)
		if result.Ok then
			Sfx.Play("Upgrade", 1.15)
			Effects.Sparks(row, stat.Color, 14, 0.7)
			local scale = row:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = row })
			scale.Scale = 1.04
			Kit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			hint(MetaClient.Message(result))
		end
		StatsPanel.Refresh()
	end)
	rows[stat.Id] = { Count = count, Effect = effect, Fill = fill, Add = add }
end

function StatsPanel.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "StatsGui", "STATS", Vector2.new(0.7, 0.84), Vector2.new(780, 620))

	pointsLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.6, 0, 0, 36),
		Parent = modal.Body,
	}, 32)
	Kit.textStroke(Color3.fromRGB(70, 30, 0), 2.5, 0).Parent = pointsLabel
	Kit.label({
		Text = "You get 1 point every level. Put them where you want: each stat has a cap.",
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(0.62, 0, 0, 18),
		Parent = modal.Body,
	}, 15)
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.new(0.45, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	Kit.textStroke(Color3.fromRGB(40, 14, 0), 1.5, 0).Parent = hintLabel

	resetButton = Kit.button("RESET", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(190, 48),
		Parent = modal.Body,
	})
	resetButton.Activated:Connect(function()
		local cost = Meta.StatResetCost(State.Meta.Stats)
		if cost == 0 then
			hint(MetaClient.Message({ Reason = "NothingToReset" }))
			return
		end
		if not resetArmed then
			resetArmed = true
			armToken += 1
			local token = armToken
			hint(`Takes every point back for 💎{Kit.commas(cost)}. Tap again!`)
			StatsPanel.Refresh()
			task.delay(3, function()
				if token == armToken then -- an older tap's timer mustn't disarm a newer one
					resetArmed = false
					StatsPanel.Refresh()
				end
			end)
			return
		end
		resetArmed = false
		local result = MetaClient.Call("ResetStats")
		if result.Ok then
			Sfx.Play("Whoosh", 0.8)
			hint("Points are back: spend them again")
		else
			hint(MetaClient.Message(result))
		end
		StatsPanel.Refresh()
	end)

	local list = Kit.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 66),
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3) }),
	})
	for i, stat in Meta.Stats do
		statRow(list, stat, i)
	end

	modal.OnOpen = StatsPanel.Refresh
	State.Changed:Connect(StatsPanel.Refresh)
end

function StatsPanel.Toggle()
	modal:Toggle()
end

return StatsPanel
