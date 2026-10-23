-- Deck rules, the battle engine, boss mechanics, rewards, and the tuning targets:
-- the first Common + Uncommon deck (about 14.6k Deck Power) beats Kurogane Normal in 60-90 s,
-- and a deck at each fight's recommended power wins it in 60-90 s.
local Config = MODULES.Config
local Deck = MODULES.Deck
local Bosses = MODULES.Bosses
local Rewards = MODULES.Rewards
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. Deck rules ---------------------------------------------------------------------
local starterIds = { "rook", "kaede", "tomo", "mirai", "hana", "goro", "suzu", "ibuki" }
local starterOwned = F.own(starterIds)
local starter = Deck.AutoBuild(starterOwned)
local starterPower = Deck.Power(starter, starterOwned)
print(`   starter deck: {table.concat(starter.Attack, ",")} / {table.concat(starter.Support, ",")} = {starterPower} power`)
check(math.abs(starterPower - 14600) <= 150, `first Common + Uncommon deck is about 14.6k power ({starterPower})`)
check(Deck.Count(starter, "Attack") == 4 and Deck.Count(starter, "Support") == 4, "auto-build fills 4 Attack + 4 Support")
check(starter.Attack[1] == "tomo" and starter.Support[1] == "suzu", "auto-build puts the strongest card on the left")

local ok = Deck.Validate({ Attack = { "rook", "", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(ok ~= nil, "a deck with empty slots is valid")
local _, why = Deck.Validate({ Attack = { "rook", "rook", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(why == "Duplicate", "the same card twice is refused")
_, why = Deck.Validate({ Attack = { "hana", "", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(why == "WrongType", "a Support card in an Attack slot is refused")
_, why = Deck.Validate({ Attack = { "sora", "", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(why == "NotOwned", "a card the player doesn't own is refused")
local badShapes = {
	{ Attack = { "rook", "", "" }, Support = { "", "", "", "" } },
	{ Attack = { "rook", "", "", "", "" }, Support = { "", "", "", "" } },
	{ Attack = { "rook", "", "", "" } },
	{ Attack = { "rook", "", "", "" }, Support = { "", "", "", 5 } },
	{ Attack = { "rook", "", "", "" }, Support = { "", "", "", "" }, Extra = {} },
	{ Attack = { x = "rook", "", "", "" }, Support = { "", "", "", "" } },
	"rook",
}
local allBad = true
for _, shape in badShapes do
	if Deck.Validate(shape, starterOwned) ~= nil then
		allBad = false
	end
end
check(allBad, "malformed decks are refused")

-- 2. Engine rules ----------------------------------------------------------------------
do
	-- Damage formula: Rook's first hit = 110 ATK x 100% x (1 - target DEF), or x1.5 on a crit. His
	-- first target is Kurogane's Warder (the Ironclad taunts, 15% DEF): 94, or 140 on a crit.
	local deck = F.deck({ "rook" }, {})
	local battle, events = F.fight("kurogane", "Normal", deck, starterOwned, 3)
	local first
	for _, e in events do
		if e.K == "Hit" and e.U == "A1" then
			first = e
			break
		end
	end
	local def = first and battle.ById[first.T].DEF or 0
	local plain, crit = math.floor(110 * (1 - def) + 0.5), math.floor(110 * 1.5 * (1 - def) + 0.5)
	check(first ~= nil and first.T == "G3" and (first.A == plain or (first.C and first.A == crit)), `damage formula (Rook's first hit {first and first.A} on {first and first.T})`)
end

do
	-- Equal SPD: the left card acts first (Hana and Ibuki are both SPD 100).
	local deck = F.deck({ "rook" }, { "hana", "ibuki" })
	local _, events = F.fight("kurogane", "Normal", deck, starterOwned, 5)
	local order = {}
	for _, e in events do
		if e.K == "Act" and e.Ab ~= "Opening" and (e.U == "S1" or e.U == "S2") then
			table.insert(order, e.U)
		end
	end
	check(order[1] == "S1" and order[2] == "S2", "equal SPD: the left card acts first")
end

do
	-- Support cards: no HP, never targeted, never KO'd; each casts its Basic as the fight opens.
	local battle, events = F.fight("kurogane", "Normal", starter, starterOwned, 9)
	local supportHit, supportKO, opened, firstHitAt = false, false, {}, nil
	for i, e in events do
		if (e.K == "Hit" or e.K == "Burn" or e.K == "Miss") and e.U == "Boss" and string.sub(e.T, 1, 1) == "S" then
			supportHit = true
		end
		if e.K == "KO" and string.sub(e.T, 1, 1) == "S" then
			supportKO = true
		end
		if e.K == "Act" and e.Ab == "Opening" then
			opened[e.U] = i
		end
		if firstHitAt == nil and e.K == "Act" and e.Ab ~= "Opening" then
			firstHitAt = i
		end
	end
	local allOpened = true
	for i = 1, 4 do
		local at = opened[`S{i}`]
		if at == nil or at > firstHitAt then
			allOpened = false
		end
	end
	check(not supportHit and not supportKO, "Support cards are never hit or KO'd")
	check(allOpened, "every Support card casts its Basic before the first action")
	local snap = battle:Snapshot()
	check(snap.U.S1.H == nil and snap.U.A1.H ~= nil, "Support cards have no HP in the battle snapshot")
end

do
	-- Ultimates need 100 energy and are refused before that.
	local strongOwned = F.allOwned(0)
	local strong = Deck.AutoBuild(strongOwned)
	local b = Engine.new({ Units = F.units(strong, strongOwned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(2) })
	check(b:UseUltimate("A1") == false, "an Ultimate is refused without energy")
	b.ById.A1.Energy = Config.Battle.UltimateCost
	check(b:UseUltimate("A1") == true and b.ById.A1.Energy == 0, "an Ultimate fires at 100 energy and spends it")
	check(b:UseUltimate("Boss") == false and b:UseUltimate("Z9") == false, "Ultimate requests for bad ids are refused")
end

do
	-- Traits: a speed trait makes the card faster for the whole fight, an energy trait starts its
	-- Ultimate charged, and neither changes the card's ATK.
	local owned = F.allOwned(0)
	local deck = Deck.AutoBuild(owned)
	local units = F.units(deck, owned)
	local plain = Engine.new({ Units = units, BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5) })
	for _, unit in units do
		if unit.Id == "A1" then
			unit.Trait = { { Stat = "SPD", Amount = 0.1 }, { Stat = "StartEnergy", Amount = 0.25 } }
		end
	end
	local geared = Engine.new({ Units = units, BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5) })
	check(math.abs(geared:Speed(geared.ById.A1) - plain:Speed(plain.ById.A1) * 1.1) < 1e-6, "a +10% speed trait makes the card 10% faster")
	check(geared.ById.A1.Energy == 0.25 * Config.Battle.UltimateCost, "a +25% energy trait starts the Ultimate a quarter charged")
	check(geared.ById.A1.Main == plain.ById.A1.Main, "traits never change a card's ATK")
end

-- 3. Boss mechanics -------------------------------------------------------------------------
local function eventsFor(index, seed)
	local fx = F.FIGHTS[index]
	local deck, owned = F.fixtureDeck(fx)
	return F.fight(fx.Boss, fx.Difficulty, deck, owned, seed)
end

do
	local _, events = eventsFor(1, 21)
	local seen = {}
	for _, e in events do
		seen[e.K] = true
		if e.K == "Burn" and e.T ~= "Boss" then
			seen.AllyBurn = true
		end
	end
	check(seen.Phase and seen.Enrage and seen.Warn and seen.AllyBurn, "Kurogane burns, warns, adds Ash Storm at 50% and enrages at 20%")
end

do
	local _, events = eventsFor(4, 21)
	local frozen, thawed, slowed = false, false, false
	for _, e in events do
		frozen = frozen or e.K == "Frozen"
		thawed = thawed or e.K == "Thaw"
		slowed = slowed or e.K == "Slow"
	end
	check(frozen and thawed and slowed, "Rimeveil freezes a card (it skips an action) and slows the deck at 50%")
end

do
	local _, events = eventsFor(7, 21)
	local barrier, broke, stolen, leaked = false, false, false, false
	for _, e in events do
		barrier = barrier or e.K == "Barrier"
		broke = broke or e.K == "Break"
		stolen = stolen or e.K == "Steal"
		leaked = leaked or (e.K == "Hit" and e.Bl == true)
	end
	check(barrier and broke and leaked and stolen, "Vex raises Null Barrier, it leaks Basic damage, Skills break it, and he steals buffs")
end

do
	-- Hard adds a move Normal doesn't have; Nightmare warnings are shorter.
	local normal = Engine.new({ Units = F.units(starter, starterOwned), BossId = "kurogane", Difficulty = "Normal" })
	local hard = Engine.new({ Units = F.units(starter, starterOwned), BossId = "kurogane", Difficulty = "Hard" })
	local nightmare = Engine.new({ Units = F.units(starter, starterOwned), BossId = "kurogane", Difficulty = "Nightmare" })
	check(#hard.Boss.Moves == #normal.Boss.Moves + 1, "Hard adds an extra boss move")
	check(nightmare.WarnSeconds < normal.WarnSeconds, "Nightmare warnings are shorter")
end

-- 3b. Squads (4v4) ----------------------------------------------------------------------------
do
	-- Every boss brings three guards; a Warder taunts the cards and shields the leader.
	local b = Engine.new({ Units = F.units(starter, starterOwned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(4) })
	check(#b.Enemies == 4 and b.ById.G1 and b.ById.G3.Taunt, "Kurogane fights with three guards, the Ironclad (a Warder) in front")
	check(b:CardTarget() == b.ById.G3, "with no target picked, cards hit the taunting Warder first")
	check(b:SetFocus("Boss") and b:CardTarget() == b.Boss, "tapping the leader focuses every card on it")
	check(not b:SetFocus("A1") and not b:SetFocus("Nope") and not b:SetFocus(7), "focus refuses cards, unknown ids and junk")
	check(b:Protection(b.Boss) > 0 and b:Protection(b.ById.G1) == 0, "a standing Warder protects only the leader")
	b.ById.G3.Alive = false
	check(b:Protection(b.Boss) == 0, "with the Warder down the leader loses its protection")
	b:SetFocus(nil)
	check(b:CardTarget() ~= b.Boss, "without a Warder or a focus, cards pick the weakest enemy (a guard before the leader)")
end

do
	-- The fight is won when the leader falls, guards or not; downed guards stay down.
	local b = Engine.new({ Units = F.units(starter, starterOwned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(4) })
	b:DamageEnemy(b.ById.G1, b.ById.A1, b.ById.G1.MaxHP, false, "Hit")
	check(not b.ById.G1.Alive and not b.Over, "a guard at 0 HP is down and the fight goes on")
	check(not b:SetFocus("G1"), "a downed guard can't be targeted")
	b:DamageEnemy(b.Boss, b.ById.A1, b.Boss.MaxHP, false, "Hit")
	check(b.Over and b.Result == "Win", "the leader falling wins the fight")
end

do
	-- Menders heal the squad; area attacks hit every enemy.
	local fx = F.FIGHTS[1]
	local deck, owned = F.fixtureDeck(fx)
	local _, events = F.fight(fx.Boss, fx.Difficulty, deck, owned, 11)
	local healed, rallied = false, false
	for _, e in events do
		healed = healed or (e.K == "EnemyHeal" and e.A > 0)
		rallied = rallied or e.K == "Rally"
	end
	check(healed and rallied, "the Ember Monk heals hurt enemies and rallies the squad")
	local b = Engine.new({ Units = F.units(F.deck({ "hayate" }, {}), F.own({ "hayate" })), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(1) })
	b:RunAbility(b.ById.A1, b.ById.A1.Skill, "Skill")
	local hit = {}
	for _, e in b:TakeEvents() do
		if e.K == "Hit" and e.U == "A1" then
			hit[e.T] = true
		end
	end
	check(hit.Boss and hit.G1 and hit.G2 and hit.G3, "Hayate's Cyclone hits every enemy")
end

-- 4. Progression and rewards ------------------------------------------------------------------
check(Bosses.IsUnlocked({}, "kurogane", "Normal"), "World 1 Normal is open from the start")
check(not Bosses.IsUnlocked({}, "kurogane", "Hard") and not Bosses.IsUnlocked({}, "rimeveil", "Normal"), "Hard and World 2 start locked")
check(
	Bosses.IsUnlocked({ ["kurogane:Normal"] = true }, "kurogane", "Hard")
		and Bosses.IsUnlocked({ ["kurogane:Normal"] = true }, "rimeveil", "Normal"),
	"clearing Normal unlocks that boss's Hard and the next world's Normal"
)
check(Bosses.IsUnlocked({ ["kurogane:Hard"] = true }, "kurogane", "Nightmare"), "clearing Hard unlocks Nightmare")

local rewardsOk = true
local DESIGN = { -- D = rolls, luck, floor, first-clear bonus (design doc table)
	{ 5, 1.35, "Uncommon", "Rare" },
	{ 7, 1.70, "Uncommon", "Rare" },
	{ 9, 2.05, "Rare", "Epic" },
	{ 11, 2.40, "Rare", "Epic" },
	{ 13, 2.75, "Rare", "Epic" },
	{ 15, 3.10, "Rare", "Epic" },
	{ 17, 3.45, "Epic", "Legendary" },
	{ 19, 3.80, "Epic", "Legendary" },
	{ 21, 4.00, "Epic", "Legendary" },
}
for d, row in DESIGN do
	local r = Rewards.For(d)
	if r.Rolls ~= row[1] or not near(r.Luck, row[2], 1e-9) or r.Floor ~= row[3] or r.Bonus ~= row[4] then
		rewardsOk = false
		print(`   D{d}: {r.Rolls} rolls, {r.Luck}x, {r.Floor}, {r.Bonus}`)
	end
end
check(rewardsOk, "reward rolls, boss luck, floor and first-clear bonus match the design table for D 1-9")
check(near(Rewards.TotalLuck(4, 2), 5), "boss luck x player luck is capped at 5x")

local dOk = true
for _, boss in Bosses.List do
	for i, name in Bosses.DifficultyOrder do
		local diff = boss.Difficulties[name]
		if diff == nil or diff.D ~= (boss.World - 1) * 3 + i then
			dOk = false
		end
	end
end
check(dOk, "every world has Normal / Hard / Nightmare with D in order (World 1 Normal = 1)")

-- 5. Tuning -------------------------------------------------------------------------------------
local rate, times, kos = F.campaign("kurogane", "Normal", starter, starterOwned, 200)
local inWindow = 0
for _, t in times do
	if t >= 60 and t <= 90 then
		inWindow += 1
	end
end
print(
	string.format(
		"   14.6k starter vs Kurogane Normal: %d%% wins, p10 %.1fs / median %.1fs / p90 %.1fs, %.2f KOs",
		rate * 100,
		F.percentile(times, 0.1),
		F.percentile(times, 0.5),
		F.percentile(times, 0.9),
		kos
	)
)
check(rate >= 0.95, `the 14.6k deck wins at least 95% of fights ({math.floor(rate * 100)}%)`)
check(#times > 0 and inWindow / #times >= 0.9, `90%+ of its wins take 60-90 s ({inWindow}/{#times})`)

for _, fx in F.FIGHTS do
	local deck, owned = F.fixtureDeck(fx)
	local power = Deck.Power(deck, owned)
	local recommended = Bosses.Get(fx.Boss).Difficulties[fx.Difficulty].Recommended
	local r, t, k = F.campaign(fx.Boss, fx.Difficulty, deck, owned, 100)
	local median = F.percentile(t, 0.5)
	print(
		string.format(
			"   %-8s %-9s deck %6d (rec %6d): %3d%% wins, median %.1fs, %.2f KOs",
			fx.Boss,
			fx.Difficulty,
			power,
			recommended,
			r * 100,
			median,
			k
		)
	)
	check(
		math.abs(power - recommended) / recommended <= 0.1 and r >= 0.9 and median >= 60 and median <= 90,
		`{fx.Boss} {fx.Difficulty}: a deck at the recommended power wins in 60-90 s`
	)
end

local lone = F.campaign("kurogane", "Normal", F.deck({ "rook" }, {}), starterOwned, 20)
check(lone == 0, "a single Common card loses")
