-- Supports are paired passive equipment: no health, damage, active turns or infinite healing.
local Cards, Info, Engine, Config = MODULES.Cards, MODULES.CardInfo, MODULES.BattleEngine, MODULES.Config
local F = FIXTURES
local function setup(id, border, stars)
	local owned = F.own({ "rook", "tomo", id }, stars or 0, { [id] = border or "Normal" })
	return Engine.new({ Units = F.units(F.deck({ "rook", "tomo" }, { id }), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
end
for _, card in Cards.List do
	if card.Type == "Support" then
		check(card.Main == 0 and card.HP == nil and card.SPD == 0 and card.Support ~= nil, card.Id .. " has a passive, no damage / HP / action speed")
		check(#card.Abilities == 1 and card.Abilities[1].Slot == "Passive" and Cards.Power(card, 5, "Secret", 4) == 0, card.Id .. " cannot contribute fake combat power or active skills")
		local b = setup(card.Id)
		local s = b.ById.S1
		check(s.Paired == b.ById.A1 and #b.ById.A2.SupportMods == 0, card.Id .. " helps only its matching attacker")
		b:Opening()
		b:CardAct(s)
		check(s.Actions == 0 and s.Dealt == 0 and not b:UseUltimate("S1") and b:Speed(s) == 0, card.Id .. " never acts or deals damage")
		for _, border in { "Normal", "Gold", "Rainbow", "Secret" } do
			check(#Info.Describe(card, card.Abilities[1], 5, border, 3) > 30, card.Id .. " " .. border .. " explains its actual passive and limits")
		end
	end
end
for _, border in { "Normal", "Gold", "Rainbow", "Secret" } do
	local b = setup("hana", border)
	local a, mod = b.ById.A1, b.ById.S1.Modifier
	a.HP = math.floor(a.MaxHP * 0.4)
	local before = a.HP - 1
	b:DamageAlly(a, 1, "Hit", "Boss")
	check(a.HP == before + math.floor(a.MaxHP * mod.Amount + 0.5) and mod.Used == 1, border .. " emergency heal uses the displayed percentage of paired max HP")
	a.HP = math.floor(a.MaxHP * 0.2)
	before = a.HP
	b:DamageAlly(a, 1, "Hit", "Boss")
	check(a.HP == before - 1 and mod.Used == 1, border .. " emergency heal cannot repeat")
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(not a.Alive, border .. " emergency heal cannot revive or stop a fatal hit")
	local shielded = setup("tetsu", border)
	local shield = shielded.ById.A1.Shield
	shielded:DamageAlly(shielded.ById.A1, shield + 1, "Hit", "Boss")
	shielded:Opening()
	check(shielded.ById.A1.Shield == 0 and shielded.ById.A2.Shield == 0, border .. " opening shield is paired and never refreshes")
	local boosted = setup("suzu", border)
	check(near(boosted:Buff(boosted.ById.A1, "SPD"), Cards.SupportValue(Cards.Get("suzu"), 0, border)), border .. " paired speed equals the shared description formula")
end
do
	local b = setup("aurelia")
	local a = b.ById.A1
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(a.Alive and a.HP == 1 and a.Invuln == 0, "last stand survives one hit at 1 HP, without team invulnerability")
	b:DamageAlly(a, 1, "Hit", "Boss")
	check(not a.Alive and b.ById.A2.Alive, "second fatal hit defeats that attacker; teammates are unaffected")
	local summary = b:Summary().Units.S1
	check(summary.Dealt == 0 and summary.Passive.Attached and summary.Passive.Used == 1 and summary.Passive.Uses == 1, "results report a consumed passive trigger instead of damage or fake healing")
end
do
	local b = setup("amane")
	local a = b.ById.A1
	for i = 1, 3 do
		a.Frozen = true
		a.Burns = { { Damage = 1, Ticks = 2, Timer = 2 } }
		b:SupportCleanse(a)
		check((not a.Frozen and #a.Burns == 0) == (i <= 2), `cleanse application {i}: only two charges per battle`)
	end
end
do
	local b = setup("amaya", "Secret", 5)
	local a, enemy = b.ById.A1, b.Boss
	local cap = math.floor(a.MaxHP * 0.2 + 0.5)
	for _ = 1, 30 do
		a.HP = 1
		enemy.HP, enemy.MaxHP = 1e9, 1e9
		b:HitEnemy(a, enemy, 10, true)
	end
	check(b.ById.S1.Modifier.Healed == cap, "lifesteal total is capped at 20% of paired max HP for the whole battle")
	b = setup("amaya")
	a, enemy = b.ById.A1, b.Boss
	a.HP, enemy.HP = 1, 1
	b:HitEnemy(a, enemy, 1000, true)
	check(a.HP == 1, "lifesteal ignores overkill damage")
end
do
	local b = setup("yume")
	local a = b.ById.A1
	local ability = { Name = "Test multi hit", Effects = { { Kind = "Damage", Pct = 0.01, Hits = 3 } } }
	for _ = 1, 6 do b:RunAbility(a, ability, "Skill") end
	check(b.ById.S1.Modifier.Used == 4, "weakening uses one charge per cast, capped at four casts")
end
do
	local b = setup("ibuki")
	local a = b.ById.A1
	local misses = 0
	for _ = 1, 1000 do
		a.HP = a.MaxHP
		b:HitAlly(b.Boss, a, { Pct = 0.01 })
		for _, e in b:TakeEvents() do if e.K == "Miss" then misses += 1 end end
	end
	check(misses > 30 and misses < 100, `base dodge is a small chance, not invulnerability ({misses}/1000)`)
	local before = b:Snapshot().U.A1.NextIn
	b:Step(Config.Battle.Tick)
	local snap = b:Snapshot()
	check(snap.U.S1.H == nil and snap.U.S1.G == 0 and snap.U.S1.NextIn == nil and snap.U.A1.NextIn < before, "server snapshots distinguish passive supports from the attacker countdown")
end
local hana = Cards.Get("hana")
check(Cards.SupportValue(hana, 5, "Gold") > Cards.SupportValue(hana, 0, "Gold") and Cards.SupportValue(hana, 0, "Gold") > Cards.SupportValue(hana, 0, "Normal"), "border and copy bonus strengthen passives without increasing trigger counts")
check(Info.CopyBonus(5) == "Copy bonus +25%" and not Info.Headline(hana, 0, "Gold"):find("DMG", 1, true), "support facts show real effects and explain the retained copy bonus")
for _, card in Cards.List do
	for _, ability in card.Abilities do
		check(#Info.Describe(card, ability, 5, "Secret", 3) > 0, card.Id .. " " .. ability.Slot .. " has readable skill text")
	end
end

-- The core attackers remain playable without a healer / passive row.
for _, index in { 1, 3, 7 } do
	local fx = F.FIGHTS[index]
	local deck, owned = F.fixtureDeck(fx)
	deck.Support = { "", "", "", "" }
	local rate, times = F.campaign(fx.Boss, fx.Difficulty, deck, owned, 20)
	check(rate >= 0.9 and F.percentile(times, 0.5) <= 100, `{fx.Boss} {fx.Difficulty}: Attack row wins without Support healing`)
end
