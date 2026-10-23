--!nonstrict
-- Player profiles: tap anyone in the server list (UI/PlayerList) to see their profile. The Profile
-- remote takes a user id and answers for players in this server only: name, level, Deck Power, rolls,
-- tower floor, bosses cleared, Index progress, playtime, their favourite card, their strongest cards
-- and their active deck. Read-only and rate-limited.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)
local Borders = require(Shared.Borders)
local Deck = require(Shared.Deck)
local Rarity = require(Shared.Rarity)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local RateLimit = require(script.Parent.RateLimit)

local ProfileService = {}

local limiter = RateLimit.new(2, 4)
local TOP_CARDS = 6

local function cardInfo(id: string, entry): { [string]: any }
	return { Id = id, Stars = entry.Stars, Fusion = entry.Fusion, Border = Borders.Best(entry.Borders) }
end

local function profileOf(target: Player)
	local profile = DataService.Get(target)
	if profile == nil then
		return nil
	end
	local data = profile.Data

	-- The strongest cards they own (Deck Power of each), and the favourite (else the rarest).
	local owned = {}
	for id, entry in data.Cards do
		local card = Cards.Get(id)
		if card then
			table.insert(owned, { Id = id, Entry = entry, Power = Cards.Power(card, entry.Stars, entry.Fusion, Borders.Best(entry.Borders)), Rarity = Rarity.Index(Cards.FusedRarity(card, entry.Fusion)) })
		end
	end
	table.sort(owned, function(a, b)
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return a.Id < b.Id
	end)
	local top = {}
	for i = 1, math.min(TOP_CARDS, #owned) do
		table.insert(top, cardInfo(owned[i].Id, owned[i].Entry))
	end
	local favId = data.Settings.Favorite
	if favId == nil or data.Cards[favId] == nil then
		favId = nil
		local best = 0
		for _, c in owned do
			if c.Rarity > best then
				best, favId = c.Rarity, c.Id
			end
		end
	end

	local cleared, fights = 0, 0
	for _, boss in Bosses.List do
		for _, difficulty in Bosses.DifficultyOrder do
			if boss.Difficulties[difficulty] then
				fights += 1
				if data.Progress.Cleared[Bosses.FightKey(boss.Id, difficulty)] then
					cleared += 1
				end
			end
		end
	end

	local deck = DeckService.Active(data)
	local deckCards = {}
	for _, row in Deck.Rows do
		for _, id in deck[row] do
			table.insert(deckCards, if id ~= "" and data.Cards[id] then cardInfo(id, data.Cards[id]) else false)
		end
	end

	return {
		Ok = true,
		UserId = target.UserId,
		Name = target.Name,
		DisplayName = target.DisplayName,
		Level = data.Level,
		Rolls = data.TotalRolls,
		Power = Deck.Power(deck, data.Cards),
		Floor = data.Tower.Floor,
		Cleared = cleared,
		Fights = fights,
		Found = #owned,
		Total = #Cards.List,
		Playtime = math.floor(DataService.Playtime(target)),
		Favorite = if favId then cardInfo(favId, data.Cards[favId]) else nil,
		Top = top,
		Deck = deckCards,
	}
end

function ProfileService.Start()
	Remotes.Profile.OnServerInvoke = function(player: Player, userId: unknown)
		if type(userId) ~= "number" or userId ~= userId then
			return { Ok = false, Reason = "BadRequest" }
		end
		if not limiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		local target = Players:GetPlayerByUserId(userId)
		if target == nil then
			return { Ok = false, Reason = "Gone" }
		end
		return profileOf(target) or { Ok = false, Reason = "Loading" }
	end
end

return ProfileService
