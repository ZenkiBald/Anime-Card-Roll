-- Shared by the battle tests and boss tuning: decks and a headless fight runner.
local Config = MODULES.Config
local Cards = MODULES.Cards
local Deck = MODULES.Deck
local Engine = MODULES.BattleEngine

local Fixtures = {}

-- `fusion` (optional) maps card ids to how many times they're fused.
function Fixtures.own(ids, stars, fusion)
	local owned = {}
	for _, id in ids do
		owned[id] = { Copies = 1, Stars = stars or 0, Fusion = fusion and fusion[id] }
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
				table.insert(list, { Id = `{string.sub(row, 1, 1)}{i}`, CardId = id, Stars = owned[id].Stars, Fusion = owned[id].Fusion })
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

-- A deck at about the recommended power for each fight, built the way a player would get there.
Fixtures.FIGHTS = {
	{ Boss = "kurogane", Difficulty = "Normal", Stars = 0,
		Attack = { "tomo", "mirai", "rook", "kaede" }, Support = { "ibuki", "hana", "goro" } },
	{ Boss = "kurogane", Difficulty = "Hard", Stars = 5,
		Attack = { "tomo", "mirai", "rook", "kaede" }, Support = { "suzu", "ibuki", "hana", "goro" } },
	{ Boss = "kurogane", Difficulty = "Nightmare", Stars = 0,
		Attack = { "akane", "sora", "tomo", "mirai" }, Support = { "yume", "suzu", "ibuki", "hana" } },
	{ Boss = "rimeveil", Difficulty = "Normal", Stars = 0,
		Attack = { "akane", "sora", "tomo", "mirai" }, Support = { "tetsu", "yume", "suzu", "ibuki" } },
	{ Boss = "rimeveil", Difficulty = "Hard", Stars = 0,
		Attack = { "kaito", "akane", "sora", "mirai" }, Support = { "luna", "tetsu", "yume", "hana" } },
	{ Boss = "rimeveil", Difficulty = "Nightmare", Stars = 5,
		Attack = { "kaito", "akane", "sora", "tomo" }, Support = { "luna", "tetsu", "yume", "suzu" } },
	{ Boss = "vex", Difficulty = "Normal", Stars = 3,
		Attack = { "kaito", "akane", "sora", "tomo" }, Support = { "luna", "tetsu", "yume", "suzu" } },
	{ Boss = "vex", Difficulty = "Hard", Stars = 0,
		Attack = { "noa", "kaito", "akane", "sora" }, Support = { "orin", "luna", "tetsu", "yume" } },
	{ Boss = "vex", Difficulty = "Nightmare", Stars = 0,
		Attack = { "raijen", "noa", "kaito", "akane" }, Support = { "orin", "luna", "tetsu", "yume" } },
	-- World 4: Amane's cleanse answers Thunderclap; Nightmare needs a few fusions on top of 5 stars.
	{ Boss = "tenrai", Difficulty = "Normal", Stars = 0,
		Attack = { "raijen", "noa", "kaito", "tsubasa" }, Support = { "aurelia", "amaya", "orin", "amane" } },
	{ Boss = "tenrai", Difficulty = "Hard", Stars = 5,
		Attack = { "raijen", "noa", "kaito", "tsubasa" }, Support = { "aurelia", "amaya", "orin", "amane" } },
	{ Boss = "tenrai", Difficulty = "Nightmare", Stars = 5, Fusion = { kaito = 1, tsubasa = 1, amane = 2 },
		Attack = { "raijen", "noa", "kaito", "tsubasa" }, Support = { "aurelia", "amaya", "orin", "amane" } },
}

function Fixtures.fixtureDeck(fixture)
	local ids = table.clone(fixture.Attack)
	for _, id in fixture.Support do
		table.insert(ids, id)
	end
	local owned = Fixtures.own(ids, fixture.Stars, fixture.Fusion)
	return Fixtures.deck(fixture.Attack, fixture.Support), owned
end

FIXTURES = Fixtures
