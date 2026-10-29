--!nonstrict
-- The Index: every card by its best border (Base / Gold / Rainbow / Secret; not found yet under Base), each
-- border's odds, how many cards were found at it, and a completion reward (permanent luck + loot) for finding
-- every card at a border. Tap a card for its details; ODDS opens the live odds panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity) -- trait tier colours only
local Cards = require(Shared.Cards)
local CardInfo = require(Shared.CardInfo)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local ColumnBonds = require(Shared.ColumnBonds)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)
local Config = require(Shared.Config)
local Odds = require(Shared.Odds)
local Meta = require(Shared.Meta)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardView = require(script.Parent.CardView)
local Abilities = require(script.Parent.Abilities)
local CardTile = require(script.Parent.CardTile)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Index = {}

local modal
local list: ScrollingFrame
local progressLabel: TextLabel
local progressFill: Frame
local detail: TextButton? = nil
local onOdds: (() -> ())? = nil
local dirty = true
local tabSetters = {}
local tab = "All"
local filterBy = "All"
local search = ""
local cellSize = 110 -- card tile size, fitted to the list width

local function closeDetail()
	if detail then
		detail:Destroy()
		detail = nil
	end
end

local function showDetail(card, chosenBorder: string?, parent: Instance?)
	closeDetail()
	local entry = State.Cards[card.Id]
	local owned = entry ~= nil
	local stars = if entry then entry.Stars else 0
	local best = chosenBorder or (if entry then Borders.Best(entry.Borders) else "Normal")
	local tier = Borders.Get(best)
	local node = if entry then Awaken.Level(entry) else 0

	-- Kit-style detail sheet: dark gradient, edged in the card's border colour.
	local panel = Kit.new("TextButton", {
		Name = "Detail",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
		Parent = parent or modal.Body,
	}, {
		Kit.corner(UDim.new(0, 16)),
		Kit.gradient(ColorSequence.new(Theme.Color.TileTop:Lerp(tier.Dark, 0.35), Theme.Color.TileBottom:Lerp(Color3.new(0, 0, 0), 0.35)), 90),
		Kit.stroke(tier.Color, 3, 0.15),
	})
	detail = panel
	local back = Kit.button("< BACK TO CARDS", Theme.Color.Line, Theme.Color.TileBottom, {
		Name = "BackToCards", Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(170, 28), ZIndex = 23, Parent = panel,
	})
	back.Activated:Connect(closeDetail)

	local left = Kit.new("Frame", {
		Name = "CardSide",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(0.4, 0, 1, -34),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = panel,
	}, { Kit.padding(10) })
	local view = CardView.new(card.Id, {
		Owned = owned,
		Stars = stars,
		Awaken = node,
		Animate = owned,
		Border = best,
		Trait = entry and entry.Trait,
		Foil = entry and Foils.Best(entry.Foils),
	})
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Parent = left
	if owned and Borders.Index(best) >= 3 then
		Effects.Shimmer(view, 2)
	end

	local right = Kit.new("ScrollingFrame", {
		Name = "Info",
		Position = UDim2.new(0.42, 0, 0, 34),
		Size = UDim2.new(0.58, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = panel,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }),
	})

	local order = 0
	local infoParent: Instance = right
	local function line(text: string, font: Enum.Font, color: Color3, height: number, maxText: number)
		order += 1
		return Kit.label({
			Text = text,
			RichText = true,
			Font = font,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = maxText,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = order,
			ZIndex = 22,
			Parent = infoParent,
		}, maxText)
	end

	line(if owned then card.Name else "???", Theme.Font.Display, Theme.Color.Text, 30, 28)
	if owned then
		line(Kit.statsText(card, stars, best, node, true), Theme.Font.Heavy, Theme.Color.Text, 24, 18)
		order = Abilities.List(card, right, order, "big", best)
	end
	-- Collection data remains available without competing with the ability text.
	local extras = Kit.new("Frame", { Name = "CollectionDetails", Visible = false, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 2, ZIndex = 22, Parent = right }, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	local toggle = Kit.new("TextButton", { Name = "CollectionToggle", Text = "SHOW COLLECTION & MASTERY", Font = Theme.Font.Bold, TextSize = 14,
		TextColor3 = Theme.Color.Muted, BackgroundColor3 = Theme.Color.TileBottom, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order + 1, ZIndex = 23, Parent = right }, { Kit.corner(UDim.new(0, 8)) })
	toggle.Activated:Connect(function()
		extras.Visible = not extras.Visible
		toggle.Text = if extras.Visible then "HIDE COLLECTION & MASTERY" else "SHOW COLLECTION & MASTERY"
	end)
	infoParent = extras
	line(
		`<font color="#{tier.Color:ToHex()}">{string.upper(tier.Name)} BORDER{if card.Type == "Attack" then ` · {tier.Multiplier}x` else ""}</font>  ·  {card.Type}  ·  {if owned then card.Title else "Not found yet"}`,
		Theme.Font.Heavy,
		Theme.Color.Muted,
		20,
		17
	)
	-- The card's pull chance (any border); boss cards only join the pool after their boss's first Normal clear.
	local featured = Cards.FeaturedAt(workspace:GetServerTimeNow())
	local pullChance = Cards.PullChances(Cards.Pool(State.Progress.Cleared), nil, nil, featured)[card.Id]
	if featured == card.Id then
		line(`⭐ FEATURED THIS WEEK: x{Cards.FeaturedBoost} as likely to pull`, Theme.Font.Heavy, Theme.Color.Gold, 18, 15)
	end
	if pullChance then
		local chance = pullChance * 100
		line(`Chance per roll: <b>{Odds.FormatPercent(chance)}</b>, any border`, Theme.Font.Bold, Theme.Color.Support, 18, 15)
		-- Its rarity number at each border (Cards.Rarity: pulls it takes at 1x luck).
		local parts = {}
		for _, b in Borders.List do
			table.insert(parts, `<font color="#{b.Color:ToHex()}">{b.Name}</font> <b>{Kit.commas(Cards.Rarity(card.Id, b.Id))}</b>`)
		end
		line(`RARITY  {table.concat(parts, "   ")}`, Theme.Font.Heavy, Theme.Color.Text, 18, 15)
	elseif card.Boss then
		line(`🔒 Beat {string.upper(card.Boss)} on Normal to add this card to the roll pool`, Theme.Font.Bold, Theme.Color.Support, 18, 15)
	end
	if owned then
		line(
			`{CardInfo.CopyBonus(stars)}  ·  {entry.Copies} pulled`,
			Theme.Font.Bold,
			Theme.Color.Gold,
			20,
			16
		)
		if card.Type == "Attack" then
			line(`Action speed {card.SPD} · Attack rating {Kit.commas(Cards.Power(card, stars, best, node))}`, Theme.Font.Medium, Theme.Color.Text, 20, 16)
		end
		-- Border fusion: 100 copies at one border fuse into 1 copy at the next (Hoshi, in town).
		local copies = entry.BorderCopies or {}
		local copyParts = {}
		for _, id in Borders.Order do
			table.insert(copyParts, `<font color="#{Borders.Get(id).Color:ToHex()}">{Borders.Get(id).Name} {Kit.commas(copies[id] or 0)}</font>`)
		end
		line(`Copies  {table.concat(copyParts, "  ·  ")}`, Theme.Font.Heavy, Theme.Color.Text, 20, 16)
		local fuseFrom = Borders.BestOwned(copies)
		for _, id in Borders.Order do
			if Borders.Next(id) and (copies[id] or 0) >= Config.FusionCopies then
				fuseFrom = id
			end
		end
		local fuseTo = Borders.Next(fuseFrom)
		line(
			if fuseTo
				then `🔥 Border fusion: <b>{Kit.commas(copies[fuseFrom] or 0)}/{Config.FusionCopies}</b> {Borders.Get(fuseFrom).Name} copies fuse into 1 {string.upper(Borders.Get(fuseTo).Name)} (Hoshi the Fusion Master, in town)`
				else `🔥 Secret Border: the top of the ladder`,
			Theme.Font.Bold,
			Color3.fromRGB(255, 160, 90),
			20,
			16
		)
		for _,bond in ColumnBonds.List do
			if card.Id==bond.Attack or card.Id==bond.Support then
				local partner=Cards.Get(if card.Id==bond.Attack then bond.Support else bond.Attack)
				line(`Bond: {bond.Name} · pair with {if partner then partner.Name else "its companion"} in the same numbered column. {bond.Text}`,Theme.Font.Bold,Color3.fromRGB(255,190,120),38,15)
			end
		end
		-- Borders found for this card: each one lit or still to find, with its odds.
		local found = entry.Borders or {}
		local parts = {}
		for _, border in Borders.List do
			if border.Id ~= "Normal" then
				local has = found[border.Id] == true
				local color = if has then border.Color:ToHex() else "6E6A88"
				table.insert(parts, `<font color="#{color}">{if has then "◆" else "◇"} <b>{string.upper(border.Name)}</b></font>`)
			end
		end
		line(`Borders  {table.concat(parts, "   ")}`, Theme.Font.Heavy, Theme.Color.Text, 20, 17)
		if best ~= "Normal" then
			line(if card.Type == "Support" then CardInfo.BorderHelp(card, best) else `Wearing {tier.Name}: {tier.Multiplier}x base stats`, Theme.Font.Bold, tier.Color, 18, 15)
		end
		-- Foils found, Mastery ranks, and the trait slots (rolled at the Trait Master).
		local foundFoils = entry.Foils or {}
		local foilParts = {}
		for i, foil in Foils.List do
			if i > 1 then
				local has = foundFoils[foil.Id] == true
				local color = if has then foil.Color:ToHex() else "6E6A88"
				table.insert(foilParts, `<font color="#{color}">{if has then "FOUND" else "MISSING"} <b>{string.upper(foil.Name)}</b></font>`)
			end
		end
		line(`Foils  {table.concat(foilParts, "   ")}`, Theme.Font.Heavy, Theme.Color.Text, 20, 17)
		local bestFoil = Foils.Best(entry.Foils)
		if bestFoil ~= "standard" then
			line(`Wearing {Foils.Get(bestFoil).Name}: {Foils.Get(bestFoil).Text} (in battle)`, Theme.Font.Bold, Foils.Get(bestFoil).Color, 18, 15)
		end
		local nodeParts = {}
		for _, n in Awaken.Nodes do
			local open = node >= n.Node
			table.insert(nodeParts, `<font color="#{if open then "FFC42E" else "6E6A88"}">{if open then "●" else "○"} {n.Challenges}: {n.Text}</font>`)
		end
		line(`BATTLE MASTERY  ({Awaken.Count(entry)} distinct boss challenges)\nWin different story boss difficulties with this card equipped. Repeats and duplicate pulls grant no marks.\n{table.concat(nodeParts, "\n")}`, Theme.Font.Bold, Theme.Color.Text, 20, 15)
		local function traitLineText(id: string?): string
			local trait = Traits.Get(id)
			return if trait
				then `<font color="#{Rarity.Get(trait.Tier).Color:ToHex()}"><b>{string.upper(trait.Name)}</b></font> ({trait.Tier}): {Traits.Text(trait.Id)}`
				else "none yet"
		end
		line(`Trait 1  {traitLineText(entry.Trait)}`, Theme.Font.Heavy, Theme.Color.Text, 20, 16)
		line(
			if entry.Trait2Unlocked or node >= Traits.Slot2Node then `Trait 2  {traitLineText(entry.Trait2)}` else `Trait 2  🔒 opens at Mastery rank {Traits.Slot2Node}`,
			Theme.Font.Heavy,
			Theme.Color.Text,
			20,
			16
		)
		order += 1
		-- Traits are rolled in town only: walk to Kenshin the Trait Master, beside Hoshi.
		line(
			if entry.Pending
				then "🧬 A trait roll waits for your choice: visit Kenshin the Trait Master in town"
				else `🧬 New traits: visit Kenshin the Trait Master in town (🧬{Traits.RollCost} a roll)`,
			Theme.Font.Bold,
			Color3.fromRGB(80, 230, 200),
			16,
			14
		)

		-- FAVOURITE: this card becomes your picture in the server list and on your name tag.
		order += 1
		local isFav = State.Meta.Favorite == card.Id
		local fav = Kit.button(if isFav then "★ YOUR FAVOURITE" else "☆ SET AS FAVOURITE", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
			LayoutOrder = order,
			Size = UDim2.new(0, 230, 0, 40),
			ZIndex = 22,
			Parent = infoParent,
		})
		fav.Activated:Connect(function()
			local want = if State.Meta.Favorite == card.Id then "" else card.Id
			local result = MetaClient.Call("SetFavorite", want)
			if result.Ok then
				Sfx.Play("Upgrade", 1.3)
				fav.Label.Text = if want ~= "" then "★ YOUR FAVOURITE" else "☆ SET AS FAVOURITE"
			end
		end)
	else
		line("Keep rolling to discover this card and its abilities!", Theme.Font.Bold, Theme.Color.Muted, 20, 16)
	end
	line("Use BACK TO CARDS to return to your team.", Theme.Font.Medium, Theme.Color.Muted, 18, 14)
	panel.Activated:Connect(function()
		closeDetail()
		Index.Refresh()
	end)
end

-- Also used by DECK: readable, scrollable skills at the selected tile's actual border.
function Index.Inspect(cardId: string, border: string?, parent: Instance)
	local card = Cards.Get(cardId)
	if card then showDetail(card, border, parent) end
end

Index.CloseDetail = closeDetail

-- One border tier: its odds, how many cards have been found at it (boss cards aside), its completion
-- reward, and the cards whose best border it is (Base also lists the cards not found yet).
local function section(rarity: string, order: number)
	local tier = Borders.Get(rarity)
	local pool = {}
	local found = 0
	for _, card in Cards.List do
		if card.Boss == nil and not card.Weather then
			table.insert(pool, card)
			local own = State.Cards[card.Id]
			if own and (rarity == "Normal" or (own.Borders and own.Borders[rarity])) then
				found += 1
			end
		end
	end
	-- Cards in this section after the tab / filter / search.
	local shown = {}
	for _, card in Cards.List do
		local own = State.Cards[card.Id]
		local owned = own ~= nil
		local here = not card.Weather and (if owned then Borders.Best(own.Borders) == rarity else (rarity == "Normal" and card.Boss == nil))
		if not here then
			continue
		end
		local matchesTab = tab == "All" or card.Type == tab
		local matchesFilter = filterBy == "All" or (filterBy == "Found" and owned) or (filterBy == "Missing" and not owned)
		local matchesSearch = search == "" or (owned and string.find(string.lower(card.Name), search, 1, true) ~= nil)
		if matchesTab and matchesFilter and matchesSearch then
			table.insert(shown, card)
		end
	end
	if #shown == 0 and (search ~= "" or filterBy ~= "All" or tab ~= "All") then
		return -- nothing to show here
	end
	local reward = Meta.IndexRewards[rarity]
	local claimed = State.Meta.IndexClaimed[rarity] == true
	local complete = found == #pool and #pool > 0
	local chance = Odds.Chances(State.Luck())[rarity]

	local box = Kit.new("Frame", {
		Name = rarity,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = tier.Dark:Lerp(Color3.new(0, 0, 0), 0.6),
		BackgroundTransparency = 0.2,
		Parent = list,
	}, {
		Kit.corner(),
		Kit.stroke(tier.Color, if complete then 3 else 2, if complete then 0 else 0.5),
		Kit.padding(10),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
	})

	-- Header strip in the rarity's colour: name, odds and progress, reward / claim.
	local header = Kit.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = box,
	}, {
		Kit.corner(UDim.new(0, 14)),
		Kit.gradient(ColorSequence.new(tier.Dark:Lerp(Color3.new(0, 0, 0), 0.2), Color3.fromRGB(12, 15, 23)), 0),
		Kit.stroke(tier.Color, 1.2, 0.2),
	})
	-- A swatch of the border's own frame colours.
	local badge = Kit.new("Frame", {
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = header,
	}, { Kit.corner(UDim.new(0, 4)), Kit.gradient(tier.Gradient, 45), Kit.stroke(Color3.new(1, 1, 1), 1.2, 0.3) })
	Controls.Outlined(Kit.label({
		Text = `{tier.Multiplier}x`,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.75, 0.6),
		Parent = badge,
	}, 18), 1.5)
	Controls.Outlined(Kit.label({
		Text = `{string.upper(tier.Name)} BORDER`,
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(56, 4),
		Size = UDim2.new(0.4, 0, 0, 26),
		Parent = header,
	}, 26), 2)
	Controls.Outlined(Kit.label({
		Text = `{Odds.FormatPercent(chance)}{if rarity == "Normal" then "" else `  ·  {Odds.FormatRarity(chance)}`}  ·  {found}/{#pool} found{if rarity == "Normal" then "" else ` at {tier.Name}`}`,
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(223, 235, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(0.45, 0, 0, 16),
		Parent = header,
	}, 15), 1.5)

	local rewardText = `+{reward.Luck}x luck  {Meta.Describe(reward.Reward)}`
	if claimed then
		Controls.Outlined(Kit.label({
			Text = `✓ CLAIMED  ·  {rewardText}`,
			Font = Theme.Font.Display,
			TextColor3 = Theme.Color.Quick,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0, 22),
			Parent = header,
		}, 18), 1.5)
	elseif complete then
		local claim = Kit.button(`CLAIM  {rewardText}`, Theme.Color.Gold, Color3.fromRGB(170, 110, 0), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.48, 0, 0, 40),
			Parent = header,
		})
		local scale = claim:FindFirstChildOfClass("UIScale")
		if scale then
			task.spawn(Effects.Pulse, scale, 3, 0.6, 0.06)
		end
		claim.Activated:Connect(function()
			local result = MetaClient.Call("ClaimIndex", rarity)
			if result.Ok then
				Sfx.Play("Reward", 1.1)
				dirty = true
				Index.Refresh()
			end
		end)
	else
		Controls.Outlined(Kit.label({
			Text = `{if rarity == "Normal" then `Find all {#pool}` else `All {#pool} at {tier.Name}`}:  {rewardText}`,
			Font = Theme.Font.Heavy,
			TextColor3 = Color3.fromRGB(223, 235, 255),
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0, 20),
			Parent = header,
		}, 16), 1.5)
	end

	-- Cards.
	local grid = Kit.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = box,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellSize, cellSize),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	table.sort(shown, function(a, b)
		if a.Type ~= b.Type then
			return a.Type == "Attack"
		end
		return a.Name < b.Name
	end)
	for i, card in shown do
		local own = State.Cards[card.Id]
		local tile = CardTile.new(card.Id, {
			Owned = own ~= nil,
			Stars = if own then own.Stars else 0,
			Border = if own then Borders.Best(own.Borders) else nil,
			Copies = if own then own.Copies else nil,
		})
		tile.LayoutOrder = i
		tile.Parent = grid
		tile.Activated:Connect(function()
			showDetail(card)
		end)
	end
end

local function celestialSection()
	if not require(Shared.Config).CelestialCardsReady then return end
	local holder=Kit.new("Frame",{Name="CelestialCodex",LayoutOrder=10,Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=list},{Kit.new("UIListLayout",{Padding=UDim.new(0,10)})})
	Kit.label({Text="CELESTIAL CODEX · EVENT ATTACK CARDS",Size=UDim2.new(1,0,0,32),Font=Theme.Font.Display,Parent=holder},22)
	for _,sky in require(Shared.Weather).List do
		if sky.Id=="clear" then continue end
		Kit.label({Text=sky.Name.." · "..sky.Series,TextColor3=sky.Color,Size=UDim2.new(1,0,0,24),Parent=holder},18)
		local grid=Kit.new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=holder},{Kit.new("UIGridLayout",{CellSize=UDim2.fromOffset(cellSize,cellSize),CellPadding=UDim2.fromOffset(10,10)})})
		for _,card in Cards.List do
			if card.Weather==sky.Id and (search=="" or string.find(string.lower(card.Name),search,1,true)) then
				local own=State.Cards[card.Id]
				local tile=CardTile.new(card.Id,{Owned=own~=nil,Border=if own then Borders.Best(own.Borders) else "Normal"})
				tile.Parent=grid;tile.Activated:Connect(function() showDetail(card) end)
			end
		end
	end
end

function Index.Refresh()
	if not modal.IsOpen or not dirty or detail ~= nil then
		return
	end
	dirty = false
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local width = Kit.logicalSize(list).X - 40
	if width > 0 then
		local count = math.clamp(math.floor(width / 120), 3, 9)
		cellSize = math.floor((width - 10 * (count - 1)) / count)
	end
	local total, found = 0, 0
	for _, card in Cards.List do
		if not card.Weather then total+=1; if State.Cards[card.Id] then found+=1 end end
	end
	progressLabel.Text = `FOUND {found} / {total}  ·  {math.floor(found / total * 100)}%`
	Kit.tween(progressFill, 0.4, { Size = UDim2.fromScale(math.max(0.02, found / total), 1) })
	for name, set in tabSetters do
		set(name == tab)
	end
	for i, border in Borders.Order do
		section(border, i)
	end
	celestialSection()
end

local function redraw()
	dirty = true
	Index.Refresh()
end

-- `host`: the SQUAD panel (Modal.Tabbed); the Index is its INDEX tab.
function Index.Init(playerGui: Instance, openOdds: () -> (), host: any?)
	onOdds = openOdds
	modal = if host then host:Page("INDEX") else Modal.new(playerGui, "IndexGui", "Index", Vector2.new(0.94, 0.9), Vector2.new(1200, 760))

	Controls.Search(modal.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, -10),
		Size = UDim2.fromOffset(200, 40),
	}, function(text)
		search = text
		redraw()
	end)

	-- Top bar: tabs, filter, completion bar, odds.
	local bar = Kit.new("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	local tabs = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(0.5, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	for i, info in { { "All", Controls.Purple }, { "Attack", Theme.Color.Attack }, { "Support", Theme.Color.Quick } } do
		local button, set = Controls.Tab(tabs, info[1], info[2], i, 110)
		button.Activated:Connect(function()
			tab = info[1]
			redraw()
		end)
		tabSetters[info[1]] = set
	end
	local right = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local track = Kit.new("Frame", {
		Name = "Progress",
		LayoutOrder = 1,
		Size = UDim2.new(0, 220, 0, 30),
		BackgroundColor3 = Color3.fromRGB(6, 8, 12),
		Parent = right,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Theme.Color.Gold, 2, 0.3) })
	progressFill = Kit.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.gradient(ColorSequence.new(Theme.Color.Gold, Theme.Color.Roll), 0),
	})
	progressLabel = Controls.Outlined(Kit.label({
		Text = "",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.75),
		ZIndex = 2,
		Parent = track,
	}, 17), 1.5)
	Controls.Option(right, "Filter", { "All", "Found", "Missing" }, 2, function(value)
		filterBy = value
		redraw()
	end)
	local oddsButton = Kit.button("📊 ODDS", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 3,
		Size = UDim2.new(0, 104, 1, 0),
		Parent = right,
	})
	oddsButton.Activated:Connect(function()
		if onOdds then
			onOdds()
		end
	end)

	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(90, 210, 255),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10) }),
	})

	modal.OnOpen = function()
		closeDetail()
		task.defer(redraw) -- after the list has its size, for the tile size
	end
	-- Rebuild at most every 0.8 s, so Auto Roll results don't redraw it every roll.
	local pending = false
	State.Changed:Connect(function()
		dirty = true
		if pending or not modal.IsOpen then
			return
		end
		pending = true
		task.delay(0.8, function()
			pending = false
			Index.Refresh()
		end)
	end)
end

function Index.Toggle()
	modal:Toggle()
end

return Index
