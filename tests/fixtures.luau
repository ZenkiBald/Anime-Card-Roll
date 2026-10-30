-- Shared by the battle tests and boss tuning: decks and a headless fight runner.
local Config = MODULES.Config
local Cards = MODULES.Cards
local Deck = MODULES.Deck
local Engine = MODULES.BattleEngine
local Borders = MODULES.Borders
local Awaken = MODULES.Awaken

local Fixtures = {}

-- `borders` (optional) maps card ids to the border (tier) they wear; the rest are Base. `awaken`: every card's
-- Awakening node (0-4).
function Fixtures.own(ids, stars, borders, awaken)
	local owned = {}
	for _, id in ids do
		local border = borders and borders[id] or "Normal"
		owned[id] = {
			Copies = 1,
			Stars = stars or 0,
			Mastery = {},
			Borders = if border ~= "Normal" then { [border] = true } else nil,
			BorderCopies = { [border] = 1 },
		}
		local needed = MODULES.Awaken.Nodes[awaken or 0]
		for i = 1, if needed then needed.Challenges else 0 do owned[id].Mastery[`fixture:{i}`] = true end
	end
	return owned
end

function Fixtures.allOwned(stars)
	local ids = {}
	for _, card in Cards.List do
		table.insert(ids, card.Id)
	end
	return Fixtures.own(ids, stars)
end

function Fixtures.deck(attack, support)
	local deck = Deck.Empty()
	for i, id in attack do
		deck.Attack[i] = id
	end
	for i, id in support do
		deck.Support[i] = id
	end
	return deck
end

function Fixtures.units(deck, owned)
	local list = {}
	for _, row in { "Attack", "Support" } do
		for i, id in deck[row] do
			if id ~= "" then
				-- Awakening as the server applies it: stats and bonds by node, and the node's battle effects.
				local node = Awaken.Level(owned[id])
				local effects = Awaken.Effects(node)
				local border = Deck.PlayBorder(owned[id])
				table.insert(list, {
					Id = `{string.sub(row, 1, 1)}{i}`,
					CardId = id,
					Stars = owned[id].Stars,
					Border = border,
					Copies = (owned[id].BorderCopies or {})[border], -- the duplicate bonus, as BattleService sends it
					Awaken = node,
					Trait = if #effects > 0 then effects else nil,
				})
			end
		end
	end
	return list
end

-- One whole fight. Returns the engine and every event it emitted.
function Fixtures.fight(bossId, difficulty, deck, owned, seed, autoUlt)
	local battle = Engine.new({
		Units = Fixtures.units(deck, owned),
		BossId = bossId,
		Difficulty = difficulty,
		Rng = Random.new(seed),
	})
	battle.AutoUlt = autoUlt ~= false
	local events = {}
	while not battle.Over do
		battle:Step(Config.Battle.Tick)
		for _, e in battle:TakeEvents() do
			table.insert(events, e)
		end
	end
	return battle, events
end

function Fixtures.percentile(sorted, p)
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.floor(#sorted * p + 0.5), 1, #sorted)]
end

-- Many fights: win rate, sorted win times, average KOs per fight.
function Fixtures.campaign(bossId, difficulty, deck, owned, n)
	local wins, times, kos = 0, {}, 0
	for seed = 1, n do
		local battle, events = Fixtures.fight(bossId, difficulty, deck, owned, seed * 7919)
		if battle.Result == "Win" then
			wins += 1
			table.insert(times, battle.Time)
		end
		for _, e in events do
			if e.K == "KO" and string.sub(e.T, 1, 1) == "A" then -- the player's cards, not guards
				kos += 1
			end
		end
	end
	table.sort(times)
	return wins / n, times, kos / n
end

-- The intended squad for each fight (the user's 2026-10-30 progression): World 1 Normal four Base starters,
-- Hard 2 Gold + 2 Base, Nightmare 4 Gold; World 2 Normal 4 Gold, Hard 2 Rainbow + 2 Gold, Nightmare 4 Rainbow;
-- World 3 Normal 2 Rainbow + 2 Gold, Hard 4 Rainbow, Nightmare 1 Secret + 3 Rainbow; World 4 Normal 4 Rainbow,
-- Hard 2 Secret + 2 Rainbow, Nightmare 4 Secret.
-- `Borders` maps card ids to their border (the rest are Base).
local S1 = { "heavenly_pact", "mitotic_seal", "wisteria_vial", "thunderclap_form" }
local S2 = { "sand_gourd", "puppet_threads", "storm_mantle", "blood_vow" }
local S3 = { "beast_seal", "ocular_seal", "blink_kunai", "storm_mantle" }
local BLOOD_MOON = { "celestial_eclipse_muzan", "celestial_eclipse_kokushibo", "celestial_eclipse_doma", "celestial_eclipse_akaza" }
local function wear(border, ids, supports, supportBorder, extra)
	local t = {}
	for _, id in ids do t[id] = border end
	for _, id in supports do t[id] = supportBorder or border end
	for id, b in extra or {} do t[id] = b end
	return t
end
local function fight(boss, difficulty, attack, support, border, supportBorder, extra)
	return { Boss = boss, Difficulty = difficulty, Stars = 0, Attack = attack, Support = support,
		Borders = wear(border, attack, support, supportBorder, extra) }
end
Fixtures.FIGHTS = {
	fight("kurogane", "Normal", { "kaede", "hana", "suzu", "luna" }, S1, "Normal"),
	fight("kurogane", "Hard", { "kaede", "hana", "amane", "hayate" }, S1, "Gold", "Normal", { amane = "Normal", hayate = "Normal" }),
	fight("kurogane", "Nightmare", { "tomo", "rook", "noa", "ibuki" }, S2, "Gold"),
	fight("rimeveil", "Normal", { "amane", "hayate", "tetsu", "ibuki" }, S2, "Gold"),
	fight("rimeveil", "Hard", { "goro", "sora", "amaya", "orin" }, S2, "Rainbow", "Gold", { amaya = "Gold", orin = "Gold" }),
	fight("rimeveil", "Nightmare", { "orin", "tsubasa", "kaito", "yume" }, S3, "Rainbow"),
	fight("vex", "Normal", { "kaito", "celestial_rain_broly", "celestial_rain_gogeta", "celestial_rain_goku" }, S3, "Rainbow", "Gold", { celestial_rain_gogeta = "Gold", celestial_rain_goku = "Gold" }),
	fight("vex", "Hard", { "celestial_rain_goku", "celestial_rain_vegeta", "celestial_rain_gogeta", "celestial_thunder_toji" }, S3, "Rainbow"),
	fight("vex", "Nightmare", BLOOD_MOON, S3, "Rainbow", nil, { celestial_eclipse_muzan = "Secret" }),
	fight("tenrai", "Normal", { "raijen", "aurelia", "vex_card", "tenrai_card" }, S3, "Rainbow"),
	fight("tenrai", "Hard", { "celestial_blizzard_yhwach", "celestial_thunder_sukuna", "celestial_blizzard_yamamoto", "celestial_thunder_gojo" }, S3, "Secret", nil, { celestial_blizzard_yamamoto = "Rainbow", celestial_thunder_gojo = "Rainbow" }),
	fight("tenrai", "Nightmare", BLOOD_MOON, S3, "Secret"),
}
-- Windows (the user's 2026-10-30 boss HP): 60-90 s by default. World 3 Nightmare (32M) takes the strongest
-- 1 Secret + 3 Rainbow squad about 95-100 s; World 4 Nightmare (125M) is the 110-140 s four-Secret chase.
Fixtures.FIGHTS[1].Window = { 50, 90 } -- four Base starters, the weakest squad there is, clear 60,000 HP in ~57 s
Fixtures.FIGHTS[9].Window = { 60, 100 }
Fixtures.FIGHTS[12].Window = { 110, 140 }

function Fixtures.fixtureDeck(fixture)
	local ids = table.clone(fixture.Attack)
	for _, id in fixture.Support do
		table.insert(ids, id)
	end
	local owned = Fixtures.own(ids, 0, fixture.Borders)
	-- Non-story chase fixtures explicitly request earned mastery; story fixtures use prior clears.
	if not fixture.Boss then return Fixtures.deck(fixture.Attack, fixture.Support), Fixtures.own(ids, 0, fixture.Borders, fixture.Awaken) end
	local boss = MODULES.Bosses.Get(fixture.Boss)
	local difficulty = if boss then boss.Difficulties[fixture.Difficulty].D else 1
	for _, entry in owned do for i=1,difficulty-1 do entry.Mastery[`fixture:{i}`] = true end end
	return Fixtures.deck(fixture.Attack, fixture.Support), owned
end

FIXTURES = Fixtures
