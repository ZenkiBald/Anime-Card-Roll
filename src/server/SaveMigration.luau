--!strict
-- Brings an old save up to date when its profile loads (DataService calls Migrate after Reconcile). Pure:
-- no Roblox services, so tests/save_test.luau runs it headless on old-style saves. Every step is safe to run
-- again on a save that's already current (it does nothing then).
--   * Card accessories were removed: each one owned (in the bag or worn) is refunded as Shards.
--   * Pity was removed: the saved pity counters go.
--   * Borders became the tiers (no card rarities): each card gets per-border copy counts (BorderCopies).
--     Its old copies are Base copies, minus one for each special border it had found (that pull was the
--     border); an old rarity fusion becomes Gold copies. The card's total Copies always equals the sum.
--   * Auto Roll no longer stops by itself: the saved stop setting goes.
--   * The short-lived roll bank (rarity tickets) comes back as Roll Packs (10 tickets a pack, rounded up).
--   * Artifacts became tower rewards: a save that already cleared the Pagoda gets its artifact.
--   * The Infinite Tower became a run: the old highest floor stays as the best run (Tower.Floor) and the
--     run starts at floor 1. A save that loads mid-fight (Tower.Live set: the player left, or the server
--     closed, during a tower fight) counts that fight as lost: the run ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Borders = require(Shared.Borders)
local Tower = require(Shared.Tower)

local SaveMigration = {}

SaveMigration.AccessoryRefund = 150 -- Shards per card accessory

-- Fills in BorderCopies for one card entry from the old fields. Returns true when it changed the entry.
function SaveMigration.CardBorders(entry: any): boolean
	if type(entry) ~= "table" or entry.BorderCopies ~= nil then
		return false
	end
	local copies: { [string]: number } = {}
	local special = 0
	for id, has in entry.Borders or {} do
		if has and id ~= "Normal" and Borders.ById[id] then
			copies[id] = 1
			special += 1
		end
	end
	local fused = if type(entry.Fusion) == "number" then math.max(0, math.floor(entry.Fusion)) else 0
	if fused > 0 then
		copies.Gold = (copies.Gold or 0) + fused
		entry.Borders = entry.Borders or {}
		entry.Borders.Gold = true
	end
	local old = if type(entry.Copies) == "number" then math.max(0, math.floor(entry.Copies)) else 1
	copies.Normal = math.max(0, old - special)
	entry.BorderCopies = copies
	-- The total is the sum of the piles (a save with more found borders than copies used to disagree).
	local total = 0
	for _, n in copies do
		total += n
	end
	entry.Copies = math.max(1, total)
	if total == 0 then
		copies.Normal = 1
	end
	entry.Borders = entry.Borders or {}
	entry.Borders.Normal = true
	return true
end

-- Runs every step on a whole save (profile.Data). Returns a list of what it did (for logs and tests).
function SaveMigration.Migrate(data: any): { string }
	local done = {}
	-- Card accessories: refunded as Shards.
	local gear = data.Gear
	if type(gear) == "table" and (type(gear.Accessories) == "table" or type(gear.Cards) == "table") then
		local count = 0
		for _, n in gear.Accessories or {} do
			count += if type(n) == "number" then math.max(0, n) else 0
		end
		for _ in gear.Cards or {} do
			count += 1
		end
		data.Shards = (data.Shards or 0) + count * SaveMigration.AccessoryRefund
		gear.Accessories = nil
		gear.Cards = nil
		table.insert(done, `accessories refunded: {count}`)
	end
	if data.Pity ~= nil then
		data.Pity = nil -- rolls are pure luck now
		table.insert(done, "pity removed")
	end
	-- Borders are the tiers.
	local cards = 0
	for _, entry in data.Cards or {} do
		if SaveMigration.CardBorders(entry) then
			cards += 1
		end
	end
	if cards > 0 then
		table.insert(done, `border copies: {cards} cards`)
	end
	local settings = data.Settings
	if type(settings) == "table" and settings.AutoStop ~= nil then
		settings.AutoStop = nil
		table.insert(done, "auto stop removed")
	end
	-- The roll bank's tickets come back as Roll Packs.
	local bank = data.RollBank
	if type(bank) == "table" then
		local tickets = 0
		for _, count in bank do
			tickets += if type(count) == "number" then math.max(0, count) else 0
		end
		if tickets > 0 then
			data.Packs = data.Packs or {}
			data.Packs["10"] = (data.Packs["10"] or 0) + math.ceil(tickets / 10)
		end
		data.RollBank = nil
		table.insert(done, `roll bank: {tickets} tickets`)
	end
	-- The Pagoda's artifact for a save that cleared floor 100 before it existed.
	local pagoda = data.Pagoda
	local top = Tower.PagodaMilestones[Tower.Pagoda.Floors]
	local crown = top and top.Artifact
	if crown and type(pagoda) == "table" and type(pagoda.Floor) == "number" and pagoda.Floor >= Tower.Pagoda.Floors and type(data.Gear) == "table" then
		data.Gear.TowerArtifacts = data.Gear.TowerArtifacts or {}
		if not data.Gear.TowerArtifacts[crown] then
			data.Gear.TowerArtifacts[crown] = true
			table.insert(done, "pagoda artifact granted")
		end
	end
	-- The Infinite Tower is a run.
	local tower = data.Tower
	if type(tower) == "table" then
		if type(tower.Run) ~= "number" then
			tower.Run = 0
			table.insert(done, "tower run started")
		end
		if tower.Live ~= nil then
			tower.Live = nil
			tower.Run = 0
			table.insert(done, "tower run ended (left mid-fight)")
		end
	end
	return done
end

return SaveMigration
