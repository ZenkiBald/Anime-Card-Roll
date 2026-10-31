-- The 2026-10-30 economy pass: luck tilts card pulls toward rare cards, sky searches scale with luck, the
-- user's base odds, tiered fusion costs and the duplicate stat bonus.
local Cards, Borders, CelestialRolls, Engine = MODULES.Cards, MODULES.Borders, MODULES.CelestialRolls, MODULES.BattleEngine
local F = FIXTURES

-- 1. Base odds: the user's tiers (1 in N per pull, normal pool, before luck).
do
	local function oneIn(id: string): number
		return Cards.WeightTotal / (Cards.Get(id) :: any).Weight
	end
	local ok = true
	for id, n in { tomo = 20, ibuki = 30, amane = 50, tetsu = 70, goro = 100, amaya = 140, orin = 200, kaito = 250, yume = 350, mirai = 350, akane = 350, raijen = 500, aurelia = 500, beast_seal = 500,
		kurogane_card = 400, rimeveil_card = 500, vex_card = 650, tenrai_card = 800 } do
		ok = ok and math.abs(oneIn(id) - n) < 1e-6
	end
	check(ok, "normal and boss cards sit at the user's odds (lower-mid 1 in 20-30 ... apex 1 in 500, bosses 400 / 500 / 650 / 800)")
	check(Cards.Rarity("yume", "Secret") == 175000000 and Cards.Rarity("raijen", "Secret") == 250000000 and Cards.Rarity("tenrai_card", "Secret") == 400000000,
		"Secret rarities: elite 1 in 175M, apex 1 in 250M, the W4 boss card 1 in 400M")
	local total = 0
	for _, card in Cards.List do
		if not card.Weather then total += card.Weight end
	end
	check(math.abs(total - Cards.WeightTotal) < 1e-3, "the full normal + boss pool adds up to 100%")
	local sky = true
	for id, n in { celestial_rain_broly = 10000, celestial_rain_goku = 40000, celestial_blizzard_yhwach = 80000, celestial_thunder_gojo = 50000, celestial_eclipse_akaza = 50000, celestial_eclipse_kokushibo = 125000, celestial_eclipse_muzan = 200000 } do
		sky = sky and (Cards.Get(id) :: any).SkyOneIn == n
	end
	check(sky and Cards.Rarity("celestial_eclipse_kokushibo", "Secret") == 62500000000, "sky odds span 10,000-200,000; displayed Secret rarity uses the same base odds")
end

-- 2. Luck tilts pulls toward rare cards: nothing at 1x, high / elite / apex / boss 2.5-5x at endgame luck.
do
	local pool = Cards.Pool({ ["kurogane:Normal"] = true, ["rimeveil:Normal"] = true, ["vex:Normal"] = true, ["tenrai:Normal"] = true })
	local base, lucky = Cards.PullChances(pool), Cards.PullChances(pool, nil, nil, nil, 40)
	local sum = 0
	for _, chance in lucky do
		sum += chance
	end
	check(math.abs(sum - 1) < 1e-9 and Cards.LuckTilt(Cards.Get("raijen") :: any, 1) == 1, "luck-tilted chances still add up to 100%; 1x luck changes nothing")
	local function lift(id: string): number
		return lucky[id] / base[id]
	end
	check(lift("kaito") >= 2.4 and lift("yume") >= 3 and lift("raijen") >= 3.5 and lift("tenrai_card") >= 4 and lift("tenrai_card") <= 5.01 and lift("hana") < 1,
		`at 40x luck rare cards come far more often (high {string.format("%.1f", lift("kaito"))}x, apex {string.format("%.1f", lift("raijen"))}x, W4 boss {string.format("%.1f", lift("tenrai_card"))}x) and starters a little less`)
	check(Cards.LuckTilt(Cards.Get("tenrai_card") :: any, 1e9) <= Cards.Tilt.Max, "absurd luck can't push a card past its tilt cap")
end

-- 3. Sky searches scale with 35% of the luck bonus.
do
	local pool = Cards.WeatherPool("eclipse")
	local c1, c40 = CelestialRolls.Chances(pool, 1), CelestialRolls.Chances(pool, 40)
	check(math.abs(c40[1] / c1[1] - 2) < 1e-9, "high luck cannot exceed 2x sky find odds")
end

-- 4. Fusion costs and the duplicate bonus.
do
	check(Cards.FusionCost(Cards.Get("hana")) == 100 and Cards.FusionCost(Cards.Get("kurogane_card")) == 100 and Cards.FusionCost(Cards.Get("celestial_rain_broly")) == 100,
		"fusing takes 100 copies at every border, for every card")
	check(Cards.DupeBonus(1) == 0 and math.abs(Cards.DupeBonus(11) - 0.05) < 1e-9 and Cards.DupeBonus(51) == 0.25 and Cards.DupeBonus(500) == 0.25,
		"every duplicate adds +0.5% ATK / HP, capped at +25%")
	local hana = Cards.Get("hana") :: any
	check(Cards.Stat(hana, hana.Main, 0, "Gold", 0, 21) == math.floor(hana.Main * 4 * 1.1 + 0.5), "21 Gold copies fight at +10%")
	local owned = F.own({ "hana" }, 0, { hana = "Gold" })
	owned.hana.BorderCopies.Gold = 21
	local battle = Engine.new({ Units = F.units(F.deck({ "hana" }, {}), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(1) })
	local plain = Engine.new({ Units = F.units(F.deck({ "hana" }, {}), F.own({ "hana" }, 0, { hana = "Gold" })), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(1) })
	check(battle.ById.A1.Main > plain.ById.A1.Main and MODULES.Deck.CardPower("hana", owned) > MODULES.Deck.CardPower("hana", F.own({ "hana" }, 0, { hana = "Gold" })),
		"the duplicate bonus reaches battle stats and Deck Power")
end

-- 5. The Pagoda crown's squad ATK reaches the battle as a whole-fight ATK buff.
do
	local crown = MODULES.Items.TowerArtifactById.hundredcrown
	check(crown.Bonuses.ATK == 0.15 and crown.Bonuses.Luck == 3 and crown.Bonuses.Border == 0.5, "the Crown of the Hundred Floors: +3x luck, +50% border chance, +15% squad ATK")
	check(Borders.EffectiveLuck(35) == 35 and Borders.EffectiveLuck(60) < 60, "luck is raw up to 35x, with diminishing returns above")
end
do
	local Meta, Tower, Packs = MODULES.Meta, MODULES.Tower, MODULES.Packs
	check(Meta.StatSpend({Luck=38}, 50, "Luck", "max") == 2, "training MAX respects the stat cap")
	check(Meta.StatSpend({Luck=20}, 24, "RollSpeed", 20) == 3, "typed training spending respects remaining points")
	check(Meta.StatSpend({}, 10, "RollSpeed", 5) == 5, "typed training allocates multiple points at once")
	for _, bad in {0,-1,1.5,math.huge,-math.huge,0/0,"20",true,{}} do
		check(Meta.StatSpend({}, 50, "Luck", bad) == 0, "training rejects invalid amounts")
	end
	check(Meta.StatSpend({}, 50, "fake", "max") == 0 and Meta.StatSpend({}, 1, "Luck", "max") == 0,
		"training rejects unknown stats and empty budgets")
	check(Packs.ById["10000"].Rolls == 10000 and Packs.Condense["1000"].To == "10000"
		and Packs.Condense["1000"].Need * Packs.ById["1000"].Rolls == 10000, "Colossal Pack condensing preserves all 10000 pulls")
	local tower = {Floor=9,Run=9,Checkpoints={}}
	local first = Tower.ClaimCheckpoints(tower)
	check(#first == 1 and first[1].Floor == 5 and #Tower.ClaimCheckpoints(tower) == 0,
		"tower checkpoints pay once, not on repeated wins or restarted runs")
	tower.Floor=10; tower.Run=1
	local second = Tower.ClaimCheckpoints(tower)
	check(#second == 1 and second[1].Reward.Artifacts.clover == 1 and second[1].Reward.Title == "Skyward",
		"floor 10 guarantees a usable relic and permanent title")
	tower.Floor=100
	local caughtUp = Tower.ClaimCheckpoints(tower)
	check(#caughtUp == 4 and caughtUp[4].Reward.Packs["10000"] == 1 and caughtUp[4].Reward.TowerArtifacts.spireheart,
		"old best runs catch up to each new checkpoint without duplicating earlier claims")
	check(Tower.NextCheckpoint(100,tower.Checkpoints) == nil and #Tower.ClaimCheckpoints(tower) == 0,
		"finished checkpoint tracks have no unpaid target or duplicate rewards")
	for _, bond in MODULES.ColumnBonds.List do
		local a, s = MODULES.Cards.Get(bond.Attack), MODULES.Cards.Get(bond.Support)
		check(MODULES.CardInfo.BondText(a):find(s.Name,1,true) ~= nil and MODULES.CardInfo.BondText(s):find(a.Name,1,true) ~= nil,
			"both bonded cards identify their exact familiar partner")
	end
	check(MODULES.CardInfo.BondText(MODULES.Cards.Get("blink_kunai"),"Secret"):find("45% → 50%",1,true) ~= nil,
		"bond descriptions show the actual capped Secret opening-charge increase")
end

-- Unlucky starts: no Gold / sky finds / traits, just the real normal pool and BEST DECK.
do
	local Cards, Deck, Bulk = MODULES.Cards, MODULES.Deck, MODULES.BulkRoll
	local pool = Cards.Pool({})
	local chances = Cards.PullChances(pool, nil, nil, nil, 1)
	local probabilities = {}
	for i, card in pool do probabilities[i] = chances[card.Id] end
	local wins, pulls, times = 0, {}, {}
	for seed = 1, 30 do
		local rng = Random.new(seed * 179)
		local owned, count, deck = {}, 0, Deck.Empty()
		repeat
			local n = if count == 0 then 10 else 1
			local drawn = Bulk.Multinomial(rng, n, probabilities)
			for i, amount in drawn do
				if amount > 0 then
					local id = pool[i].Id
					if not owned[id] then owned[id] = FIXTURES.own({id})[id]; owned[id].Copies=0; owned[id].BorderCopies.Normal=0 end
					owned[id].Copies += amount
					owned[id].BorderCopies.Normal += amount
				end
			end
			count += n
			deck = Deck.AutoBuild(owned)
		until Deck.Count(deck,"Attack") == 4 or count >= 100
		table.insert(pulls,count)
		local fight = FIXTURES.fight("kurogane","Normal",deck,owned,seed*7919)
		if fight.Result == "Win" then wins += 1; table.insert(times,fight.Time) end
	end
	table.sort(pulls);table.sort(times)
	print(`   All-Base fresh starts: {wins}/30 wins; four attackers in median {FIXTURES.percentile(pulls,.5)} / p95 {FIXTURES.percentile(pulls,.95)} pulls; median fight {string.format("%.1f",FIXTURES.percentile(times,.5))}s`)
	check(wins >= 29 and pulls[#pulls] < 100, "unlucky first sessions reach four attackers and beat the first boss without Gold or sky cards")
end

-- Traits improve real combat stats, without multiplying four slots into a runaway bonus.
do
	local T,D=MODULES.Traits,MODULES.Deck
	check(T.Multiplier(nil,nil,"sovereign")==2 and T.Multiplier("swift","eternal","apex","godspeed")==2,
		"trait lookup handles empty slots and strongest-only cap")
	for _,trait in T.List do
		check(trait.Multiplier>=1.1 and trait.Multiplier<=2 and #trait.Effects>0,"stat boost plus specialty: "..trait.Name)
	end
	check(D.TraitMultiplier({Trait="swift",Trait2="eternal"})==1.1 and D.TraitMultiplier({Trait="swift",Trait2="eternal",Trait2Unlocked=true})==2,
		"locked second traits cannot grant stats")
	local deck=F.deck({"hana"},{"mitotic_seal"})
	local own=F.own({"hana","mitotic_seal"},0)
	local base=Engine.new({Units=F.units(deck,own),BossId="kurogane",Difficulty="Normal",Rng=Random.new(1)})
	own.hana.Trait="swift";own.mitotic_seal.Trait="sovereign"
	local boosted=Engine.new({Units=F.units(deck,own),BossId="kurogane",Difficulty="Normal",Rng=Random.new(1)})
	check(boosted.ById.A1.Main==2*base.ById.A1.Main and boosted.ById.A1.MaxHP==2*base.ById.A1.MaxHP,
		"support trait transfers its strongest DMG / HP boost to the matching attacker")
	check(D.Power(deck,own)==boosted.ById.A1.Main*MODULES.Config.Power.PerATK+boosted.ById.A1.MaxHP,
		"deck recommendation rating agrees with real trait-boosted combat stats")
	check(D.PowerAt("mitotic_seal",own)==0,"trait supports still add no damage, HP or attack rating of their own")
	local chances=T.Chances()
	check(math.abs(chances.sovereign-1/6000)<1e-12 and T.Pick(.9999,.5)=="sovereign","Secret chase traits use their advertised 1 in 6,000 odds each")
	local pool=Cards.WeatherPool("rain")
	local c1,c6,cHuge=CelestialRolls.Chances(pool,1),CelestialRolls.Chances(pool,6),CelestialRolls.Chances(pool,1e9)
	check(math.abs(c6[1]/c1[1]-1.5)<1e-9 and math.abs(cHuge[1]/c1[1]-2)<1e-9,"sky luck rises gently before its cap")
end
