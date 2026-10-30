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
	for id, n in { celestial_rain_broly = 300, celestial_rain_goku = 650, celestial_blizzard_yhwach = 1250, celestial_thunder_gojo = 1000, celestial_eclipse_akaza = 1200, celestial_eclipse_kokushibo = 2000, celestial_eclipse_muzan = 2500 } do
		sky = sky and (Cards.Get(id) :: any).SkyOneIn == n
	end
	check(sky and Cards.Rarity("celestial_eclipse_kokushibo", "Secret") == 1000000000, "sky cards: Limitbreak 1 in 300-650 ... Blood Moon 1,200-2,500 (Kokushibo Secret 1 in 1 billion)")
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
	check(math.abs(c40[1] / c1[1] - (1 + 39 * 0.35)) < 1e-9, "40x luck finds a sky card 14.65x as often")
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
