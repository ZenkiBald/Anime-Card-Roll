-- Deck rules, the battle engine, boss mechanics, rewards, and the tuning targets:
-- the first all-Base deck (about 31.5k Deck Power) is too weak for Kurogane Normal (it needs Gold borders,
-- tests/fixtures.luau), and a deck at each fight's recommended power wins it in 60-90 s.
local Config = MODULES.Config
local Deck = MODULES.Deck
local Cards = MODULES.Cards
local Bosses = MODULES.Bosses
local Rewards = MODULES.Rewards
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. Deck rules ---------------------------------------------------------------------
local starterIds = { "rook", "kaede", "tomo", "noa", "mitotic_seal", "wisteria_vial", "thunderclap_form", "heavenly_pact" }
local starterOwned = F.own(starterIds)
local starter = Deck.AutoBuild(starterOwned)
local starterPower = Deck.Power(starter, starterOwned)
print(`   starter deck: {table.concat(starter.Attack, ",")} / {table.concat(starter.Support, ",")} = {starterPower} power`)
check(math.abs(starterPower - 31500) <= 600, `the first all-Base deck is about 31.5k power ({starterPower})`)
check(Deck.Count(starter, "Attack") == 4 and Deck.Count(starter, "Support") == 4, "auto-build fills 4 Attack + 4 Support")
check(starter.Attack[1] == "noa" and starter.Support[1] == "heavenly_pact", "auto-build puts the strongest card on the left")

local ok = Deck.Validate({ Attack = { "rook", "", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(ok ~= nil, "a deck with empty slots is valid")
local _, why = Deck.Validate({ Attack = { "rook", "rook", "", "" }, Support = { "", "", "", "" } }, starterOwned)
check(why == "Duplicate", "the same card twice is refused")
_, why = Deck.Validate({ Attack = { "mitotic_seal", "", "", "" }, Support = { "", "", "", "" } }, starterOwned)
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
	-- Damage formula: Rook's first hit = his ATK x 100% x (1 - target DEF), or x1.5 on a
	-- crit. His first target is Kurogane's Warder (the Ironclad taunts, 15% DEF).
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
	local rook = Cards.Get("rook") :: any
	local rookAtk = Cards.Stat(rook, rook.Main, 0, "Normal")
	local plain, crit = math.floor(rookAtk * (1 - def) + 0.5), math.floor(rookAtk * 1.5 * (1 - def) + 0.5)
	check(first ~= nil and first.T == "G3" and (first.A == plain or (first.C and first.A == crit)), `damage formula (Rook's first hit {first and first.A} on {first and first.T})`)
end

do
	local b = Engine.new({ Units = F.units(F.deck({ "rook", "tomo" }, {}), starterOwned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5) })
	b.ById.A1.SPD, b.ById.A2.SPD = 100, 100
	b.ById.A1.Buffs, b.ById.A2.Buffs = {}, {}
	b.ById.A1.Gauge, b.ById.A2.Gauge = 1, 1
	b:Step(Config.Battle.Tick)
	local first
	for _, e in b:TakeEvents() do if e.K == "Act" then first = first or e.U end end
	check(first == "A1" and b.ById.A2.Gauge >= 1, "equal SPD and gauge: the left attacker acts first")
end

do
	-- Passive Supports: no HP, enemy targets, KOs or opening actions.
	local battle, events = F.fight("kurogane", "Normal", starter, starterOwned, 9)
	local supportHit, supportKO, opened = false, false, {}
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
	end
	check(not supportHit and not supportKO, "Support cards are never hit or KO'd")
	check(next(opened) == nil, "passive Support cards do not cast opening moves")
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
	check(b:UseUltimate("A1") == false, "full energy cannot bypass the opening Ultimate cooldown")
	b.Time=Config.Battle.UltimateMinSeconds
	check(b:UseUltimate("A1") == true and b.ById.A1.Energy == 0, "an Ultimate fires after its cooldown at full energy")
	b.ById.A1.Energy=Config.Battle.UltimateCost
	check(not b:UseUltimate("A1"), "refilling energy cannot bypass the per-card cooldown")
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
	-- Speed buffs add up (a Tempest synergy may already be on): +10% of the card's base SPD.
	check(math.abs(geared:Speed(geared.ById.A1) - plain:Speed(plain.ById.A1) - plain.ById.A1.SPD * 0.1) < 1e-6, "a +10% speed trait makes the card 10% faster")
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
local DESIGN = { -- D = rolls, luck (design doc table; reward floors went with the rarities)
	{ 5, 1.35 }, { 7, 1.70 }, { 9, 2.05 }, { 11, 2.40 }, { 13, 2.75 }, { 15, 3.10 }, { 17, 3.45 }, { 19, 3.80 }, { 21, 4.00 },
}
for d, row in DESIGN do
	local r = Rewards.For(d)
	if r.Rolls ~= row[1] or not near(r.Luck, row[2], 1e-9) then
		rewardsOk = false
		print(`   D{d}: {r.Rolls} rolls, {r.Luck}x`)
	end
end
check(rewardsOk, "reward rolls and boss luck match the design table for D 1-9")
check(near(Rewards.TotalLuck(4,8),32), "boss luck multiplies earned luck without a hard cap")

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
-- Kurogane Normal is 250,000 HP (the user's 2026-10-30 call): the first all-Base deck runs out of time,
-- and the Gold World 1 fixture is the first deck that clears it.
local rate = F.campaign("kurogane", "Normal", starter, starterOwned, 30)
print(string.format("   31.5k all-Base starter vs Kurogane Normal: %d%% wins", rate * 100))
check(rate == 0, `the all-Base starter deck can't beat Kurogane Normal yet ({math.floor(rate * 100)}%)`)

for _, fx in F.FIGHTS do
	local deck, owned = F.fixtureDeck(fx)
	local power = Deck.Power(deck, owned)
	local recommended = Bosses.Get(fx.Boss).Difficulties[fx.Difficulty].Recommended
	local r, t, k = F.campaign(fx.Boss, fx.Difficulty, deck, owned, if fx.Unwinnable then 20 else 100)
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
	if fx.Unwinnable then
		-- Reported, not required: no deck in the game wins it (docs/LAUNCH_CHECKLIST.md).
		print(`   NOTE {fx.Boss} {fx.Difficulty}: the strongest possible deck wins {math.floor(r * 100)}% (out of reach)`)
	else
		local top = if fx.Chase then 100 else 90
		check(
			math.abs(power - recommended) / recommended <= 0.1 and r >= 0.9 and median >= 60 and median <= top,
			`{fx.Boss} {fx.Difficulty}: a deck at the recommended power wins in 60-{top} s`
		)
	end
end

local lone = F.campaign("kurogane", "Normal", F.deck({ "rook" }, {}), starterOwned, 20)
check(lone == 0, "a single Common card loses")

-- Threat and rhythm (2026-10-26): squads take real damage, even far above a fight's power, and a fight opens
-- as a run of turns, not one burst.
do
	local Engine = MODULES.BattleEngine
	local fx = F.FIGHTS[3] -- Kurogane Nightmare
	local deck, owned = F.fixtureDeck(fx)
	local healed, lowest = 0, 1
	for seed = 1, 10 do
		local battle, events = F.fight(fx.Boss, fx.Difficulty, deck, owned, seed * 131)
		for _, e in events do
			if e.K == "Heal" then
				healed += e.A or 0
			end
		end
		for _, unit in battle.Allies do
			if unit.HasHP then
				lowest = math.min(lowest, if unit.Alive then unit.HP / unit.MaxHP else 0)
			end
		end
	end
	check(lowest < 0.7, `a Nightmare fight hurts without repeated Support healing; limited healing ({healed}) and a card drops below 70% HP ({math.floor(lowest * 100)}%)`)

	-- A deck ten times the fight's power still feels the hits (Config.Battle.MinHit).
	local strong = F.own({ "tomo", "noa", "rook", "kaede", "mitotic_seal", "wisteria_vial" }, 5, { tomo = "Rainbow", noa = "Rainbow", rook = "Rainbow", kaede = "Rainbow" })
	local b = Engine.new({ Units = F.units(F.deck({ "tomo", "noa", "rook", "kaede" }, { "mitotic_seal", "wisteria_vial" }), strong), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5) })
	local taken = 0
	for _ = 1, 60 do
		b:Step(MODULES.Config.Battle.Tick)
		for _, e in b:TakeEvents() do
			if e.K == "Hit" and string.sub(e.T or "", 1, 1) == "A" then
				taken += e.A
			end
		end
	end
	check(taken > 0, `an overpowered deck still takes hits in its first 6 s ({taken} damage)`)

	-- The opening: bars start part-filled, one unit acts per tick.
	local c = Engine.new({ Units = F.units(deck, owned), BossId = fx.Boss, Difficulty = fx.Difficulty, Rng = Random.new(9) })
	local perTick = 0
	for _ = 1, 20 do
		c:Step(MODULES.Config.Battle.Tick)
		local acts = 0
		for _, e in c:TakeEvents() do
			if e.K == "Act" and e.Ab ~= "Opening" and e.Ab ~= "Ultimate" then
				acts += 1
			end
		end
		perTick = math.max(perTick, acts)
	end
	check(perTick <= 2, `units take turns: at most one action (plus an echo) per tick in the opening 2 s (saw {perTick})`)
	local snap = c:Snapshot()
	local hasSkillCountdown = false
	for id, s in snap.U do
		if string.sub(id, 1, 1) == "A" and s.K ~= nil then
			hasSkillCountdown = true
		end
	end
	check(hasSkillCountdown and snap.U.Boss.Nx ~= nil, "the snapshot carries each card's Skill countdown and the leader's next big move")
end
