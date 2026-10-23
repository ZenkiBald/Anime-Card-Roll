--!nonstrict
-- Card hover zoom + ability flyout, for the DECK formation plates and the CARD VAULT tiles.
--   PC: the card scales to 1.15 (0.15 s quad) and rises to ZIndex 50 on MouseEnter; after 0.25 s of
--   hovering, the flyout opens beside it. MouseLeave closes it and puts the card back.
--   Touch: a long press (or a tap) opens the flyout; a tap anywhere else closes it.
-- Flyout (280 px obsidian, 1.2 px border in the element's colour): name, title, element badge, role badge,
-- border tier ("Gold Border · 4x"); then the Basic (name, target, formula), the Skill (name, cooldown,
-- stagger, effect), the Ultimate (bold italic name, energy cost, text) and the card's bond links.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Elements = require(Shared.Elements)
local Config = require(Shared.Config)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Abilities = require(script.Parent.Abilities)
local State = require(script.Parent.Parent.State)

local CardTooltip = {}

local WIDTH = 280
local HOVER_SCALE = 1.15
local HOVER_DELAY = 0.25
local LONG_PRESS = 0.35
local ROLE_COLORS = {
	Striker = Color3.fromRGB(255, 90, 90),
	Hexer = Color3.fromRGB(190, 110, 255),
	Mender = Color3.fromRGB(90, 230, 150),
	Warder = Color3.fromRGB(90, 170, 255),
}
local TARGETS = {
	Enemies = "all enemies",
	RandomEnemy = "random enemies",
	Self = "itself",
	Lowest = "the lowest-HP ally",
	Attack = "every Attack card",
	All = "the whole squad",
	Random = "a random ally",
}

local gui: ScreenGui? = nil
local flyout: Frame? = nil
local owner: GuiObject? = nil -- the card the open flyout belongs to

-- A card's battle role, read from what its abilities do: heals = Mender, shields / taunts / guard = Warder,
-- burns / debuffs = Hexer, else Striker.
function CardTooltip.Role(card): string
	local has = {}
	for _, ability in card.Abilities do
		for _, effect in ability.Effects do
			has[effect.Kind] = true
			if effect.Kind == "Buff" and effect.Stat == "Guard" then
				has.Guard = true
			end
		end
	end
	if has.Heal or has.Revive then
		return "Mender"
	elseif has.Shield or has.Taunt or has.Guard or has.Evade then
		return "Warder"
	elseif has.Burn or has.Debuff then
		return "Hexer"
	end
	return "Striker"
end

local function targetText(ability): string
	for _, effect in ability.Effects do
		if effect.Kind == "Damage" or effect.Kind == "Burn" or effect.Kind == "Debuff" then
			return TARGETS[effect.Target] or "the focus target"
		elseif TARGETS[effect.Target] then
			return TARGETS[effect.Target]
		end
	end
	return "the focus target"
end

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
	local edge = if element then element.Color else Theme.Color.Line
	local tier = Borders.Get(border)
	local role = CardTooltip.Role(card)
	local frame = Kit.new("Frame", {
		Name = "CardTooltip",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.05,
		ZIndex = 50,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(0, 5)),
		Kit.stroke(edge, 1.2, 0),
		Kit.padding(10),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
	})
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
			BackgroundColor3 = Theme.Color.Line,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 51,
			Parent = frame,
		})
	end

	-- Header.
	line(string.upper(card.Name), Theme.Font.Display, Theme.Color.Text, 20)
	line(card.Title or "", Theme.Font.Bold, Theme.Color.Muted, 13)
	line(
		`{if element then badge(`{element.Icon} {string.upper(element.Name)}`, element.Color) .. "   " else ""}{badge(
			`◆ {string.upper(role)}`,
			ROLE_COLORS[role]
		)}   {badge(Borders.Label(border), tier.Color)}`,
		Theme.Font.Heavy,
		Theme.Color.Text,
		13
	)

	-- Abilities: Basic, Skill, Ultimate (passives / auras / signatures follow in plain rows).
	local basic, skill, ult = Cards.Ability(card, "Basic"), Cards.Ability(card, "Skill"), Cards.Ability(card, "Ultimate")
	if basic then
		rule()
		line(`{badge("BASIC", Abilities.Slots.Basic.Color)}  <b>{basic.Name}</b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`Target: {targetText(basic)}\n{Abilities.Describe(basic)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	if skill then
		rule()
		line(`{badge("SKILL", Abilities.Slots.Skill.Color)}  <b>{skill.Name}</b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`CD: every {skill.Every or 3} actions  ·  {staggerText(skill)}\n{Abilities.Describe(skill)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	if ult then
		rule()
		line(`{badge("ULTIMATE", Abilities.Slots.Ultimate.Color)}  <b><i>{ult.Name}</i></b>`, Theme.Font.Heavy, Theme.Color.Text, 15)
		line(`⚡ {Config.Battle.UltimateCost} energy\n{Abilities.Describe(ult)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
	end
	for _, ability in card.Abilities do
		if ability.Slot ~= "Basic" and ability.Slot ~= "Skill" and ability.Slot ~= "Ultimate" then
			local slot = Abilities.Slots[ability.Slot] or Abilities.Slots.Basic
			rule()
			line(`{badge(slot.Label, slot.Color)}  <b>{ability.Name}</b>\n{Abilities.Describe(ability)}`, Theme.Font.Medium, Theme.Color.Muted, 13)
		end
	end
	if card.Link then
		line(`🔗 <b>{card.Link.Name}</b>: {card.Link.Text}`, Theme.Font.Medium, Theme.Color.Muted, 13)
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
