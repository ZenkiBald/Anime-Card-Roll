--!nonstrict
-- LUCKY WHEEL: eight prize tiles in a ring around a big SPIN button. A light races round the ring and
-- slows down onto the prize the server picked (MetaService "SpinWheel"); every prize's chance is
-- listed beside it. Free spins come from time played (Meta.Wheel.SpinEvery), banked up to MaxSpins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Wheel = {}

local modal
local tiles = {} -- [i] = tile frame
local spinButton
local spinsLabel: TextLabel
local nextLabel: TextLabel
local nextFill: Frame
local hintLabel: TextLabel
local spinning = false
local lit = 0

local function hint(text: string)
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.4, function()
		Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
	end)
end

local function light(index: number)
	for i, tile in tiles do
		local on = i == index
		tile.UIStroke.Color = if on then Color3.new(1, 1, 1) else Meta.Wheel.Prizes[i].Color
		tile.UIStroke.Thickness = if on then 5 else 2.5
		tile.Glow.Visible = on
	end
	lit = index
end

local function refresh()
	if not modal or not modal.IsOpen then
		return
	end
	local wheel = State.Meta.Wheel or { Spins = 0, Progress = 0 }
	local spins = wheel.Spins
	spinsLabel.Text = `{spins} / {Meta.Wheel.MaxSpins} SPINS`
	if not spinning then
		spinButton.Label.Text = if spins > 0 then "SPIN!" else "NO SPINS"
		Kit.dim(spinButton, spins <= 0)
	end
	if spins >= Meta.Wheel.MaxSpins then
		nextLabel.Text = "Spins full: use one!"
		nextFill.Size = UDim2.fromScale(1, 1)
	else
		-- Progress counts up between server updates.
		local progress = math.min(Meta.Wheel.SpinEvery, wheel.Progress + (os.clock() - State.MetaAt))
		local left = Meta.Wheel.SpinEvery - progress
		nextLabel.Text = string.format("Next free spin in %d:%02d", left // 60, math.floor(left % 60))
		nextFill.Size = UDim2.fromScale(progress / Meta.Wheel.SpinEvery, 1)
	end
end

local function spin()
	if spinning then
		return
	end
	if (State.Meta.Wheel and State.Meta.Wheel.Spins or 0) <= 0 then
		hint("Play a little longer for a free spin")
		return
	end
	spinning = true
	spinButton.Label.Text = "..."
	local ok, result = pcall(function()
		return Remotes.Meta:InvokeServer("SpinWheel")
	end)
	if not ok or result == nil or not result.Ok then
		spinning = false
		hint(if ok and result then MetaClient.Message(result) else "Spin failed, try again")
		refresh()
		return
	end
	local target = result.Reason :: number
	-- 3 laps, then on to the prize; each step a little slower than the last.
	local count = #tiles
	local steps = count * 3 + ((target - lit - 1) % count + 1)
	local index = lit
	for step = 1, steps do
		index = index % count + 1
		light(index)
		Sfx.Play("Click", 1 + step / steps * 0.6)
		local t = step / steps
		task.wait(0.035 + t * t * t * 0.35)
	end
	local prize = Meta.Wheel.Prizes[target]
	local tile = tiles[target]
	tile.Pop.Scale = 1.35
	Kit.tween(tile.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Effects.Sparks(tile, prize.Color, 24, 1.2)
	if prize.Label == "JACKPOT" then
		Effects.Flash(modal.Panel, Theme.Color.Gold, 0.8, 0.2)
		Sfx.Sting("Legendary")
	else
		Sfx.Play("Reward")
	end
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	if result.Granted and MetaClient.OnGranted then
		MetaClient.OnGranted(result.Granted)
	end
	hint(`You won {Meta.Describe(prize.Reward)}!`)
	spinning = false
	refresh()
end

function Wheel.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "WheelGui", "LUCKY WHEEL", Vector2.new(0.84, 0.82), Vector2.new(920, 600))
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.45, 0, 0, 20),
		Parent = modal.Header,
	}, 17)

	-- The ring.
	local ring = Kit.new("Frame", {
		Name = "Ring",
		Size = UDim2.fromScale(0.6, 1),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	local square = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = ring,
	}, { Kit.aspect(1, Enum.DominantAxis.Height) })
	-- Soft disc behind the tiles, with a turning ring of rays.
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.98, 0.98),
		BackgroundColor3 = Color3.fromRGB(30, 14, 66),
		BackgroundTransparency = 0.2,
		Parent = square,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.Color.Gold, 4, 0.1) })
	Effects.Rays(square, Color3.fromRGB(200, 150, 255), 8)
	for i, prize in Meta.Wheel.Prizes do
		local angle = math.rad((i - 1) * (360 / #Meta.Wheel.Prizes) - 90)
		local tile = Kit.tile({
			Name = `Prize{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.37, 0.5 + math.sin(angle) * 0.37),
			Size = UDim2.fromScale(0.22, 0.22),
			ZIndex = 3,
			Parent = square,
		}, prize.Color)
		Kit.new("UIScale", { Name = "Pop", Scale = 1, Parent = tile })
		Kit.new("Frame", {
			Name = "Glow",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = prize.Color,
			BackgroundTransparency = 0.45,
			Visible = false,
			ZIndex = 4,
			Parent = tile,
		}, { Kit.corner(UDim.new(0, 16)) })
		local label = Kit.label({
			Text = prize.Label,
			Font = Theme.Font.Display,
			TextColor3 = if prize.Label == "JACKPOT" then Theme.Color.Gold else Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.5),
			ZIndex = 6,
			Parent = tile,
		}, 30)
		Kit.textStroke(Color3.fromRGB(20, 8, 40), 2.5, 0).Parent = label
		tiles[i] = tile
	end
	spinButton = Kit.button("SPIN!", Theme.Color.Roll, Theme.Color.RollDeep, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.2),
		ZIndex = 8,
		Parent = square,
	})
	spinButton.Label.UITextSizeConstraint.MaxTextSize = 40
	spinButton.Activated:Connect(function()
		task.spawn(spin)
	end)

	-- Odds and the free-spin timer.
	local side = Kit.new("Frame", {
		Position = UDim2.fromScale(0.62, 0),
		Size = UDim2.fromScale(0.38, 1),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	}, { Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
	spinsLabel = Kit.label({
		LayoutOrder = 1,
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = side,
	}, 32)
	Kit.textStroke(Color3.fromRGB(70, 40, 0), 2.5, 0).Parent = spinsLabel
	local track = Kit.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Color3.fromRGB(14, 8, 30),
		Parent = side,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Theme.Color.Gold, 1.5, 0.4) })
	nextFill = Kit.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.Gold,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	nextLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = track,
	}, 15)
	Kit.textStroke(Color3.fromRGB(20, 8, 40), 1.5, 0).Parent = nextLabel
	Kit.label({
		LayoutOrder = 3,
		Text = `A free spin every {Meta.Wheel.SpinEvery // 60} minutes you play. Every prize and its chance:`,
		Font = Theme.Font.Bold,
		TextColor3 = Color3.fromRGB(214, 200, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = side,
	}, 15)
	local total = Meta.WheelTotalWeight()
	for i, prize in Meta.Wheel.Prizes do
		local row = Kit.tile({ LayoutOrder = 3 + i, Size = UDim2.new(1, 0, 0, 34), Parent = side }, prize.Color)
		Kit.label({
			Text = prize.Label,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0.15, 0),
			Size = UDim2.new(0.4, 0, 0.7, 0),
			Parent = row,
		}, 18)
		Kit.label({
			Text = if prize.Label == "JACKPOT" then Meta.Describe(prize.Reward) else "",
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Gold,
			Position = UDim2.new(0.34, 0, 0.2, 0),
			Size = UDim2.new(0.36, 0, 0.6, 0),
			Parent = row,
		}, 14)
		Kit.label({
			Text = string.format("%.0f%%", prize.Weight / total * 100),
			Font = Theme.Font.Display,
			TextColor3 = prize.Color:Lerp(Color3.new(1, 1, 1), 0.4),
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, -12, 0.15, 0),
			Size = UDim2.new(0.3, 0, 0.7, 0),
			Parent = row,
		}, 18)
	end
	light(1)
	modal.OnOpen = function()
		task.spawn(function()
			MetaClient.Call("Get")
			refresh()
		end)
		refresh()
	end
	State.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

function Wheel.Toggle()
	modal:Toggle()
end

-- Madame Fortuna's prompt in town opens the wheel.
function Wheel.Open()
	modal:Open()
end

return Wheel
