-- Authored abilities must describe real triggers, costs, statuses and shared rounded values.
local Cards, Info, Engine, Config = MODULES.Cards, MODULES.CardInfo, MODULES.BattleEngine, MODULES.Config
local F = FIXTURES

-- All characters fight; relics keep the old passive's separate identity and have no character art.
do
	local attacks, supports = 0, 0
	for _, card in Cards.List do
		if card.Type == "Attack" then attacks += 1 else supports += 1 end
	end
	check(attacks == 42 and supports == 11, "37 normal cards plus sixteen Celestial Attack cards")
	for characterId, relicId in Cards.LegacySupports do
		local card, relic = Cards.Get(characterId), Cards.Get(relicId)
		check(card.Type == "Attack" and card.Image ~= nil and card.Support == nil and relic.Type == "Support" and relic.Image ~= card.Image, characterId .. " keeps its portrait as an attacker; the relic never borrows that portrait")
		local b = Engine.new({ Units = {{ Id = "A1", CardId = characterId, Stars = 0, Border = "Normal" }}, BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5), Guards = {} })
		b.Boss.HP = 1e8; b.Boss.MaxHP = 1e8
		local a = b.ById.A1
		local casts = true
		for _, slot in { "Basic", "Skill", "Ultimate" } do
			local ability = Cards.Ability(card, slot)
			local before = a.Dealt
			if ability then b:RunAbility(a, ability, slot) end
			casts = casts and ability ~= nil and a.Dealt > before
		end
		check(casts and a.HasHP and a.SPD > 0, characterId .. " has real HP, speed and damaging Basic / Skill / Ultimate without Support")
	end
	local converted = { "hana", "suzu", "ibuki", "tetsu" }
	local gold = {}
	for _, id in converted do gold[id] = "Gold" end
	local rate, times = F.campaign("kurogane", "Normal", F.deck(converted, {}), F.own(converted, 0, gold), 20)
	print(string.format("   converted all-Gold Attack-only team: %d%% wins, %.1fs median", rate * 100, F.percentile(times, .5)))
	check(rate >= .9 and F.percentile(times, .5) <= 100, "converted characters can win a starter fight together without relic healing")
	local invalid = MODULES.Deck.Empty(); invalid.Support[1] = "hana"
	check(MODULES.Deck.Clean(invalid, F.allOwned(0)).Support[1] == "", "stale client Support slots cannot keep a converted Attack card")
end

do
	local owned = F.own({"mirai", "mitotic_seal"})
	local units = F.units(F.deck({"mirai"},{"mitotic_seal"}), owned)
	units[2].Trait = {{Stat="SPD",Amount=0.05},{Stat="StartEnergy",Amount=0.25}}
	local battle = MODULES.BattleEngine.new({Units=units,BossId="kurogane",Difficulty="Normal",Rng=Random.new(5)})
	check(battle.ById.A1.Buffs["SupportTrait:S1:1"] ~= nil, "Support speed trait reaches its matching attacker")
	check(battle.ById.A1.Energy >= 25 and battle.ById.S1.HP == 0, "Support starting-charge trait charges the attacker without giving Support HP")
	check(MODULES.Cards.SupportValue(MODULES.Cards.Get("mitotic_seal"),0,"Normal",0) == MODULES.Cards.SupportValue(MODULES.Cards.Get("mitotic_seal"),5,"Normal",4), "duplicate counts never strengthen a passive")
end
local function setup(id, border, stars)
	local owned = F.own({ "rook", "tomo", id }, stars or 0, { [id] = border or "Normal" })
	return Engine.new({ Units = F.units(F.deck({ "rook", "tomo" }, { id }), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
end
local function attacker(id)
	return Engine.new({ Units = F.units(F.deck({ id }, {}), F.allOwned(0)), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(17) })
end
do
	local blink = attacker("orin")
	check(blink.ById.A1.Energy == 0.25 * blink.ById.A1.UltCost and blink:Buff(blink.ById.A1, "Guard") == 0, "Time Weaver's entry charge is a real 25% of its Ultimate, with no vulnerability")
	local cloak = attacker("aurelia"); local a = cloak.ById.A1
	a.HP = math.floor(a.MaxHP * .4)
	cloak:DamageAlly(a, 1, "Hit", "Boss")
	local after = a.HP
	cloak:RunEffect(a, { Kind = "Heal", Pct = 1, Target = "Self" })
	check(a.HP > after and a.HealingLock == 0 and cloak:Buff(a, "ATK") == .2, "Nine-Tails Sovereign's own cloak heals once and grants DMG, without blocking later healing")
	local b = attacker("goro"); b.Rng = { NextNumber = function() return 0 end }
	b.Boss.HP = 1e8; b.Boss.MaxHP = 1e8
	for _ = 1, 8 do b:Trigger(b.ById.A1, "OnAct") end
	check(b.ById.A1.Triggered[1].Used == 4 and b.ById.A1.Dealt > 0, "Fist of Severance's follow-up actually strikes and stops at four activations")
end
local banned = { "Fights and takes enemy hits", "Paired attacker only:", "matching Attack slot only", "Automatic on its action", "triggers per battle", "once per cast", "next hit can defeat", "Give this card", "turn(s)", "base damage" }
-- 2026-10-30: passives lost their self-penalties. Each still needs a trigger plus a bound: a status / RNG
-- mechanic, an activation limit or a condition (below half HP, on a kill ...).
for _, card in Cards.List do
	for _, ability in card.Abilities do
		local trigger = ability.Trigger ~= nil or (card.Support ~= nil and card.Support.Trigger ~= nil)
		local penalty, bounded = false, ability.Chance ~= nil or ability.Limit ~= nil
		for _, effect in ability.Effects do
			penalty = penalty or (effect.Kind == "Buff" and effect.Amount < 0 and (effect.Target == nil or effect.Target == "Self")) or effect.Kind == "HealingLock"
			bounded = bounded or table.find({ "Burn", "Bleed", "Debuff", "Cleanse", "Evade" }, effect.Kind) ~= nil or effect.When ~= nil
		end
		bounded = bounded or table.find({ "BelowHalf", "OnKill", "OnCrit", "OnEntry" }, ability.Trigger or "") ~= nil
		if card.Support then
			penalty = card.Support.Kind ~= "Dodge" and (card.Support.Penalty or 0) > 0
			bounded = card.Support.Chance ~= nil or card.Support.Uses ~= nil or card.Support.Threshold ~= nil or card.Support.Kind == "Dodge"
		end
		if ability.Slot == "Passive" or ability.Slot == "Aura" or ability.Slot == "Signature" then
			check(trigger and bounded and not penalty, card.Id .. " " .. ability.Name .. " has a trigger and a bound, and no self-penalty")
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
	local b = setup("mitotic_seal", border)
	local a, mod = b.ById.A1, b.ById.S1.Modifier
	a.HP = math.floor(a.MaxHP * 0.5)
	a.Frozen = true
	a.Burns = { { Damage = 1, Ticks = 2, Timer = 2 } }
	local before = a.HP - 1
	b:DamageAlly(a, 1, "Hit", "Boss")
	check(a.HP == before + math.floor(a.MaxHP * mod.Amount + 0.5) and mod.Used == 1 and not a.Frozen and #a.Burns == 0 and a.HealingLock == 0, border .. " renewal cleanses and uses the rounded server percentage, with no healing lock")
	before = a.HP
	check(b:SupportHeal(mod, a, 100) == 100 and a.HP == before + 100, border .. " later healing still lands after the renewal")
	a.HP = 1
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(not a.Alive and mod.Used == 1, border .. " renewal is limited and cannot revive")
	local swift = setup("thunderclap_form", border)
	local base = attacker("rook")
	check(near(swift:Buff(swift.ById.A1, "SPD") - base:Buff(base.ById.A1, "SPD"), Cards.SupportValue(Cards.Get("thunderclap_form"), 0, border)) and swift.ById.A1.Buffs["Cost:S1"] == nil, border .. " thunder speed is real, with no DMG trade-off")
	check(Cards.SupportValue(Cards.Get("thunderclap_form"), 5, border, 3) * 100 % 5 < 1e-8, border .. " copies and Awakening keep actual passive strength in steps of 5%")
end
do
	local b = setup("beast_seal")
	local a, support = b.ById.A1, b.ById.S1
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(a.Alive and a.HP == math.floor(a.MaxHP * .55 + .5) and a.Invuln == 0 and a.Buffs["Cost:S1"] == nil, "Crimson Chakra Cloak returns at 55% HP (Base) with no DMG cost")
	local seal = Cards.Get("beast_seal") :: any
	check(Cards.SupportValue(seal, 0, "Gold") == .7 and Cards.SupportValue(seal, 0, "Rainbow") == .85 and Cards.SupportValue(seal, 0, "Secret") == 1, "the cloak returns at 70% / 85% / 100% on Gold / Rainbow / Secret")
	check(b:SupportHeal(support.Modifier, a, 100) == 100 and a.HealingLock == 0 and not b:Snapshot().U.A1.F:find("N"), "after the cloak the card can still be healed (no healing lock)")
	b:DamageAlly(a, a.MaxHP * 2, "Hit", "Boss")
	check(not a.Alive and support.Modifier.Used == 1 and b.ById.A2.Alive, "a second fatal hit defeats the supported card without reviving again")
	local report = b:Summary().Units.S1.Passive
	check(report.Used == 1 and report.Uses == 1, "results and limit badge share the consumed activation limit")
end
do
	local b = setup("puppet_threads")
	local a, enemy = b.ById.A1, b.Boss
	for i = 1, 3 do
		a.Frozen = true; a.Burns = { { Damage = 1, Ticks = 2, Timer = 2 } }; enemy.Frozen = false; enemy.Burns = {}
		b:SupportCleanse(a, enemy)
		check((not a.Frozen and #a.Burns == 0 and enemy.Frozen and #enemy.Burns == 1) == (i <= 2), `Puppet Reversal {i}: cleanses and reflects exactly two applications`)
	end
end
do
	local b = setup("storm_mantle", "Secret", 5)
	b.Rng = { NextNumber = function() return 0 end }
	local a, enemy = b.ById.A1, b.Boss
	local cap = math.floor(a.MaxHP * .25 + .5)
	for _ = 1, 100 do a.HP = 1; enemy.HP, enemy.MaxHP = 1e9, 1e9; b:HitEnemy(a, enemy, 10, true) end
	check(b.ById.S1.Modifier.Healed == cap, "Stormheart Siphon cannot exceed its 25% HP effect cap")
	local c = setup("storm_mantle"); c.Rng = { NextNumber = function() return .99 end }; c.ById.A1.HP = 1
	c:HitEnemy(c.ById.A1, c.Boss, 1)
	check(c.ById.A1.HP == 1 and c.ById.S1.Modifier.Healed == 0, "the siphon does nothing when its chance fails")
end
do
	local b = setup("ocular_seal"); b.Rng = { NextNumber = function() return 0 end }
	local a = b.ById.A1
	local ability = { Name = "multi hit", Effects = { { Kind = "Damage", Pct = .01, Hits = 3 } } }
	for _ = 1, 6 do b:RunAbility(a, ability, "Skill") end
	check(b.ById.S1.Modifier.Used == 4 and #b.ById.G3.Burns == 4, "Crows use one charge per cast and combine Weaken with four Black Flames Burns")
	local c = setup("ocular_seal"); c.Rng = { NextNumber = function() return .99 end }
	c:RunAbility(c.ById.A1, ability, "Skill")
	check(c.ById.S1.Modifier.Used == 0 and #c.ById.G3.Burns == 0, "failed Crows rolls do not apply either bundled effect")
end
do
	local b = setup("heavenly_pact"); b.Rng = { NextNumber = function() return 0 end }
	local a = b.ById.A1
	for _ = 1, 10 do a.HP = a.MaxHP; b:HitAlly(b.Boss, a, { Pct = .01 }) end
	check(b.ById.S1.Modifier.Used == 4 and b:EnemyDebuff(b.Boss, "ATK") >= .1, "Cloud-Step evades four hits and applies Weaken")
	local snap = b:Snapshot()
	check(snap.U.S1.H == nil and snap.U.S1.G == 0 and snap.U.S1.NextIn == nil and snap.U.A1.NextIn ~= nil, "snapshots still distinguish passive equipment from attackers")
end
do
	local b = setup("blood_vow"); b.Rng = { NextNumber = function() return 0 end }
	local before = b.Boss.HP
	for _ = 1, 10 do b.ById.A1.HP = b.ById.A1.MaxHP; b:DamageAlly(b.ById.A1, 100, "Hit", "Boss") end
	check(b.ById.S1.Modifier.Used == 4 and b.Boss.HP == before - 60 and b.ById.S1.Dealt == 0 and b.ById.A1.Dealt == 60, "counter damage belongs to the supported card and respects four activations")
end
do
	local b = setup("wisteria_vial"); local a = b.ById.A1; a.HP = 1
	b:DamageEnemy(b.ById.G1, a, b.ById.G1.MaxHP, false, "Hit")
	check(a.HP > 1 and a.Buffs["Cost:S1"] == nil and b.ById.S1.Modifier.Used == 1, "Wisteria Antidote triggers on a real defeat, with no DMG cost")
end
do
	local b = attacker("akane"); b.Rng = { NextNumber = function() return 0 end }
	b:HitEnemy(b.ById.A1, b.Boss, .1)
	check(#b.Boss.Burns == 1 and b.Boss.Burns[1].Kind == "Bleed" and b:Snapshot().U.Boss.F:find("L"), "Cursed Incision inflicts distinct Bleed on a critical hit")
	local c = attacker("kaito"); c.ById.A1.HP = c.ById.A1.MaxHP*.4
	c:DamageAlly(c.ById.A1, 1, "Hit", "Boss")
	check(near(c:Buff(c.ById.A1, "ATK"), .25) and near(c:Buff(c.ById.A1, "Guard"), 0) and c.ById.A1.Triggered[1].Used == 1, "Unbroken Pride awakens once below half HP, with no defensive cost")
	local d = attacker("tenrai_card"); local a = d.ById.A1; a.HP = a.MaxHP*.4; a.Frozen = true
	d:DamageAlly(a, 1, "Hit", "Boss")
	check(not a.Frozen and a.HP > a.MaxHP*.5 and a.HealingLock == 0, "Demon Rebirth cleanses and regenerates, without locking healing")
end
check(Info.Highlight("Deal 125% DMG for 3 turns. Burn enemy 2."):find('<b>3 turns</b>', 1, true) and not Info.Highlight("enemy 2"):find('<font', 1, true), "only percentages, turn counts and statuses are highlighted")
check(Info.Badges(Cards.Get("beast_seal"), Cards.Get("beast_seal").Abilities[1])[1] == "Activation Limit: 1", "activation limits are structured badge data, not paragraphs")
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
	local b = setup("wisteria_vial"); local a = b.ById.A1; a.HP = 0; a.Alive = false
	b:DamageEnemy(b.ById.G1, a, b.ById.G1.MaxHP, false, "Burn")
	check(a.HP == 0 and b.ById.S1.Modifier.Used == 0, "a defeated supported card cannot consume a kill-heal activation")
end
-- Freeze reflection costs the enemy its next action, not merely a tooltip label.
do
	local b = setup("puppet_threads"); local enemy = b.Boss
	b.ById.A1.Frozen = true; b:SupportCleanse(b.ById.A1, enemy)
	enemy.Gauge = 2
	local count = enemy.Actions
	b:Step(Config.Battle.Tick)
	check(not enemy.Frozen and enemy.Actions == count, "reflected Freeze actually skips the enemy's next action")
end

-- A cleanse triggered by the first burn tick also cancels the other due burns that frame.
do
	local b = setup("mitotic_seal"); local a = b.ById.A1
	a.HP = math.floor(a.MaxHP*.5)
	local before = a.HP
	for _ = 1, 3 do table.insert(a.Burns, { Damage = 10, Ticks = 1, Timer = 0, Source = "Boss" }) end
	b:Step(Config.Battle.Tick)
	check(a.HP == before - 10 + math.floor(a.MaxHP*b.ById.S1.Modifier.Amount+.5) and #a.Burns == 0, "reactive cleansing cancels remaining simultaneous Burn ticks")
end
