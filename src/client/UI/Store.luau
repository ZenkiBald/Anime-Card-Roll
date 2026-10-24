--!nonstrict
-- STORE (menu button): one full-screen scroll. Top: the Robux passes; middle: Shard bundles and the
-- Server Luck Totem (MonetizationConfig.luau); bottom: REDEEM CODES (UI/Codes builds into it). The server
-- decides everything (MonetizationService): BUY prompts the real purchase, or grants a mock one in
-- Studio / test mode while the id is still 0. Perks marked "changes odds" change odds or hand out random
-- rewards; where paid random items aren't allowed (PolicyService) they show greyed out and the totem
-- isn't sold. ODDS shows every outcome and its live chance.
-- Look: Dark Feudal. Parchment section titles over a steel rule; each product an Urushi plate with a
-- steel bezel, its crest in a diamond IconBadge (a short monogram, no emoji), ghost-text perks, and a
-- solid vermilion wax BUY button reading "R$ price".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.MonetizationConfig)
local Packs = require(Shared.Packs)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local IconBadge = require(script.Parent.Components.IconBadge)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))
local C = UITheme.Colors
local Modal = require(script.Parent.Modal)
local Sfx = require(script.Parent.Sfx)
local Codes = require(script.Parent.Codes)
local State = require(script.Parent.Parent.State)

local Store = {}

local REASONS = {
	Owned = "You already own that",
	NotForSale = "Not on sale yet",
	Restricted = "Not available in your region",
	TooFast = "One at a time",
	Loading = "Still loading",
}

local modal
local list: ScrollingFrame
local hintLabel: TextLabel
local openOdds: (() -> ())? = nil
local hintToken = 0

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.6, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- Clears the rows (the codes box stays: it keeps what's typed).
local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and not child:GetAttribute("Keep") then
			child:Destroy()
		end
	end
end

-- A section heading across the scroll: parchment caps and a slim steel rule.
local function section(order: number, title: string, note: string?)
	local frame = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, if note then 48 else 30),
		BackgroundTransparency = 1,
		Parent = list,
	})
	Kit.label({
		Text = title,
		Font = Theme.Font.Display,
		TextColor3 = C.WashiParchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 22),
		Parent = frame,
	}, 20)
	if note then
		Kit.label({
			Text = note,
			Font = Theme.Font.Bold,
			TextColor3 = C.WashiGhost,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(2, 26),
			Size = UDim2.new(1, -4, 0, 16),
			Parent = frame,
		}, 14)
	end
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = C.TamahaganeSlate,
		Parent = frame,
	})
	return frame
end

-- The solid vermilion wax BUY button: "R$ 149", parchment text, a hot rim; the press springs (Kit.pressable).
local function buyButton(parent: Instance, text: string, enabled: boolean): TextButton
	local button = Kit.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(160, 46),
		AutoButtonColor = false,
		BackgroundColor3 = if enabled then C.VermilionWax else C.UrushiInset,
		Font = Theme.Font.Display,
		Text = text,
		TextColor3 = if enabled then C.WashiParchment else C.WashiGhost,
		TextSize = 22,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0, 4)),
		Kit.stroke(if enabled then C.VermilionHover else C.TamahaganeSlate, 1.5, 0),
	})
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.5).Parent = button
	if enabled then
		button.MouseEnter:Connect(function()
			Kit.tween(button, 0.12, { BackgroundColor3 = C.VermilionHover })
		end)
		button.MouseLeave:Connect(function()
			Kit.tween(button, 0.12, { BackgroundColor3 = C.VermilionWax })
		end)
	end
	Kit.pressable(button)
	return button
end

local draw -- below

local function request(action: string, key: string?)
	local ok, result = pcall(function()
		return Remotes.Store:InvokeServer(action, key)
	end)
	if not ok or result == nil then
		hint("Couldn't reach the store")
		return
	end
	if not result.Ok then
		hint(REASONS[result.Reason] or "Couldn't buy that")
		return
	end
	if result.State then
		State.ApplyStore(result.State)
	end
	if result.Mock then
		Sfx.Play("Upgrade", 1.1)
		hint("Granted (Studio mock purchase: no Robux spent)")
	elseif result.Prompted then
		hint("Check the purchase window")
	end
	draw()
end

-- The crests: short monograms that say what each product does (no emoji).
local CRESTS = { FastRoll = "FR", AutoRoll = "A+", TripleRoll = "x3", VIP = "VIP" }

local function row(order: number, color: Color3, crest: string, title: string, perks: { { Text: string, Random: boolean? } }, price: number, owned: boolean, onBuy: () -> (), blocked: boolean?)
	local restricted = State.Store.Restricted
	local frame = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.UrushiRaised,
		Parent = list,
	}, { Kit.corner(UDim.new(0, 5)), Kit.stroke(C.TamahaganeSlate, 1.5, 0) })
	Kit.padding(12).Parent = frame
	-- The product's crest: a short monogram in a diamond plate glowing in the product's colour.
	IconBadge.new({
		IconAsset = crest,
		GlowColor = color,
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.fromOffset(-2, -2),
		Parent = frame,
	})
	local title_ = Kit.label({
		Text = title,
		Font = Theme.Font.Display,
		TextColor3 = C.WashiParchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(1, -260, 0, 30),
		Parent = frame,
	}, 28)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = title_
	local lines = {}
	for _, perk in perks do
		if perk.Random and restricted then
			table.insert(lines, `<font color="#4E4A44">• {perk.Text} (not available in your region)</font>`)
		elseif perk.Random then
			table.insert(lines, `• {perk.Text}  <font color="#C9A24A">· changes odds</font>`)
		else
			table.insert(lines, `• {perk.Text}`)
		end
	end
	Kit.label({
		Text = table.concat(lines, "\n"),
		RichText = true,
		Font = Theme.Font.Bold,
		TextColor3 = C.WashiGhost,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 16,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(66, 32),
		Size = UDim2.new(1, -260, 0, 20),
		Parent = frame,
	}, 16)
	local buy = buyButton(frame, if owned then "OWNED" elseif blocked then "UNAVAILABLE" else `R$ {price}`, not owned and not blocked)
	buy.Activated:Connect(function()
		if not owned and not blocked then
			onBuy()
		end
	end)
end

function draw()
	if not modal.IsOpen then
		return
	end
	clear()
	local store = State.Store
	section(1, "GAME PASSES", "Yours for good")
	for i, pass in MonetizationConfig.Passes do
		row(10 + i, pass.Color, CRESTS[pass.Key] or string.sub(pass.Name, 1, 2), string.upper(pass.Name), pass.Perks, pass.Price, store.Passes[pass.Key] == true, function()
			request("Buy", pass.Key)
		end)
	end
	section(40, "SHARDS & SERVER TOTEM", "Buy as often as you like")
	for i, bundle in MonetizationConfig.ShardBundles do
		row(40 + i, Color3.fromRGB(196, 140, 255), Kit.short(bundle.Shards), string.upper(bundle.Name), {
			{ Text = `{Kit.commas(bundle.Shards)} Shards (spend them on potions and Shard upgrades)`, Random = true },
		}, bundle.Price, false, function()
			request("BuyShards", bundle.Key)
		end, store.Restricted)
	end
	local totem = MonetizationConfig.Totem
	local now = workspace:GetServerTimeNow()
	local running = store.TotemEnds and store.TotemEnds > now
	local packs = Packs.Describe(totem.Packs)
	row(60, Color3.fromRGB(110, 255, 160), `x{totem.Luck}`, string.upper(totem.Name), {
		{ Text = `The whole server: x{totem.Luck} luck for {totem.Seconds // 60} min (buy again to add time)`, Random = true },
		{ Text = `You: {packs} and {totem.TraitShards} Trait Shards`, Random = true },
		{ Text = if running then `Running now: {math.floor((store.TotemEnds - now) / 60)} min left` else "A totem rises by the town spawn while it runs" },
	}, totem.Price, false, function()
		request("BuyTotem")
	end, store.Restricted)

	local footer = Kit.new("Frame", {
		LayoutOrder = 70,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = list,
	})
	Kit.label({
		Text = if store.Mock
			then "Studio / test mode: BUY grants without Robux while a pass id is 0 (MonetizationConfig)."
			else "Perks marked \"changes odds\" change odds or give random rewards: every outcome and its live chance is in ODDS.",
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -150, 1, 0),
		Parent = footer,
	}, 15)
	local odds = Kit.button("ODDS", Theme.Color.Quick, Theme.Color.QuickDeep, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(130, 40),
		Parent = footer,
	})
	odds.Activated:Connect(function()
		if openOdds then
			openOdds()
		end
	end)
end

function Store.Init(playerGui: Instance, oddsFn: (() -> ())?)
	openOdds = oddsFn
	modal = Modal.new(playerGui, "StoreGui", "STORE", Vector2.new(0.96, 0.94), Vector2.new(1120, 880))
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 16),
		Size = UDim2.new(0.5, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	list = Kit.new("ScrollingFrame", {
		Name = "Passes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
	})
	-- REDEEM CODES at the bottom (built once; it stays through redraws).
	section(90, "REDEEM CODES", "Codes from updates and socials: each works once")
	Codes.Build(list, 91)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and (child.LayoutOrder == 90 or child.LayoutOrder == 91) then
			child:SetAttribute("Keep", true)
		end
	end
	modal.OnOpen = function()
		Codes.Reset()
		draw()
	end
	State.Changed:Connect(function(kind)
		if kind == "store" then
			draw()
		end
	end)
end

function Store.Toggle()
	modal:Toggle()
end

-- Opened at the Server Luck Totem (the last row; HUD: STORE > TOTEM).
function Store.OpenTotem()
	modal:Open()
	task.defer(function()
		list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
	end)
end

return Store
