--!strict
-- Hoshi's border fusion: Config.FusionCopies (100) copies of one card at one border fuse into 1 copy of
-- it at the next border (Base -> Gold -> Rainbow -> Secret). The card wears its best border, so Deck
-- Power, the battle engine and every screen pick the new tier up from the save (Cards[id].BorderCopies /
-- Borders). Fusing is Awakening node 5 (Awaken.luau): it pays Awaken.FusionTraitShards, and every fusion
-- is counted in Cards[id].Fusion. Fusions give no luck (the 4x card is the reward).
-- Fuse remote: (cardId, border) = fuse 100 of that border; ("ALL") = FUSE ALL; only beside Hoshi (NpcRange).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Awaken = require(Shared.Awaken)
local Borders = require(Shared.Borders)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)
local NpcRange = require(script.Parent.NpcRange)
local AvatarService = require(script.Parent.AvatarService)

local FusionService = {}

local limiter = RateLimit.new(2, 4)

-- One fusion on a save entry (no checks beyond the copy count): 100 copies at `from` -> 1 at the next border.
local function fuseOnce(entry: any, from: string): string?
	local to = Borders.Next(from)
	local copies = entry.BorderCopies or {}
	if to == nil or (copies[from] or 0) < Config.FusionCopies then
		return nil
	end
	copies[from] -= Config.FusionCopies
	copies[to] = (copies[to] or 0) + 1
	entry.BorderCopies = copies
	entry.Copies -= Config.FusionCopies - 1 -- the copies become one card at the next border
	entry.Borders = entry.Borders or {}
	entry.Borders[to] = true
	entry.Fusion = (entry.Fusion or 0) + 1 -- fusions done (node 5 luck)
	entry.Awaken = math.max(entry.Awaken or 0, 4) -- nodes 1-4 stay open for good
	return to
end

-- What every fusion pays (Awakening node 5), `count` times over.
local function pay(player: Player, data, count: number)
	local granted = MetaService.Grant(data, { TraitShards = Awaken.FusionTraitShards * count }, player)
	for _ = 1, count do
		MetaService.Track(player, "Fusions")
	end
	MetaService.AddXP(player, data, Meta.XP.Fusion * count)
	AvatarService.Apply(player) -- if the worn avatar card moved up a border, its aura follows now
	return granted
end

-- FUSE ALL: every card, lowest border first, again and again while any border holds 100 copies (so 200
-- Base copies make 2 Gold, and 100 Gold made that way go on to a Rainbow).
local function fuseAll(player: Player, profile): { [string]: any }
	local data = profile.Data
	local fused, cards = 0, {}
	for cardId, entry in data.Cards do
		if Cards.Get(cardId) == nil then
			continue
		end
		local any = false
		for _, from in Borders.Order do
			while fuseOnce(entry, from) do
				fused += 1
				any = true
			end
		end
		if any then
			cards[cardId] = DataService.CardState(entry)
		end
	end
	if fused == 0 then
		return { Ok = false, Reason = "NotEnough" }
	end
	local granted = pay(player, data, fused)
	return { Ok = true, All = true, Fused = fused, Cards = cards, Granted = granted, Meta = MetaService.State(player, data) }
end

-- Fuse remote: (cardId, border) fuses 100 of that border on one card; ("ALL") fuses everything that can.
local function fuse(player: Player, cardId: unknown, border: unknown): { [string]: any }
	if type(cardId) ~= "string" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	if not limiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	if not NpcRange.Near(player, "fuser") then
		return { Ok = false, Reason = "TooFar" } -- fusing happens beside Hoshi
	end
	if cardId == "ALL" then
		return fuseAll(player, profile)
	end
	local from = if type(border) == "string" and Borders.ById[border] then border else "Normal"
	local card = Cards.Get(cardId)
	local entry = profile.Data.Cards[cardId]
	if card == nil or entry == nil then
		return { Ok = false, Reason = "NotOwned" }
	end
	if Borders.Next(from) == nil then
		return { Ok = false, Reason = "MaxBorder" }
	end
	local to = fuseOnce(entry, from)
	if to == nil then
		return { Ok = false, Reason = "NotEnough" }
	end
	local granted = pay(player, profile.Data, 1)
	return {
		Ok = true,
		CardId = cardId,
		Card = DataService.CardState(entry),
		Granted = granted, -- the node 5 Trait Shards
		From = from,
		Border = to,
		Meta = MetaService.State(player, profile.Data), -- the "fuse a card" quest
	}
end

function FusionService.Start()
	Remotes.Fuse.OnServerInvoke = fuse
end

return FusionService
