-- Real server results and the corresponding player-facing values must agree.
local Cards, Info, Engine = MODULES.Cards, MODULES.CardInfo, MODULES.BattleEngine
local F = FIXTURES
local hana, suzu, goro = Cards.Get("hana"), Cards.Get("suzu"), Cards.Get("goro")
check(Info.Headline(hana, 0, "Normal") == "HEAL 300" and Info.Headline(hana, 0, "Gold") == "HEAL 1,200", "support headline shows healing, not combat power")
check(Info.CopyBonus(5) == "Copy bonus +25%", "duplicate progression has a plain percentage label")
check(Info.Describe(hana, Cards.Ability(hana, "Basic"), 0, "Gold"):find("1,200 HP", 1, true) ~= nil, "Gold support skill description resolves its actual healing amount")

for _, border in { "Normal", "Gold", "Rainbow", "Secret" } do
	local owned = F.own({ "rook", "hana", "suzu", "goro" }, 0, { hana = border, suzu = border, goro = border })
	local engine = Engine.new({ Units = F.units(F.deck({ "rook" }, { "hana", "suzu", "goro" }), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
	local attacker, medic, booster, ward = engine.ById.A1, engine.ById.S1, engine.ById.S2, engine.ById.S3
	attacker.HP = 1
	local heal = Cards.Ability(hana, "Basic").Effects[1]
	engine:RunEffect(medic, heal, false, "healing check")
	check(attacker.HP == math.min(attacker.MaxHP, 1 + Cards.Stat(hana, hana.Main, 0, border)), border .. " heal uses border stats and cannot exceed maximum HP")
	local shield = Cards.Ability(goro, "Basic").Effects[2]
	engine:RunEffect(ward, shield, false, "shield check")
	check(attacker.Shield == Cards.Stat(goro, goro.Main, 0, border), border .. " shield uses the same amount displayed by card facts")
	local boost = Cards.Ability(suzu, "Basic").Effects[1]
	engine:RunEffect(booster, boost, false, "boost check")
	check(near(attacker.Buffs["S2:boost check:ATK"].Amount, 0.08 * Cards.SupportBoost(suzu, border)), border .. " support percentage boost is applied by the server")
	check(near(attacker.Buffs["Link:S1"].Amount, Cards.LinkAmount(hana, border)), border .. " paired-slot bonus scales with the support border")
	check(not medic.HasHP and medic.Alive, border .. " support has no health / knockout state")
end
local foreign = { Kind = "Buff", Stat = "ATK", Amount = 0.1 }
check(Cards.EffectAmount(suzu, foreign, "Secret") == 0.1, "a shared synergy does not inherit a support card's border boost")
do
	local ibuki = Cards.Get("ibuki")
	local owned = F.own({ "rook", "ibuki" }, 0, { ibuki = "Gold" })
	local battle = Engine.new({ Units = F.units(F.deck({ "rook" }, { "ibuki" }), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(4) })
	local debuff = Cards.Ability(ibuki, "Basic").Effects[2]
	battle:RunEffect(battle.ById.S1, debuff, false, "debuff check")
	local found = false
	for _, enemy in battle.Enemies do
		local active = enemy.Debuffs["S1:debuff check:ATK"]
		found = found or (active ~= nil and near(active.Amount, 0.125))
	end
	check(found, "the server applies the stronger Gold support debuff")
	local rook = Cards.Get("rook")
	check(Cards.SupportBoost(rook, "Secret") == 1, "Attack percentage skills do not inherit Support border scaling")
end
for _, card in Cards.List do
	for _, ability in card.Abilities do
		local text = Info.Describe(card, ability, 5, "Secret", 3)
		check(#text > 0 and not text:find("PWR", 1, true), card.Id .. " " .. ability.Slot .. " has concrete player-facing skill text")
	end
end
