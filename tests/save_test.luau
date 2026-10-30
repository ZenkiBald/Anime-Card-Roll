-- Old saves brought up to date on load (src/server/SaveMigration.luau): nothing a player owned is lost,
-- the per-border copy piles add up to the card's total, and running it twice changes nothing.
local SaveMigration = MODULES.SaveMigration

do
	local d = { Cards = {}, Progress = { Cleared = { ["kurogane:Normal"] = true } },
		Tutorial = { Step = 4 }, Titles = { Apprentice = true }, Settings = { Title = "Apprentice" } }
	SaveMigration.Migrate(d)
	check(d.Titles["First Victory"] == true and d.Titles.Apprentice and d.Settings.Title == "Apprentice",
		"past first-boss quest claimants receive First Victory without losing their worn title")
	local again = SaveMigration.Migrate(d)
	check(not table.find(again, "first boss quest title granted"), "first-boss title backfill is idempotent")
	local pending = { Cards = {}, Progress = { Cleared = { ["kurogane:Normal"] = true } }, Tutorial = { Step = 3 } }
	SaveMigration.Migrate(pending)
	check(not (pending.Titles and pending.Titles["First Victory"]), "an unclaimed boss quest still waits for its normal claim")
end

-- Celestial display-name / art revisions keep the original collection keys and border piles.
do
	local data = { Cards = {} }
	for _, card in MODULES.Cards.List do
		if card.Weather then
			data.Cards[card.Id] = { Copies = 101, Stars = 0, Borders = { Normal = true, Gold = true },
				BorderCopies = { Normal = 100, Gold = 1 }, Play = "Gold" }
		end
	end
	SaveMigration.Migrate(data)
	SaveMigration.Migrate(data)
	local count, kept = 0, true
	for id, entry in data.Cards do
		count += 1
		kept = kept and MODULES.Cards.Get(id) ~= nil and entry.Copies == 101
			and entry.BorderCopies.Normal == 100 and entry.BorderCopies.Gold == 1 and entry.Play == "Gold"
	end
	check(count == 16 and kept and MODULES.Cards.Get("celestial_rain_goku").Name == "Silver Sovereign",
		"all 16 renamed sky cards keep their saved IDs, copies and selected borders")
end

do
	local data={Cards={rook={Copies=1,Stars=0}},TotalRolls=100,Shards=1000,TraitShards=3,Upgrades={Luck=2,RollSpeed=1},Packs={["1000:Flame"]=2},Potions={Active={superluck=100,mythic=100}}}
	SaveMigration.Migrate(data)
	local count=data.TraitShards
	check(data.Shards==0 and count==3+math.ceil(1000/MODULES.Meta.ShardExchange)+math.ceil(2*MODULES.Packs.InfuseCost/MODULES.Meta.ShardExchange),"retired balance and infused-pack spend are compensated as Trait Shards")
	check(data.Packs["1000"]==2 and data.Packs["1000:Flame"]==nil and data.Upgrades.Luck==2 and data.Upgrades.RollSpeed==1,"infused packs retain every roll and bought permanent bonuses remain")
	check(data.Potions.Active.superluck==200 and data.Potions.Active.mythic==750,"running higher-tier luck potions receive their longer replacement duration")
	data.Progress.RewardAt["kurogane:Normal"]=123456
	SaveMigration.Migrate(data)
	check(data.TraitShards==count and data.Potions.Active.mythic==750 and data.Progress.RewardAt["kurogane:Normal"]==123456,"economy compensation and persisted reward cooldowns survive a second migration")
end

do
	local data={Cards={},TotalRolls=0}
	SaveMigration.Migrate(data)
	local count=data.Packs["10"]
	check(data.SelectedCollection=="normal" and data.Celestial.Fragments==0 and count==1,"new profile starts with one consumable card pack and normal collection")
	SaveMigration.Migrate(data)
	check(data.Packs["10"]==count,"starter pack and weather migration are idempotent")
	data.SelectedCollection="chakra"
	data.Celestial.Fragments=8
	SaveMigration.Migrate(data)
	check(data.SelectedCollection=="chakra" and data.Celestial.Fragments==8,"selected collection and earned weather items survive migration")
end

do
	local entry = { Copies=120, Stars=5, Awaken=4, Trait2="swift", BorderCopies={Normal=119,Gold=1}, Borders={Normal=true,Gold=true} }
	local data = { Cards={rook=entry} }
	SaveMigration.Migrate(data)
	check(entry.Stars == 0 and entry.Awaken == nil and MODULES.Awaken.Level(entry) == 0, "copy stats retire without granting free mastery")
	check(entry.Copies == 120 and entry.BorderCopies.Gold == 1 and entry.Trait2Unlocked, "migration preserves copies, borders and existing second trait slot")
	local mark = "kurogane:Normal"
	check(MODULES.Awaken.Award(entry, mark) and not MODULES.Awaken.Award(entry, mark), "one mastery mark per distinct challenge; farming repeats grants none")
	SaveMigration.Migrate(data)
	check(MODULES.Awaken.Count(entry) == 1 and MODULES.Awaken.Level(entry) == 1, "mastery survives a repeated save migration")
	for i=2,10 do MODULES.Awaken.Award(entry, `challenge:{i}`) end
	check(MODULES.Awaken.Level(entry) == 4, "ten distinct boss challenges unlock the second trait slot")
	check(MODULES.Cards.Stat(MODULES.Cards.Get("rook"),550,0,"Normal") == MODULES.Cards.Stat(MODULES.Cards.Get("rook"),550,5,"Normal",4), "copies and mastery cannot multiply base damage")
	local fused = {Cards={rook={Copies=100,Stars=5,Fusion=1}}}
	SaveMigration.Migrate(fused)
	check(fused.Cards.rook.Trait2Unlocked and MODULES.Awaken.Level(fused.Cards.rook)==0, "legacy fusion keeps second-slot access without free mastery")
end

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

check(data.Shards == 0 and data.TraitShards >= math.ceil((1000 + 4 * SaveMigration.AccessoryRefund)/MODULES.Meta.ShardExchange) and data.Gear.Accessories == nil and data.Gear.Cards == nil, "every accessory refund is preserved as Trait Shards after retiring the old currency")
check(data.Pity == nil, "pity counters go")
check(data.Settings.AutoStop == nil, "the Auto Roll stop setting goes (Auto Roll never stops)")
check(data.RollBank == nil and data.Packs["10"] == 1 + 3, "21 bank tickets come back as 3 Roll Packs, on top of the packs held")

-- Running it again on the migrated save changes nothing.
local again = deepCopy(data)
SaveMigration.Migrate(again)
check(same(again, data), "migrating twice changes nothing")

-- Character conversion preserves every collection investment and all saved Support positions.
do
	local old = {
		Cards = { hana = { Copies = 9, Stars = 0, BorderCopies = { Normal = 6, Gold = 3 }, Borders = { Normal = true, Gold = true }, Play = "Gold", Trait = "swift", Trait2 = "keen", Trait2Unlocked = true, Mastery = { ["kurogane:Normal"] = true }, Foil = "Aura" } },
		Decks = { Active = 2, Presets = {
			{ Attack = { "rook", "", "", "" }, Support = { "hana", "", "", "" } },
			{ Attack = { "tomo", "", "", "" }, Support = { "", "hana", "", "" } },
		} },
		Deck = { Support = { "", "", "hana", "" } },
	}
	SaveMigration.Migrate(old)
	check(old.Cards.hana ~= nil and same(old.Cards.hana, old.Cards.mitotic_seal), "converted character stays owned and its relic receives the same copies, borders, traits, foil and mastery")
	check(old.Cards.hana ~= old.Cards.mitotic_seal and old.Cards.hana.BorderCopies ~= old.Cards.mitotic_seal.BorderCopies and old.Cards.hana.Mastery ~= old.Cards.mitotic_seal.Mastery, "character and compensated relic have independent saved tables")
	check(old.Decks.Active == 2 and old.Decks.Presets[1].Support[1] == "mitotic_seal" and old.Decks.Presets[2].Support[2] == "mitotic_seal" and old.Deck.Support[3] == "mitotic_seal", "all presets and the legacy deck retain their Support slot through conversion")
	check(old.Decks.Presets[1].Attack[1] == "rook" and old.Decks.Presets[2].Attack[1] == "tomo", "conversion does not rearrange the Attack lineup")
	local second = deepCopy(old)
	SaveMigration.Migrate(old)
	check(same(old, second), "rejoining never grants a second relic compensation or resets progress")
	old.Cards.mitotic_seal.BorderCopies.Gold = 2
	check(old.Cards.hana.BorderCopies.Gold == 3, "fusing or spending relic copies cannot consume the character's collection")
	local existing = { Cards = { hana = { Copies = 3 }, mitotic_seal = { Copies = 7 } } }
	SaveMigration.Migrate(existing)
	check(existing.Cards.mitotic_seal.Copies == 7, "an already-owned relic is never overwritten by conversion")
end

-- Junk values don't crash it.
local kept = { Cards = { x = { Copies = "lots", Fusion = "two" } }, Settings = { AutoStop = "Gold" } }
local ok = pcall(SaveMigration.Migrate, kept)
check(ok and kept.Settings.AutoStop == nil and kept.Cards.x.BorderCopies.Normal >= 1, "junk card fields don't crash it")

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

-- A save that cleared the Pagoda before artifacts became its reward gets the artifact (once).
do
	local done = { Cards = {}, Pagoda = { Floor = 100 }, Gear = { Artifacts = {}, Worn = {} } }
	SaveMigration.Migrate(done)
	check(done.Gear.TowerArtifacts.hundredcrown == true, "a cleared Pagoda save gets the Crown of the Hundred Floors")
	local mid = { Cards = {}, Pagoda = { Floor = 60 }, Gear = { Artifacts = {}, Worn = {} } }
	SaveMigration.Migrate(mid)
	check(mid.Gear.TowerArtifacts == nil, "a save partway up the Pagoda gets nothing yet")
end

-- LastSeen must be a number (time-away rewards); junk resets to 0.
do
	local junk = { Cards = {}, LastSeen = "yesterday" }
	SaveMigration.Migrate(junk)
	local fine = { Cards = {}, LastSeen = 1761523200 }
	SaveMigration.Migrate(fine)
	check(junk.LastSeen == 0 and fine.LastSeen == 1761523200, "a junk LastSeen resets to 0; a real one stays")
end

do
	local data = { Cards = {
		rook = { Copies = 6, Stars = 5, Borders = { Normal = true, Gold = true, Rainbow = true }, BorderCopies = { Gold = 5, Rainbow = 1 }, Play = "Gold" },
		tomo = { Copies = 2, Stars = 1, Borders = { Normal = true, Gold = true }, BorderCopies = { Normal = 0, Gold = 2 }, Play = "Normal" },
		noa = { Copies = 1, Stars = 0, Borders = { Normal = true }, BorderCopies = { Normal = 1 }, Play = 42 },
	} }
	SaveMigration.Migrate(data)
	check(data.Cards.rook.Play == "Gold", "a border pick with copies stays (5 Gold kept in play beside the Rainbow)")
	check(data.Cards.tomo.Play == nil and data.Cards.noa.Play == nil, "a pick at a fused-away border, or junk, goes back to the best border")
	local again = SaveMigration.Migrate(data)
	check(#again == 0 or not table.find(again, "border picks reset: 1 cards"), "the border pick step is safe to run twice")
end

-- Reveal preferences are repaired independently of cards / the QUICK toggle.
do
 local d={Cards={},Settings={QuickRoll=true}}
 SaveMigration.Migrate(d)
 check(d.RevealSettingsVersion==1 and d.Settings.RevealMinimum=="Rainbow" and d.Settings.RevealStyle=="Pack" and d.Settings.RevealDuplicates==false and d.Settings.QuickRoll==true,"old saves get safe reveal defaults without changing QUICK")
 d.Settings.RevealMinimum="Secret";d.Settings.RevealStyle="Cinematic";d.Settings.RevealDuplicates=true
 SaveMigration.Migrate(d)
 check(d.Settings.RevealMinimum=="Secret" and d.Settings.RevealStyle=="Cinematic" and d.Settings.RevealDuplicates==true,"reveal migration preserves choices and is idempotent")
 d.Settings.RevealMinimum={};d.Settings.RevealStyle="invalid";d.Settings.RevealDuplicates="yes"
 SaveMigration.Migrate(d)
 check(d.Settings.RevealMinimum=="Rainbow" and d.Settings.RevealStyle=="Pack" and d.Settings.RevealDuplicates==false,"malformed reveal preferences are repaired")
end

-- Battle controls: AUTO ULT and HOLD ULT FOR BREAK switch on once; a later OFF survives.
do
 local d={Cards={},Settings={AutoUlt=false}}
 SaveMigration.Migrate(d)
 check(d.BattleControlsVersion==1 and d.Settings.AutoUlt==true and d.Settings.HoldUlt==true,"old saves start with AUTO ULT and HOLD ULT FOR BREAK on")
 d.Settings.AutoUlt=false;d.Settings.HoldUlt=false
 SaveMigration.Migrate(d)
 check(d.Settings.AutoUlt==false and d.Settings.HoldUlt==false,"a later OFF choice is kept (the step runs once)")
 d.Settings.HoldUlt="yes"
 SaveMigration.Migrate(d)
 check(d.Settings.HoldUlt==true,"a malformed hold setting is repaired to on")
end
