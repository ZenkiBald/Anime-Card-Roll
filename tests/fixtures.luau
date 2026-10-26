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
				table.insert(list, {
					Id = `{string.sub(row, 1, 1)}{i}`,
					CardId = id,
					Stars = owned[id].Stars,
					Border = Deck.PlayBorder(owned[id]),
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

-- A deck at about the recommended power for each fight, built the way a player would get there without
-- chasing Rainbow / Secret (those are for the towers): World 1 on Base cards, World 2 brings in Gold borders
-- (from luck or fusing 100 copies), World 3 is all Gold, World 4 is all Gold at 5 stars, Awakening up to node 3.
-- `Borders` maps card ids to their border (the rest are Base); `Awaken` is every card's Awakening node.
Fixtures.FIGHTS = {
	{ Boss = "kurogane", Difficulty = "Normal", Stars = 0,
		Attack = { "tomo", "noa", "rook", "kaede" }, Support = { "ibuki", "hana", "luna" } },
	{ Boss = "kurogane", Difficulty = "Hard", Stars = 5,
		Attack = { "tomo", "noa", "rook", "kaede" }, Support = { "suzu", "ibuki", "hana", "luna" } },
	{ Boss = "kurogane", Difficulty = "Nightmare", Stars = 0, Borders = { sora = "Gold", amane = "Gold" },
		Attack = { "sora", "hayate", "tomo", "noa" }, Support = { "amane", "suzu", "ibuki", "hana" } },
	{ Boss = "rimeveil", Difficulty = "Normal", Stars = 0, Borders = { kaede = "Gold", sora = "Gold", tetsu = "Gold" },
		Attack = { "kaede", "sora", "tomo", "noa" }, Support = { "tetsu", "yume", "suzu", "ibuki" } },
	{ Boss = "rimeveil", Difficulty = "Hard", Stars = 0, Borders = { kaito = "Gold", akane = "Gold", sora = "Gold", luna = "Gold", tetsu = "Gold", yume = "Gold" },
		Attack = { "kaito", "akane", "sora", "noa" }, Support = { "luna", "tetsu", "yume", "hana" } },
	{ Boss = "rimeveil", Difficulty = "Nightmare", Stars = 0, Borders = { kaito = "Gold", akane = "Gold", sora = "Gold", tomo = "Gold", luna = "Gold", tetsu = "Gold", yume = "Gold", suzu = "Gold" },
		Attack = { "kaito", "akane", "sora", "tomo" }, Support = { "luna", "tetsu", "yume", "suzu" } },
	{ Boss = "vex", Difficulty = "Normal", Stars = 0, Borders = { kaito = "Gold", akane = "Gold", sora = "Gold", tomo = "Gold", luna = "Gold", tetsu = "Gold", yume = "Gold" },
		Attack = { "kaito", "akane", "sora", "tomo" }, Support = { "luna", "tetsu", "yume", "suzu" } },
	{ Boss = "vex", Difficulty = "Hard", Stars = 5, Borders = { mirai = "Gold", kaito = "Gold", akane = "Gold", sora = "Gold", orin = "Gold", luna = "Gold", tetsu = "Gold", yume = "Gold" },
		Attack = { "mirai", "kaito", "akane", "sora" }, Support = { "orin", "luna", "tetsu", "yume" } },
	{ Boss = "vex", Difficulty = "Nightmare", Stars = 5, Awaken = 1, Borders = { raijen = "Gold", mirai = "Gold", kaito = "Gold", akane = "Gold", orin = "Gold", luna = "Gold", tetsu = "Gold", yume = "Gold" },
		Attack = { "raijen", "mirai", "kaito", "akane" }, Support = { "orin", "luna", "tetsu", "yume" } },
	-- World 4: Amane's cleanse answers Thunderclap; all Gold at 5 stars, Awakening climbs.
	{ Boss = "tenrai", Difficulty = "Normal", Stars = 5, Awaken = 1, Borders = { raijen = "Gold", mirai = "Gold", tsubasa = "Gold", akane = "Gold", aurelia = "Gold", yume = "Gold", orin = "Gold", amane = "Gold" },
		Attack = { "raijen", "mirai", "tsubasa", "akane" }, Support = { "aurelia", "yume", "orin", "amane" } },
	{ Boss = "tenrai", Difficulty = "Hard", Stars = 5, Awaken = 2, Borders = { raijen = "Gold", mirai = "Gold", tsubasa = "Gold", akane = "Gold", aurelia = "Gold", yume = "Gold", orin = "Gold", amane = "Gold" },
		Attack = { "raijen", "mirai", "tsubasa", "akane" }, Support = { "aurelia", "yume", "orin", "amane" } },
	{ Boss = "tenrai", Difficulty = "Nightmare", Stars = 5, Awaken = 3, Borders = { raijen = "Gold", mirai = "Gold", tsubasa = "Gold", akane = "Gold", aurelia = "Gold", yume = "Gold", orin = "Gold", amane = "Gold" },
		Attack = { "raijen", "mirai", "tsubasa", "akane" }, Support = { "aurelia", "yume", "orin", "amane" } },
}

function Fixtures.fixtureDeck(fixture)
	local ids = table.clone(fixture.Attack)
	for _, id in fixture.Support do
		table.insert(ids, id)
	end
	local owned = Fixtures.own(ids, 0, fixture.Borders)
	local boss = MODULES.Bosses.Get(fixture.Boss)
	local difficulty = if boss then boss.Difficulties[fixture.Difficulty].D else 1
	for _, entry in owned do for i=1,difficulty-1 do entry.Mastery[`fixture:{i}`] = true end end
	return Fixtures.deck(fixture.Attack, fixture.Support), owned
end

FIXTURES = Fixtures
