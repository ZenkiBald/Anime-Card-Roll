--!strict
-- Hoshi's border fusion: Config.FusionCopies (100) copies of one card at one border fuse into 1 copy of
-- it at the next border (Base -> Gold -> Rainbow -> Secret). The card wears its best border, so Deck
-- Power, the battle engine and every screen pick the new tier up from the save (Cards[id].BorderCopies /
-- Borders). Fusing is Awakening node 5 (Awaken.luau): it pays Awaken.FusionTraitShards, and every fusion
-- adds Awaken.FusionLuck permanent base luck (MetaService.BaseLuck counts them in Cards[id].Fusion).
-- Fuse remote: (cardId, border) = fuse 100 of that border; only beside Hoshi (NpcRange).

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

local function fuse(player: Player, cardId: unknown, border: unknown): { [string]: any }
	if type(cardId) ~= "string" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local from = if type(border) == "string" and Borders.ById[border] then border else "Normal"
	local to = Borders.Next(from)
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
	local card = Cards.Get(cardId)
	local entry = profile.Data.Cards[cardId]
	if card == nil or entry == nil then
		return { Ok = false, Reason = "NotOwned" }
	end
	if to == nil then
		return { Ok = false, Reason = "MaxBorder" }
	end
	local copies = entry.BorderCopies or {}
	if (copies[from] or 0) < Config.FusionCopies then
		return { Ok = false, Reason = "NotEnough" }
	end
	copies[from] -= Config.FusionCopies
	copies[to] = (copies[to] or 0) + 1
	entry.BorderCopies = copies
	entry.Copies -= Config.FusionCopies - 1 -- the copies become one card at the next border
	entry.Borders = entry.Borders or {}
	entry.Borders[to] = true
	entry.Fusion = (entry.Fusion or 0) + 1 -- fusions done (node 5 luck)
	entry.Awaken = math.max(entry.Awaken or 0, 4) -- nodes 1-4 stay open for good
	local granted = MetaService.Grant(profile.Data, { TraitShards = Awaken.FusionTraitShards }, player)
	AvatarService.Apply(player) -- if this is the worn avatar card, its aura moves up a border now
	MetaService.Track(player, "Fusions")
	MetaService.AddXP(player, profile.Data, Meta.XP.Fusion)
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
