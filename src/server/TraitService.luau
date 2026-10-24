--!nonstrict
-- Kenshin the Trait Master (Traits.luau has the rules): Trait Shards buy trait rolls on an owned card.
-- A roll is saved as the card's Pending (so leaving mid-choice loses nothing) until the player picks
-- KEEP OLD or APPLY NEW. Slot 2 opens at Awakening node 4.
-- TraitMaster remote (RemoteFunction):
--   "Roll", cardId, slot           Traits.RollCost: one new trait for that slot
--   "LockRoll", cardId, lockSlot   Traits.LockCost: keep lockSlot, roll the other slot twice
--   "Choose", cardId, pick         0 = keep the old trait, 1 / 2 = take that rolled one
--   "AutoRoll", cardId, { Slot, Targets = { traitId } }
--                                  rolls that slot (RollCost each, up to Traits.AutoMax) until a target
--                                  lands and applies it; no hit keeps the old trait (no Pending either way)

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

-- AUTO ROLL (see the header). `arg` = { Slot = 1 | 2, Targets = { trait ids } }, checked here.
local function autoRoll(player: Player, data, cardId: string, entry, arg: unknown)
	if type(arg) ~= "table" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local slot, list = (arg :: any).Slot, (arg :: any).Targets
	if (slot ~= 1 and slot ~= 2) or type(list) ~= "table" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local targets, count = {}, 0
	for _, id in list do
		if type(id) ~= "string" or Traits.Get(id) == nil or count >= #Traits.List then
			return { Ok = false, Reason = "BadRequest" }
		end
		if not targets[id] then
			targets[id] = true
			count += 1
		end
	end
	if count == 0 then
		return { Ok = false, Reason = "NoTargets" }
	end
	if not slotOpen(entry, slot) then
		return { Ok = false, Reason = "SlotLocked" }
	end
	local current = if slot == 2 then entry.Trait2 else entry.Trait
	if current and targets[current] then
		return { Ok = false, Reason = "HasTarget" }
	end
	if not limiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	if not NpcRange.Near(player, "traitmaster") then
		return { Ok = false, Reason = "TooFar" }
	end
	local affordable = math.floor((data.TraitShards or 0) / Traits.RollCost)
	if affordable < 1 then
		return { Ok = false, Reason = "NoTraitShards" }
	end
	local rolled, hit = Traits.AutoRun(roll, targets, math.min(Traits.AutoMax, affordable))
	local spent = #rolled * Traits.RollCost
	data.TraitShards -= spent
	if hit then
		if slot == 2 then
			entry.Trait2 = hit
		else
			entry.Trait = hit
		end
	end
	MetaService.Track(player, "TraitRolls", #rolled)
	TutorialService.Note(player, "TraitRoll")
	return reply(player, data, cardId, { Rolled = rolled, Hit = hit, Slot = slot, Spent = spent, Big = hit ~= nil and Traits.TierIndex(hit) >= Traits.BigTier })
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
	if action == "AutoRoll" then
		return autoRoll(player, data, cardId, entry, arg)
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
