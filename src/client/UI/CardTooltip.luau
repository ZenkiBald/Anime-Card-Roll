--!nonstrict
-- Card hover zoom + ability flyout, for the DECK formation plates and the CARD VAULT tiles.
--   PC: the card scales to 1.15 (0.15 s quad) and rises to ZIndex 50 on MouseEnter; after 0.25 s of
--   hovering, the flyout opens beside it. MouseLeave closes it and puts the card back.
--   Touch: a long press (or a tap) opens the flyout; a tap anywhere else closes it.
-- Viewport-bounded, scrollable skill card: identity, Attack stats, authored techniques and limit pills.
-- Uses the same ability renderer as the Index, reveals and battle inspection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Awaken = require(Shared.Awaken)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local StatLine=require(script.Parent.StatLine)
local Abilities = require(script.Parent.Abilities)
local State = require(script.Parent.Parent.State)

local CardTooltip = {}

local HOVER_SCALE = 1.15
local HOVER_DELAY = 0.25
local LONG_PRESS = 0.35
local gui: ScreenGui? = nil
local flyout: Frame? = nil
local owner: GuiObject? = nil -- the card the open flyout belongs to

function CardTooltip.IsOpen(): boolean
	return flyout ~= nil
end

function CardTooltip.Close()
	if flyout then
		flyout:Destroy()
		flyout = nil
	end
	owner = nil
end

local function build(cardId: string, border: string): Frame?
	local card = Cards.Get(cardId)
	if card == nil or gui == nil then return nil end
	local screen = gui.AbsoluteSize
	local width = math.min(380, screen.X - 24)
	local frame = Kit.new("Frame", { Name = "CardTooltip", Size = UDim2.fromOffset(width, math.min(620, screen.Y - 24)),
		BackgroundColor3 = Color3.fromRGB(8, 10, 15), ZIndex = 50, Parent = gui }, {
		Kit.corner(UDim.new(0, 12)), Kit.stroke(Borders.Get(border).Color, 2, 0.15),
	})
	local scroll = Kit.new("ScrollingFrame", { Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, ZIndex = 51, Parent = frame }, {
		Kit.padding(12), Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9) }),
	})
	local function label(name, value, order, size, color)
		return Kit.new("TextLabel", { Name = name, Text = value, RichText = true, Font = if order == 1 then Theme.Font.Display else Theme.Font.Medium,
			TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
			BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order, ZIndex = 52, Parent = scroll })
	end
	local tier = Borders.Get(border)
	label("CardName", card.Name, 1, 23, Color3.new(1, 1, 1))
	label("CardTier", `{tier.Name} · {card.Type}`, 2, 13, tier.Color)
	local own = State.Cards[card.Id]
	local stars, node = if own then own.Stars else 0, if own then Awaken.Level(own) else 0
	local copies = Cards.CopiesAt(own, border)
	if card.Type == "Attack" then StatLine.new(card,stars,border,node,{Size=UDim2.new(1,-4,0,24),LayoutOrder=3,ZIndex=52,Parent=scroll},true,copies) end
	if card.Type == "Attack" and Cards.DupeBonus(copies) > 0 then
		label("Dupes", `Duplicates: +{math.floor(Cards.DupeBonus(copies) * 1000 + 0.5) / 10}% ATK / HP ({copies} copies, max +{math.floor(Cards.DupeCap * 100)}%)`, 3, 13, Color3.fromRGB(255, 210, 90))
	end
	local bondRow = Abilities.BondRow(card, scroll, 4, "small", border)
	for _, child in bondRow:GetDescendants() do if child:IsA("GuiObject") then child.ZIndex += 30 end end
	bondRow.ZIndex += 30
	for i, ability in card.Abilities do
		local row = Abilities.Row(ability, scroll, i + 4, "small", card, stars, border, node)
		-- Rows share the same renderer as the full card sheet, above this tooltip's surface.
		for _, child in row:GetDescendants() do if child:IsA("GuiObject") then child.ZIndex += 30 end end
		row.ZIndex += 30
	end
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	local function fit()
		if frame.Parent and layout then frame.Size = UDim2.fromOffset(width, math.clamp(layout.AbsoluteContentSize.Y + 24, 80, screen.Y - 24)) end
	end
	if layout then layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit) end
	task.defer(fit)
	return frame
end

-- Opens the flyout for `cardId` beside `anchor` (right of it, or left when there's no room).
function CardTooltip.Show(anchor: GuiObject, cardId: string, border: string?)
	CardTooltip.Close()
	local frame = build(cardId, border or "Normal")
	if frame == nil or gui == nil then
		return
	end
	flyout = frame
	owner = anchor
	local function place()
		if flyout ~= frame or not anchor.Parent then return end
		local screen = (gui :: ScreenGui).AbsoluteSize
		local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
		local height = frame.AbsoluteSize.Y
		local width = frame.AbsoluteSize.X
		local x = pos.X + size.X + 10
		if x + width > screen.X - 8 then
			x = pos.X - width - 10
		end
		x = math.clamp(x, 8, math.max(8, screen.X - width - 8))
		local y = math.clamp(pos.Y, 8, math.max(8, screen.Y - height - 8))
		frame.Position = UDim2.fromOffset(x, y)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	task.defer(function()
		if flyout == frame then
			place() -- again once the automatic size has its height
		end
	end)
end

-- Hooks hover zoom and the flyout onto a card button. `info` returns (cardId, border) at the moment it
-- opens, so a reused plate always shows its current card; nil = nothing to show.
function CardTooltip.Attach(button: GuiButton, info: () -> (string?, string?))
	local scale = button:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = button })
	local baseZ = button.ZIndex
	local hovering = false
	local token = 0
	local function open()
		local id, border = info()
		if id and id ~= "" then
			CardTooltip.Show(button, id, border)
		end
	end
	button.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		hovering = true
		token += 1
		local mine = token
		button.ZIndex = 50
		Kit.tween(scale, 0.15, { Scale = HOVER_SCALE }, Enum.EasingStyle.Quad)
		task.delay(HOVER_DELAY, function()
			if hovering and mine == token and button.Parent then
				open()
			end
		end)
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		token += 1
		button.ZIndex = baseZ
		Kit.tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Quad)
		task.delay(0.18, function()
			if owner ~= button or hovering then return end
			local pos = UserInputService:GetMouseLocation()
			local objects = game.Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
			for _, object in objects do if flyout and object:IsDescendantOf(flyout) then return end end
			CardTooltip.Close()
		end)
	end)
	-- A click springs the press scale back to 1 (Kit.pressable); keep the zoom while still hovered.
	button.MouseButton1Up:Connect(function()
		task.delay(0.23, function()
			if hovering then
				Kit.tween(scale, 0.15, { Scale = HOVER_SCALE }, Enum.EasingStyle.Quad)
			end
		end)
	end)
	-- Touch: long press, or a tap, opens it.
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		token += 1
		local mine = token
		task.delay(LONG_PRESS, function()
			if mine == token and button.Parent then
				open()
			end
		end)
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			token += 1
			if owner ~= button then
				open() -- a tap
			end
		end
	end)
	button.Destroying:Connect(function()
		if owner == button then
			CardTooltip.Close()
		end
	end)
end

function CardTooltip.Init(playerGui: Instance)
	gui = Kit.screenGui("CardTooltipGui", 30, playerGui)
	-- A tap or click away from the card closes it.
	UserInputService.InputBegan:Connect(function(input)
		if flyout == nil or owner == nil then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local p = input.Position
		local a, s = owner.AbsolutePosition, owner.AbsoluteSize
		local inside = p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
		if flyout then
			local f, z = flyout.AbsolutePosition, flyout.AbsoluteSize
			inside = inside or (p.X >= f.X and p.X <= f.X + z.X and p.Y >= f.Y and p.Y <= f.Y + z.Y)
		end
		if not inside then
			CardTooltip.Close()
		end
	end)
end

return CardTooltip
