--!nonstrict
-- Live odds with the player's current luck (pure luck: there is no pity): the border odds (the tiers), each
-- card's pull chance, the foil odds and every trait's odds. Uses the same Odds / Borders / Traits modules as the server, so the numbers always match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity) -- trait tier colours
local Cards = require(Shared.Cards)
local Odds = require(Shared.Odds)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local Foils = require(Shared.Foils)
local RollBoost = require(Shared.RollBoost)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local OddsPanel = {}

local modal
local borderRows = {} -- [border id] = { Chance, OneIn }
local cardRows = {} -- [card id] = { Chance, OneIn }
local surgeRows = {} -- [border id] = { Chance = standard surge, OneIn = perfect surge }
local surgeTitle: TextLabel
local borderTitle: TextLabel
local luckLabel: TextLabel
local function refresh()
	local luck = State.Luck()
	local boost = Meta.Bonus(State.Meta.Stats, State.Meta.Gear, "Border")
	local chances = Odds.Chances(luck, boost)
	for id, row in borderRows do
		row.Chance.Text = Odds.FormatPercent(chances[id])
		row.OneIn.Text = Odds.FormatOneIn(chances[id])
	end
	luckLabel.Text = string.format("Luck %.2fx   ·   every roll is pure luck", luck)
	borderTitle.Text = if boost > 0
		then `BORDERS (the tiers)  <font color="#FF78DC">(+{math.floor(boost * 100 + 0.5)}% Border Chance)</font>`
		else "BORDERS (the tiers)"
	-- Overcharge Surge: the same table with the surge's border multiplier (it multiplies the Border Chance
	-- boost exactly as RollService does).
	local cfg = RollBoost.Surge
	local standard = Odds.Chances(luck, (1 + boost) * cfg.BorderMult - 1)
	local perfect = Odds.Chances(luck, (1 + boost) * cfg.PerfectBorderMult - 1)
	for id, row in surgeRows do
		row.Chance.Text = `{Odds.FormatPercent(standard[id])}`
		row.OneIn.Text = `{Odds.FormatPercent(perfect[id])}`
	end
	local untilSurge = RollBoost.UntilSurge(State.Summary.TotalRolls or 0)
	surgeTitle.Text = `OVERCHARGE SURGE  <font color="#FFC42E">(every {cfg.Every}th roll · next in {untilSurge})</font>`
	-- Which card a pull gives (any border): its pull weight among the cards unlocked so far.
	local pull = Cards.PullChances(Cards.Pool(State.Progress.Cleared))
	for id, row in cardRows do
		local chance = pull[id]
		row.Chance.Text = if chance then Odds.FormatPercent(chance * 100) else "🔒"
		row.OneIn.Text = if chance then Odds.FormatOneIn(chance * 100) else "beat its boss on Normal"
	end
end

local function oddsRow(parent: Instance, name: string, order: number, height: number)
	local row = Kit.new("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Color.PanelLight,
		Parent = parent,
	}, { Kit.corner(UDim.new(0, 10)) })
	local chance = Kit.label({
		Name = "Chance",
		Text = "",
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.new(0.22, 0, 0.6, 0),
		Parent = row,
	}, 17)
	local oneIn = Kit.label({
		Name = "OneIn",
		Text = "",
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.72, 0, 0.2, 0),
		Size = UDim2.new(0.28, -6, 0.6, 0),
		Parent = row,
	}, 15)
	return row, { Chance = chance, OneIn = oneIn }
end

local function heading(parent: Instance, text: string, order: number): TextLabel
	return Kit.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		Text = text,
		RichText = true,
		Parent = parent,
	}, 22)
end

function OddsPanel.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "OddsGui", "ODDS", Vector2.new(0.6, 0.86), Vector2.new(620, 640))

	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	luckLabel = Kit.label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Quick,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 17,
		Text = "",
		Parent = scroll,
	}, 17)

	-- Borders: the tiers, rolled on every pull at the player's luck (Border Chance raises them too).
	borderTitle = heading(scroll, "BORDERS (the tiers)", 1)
	for i = #Borders.List, 1, -1 do
		local border = Borders.List[i]
		local row, labels = oddsRow(scroll, "Border" .. border.Id, 2 + (#Borders.List - i), 36)
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = row,
		}, { Kit.corner(UDim.new(0.3, 0)), Kit.gradient(border.Gradient, 45) })
		Kit.label({
			Text = `{string.upper(border.Name)}  <font color="#A8A2C8">{border.Multiplier}x stats</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextColor3 = border.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 38, 0.2, 0),
			Size = UDim2.new(0.5, -38, 0.6, 0),
			Parent = row,
		}, 17)
		borderRows[border.Id] = labels
	end

	-- Overcharge Surge: every 25th roll multiplies the special border odds (no pity, still pure luck).
	surgeTitle = heading(scroll, "OVERCHARGE SURGE", 6)
	local cfg = RollBoost.Surge
	local columns, header = oddsRow(scroll, "SurgeColumns", 7, 26)
	columns.BackgroundTransparency = 1
	header.Chance.Text = `STANDARD {cfg.BorderMult}x`
	header.OneIn.Text = `PERFECT {cfg.PerfectBorderMult}x · {cfg.PerfectCards} cards`
	for i = #Borders.List, 1, -1 do
		local border = Borders.List[i]
		local row, labels = oddsRow(scroll, "Surge" .. border.Id, 8 + (#Borders.List - i), 32)
		Kit.label({
			Text = string.upper(border.Name),
			Font = Theme.Font.Heavy,
			TextColor3 = border.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0.2, 0),
			Size = UDim2.new(0.5, -12, 0.6, 0),
			Parent = row,
		}, 16)
		labels.OneIn.TextColor3 = Color3.fromRGB(255, 196, 46)
		surgeRows[border.Id] = labels
	end
	Kit.label({
		LayoutOrder = 12,
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 13,
		Text = `A standard surge (Auto Roll, or a late tap) rolls 1 card at {cfg.BorderMult}x border odds. A perfect tap inside the `
			.. `{cfg.PerfectWindow}s window after the cooldown rolls {cfg.PerfectCards} cards, each at {cfg.PerfectBorderMult}x. Base takes the rest.`,
		Parent = scroll,
	}, 13)

	-- Cards: which card a pull gives, by pull weight (boss cards join after their boss's first Normal clear).
	heading(scroll, "CARDS (per pull, any border)", 20)
	for i, card in Cards.List do
		local row, labels = oddsRow(scroll, "Card" .. card.Id, 20 + i, 30)
		Kit.label({
			Text = `{card.Name}  <font color="#A8A2C8">{card.Type}{if card.Boss then " · boss card" else ""}</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0.2, 0),
			Size = UDim2.new(0.5, -10, 0.6, 0),
			Parent = row,
		}, 15)
		cardRows[card.Id] = labels
	end

	-- Foils: rolled on every pull, on their own (Foils.luau); a card wears its best.
	Kit.label({
		LayoutOrder = 300,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		Text = "FOILS (every pull)",
		Parent = scroll,
	}, 22)
	local foilChances = Foils.Chances()
	for i, foil in Foils.List do
		local row = Kit.new("Frame", {
			Name = "Foil" .. foil.Id,
			LayoutOrder = 301 + (#Foils.List - i),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroll,
		}, { Kit.corner(UDim.new(0, 10)) })
		Kit.label({
			Text = `{foil.Icon} {string.upper(foil.Name)}  <font color="#A8A2C8">{foil.Text}</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextColor3 = foil.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0.2, 0),
			Size = UDim2.new(0.7, -10, 0.6, 0),
			Parent = row,
		}, 16)
		Kit.label({
			Text = `{Odds.FormatPercent(foilChances[foil.Id] * 100)}  ·  {Odds.FormatOneIn(foilChances[foil.Id] * 100)}`,
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, 0, 0.2, 0),
			Size = UDim2.new(0.3, -8, 0.6, 0),
			Parent = row,
		}, 15)
	end

	-- Traits: rolled at the Trait Master for Trait Shards (Traits.luau), not on pulls.
	Kit.label({
		LayoutOrder = 400,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		Text = "TRAITS (per Trait Master roll)",
		Parent = scroll,
	}, 22)
	local traitChances = Traits.Chances()
	for i = #Traits.List, 1, -1 do
		local trait = Traits.List[i]
		local tier = Rarity.Get(trait.Tier)
		local row = Kit.new("Frame", {
			Name = "Trait" .. trait.Id,
			LayoutOrder = 401 + (#Traits.List - i),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroll,
		}, { Kit.corner(UDim.new(0, 10)) })
		Kit.label({
			Text = `{trait.Icon} {string.upper(trait.Name)}  <font color="#A8A2C8">{Traits.Text(trait.Id)}</font>`,
			RichText = true,
			Font = Theme.Font.Heavy,
			TextColor3 = tier.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0.2, 0),
			Size = UDim2.new(0.7, -10, 0.6, 0),
			Parent = row,
		}, 16)
		Kit.label({
			Text = `{Odds.FormatPercent(traitChances[trait.Id] * 100)}  ·  {Odds.FormatOneIn(traitChances[trait.Id] * 100)}`,
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, 0, 0.2, 0),
			Size = UDim2.new(0.3, -8, 0.6, 0),
			Parent = row,
		}, 15)
	end

	Kit.label({
		LayoutOrder = 600,
		Size = UDim2.new(1, 0, 0, 72),
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 14,
		Text = "Rolls are free and pure luck (no pity). Every pull picks a card by its pull weight, then rolls its border (the tier: "
			.. `Base 1x / Gold 4x / Rainbow 16x / Secret 64x stats). Luck raises the rarer borders most, up to {Config.Roll.LuckCap}x; Base `
			.. "always keeps at least half. An infused Mega Pack weighs its element x1.5. Every pull also rolls a foil on its own; a card "
			.. "keeps the best of each. Every 25th roll is an Overcharge Surge (10x border odds; 3 cards at 12x when hit perfectly). 100 copies "
			.. "at one border fuse into 1 at the next (Hoshi). Traits are rolled at the Trait Master. Probabilities are rounded, so the "
			.. "displayed values may not add up to exactly 100%.",
		Parent = scroll,
	}, 14)

	modal.OnOpen = refresh
	State.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function OddsPanel.Toggle()
	modal:Toggle()
end

return OddsPanel
