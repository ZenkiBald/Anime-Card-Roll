--!nonstrict
-- Card hover zoom + ability flyout, for the DECK formation plates and the CARD VAULT tiles.
--   PC: the card scales to 1.15 (0.15 s quad) and rises to ZIndex 50 on MouseEnter; after 0.25 s of
--   hovering, the flyout opens beside it. MouseLeave closes it and puts the card back.
--   Touch: a long press (or a tap) opens the flyout; a tap anywhere else closes it.
-- Flyout (280 px Urushi lacquer, 2 px Tamahagane frame, a line of the element's glow on top): name in Washi
-- parchment, title, element and role IconBadges (the card's `Role`), border tier ("Gold Border · 4x"); then the Basic (name, target, formula), the Skill (name, cooldown,
-- stagger, effect), the Ultimate (bold italic name, energy cost, text) and the card's bond links.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local CardInfo = require(Shared.CardInfo)
local Borders = require(Shared.Borders)
local Elements = require(Shared.Elements)
local Config = require(Shared.Config)
local Awaken = require(Shared.Awaken)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Abilities = require(script.Parent.Abilities)
local ElementUi = require(script.Parent.ElementUi)
local State = require(script.Parent.Parent.State)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))

local CardTooltip = {}

local WIDTH = 280
local HOVER_SCALE = 1.15
local HOVER_DELAY = 0.25
local LONG_PRESS = 0.35
local gui: ScreenGui? = nil
local flyout: Frame? = nil
local owner: GuiObject? = nil -- the card the open flyout belongs to

-- Stagger a skill adds to an enemy leader: every damage hit fills Config.Battle.StaggerPerHit.
local function staggerText(ability): string
	local hits = 0
	for _, effect in ability.Effects do
		if effect.Kind == "Damage" then
			hits += effect.Hits or 1
		end
	end
	if hits == 0 then
		return "no stagger"
	end
	return `+{string.format("%.1f", hits * Config.Battle.StaggerPerHit * 100)}% stagger`
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
	if card == nil or gui == nil then
		return nil
	end
	local element = Elements.Get(card.Element)
	local edge = if element then element.Color else UITheme.Colors.TamahaganeLight
	local tier = Borders.Get(border)
	local role = card.Role -- Cards.luau: Striker | Hexer | Mender | Warder
	local frame = Kit.new("Frame", {
		Name = "CardTooltip",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0.03,
		ZIndex = 50,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(0, 5)),
		Kit.padding(10),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
	})
	-- A 2 px Tamahagane steel frame, and a thin line of the element's glow along the top.
	local steel = Instance.new("UIStroke")
	steel.Thickness = 2
	steel.Color = UITheme.Colors.Tamahagane
	steel.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	steel.Parent = frame
	Kit.new("Frame", {
		Name = "ElementLine",
		Size = UDim2.new(1, 0, 0, 2),
		LayoutOrder = 0, -- first in the list
		BorderSizePixel = 0,
		BackgroundColor3 = edge,
		ZIndex = 52,
		Parent = frame,
	}, { Kit.new("UIGradient", { Transparency = NumberSequence.new(0.6, 0) }) })
	local order = 0
	local function line(text: string, font: Enum.Font, color: Color3, size: number)
		order += 1
		return Kit.new("TextLabel", {
			Text = text,
			RichText = true,
			Font = font,
			TextColor3 = color,
			TextSize = size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			ZIndex = 51,
			Parent = frame,
		})
	end
	local function badge(text: string, color: Color3): string
		return `<font color="#{color:ToHex()}"><b>{text}</b></font>`
	end
	local function rule()
		order += 1
		Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = UITheme.Colors.Tamahagane,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 51,
			Parent = frame,
		})
	end

	-- Header: the name in Washi parchment, the title, then the element and role badges with their names
	-- and the border tier.
	line(string.upper(card.Name), Theme.Font.Display, UITheme.Colors.WashiParchment, 20)
	line(card.Title or "", Theme.Font.Bold, UITheme.Colors.TextMuted, 13)
	order += 1
	local chips = Kit.new("Frame", {
		Name = "Badges",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 51,
		Parent = frame,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local function chip(badgeFrame: Frame?, text: string, color: Color3, chipOrder: number)
		if badgeFrame then
			badgeFrame.LayoutOrder = chipOrder
			badgeFrame.Parent = chips
		end
		Kit.new("TextLabel", {
			Text = text,
			Font = Theme.Font.Heavy,
			TextColor3 = color,
			TextSize = 12,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = chipOrder + 1,
			ZIndex = 52,
			Parent = chips,
		})
	end
	if element then
		chip(ElementUi.Badge(element.Id, { Size = UDim2.fromOffset(28, 28), ZIndex = 52 }), string.upper(element.Name), element.Color, 1)
	end
	local roleInfo = UITheme.Roles[role]
	chip(ElementUi.RoleBadge(role, { Size = UDim2.fromOffset(28, 28), ZIndex = 52 }), `  {string.upper(role or "")}`, if roleInfo then roleInfo.Color else UITheme.Colors.TextMuted, 3)
	line(badge(Borders.Label(border), tier.Color), Theme.Font.Heavy, UITheme.Colors.WashiParchment, 13)
	-- The rarity number at this border: how many pulls it takes (Cards.Rarity).
	line(`RARITY <font color="#{tier.Color:Lerp(Color3.new(1, 1, 1), 0.25):ToHex()}"><b>{Kit.commas(Cards.Rarity(card.Id, border))}</b></font>`, Theme.Font.Heavy, UITheme.Colors.WashiParchment, 14)
	-- The card's battle numbers at its stars, border and Awakening.
	local own = State.Cards[card.Id]
	local stars = if own then own.Stars else 0
	local node = if own then Awaken.Level(own) else 0
	line(Kit.statsText(card, stars, border, node, true), Theme.Font.Heavy, UITheme.Colors.WashiParchment, 14)
	line(`{card.Type}: {CardInfo.Job(card)}. {CardInfo.CopyBonus(stars)}.`, Theme.Font.Bold, Theme.Color.Muted, 13)
	-- What its duplicates are for: the next Awakening node, and fusing this border's pile at Hoshi.
	if own then
		local nextNode = Awaken.Nodes[node + 1]
		if nextNode and nextNode.Node <= 4 then
			line(`AWAKENING <font color="#4FC3F7">{Kit.commas(own.Copies)}/{nextNode.Copies}</font> → {nextNode.Name}: {nextNode.Text}`, Theme.Font.Bold, UITheme.Colors.WashiGhost, 12)
		end
		local pile = (own.BorderCopies or {})[border] or 0
		local nextBorder = Borders.Next(border)
		if nextBorder then
			local ready = pile >= Config.FusionCopies
			line(
				if ready
					then `<font color="#FFD700"><b>FUSE!</b></font> {pile} {Borders.Get(border).Name} copies: fuse 100 into a {Borders.Get(nextBorder).Name} at Hoshi`
					else `FUSION <font color="#FFD700">{pile}/{Config.FusionCopies}</font> {Borders.Get(border).Name} copies → 1 {Borders.Get(nextBorder).Name} (at Hoshi)`,
				Theme.Font.Bold,
				UITheme.Colors.WashiGhost,
				12
			)
		end
	end

	-- Abilities: Basic, Skill, Ultimate (passives / auras / signatures follow in plain rows).
	local basic, skill, ult = Cards.Ability(card, "Basic"), Cards.Ability(card, "Skill"), Cards.Ability(card, "Ultimate")
	if basic then
		rule()
		line(`{badge("BASIC", Abilities.Slots.Basic.Color)}  <b>{basic.Name}</b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`Automatic on its action\n{Abilities.Describe(basic, card, stars, border, node)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	if skill then
		rule()
		line(`{badge("SKILL", Abilities.Slots.Skill.Color)}  <b>{skill.Name}</b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`Every {skill.Every or 3} actions  ·  {staggerText(skill)}\n{Abilities.Describe(skill, card, stars, border, node)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	if ult then
		rule()
		line(`{badge("ULTIMATE", Abilities.Slots.Ultimate.Color)}  <b><i>{ult.Name}</i></b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`Tap at {Config.Battle.UltimateCost} energy\n{Abilities.Describe(ult, card, stars, border, node)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	for _, ability in card.Abilities do
		if ability.Slot ~= "Basic" and ability.Slot ~= "Skill" and ability.Slot ~= "Ultimate" then
			local slot = Abilities.Slots[ability.Slot] or Abilities.Slots.Basic
			rule()
			line(`{badge(slot.Label, slot.Color)}  <b>{ability.Name}</b>\n{Abilities.Describe(ability, card, stars, border, node)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
		end
	end
	if card.Link then
		line(`<b>{card.Link.Name}</b>: {CardInfo.Link(card, border)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end

	-- Bond links.
	local bonds = Elements.BondsOf(card.Id)
	if #bonds > 0 then
		rule()
		for _, bond in bonds do
			local partner = Cards.Get(bond.Partner)
			local have = State.Cards[bond.Partner] ~= nil
			line(
				`🤝 <b>{if partner then partner.Name else bond.Partner}</b> · {badge(string.upper(bond.Bond.Name), Color3.fromRGB(255, 190, 120))}{if have
					then ""
					else " <font color=\"#8A94AC\">(not found)</font>"}`,
				Theme.Font.Bold,
				Theme.Color.Text,
				13
			)
		end
	end
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
		local screen = (gui :: ScreenGui).AbsoluteSize
		local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
		local height = frame.AbsoluteSize.Y
		local x = pos.X + size.X + 10
		if x + WIDTH > screen.X - 8 then
			x = pos.X - WIDTH - 10
		end
		x = math.clamp(x, 8, math.max(8, screen.X - WIDTH - 8))
		local y = math.clamp(pos.Y, 8, math.max(8, screen.Y - height - 8))
		frame.Position = UDim2.fromOffset(x, y)
	end
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
		if owner == button then
			CardTooltip.Close()
		end
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
		if not inside then
			CardTooltip.Close()
		end
	end)
end

return CardTooltip
