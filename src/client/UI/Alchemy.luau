--!nonstrict
-- PACK ALCHEMY (Hoshi's second tab, in town only): CONDENSE 10 Roll Packs into a Big Roll Pack and 10 Big
-- Roll Packs into a Mega Roll Pack, or INFUSE a Mega Roll Pack with an element for Packs.InfuseCost Shards
-- (that element's cards weigh x1.5 inside each rarity). One row per pack size with what you hold. The
-- server does it (RollService "PackAlchemy", only beside Hoshi).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared.Packs)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local Alchemy = {}

local REASONS = {
	NotEnough = "Not enough packs",
	NoShards = "Not enough Shards",
	TooFar = "Stand beside Hoshi to do alchemy",
	TooFast = "One at a time",
}

local modal
local list: ScrollingFrame
local hintLabel: TextLabel
local hintToken = 0
local busy = false

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.4, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local draw -- below

local function request(action: string, packId: string, element: string?)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.PackAlchemy:InvokeServer(action, packId, element)
	end)
	busy = false
	if not ok or result == nil or not result.Ok then
		local reason = if ok and result then result.Reason else nil
		hint(REASONS[reason] or "Couldn't do that")
		return
	end
	State.ApplyPacks(result.Packs)
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	local made = Packs.ById[result.Made]
	Sfx.Play("Upgrade", 1.15)
	Effects.Sparks(list, if made then made.Color else Theme.Color.Gold, 20, 0.9)
	hint(if made then `Made a {made.Name}!` else "Done")
	draw()
end

local function row(order: number, pack, height: number)
	local frame = Kit.tile({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Parent = list }, pack.Color)
	Kit.label({
		Text = pack.Icon,
		Font = Theme.Font.Heavy,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(52, 52),
		Parent = frame,
	}, 44)
	Kit.label({
		Text = string.upper(pack.Name),
		Font = Theme.Font.Display,
		TextColor3 = pack.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(74, 10),
		Size = UDim2.new(1, -300, 0, 26),
		Parent = frame,
	}, 22)
	Kit.label({
		Text = `You have <b>{Kit.commas(State.Packs[pack.Id] or 0)}</b>  ·  {Kit.commas(pack.Rolls)} rolls each`,
		RichText = true,
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(74, 38),
		Size = UDim2.new(1, -300, 0, 20),
		Parent = frame,
	}, 16)
	return frame
end

function draw()
	if not modal.IsOpen then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, pack in Packs.List do
		if pack.Element then
			continue
		end
		order += 1
		local held = State.Packs[pack.Id] or 0
		local rule = Packs.Condense[pack.Id]
		local infuse = false
		local frame = row(order, pack, if infuse then 150 else 76)
		if rule then
			local to = Packs.ById[rule.To]
			local button = Kit.button(`CONDENSE {rule.Need} → 1 {to.Icon}`, Theme.Color.Accent, Theme.Color.AccentDeep, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 14),
				Size = UDim2.fromOffset(220, 46),
				Parent = frame,
			})
			Kit.dim(button, held < rule.Need)
			button.Activated:Connect(function()
				if (State.Packs[pack.Id] or 0) >= rule.Need then
					request("Condense", pack.Id)
				else
					hint(`Needs {rule.Need} {pack.Name}s`)
				end
			end)
		end
		if infuse then
			Kit.label({
				Text = `INFUSE · 💎{Kit.commas(Packs.InfuseCost)}: that element's cards weigh x{Packs.InfuseWeight} inside each rarity`,
				Font = Theme.Font.Heavy,
				TextColor3 = Theme.Color.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(14, 70),
				Size = UDim2.new(1, -28, 0, 20),
				Parent = frame,
			}, 15)
			local elements = Kit.new("Frame", {
				Position = UDim2.fromOffset(14, 96),
				Size = UDim2.new(1, -28, 0, 42),
				BackgroundTransparency = 1,
				Parent = frame,
			}, {
				Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			})
			local canPay = held >= 1 and (State.Summary.Shards or 0) >= Packs.InfuseCost
			for i, element in Packs.InfuseElements do
				local button = Kit.button(`{element.Icon} {string.upper(element.Id)}`, element.Color, element.Color:Lerp(Color3.new(0, 0, 0), 0.6), {
					LayoutOrder = i,
					Size = UDim2.new(0.2, -7, 1, 0),
					Parent = elements,
				})
				Kit.dim(button, not canPay)
				button.Activated:Connect(function()
					request("Infuse", "1000", element.Id)
				end)
			end
		end
	end
	-- Infused Mega Packs you hold.
	for _, pack in Packs.List do
		if pack.Element and (State.Packs[pack.Id] or 0) > 0 then
			order += 1
			row(order, pack, 76)
		end
	end
	order += 1
	Kit.label({
		LayoutOrder = order,
		Text = "Open packs from your BAG. Condensed packs use your active collection and luck when opened.",
		Font = Theme.Font.Bold,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = list,
	}, 14)
end

-- `host`: Hoshi's panel (Modal.Tabbed); this is its PACK ALCHEMY tab.
function Alchemy.Init(host)
	modal = host:Page("PACK ALCHEMY")
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 12),
		Size = UDim2.new(0.45, 0, 0, 20),
		Parent = modal.Header,
	}, 16)
	list = Kit.new("ScrollingFrame", {
		Name = "Packs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
	})
	modal.OnOpen = draw
	State.Changed:Connect(function(kind)
		if kind ~= "raid" and modal.IsOpen and not busy then
			draw()
		end
	end)
end

return Alchemy
