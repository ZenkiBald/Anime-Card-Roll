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
--   * LastSeen (time-away rewards) must be a number: anything else becomes 0 (no reward on that load).
--   * Artifacts became tower rewards: a save that already cleared the Pagoda gets its artifact.
--   * The Infinite Tower became a run: the old highest floor stays as the best run (Tower.Floor) and the
--     run starts at floor 1. A save that loads mid-fight (Tower.Live set: the player left, or the server
--     closed, during a tower fight) counts that fight as lost: the run ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Borders = require(Shared.Borders)
local Tower = require(Shared.Tower)
local Cards = require(Shared.Cards)
local Collections = require(Shared.Collections)
local Meta = require(Shared.Meta)
local Packs = require(Shared.Packs)

local RevealPolicy=require(Shared.RevealPolicy)
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
	-- Copy strength is retired; keep collections and existing second-slot access, without free mastery.
	if data.BattleMasteryVersion ~= 1 then
		for _, entry in data.Cards or {} do
			if type(entry) == "table" then
				if (tonumber(entry.Awaken) or 0) >= 4 or (tonumber(entry.Fusion) or 0) > 0 or entry.Trait2 ~= nil then entry.Trait2Unlocked = true end
				entry.Stars = 0
				entry.Awaken = nil
				entry.Mastery = if type(entry.Mastery) == "table" then entry.Mastery else {}
			end
		end
		data.BattleMasteryVersion = 1
		table.insert(done, "copy bonuses retired; battle mastery started")
	end
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
	-- Keep the owned character; compensate its former passive as an independent relic once.
	-- Run after border normalization so old saves also retain each exact per-border pile.
	if data.SupportRelicsVersion ~= 1 then
		local function copy(value: any): any
			if type(value) ~= "table" then return value end
			local result = {}
			for key, item in value do result[key] = copy(item) end
			return result
		end
		local owned = if type(data.Cards) == "table" then data.Cards else {}
		for characterId, supportId in Cards.LegacySupports do
			local entry = owned[characterId]
			if type(entry) == "table" and owned[supportId] == nil then
				owned[supportId] = copy(entry)
			end
		end
		local function remap(deck: any)
			if type(deck) ~= "table" or type(deck.Support) ~= "table" then return end
			for slot, id in deck.Support do
				if type(id) == "string" and Cards.LegacySupports[id] then
					local supportId = Cards.LegacySupports[id]
					deck.Support[slot] = if owned[supportId] then supportId else ""
				end
			end
		end
		if type(data.Decks) == "table" and type(data.Decks.Presets) == "table" then
			for _, preset in data.Decks.Presets do remap(preset) end
		end
		remap(data.Deck) -- older single-deck profiles
		data.SupportRelicsVersion = 1
		table.insert(done, "character attackers and independent Support relics")
	end
	-- A card's picked border (`Play`, Deck.PlayBorder) must be a border it has copies at; anything else
	-- (junk, or a pile fused away) goes back to fighting at its best border.
	local plays = 0
	for _, entry in data.Cards or {} do
		if type(entry) == "table" and entry.Play ~= nil then
			local play = entry.Play
			local copies = if type(entry.BorderCopies) == "table" then entry.BorderCopies else {}
			if type(play) ~= "string" or Borders.ById[play] == nil or type(copies[play]) ~= "number" or copies[play] <= 0 then
				entry.Play = nil
				plays += 1
			end
		end
	end
	if plays > 0 then
		table.insert(done, `border picks reset: {plays} cards`)
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
	if data.LastSeen ~= nil and (type(data.LastSeen) ~= "number" or data.LastSeen ~= data.LastSeen) then
		data.LastSeen = 0
		table.insert(done, "last seen reset")
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
	if data.CelestialVersion ~= 1 then
		data.SelectedCollection="normal"
		data.Celestial={Fragments=0,Inventory={}}
		data.Progress=data.Progress or {Cleared={},BestTime={}}
		data.Progress.RewardAt={}
		if (data.TotalRolls or 0)==0 and next(data.Cards or {})==nil then
			data.Packs=data.Packs or {}
			data.Packs["10"]=(data.Packs["10"] or 0)+1
		end
		data.CelestialVersion=1
		table.insert(done,"Celestial collections, weather inventory and starter pack")
	end
	if type(data.SelectedCollection)~="string" or not Collections.Unlocked(data.SelectedCollection,data.Progress and data.Progress.Cleared or {}) then data.SelectedCollection="normal" end
	if data.EconomyVersion~=1 then
		-- Keep purchased permanent upgrade effects; convert the spendable balance to rerolls.
		data.TraitShards=(data.TraitShards or 0)+math.ceil(math.max(0,data.Shards or 0)/Meta.ShardExchange)
		data.Shards=0
		data.Progress=data.Progress or {Cleared={},BestTime={}}
		data.Progress.RewardAt=data.Progress.RewardAt or {}
		for id,count in data.Packs or {} do
			local pack=Packs.ById[id]
			if pack and pack.Element and count>0 then
				data.Packs["1000"]=(data.Packs["1000"] or 0)+count
				data.TraitShards+=math.ceil(Packs.InfuseCost*count/Meta.ShardExchange)
				data.Packs[id]=nil
			end
		end
		local active=if data.Potions and type(data.Potions.Active)=="table" then data.Potions.Active else {}
		for id,factor in {superluck=2,mythic=7.5} do
			if type(active[id])=="number" and active[id]>0 then active[id]=math.min(Meta.MaxPotionSeconds,active[id]*factor) end
		end
		data.EconomyVersion=1
		table.insert(done,"retired Shard balance and infused packs compensated; active luck potions extended")
	end
	data.Settings=if type(data.Settings)=="table" then data.Settings else {}
	local reveal=RevealPolicy.Read(data.Settings)
	if data.RevealSettingsVersion~=1 then table.insert(done,"reveal preferences initialized");data.RevealSettingsVersion=1 end
	for key,value in reveal do data.Settings[key]=value end
	-- 2026-10-30 battle controls: AUTO ULT and HOLD ULT FOR BREAK start on (once), so AFK / hidden fights
	-- keep firing Ultimates; later choices stay. Malformed values are repaired to on.
	if data.BattleControlsVersion~=1 then
		data.Settings.AutoUlt=true
		data.Settings.HoldUlt=true
		data.BattleControlsVersion=1
		table.insert(done,"AUTO ULT and HOLD ULT FOR BREAK switched on")
	end
	if type(data.Settings.AutoUlt)~="boolean" then data.Settings.AutoUlt=true end
	if type(data.Settings.HoldUlt)~="boolean" then data.Settings.HoldUlt=true end
	return done
end

return SaveMigration
