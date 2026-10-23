--!strict
-- Deck rules, shared so the deck screen shows exactly what the server accepts.
-- A deck is 4 Attack slots (front row) + 4 Support slots (back row). "" is an empty slot.
-- Rules: each slot takes only its type, no card twice, only owned cards, empty slots allowed.

local Config = require(script.Parent.Config)
local Cards = require(script.Parent.Cards)
local Borders = require(script.Parent.Borders)
local Elements = require(script.Parent.Elements)
local Awaken = require(script.Parent.Awaken)

export type Deck = { Attack: { string }, Support: { string } }
export type Owned = { [string]: { Copies: number, Stars: number, Fusion: number?, Borders: { [string]: boolean }?, BorderCopies: { [string]: number }?, Awaken: number? } }

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

-- Card power with the owner's stars, best border (the tier) and Awakening.
function Deck.CardPower(id: string, owned: Owned): number
	local card = Cards.Get(id)
	if card == nil then
		return 0
	end
	local entry = owned[id]
	return if entry
		then Cards.Power(card, entry.Stars, Borders.Best(entry.Borders), Awaken.Level(entry :: any))
		else Cards.Power(card, 0)
end

-- The player's "rarest" card: the best border worn, then the least likely card (lowest Weight).
-- A score for leaderboards too: border index x 1000 + how rare the card is (0-999).
function Deck.Rarest(owned: Owned): (string?, string, number)
	local bestId, bestBorder, bestScore = nil, "Normal", -1
	for id, entry in owned do
		local card = Cards.Get(id)
		if card then
			local border = Borders.Best(entry.Borders)
			local score = Borders.Index(border) * 1000 + math.clamp(math.floor(999 - card.Weight * 50), 0, 999)
			if score > bestScore then
				bestId, bestBorder, bestScore = id, border, score
			end
		end
	end
	return bestId, bestBorder, math.max(bestScore, 0)
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

-- Deck Cost: each card's Cards.Cost (by the border it wears), for the Cost Challenge
-- (Config.Deck.CostCap). Without `owned`, every card counts as Base.
function Deck.Cost(deck: Deck, owned: Owned?): number
	local total = 0
	for _, row in Deck.Rows do
		for _, id in (deck :: any)[row] :: { string } do
			local card = Cards.Get(id)
			if card then
				local entry = owned and owned[id]
				total += Cards.Cost(if entry then Borders.Best(entry.Borders) else nil)
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
-- How much a card is worth against a squad of these elements (one entry per enemy, the leader can count
-- twice): its power x its average damage multiplier, and for Attack cards / the average multiplier of
-- the hits it takes. 1 against no one in particular.
function Deck.MatchupValue(cardId: string, against: { string }?): number
	local card = Cards.Get(cardId)
	if card == nil or against == nil or #against == 0 then
		return 1
	end
	local dealt, taken = 0, 0
	for _, element in against do
		dealt += Elements.Multiplier(card.Element, element)
		taken += Elements.Multiplier(element, card.Element)
	end
	dealt /= #against
	taken /= #against
	return if card.Type == "Attack" then dealt / taken else dealt
end

-- The card elements in a deck, slot by slot (for synergies).
function Deck.Elements(deck: Deck): { string }
	local list = {}
	for _, row in Deck.Rows do
		for _, id in (deck :: any)[row] do
			local card = Cards.Get(id)
			if card then
				table.insert(list, card.Element)
			end
		end
	end
	return list
end

-- The strongest 4 + 4. With `against` (the enemy squad's elements) it counter-builds: each card's power
-- is weighed by Deck.MatchupValue, so cards that beat the squad's elements move up.
function Deck.AutoBuild(owned: Owned, against: { string }?): Deck
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
			local pa, pb = Deck.CardPower(a, owned) * Deck.MatchupValue(a, against), Deck.CardPower(b, owned) * Deck.MatchupValue(b, against)
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
