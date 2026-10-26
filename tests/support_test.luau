-- Authored abilities must describe real triggers, costs, statuses and shared rounded values.
local Cards, Info, Engine, Config = MODULES.Cards, MODULES.CardInfo, MODULES.BattleEngine, MODULES.Config
local F = FIXTURES
local function setup(id, border, stars)
	local owned = F.own({ "rook", "tomo", id }, stars or 0, { [id] = border or "Normal" })
	return Engine.new({ Units = F.units(F.deck({ "rook", "tomo" }, { id }), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
end
local function attacker(id)
	return Engine.new({ Units = F.units(F.deck({ id }, {}), F.allOwned(0)), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
end
local banned = { "Fights and takes enemy hits", "Paired attacker only:", "matching Attack slot only", "Automatic on its action", "triggers per battle", "once per cast", "next hit can defeat", "Give this card", "turn(s)", "base damage" }
for _, card in Cards.List do
	for _, ability in card.Abilities do
		local strength = 0
		if ability.Trigger or (card.Support and card.Support.Trigger) then strength += 1 end
		local cost, status = false, ability.Chance ~= nil
		for _, effect in ability.Effects do
			cost = cost or (effect.Kind == "Buff" and effect.Amount < 0) or effect.Kind == "HealingLock"
			status = status or table.find({ "Burn", "Bleed", "Debuff", "Cleanse", "Evade" }, effect.Kind) ~= nil
		end
		if card.Support then
			cost = (card.Support.Penalty or 0) > 0 or card.Support.Kind == "LowHeal"
			status = card.Support.Chance ~= nil or card.Support.Kind == "Dodge" or card.Support.Kind == "Cleanse"
		end
		if cost then strength += 1 end
		if status then strength += 1 end
		if ability.Slot == "Passive" or ability.Slot == "Aura" or ability.Slot == "Signature" then
			check(strength >= 2, card.Id .. " " .. ability.Name .. " combines a trigger with a cost or status / RNG mechanic")
		end
		local allCopyClean = true
		for _, border in { "Normal", "Gold", "Rainbow", "Secret" } do
			for stars = 0, 5 do
				local text = Info.Describe(card, ability, stars, border, 3)
				local valid = #text > 10 and not text:find("{", 1, true) and not text:find("%d+%.%d+%%")
				for _, phrase in banned do valid = valid and not text:find(phrase, 1, true) end
				for value in text:gmatch("(%d+)%%") do valid = valid and tonumber(value) % 5 == 0 end
				allCopyClean = allCopyClean and valid
			end
		end
		check(allCopyClean, card.Id .. " " .. ability.Name .. ": all borders / copies resolve to clean RPG copy")
	end
	if card.Type == "Support" then
		local b = setup(card.Id)
		local s = b.ById.S1
		b:Opening(); b:CardAct(s)
		check(card.Main == 0 and card.HP == nil and card.SPD == 0 and s.Dealt == 0 and s.Actions == 0 and not b:UseUltimate("S1"), card.Id .. " remains passive equipment without its own damage, HP or turns")
		check(s.Paired == b.ById.A1 and #b.ById.A2.SupportMods == 0, card.Id .. " modifies only the supported card")
	end
end
for _, border in { "Normal", "Gold", "Rainbow", "Secret" } do
	local b = setup("hana", border)
	local a, mod = b.ById.A1, b.ById.S1.Modifier
	a.HP = math.floor(a.MaxHP * 0.5)
	a.Frozen = true
	a.Burns = { { Damage = 1, Ticks = 2, Timer = 2 } }
	local before = a.HP - 1
	b:DamageAlly(a, 1, "Hit", "Boss")
	check(a.HP == before + math.floor(a.MaxHP * mod.Amount + 0.5) and mod.Used == 1 and not a.Frozen and #a.Burns == 0 and a.HealingLock == 4, border .. " renewal cleanses, uses the rounded server percentage, and applies its healing cost")
	before = a.HP
	check(b:SupportHeal(mod, a, 100) == 0 and a.HP == before, border .. " healing lock really prevents healing")
	a.HP = 1
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(not a.Alive and mod.Used == 1, border .. " renewal is limited and cannot revive")
	local swift = setup("suzu", border)
	local base = attacker("rook")
	check(near(swift:Buff(swift.ById.A1, "SPD") - base:Buff(base.ById.A1, "SPD"), Cards.SupportValue(Cards.Get("suzu"), 0, border)) and near(swift.ById.A1.Buffs["Cost:S1"].Amount, -.1), border .. " thunder speed has its real DMG trade-off")
	check(Cards.SupportValue(Cards.Get("suzu"), 5, border, 3) * 100 % 5 < 1e-8, border .. " copies and Awakening keep actual passive strength in steps of 5%")
end
do
	local b = setup("aurelia")
	local a, support = b.ById.A1, b.ById.S1
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(a.Alive and a.HP == math.floor(a.MaxHP * .85 + .5) and a.Invuln == 0 and near(a.Buffs["Cost:S1"].Amount, -.25), "Crimson Chakra Cloak returns at 85% HP and costs 25% DMG")
	check(b:SupportHeal(support.Modifier, a, 100) == 0 and a.HealingLock == math.huge and b:Snapshot().U.A1.F:find("N"), "the cloak permanently prevents healing and exposes its status")
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(not a.Alive and support.Modifier.Used == 1 and b.ById.A2.Alive, "a second fatal hit defeats the supported card without reviving again")
	local report = b:Summary().Units.S1.Passive
	check(report.Used == 1 and report.Uses == 1, "results and limit badge share the consumed activation limit")
end
do
	local b = setup("amane")
	local a, enemy = b.ById.A1, b.Boss
	for i = 1, 3 do
		a.Frozen = true; a.Burns = { { Damage = 1, Ticks = 2, Timer = 2 } }; enemy.Frozen = false; enemy.Burns = {}
		b:SupportCleanse(a, enemy)
		check((not a.Frozen and #a.Burns == 0 and enemy.Frozen and #enemy.Burns == 1) == (i <= 2), `Puppet Reversal {i}: cleanses and reflects exactly two applications`)
	end
end
do
	local b = setup("amaya", "Secret", 5)
	b.Rng = { NextNumber = function() return 0 end }
	local a, enemy = b.ById.A1, b.Boss
	local cap = math.floor(a.MaxHP * .25 + .5)
	for _ = 1, 100 do a.HP = 1; enemy.HP, enemy.MaxHP = 1e9, 1e9; b:HitEnemy(a, enemy, 10, true) end
	check(b.ById.S1.Modifier.Healed == cap, "Stormheart Siphon cannot exceed its 25% HP effect cap")
	local c = setup("amaya"); c.Rng = { NextNumber = function() return .99 end }; c.ById.A1.HP = 1
	c:HitEnemy(c.ById.A1, c.Boss, 1)
	check(c.ById.A1.HP == 1 and c.ById.S1.Modifier.Healed == 0, "the siphon does nothing when its chance fails")
end
do
	local b = setup("yume"); b.Rng = { NextNumber = function() return 0 end }
	local a = b.ById.A1
	local ability = { Name = "multi hit", Effects = { { Kind = "Damage", Pct = .01, Hits = 3 } } }
	for _ = 1, 6 do b:RunAbility(a, ability, "Skill") end
	check(b.ById.S1.Modifier.Used == 4 and #b.ById.G3.Burns == 4, "Crows use one charge per cast and combine Weaken with four Black Flames Burns")
	local c = setup("yume"); c.Rng = { NextNumber = function() return .99 end }
	c:RunAbility(c.ById.A1, ability, "Skill")
	check(c.ById.S1.Modifier.Used == 0 and #c.ById.G3.Burns == 0, "failed Crows rolls do not apply either bundled effect")
end
do
	local b = setup("ibuki"); b.Rng = { NextNumber = function() return 0 end }
	local a = b.ById.A1
	for _ = 1, 10 do a.HP = a.MaxHP; b:HitAlly(b.Boss, a, { Pct = .01 }) end
	check(b.ById.S1.Modifier.Used == 4 and b:EnemyDebuff(b.Boss, "ATK") >= .1, "Cloud-Step evades four hits and applies Weaken")
	local snap = b:Snapshot()
	check(snap.U.S1.H == nil and snap.U.S1.G == 0 and snap.U.S1.NextIn == nil and snap.U.A1.NextIn ~= nil, "snapshots still distinguish passive equipment from attackers")
end
do
	local b = setup("goro"); b.Rng = { NextNumber = function() return 0 end }
	local before = b.Boss.HP
	for _ = 1, 10 do b.ById.A1.HP = b.ById.A1.MaxHP; b:DamageAlly(b.ById.A1, 100, "Hit", "Boss") end
	check(b.ById.S1.Modifier.Used == 4 and b.Boss.HP == before - 60 and b.ById.S1.Dealt == 0 and b.ById.A1.Dealt == 60, "counter damage belongs to the supported card and respects four activations")
end
do
	local b = setup("luna"); local a = b.ById.A1; a.HP = 1
	b:DamageEnemy(b.ById.G1, a, b.ById.G1.MaxHP, false, "Hit")
	check(a.HP > 1 and near(a.Buffs["Cost:S1"].Amount, -.1) and b.ById.S1.Modifier.Used == 1, "Wisteria Antidote triggers on a real defeat and pays its DMG cost")
end
do
	local b = attacker("akane"); b.Rng = { NextNumber = function() return 0 end }
	b:HitEnemy(b.ById.A1, b.Boss, .1)
	check(#b.Boss.Burns == 1 and b.Boss.Burns[1].Kind == "Bleed" and b:Snapshot().U.Boss.F:find("L"), "Cursed Incision inflicts distinct Bleed on a critical hit")
	local c = attacker("kaito"); c.ById.A1.HP = c.ById.A1.MaxHP*.4
	c:DamageAlly(c.ById.A1, 1, "Hit", "Boss")
	check(near(c:Buff(c.ById.A1, "ATK"), .25) and near(c:Buff(c.ById.A1, "Guard"), -.1) and c.ById.A1.Triggered[1].Used == 1, "Unbroken Pride awakens once below half HP with a real defensive cost")
	local d = attacker("tenrai_card"); local a = d.ById.A1; a.HP = a.MaxHP*.4; a.Frozen = true
	d:DamageAlly(a, 1, "Hit", "Boss")
	check(not a.Frozen and a.HP > a.MaxHP*.5 and a.HealingLock == math.huge, "Demon Rebirth cleanses and regenerates before permanently locking healing")
end
check(Info.Highlight("Deal 125% DMG for 3 turns. Burn enemy 2."):find('<b>3 turns</b>', 1, true) and not Info.Highlight("enemy 2"):find('<font', 1, true), "only percentages, turn counts and statuses are highlighted")
check(Info.Badges(Cards.Get("aurelia"), Cards.Get("aurelia").Abilities[1])[1] == "Activation Limit: 1", "activation limits are structured badge data, not paragraphs")
for _, index in { 1, 3, 7 } do
	local fx = F.FIGHTS[index]; local deck, owned = F.fixtureDeck(fx); deck.Support = { "", "", "", "" }
	local rate, times = F.campaign(fx.Boss, fx.Difficulty, deck, owned, 20)
	check(rate >= .9 and F.percentile(times, .5) <= 100, `{fx.Boss} {fx.Difficulty}: attackers remain viable without healing Support`)
end

-- Multi-hit techniques roll hit passives for the actual victim of each hit.
do
	local b = attacker("noa"); b.Rng = { NextNumber = function() return 0 end }
	b:RunAbility(b.ById.A1, { Name = "Three hits", Effects = { { Kind = "Damage", Pct = .05, Hits = 3 } } }, "Skill")
	check(b.ById.A1.Triggered[1].Used == 3, "an on-hit passive rolls on every hit, not once per multi-hit technique")
end
-- Posthumous damage may win a fight, but it must not heal a defeated card.
do
	local b = setup("luna"); local a = b.ById.A1; a.HP = 0; a.Alive = false
	b:DamageEnemy(b.ById.G1, a, b.ById.G1.MaxHP, false, "Burn")
	check(a.HP == 0 and b.ById.S1.Modifier.Used == 0, "a defeated supported card cannot consume a kill-heal activation")
end
-- Freeze reflection costs the enemy its next action, not merely a tooltip label.
do
	local b = setup("amane"); local enemy = b.Boss
	b.ById.A1.Frozen = true; b:SupportCleanse(b.ById.A1, enemy)
	enemy.Gauge = 2
	local count = enemy.Actions
	b:Step(Config.Battle.Tick)
	check(not enemy.Frozen and enemy.Actions == count, "reflected Freeze actually skips the enemy's next action")
end

-- A cleanse triggered by the first burn tick also cancels the other due burns that frame.
do
	local b = setup("hana"); local a = b.ById.A1
	a.HP = math.floor(a.MaxHP*.5)
	local before = a.HP
	for _ = 1, 3 do table.insert(a.Burns, { Damage = 10, Ticks = 1, Timer = 0, Source = "Boss" }) end
	b:Step(Config.Battle.Tick)
	check(a.HP == before - 10 + math.floor(a.MaxHP*b.ById.S1.Modifier.Amount+.5) and #a.Burns == 0, "reactive cleansing cancels remaining simultaneous Burn ticks")
end
