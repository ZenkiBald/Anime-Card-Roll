--!nonstrict
-- Compact presentation receipts; ownership is applied by RollService before any reveal.
local Cards = require(script.Parent.Cards)
local Packs = require(script.Parent.Packs)
local Batch = {}
Batch.HighlightCount = Packs.ShowCards
-- One request opens the whole selection in a single bulk draw (RollService), so this is only a sanity
-- ceiling on pulls per request, far above any real pile; the work doesn't grow with the count.
Batch.MaxRolls = 1e12

function Batch.OpenCount(packId, requested, held)
	local pack = Packs.ById[packId]
	if not pack then return nil end
	local wanted = if requested == "all" then math.huge elseif requested == nil then 1 else requested
	if type(wanted) ~= "number" or wanted ~= wanted or wanted < 1 then return nil end
	if requested ~= "all" and wanted == math.huge then return nil end
	return math.min(math.floor(wanted), math.max(0, held), math.max(1, Batch.MaxRolls // pack.Rolls))
end

function Batch.Rarer(a, b)
	local ar = a.Rarity or Cards.Rarity(a.CardId, a.Border)
	local br = b.Rarity or Cards.Rarity(b.CardId, b.Border)
	if ar ~= br then return ar > br end
	if a.CardId ~= b.CardId then return a.CardId < b.CardId end
	return (a.Border or "Normal") < (b.Border or "Normal")
end

function Batch.New()
	return { Rolls = 0, New = 0, Counts = {}, Groups = {}, Results = {} }
end

function Batch.Add(batch, result)
	local border = result.Border or "Normal"
	batch.Rolls += 1
	batch.Counts[border] = (batch.Counts[border] or 0) + 1
	if result.Outcome == "New" then batch.New += 1 end
	local key = result.CardId .. ":" .. border
	local group = batch.Groups[key]
	if not group then
		group = { CardId = result.CardId, Border = border, Count = 0, Rarity = Cards.Rarity(result.CardId, border), Foil=result.Foil }
		batch.Groups[key] = group
	end
	group.Count += 1
	group.NewBorder = group.NewBorder or result.NewBorder == true
	group.Outcome = if group.Outcome == "New" or result.Outcome == "New" then "New" else "Copy"
	local receipt = { CardId = result.CardId, Border = border, Foil = result.Foil,
		Outcome = result.Outcome, NewBorder = result.NewBorder, Rarity = group.Rarity }
	local shown = batch.Results
	if #shown < Batch.HighlightCount or Batch.Rarer(receipt, shown[#shown]) then
		table.insert(shown, receipt)
		table.sort(shown, Batch.Rarer)
		if #shown > Batch.HighlightCount then table.remove(shown) end
	end
end

-- `count` pulls of one card at one border at once (bulk pack opening): one group, one highlight receipt.
function Batch.AddGroup(batch, cardId, border, count, outcome, newBorder, foil, newFoil)
	batch.Rolls += count
	batch.Counts[border] = (batch.Counts[border] or 0) + count
	if outcome == "New" then batch.New += 1 end
	local key = cardId .. ":" .. border
	local group = batch.Groups[key]
	if not group then
		group = { CardId = cardId, Border = border, Count = 0, Rarity = Cards.Rarity(cardId, border), Foil = foil }
		batch.Groups[key] = group
	end
	group.Count += count
	group.NewBorder = group.NewBorder or newBorder == true
	group.Outcome = if group.Outcome == "New" or outcome == "New" then "New" else "Copy"
	local receipt = { CardId = cardId, Border = border, Foil = foil, NewFoil = newFoil,
		Outcome = outcome, NewBorder = newBorder, Rarity = group.Rarity, Count = count }
	local shown = batch.Results
	if #shown < Batch.HighlightCount or Batch.Rarer(receipt, shown[#shown]) then
		table.insert(shown, receipt)
		table.sort(shown, Batch.Rarer)
		if #shown > Batch.HighlightCount then table.remove(shown) end
	end
end

function Batch.Finish(batch)
	local groups = {}
	for _, group in batch.Groups do table.insert(groups, group) end
	table.sort(groups, Batch.Rarer)
	batch.Groups = groups
	batch.Reveals={}
	for _,g in groups do table.insert(batch.Reveals,{CardId=g.CardId,Border=g.Border,Foil=g.Foil,Outcome=g.Outcome,NewBorder=g.NewBorder,Rarity=g.Rarity}) end
	return batch
end

-- Merge completed server chunks without keeping individual pulls in memory.
function Batch.Accumulate(target,result)
	target.Rolls+=result.Rolls or 0
	target.TotalCards=(target.TotalCards or 0)+(result.TotalCards or result.Rolls or 0)
	target.Opened=(target.Opened or 0)+(result.Opened or 0)
	target.New+=result.New or 0
	target.PackId=result.PackId;target.Luck=result.Luck
	for id,n in result.Counts or {} do target.Counts[id]=(target.Counts[id] or 0)+n end
	for _,g in result.Groups or {} do
		local key=g.CardId..":"..g.Border
		local held=target.Groups[key]
		if held then
			held.Count+=g.Count
			held.NewBorder=held.NewBorder or g.NewBorder
			if g.Outcome=="New" then held.Outcome="New" end
		else target.Groups[key]=table.clone(g) end
	end
end

return Batch
