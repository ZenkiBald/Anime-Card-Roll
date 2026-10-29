--!nonstrict
-- Gifts: today's 3 daily quests, the 7-day login streak, free gifts for time played this session,
-- and lifetime roll milestones. The server checks every claim (MetaService).
-- Chunky kit tiles with the uploaded icons; claimed (and still-locked playtime) tiles sit under a
-- dark cover so only what's ready stands out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local RewardLine = require(script.Parent.RewardLine)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Gifts = {}

local modal
local list: ScrollingFrame
local hintLabel: TextLabel
local hintToken = 0
local claimAllButton
local claimingAll=false
local built = false
local dailyTiles = {}
local giftTiles = {}
local milestoneRows = {}
local questBox: Frame
local questReset: TextLabel
local questRows = {} -- [questId] = refs
local questDayShown = nil

local GOLD_DEEP = Color3.fromRGB(170, 110, 0)
local CAPTION = Color3.fromRGB(207, 219, 241)
local CLAIMED_GREEN = Color3.fromRGB(120, 240, 160)

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

local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function heading(text: string, iconKey: string?, order: number)
	local row = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = list,
	})
	local icon = Kit.label({ Text = "", Size = UDim2.fromOffset(32, 32), Parent = row })
	if not (iconKey and Skin.Icon(icon, iconKey)) then
		icon:Destroy()
	end
	local label = Kit.label({
		Text = text,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, if iconKey then 40 else 0, 0, 2),
		Size = UDim2.new(1, -40, 1, -4),
		Parent = row,
	}, 28)
	Kit.textStroke(Color3.fromRGB(70, 40, 0), 2, 0).Parent = label
end

local function claim(action: string, arg: any?, frame: GuiObject)
	local result = MetaClient.Call(action, arg)
	if result.Ok then
		Sfx.Play("Reward")
		Effects.Sparks(frame, Theme.Color.Gold, 18, 0.9)
	else
		hint(MetaClient.Message(result))
	end
	Gifts.Refresh()
end

-- Big icon + big number for a reward bundle: the Shard icon and "+20", or the potion's own emoji
-- and "x2" when there are no Shards. Other potions go on a small line under the number.
-- `iconKey` swaps the main icon (the day-7 chest uses the GIFTS icon).
local function rewardFace(frame: GuiObject, bundle, iconTop: number, iconKey: string?)
	bundle=Meta.RetireShards(bundle)
	local firstPotion, potionCount = nil, 0
	for _, potion in Meta.Potions do
		local count = bundle.Potions and bundle.Potions[potion.Id]
		if count and count > 0 and firstPotion == nil then
			firstPotion, potionCount = potion, count
		end
	end
	local shards = bundle.TraitShards or 0
	local icon = Kit.label({
		Name = "RewardIcon",
		Text = if shards > 0 or firstPotion == nil then "🧬" else firstPotion.Icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, iconTop),
		Size = UDim2.fromOffset(46, 46),
		Parent = frame,
	}, 42)
	local key = iconKey or (if shards > 0 then "TraitShards" elseif firstPotion then `Potion:{firstPotion.Id}` else nil)
	local art = if key then Skin.Icon(icon, key) else nil
	local amount = Kit.label({
		Text = if shards > 0 then `+{Kit.commas(shards)}` elseif firstPotion then `x{potionCount}` else "",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, iconTop + 46),
		Size = UDim2.new(0.92, 0, 0, 28),
		Parent = frame,
	}, 28)
	Kit.textStroke(Color3.fromRGB(13, 17, 27), 2, 0).Parent = amount
	local extra = if shards > 0 and bundle.Potions then Meta.Describe({ Potions = bundle.Potions }) else ""
	if extra ~= "" then
		RewardLine.new({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, iconTop + 74),
			Size = UDim2.new(0.92, 0, 0, 18),
			Parent = frame,
		}, extra, 17)
	end
	return art or icon
end

-- CLAIM button and the state text ("✓ CLAIMED", timers) that shows over the dim cover.
local function footer(frame: GuiObject, onClaim: () -> ())
	local button = Kit.button("CLAIM", Theme.Color.Gold, GOLD_DEEP, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.86, 0, 0, 34),
		ZIndex = 6,
		Parent = frame,
	})
	button.Activated:Connect(onClaim)
	local state = Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		TextColor3 = CLAIMED_GREEN,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.9, 0, 0, 22),
		ZIndex = 6,
		Parent = frame,
	}, 20)
	Kit.textStroke(Color3.fromRGB(10, 6, 24), 2, 0).Parent = state
	return button, state
end

-- Today's quest rows (rebuilt when the day, and so the quests, change).
local function buildQuests()
	for _, child in questBox:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(questRows)
	local quests = State.Meta.Quests
	questDayShown = quests.Day
	for i, entry in quests.List do
		local quest = Meta.QuestById[entry.Id]
		if quest == nil then
			continue
		end
		local row = Kit.tile({ LayoutOrder = i, Size = UDim2.new(1, -6, 0, 70), Parent = questBox })
		Kit.label({
			Text = quest.Text,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 14, 0, 8),
			Size = UDim2.new(0.49, 0, 0, 24),
			Parent = row,
		}, 24)
		RewardLine.new({
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.new(0.24, -8, 0, 24),
			Parent = row,
		}, Meta.Describe(quest.Reward), 19)
		local track = Kit.new("Frame", {
			Position = UDim2.new(0, 14, 0, 42),
			Size = UDim2.new(0.74, -14, 0, 14),
			BackgroundColor3 = Color3.fromRGB(6, 7, 11),
			Parent = row,
		}, { Kit.corner(UDim.new(1, 0)) })
		local fill = Kit.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Color.Quick,
			Parent = track,
		}, { Kit.corner(UDim.new(1, 0)) })
		local count = Kit.label({
			Text = "",
			Font = Theme.Font.Heavy,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = track,
		}, 13)
		Kit.textStroke(Color3.fromRGB(10, 6, 24), 1.5, 0).Parent = count
		local button = Kit.button("CLAIM", Theme.Color.Gold, GOLD_DEEP, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.22, 0, 0, 42),
			ZIndex = 6,
			Parent = row,
		})
		button.Activated:Connect(function()
			claim("ClaimQuest", quest.Id, row)
		end)
		local state = Kit.label({
			Text = "",
			Font = Theme.Font.Display,
			TextColor3 = CLAIMED_GREEN,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0.22, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = row,
		}, 22)
		Kit.textStroke(Color3.fromRGB(10, 6, 24), 2, 0).Parent = state
		questRows[entry.Id] = { Row = row, Stroke = row.UIStroke, Fill = fill, Count = count, Button = button, State = state, Quest = quest }
	end
end

local function build()
	built = true
	-- Daily quests first: what to do today.
	local questHead = Kit.new("Frame", {
		LayoutOrder = -2,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = list,
	})
	local questTitle = Kit.label({
		Text = "DAILY QUESTS",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(0.6, 0, 1, -4),
		Parent = questHead,
	}, 28)
	Kit.textStroke(Color3.fromRGB(70, 40, 0), 2, 0).Parent = questTitle
	questReset = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = CAPTION,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0.38, 0, 0, 20),
		Parent = questHead,
	}, 18)
	questBox = Kit.new("Frame", {
		LayoutOrder = -1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) }),
	})
	buildQuests()

	heading("DAILY STREAK", "GIFTS", 1)
	local dailyRow = Kit.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
	})
	for day, bundle in Meta.Daily do
		-- Seven tiles always fit the row.
		local frame = Kit.tile({ LayoutOrder = day, Size = UDim2.new(1 / #Meta.Daily, -7, 1, -6), Parent = dailyRow })
		Kit.label({
			Text = `DAY {day}`,
			Font = Theme.Font.Display,
			TextColor3 = CAPTION,
			Position = UDim2.new(0.05, 0, 0, 8),
			Size = UDim2.new(0.9, 0, 0, 20),
			Parent = frame,
		}, 20)
		rewardFace(frame, bundle, 30, if day == #Meta.Daily then "GIFTS" else nil)
		local button, state = footer(frame, function()
			claim("ClaimDaily", nil, frame)
		end)
		dailyTiles[day] = { Frame = frame, Stroke = frame.UIStroke, Button = button, State = state }
	end

	heading("PLAYTIME GIFTS · this session", nil, 3)
	local giftRow = Kit.new("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(128, 166),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
	})
	for i, gift in Meta.Playtime do
		local frame = Kit.tile({ LayoutOrder = i, Parent = giftRow })
		Kit.label({
			Text = `{gift.Minutes} MIN`,
			Font = Theme.Font.Display,
			TextColor3 = CAPTION,
			Position = UDim2.new(0.05, 0, 0, 8),
			Size = UDim2.new(0.9, 0, 0, 18),
			Parent = frame,
		}, 18)
		local box = rewardFace(frame, gift.Reward, 28, "GIFTS")
		local button, state = footer(frame, function()
			claim("ClaimGift", i, frame)
		end)
		local scale = Kit.new("UIScale", { Scale = 1, Parent = box })
		local bounce = TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Scale = 1.12,
		})
		giftTiles[i] = { Frame = frame, Stroke = frame.UIStroke, Button = button, State = state, Gift = gift, Bounce = bounce, BoxScale = scale }
	end

	heading("ROLL MILESTONES", nil, 5)
	for i, milestone in Meta.Milestones do
		local row = Kit.tile({ LayoutOrder = 5 + i, Size = UDim2.new(1, -6, 0, 62), Parent = list })
		Kit.label({
			Text = `{Kit.commas(milestone.Rolls)} ROLLS`,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 14, 0, 7),
			Size = UDim2.new(0.3, 0, 0, 26),
			Parent = row,
		}, 26)
		RewardLine.new({
			Position = UDim2.new(0.31, 0, 0, 9),
			Size = UDim2.new(0.33, 0, 0, 22),
			Parent = row,
		}, Meta.Describe(milestone.Reward), 21)
		local track = Kit.new("Frame", {
			Position = UDim2.new(0, 14, 0, 40),
			Size = UDim2.new(0.64, -14, 0, 12),
			BackgroundColor3 = Color3.fromRGB(6, 7, 11),
			Parent = row,
		}, { Kit.corner(UDim.new(1, 0)) })
		local fill = Kit.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Color.Gold,
			Parent = track,
		}, { Kit.corner(UDim.new(1, 0)) })
		local button = Kit.button("CLAIM", Theme.Color.Gold, GOLD_DEEP, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.22, 0, 0, 40),
			ZIndex = 6,
			Parent = row,
		})
		button.Activated:Connect(function()
			claim("ClaimMilestone", i, row)
		end)
		local state = Kit.label({
			Text = "",
			Font = Theme.Font.Display,
			TextColor3 = CAPTION,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0.3, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = row,
		}, 22)
		Kit.textStroke(Color3.fromRGB(10, 6, 24), 2, 0).Parent = state
		milestoneRows[i] = { Row = row, Stroke = row.UIStroke, Fill = fill, Button = button, State = state, Milestone = milestone }
	end
end

-- Outline: gold and thick when ready to claim, faint under a dim cover, the normal tile edge otherwise.
local function highlight(stroke: UIStroke, ready: boolean, dimmed: boolean)
	stroke.Color = if ready then Theme.Color.Gold else Theme.Color.TileEdge
	stroke.Thickness = if ready then 3.5 else 2.5
	stroke.Transparency = if ready then 0 elseif dimmed then 0.65 else 0.1
end

function Gifts.Refresh()
	if not modal or not modal.IsOpen then
		return
	end
	if not built then
		build()
	end
	-- Daily quests.
	local quests = State.Meta.Quests
	if quests.Day ~= questDayShown then
		buildQuests()
	end
	local resetIn = math.max(0, math.floor(quests.ResetIn - (os.clock() - State.MetaAt)))
	questReset.Text = string.format("new quests in %d:%02d:%02d", resetIn // 3600, resetIn // 60 % 60, resetIn % 60)
	for _, entry in quests.List do
		local refs = questRows[entry.Id]
		if refs then
			local goal = refs.Quest.Goal
			local done = entry.Progress >= goal
			refs.Fill.Size = UDim2.fromScale(math.clamp(entry.Progress / goal, 0, 1), 1)
			refs.Count.Text = `{Kit.commas(entry.Progress)} / {Kit.commas(goal)}`
			refs.Button.Visible = done and not entry.Claimed
			refs.State.Text = if entry.Claimed then "✓ CLAIMED" elseif done then "" else "IN PROGRESS"
			refs.State.TextColor3 = if entry.Claimed then CLAIMED_GREEN else CAPTION
			highlight(refs.Stroke, done and not entry.Claimed, entry.Claimed)
			Kit.dimTile(refs.Row, entry.Claimed)
		end
	end
	-- Daily streak.
	local daily = State.Meta.Daily
	for day, refs in dailyTiles do
		local claimed = if daily.CanClaim then day < daily.Day else day <= daily.Day
		local today = daily.CanClaim and day == daily.Day
		refs.Button.Visible = today
		refs.State.Text = if claimed then "✓ CLAIMED" elseif not daily.CanClaim and day == daily.Day + 1 then "TOMORROW" else ""
		refs.State.TextColor3 = if claimed then CLAIMED_GREEN else CAPTION
		highlight(refs.Stroke, today, claimed)
		Kit.dimTile(refs.Frame, claimed)
	end
	-- Playtime gifts.
	local session = State.SessionSeconds()
	for i, refs in giftTiles do
		local claimed = MetaClient.GiftClaimed(i)
		local ready = session >= refs.Gift.Minutes * 60
		local claimable = ready and not claimed
		refs.Button.Visible = claimable
		refs.State.Text = if claimed then "✓ CLAIMED" elseif ready then "" else clockText(refs.Gift.Minutes * 60 - session)
		refs.State.TextColor3 = if claimed then CLAIMED_GREEN else Theme.Color.Text
		highlight(refs.Stroke, claimable, not claimable)
		Kit.dimTile(refs.Frame, not claimable)
		-- Only boxes you can open bounce.
		if claimable and refs.Bounce.PlaybackState ~= Enum.PlaybackState.Playing then
			refs.Bounce:Play()
		elseif not claimable and refs.Bounce.PlaybackState == Enum.PlaybackState.Playing then
			refs.Bounce:Cancel()
			refs.BoxScale.Scale = 1
		end
	end
	-- Milestones.
	local rolls = State.Rolls()
	for _, refs in milestoneRows do
		local target = refs.Milestone.Rolls
		local claimed = State.Meta.Milestones[tostring(target)] == true
		local ready = rolls >= target
		refs.Fill.Size = UDim2.fromScale(math.clamp(rolls / target, 0, 1), 1)
		refs.Button.Visible = ready and not claimed
		refs.State.Text = if claimed then "✓ CLAIMED" elseif ready then "" else `{Kit.commas(rolls)} / {Kit.commas(target)}`
		refs.State.TextColor3 = if claimed then CLAIMED_GREEN else CAPTION
		highlight(refs.Stroke, ready and not claimed, claimed)
		Kit.dimTile(refs.Row, claimed)
	end
end

-- `host`: the QUESTS panel (Modal.Tabbed); daily quests and gifts are its second tab.
function Gifts.Init(playerGui: Instance, host: any?)
	modal = if host then host:Page("DAILY & GIFTS") else Modal.new(playerGui, "GiftsGui", "GIFTS", Vector2.new(0.84, 0.86), Vector2.new(940, 700))
	claimAllButton=Kit.button("CLAIM ALL",Theme.Color.Support,Theme.Color.SupportDeep,{Name="ClaimAll",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(180,36),Parent=modal.Body})
	claimAllButton.Activated:Connect(function()
		if claimingAll then return end
		claimingAll=true;claimAllButton.Label.Text="CLAIMING..."
		local result=MetaClient.Call("ClaimAll","Rewards")
		claimingAll=false;claimAllButton.Label.Text="CLAIM ALL"
		if result.Ok then hint(`Claimed {if result.Extra then result.Extra.Claimed else 0} rewards`);Sfx.Play("Reward") else hint(MetaClient.Message(result)) end
		Gifts.Refresh()
	end)
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.4, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	list = Kit.new("ScrollingFrame", {
		Position=UDim2.fromOffset(0,44),
		Size = UDim2.new(1,0,1,-44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Gold,
		-- The bar takes its own strip, so the last tile in a row never sits under it.
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	modal.OnOpen = function()
		-- Ask for fresh numbers (session time, daily status) each time it opens.
		task.spawn(function()
			MetaClient.Call("Get")
			Gifts.Refresh()
		end)
		Gifts.Refresh()
	end
	State.Changed:Connect(Gifts.Refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			Gifts.Refresh()
		end
	end)
end

function Gifts.Toggle()
	modal:Toggle()
end

return Gifts
