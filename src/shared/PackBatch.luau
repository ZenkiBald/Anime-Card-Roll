--!nonstrict
-- Compact presentation receipts; ownership is applied by RollService before any reveal.
local Cards = require(script.Parent.Cards)
local Packs = require(script.Parent.Packs)
local Batch = {}
Batch.HighlightCount = Packs.ShowCards
Batch.MaxRolls = 10000

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
		group = { CardId = result.CardId, Border = border, Count = 0, Rarity = Cards.Rarity(result.CardId, border) }
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

function Batch.Finish(batch)
	local groups = {}
	for _, group in batch.Groups do table.insert(groups, group) end
	table.sort(groups, Batch.Rarer)
	batch.Groups = groups
	return batch
end

return Batch
