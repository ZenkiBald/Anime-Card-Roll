--!strict
-- The Fusion Master: Config.FusionCopies copies of one card fuse it one rarity up, again and again
-- up to Secret. The fused card keeps its stars and gets its new rarity's power (Cards.Stat), so the
-- battle engine, Deck Power and the deck screen all pick it up from the save's Fusion count.
-- Fusing is Awakening node 5 (Awaken.luau): it pays Awaken.FusionTraitShards, and every fusion adds
-- Awaken.FusionLuck permanent base luck (MetaService.BaseLuck counts the fusions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Awaken = require(Shared.Awaken)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)

local FusionService = {}

local limiter = RateLimit.new(2, 4)

local function fuse(player: Player, cardId: unknown): { [string]: any }
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
	local card = Cards.Get(cardId)
	local entry = profile.Data.Cards[cardId]
	if card == nil or entry == nil then
		return { Ok = false, Reason = "NotOwned" }
	end
	local fusion = entry.Fusion or 0
	if fusion >= Cards.MaxFusion(card) then
		return { Ok = false, Reason = "MaxRarity" }
	end
	if entry.Copies < Config.FusionCopies then
		return { Ok = false, Reason = "NotEnough" }
	end
	entry.Copies -= Config.FusionCopies - 1 -- the copies become one fused card
	entry.Fusion = fusion + 1
	entry.Awaken = math.max(entry.Awaken or 0, 4) -- nodes 1-4 stay open for good
	local granted = MetaService.Grant(profile.Data, { TraitShards = Awaken.FusionTraitShards }, player)
	MetaService.Track(player, "Fusions")
	MetaService.AddXP(player, profile.Data, Meta.XP.Fusion)
	return {
		Ok = true,
		CardId = cardId,
		Card = DataService.CardState(entry),
		Granted = granted, -- the node 5 Trait Shards
		Rarity = Cards.FusedRarity(card, entry.Fusion),
		Meta = MetaService.State(player, profile.Data), -- the "fuse a card" quest
	}
end

function FusionService.Start()
	Remotes.Fuse.OnServerInvoke = fuse
end

return FusionService
