--!nonstrict
-- Boss screen: pick a world and difficulty, see the boss in 3D, compare Deck Power with the
-- recommended power, preview the rewards, switch deck presets, then fight.
-- The TOWER tab shows the next floor of the player's Infinite Tower run and the PAGODA tab the next
-- Hundred-Floor Pagoda floor (Tower.luau) the same way, with the day's
-- mutator; the RAID tab shows the server raid (Raid.luau): its countdown, the shared pool, the top hitters.
-- Every tab has a SCOUT box: the squad's elements, how the active deck lines up, its synergies and
-- bonds, and COUNTER-BUILD (Auto-build weighed against that squad, Deck.AutoBuild).
-- Opened from the BATTLE button, by challenging a boss in the hub, or at the tower gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Borders = require(Shared.Borders)
local Rewards = require(Shared.Rewards)
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Tower = require(Shared.Tower)
local Packs = require(Shared.Packs)
local Elements = require(Shared.Elements)
local Raid = require(Shared.Raid)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Skin = require(script.Parent.Skin)
local ModelView = require(script.Parent.ModelView)
local ElementUi = require(script.Parent.ElementUi)
local ElementGuide = require(script.Parent.ElementGuide)
local CardView = require(script.Parent.CardView)
local State = require(script.Parent.Parent.State)

local BossScreen = {}

export type Actions = {
	EditDeck: (target: string) -> (), -- target: the boss id, Tower.Id or Raid.Id the deck is for
	Fight: (bossId: string, difficulty: string?, options: { Cost: boolean? }?) -> (boolean, string?), -- bossId may be Tower.Id, Tower.PagodaId or Raid.Id
}

local actions: Actions
local modal
local bossId = Bosses.List[1].Id
local difficulty = "Normal"
local mode = "boss" -- "boss" | "tower" | "pagoda" | "raid"
local TOWER_COLOR = Color3.fromRGB(90, 230, 220)
local PAGODA_COLOR = Color3.fromRGB(255, 140, 90)
local RAID_COLOR = Color3.fromRGB(255, 80, 120)
local SCOUT_COLOR = Color3.fromRGB(150, 200, 255)
local costChallenge = false -- boss fights: the 30-point Cost Challenge (2x Trait Shards)
local raidLive: { [string]: any } = {} -- the RAID tab's live labels, updated every second without a rebuild
local tabsLive = false -- whether the tabs were drawn with the raid live
local raidShape = "" -- what the RAID tab was built for (window, open, cleared): a change rebuilds it
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
		Kit.stroke(Color3.fromRGB(90, 170, 220), 2, 0.4).Parent = button
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
		Kit.textStroke(Color3.fromRGB(13, 17, 27), 1.5, 0.1).Parent = label
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

-- `floor` (Tower.FloorAt) shows the boss as that tower floor's echo; `raidName` as the raid's Colossus.
local function setShowcase(boss, floor, raidName: string?)
	showcaseGradient.Color = ColorSequence.new(boss.Accent:Lerp(Color3.new(0, 0, 0), 0.25), boss.Deep)
	local affix = floor and floor.Affix and Tower.AffixById[floor.Affix]
	showcaseName.Text = string.upper(if raidName then raidName elseif floor then floor.Name else boss.Name)
	showcaseTitle.Text = if affix then `{affix.Icon} {affix.Name}: {affix.Text}` else `{Elements.Label(boss.Element)} · {boss.Title}`
	showcaseWorld.Text = if raidName
		then "SERVER RAID · EVERYONE TOGETHER"
		elseif floor then `{if floor.Mode == Tower.PagodaId then "HUNDRED-FLOOR PAGODA" else "INFINITE TOWER"} · FLOOR {floor.Floor}`
		else `WORLD {boss.World} · {string.upper(boss.WorldName)}`
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
	if raidName then
		view:SetTint(Color3.fromRGB(255, 150, 170)) -- a Colossus
		return
	end
	if floor then
		view:SetTint(if floor.Guardian then Color3.fromRGB(255, 226, 150) else Color3.fromRGB(170, 240, 255)) -- an echo
		return
	end
	local locked = not Bosses.IsUnlocked(cleared(), boss.Id, "Normal")
	view:SetTint(if locked then Color3.fromRGB(15, 19, 30) else Color3.new(1, 1, 1))
end

-- "GUARDS  🗡️ Ash Ashigaru · Striker   🔥 Ember Monk · Mender ..." for a squad's guard ids.
local function guardLine(ids: { string }): string
	local parts = {}
	for _, id in ids do
		local g = Bosses.GuardTypes[id]
		if g then
			local element = Elements.Get(g.Element)
			table.insert(parts, `{g.Icon} <font color="#{g.Color:ToHex()}"><b>{g.Name}</b></font> · {g.Role} {if element then element.Icon else ""}`)
		end
	end
	return "GUARDS   " .. table.concat(parts, "    ")
end

local function towerOpen(): boolean
	return not Config.Unlocks.Enabled or cleared()[Tower.UnlockAfter] == true
end

local function buildTabs()
	for _, child in tabs:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, other in Bosses.List do
		local open = Bosses.IsUnlocked(cleared(), other.Id, "Normal")
		local button = pill(tabs, if open then `WORLD {other.World}` else `WORLD {other.World} · LOCKED`, i, if open then 92 else 150, other.Accent, mode == "boss" and other.Id == bossId, not open)
		button.Activated:Connect(function()
			mode = "boss"
			bossId = other.Id
			difficulty = "Normal"
			refresh()
		end)
	end
	local towerButton = pill(tabs, "TOWER", #Bosses.List + 1, 92, TOWER_COLOR, mode == "tower", not towerOpen())
	towerButton.Activated:Connect(function()
		mode = "tower"
		refresh()
	end)
	local pagodaButton = pill(tabs, "PAGODA", #Bosses.List + 2, 100, PAGODA_COLOR, mode == "pagoda", not towerOpen())
	pagodaButton.Activated:Connect(function()
		mode = "pagoda"
		refresh()
	end)
	local live = State.Raid ~= nil and State.Raid.Open
	tabsLive = live
	local raidButton = pill(tabs, if live then "RAID · LIVE" else "RAID", #Bosses.List + 3, if live then 120 else 92, RAID_COLOR, mode == "raid", false)
	raidButton.Activated:Connect(function()
		mode = "raid"
		refresh()
	end)
end

-- SCOUT: the squad's elements and what beats them, how the active deck lines up against the leader,
-- the deck's synergies and bonds, and COUNTER-BUILD for this fight (`target`: boss id, Tower.Id, Raid.Id).
local function scoutBox(order: number, leaderId: string, guards: { string }, deck, target: string)
	local leader = Bosses.Get(leaderId)
	local scout = box(order, SCOUT_COLOR)
	text(scout, 1, "SCOUT", SCOUT_COLOR, 18, Theme.Font.Heavy)
	text(
		scout,
		2,
		`Leader {ElementUi.Rich(leader.Element)}   ·   beat it with <b>{ElementUi.RichList(Elements.Counters(leader.Element))}</b> (+30% damage)`,
		Theme.Color.Text,
		16,
		Theme.Font.Heavy
	)
	if #guards > 0 then
		local parts = {}
		for _, id in guards do
			local g = Bosses.GuardTypes[id]
			if g then
				table.insert(parts, `{g.Icon} {g.Role} {ElementUi.Rich(g.Element)}`)
			end
		end
		text(scout, 3, "Guards   " .. table.concat(parts, "    "), Theme.Color.Text, 15, Theme.Font.Bold)
	end

	local strong, weak, hurt, ids = 0, 0, 0, {}
	for _, deckRow in Deck.Rows do
		for _, id in deck[deckRow] do
			local card = Cards.Get(id)
			if card then
				table.insert(ids, id)
				local matchup = Elements.Matchup(card.Element, leader.Element)
				if matchup == "Strong" then
					strong += 1
				elseif matchup == "Weak" then
					weak += 1
				end
				if card.Type == "Attack" and Elements.Matchup(leader.Element, card.Element) == "Strong" then
					hurt += 1
				end
			end
		end
	end
	local deckLine = `Your deck vs the leader:  <font color="#56D68A"><b>{strong} strong</b></font>  ·  <font color="#FF7846"><b>{weak} weak</b></font>`
	if hurt > 0 then
		deckLine ..= `  ·  {hurt} Attack card{if hurt == 1 then "" else "s"} take +30% from it`
	end
	text(scout, 4, deckLine, Theme.Color.Text, 16, Theme.Font.Heavy)

	local synergies = Elements.ActiveSynergies(Deck.Elements(deck))
	local lines = {}
	for _, active in synergies do
		local element = Elements.Get(active.Synergy.Element)
		table.insert(lines, `{element and element.Icon or ""} <b>{string.upper(active.Synergy.Name)}</b> ({active.Count}): {active.Tier.Text}`)
	end
	for _, bond in Elements.ActiveBonds(ids) do
		table.insert(lines, `🤝 <b>{string.upper(bond.Name)}</b>: Dual Ultimate when the leader drops to half`)
	end
	if #lines == 0 then
		table.insert(lines, "No synergy yet: 2 cards of one element switch one on (4 for a bigger one)")
	end
	text(scout, 5, table.concat(lines, "\n"), Color3.fromRGB(255, 214, 150), 15, Theme.Font.Bold)

	local buttons = Kit.new("Frame", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = scout,
	}, {
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
	})
	local counter = Kit.button("COUNTER-BUILD", Color3.fromRGB(90, 160, 255), Color3.fromRGB(30, 60, 140), {
		LayoutOrder = 1,
		Size = UDim2.new(0, 220, 1, 0),
		Parent = buttons,
	})
	local guide = Kit.button("HOW ELEMENTS WORK", Theme.Color.PanelLight, Theme.Color.Panel, {
		LayoutOrder = 2,
		Size = UDim2.new(0, 220, 1, 0),
		Parent = buttons,
	})
	guide.Activated:Connect(ElementGuide.Open)
	counter.Activated:Connect(function()
		local ok, result = pcall(function()
			return Remotes.Deck:InvokeServer("AutoBuild", State.Decks.Active, target)
		end)
		if ok and result and result.Decks then
			State.ApplyDecks(result.Decks)
			hint("Deck rebuilt: your strongest cards, weighed by element against this squad")
		else
			hint("Couldn't rebuild the deck")
		end
	end)
end

-- Deck presets, a peek at the active deck, and EDIT DECK + FIGHT (rows from `order` on). `fight`
-- returns what actions.Fight does, or nothing when it refused by itself.
local function deckAndFight(order0: number, deck, unlocked: boolean, fight: () -> (boolean?, string?), label: string?, target: string)
	local presetRow = row(order0, 36)
	for i = 1, math.max(Config.Deck.Presets, #State.Decks.Presets) do
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

	local peek = row(order0 + 1, 52)
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
				local own = State.Cards[card.Id]
				CardView.Portrait(id, true).Parent = chip
				CardView.Bevel(chip, Borders.Best(own and own.Borders), 2)
			else
				Kit.label({
					Text = "-",
					Font = Theme.Font.Display,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.6),
					Parent = chip,
				}, 22)
			end
		end
		if deckRow == "Attack" then
			order += 1
			Kit.new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(12, 50), BackgroundTransparency = 1, Parent = peek })
		end
	end

	-- Buttons
	local buttons = row(order0 + 2, 60)
	local edit = Kit.button("EDIT DECK", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 1,
		Size = UDim2.new(0, 170, 1, 0),
		Parent = buttons,
	})
	edit.Activated:Connect(function()
		actions.EditDeck(target)
	end)
	local fightButton = Kit.button(if unlocked then label or "FIGHT!" else "LOCKED", Theme.Color.Roll, Theme.Color.RollDeep, {
		LayoutOrder = 2,
		Size = UDim2.new(0, 220, 1, 0),
		Parent = buttons,
	})
	Kit.dim(fightButton, not unlocked)
	fightButton.Activated:Connect(function()
		if unlocked and Deck.Count(deck, "Attack") == 0 then
			hint("Put at least one Attack card in your deck first")
			return
		end
		local ok, message = fight()
		if ok then
			modal:Close()
		elseif message then
			hint(message)
		end
	end)
end

-- The floor box shared by both towers: the enemy, its moves, guards, affix and the day's mutator.
local function floorBox(order: number, floor, color: Color3)
	local boss = Bosses.Get(floor.Boss)
	local foe = box(order, if floor.Guardian then Theme.Color.Gold else color)
	text(
		foe,
		1,
		`FLOOR {floor.Floor} · <b>{string.upper(floor.Name)}</b>` .. (if floor.Guardian then `  <font color="#FFC42E">GUARDIAN</font>` else ""),
		if floor.Guardian then Theme.Color.Gold else color,
		21,
		Theme.Font.Heavy
	)
	text(foe, 2, `{boss.Name}'s moves ({floor.Difficulty} set): {boss.Mechanic}`, Theme.Color.Text, 16, Theme.Font.Bold)
	text(foe, 4, guardLine(floor.Guards), Theme.Color.Text, 15, Theme.Font.Heavy)
	local affix = floor.Affix and Tower.AffixById[floor.Affix]
	if affix then
		text(foe, 3, `{affix.Icon} <b>{string.upper(affix.Name)}</b>: {affix.Text}`, Color3.fromRGB(255, 170, 230), 17, Theme.Font.Heavy)
	end
	local mutator = State.Mutator()
	local resetIn = 86400 - os.time() % 86400
	text(
		foe,
		5,
		`TODAY  {mutator.Icon} <b>{string.upper(mutator.Name)}</b>: {mutator.Text}  ·  next in {resetIn // 3600}h {(resetIn % 3600) // 60}m`,
		Color3.fromRGB(150, 255, 190),
		16,
		Theme.Font.Heavy
	)
end

local function powerBox(order: number, recommended: number, power: number)
	local enough = power >= recommended
	local panel = box(order, if enough then Theme.Color.Quick else Theme.Color.Roll)
	text(
		panel,
		1,
		`Recommended <b>{Kit.commas(recommended)}</b>   ·   Your deck <font color="{if enough then "#56D68A" else "#FF7846"}"><b>{Kit.commas(power)}</b></font>`,
		Theme.Color.Text,
		21,
		Theme.Font.Heavy
	)
end

local function rewardExtras(reward): string
	local extras = `+💎{Kit.commas(reward.Shards)} Shards  ·  +🧬{reward.TraitShards} Trait Shards`
	if reward.Potion then
		local potion = Meta.PotionById[reward.Potion]
		extras ..= `  ·  {potion.Icon} {potion.Name}`
	end
	return extras
end

-- The TOWER tab: the Infinite Tower run's next floor, its power check and what it pays. A loss ends the run.
local function buildTower()
	local tower = State.Tower
	local floorNo = tower.Run + 1
	local floor = Tower.FloorAt(floorNo)
	local boss = Bosses.Get(floor.Boss)
	local unlocked = towerOpen()
	local deck = State.ActiveDeck() or Deck.Empty()
	local power = Deck.Power(deck, State.Cards)
	setShowcase(boss, floor)
	buildTabs()

	text(
		body,
		0,
		"Climb as high as you can in one run: every win goes up a floor, every floor pays, and Roll Packs drop every 5th floor (a Big Roll Pack every 25th). Lose once, give up or leave mid-fight and the run starts again from floor 1.",
		Theme.Color.Muted,
		17,
		Theme.Font.Bold
	)
	local status = row(1, 36)
	text(
		status,
		1,
		`  THIS RUN  <b>FLOOR {floorNo}</b>     ·     BEST RUN  <b>FLOOR {tower.Best}</b>  `,
		TOWER_COLOR,
		19,
		Theme.Font.Heavy
	).Size = UDim2.new(1, 0, 0, 36)
	floorBox(2, floor, TOWER_COLOR)
	if not unlocked then
		text(body, 3, `LOCKED · {Tower.UnlockHint()} to open the tower.`, Theme.Color.Roll, 15, Theme.Font.Heavy)
	end
	scoutBox(3, floor.Boss, floor.Guards, deck, Tower.Id)
	powerBox(4, floor.Recommended, power)

	local record = floorNo > tower.Best
	local reward = Tower.Reward(floorNo, record)
	local rewardBox = box(5, Theme.Color.Gold)
	text(rewardBox, 1, if floor.Guardian and record then "GUARDIAN REWARDS · NEW RECORD" else "FLOOR REWARDS", Theme.Color.Gold, 20, Theme.Font.Heavy)
	if reward.Packs and next(reward.Packs) then
		text(rewardBox, 2, `<b>{Packs.Describe(reward.Packs)}</b>  (saved to your BAG, opened at your luck)`, Theme.Color.Gold, 18)
	else
		local packFloor = floorNo + 1
		while Packs.ForFloor(packFloor) == nil do
			packFloor += 1
		end
		text(rewardBox, 2, `No pack on this floor · next: <b>{Packs.Describe(Packs.ForFloor(packFloor))}</b> on floor {packFloor}`, Theme.Color.Text, 17)
	end
	text(rewardBox, 3, rewardExtras(reward), Theme.Color.Text, 17, Theme.Font.Bold)
	text(
		rewardBox,
		4,
		if reward.Relic > 0
			then `🔮 Relic drop <b>{string.format("%.1f", reward.Relic * 100)}%</b> (every win from floor {Items.RelicFloor})`
			else `🔮 Relics drop from floor {Items.RelicFloor} up (0.1% a win), only in the Infinite Tower`,
		Color3.fromRGB(255, 170, 230),
		17,
		Theme.Font.Bold
	)
	if floor.Guardian and not record then
		text(rewardBox, 5, `Guardian bonuses (x{Tower.GuardianShards} Shards, a sure potion) pay on floors past your best run (floor {tower.Best})`, Theme.Color.Muted, 15, Theme.Font.Bold)
	elseif not floor.Guardian then
		local guardian = Tower.NextGuardian(floorNo)
		text(
			rewardBox,
			5,
			if guardian > tower.Best
				then `Next Guardian: floor {guardian} · x{Tower.GuardianShards} Shards, a sure potion and 2 Roll Packs`
				else `Next Guardian: floor {guardian} · 2 Roll Packs (its bonuses pay past floor {tower.Best})`,
			Theme.Color.Gold,
			16,
			Theme.Font.Heavy
		)
	end

	deckAndFight(6, deck, unlocked, function()
		if not unlocked then
			hint(`{Tower.UnlockHint()} first`)
			return
		end
		return actions.Fight(Tower.Id, nil)
	end, if floorNo == 1 then "START RUN · FLOOR 1" else `CLIMB · FLOOR {floorNo}`, Tower.Id)
	hintLabel.Parent = body
end

-- The PAGODA tab: the Hundred-Floor Pagoda's next floor (progress is kept), its milestones and floor 100.
local function buildPagoda()
	local cleared = State.Tower.Pagoda
	local done = cleared >= Tower.Pagoda.Floors
	local floorNo = math.min(Tower.Pagoda.Floors, cleared + 1)
	local floor = Tower.FloorAt(floorNo, nil, nil, Tower.PagodaId)
	local boss = Bosses.Get(floor.Boss)
	local unlocked = towerOpen()
	local deck = State.ActiveDeck() or Deck.Empty()
	local power = Deck.Power(deck, State.Cards)
	setShowcase(boss, floor)
	buildTabs()

	text(
		body,
		0,
		`{Tower.Pagoda.Floors} floors, each beaten once and kept for good: a loss just tries the floor again. Big rewards wait on floors 25, 50 and 75, and floor 100 pays the Pagoda's own artifact (always on) and the "{Tower.Pagoda.Title}" title. Its top floors take Rainbow and Secret decks.`,
		Theme.Color.Muted,
		17,
		Theme.Font.Bold
	)
	-- Progress bar: floors cleared out of 100, with the milestones marked.
	local track = Kit.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Theme.Color.Backdrop,
		Parent = body,
	}, { Kit.corner(UDim.new(1, 0)) })
	Kit.new("Frame", {
		Size = UDim2.fromScale(cleared / Tower.Pagoda.Floors, 1),
		BackgroundColor3 = PAGODA_COLOR,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	for at in Tower.PagodaMilestones do
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at / Tower.Pagoda.Floors, 0.5),
			Size = UDim2.fromOffset(4, 26),
			BorderSizePixel = 0,
			BackgroundColor3 = if cleared >= at then Theme.Color.Gold else Theme.Color.Muted,
			ZIndex = 3,
			Parent = track,
		})
	end
	Kit.label({
		Text = `{cleared} / {Tower.Pagoda.Floors} FLOORS`,
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Text,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = track,
	}, 15)

	if done then
		local crown = box(2, Theme.Color.Gold)
		text(crown, 1, "🏯 <b>PAGODA CONQUERED</b>", Theme.Color.Gold, 24, Theme.Font.Heavy)
		text(crown, 2, `All {Tower.Pagoda.Floors} floors beaten. You wear the "{Tower.Pagoda.Title}" title.`, Theme.Color.Text, 17, Theme.Font.Bold)
		hintLabel.Parent = body
		return
	end
	floorBox(2, floor, PAGODA_COLOR)
	if not unlocked then
		text(body, 3, `LOCKED · {Tower.UnlockHint()} to open the Pagoda.`, Theme.Color.Roll, 15, Theme.Font.Heavy)
	end
	scoutBox(3, floor.Boss, floor.Guards, deck, Tower.PagodaId)
	powerBox(4, floor.Recommended, power)

	local reward = Tower.PagodaReward(floorNo)
	local rewardBox = box(5, Theme.Color.Gold)
	local milestone = reward.Milestone
	text(rewardBox, 1, if milestone then `MILESTONE · FLOOR {floorNo}` elseif floor.Guardian then "GUARDIAN REWARDS" else "FLOOR REWARDS", Theme.Color.Gold, 20, Theme.Font.Heavy)
	if reward.Packs and next(reward.Packs) then
		text(rewardBox, 2, `<b>{Packs.Describe(reward.Packs)}</b>  (saved to your BAG)`, Theme.Color.Gold, 18)
	end
	text(rewardBox, 3, rewardExtras(reward), Theme.Color.Text, 17, Theme.Font.Bold)
	-- The Pagoda's artifact waits on its last floor (always on once owned).
	local crownId = Tower.PagodaMilestones[Tower.Pagoda.Floors].Artifact
	local crown = crownId and Items.TowerArtifactById[crownId]
	if milestone and milestone.Artifact and crown then
		text(rewardBox, 4, `🏯 THE ARTIFACT: <b>{crown.Name}</b> ({Items.TowerArtifactText(crown)}, always on)` .. (if milestone.Title then `  ·  🏷️ the "{milestone.Title}" title` else ""), Color3.fromRGB(255, 140, 90), 17, Theme.Font.Heavy)
	else
		local nextMilestone = Tower.NextMilestone(floorNo)
		if nextMilestone then
			local m = Tower.PagodaMilestones[nextMilestone]
			text(rewardBox, 4, `Next milestone: floor {nextMilestone} · {Packs.Describe(m.Packs)} and 🧬{m.TraitShards}`, Theme.Color.Gold, 16, Theme.Font.Heavy)
		end
		if crown then
			text(rewardBox, 5, `🏯 Floor {Tower.Pagoda.Floors}: <b>{crown.Name}</b>, the Pagoda's artifact ({Items.TowerArtifactText(crown)}, always on)`, Color3.fromRGB(255, 140, 90), 16, Theme.Font.Heavy)
		end
	end

	deckAndFight(6, deck, unlocked, function()
		if not unlocked then
			hint(`{Tower.UnlockHint()} first`)
			return
		end
		return actions.Fight(Tower.PagodaId, nil)
	end, `CLIMB · FLOOR {floorNo}`, Tower.PagodaId)
	hintLabel.Parent = body
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function short(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return Kit.commas(math.floor(n))
end

-- The RAID tab's changing parts: the countdown, the pool and the top hitters.
local function updateRaidLive()
	local raid = State.Raid
	if raid == nil or raidLive.Status == nil or raidLive.Status.Parent == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	if raid.Open then
		raidLive.Status.Text = `<font color="#FF5078"><b>LIVE</b></font> · ends in <b>{clock(raid.Ends - now)}</b>  ·  {raid.Hitters} hitter{if raid.Hitters == 1 then "" else "s"}`
	elseif raid.Cleared and now < raid.Ends + 60 then
		raidLive.Status.Text = `<font color="#56D68A"><b>CLEARED!</b></font>  ·  next raid in <b>{clock(raid.Next - now)}</b>`
	else
		raidLive.Status.Text = `Next raid in <b>{clock(raid.Next - now)}</b>  (every hour, at half past)`
	end
	local share = if raid.Max > 0 then math.clamp(1 - raid.Dealt / raid.Max, 0, 1) else 1
	raidLive.Fill.Size = UDim2.fromScale(share, 1)
	raidLive.Pool.Text = if raid.Max > 0
		then `Colossus HP  <b>{short(math.max(0, raid.Max - raid.Dealt))}</b> / {short(raid.Max)}`
		else "The Colossus's HP grows as players join: the first hit starts the pool"
	local lines = {}
	for i, hitter in raid.Top do
		table.insert(lines, `{i}. <b>{hitter.Name}</b>  {short(hitter.Damage)}`)
	end
	raidLive.Top.Text = if #lines > 0 then "TOP HITTERS   " .. table.concat(lines, "    ") else "No hits yet: be the first!"
	local luck = State.RaidLuck()
	raidLive.Luck.Text = if luck > 1
		then `🍀 RAID LUCK x{Raid.LuckBoost} is on for everyone: {clock((raid.LuckEnds or now) - now)} left`
		else `🍀 Clear it: RAID LUCK x{Raid.LuckBoost} for everyone on the server for {Raid.LuckSeconds // 60} min`
end

-- The RAID tab: the server's Colossus, the shared pool, scouting, rewards and JOIN RAID.
local function buildRaid()
	local raid = State.Raid
	local w = Raid.At(workspace:GetServerTimeNow())
	local raidBoss = if raid then raid.Boss else w.Colossus.Boss
	local raidName = if raid then raid.Name else w.Colossus.Name
	local boss = Bosses.Get(raidBoss)
	local open = raid ~= nil and raid.Open
	local deck = State.ActiveDeck() or Deck.Empty()
	local power = Deck.Power(deck, State.Cards)
	raidShape = if raid then `{raid.Index}:{tostring(raid.Open)}:{tostring(raid.Cleared)}` else "none"
	setShowcase(boss, nil, raidName)
	buildTabs()

	text(
		body,
		1,
		"Everyone on this server fights the Colossus together. Every hit drains one shared HP pool: empty it before time runs out and everyone who hit it is paid.",
		Theme.Color.Muted,
		17,
		Theme.Font.Bold
	)
	local status = box(2, RAID_COLOR)
	text(status, 1, `SERVER RAID · <b>{string.upper(raidName)}</b>`, RAID_COLOR, 21, Theme.Font.Heavy)
	raidLive.Status = text(status, 2, "", Theme.Color.Text, 17, Theme.Font.Heavy)
	local track = Kit.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Theme.Color.Backdrop,
		Parent = status,
	}, { Kit.corner(UDim.new(1, 0)) })
	raidLive.Fill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RAID_COLOR,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	raidLive.Pool = text(status, 4, "", Theme.Color.Text, 16, Theme.Font.Bold)
	raidLive.Top = text(status, 5, "", Theme.Color.Gold, 15, Theme.Font.Heavy)
	raidLive.Luck = text(status, 6, "", Color3.fromRGB(150, 255, 190), 15, Theme.Font.Heavy)
	text(status, 7, `{boss.Name}'s moves, alone and huge: {boss.Mechanic}`, Theme.Color.Muted, 15, Theme.Font.Bold)
	updateRaidLive()

	scoutBox(3, raidBoss, {}, deck, Raid.Id)

	local reward = Raid.Reward(true, Raid.StatsFor(power).Base * 2, power, false)
	local rewardBox = box(4, Theme.Color.Gold)
	text(rewardBox, 1, "RAID REWARDS", Theme.Color.Gold, 20, Theme.Font.Heavy)
	text(
		rewardBox,
		2,
		`Cleared: <b>+💎{Kit.commas(reward.Shards)}</b> + <b>🧬{reward.TraitShards}</b> (two good runs; more damage pays more) + <b>{Packs.Describe(reward.Packs)}</b>`,
		Theme.Color.Text,
		17,
		Theme.Font.Bold
	)
	text(rewardBox, 3, `Top hitter: <b>+{Packs.Describe(Raid.TopPacks)} +🧬{Raid.TopTraitShards}</b>   ·   Not cleared: about half the Shards`, Theme.Color.Gold, 16, Theme.Font.Heavy)
	text(rewardBox, 4, `Each run is {Raid.FightSeconds} s against a Colossus sized to your deck, so every player's hits count.`, Theme.Color.Muted, 15, Theme.Font.Bold)

	deckAndFight(5, deck, open, function()
		if not open then
			hint(if raid and raid.Cleared then "This raid is cleared: wait for the next one" else "The raid isn't open right now")
			return
		end
		return actions.Fight(Raid.Id, nil)
	end, if open then `JOIN RAID · {Raid.FightSeconds}s RUN` else "NOT OPEN", Raid.Id)
	hintLabel.Parent = body
end

local function build()
	hintLabel.Parent = nil -- reused across rebuilds
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if mode == "tower" then
		buildTower()
		return
	elseif mode == "pagoda" then
		buildPagoda()
		return
	elseif mode == "raid" then
		buildRaid()
		return
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
	text(body, 1, guardLine(boss.Guards), Theme.Color.Text, 16, Theme.Font.Heavy)
	scoutBox(3, boss.Id, boss.Guards, deck, boss.Id)

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

	-- The Cost Challenge: a deck of at most Config.Deck.CostCap points (by the borders worn) for 2x Trait Shards.
	local cost = Deck.Cost(deck, State.Cards)
	local fits = cost <= Config.Deck.CostCap
	local costRow = row(5, 40)
	local toggle = pill(costRow, if costChallenge then "COST CHALLENGE: ON" else "COST CHALLENGE: OFF", 1, 190, Theme.Color.Gold, costChallenge, false)
	toggle.Activated:Connect(function()
		costChallenge = not costChallenge
		refresh()
	end)
	local costText = text(
		costRow,
		2,
		`Deck Cost <font color="{if fits then "#56D68A" else "#FF7846"}"><b>{cost}/{Config.Deck.CostCap}</b></font> · win for <b>x{Config.Deck.CostTraitShards} 🧬</b> (Base 2 · Gold 4 · Rainbow 6 · Secret 8)`,
		Theme.Color.Text,
		15,
		Theme.Font.Heavy
	)
	costText.Size = UDim2.new(1, -200, 0, 19)

	-- Rewards preview.
	local reward = Rewards.For(fight.D)
	local rewardBox = box(6, Theme.Color.Gold)
	text(rewardBox, 1, "WIN REWARDS", Theme.Color.Gold, 20, Theme.Font.Heavy)
	text(
		rewardBox,
		2,
		`<b>{Packs.Describe(Packs.ForBoss(fight.D, false))}</b>  (saved to your BAG, opened at your luck)`,
		Theme.Color.Gold,
		18
	)
	local dropPotion = Meta.PotionById[reward.Potion]
	text(
		rewardBox,
		3,
		`+💎{reward.Shards} Shards  ·  +🧬{Rewards.TraitShards(fight.D, false) * (if costChallenge then Config.Deck.CostTraitShards else 1)} Trait Shards ({if cleared()[key] then "" else "x2 first clear · "}{if costChallenge then "Cost Challenge x2" else "x2 on a Cost Challenge"})  ·  {math.floor(Config.Rewards.PotionChance * 100)}% chance of a {dropPotion.Icon} {dropPotion.Name}`,
		Theme.Color.Text,
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
			"FIRST CLEAR BONUS: +1 Roll Pack",
			Theme.Color.Text,
			17,
			Theme.Font.Heavy
		)
	end

	deckAndFight(7, deck, unlocked, function()
		if not unlocked then
			hint(`{Bosses.UnlockHint(boss.Id, difficulty)} first`)
			return
		end
		if costChallenge and not fits then
			hint(`Cost Challenge: your deck costs {cost}, the cap is {Config.Deck.CostCap}`)
			return
		end
		return actions.Fight(bossId, difficulty, if costChallenge then { Cost = true } else nil)
	end, if costChallenge then "FIGHT! · COST" else nil, boss.Id)
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
		TextColor3 = Color3.fromRGB(220, 232, 255),
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
		TextColor3 = Color3.fromRGB(206, 218, 240),
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
	Kit.textStroke(Color3.fromRGB(13, 17, 27), 1.5, 0).Parent = hintLabel

	modal.OnOpen = build
	State.Changed:Connect(function(kind)
		if kind == "raid" then
			-- Raid news comes every second: only a new window, open or cleared rebuilds the tab.
			if not modal.IsOpen then
				return
			end
			local raid = State.Raid
			local shape = if raid then `{raid.Index}:{tostring(raid.Open)}:{tostring(raid.Cleared)}` else "none"
			if mode == "raid" and shape == raidShape then
				updateRaidLive()
			elseif mode == "raid" or (raid ~= nil and raid.Open) ~= tabsLive then
				refresh()
			end
			return
		end
		if kind ~= "roll" then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if modal.IsOpen and mode == "raid" then
				updateRaidLive()
			end
		end
	end)
end

function BossScreen.Toggle()
	modal:Toggle()
end

-- The RAID tab (from the HUD's raid pill).
function BossScreen.OpenRaid()
	mode = "raid"
	modal:Open()
end

-- A boss fight with the Cost Challenge switched on (HUD: BATTLE > COST).
function BossScreen.OpenCost()
	mode = "boss"
	costChallenge = true
	modal:Open()
end

-- The TOWER tab, from the tower gate.
function BossScreen.OpenTower()
	if mode ~= "pagoda" then
		mode = "tower"
	end
	modal:Open()
end

function BossScreen.Open(id: string?)
	if id then
		mode = "boss"
	end
	if id and Bosses.Get(id) then
		if id ~= bossId then
			difficulty = "Normal"
		end
		bossId = id
	end
	modal:Open()
end

return BossScreen
