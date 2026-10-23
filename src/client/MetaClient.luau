--!nonstrict
-- Talks to MetaService (potions, shop, gifts, Index rewards) and counts what's ready to claim,
-- for the red badges on the menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Meta = require(Shared.Meta)
local Rarity = require(Shared.Rarity)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = require(script.Parent.State)

local MetaClient = {}

MetaClient.Reasons = {
	NoShards = "Not enough Shards",
	NoPotion = "You don't have that potion",
	PotionFull = "That potion is already running for an hour",
	MaxLevel = "Already at max level",
	NoPoints = "No stat points left: level up for more",
	SlotsFull = "All 3 artifact slots are full: remove one first",
	AlreadyWorn = "Already worn",
	NoItem = "You don't have that one in the bag",
	NothingToReset = "No points spent yet",
	Claimed = "Already claimed",
	NotYet = "Not ready yet",
	TooFast = "Slow down a little",
	Loading = "Still loading",
	NoSpins = "No spins yet: play a little longer",
	TooFar = "Stand beside Madame Fortuna to spin",
}

-- Called with (bundle) whenever something is granted, to show a reward toast.
MetaClient.OnGranted = nil :: ((bundle: any) -> ())?

function MetaClient.Call(action: string, arg: any?)
	local ok, result = pcall(function()
		return Remotes.Meta:InvokeServer(action, arg)
	end)
	if not ok or result == nil then
		return { Ok = false, Reason = "Network" }
	end
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	if result.Ok and result.Granted and MetaClient.OnGranted then
		MetaClient.OnGranted(result.Granted)
	end
	return result
end

function MetaClient.Message(result): string
	return MetaClient.Reasons[result.Reason] or "Something went wrong"
end

-- Found every card of a rarity (computed here, checked again by the server on claim).
function MetaClient.RarityComplete(rarity: string): boolean
	local pool = Cards.ByRarity[rarity]
	if pool == nil or #pool == 0 then
		return false
	end
	for _, card in pool do
		if State.Cards[card.Id] == nil then
			return false
		end
	end
	return true
end

function MetaClient.IndexClaimable(): number
	local n = 0
	for _, rarity in Rarity.Order do
		if MetaClient.RarityComplete(rarity) and not State.Meta.IndexClaimed[rarity] then
			n += 1
		end
	end
	return n
end

function MetaClient.GiftClaimed(index: number): boolean
	for _, claimed in (State.Meta.GiftsClaimed or {}) :: { any } do
		if claimed == index then
			return true
		end
	end
	return false
end

-- Today's quests that are done but not claimed yet.
function MetaClient.QuestsReady(): number
	local n = 0
	for _, entry in (State.Meta.Quests and State.Meta.Quests.List or {}) :: { any } do
		local quest = Meta.QuestById[entry.Id]
		if quest and not entry.Claimed and entry.Progress >= quest.Goal then
			n += 1
		end
	end
	return n
end

function MetaClient.GiftsClaimable(): number
	local n = (if State.Meta.Daily.CanClaim then 1 else 0) + MetaClient.QuestsReady()
	local session = State.SessionSeconds()
	for i, gift in Meta.Playtime do
		if session >= gift.Minutes * 60 and not MetaClient.GiftClaimed(i) then
			n += 1
		end
	end
	local rolls = State.Rolls()
	for _, milestone in Meta.Milestones do
		if rolls >= milestone.Rolls and not State.Meta.Milestones[tostring(milestone.Rolls)] then
			n += 1
		end
	end
	return n
end

-- Roll Packs waiting in the BAG (its red badge counts them with the potions).
function MetaClient.PackCount(): number
	local n = 0
	for _, count in (State.Packs or {}) :: { [string]: number } do
		n += count
	end
	return n
end

function MetaClient.PotionCount(): number
	local n = 0
	for _, count in (State.Meta.Inventory or {}) :: { [string]: number } do
		n += count
	end
	return n
end

return MetaClient
