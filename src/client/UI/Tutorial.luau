--!nonstrict
-- Kenji's questline on screen (Tutorial.luau, TutorialService): a tracker banner (in the HUD's quest slot,
-- above the menu, so it scales and hides with the HUD) with the open quest and its progress; when it's done the banner glows and shows CLAIM (a tap claims it right
-- there). Tapping it otherwise, or talking to Kenji, opens KENJI'S PATH: all six quests, what Kenji
-- says, where to go, and the reward. The banner leaves for good once the last quest is claimed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local Meta = require(Shared.Meta)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local Skin = require(script.Parent.Skin)
local RewardLine = require(script.Parent.RewardLine)

local TutorialUi = {}

local SAGE = Color3.fromRGB(255, 214, 120)
local TEAL = Color3.fromRGB(80, 230, 200)

local banner: any -- children read by name
local bannerTitle: TextLabel
local bannerText: TextLabel
local claimPill: Frame
local modal
local list: ScrollingFrame
local state = nil -- TutorialService.State
local busy = false
local wasReady = false

-- Hands a reward to the HUD (set by Main: Hud.Reward and Hud.Hint).
local announce: ((text: string, hint: string?) -> ())? = nil
-- Tells Main the quest line changed (active, ready): the HUD shows the slot and the KENJI badge.
local onChange: ((active: boolean, ready: boolean) -> ())? = nil

local function applyVisible()
	if onChange then
		onChange(TutorialUi.Active(), TutorialUi.Ready())
	end
end

local function rewardText(quest): string
	local text = Meta.Describe(quest.Reward)
	if quest.Title then
		text ..= `  ·  title « {quest.Title} »`
	end
	return text
end

local function drawBanner()
	if state == nil or state.Done then
		applyVisible()
		return
	end
	local quest = Tutorial.Steps[state.Step]
	bannerTitle.Text = `KENJI'S PATH  {state.Step}/{state.Total}`
	if state.Ready then
		bannerText.Text = `{quest.Name} complete · Tap to claim`
	else
		bannerText.Text = `{quest.Text}  <b>{state.Count}/{state.Goal}</b>`
	end
	claimPill.Visible = state.Ready
	banner.UIStroke.Color = if state.Ready then Theme.Color.Gold else SAGE
	banner.UIStroke.Thickness = 1
	if state.Ready and not wasReady then
		banner.Pop.Scale = 1.25
		Kit.tween(banner.Pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Effects.Sparks(banner, Theme.Color.Gold, 16, 0.9)
		Sfx.Play("Reward", 1.2)
	end
	wasReady = state.Ready
	applyVisible()
end

local drawList -- below

local function apply(newState)
	state = newState
	drawBanner()
	if modal and modal.IsOpen then
		drawList()
	end
end

local function claim(action: string?)
	if busy or state == nil or not state.Ready then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.Tutorial:InvokeServer(action or "Claim")
	end)
	busy = false
	if not ok or result == nil or not result.Ok then
		return
	end
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	Sfx.Sting("Epic", true)
	Effects.Sparks(banner, Theme.Color.Gold, 24, 1)
	if announce then
		announce(Meta.Describe(result.Granted or {}), if result.Title then `New title: « {result.Title} »!` else nil)
	end
	wasReady = false
	apply(result.State)
	-- The next quest's opening words.
	local nextQuest = result.State and Tutorial.Steps[result.State.Step]
	if nextQuest and announce then
		task.delay(1.2, function()
			if announce then
				announce("", `Kenji: "{nextQuest.Kenji}"`)
			end
		end)
	end
end

function drawList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local step = if state then state.Step else 1
	for i, quest in Tutorial.Steps do
		local done = i < step
		local open = i == step
		local tile = Kit.tile({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = list }, if open then SAGE elseif done then Theme.Color.Quick else Theme.Color.TileEdge)
		Kit.padding(10).Parent = tile
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = tile })
		local function line(order: number, text: string, color: Color3, size: number, font: Enum.Font?)
			return Kit.label({
				LayoutOrder = order,
				Text = text,
				RichText = true,
				Font = font or Theme.Font.Bold,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = size,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, size + 4),
				Parent = tile,
			}, size)
		end
		local mark = if done then "✓" elseif open then "▶" else "🔒"
		line(1, `{mark}  {i}. <b>{string.upper(quest.Name)}</b>  ·  {quest.Text}`, if open then SAGE elseif done then Theme.Color.Quick else Theme.Color.Muted, 19, Theme.Font.Heavy)
		if open then
			line(2, `"{quest.Kenji}"`, Theme.Color.Text, 16)
			line(3, `👉 {quest.Hint}   ·   progress <b>{state and state.Count or 0}/{quest.Goal}</b>`, TEAL, 15, Theme.Font.Heavy)
			RewardLine.new({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26), Parent = tile }, `Reward: {rewardText(quest)}`, 15)
			if state and state.Ready then
				local button = Kit.button("CLAIM", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
					LayoutOrder = 5,
					Size = UDim2.new(0, 200, 0, 42),
					Parent = tile,
				})
				button.Activated:Connect(function() claim() end)
			end
		elseif not done then
			RewardLine.new({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 24), Parent = tile }, `Reward: {rewardText(quest)}`, 14)
		end
	end
end

-- `slot` is the HUD's quest slot (Hud.QuestSlot); the banner fills it.
function TutorialUi.Init(
	playerGui: Instance,
	slot: GuiObject,
	announceFn: (text: string, hint: string?) -> (),
	changeFn: (active: boolean, ready: boolean) -> (),
	host: any? -- the QUESTS panel (Modal.Tabbed): the path is its first tab
)
	announce = announceFn
	onChange = changeFn
	banner = Kit.new("TextButton", {
		Name = "Tracker",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 12, 19),
		BackgroundTransparency = 0.1,
		Text = "",
		Parent = slot,
	}, {
		Kit.corner(UDim.new(0, 14)),
		Kit.stroke(SAGE, 2, 0),
		Kit.new("UIScale", { Name = "Pop", Scale = 1 }),
	})
	Skin.Apply(banner, "Panel")
	bannerTitle = Kit.label({
		Name = "Title",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextColor3 = SAGE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.035, 0.07),
		Size = UDim2.fromScale(0.93, 0.4),
		Parent = banner,
	}, 17)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = bannerTitle
	bannerText = Kit.label({
		Name = "Text",
		Text = "",
		RichText = true,
		Font = Theme.Font.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.035, 0.5),
		Size = UDim2.fromScale(0.93, 0.42),
		Parent = banner,
	}, 15)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = bannerText
	claimPill = Kit.new("Frame", {
		Name = "Claim",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromScale(0.2, 0.6),
		BackgroundColor3 = Theme.Color.RollDeep,
		Visible = false,
		ZIndex = 3,
		Parent = banner,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 2, 0) })
	Skin.Apply(claimPill, "RollButton")
	Kit.label({ Text = "CLAIM", Font = Theme.Font.Heavy, TextColor3 = Theme.Color.Text, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = claimPill }, 12)
	bannerTitle.Size = UDim2.fromScale(0.72, 0.4)
	bannerText.Size = UDim2.fromScale(0.72, 0.42)
	Kit.pressable(banner)
	banner.Activated:Connect(function()
		if state and state.Ready then
			claim()
		else
			TutorialUi.Open()
		end
	end)

	modal = if host then host:Page("KENJI'S PATH") else Modal.new(playerGui, "KenjiGui", "KENJI'S PATH", Vector2.new(0.7, 0.84), Vector2.new(760, 640))
	local claimAll=Kit.button("CLAIM ALL READY",Theme.Color.Support,Theme.Color.SupportDeep,{Name="ClaimAll",Size=UDim2.fromOffset(200,36),Parent=modal.Body})
	claimAll.Activated:Connect(function() claim("ClaimAll") end)
	list = Kit.new("ScrollingFrame", {
		Name = "Quests",
		Position=UDim2.fromOffset(0,44),Size = UDim2.new(1,0,1,-44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
	})
	modal.OnOpen = drawList

	Remotes.TutorialState.OnClientEvent:Connect(function(newState)
		if type(newState) == "table" then
			apply(newState)
		end
	end)
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.Tutorial:InvokeServer("State")
		end)
		if ok and type(result) == "table" and result.Ok then
			apply(result)
			if not result.Done and result.Step == 1 and announce then
				local first = Tutorial.Steps[1]
				task.delay(4, function()
					if announce then
						announce("", `Kenji: "{first.Kenji}"`)
					end
				end)
			end
		end
	end)
end

-- KENJI'S PATH (from the banner or by talking to Kenji). Returns false once the path is finished.
function TutorialUi.Open(): boolean
	if modal == nil or (state and state.Done) then
		return false
	end
	modal:Open()
	return true
end

function TutorialUi.Active(): boolean
	return state ~= nil and not state.Done
end

-- The open quest is done and waits for CLAIM.
function TutorialUi.Ready(): boolean
	return state ~= nil and not state.Done and state.Ready == true
end

return TutorialUi
