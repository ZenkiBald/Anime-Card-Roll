--!nonstrict
-- Opening Roll Packs (Packs.luau) on the client: asks the server to open some (1, 5, 10 or "all"), keeps the client's copy of
-- the player's cards and packs in step, and plays it: the rarest pulls flip one by one (RewardReveal)
-- under a line that sums up everything the pack gave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared.Packs)
local Borders = require(Shared.Borders)
local Cards = require(Shared.Cards)
local RevealPolicy=require(Shared.RevealPolicy)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local RewardReveal = require(script.Parent.RewardReveal)
local Reveal=require(script.Parent.Reveal)
local State = require(script.Parent.Parent.State)
local CardView = require(script.Parent.CardView)

local PackOpen = {}

local REASONS = {
	TooFast = "One moment...",
	InBattle = "Finish the fight first",
	NoPacks = "You don't have that pack",
	Loading = "Still loading",
}

-- Opens `count` packs of `packId` (default 1; a number or "all"). Returns the server's result (Opened =
-- how many it opened), or nil and a message.
function PackOpen.Open(packId: string, count: (number | string)?): (any, string?, string?)
	local ok, result = pcall(function()
		return Remotes.OpenPack:InvokeServer(packId, count or 1)
	end)
	if not ok or result == nil or not result.Ok then
		return nil, if ok and result then REASONS[result.Reason] or "Couldn't open it" else "Couldn't open it, try again",if ok and result then result.Reason else "Network"
	end
	for id, entry in result.Cards or {} do
		State.Cards[id] = entry
	end
	if result.Quests then
		State.Meta.Quests = result.Quests
	end
	State.ApplyPacks(result.Packs)
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	if result.Summary then State.ApplyRoll({ Summary = result.Summary }) end
	return result, nil
end

-- USE ALL: the server opens the whole pile in one instant bulk draw, whatever its size (one request,
-- retried once if it lands inside the open limiter). `onProgress` / `cancelled` are kept for BAG.
function PackOpen.UseAll(packId,onProgress,cancelled)
	local wanted=State.Packs[packId] or 0
	local result,why,reason=PackOpen.Open(packId,"all")
	if not result and reason=="TooFast" and not cancelled() then
		task.wait(1)
		result,why=PackOpen.Open(packId,"all")
	end
	if not result then return nil,why or "Opening stopped" end
	onProgress(result.Opened,wanted)
	result.Stopped=(State.Packs[packId] or 0)>0 and result.Opened<wanted
	return result,nil
end

-- "100 rolls at 2.40x luck · 3 NEW · Legendary 2 · Epic 9 · Rare 30 ..." (rarest first).
function PackOpen.SummaryText(result): string
	local opened = if (result.Opened or 1) > 1 then `{result.Opened} packs · ` else ""
	local parts = { `{opened}{Kit.commas(result.Rolls)} rolls at {string.format("%.2f", result.Luck or 1)}x luck` }
	if (result.New or 0) > 0 then
		table.insert(parts, `<font color="#FFC42E"><b>{result.New} NEW</b></font>`)
	end
	for i = #Borders.Order, 1, -1 do
		local id = Borders.Order[i]
		local count = result.Counts and result.Counts[id]
		if count and count > 0 then
			table.insert(parts, `<font color="#{Borders.Get(id).Color:ToHex()}">{Borders.Get(id).Name} {Kit.commas(count)}</font>`)
		end
	end
	return table.concat(parts, "  ·  ")
end

-- Grouped receipts include the highlighted cards: every tile count belongs to this opening only.
function PackOpen.ShowSummary(parent: Frame, result)
	local groups = result.Groups or {}
	local heading = Kit.label({ Name = "BatchTitle", Text = `ALL {Kit.commas(result.TotalCards or result.Rolls)} CARDS · {#groups} STACKS`,
		Font = Theme.Font.Heavy, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 25), Parent = parent }, 21)
	heading.TextColor3 = Theme.Color.Gold
	Kit.label({ Text = "Rarest first · every card is already saved", TextColor3 = Theme.Color.Muted,
		Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 20), Parent = parent }, 15)
	local gridArea = Kit.new("ScrollingFrame", { Name = "BatchStacks", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, 0, 1, -53), BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, Parent = parent })
	local grid = Kit.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder,
		CellPadding = UDim2.fromOffset(8, 8), Parent = gridArea })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), Parent = gridArea })
	local function resize()
		local size = Kit.logicalSize(gridArea)
		local columns = if size.X >= 640 then 4 elseif size.X >= 420 then 3 else 2
		grid.CellSize = UDim2.fromOffset(math.max(100, math.floor((size.X - 16 - (columns - 1) * 8) / columns)), 105)
	end
	gridArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)
	for i, group in groups do
		local card = Cards.Get(group.CardId)
		if not card then continue end
		local border = Borders.Get(group.Border)
		local tile = Kit.tile({ Name = "Stack_" .. group.CardId .. "_" .. group.Border, LayoutOrder = i, Parent = gridArea }, border.Color)
		tile:SetAttribute("BatchCount", group.Count)
		local picture = CardView.Art(group.CardId, true) or CardView.Portrait(group.CardId, true, false)
		picture.Position = UDim2.new(0, 5, 0, 8)
		picture.Size = UDim2.new(0, 58, 1, -16)
		picture.Parent = tile
		Kit.label({ Text = card.Name, Font = Theme.Font.Heavy, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 70, 0, 6), Size = UDim2.new(1, -76, 0, 38), Parent = tile }, 16)
		Kit.label({ Text = border.Name .. " · " .. Kit.commas(group.Rarity), TextColor3 = border.Color,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 70, 0, 46), Size = UDim2.new(1, -76, 0, 18), Parent = tile }, 12)
		Kit.label({ Text = "×" .. Kit.commas(group.Count), Font = Theme.Font.Display, TextColor3 = Theme.Color.Gold,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 70, 0, 66), Size = UDim2.new(1, -76, 0, 31), Parent = tile }, 28)
	end
	return gridArea
end

-- One batch screen: five best pulls first, then all quantities. Animation never reapplies ownership.
function PackOpen.Play(area: Frame, result, onDone: (() -> ())?)
	local pack = Packs.ById[result.PackId]
	Kit.label({
		Name = "PackSummary",
		Text = `{if pack then string.upper(pack.Name) .. "  ·  " else ""}{PackOpen.SummaryText(result)}`,
		RichText = true,
		Font = Theme.Font.Heavy,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = area,
	}, 18)
	local fan = Kit.new("Frame", {
		Name = "Fan",
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		Parent = area,
	})
	local function finish()
		if not fan.Parent then return end
		for _, child in fan:GetChildren() do child:Destroy() end
		PackOpen.ShowSummary(fan, result)
		if onDone then onDone() end
	end
	local settings=RevealPolicy.Read(State.Meta)
	local chosen=RevealPolicy.Select(result.Reveals or result.Results or {},settings)
	if #chosen==0 then finish()
	elseif settings.RevealStyle=="Cinematic" then
		task.spawn(function()
			for _,card in chosen do
				if not fan.Parent then return end
				local done=false
				Reveal.Full(card,function() done=true end)
				while not done and fan.Parent do task.wait(.05) end
			end
			finish()
		end)
	else RewardReveal.Play(fan, { Results = chosen, AlreadyApplied = true }, finish) end
end

return PackOpen
