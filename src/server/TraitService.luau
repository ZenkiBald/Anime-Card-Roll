--!nonstrict
-- Kenshin the Trait Master (Traits.luau has the rules): Trait Shards buy trait rolls on an owned card.
-- A roll is saved as the card's Pending (so leaving mid-choice loses nothing) until the player picks
-- KEEP OLD or APPLY NEW. Slot 2 opens at Awakening node 4.
-- TraitMaster remote (RemoteFunction):
--   "Roll", cardId, slot           Traits.RollCost: one new trait for that slot
--   "LockRoll", cardId, lockSlot   Traits.LockCost: keep lockSlot, roll the other slot twice
--   "Choose", cardId, pick         0 = keep the old trait, 1 / 2 = take that rolled one

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Traits = require(Shared.Traits)
local Awaken = require(Shared.Awaken)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)
local TutorialService = require(script.Parent.TutorialService)
local NpcRange = require(script.Parent.NpcRange)

local TraitService = {}

local rng = Random.new()
local limiter = RateLimit.new(3, 6)

local function slotOpen(entry, slot: number): boolean
	return slot == 1 or (slot == 2 and Awaken.Level(entry) >= Traits.Slot2Node)
end

local function roll(): string
	return Traits.Pick(rng:NextNumber(), rng:NextNumber())
end

local function reply(player: Player, data, cardId: string, extra)
	local result = {
		Ok = true,
		CardId = cardId,
		Card = DataService.CardState(data.Cards[cardId]),
		TraitShards = data.TraitShards or 0,
		Meta = MetaService.State(player, data),
	}
	for key, value in extra or {} do
		result[key] = value
	end
	return result
end

local function handle(player: Player, action: unknown, cardId: unknown, arg: unknown)
	if type(cardId) ~= "string" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	local data = profile.Data
	local entry = data.Cards[cardId]
	if entry == nil then
		return { Ok = false, Reason = "NotOwned" }
	end

	if action == "Choose" then
		local pending = entry.Pending
		if pending == nil then
			return { Ok = false, Reason = "NothingPending" }
		end
		if arg ~= 0 and arg ~= 1 and arg ~= 2 then
			return { Ok = false, Reason = "BadRequest" }
		end
		local picked = if arg == 0 then nil else pending.Traits[arg]
		if arg ~= 0 and picked == nil then
			return { Ok = false, Reason = "BadRequest" }
		end
		if picked then
			if pending.Slot == 2 then
				entry.Trait2 = picked
			else
				entry.Trait = picked
			end
		end
		entry.Pending = nil
		return reply(player, data, cardId, { Applied = picked })
	end

	-- Rolling: one choice at a time.
	if entry.Pending then
		return { Ok = false, Reason = "Pending", Card = DataService.CardState(entry) }
	end
	local slot, cost, count
	if action == "Roll" then
		if arg ~= 1 and arg ~= 2 then
			return { Ok = false, Reason = "BadRequest" }
		end
		slot, cost, count = arg, Traits.RollCost, 1
	elseif action == "LockRoll" then
		if arg ~= 1 and arg ~= 2 then
			return { Ok = false, Reason = "BadRequest" }
		end
		if not slotOpen(entry, 2) then
			return { Ok = false, Reason = "SlotLocked" }
		end
		slot, cost, count = if arg == 1 then 2 else 1, Traits.LockCost, 2
	else
		return { Ok = false, Reason = "BadRequest" }
	end
	if not slotOpen(entry, slot) then
		return { Ok = false, Reason = "SlotLocked" }
	end
	if not limiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	if not NpcRange.Near(player, "traitmaster") then
		return { Ok = false, Reason = "TooFar" } -- traits are rolled beside Kenshin
	end
	if (data.TraitShards or 0) < cost then
		return { Ok = false, Reason = "NoTraitShards" }
	end
	data.TraitShards -= cost
	local rolled = {}
	for _ = 1, count do
		table.insert(rolled, roll())
	end
	entry.Pending = { Slot = slot, Traits = rolled }
	MetaService.Track(player, "TraitRolls")
	TutorialService.Note(player, "TraitRoll")
	local best = 0
	for _, id in rolled do
		best = math.max(best, Traits.TierIndex(id))
	end
	return reply(player, data, cardId, { Rolled = rolled, Slot = slot, Big = best >= Traits.BigTier })
end

function TraitService.Start()
	Remotes.TraitMaster.OnServerInvoke = handle
end

return TraitService
