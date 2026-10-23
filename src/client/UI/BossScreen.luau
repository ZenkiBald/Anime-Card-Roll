--!nonstrict
-- Boss screen: pick a world and difficulty, see the boss in 3D, compare Deck Power with the
-- recommended power, preview the rewards, switch deck presets, then fight.
-- Opened from the BATTLE button or by challenging a boss in the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Rarity = require(Shared.Rarity)
local Rewards = require(Shared.Rewards)
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Skin = require(script.Parent.Skin)
local ModelView = require(script.Parent.ModelView)
local State = require(script.Parent.Parent.State)

local BossScreen = {}

export type Actions = {
	EditDeck: () -> (),
	Fight: (bossId: string, difficulty: string) -> (boolean, string?),
}

local actions: Actions
local modal
local bossId = Bosses.List[1].Id
local difficulty = "Normal"
local showcase: Frame -- left: the boss in 3D
local showcaseGradient: UIGradient
local showcaseName: TextLabel
local showcaseTitle: TextLabel
local showcaseWorld: TextLabel
local view = nil -- ModelView
local viewBoss = nil
local body: ScrollingFrame -- right: details
local tabs: Frame
local hintLabel: TextLabel
local hintToken = 0

local function cleared(): { [string]: boolean }
	return State.Progress.Cleared or {}
end

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.5, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function pill(parent: Instance, text: string, order: number, width: number, color: Color3, on: boolean, locked: boolean): TextButton
	local button = Kit.new("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, width, 1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = if on then color else Theme.Color.PanelLight,
		BackgroundTransparency = if locked then 0.55 else 0,
		Text = "",
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	if on then
		Skin.Apply(button, Skin.ButtonFor(color)) -- the picked one gets the glossy kit art
	else
		Kit.stroke(Color3.fromRGB(150, 120, 230), 2, 0.4).Parent = button
	end
	local label = Kit.label({
		Text = text,
		Font = if on then Theme.Font.Display else Theme.Font.Heavy,
		TextTransparency = if locked then 0.45 else 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.62),
		Parent = button,
	}, 17)
	if on then
		Kit.textStroke(Color3.fromRGB(30, 10, 70), 1.5, 0.1).Parent = label
	end
	Kit.pressable(button)
	return button
end

local function row(order: number, height: number): Frame
	return Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			Wraps = true,
		}),
	})
end

local function text(parent: Instance, order: number, value: string, color: Color3, size: number, font: Enum.Font?): TextLabel
	return Kit.label({
		LayoutOrder = order,
		Text = value,
		RichText = true,
		Font = font or Theme.Font.Bold,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = size,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
		Parent = parent,
	}, size)
end

local function box(order: number, color: Color3): Frame
	return Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.PanelLight,
		BackgroundTransparency = 0.25,
		Parent = body,
	}, {
		Kit.corner(UDim.new(0, 12)),
		Kit.stroke(color, 1.5, 0.5),
		Kit.padding(10),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
end

local refresh

local function setShowcase(boss)
	showcaseGradient.Color = ColorSequence.new(boss.Accent:Lerp(Color3.new(0, 0, 0), 0.25), boss.Deep)
	showcaseName.Text = string.upper(boss.Name)
	showcaseTitle.Text = boss.Title
	showcaseWorld.Text = `WORLD {boss.World} · {string.upper(boss.WorldName)}`
	if viewBoss ~= boss.Id then
		if view then
			view.Frame:Destroy()
		end
		view = ModelView.new(boss.Id, {
			Name = "Boss",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.8),
			ZIndex = 2,
			Parent = showcase,
		}, 0, 5)
		viewBoss = boss.Id
	end
	local locked = not Bosses.IsUnlocked(cleared(), boss.Id, "Normal")
	view:SetTint(if locked then Color3.fromRGB(60, 56, 80) else Color3.new(1, 1, 1))
end

local function buildTabs()
	for _, child in tabs:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, other in Bosses.List do
		local open = Bosses.IsUnlocked(cleared(), other.Id, "Normal")
		local button = pill(tabs, if open then `WORLD {other.World}` else `WORLD {other.World} · LOCKED`, i, if open then 92 else 150, other.Accent, other.Id == bossId, not open)
		button.Activated:Connect(function()
			bossId = other.Id
			difficulty = "Normal"
			refresh()
		end)
	end
end

local function build()
	hintLabel.Parent = nil -- reused across rebuilds
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local boss = Bosses.Get(bossId)
	local fight = boss.Difficulties[difficulty]
	local key = Bosses.FightKey(boss.Id, difficulty)
	local unlocked = Bosses.IsUnlocked(cleared(), boss.Id, difficulty)
	local deck = State.ActiveDeck() or Deck.Empty()
	local power = Deck.Power(deck, State.Cards)
	setShowcase(boss)
	buildTabs()

	text(body, 1, boss.Mechanic, Theme.Color.Muted, 18, Theme.Font.Bold)

	-- Difficulty: cleared ones get a tick, locked ones say what opens them.
	local diffRow = row(2, 38)
	for i, name in Bosses.DifficultyOrder do
		local open = Bosses.IsUnlocked(cleared(), boss.Id, name)
		local done = cleared()[Bosses.FightKey(boss.Id, name)] == true
		local color = if i == 3 then Theme.Color.Danger elseif i == 2 then Theme.Color.Roll else Theme.Color.Quick
		local label = string.upper(name) .. (if done then "  ✓" else "")
		local button = pill(diffRow, label, i, 118, color, name == difficulty, not open)
		button.Activated:Connect(function()
			difficulty = name
			refresh()
		end)
	end
	if not unlocked then
		text(body, 3, `LOCKED · {Bosses.UnlockHint(boss.Id, difficulty)} to open this fight.`, Theme.Color.Roll, 15, Theme.Font.Heavy)
	end

	-- Power check with a bar against the recommended power.
	local enough = power >= fight.Recommended
	local powerBox = box(4, if enough then Theme.Color.Quick else Theme.Color.Roll)
	text(
		powerBox,
		1,
		`Recommended <b>{Kit.commas(fight.Recommended)}</b>   ·   Your deck <font color="{if enough then "#56D68A" else "#FF7846"}"><b>{Kit.commas(power)}</b></font>`,
		Theme.Color.Text,
		21,
		Theme.Font.Heavy
	)
	local track = Kit.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Theme.Color.Backdrop,
		Parent = powerBox,
	}, { Kit.corner(UDim.new(1, 0)) })
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = if enough then Theme.Color.Quick else Theme.Color.Roll,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	Kit.tween(fill, 0.5, { Size = UDim2.fromScale(math.clamp(power / (fight.Recommended * 1.5), 0.02, 1), 1) }, Enum.EasingStyle.Quad)
	Kit.new("Frame", {
		Position = UDim2.fromScale(1 / 1.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	if not enough then
		text(powerBox, 3, "Below the recommended power: roll for more cards, or try anyway!", Theme.Color.Roll, 16, Theme.Font.Bold)
	end

	-- Rewards preview.
	local reward = Rewards.For(fight.D)
	local floor = Rarity.Get(reward.Floor)
	local bonus = Rarity.Get(reward.Bonus)
	local rewardBox = box(5, Theme.Color.Gold)
	text(rewardBox, 1, "WIN REWARDS", Theme.Color.Gold, 20, Theme.Font.Heavy)
	text(
		rewardBox,
		2,
		`<b>{reward.Rolls}</b> reward rolls  ·  <b>{string.format("%.2f", reward.Luck)}x</b> luck  ·  every card <font color="#{floor.Color:ToHex()}"><b>{reward.Floor}</b></font> or better`,
		Theme.Color.Text,
		18
	)
	local dropPotion = Meta.PotionById[reward.Potion]
	text(
		rewardBox,
		3,
		`+💎{reward.Shards} Shards  ·  {math.floor(Config.Rewards.PotionChance * 100)}% chance of a {dropPotion.Icon} {dropPotion.Name}`,
		Theme.Color.Text,
		17,
		Theme.Font.Bold
	)
	-- Gear odds for this fight (Items.luau: harder fights drop more often, and rarer gear).
	local rarityChances = Items.RarityChances(fight.D)
	local rarest = if (rarityChances.Mythic or 0) > 0 then "Mythic" else "Legendary"
	text(
		rewardBox,
		4,
		`🎒 Accessory <b>{math.floor(Items.AccessoryChance(fight.D) * 100 + 0.5)}%</b>  ·  Artifact <b>{string.format(
			"%.1f",
			Items.ArtifactChance(fight.D) * 100
		)}%</b>  ·  <font color="#{Rarity.Get(rarest).Color:ToHex()}">{rarest}</font> gear {string.format("%.1f", rarityChances[rarest] * 100)}%`,
		Color3.fromRGB(255, 170, 230),
		17,
		Theme.Font.Bold
	)
	local best = State.Progress.BestTime and State.Progress.BestTime[key]
	if cleared()[key] then
		local bestText = if best then string.format("Best time %d:%04.1f", best // 60, best % 60) else "Cleared"
		text(rewardBox, 5, `✓ {bestText}`, Theme.Color.Quick, 17, Theme.Font.Heavy)
	else
		text(
			rewardBox,
			5,
			`FIRST CLEAR BONUS: +1 <font color="#{bonus.Color:ToHex()}"><b>{reward.Bonus}</b></font> or better card`,
			Theme.Color.Text,
			17,
			Theme.Font.Heavy
		)
	end

	-- Deck presets + a peek at the active deck.
	local presetRow = row(6, 36)
	for i = 1, Config.Deck.Presets do
		local preset = State.Decks.Presets[i] or Deck.Empty()
		local button = pill(presetRow, `DECK {i} · {Kit.commas(Deck.Power(preset, State.Cards))}`, i, 136, Theme.Color.Accent, i == State.Decks.Active, false)
		button.Activated:Connect(function()
			if i == State.Decks.Active then
				return
			end
			local ok, result = pcall(function()
				return Remotes.Deck:InvokeServer("Select", i)
			end)
			if ok and result and result.Decks then
				State.ApplyDecks(result.Decks)
			end
		end)
	end

	local peek = row(7, 52)
	local order = 0
	for _, deckRow in Deck.Rows do
		for _, id in deck[deckRow] do
			order += 1
			local card = if id ~= "" then Cards.Get(id) else nil
			local chip = Kit.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.fromOffset(50, 50),
				BackgroundColor3 = if card then card.Accent else Theme.Color.PanelLight,
				BackgroundTransparency = if card then 0 else 0.5,
				Parent = peek,
			}, { Kit.corner(UDim.new(0.25, 0)) })
			if card then
				Kit.stroke(Rarity.Get(card.Rarity).Color, 2, 0).Parent = chip
			end
			Kit.label({
				Text = if card then card.Glyph else "-",
				Font = Theme.Font.Display,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.6),
				Parent = chip,
			}, 22)
		end
		if deckRow == "Attack" then
			order += 1
			Kit.new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(12, 50), BackgroundTransparency = 1, Parent = peek })
		end
	end

	-- Buttons
	local buttons = row(8, 60)
	local edit = Kit.button("EDIT DECK", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 1,
		Size = UDim2.new(0, 170, 1, 0),
		Parent = buttons,
	})
	edit.Activated:Connect(function()
		actions.EditDeck()
	end)
	local fightButton = Kit.button(if unlocked then "FIGHT!" else "LOCKED", Theme.Color.Roll, Theme.Color.RollDeep, {
		LayoutOrder = 2,
		Size = UDim2.new(0, 220, 1, 0),
		Parent = buttons,
	})
	Kit.dim(fightButton, not unlocked)
	fightButton.Activated:Connect(function()
		if not unlocked then
			hint(`{Bosses.UnlockHint(boss.Id, difficulty)} first`)
			return
		end
		if Deck.Count(deck, "Attack") == 0 then
			hint("Put at least one Attack card in your deck first")
			return
		end
		local ok, message = actions.Fight(bossId, difficulty)
		if ok then
			modal:Close()
		elseif message then
			hint(message)
		end
	end)
	hintLabel.Parent = body -- its own row: inside the wrapping button row it pushed the buttons up
end

function refresh()
	if modal.IsOpen then
		build()
	end
end

function BossScreen.Init(playerGui: Instance, bossActions: Actions)
	actions = bossActions
	modal = Modal.new(playerGui, "BossGui", "BATTLE", Vector2.new(0.9, 0.86), Vector2.new(1040, 660))

	tabs = Kit.new("Frame", {
		Name = "Worlds",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -58, 0, 8),
		Size = UDim2.new(0.62, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = modal.Header,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	showcase = Kit.new("Frame", {
		Name = "Showcase",
		Size = UDim2.new(0.38, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 16)) })
	showcaseGradient = Kit.gradient(ColorSequence.new(Color3.fromRGB(80, 40, 30), Color3.fromRGB(20, 12, 20)), 90)
	showcaseGradient.Parent = showcase
	Kit.new("Frame", {
		Name = "Floor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.8, 0.08),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = showcase,
	}, { Kit.corner(UDim.new(1, 0)) })
	showcaseWorld = Kit.label({
		Name = "World",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(230, 226, 255),
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(1, -24, 0, 18),
		ZIndex = 3,
		Parent = showcase,
	}, 16)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = showcaseWorld
	showcaseName = Kit.label({
		Name = "Name",
		Text = "",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.new(1, -20, 0.1, 0),
		ZIndex = 3,
		Parent = showcase,
	}, 34)
	Kit.textStroke(Color3.new(0, 0, 0), 2, 0.2).Parent = showcaseName
	showcaseTitle = Kit.label({
		Name = "Title",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(216, 210, 240),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 18),
		ZIndex = 3,
		Parent = showcase,
	}, 17)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = showcaseTitle

	body = Kit.new("ScrollingFrame", {
		Name = "Details",
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.fromScale(0.6, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) }),
	})
	hintLabel = Kit.label({
		Name = "Hint",
		LayoutOrder = 9,
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}, 20)
	Kit.textStroke(Color3.fromRGB(30, 10, 70), 1.5, 0).Parent = hintLabel

	modal.OnOpen = build
	State.Changed:Connect(function(kind)
		if kind ~= "roll" then
			refresh()
		end
	end)
end

function BossScreen.Toggle()
	modal:Toggle()
end

function BossScreen.Open(id: string?)
	if id and Bosses.Get(id) then
		if id ~= bossId then
			difficulty = "Normal"
		end
		bossId = id
	end
	modal:Open()
end

return BossScreen
