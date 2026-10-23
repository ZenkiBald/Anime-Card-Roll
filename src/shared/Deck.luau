--!strict
-- Deck rules, shared so the deck screen shows exactly what the server accepts.
-- A deck is 4 Attack slots (front row) + 4 Support slots (back row). "" is an empty slot.
-- Rules: each slot takes only its type, no card twice, only owned cards, empty slots allowed.

local Config = require(script.Parent.Config)
local Cards = require(script.Parent.Cards)
local Borders = require(script.Parent.Borders)

export type Deck = { Attack: { string }, Support: { string } }
export type Owned = { [string]: { Copies: number, Stars: number, Fusion: number?, Borders: { [string]: boolean }? } }

local Deck = {}

Deck.Rows = { "Attack", "Support" }

function Deck.Empty(): Deck
	local deck: Deck = { Attack = {}, Support = {} }
	for i = 1, Config.Deck.Slots do
		deck.Attack[i] = ""
		deck.Support[i] = ""
	end
	return deck
end

function Deck.Copy(deck: Deck): Deck
	return { Attack = table.clone(deck.Attack), Support = table.clone(deck.Support) }
end

-- Checks a deck sent by a client. Returns a clean copy, or nil and the reason.
function Deck.Validate(raw: unknown, owned: Owned): (Deck?, string?)
	if type(raw) ~= "table" then
		return nil, "BadDeck"
	end
	local input = raw :: { [unknown]: unknown }
	for key in input do
		if key ~= "Attack" and key ~= "Support" then
			return nil, "BadDeck"
		end
	end

	local deck = Deck.Empty()
	local seen: { [string]: boolean } = {}
	for _, row in Deck.Rows do
		local slots = input[row]
		if type(slots) ~= "table" then
			return nil, "BadDeck"
		end
		local count = 0
		for key, id in slots :: { [unknown]: unknown } do
			count += 1
			if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > Config.Deck.Slots then
				return nil, "BadDeck"
			end
			if type(id) ~= "string" then
				return nil, "BadDeck"
			end
			if id ~= "" then
				local card = Cards.Get(id)
				if card == nil then
					return nil, "BadDeck"
				end
				if card.Type ~= row then
					return nil, "WrongType"
				end
				if owned[id] == nil then
					return nil, "NotOwned"
				end
				if seen[id] then
					return nil, "Duplicate"
				end
				seen[id] = true
			end
			(deck :: any)[row][key] = id
		end
		if count ~= Config.Deck.Slots then
			return nil, "BadDeck"
		end
	end
	return deck, nil
end

-- Drops cards the player no longer owns (e.g. after a test-data reset).
function Deck.Clean(deck: Deck, owned: Owned): Deck
	local clean = Deck.Copy(deck)
	for _, row in Deck.Rows do
		local slots = (clean :: any)[row] :: { string }
		for i, id in slots do
			if id ~= "" and owned[id] == nil then
				slots[i] = ""
			end
		end
	end
	return clean
end

-- Card power with the owner's stars, fusions and best border.
function Deck.CardPower(id: string, owned: Owned): number
	local card = Cards.Get(id)
	if card == nil then
		return 0
	end
	local entry = owned[id]
	return if entry then Cards.Power(card, entry.Stars, entry.Fusion, Borders.Best(entry.Borders)) else Cards.Power(card, 0)
end

-- Deck Power: the sum of the cards in it.
function Deck.Power(deck: Deck, owned: Owned): number
	local total = 0
	for _, row in Deck.Rows do
		for _, id in (deck :: any)[row] :: { string } do
			if id ~= "" then
				total += Deck.CardPower(id, owned)
			end
		end
	end
	return total
end

function Deck.Count(deck: Deck, row: string): number
	local n = 0
	for _, id in (deck :: any)[row] :: { string } do
		if id ~= "" then
			n += 1
		end
	end
	return n
end

-- Fills each row with the highest-power cards owned, strongest on the left.
function Deck.AutoBuild(owned: Owned): Deck
	local deck = Deck.Empty()
	for _, row in Deck.Rows do
		local pool = {}
		for id in owned do
			local card = Cards.Get(id)
			if card and card.Type == row then
				table.insert(pool, id)
			end
		end
		table.sort(pool, function(a, b)
			local pa, pb = Deck.CardPower(a, owned), Deck.CardPower(b, owned)
			if pa ~= pb then
				return pa > pb
			end
			return a < b
		end)
		for i = 1, math.min(#pool, Config.Deck.Slots) do
			(deck :: any)[row][i] = pool[i]
		end
	end
	return deck
end

return Deck
