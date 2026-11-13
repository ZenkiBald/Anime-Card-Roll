--!strict
-- A pin names a particular pile, even if it currently holds zero copies.
local Borders = require(script.Parent.Borders)
local Cards = require(script.Parent.Cards)

local FusionTarget = {}

function FusionTarget.Key(cardId: string, from: string): string
	return cardId .. ":" .. from
end

function FusionTarget.Read(key: any, owned: any): (string?, string?)
	if type(key) ~= "string" or #key > 100 or type(owned) ~= "table" then return nil, nil end
	local id, from = string.match(key, "^([%w_%-]+):(%a+)$")
	if not id or not from or not Borders.ById[from] or not Borders.Next(from) then return nil, nil end
	if type(owned[id]) ~= "table" or not Cards.Get(id) then return nil, nil end
	return id, from
end

type Progress = { Kind: string, Count: number, Progress: number, Ready: boolean, Text: string }

function FusionTarget.Progress(key: any, owned: any): Progress?
	local id, from = FusionTarget.Read(key, owned)
	if not id or not from then return nil end
	local card = Cards.Get(id)
	if not card then return nil end
	local to = Borders.Next(from)
	local need = Cards.FusionCost(card)
	local count = (owned[id].BorderCopies or {})[from] or 0
	return {
		Kind = "Fusion", Count = count, Progress = math.clamp(count / need, 0, 1), Ready = count >= need,
		Text = if count >= need then `{card.Name} · {to} ready · Find Hoshi ›`
			else `{card.Name} · {count}/{need} {Borders.Get(from).Name} → {to}`,
	}
end

return FusionTarget
