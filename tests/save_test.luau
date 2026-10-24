-- Old saves brought up to date on load (src/server/SaveMigration.luau): nothing a player owned is lost,
-- the per-border copy piles add up to the card's total, and running it twice changes nothing.
local SaveMigration = MODULES.SaveMigration
local Config = MODULES.Config

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local function same(a, b): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function pileSum(entry): number
	local n = 0
	for _, k in entry.BorderCopies do
		n += k
	end
	return n
end

local function oldSave()
	return {
		Shards = 1000,
		Cards = {
			rook = { Copies = 37, Stars = 5 }, -- plain old card
			kaede = { Copies = 10, Stars = 5, Borders = { Gold = true, Rainbow = true } }, -- found two borders
			tomo = { Copies = 5, Stars = 4, Fusion = 2 }, -- fused twice under the old rarity system
			mirai = { Copies = 1, Stars = 0, Borders = { Gold = true, Rainbow = true, Secret = true } }, -- more borders than copies
			sora = { Copies = 3, Stars = 2, Borders = { Bogus = true } }, -- a border id that doesn't exist
			akane = { Copies = 120, Stars = 5, BorderCopies = { Normal = 118, Gold = 2 } }, -- already current
		},
		Gear = { Artifacts = {}, Worn = {}, Accessories = { blade = 2, charm = 1 }, Cards = { rook = "blade" } },
		Pity = { Legendary = 40 },
		Settings = { AutoStop = "Legendary" },
		RollBank = { Rare = 15, Epic = 6 },
		Packs = { ["10"] = 1 },
	}
end

local data = oldSave()
SaveMigration.Migrate(data)
local c = data.Cards

check(c.rook.BorderCopies.Normal == 37 and c.rook.Copies == 37, "old copies become Base copies")
check(
	c.kaede.BorderCopies.Normal == 8 and c.kaede.BorderCopies.Gold == 1 and c.kaede.BorderCopies.Rainbow == 1 and c.kaede.Copies == 10,
	"each found border is one of the card's copies, the rest are Base"
)
check(
	c.tomo.BorderCopies.Gold == 2 and c.tomo.BorderCopies.Normal == 5 and c.tomo.Copies == 7 and c.tomo.Borders.Gold == true and c.tomo.Fusion == 2,
	"an old rarity fusion becomes Gold copies (and still counts as a fusion for node 5 luck)"
)
check(pileSum(c.mirai) == c.mirai.Copies and c.mirai.BorderCopies.Secret == 1, "more found borders than copies: the total follows the piles")
check(c.sora.BorderCopies.Bogus == nil and c.sora.BorderCopies.Normal == 3, "an unknown border id is ignored")
check(c.akane.BorderCopies.Normal == 118 and c.akane.BorderCopies.Gold == 2 and c.akane.Copies == 120, "a current save's card is left alone")
local sumsOk = true
for _, entry in c do
	sumsOk = sumsOk and pileSum(entry) == entry.Copies
end
check(sumsOk, "every card's per-border piles add up to its total copies")

check(data.Shards == 1000 + 4 * SaveMigration.AccessoryRefund and data.Gear.Accessories == nil and data.Gear.Cards == nil, "every accessory (bagged or worn) is refunded as Shards")
check(data.Pity == nil, "pity counters go")
check(data.Settings.AutoStop == Config.DefaultAutoStop, "an old rarity Auto Roll stop goes back to the default")
check(data.RollBank == nil and data.Packs["10"] == 1 + 3, "21 bank tickets come back as 3 Roll Packs, on top of the packs held")

-- Running it again on the migrated save changes nothing.
local again = deepCopy(data)
SaveMigration.Migrate(again)
check(same(again, data), "migrating twice changes nothing")

-- A valid stop stays; junk values don't crash it.
local kept = { Cards = { x = { Copies = "lots", Fusion = "two" } }, Settings = { AutoStop = "Gold" } }
local ok = pcall(SaveMigration.Migrate, kept)
check(ok and kept.Settings.AutoStop == "Gold" and kept.Cards.x.BorderCopies.Normal >= 1, "junk card fields don't crash it, and a valid stop stays")

-- The Infinite Tower became a run: the old highest floor is the best run, the run starts at floor 1; a
-- save left mid-fight loses that run.
do
	local old = { Cards = {}, Tower = { Floor = 37 } }
	SaveMigration.Migrate(old)
	check(old.Tower.Floor == 37 and old.Tower.Run == 0, "an old tower floor becomes the best run, and the run starts at floor 1")
	local left = { Cards = {}, Tower = { Floor = 40, Run = 22, Live = 23 } }
	SaveMigration.Migrate(left)
	check(left.Tower.Run == 0 and left.Tower.Live == nil and left.Tower.Floor == 40, "a save left mid tower fight ends that run (the best stays)")
	local mid = { Cards = {}, Tower = { Floor = 40, Run = 22 } }
	SaveMigration.Migrate(mid)
	check(mid.Tower.Run == 22, "a run between fights carries on after a rejoin")
end
