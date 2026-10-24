--!nonstrict
-- BAG: everything you carry as one grid of small square tiles (like a backpack): a rarity badge
-- top-left, the count top-right, the item's colour round the edge, and a timer / level / WORN tag along
-- the bottom. Tabs filter it (ALL / PACKS / POTIONS / ARTIFACTS) and SEARCH finds by name.
-- Tapping a tile shows it on the right with what you can do with it:
--   Roll Packs: OPEN 1 / 5 / 10 / ALL (rolls at your luck now, even during Auto Roll; the pulls play over
--   the bag, PackOpen)
--   Potions: USE / BUY      Artifacts: WEAR / REMOVE (3 slots)
-- The server checks every action (MetaService, RollService "OpenPack").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Packs = require(Shared.Packs)
local Rarity = require(Shared.Rarity)

local Kit = require(script.Parent.Kit)
local IconBadge = require(script.Parent.Components.IconBadge)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)
local PackOpen = require(script.Parent.PackOpen)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Bag = {}

local TABS = {
	{ Name = "ALL", Color = Color3.fromRGB(255, 196, 46) },
	{ Name = "PACKS", Color = Color3.fromRGB(255, 160, 60) },
	{ Name = "POTIONS", Color = Color3.fromRGB(86, 214, 138) },
	{ Name = "RELICS", Color = Color3.fromRGB(255, 120, 220) },
	{ Name = "ARTIFACTS", Color = Color3.fromRGB(255, 140, 90) },
}
-- Kind "Artifact" is a relic (Items.Artifacts, worn in 3 slots); "TowerArtifact" an artifact (always on).
local KIND_ORDER = { Pack = 1, Potion = 2, Artifact = 3, TowerArtifact = 4 }
local KIND_TAB = { Pack = "PACKS", Potion = "POTIONS", Artifact = "RELICS", TowerArtifact = "ARTIFACTS" }
local KIND_NAME = { Pack = "Pack", Potion = "Potion", Artifact = "Relic", TowerArtifact = "Artifact" }
local GOLD_DEEP = Color3.fromRGB(150, 100, 10)

local modal
local grid: ScrollingFrame
local detail: ScrollingFrame
local summaryLabel: TextLabel
local hintLabel: TextLabel
local tabSetters = {}
local currentTab = "ALL"
local search = ""
local selectedKey: string? = nil
local tiles = {} -- [key] = { Button, Sub, Entry } so timers tick without a rebuild
local busy = false -- a pack reveal is over the bag
local hintToken = 0

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.2, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function clock(seconds: number): string
	seconds = math.ceil(seconds)
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function gear()
	return State.Meta.Gear or Items.Empty()
end

-- Every item the bag shows for the current tab and search: what you hold, and on a tab of its own
-- kind also the packs and potions you could get (greyed out).
local function entries()
	local list = {}
	local function add(entry)
		local tabOk = currentTab == "ALL" or KIND_TAB[entry.Kind] == currentTab
		local held = entry.Count > 0 or entry.Worn == true or entry.Running == true
		if tabOk and (held or currentTab ~= "ALL") and (search == "" or string.find(string.lower(entry.Name), search, 1, true)) then
			table.insert(list, entry)
		end
	end
	for i, pack in Packs.List do
		local count = State.Packs[pack.Id] or 0
		if pack.Element == nil or count > 0 then -- infused packs show only once you have one
			add({ Key = `Pack:{pack.Id}`, Kind = "Pack", Id = pack.Id, Item = pack, Name = pack.Name, Icon = pack.Icon, Color = pack.Color, Count = count, Order = i })
		end
	end
	for i, potion in Meta.Potions do
		add({
			Key = `Potion:{potion.Id}`,
			Kind = "Potion",
			Id = potion.Id,
			Item = potion,
			Name = potion.Name,
			Icon = potion.Icon,
			Color = potion.Color,
			Count = State.Meta.Inventory[potion.Id] or 0,
			Running = State.PotionLeft(potion.Id) > 0,
			Order = i,
		})
	end
	local data = gear()
	local worn = {}
	for _, id in data.Worn or {} do
		worn[id] = true
	end
	for i, artifact in Items.Artifacts do
		local level = (data.Artifacts or {})[artifact.Id]
		if level then
			add({
				Key = `Artifact:{artifact.Id}`,
				Kind = "Artifact",
				Id = artifact.Id,
				Item = artifact,
				Name = artifact.Name,
				Icon = artifact.Icon,
				Color = Rarity.Get(artifact.Rarity).Color,
				Rarity = artifact.Rarity,
				Count = 1,
				Level = level,
				Worn = worn[artifact.Id] == true,
				Order = i,
			})
		end
	end
	for i, artifact in Items.TowerArtifacts do
		if (data.TowerArtifacts or {})[artifact.Id] then
			add({
				Key = `TowerArtifact:{artifact.Id}`,
				Kind = "TowerArtifact",
				Id = artifact.Id,
				Item = artifact,
				Name = artifact.Name,
				Icon = artifact.Icon,
				Color = Color3.fromRGB(255, 140, 90),
				Count = 1,
				Worn = true, -- always on
				Order = i,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Kind ~= b.Kind then
			return KIND_ORDER[a.Kind] < KIND_ORDER[b.Kind]
		end
		local ra = if a.Rarity then Rarity.Index(a.Rarity) else 0
		local rb = if b.Rarity then Rarity.Index(b.Rarity) else 0
		if ra ~= rb then
			return ra > rb
		end
		return a.Order < b.Order
	end)
	return list
end

-- The tag along a tile's bottom: a potion's time left, an artifact's level, WORN, a pack's size.
local function subText(entry): (string, Color3)
	if entry.Kind == "Potion" and entry.Running then
		return clock(State.PotionLeft(entry.Id)), Theme.Color.Quick
	elseif entry.Kind == "Artifact" then
		return if entry.Worn then `WORN · Lv{entry.Level}` else `Lv{entry.Level}`, if entry.Worn then Theme.Color.Gold else Theme.Color.Text
	elseif entry.Kind == "TowerArtifact" then
		return "ALWAYS ON", Color3.fromRGB(255, 140, 90)
	elseif entry.Kind == "Pack" then
		return `{Kit.commas(entry.Item.Rolls)} rolls`, Theme.Color.Text
	end
	return "", Theme.Color.Text
end

-- A relic plaque's frame by rarity (no letter badges: the frame says it): bronze Rare, purple Epic,
-- gold Legendary, cosmic crimson Mythic (a two-tone sweep).
local RELIC_FRAME = {
	Rare = { Color = Color3.fromRGB(176, 141, 87), Thickness = 1.5 },
	Epic = { Color = Color3.fromRGB(150, 80, 220), Thickness = 2 },
	Legendary = { Color = Color3.fromRGB(255, 200, 60), Thickness = 2.5 },
	Mythic = { Color = Color3.fromRGB(220, 30, 70), Thickness = 3, Sweep = Color3.fromRGB(120, 40, 220) },
}

-- What sits in a tile's diamond crest: a pack's roll count (a sealed chest of 10 / 100 / 1K rolls), else
-- the item's own glyph.
local function crestOf(entry): string
	if entry.Kind == "Pack" then
		local rolls = entry.Item.Rolls
		return if rolls >= 1000 then `{rolls // 1000}K` else tostring(rolls)
	end
	return entry.Icon
end

-- One square tile: an Urushi plaque framed in the item's colour (a relic's by rarity), its crest in a
-- diamond IconBadge, the count top-right and a short tag along the bottom.
local function tile(entry, order: number)
	local held = entry.Count > 0 or entry.Worn == true or entry.Running == true
	local C = UITheme.Colors
	local frame = if entry.Rarity then RELIC_FRAME[entry.Rarity] else nil
	local edge = if frame then frame.Color else entry.Color
	local button = Kit.new("TextButton", {
		Name = entry.Key,
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = grid,
	}, {
		Kit.corner(UDim.new(0, 6)),
		Kit.gradient(ColorSequence.new(C.UrushiRaised, C.UrushiBase:Lerp(edge, 0.08)), 90),
	})
	local stroke = Kit.stroke(edge, if entry.Key == selectedKey then 3.5 elseif frame then frame.Thickness else 1.5, if held then 0 else 0.55)
	stroke.Parent = button
	if frame and frame.Sweep then
		Kit.gradient(ColorSequence.new(frame.Color, frame.Sweep), 45).Parent = stroke
	end
	local crest = IconBadge.new({
		Name = "Icon",
		IconAsset = crestOf(entry),
		GlowColor = edge,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.64, 0.64),
		ZIndex = 2,
		Parent = button,
	})
	if not held then
		for _, d in crest:GetDescendants() do
			if d:IsA("TextLabel") then
				d.TextTransparency = 0.55
			end
		end
	end
	local count = Kit.label({
		Name = "Count",
		Text = `x{Kit.commas(entry.Count)}`,
		Font = Theme.Font.Display,
		TextColor3 = if entry.Count > 0 then UITheme.Colors.WashiParchment else UITheme.Colors.WashiGhost,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.94, 0.06),
		Size = UDim2.fromScale(0.6, 0.2),
		ZIndex = 3,
		Parent = button,
	}, 18)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.1).Parent = count
	local text, color = subText(entry)
	local sub = Kit.label({
		Name = "Sub",
		Text = text,
		Font = Theme.Font.Heavy,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.9, 0.2),
		ZIndex = 3,
		Parent = button,
	}, 14)
	Kit.textStroke(Color3.new(0, 0, 0), 1.2, 0.1).Parent = sub
	Kit.pressable(button)
	button.Activated:Connect(function()
		selectedKey = entry.Key
		Bag.Refresh()
	end)
	tiles[entry.Key] = { Button = button, Sub = sub, Entry = entry }
end

-- Detail panel ------------------------------------------------------------------------------------

local function detailText(order: number, value: string, color: Color3, size: number, font: Enum.Font?): TextLabel
	return Kit.label({
		LayoutOrder = order,
		Text = value,
		RichText = true,
		Font = font or Theme.Font.Bold,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextScaled = false,
		TextSize = size,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
		Parent = detail,
	}, size)
end

local function actionRow(order: number): Frame
	return Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = detail,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
end

local function action(row: Frame, text: string, color: Color3, deep: Color3, order: number, enabled: boolean, onClick: () -> ())
	local button = Kit.button(text, color, deep, {
		LayoutOrder = order,
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = row,
	})
	Kit.dim(button, not enabled)
	button.Activated:Connect(onClick)
	return button
end

local function call(name: string, arg: any, okText: string?): boolean
	local result = MetaClient.Call(name, arg)
	if result.Ok then
		Sfx.Play("Upgrade", 1.2)
		if okText then
			hint(okText)
		end
	else
		hint(MetaClient.Message(result))
	end
	return result.Ok
end

-- A cover over the whole bag (pack reveals); close() takes it away.
local function cover(): (Frame, () -> ())
	busy = true
	local frame = Kit.new("Frame", {
		Name = "Cover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 7, 11),
		BackgroundTransparency = 0.04,
		Active = true,
		ZIndex = 30,
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 18)) })
	local function close()
		frame:Destroy()
		busy = false
		Bag.Refresh()
	end
	return frame, close
end

local function openPack(pack, count: (number | string)?)
	if busy then
		return
	end
	local result, message = PackOpen.Open(pack.Id, count)
	if result == nil then
		hint(message or "Couldn't open it")
		return
	end
	Sfx.Play("Whoosh", 0.9)
	local frame, close = cover()
	local area = Kit.new("Frame", {
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(1, -24, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = frame,
	})
	local buttons = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(400, 48),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 32,
		Parent = frame,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local done = Kit.button("DONE", Theme.Color.Quick, Theme.Color.QuickDeep, { LayoutOrder = 1, Size = UDim2.fromOffset(170, 48), Parent = buttons })
	done.Activated:Connect(close)
	if (State.Packs[pack.Id] or 0) > 0 then
		local again = Kit.button(if count == "all" then "OPEN MORE" elseif (count or 1) == 1 then "OPEN ANOTHER" else `OPEN {count} MORE`, Theme.Color.Gold, GOLD_DEEP, { LayoutOrder = 2, Size = UDim2.fromOffset(200, 48), Parent = buttons })
		again.Activated:Connect(function()
			close()
			openPack(pack, count)
		end)
	end
	PackOpen.Play(area, result, function()
		if buttons.Parent then
			buttons.Visible = true
		end
	end)
end

local function showDetail(entry)
	clear(detail)
	detail:SetAttribute("Timer", nil)
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = detail })
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = detail,
	})
	if entry == nil then
		detailText(1, "Tap an item to see what it does.", Theme.Color.Muted, 18, Theme.Font.Heavy)
		return
	end
	local item = entry.Item
	-- The big icon and the name.
	local big = Kit.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = detail,
	}, {
		Kit.corner(UDim.new(0, 16)),
		Kit.gradient(ColorSequence.new(UITheme.Colors.UrushiRaised, UITheme.Colors.UrushiInset), 90),
		Kit.stroke(entry.Color, 3, 0),
	})
	IconBadge.new({
		IconAsset = crestOf(entry),
		GlowColor = entry.Color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		DominantAxis = Enum.DominantAxis.Height,
		Parent = big,
	})
	local name = detailText(2, string.upper(entry.Name), entry.Color, 24, Theme.Font.Display)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = name
	local kindName = KIND_NAME[entry.Kind] or entry.Kind
	local kindText = if entry.Rarity then `{entry.Rarity} {kindName}` else kindName
	detailText(3, `{kindText}  ·  You have <b>{Kit.commas(entry.Count)}</b>`, Theme.Color.Muted, 15, Theme.Font.Heavy)

	if entry.Kind == "Pack" then
		detailText(
			4,
			`<b>{Kit.commas(item.Rolls)} rolls</b> at your luck when you open it: <font color="#56D68A"><b>{string.format("%.2f", State.Luck())}x</b></font> right now. Open it during a luck potion or LUCKY STORM for better cards!`,
			Theme.Color.Text,
			16
		)
		if item.Element then
			detailText(
				5,
				`Infused: <b>{item.Element}</b> cards weigh x{Packs.InfuseWeight} inside each rarity, and border odds double if you open it during LUCKY STORM, Raid Luck or a Luck Totem.`,
				Theme.Color.Gold,
				15
			)
		end
		-- OPEN 1 / 5 / 10 / ALL (a choice you don't have enough for is dimmed; ALL opens up to 10,000 rolls
		-- a go). Packs open while Auto Roll runs too.
		local function opener(row: Frame, label: string, count: number | string, order: number)
			local enough = if count == "all" then entry.Count > 0 else entry.Count >= (count :: number)
			action(row, label, UITheme.Colors.VermilionHover, UITheme.Colors.VermilionWax, order, enough, function()
				if (State.Packs[item.Id] or 0) <= 0 then
					hint("Beat bosses and every 5th tower floor for packs")
				elseif not enough then
					hint(`You have {State.Packs[item.Id] or 0}`)
				else
					openPack(item, count)
				end
			end)
		end
		-- A compact 2 x 2 grid of seals.
		local row = actionRow(6)
		row.Size = UDim2.new(1, 0, 0, 38)
		opener(row, "OPEN 1", 1, 1)
		opener(row, "OPEN 5", 5, 2)
		local row2 = actionRow(7)
		row2.Size = UDim2.new(1, 0, 0, 38)
		opener(row2, "OPEN 10", 10, 1)
		opener(row2, `OPEN ALL ({Kit.commas(entry.Count)})`, "all", 2)
		-- Condensing and infusing are done in town, at Hoshi's PACK ALCHEMY.
		if Packs.Condense[item.Id] or item.Id == "1000" then
			detailText(8, "⚗️ Condense 10 into a bigger pack, or infuse a Mega Pack with an element: visit Hoshi the Fusion Master in town.", Theme.Color.Muted, 14, Theme.Font.Heavy)
		end
	elseif entry.Kind == "Potion" then
		detailText(4, item.Text, Theme.Color.Text, 17, Theme.Font.Heavy)
		local left = State.PotionLeft(item.Id)
		detail:SetAttribute("Timer", item.Id)
		local timer = detailText(5, if left > 0 then `RUNNING · {clock(left)} left` else "Not running", if left > 0 then Theme.Color.Quick else Theme.Color.Muted, 16, Theme.Font.Heavy)
		timer.Name = "Timer"
		detailText(6, "The same kind adds time (up to 1 hour). Luck potions don't stack: the strongest counts. Timers only run while you play.", Theme.Color.Muted, 13)
		local row = actionRow(7)
		action(row, "USE", item.Color, item.Color:Lerp(Color3.new(0, 0, 0), 0.45), 1, entry.Count > 0, function()
			if call("UsePotion", item.Id, `{item.Name} running!`) then
				Sfx.Play("Potion") -- the bag redraws with the new timer (State.Changed)
			end
		end)
		action(row, `BUY 💎{item.Price}`, Theme.Color.Accent, Theme.Color.AccentDeep, 2, (State.Summary.Shards or 0) >= item.Price, function()
			call("BuyPotion", item.Id, `Bought a {item.Name}`)
		end)
	elseif entry.Kind == "Artifact" then
		detailText(4, `Lv {entry.Level}/{Items.MaxLevel}: <b>{Items.ArtifactText(item, entry.Level)}</b>`, Theme.Color.Gold, 17, Theme.Font.Heavy)
		if entry.Level < Items.MaxLevel then
			detailText(5, `A duplicate raises it to Lv {entry.Level + 1}: {Items.ArtifactText(item, entry.Level + 1)}`, Theme.Color.Muted, 14)
		else
			detailText(5, `Max level: duplicates melt into 💎{Items.MeltShards[item.Rarity] or 100} Shards.`, Theme.Color.Muted, 14)
		end
		local worn = gear().Worn or {}
		detailText(6, `Relics worn: <b>{#worn}/{Items.ArtifactSlots}</b>  ·  relics drop only in the Infinite Tower, from floor {Items.RelicFloor} (0.1% a win)`, Theme.Color.Text, 15, Theme.Font.Heavy)
		local row = actionRow(7)
		if entry.Worn then
			action(row, "REMOVE", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), 1, true, function()
				call("RemoveArtifact", item.Id, `{item.Name} put back in the bag`)
			end)
		else
			action(row, "WEAR", Theme.Color.Gold, GOLD_DEEP, 1, #worn < Items.ArtifactSlots, function()
				if #worn >= Items.ArtifactSlots then
					hint("All 3 relic slots are full: remove one first")
					return
				end
				call("WearArtifact", item.Id, `{item.Name} worn: {Items.ArtifactText(item, entry.Level)}`)
			end)
		end
	elseif entry.Kind == "TowerArtifact" then
		detailText(4, `<b>{Items.TowerArtifactText(item)}</b>`, Color3.fromRGB(255, 140, 90), 17, Theme.Font.Heavy)
		detailText(5, `Always on, no slot needed. Earned once: {item.Source}.`, Theme.Color.Muted, 14)
	end
end

-- Drawing ---------------------------------------------------------------------------------------

function Bag.Refresh()
	if not modal or not modal.IsOpen or busy then
		return
	end
	summaryLabel.Text = string.format(
		'Luck <font color="#56D68A"><b>%.2fx</b></font>   ·   Roll cooldown <font color="#50B4FF"><b>%.2fs</b></font>   ·   💎 <b>%s</b>   ·   🧬 <b>%s</b>   ·   Packs <b>%s</b>   ·   Relics worn <b>%d/%d</b>',
		State.Luck(),
		State.Cooldown(),
		Kit.commas(State.Summary.Shards or 0),
		Kit.commas(State.Summary.TraitShards or 0),
		Kit.commas(Packs.Count(State.Packs)),
		#(gear().Worn or {}),
		Items.ArtifactSlots
	)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(tiles)
	local list = entries()
	local selected = nil
	for _, entry in list do
		if entry.Key == selectedKey then
			selected = entry
		end
	end
	if selected == nil then
		selected = list[1]
		selectedKey = selected and selected.Key
	end
	for i, entry in list do
		tile(entry, i)
	end
	if #list == 0 then
		Kit.label({
			Text = if search ~= "" then "Nothing matches that search." else "Nothing here yet: beat bosses, climb the tower and claim QUESTS gifts.",
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Muted,
			TextWrapped = true,
			Size = UDim2.fromOffset(400, 60),
			Parent = grid,
		}, 18)
	end
	showDetail(selected)
end

-- Timers tick once a second without rebuilding the grid.
local function tickTimers()
	if not modal.IsOpen or busy then
		return
	end
	for _, refs in tiles do
		if refs.Entry.Kind == "Potion" and refs.Entry.Running then
			local text, color = subText(refs.Entry)
			refs.Sub.Text = text
			refs.Sub.TextColor3 = color
		end
	end
	local timer = detail:FindFirstChild("Timer")
	local id = detail:GetAttribute("Timer")
	if timer and type(id) == "string" then
		local left = State.PotionLeft(id)
		timer.Text = if left > 0 then `RUNNING · {clock(left)} left` else "Not running"
	end
end

local function showTab(name: string)
	currentTab = name
	for tab, set in tabSetters do
		set(tab == name)
	end
	selectedKey = nil
	Bag.Refresh()
end

function Bag.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "BagGui", "BAG", Vector2.new(0.84, 0.84), Vector2.new(1000, 640))

	Controls.Search(modal.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66, 0, 10),
		Size = UDim2.new(0.24, 0, 0, 38),
	}, function(text)
		search = text
		Bag.Refresh()
	end)
	hintLabel = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.76, -76, 0, 18),
		Size = UDim2.new(0.34, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = modal.Header,
	}, 16)

	local tabRow = Kit.new("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	for i, tab in TABS do
		local button, set = Controls.Tab(tabRow, tab.Name, tab.Color, i, if tab.Name == "ALL" then 90 else 150)
		tabSetters[tab.Name] = set
		button.Activated:Connect(function()
			showTab(tab.Name)
		end)
	end
	summaryLabel = Kit.label({
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 2, 0, 46),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = modal.Body,
	}, 15)

	grid = Kit.new("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.new(0, 0, 0, 72),
		Size = UDim2.new(0.66, 0, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(96, 96),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})
	detail = Kit.new("ScrollingFrame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 72),
		Size = UDim2.new(0.33, 0, 1, -72),
		BackgroundColor3 = Color3.fromRGB(7, 9, 14),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0, 16)), Kit.stroke(Theme.Color.TileEdge, 1.5, 0.5) })

	modal.OnOpen = function()
		showTab(currentTab)
	end
	State.Changed:Connect(function(kind)
		if kind ~= "roll" then
			Bag.Refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tickTimers()
		end
	end)
end

function Bag.Toggle()
	modal:Toggle()
end

-- Opens the BAG on its PACKS tab.
function Bag.OpenPacks()
	currentTab = "PACKS"
	modal:Open()
end

return Bag
