--!nonstrict
-- A card's abilities, written so a player can read them at a glance: one row per ability with a
-- coloured slot badge (BASIC, SKILL, ULTIMATE ...), when it fires ("every 3rd turn"), the name in big
-- letters and the effect with its numbers picked out in gold. Used by the Index detail, the card
-- reveal and the battle info popup.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage").Shared
local CardInfo = require(Shared.CardInfo)
local Deck = require(Shared.Deck)
local Awaken = require(Shared.Awaken)
local State = require(script.Parent.Parent.State)

local Abilities = {}

-- How each slot looks and when it fires, in plain words.
Abilities.Slots = {
	Basic = { Label = "BASIC", Color = Color3.fromRGB(170, 176, 196), When = "" },
	Skill = { Label = "SKILL", Color = Color3.fromRGB(80, 170, 255), When = "Every %d turns" },
	Passive = { Label = "PASSIVE", Color = Color3.fromRGB(86, 214, 138), When = "" },
	Ultimate = { Label = "ULTIMATE", Color = Color3.fromRGB(255, 196, 46), When = "" },
	Aura = { Label = "AURA", Color = Color3.fromRGB(200, 110, 255), When = "" },
	Signature = { Label = "SIGNATURE", Color = Color3.fromRGB(255, 110, 150), When = "" },
}

-- "Every 3 actions: 3 hits x 80% ATK" -> "3 hits × <gold>80%</gold> ATK" (the timing moves to the chip).
function Abilities.Describe(ability, card, stars, border, awaken): string
	return CardInfo.Highlight(if card then CardInfo.Describe(card, ability, stars or 0, border, awaken) else ability.Text)
end

function Abilities.When(ability, _card): string
	return if ability.Slot == "Skill" then string.format(Abilities.Slots.Skill.When, ability.Every or 3) else ""
end

function Abilities.Badges(ability, card, parent: Instance, order: number, z: number?)
	local badges = if card then CardInfo.Badges(card, ability) else {}
	if #badges == 0 then return end
	local level = z or 24
	local row = Kit.new("Frame", { Name = "AbilityBadges", LayoutOrder = order, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = level, Parent = parent }, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Wraps = true, Padding = UDim.new(0, 6) }),
	})
	for i, label in badges do
		local pill = Kit.new("Frame", { Name = "LimitPill", LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(205, 211, 213),
			Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, ZIndex = level + 1, Parent = row }, {
			Kit.corner(UDim.new(0.5, 0)), Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 23), PaddingRight = UDim.new(0, 9) }),
		})
		-- Draw the check so it renders consistently in Roblox fonts.
		for _, part in { { -16, 12, 5, 45 }, { -12, 10, 9, -45 } } do
			Kit.new("Frame", { Name = "Check", Position = UDim2.fromOffset(part[1], part[2]), Size = UDim2.fromOffset(part[3], 2), Rotation = part[4], BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(28, 48, 36), ZIndex = level + 2, Parent = pill })
		end
		Kit.new("TextLabel", { Text = label, TextSize = 13, Font = Theme.Font.Medium, TextColor3 = Color3.fromRGB(21, 27, 32), BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = level + 2, Parent = pill })
	end
end

-- One ability row. `size` = "big" (detail screens) or "small" (battle popup).
function Abilities.Row(ability, parent: Instance, order: number, size: string?, card, stars, border, awaken): Frame
	local big = size ~= "small"
	local slot = Abilities.Slots[ability.Slot] or Abilities.Slots.Basic
	local row = Kit.new("Frame", {
		Name = ability.Slot,
		LayoutOrder = order,
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(10, 12, 17),
		ZIndex = 22,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0, 12)),
		Kit.stroke(slot.Color, 1, 0.55),
		Kit.new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 9),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	-- Head: slot badge + when it fires.
	local head = Kit.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, if big then 24 else 20),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Parent = row,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local badge = Kit.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = slot.Color,
		ZIndex = 24,
		Parent = head,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
	})
	Kit.new("TextLabel", {
		Text = slot.Label,
		Font = Theme.Font.Heavy,
		TextSize = if big then 15 else 14,
		TextColor3 = Theme.Color.Text,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 25,
		Parent = badge,
	})
	Kit.new("TextLabel", {
		LayoutOrder = 2,
		Text = CardInfo.Highlight(Abilities.When(ability, card)),
		RichText = true,
		Font = Theme.Font.Bold,
		TextSize = if big then 15 else 14,
		TextColor3 = slot.Color:Lerp(Color3.new(1, 1, 1), 0.45),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 24,
		Parent = head,
	})
	local name = Kit.new("TextLabel", {
		LayoutOrder = 2,
		Text = ability.Name,
		Font = Theme.Font.Display,
		TextSize = if big then 24 else 21,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if big then 26 else 23),
		ZIndex = 24,
		Parent = row,
	})
	Kit.textStroke(Color3.fromRGB(8, 10, 15), 2, 0).Parent = name
	Kit.new("TextLabel", {
		LayoutOrder = 3,
		Text = Abilities.Describe(ability, card, stars, border, awaken),
		RichText = true,
		Font = Theme.Font.Medium,
		TextSize = if big then 18 else 16,
		TextColor3 = Color3.fromRGB(221, 233, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 24,
		Parent = row,
	})
	Abilities.Badges(ability, card, row, 4)
	return row
end

-- Every ability of a card, in slot order, into a list frame (it needs a UIListLayout).
function Abilities.List(card, parent: Instance, firstOrder: number, size: string?, border: string?): number
	local order = firstOrder
	local own = State.Cards[card.Id]
	for _, ability in card.Abilities do
		order += 1
		Abilities.Row(ability, parent, order, size, card, if own then own.Stars else 0,
			border or (if own then Deck.PlayBorder(own) else "Normal"), if own then Awaken.Level(own) else 0)
	end
	return order
end

return Abilities
