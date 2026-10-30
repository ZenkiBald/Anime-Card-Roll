--!nonstrict
-- The Index: every card by its best border (Base / Gold / Rainbow / Secret; not found yet under Base), each
-- border's odds, how many cards were found at it, and a completion reward (permanent luck + loot) for finding
-- every card at a border. Tap a card for its details; ODDS opens the live odds panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)
local Odds = require(Shared.Odds)
local Meta = require(Shared.Meta)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local CardView = require(script.Parent.CardView)
local StatLine=require(script.Parent.StatLine)
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
		order+=1
		StatLine.new(card,stars,best,node,{Size=UDim2.new(1,0,0,28),LayoutOrder=order,ZIndex=22,Parent=right},true)
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
	line(tier.Name.." border · "..card.Type,Theme.Font.Heavy,tier.Color,22,17)
	local chance=if card.SkyOneIn then 1/card.SkyOneIn else Cards.PullChances(Cards.Pool(State.Progress.Cleared),nil,nil,Cards.FeaturedAt(workspace:GetServerTimeNow()))[card.Id]
	if card.SkyOneIn then
		local sky=require(Shared.Weather).ById[card.Weather]
		line(sky.Name.." only · "..Odds.FormatPercent(100*chance).." per sky search",Theme.Font.Medium,Theme.Color.Muted,20,15)
		line("Every ROLL / AUTO / pack pull searches the active sky. Luck adds 35% of its bonus to the chance (30x luck = about 11x the finds).",Theme.Font.Medium,Theme.Color.Muted,20,14)
	elseif chance then
		line(Odds.FormatPercent(chance*100).." card chance · any border",Theme.Font.Medium,Theme.Color.Muted,20,15)
	elseif card.Boss then
		line("Unlock by beating this card's boss on Normal.",Theme.Font.Medium,Theme.Color.Muted,20,15)
	end
	if owned then
		local piles={}
		for _,id in Borders.Order do
			local n=(entry.BorderCopies or {})[id] or 0
			if n>0 then table.insert(piles,Borders.Get(id).Name.." x"..Kit.commas(n)) end
		end
		line("COPIES  "..table.concat(piles," · "),Theme.Font.Heavy,Theme.Color.Text,22,15)
		line(`{Cards.FusionCost(card)} copies of one border fuse into the next at Hoshi · each duplicate: +0.5% ATK / HP (max +25%).`,Theme.Font.Medium,Theme.Color.Muted,20,14)
		local foil=Foils.Get(Foils.Best(entry.Foils))
		if foil.Id~="standard" then line(foil.Name..": "..foil.Text,Theme.Font.Medium,foil.Color,22,15) end
		for i,id in {entry.Trait or "",entry.Trait2 or ""} do
			local trait=Traits.Get(id)
			if trait then line("TRAIT "..i.."  "..trait.Name.." · "..Traits.Text(id),Theme.Font.Medium,Theme.Color.Text,22,15) end
		end
		if not entry.Trait2Unlocked and node<Traits.Slot2Node then line("Second trait: reach 10 distinct boss victories.",Theme.Font.Medium,Theme.Color.Muted,20,14) end
		line("MASTERY  "..Awaken.Count(entry).." distinct boss victories",Theme.Font.Heavy,Theme.Color.Gold,22,17)
		local nextNode=Awaken.Nodes[node+1]
		if nextNode then line("Next at "..nextNode.Challenges..": "..nextNode.Text,Theme.Font.Medium,Theme.Color.Muted,20,15) end
		order+=1
		local fav=Kit.button(if State.Meta.Favorite==card.Id then "YOUR FAVOURITE" else "SET FAVOURITE",Theme.Color.Info,Theme.Color.InfoDeep,{LayoutOrder=order,Size=UDim2.new(0,230,0,36),ZIndex=22,Parent=infoParent})
		fav.Activated:Connect(function()
			local want=if State.Meta.Favorite==card.Id then "" else card.Id
			local result=MetaClient.Call("SetFavorite",want)
			if result.Ok then fav.Label.Text=if want~="" then "YOUR FAVOURITE" else "SET FAVOURITE" end
		end)
	else
		line("Discover this card to see its abilities.",Theme.Font.Medium,Theme.Color.Muted,20,16)
	end
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
	local claimAll=Kit.button("CLAIM ALL",Theme.Color.Support,Theme.Color.SupportDeep,{Name="ClaimAll",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-285,0,-10),Size=UDim2.fromOffset(130,40),Parent=modal.Header})
	local claiming=false
	claimAll.Activated:Connect(function()
		if claiming then return end
		claiming=true
		MetaClient.Call("ClaimAll","Index")
		claiming=false;Index.Refresh()
	end)

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
	local oddsButton = Kit.button("ODDS", Theme.Color.Auto, Theme.Color.AutoDeep, {
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
