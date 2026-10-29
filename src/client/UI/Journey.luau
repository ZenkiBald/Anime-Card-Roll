--!nonstrict
-- The existing game's goals and earned rewards, with live progress and routes to their screens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Goals = require(ReplicatedStorage:WaitForChild("Shared").Goals)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local HudArt = require(script.Parent.HudArt)
local BagArt = require(script.Parent.BagArt)
local State = require(script.Parent.Parent.State)
local Journey = {}

function Journey.Init(host, navigate)
	local page = host:Page("GOALS")
	local list = Kit.new("ScrollingFrame", { Name = "Goals", Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page.Body }, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,12) }),
		Kit.padding(5),
	})
	local refs = {}
	local function refresh()
		if not page.IsOpen then return end
		local preset = State.Decks.Presets[State.Decks.Active] or {}
		local rows = Goals.Journey({ Cleared = State.Progress.Cleared, Tower = State.Tower,
			Cards = State.Cards, Attack = preset.Attack })
		for i, goal in rows do
			local ref = refs[i]
			if not ref then
				local tile = Kit.tile({ Name = "Goal" .. i, LayoutOrder = i, Size = UDim2.new(1,-10,0,176), Parent = list })
				local art = Kit.new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
					Position = UDim2.fromOffset(12,18), Size = UDim2.fromOffset(88,110), Parent = tile })
				local function label(name, y, height, fontSize)
					return Kit.label({ Name = name, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true, Position = UDim2.new(0,112,0,y), Size = UDim2.new(1,-126,0,height),
						Font = if name == "Title" then Theme.Font.Display else Theme.Font.Bold, Parent = tile },fontSize)
				end
				local title = label("Title",10,28,22)
				local text = label("Objective",42,38,17)
				local reward = label("Reward",82,44,15)
				reward.TextColor3 = Theme.Color.Gold
				local count = Kit.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.new(0,14,1,-42), Size = UDim2.new(0.6,-24,0,20), Parent = tile },16)
				local track = Kit.new("Frame", { BackgroundColor3 = Theme.Color.Backdrop,
					Position = UDim2.new(0,14,1,-17), Size = UDim2.new(0.65,-24,0,7), Parent = tile }, { Kit.corner() })
				local fill = Kit.new("Frame", { BackgroundColor3 = Theme.Color.Quick, Size = UDim2.fromScale(0,1), Parent = track }, { Kit.corner() })
				local button = Kit.button("OPEN", Theme.Color.Quick, Color3.fromRGB(20,110,110), {
					AnchorPoint = Vector2.new(1,1), Position = UDim2.new(1,-12,1,-10),
					Size = UDim2.new(0.31,0,0,32), Parent = tile })
				ref = { Art = art, Title = title, Text = text, Reward = reward, Count = count, Fill = fill, Button = button }
				button.Activated:Connect(function() navigate(ref.Goal) end)
				refs[i] = ref
			end
			ref.Goal = goal
			ref.Art.Image = goal.Image or BagArt.Get(goal.ArtKey) or HudArt.Get(goal.ArtKey) or ""
			ref.Title.Text, ref.Text.Text, ref.Reward.Text = goal.Title, goal.Text, goal.Reward
			ref.Count.Text = goal.Count
			ref.Fill.Size = UDim2.fromScale(goal.Progress,1)
			ref.Button.Label.Text = if goal.Action == "Squad" then "OPEN SQUAD" else "OPEN BATTLE"
		end
	end
	page.OnOpen = refresh
	State.Changed:Connect(function(kind) if kind ~= "roll" then refresh() end end)
end

return Journey
