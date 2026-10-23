--!nonstrict
-- The Index: every card by rarity, found or not, with each rarity's odds, how many copies you
-- have, and a completion reward (permanent luck + loot) for finding every card of a rarity.
-- Tap a card for its details; ODDS opens the live odds panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
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

local function showDetail(card)
	closeDetail()
	local entry = State.Cards[card.Id]
	local owned = entry ~= nil
	local stars = if entry then entry.Stars else 0
	local fusion = if entry then entry.Fusion or 0 else 0
	local tier = Rarity.Get(card.Rarity)

	-- Kit-style detail sheet: purple gradient, edged in the card's rarity colour.
	local panel = Kit.new("TextButton", {
		Name = "Detail",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
		Parent = modal.Body,
	}, {
		Kit.corner(UDim.new(0, 16)),
		Kit.gradient(ColorSequence.new(Theme.Color.TileTop:Lerp(tier.Dark, 0.35), Theme.Color.TileBottom:Lerp(Color3.new(0, 0, 0), 0.35)), 90),
		Kit.stroke(tier.Color, 3, 0.15),
	})
	detail = panel

	local left = Kit.new("Frame", {
		Name = "CardSide",
		Size = UDim2.fromScale(0.4, 1),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = panel,
	}, { Kit.padding(10) })
	local best = if entry then Borders.Best(entry.Borders) else "Normal"
	local view = CardView.new(card.Id, { Owned = owned, Stars = stars, Fusion = fusion, Animate = owned, Border = best, Trait = entry and entry.Trait })
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Parent = left
	if owned and Rarity.AtLeast(card.Rarity, "Legendary") then
		Effects.Shimmer(view, 2)
	end

	local right = Kit.new("ScrollingFrame", {
		Name = "Info",
		Position = UDim2.fromScale(0.42, 0),
		Size = UDim2.fromScale(0.58, 1),
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
			Parent = right,
		}, maxText)
	end

	line(if owned then card.Name else "???", Theme.Font.Display, Theme.Color.Text, 30, 28)
	line(
		`<font color="#{tier.Color:ToHex()}">{string.upper(card.Rarity)}</font>  ·  {card.Type}  ·  {if owned then card.Title else "Not found yet"}`,
		Theme.Font.Heavy,
		Theme.Color.Muted,
		20,
		17
	)
	local chance = Odds.Chances(State.Luck())[card.Rarity] / #Cards.ByRarity[card.Rarity]
	line(`Chance per roll right now: <b>{Odds.FormatPercent(chance)}</b> ({Odds.FormatOneIn(chance)})`, Theme.Font.Bold, Theme.Color.Support, 18, 15)
	if owned then
		line(
			`★ {stars}/{Config.MaxStars} stars (+{math.floor(stars * Config.StarBonus * 100 + 0.5)}% stats)  ·  {entry.Copies} pulled`,
			Theme.Font.Bold,
			Theme.Color.Gold,
			20,
			16
		)
		local hpText = if card.HP then `   ❤️ HP <b>{Kit.commas(Cards.Stat(card, card.HP, stars, fusion, best))}</b>` else ""
		line(
			`{if card.Type == "Attack" then "⚔️ ATK" else "✨ PWR"} <b>{Kit.commas(Cards.Stat(card, card.Main, stars, fusion, best))}</b>{hpText}   ⚡ SPD <b>{card.SPD}</b>   Power <b>{Kit.commas(
				Cards.Power(card, stars, fusion, best)
			)}</b>`,
			Theme.Font.Medium,
			Theme.Color.Text,
			20,
			16
		)
		local fusionText = if fusion >= Cards.MaxFusion(card)
			then `🔥 Fused to {string.upper(Cards.FusedRarity(card, fusion))}: max rarity`
			else `🔥 Fusion: <b>{Kit.commas(entry.Copies)}/{Config.FusionCopies}</b> copies to fuse into {string.upper(
				Cards.FusedRarity(card, fusion + 1)
			)} (Hoshi the Fusion Master, in town)`
		line(fusionText, Theme.Font.Bold, Color3.fromRGB(255, 160, 90), 20, 16)
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
			line(`Wearing {best}: +{math.floor(Borders.Get(best).Bonus * 100 + 0.5)}% stats`, Theme.Font.Bold, Borders.Get(best).Color, 18, 15)
		end
		-- Trait: the best one this card has rolled, and REROLL (Shards, replaces it).
		local trait = Traits.Get(entry.Trait)
		local traitLine = line(
			if trait
				then `Trait  <font color="#{Rarity.Get(trait.Tier).Color:ToHex()}"><b>{trait.Icon} {string.upper(trait.Name)}</b></font>  ({trait.Tier}): {Traits.Text(trait.Id)}`
				else "Trait  none yet: every pull of this card rolls one",
			Theme.Font.Heavy,
			Theme.Color.Text,
			20,
			16
		)
		order += 1
		local reroll = Kit.button(`REROLL TRAIT 💎{Traits.RerollCost}`, Color3.fromRGB(176, 92, 255), Theme.Color.AccentDeep, {
			LayoutOrder = order,
			Size = UDim2.new(0, 230, 0, 40),
			ZIndex = 22,
			Parent = right,
		})
		reroll.Activated:Connect(function()
			local result = MetaClient.Call("RerollTrait", card.Id)
			if not result.Ok then
				reroll.Label.Text = if result.Reason == "NoShards" then "NOT ENOUGH SHARDS" else "TRY AGAIN"
				return
			end
			-- The server rolled it and says which trait came out.
			local new = result.Extra and Traits.Get(result.Extra.Trait)
			if new and State.Cards[card.Id] then
				State.Cards[card.Id].Trait = new.Id
				Sfx.Sting(new.Tier, true)
				traitLine.Text = `Trait  <font color="#{Rarity.Get(new.Tier).Color:ToHex()}"><b>{new.Icon} {string.upper(new.Name)}</b></font>  ({new.Tier}): {Traits.Text(new.Id)}`
			end
		end)

		-- FAVOURITE: this card becomes your picture in the server list and on your name tag.
		order += 1
		local isFav = State.Meta.Favorite == card.Id
		local fav = Kit.button(if isFav then "★ YOUR FAVOURITE" else "☆ SET AS FAVOURITE", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
			LayoutOrder = order,
			Size = UDim2.new(0, 230, 0, 40),
			ZIndex = 22,
			Parent = right,
		})
		fav.Activated:Connect(function()
			local want = if State.Meta.Favorite == card.Id then "" else card.Id
			local result = MetaClient.Call("SetFavorite", want)
			if result.Ok then
				Sfx.Play("Upgrade", 1.3)
				fav.Label.Text = if want ~= "" then "★ YOUR FAVOURITE" else "☆ SET AS FAVOURITE"
			end
		end)
		order = Abilities.List(card, right, order, "big")
	else
		line("Keep rolling to discover this card and its abilities!", Theme.Font.Bold, Theme.Color.Muted, 20, 16)
	end
	line("Tap anywhere on this panel to go back.", Theme.Font.Medium, Theme.Color.Muted, 18, 14)
	panel.Activated:Connect(function()
		closeDetail()
		Index.Refresh()
	end)
end

local function section(rarity: string, order: number)
	local tier = Rarity.Get(rarity)
	local pool = Cards.ByRarity[rarity] or {}
	local found = 0
	for _, card in pool do
		if State.Cards[card.Id] then
			found += 1
		end
	end
	-- Cards in this section after the tab / filter / search.
	local shown = {}
	for _, card in pool do
		local owned = State.Cards[card.Id] ~= nil
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
		BackgroundColor3 = tier.Dark:Lerp(Color3.new(0, 0, 0), 0.3),
		BackgroundTransparency = 0.2,
		Parent = list,
	}, {
		Kit.corner(UDim.new(0, 18)),
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
		Kit.gradient(ColorSequence.new(tier.Color:Lerp(Color3.new(0, 0, 0), 0.15), tier.Dark), 0),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.4),
	})
	if rarity == "Secret" then
		Kit.gradient(Rarity.Gradient("Secret"), 0).Parent = header
	end
	local badge = Kit.new("Frame", {
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = tier.Color,
		Parent = header,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 2, 0) })
	Controls.Outlined(Kit.label({
		Text = CardTile.Letters[rarity],
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.75, 0.75),
		Parent = badge,
	}, 24), 1.5)
	Controls.Outlined(Kit.label({
		Text = string.upper(rarity),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(56, 4),
		Size = UDim2.new(0.4, 0, 0, 26),
		Parent = header,
	}, 26), 2)
	Controls.Outlined(Kit.label({
		Text = `{Odds.FormatPercent(chance)}  ·  {Odds.FormatOneIn(chance)}  ·  {found}/{#pool} found`,
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(235, 230, 255),
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
			Text = `Find all {#pool}:  {rewardText}`,
			Font = Theme.Font.Heavy,
			TextColor3 = Color3.fromRGB(235, 230, 255),
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
			Fusion = if own then own.Fusion else nil,
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
	local width = list.AbsoluteSize.X - 40
	if width > 0 then
		local count = math.clamp(math.floor(width / 120), 3, 9)
		cellSize = math.floor((width - 10 * (count - 1)) / count)
	end
	local total, found = #Cards.List, 0
	for _, card in Cards.List do
		if State.Cards[card.Id] then
			found += 1
		end
	end
	progressLabel.Text = `FOUND {found} / {total}  ·  {math.floor(found / total * 100)}%`
	Kit.tween(progressFill, 0.4, { Size = UDim2.fromScale(math.max(0.02, found / total), 1) })
	for name, set in tabSetters do
		set(name == tab)
	end
	for i, rarity in Rarity.Order do
		section(rarity, i)
	end
end

local function redraw()
	dirty = true
	Index.Refresh()
end

function Index.Init(playerGui: Instance, openOdds: () -> ())
	onOdds = openOdds
	modal = Modal.new(playerGui, "IndexGui", "Index", Vector2.new(0.94, 0.9), Vector2.new(1200, 760))

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
		BackgroundColor3 = Color3.fromRGB(14, 8, 32),
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
		ScrollBarImageColor3 = Color3.fromRGB(170, 130, 255),
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
