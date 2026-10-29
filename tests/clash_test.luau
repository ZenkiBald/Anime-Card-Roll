-- The real-time battle pass (2026-10-30): archetype timers, the Boss Shield, Boss Clash, Vanguard, guard
-- links, HOLD ULT FOR BREAK, and passives without self-penalties.
local Config = MODULES.Config
local Cards = MODULES.Cards
local Engine = MODULES.BattleEngine
local F = FIXTURES
local B = Config.Battle

local function engine(attack, owned, seed, boss, difficulty)
	return Engine.new({ Units = F.units(F.deck(attack, {}), owned), BossId = boss or "kurogane", Difficulty = difficulty or "Normal", Rng = Random.new(seed or 1) })
end

-- 1. Archetypes: every Attack card's timers and per-cast damage sit in its band, per hit in 5% steps.
do
	local ok, steps = true, true
	for _, card in Cards.List do
		if card.Type == "Attack" then
			local arch = B.Archetypes[card.Archetype]
			ok = ok and arch ~= nil and card.Archetype == Cards.Archetype(card)
			ok = ok and card.BasicInterval >= math.min(arch.Interval[1], arch.Interval[2]) - 1e-9 and card.BasicInterval <= math.max(arch.Interval[1], arch.Interval[2]) + 1e-9
			ok = ok and card.SkillCooldown >= math.min(arch.Cooldown[1], arch.Cooldown[2]) - 1e-9 and card.SkillCooldown <= math.max(arch.Cooldown[1], arch.Cooldown[2]) + 1e-9
			ok = ok and card.UltimateCost == arch.UltCost
			for _, slot in { "Basic", "Skill", "Ultimate" } do
				local ability = Cards.Ability(card, slot)
				local band = arch[if slot == "Ultimate" then "Ult" else slot]
				local total = 0
				for _, e in (if ability then ability.Effects else {}) :: { any } do
					if e.Kind == "Damage" then
						total += e.Pct * (e.Hits or 1)
						steps = steps and math.abs(e.Pct * 20 - math.floor(e.Pct * 20 + 0.5)) < 1e-6
					end
				end
				if total > 0 then
					local fits = total >= band[1] - 0.05 - 1e-9 and total <= band[2] + 0.05 + 1e-9
					if not fits then print(`   {card.Id} {slot} {total} outside {band[1]}-{band[2]}`) end
					ok = ok and fits
				end
			end
		end
	end
	check(ok, "every Attack card's Basic / Skill / Ultimate timers and damage sit in its Fast / Balanced / Heavy band")
	check(steps, "every per-hit damage % is a multiple of 5")
	check(Cards.Archetype(Cards.Get("orin") :: any) == "Fast" and Cards.Archetype(Cards.Get("hana") :: any) == "Balanced" and Cards.Archetype(Cards.Get("rook") :: any) == "Heavy",
		"SPD picks the archetype: 120+ Fast, 105-119 Balanced, up to 104 Heavy")
end

-- 2. Real time: a card's Basics follow its interval, its Skill its cooldown, its Ultimate its energy.
do
	local owned = F.own({ "orin" })
	local b = engine({ "orin" }, owned, 4)
	b.ById.A1.MaxHP, b.ById.A1.HP = 1e12, 1e12 -- survive the whole sample
	local basics, skills = 0, 0
	while b.Time < 30 - 1e-6 and not b.Over do
		b:Step(B.Tick)
		for _, e in b:TakeEvents() do
			if e.K == "Act" and e.U == "A1" then
				if e.Ab == "Basic" then basics += 1 elseif e.Ab == "Skill" then skills += 1 end
			end
		end
	end
	local card = Cards.Get("orin") :: any
	local expectSkills = math.floor(30 / card.SkillCooldown)
	check(skills == expectSkills, `a Fast card's Skill fires every {card.SkillCooldown} s ({skills} in 30 s)`)
	check(math.abs(basics - (30 - skills * 0.1) / card.BasicInterval) <= skills + 2, `a Fast card's Basic fires every {card.BasicInterval} s ({basics} in 30 s)`)
	check(b.ById.A1.Energy >= b.ById.A1.UltCost - 1e-6, "with AUTO ULT off, the Ultimate charges to full in real time and waits for a tap")
	check(math.abs(b.ById.A1.UltCost / B.EnergyPerSecond - 14.8) < 0.1, "a Fast card's 80-energy Ultimate charges in about 15 s")
end

-- 3. Boss Shield: 0.5x while it stands, 1.5x when broken; Basics chip it, Heavy Skills chunk it.
do
	local owned = F.own({ "rook" })
	local function hitBoss(staggered)
		local b = engine({ "rook" }, owned, 9)
		for _, g in b.Enemies do if not g.Leader then g.Alive = false end end
		b.Boss.Staggered = staggered
		b.Slot = "Clash" -- no Shield fill; just the multiplier
		b:HitEnemy(b.ById.A1, b.Boss, 1, false)
		for _, e in b:TakeEvents() do
			if e.K == "Hit" and e.T == "Boss" then return e end
		end
		return nil
	end
	local up, broken = hitBoss(0), hitBoss(3)
	check(up and broken and up.Sd and broken.Bk and math.abs(broken.A / up.A - B.BrokenTaken / B.ShieldTaken) < 0.01,
		"the leader takes 0.5x while its Shield stands (muted) and 1.5x when it's broken (gold)")

	local b = engine({ "rook" }, owned, 9)
	local warderUp = b.Boss
	b.Slot = "Basic"
	b:HitEnemy(b.ById.A1, warderUp, 1, false)
	local withWarder = b.Boss.Stagger
	for _, g in b.Enemies do if g.Role == "Warder" then g.Alive = false end end
	b.Boss.Stagger = 0
	b:HitEnemy(b.ById.A1, b.Boss, 1, false)
	check(math.abs(withWarder / b.Boss.Stagger - (1 - B.WarderAbsorb)) < 1e-6, "a standing Warder absorbs 30% of the Shield bar's fill")
	b.Boss.Stagger = 0
	b.Slot = "Skill"
	b:HitEnemy(b.ById.A1, b.Boss, 1, false)
	check(math.abs(b.Boss.Stagger - B.ShieldFill.Skill * B.Archetypes.Heavy.SkillShield) < 1e-6 and b.Boss.Stagger > B.ShieldFill.Basic * 2,
		"a Heavy Skill fills the Shield twice as hard as other Skills, far more than a Basic")

	local k = engine({ "rook" }, owned, 9)
	k.Boss.Pending = { Move = k.Boss.Moves[1], Left = 1 }
	k:DamageEnemy(k.ById.G1, k.ById.A1, k.ById.G1.MaxHP, false, "Hit")
	check(math.abs(k.Boss.Stagger - B.GuardKOShield) < 1e-9, "a guard KO shatters 25% of the leader's Shield")
	k:FillStagger(k.Boss, 1)
	local stunned = false
	for _, e in k:TakeEvents() do stunned = stunned or e.K == "Stagger" end
	check(stunned and k.Boss.Staggered == B.StaggerSeconds and k.Boss.Pending == nil and k.Boss.Stagger == 0,
		"a full Shield breaks: the leader is stunned 6 s and its warned move is cancelled")
	local acted = false
	for _ = 1, 50 do
		k:Step(B.Tick)
		for _, e in k:TakeEvents() do acted = acted or (e.K == "Act" and e.U == "Boss") end
	end
	check(not acted, "a broken leader doesn't act during its stun")
end

-- 4. Guards: Warder link 40%, Strikers / Hexers stack on the highest-ATK card.
do
	local owned = F.own({ "rook", "hana" })
	local b = engine({ "rook", "hana" }, owned, 3)
	check(b:Protection(b.Boss) == 0.4, "a Warder's link cuts the leader's damage taken by 40%")
	local striker, strongest = nil, b:Strongest()
	for _, g in b.Enemies do if g.Role == "Striker" then striker = g end end
	b:EnemyStrike(striker, striker.Moves[#striker.Moves], b.ById.A2)
	b:EnemyStrike(striker, striker.Moves[#striker.Moves], b.ById.A2)
	check(strongest.Expose == 2 and strongest.HexLeft > 0, "a Striker stacks Expose on the highest-ATK card, whoever it hit")
	local plainHit = function(expose)
		local c = engine({ "rook" }, owned, 5)
		c.ById.A1.Expose = expose
		local before = c.ById.A1.HP
		c:HitAlly(c.Boss, c.ById.A1, { Name = "Test", Target = "Single", Pct = 1 })
		return before - c.ById.A1.HP
	end
	check(math.abs(plainHit(4) / plainHit(0) - (1 + 4 * B.HexStack)) < 0.01, "each Expose stack adds 5% damage taken")
	local h = Engine.new({ Units = F.units(F.deck({ "rook" }, {}), owned), BossId = "rimeveil", Difficulty = "Normal", Rng = Random.new(2) })
	local hexer
	for _, g in h.Enemies do if g.Role == "Hexer" then hexer = g end end
	h.ById.A1.MaxHP, h.ById.A1.HP = 1e12, 1e12
	for _ = 1, 7 do h:EnemyStrike(hexer, hexer.Moves[#hexer.Moves], h.ById.A1) end
	check(h.ById.A1.Weaken == B.HexStacks and #h.ById.A1.Burns > 0, "a Hexer stacks Weaken (up to 5) and Burns the highest-ATK card")
	h:Step(B.HexSeconds + 0.1)
	check(h.ById.A1.Weaken == 0, "Weaken / Expose stacks fall off when they aren't refreshed")
end

-- 5. Vanguard: Attack slot 1 draws half of single-target attacks, 80% as a Warder.
do
	local function share(first)
		local owned = F.own({ first, "kaede", "suzu", "luna" })
		local b = engine({ first, "kaede", "suzu", "luna" }, owned, 11)
		local n, hits = 4000, 0
		for _ = 1, n do
			if b:PickTarget(true) == b.ById.A1 then hits += 1 end
		end
		local random = 0
		for _ = 1, n do
			if b:PickTarget(false) == b.ById.A1 then random += 1 end
		end
		return hits / n, random / n
	end
	local plain, spread = share("hana")
	local warder = share("rook")
	check(math.abs(plain - B.Vanguard) < 0.04 and math.abs(warder - B.WarderVanguard) < 0.04 and math.abs(spread - 0.25) < 0.04,
		`the Vanguard draws {math.floor(plain * 100)}% of single-target hits ({math.floor(warder * 100)}% as a Warder); area / random hits spread evenly`)
end

-- 6. Boss Clash: the warned move opens a 1.2 s window; a Clash reflects 200% ATK, fills the Shield 30% and
-- cuts the move's damage 75%; ignored, the move lands as normal.
do
	local owned = F.own({ "rook", "hana" }, 0, { rook = "Gold", hana = "Gold" })
	local function run(clash)
		local b = engine({ "rook", "hana" }, owned, 21)
		for _, g in b.Enemies do if not g.Leader then g.Alive = false end end
		local move
		for _, m in b.Boss.Moves do if m.Warn and m.Target == "Single" and (m.Phase or 1) == 1 then move = m end end
		b.Boss.Pending = { Move = move, Target = b.ById.A1, Left = 0.05 }
		b.Boss.Gauge = -100 -- nothing else from the leader in this sample
		for _, unit in b.Allies do unit.Gauge, unit.SkillGauge = -100, 0 end
		local opened, early, taken, reflected, accepted = false, nil, 0, nil, nil
		early = b:Clash()
		for _ = 1, 25 do
			b:Step(B.Tick)
			for _, e in b:TakeEvents() do
				if e.K == "ClashOpen" then opened = true end
				if e.K == "Hit" and e.U == "Boss" then taken += e.A end
				if e.K == "Hit" and e.T == "Boss" and e.U ~= "Boss" then reflected = e end
			end
			if clash and opened and accepted == nil then
				accepted = b:Clash()
				for _, e in b:TakeEvents() do
					if e.K == "Hit" and e.U == "Boss" then taken += e.A end
					if e.K == "Hit" and e.T == "Boss" then reflected = e end
				end
			end
		end
		return opened, early, accepted, taken, reflected, b
	end
	local opened, early, _, plainTaken = run(false)
	local _, _, accepted, cutTaken, reflected, b = run(true)
	check(opened and early == false, "a warned leader move opens a Clash window when its warning ends; a Clash before it is refused")
	check(accepted == true and reflected ~= nil and reflected.U == "A1" and b.Boss.Stagger >= B.ClashShield - 1e-9,
		"a Clash in time sends the strongest card in: it hits back and the Shield fills 30%")
	check(plainTaken > 0 and math.abs(cutTaken / plainTaken - (1 - B.ClashCut)) < 0.02, `a Clash cuts the move's damage by 75% ({cutTaken} vs {plainTaken})`)
	check(b:Clash() == false, "a window is used once; a second Clash is refused")
end

-- 7. HOLD ULT FOR BREAK: AUTO ULT keeps full Ultimates past 60% Shield, then fires them into the break.
do
	local owned = F.own({ "rook", "hana" })
	local b = engine({ "rook", "hana" }, owned, 6)
	b.AutoUlt, b.HoldForBreak = true, true
	b.Boss.Stagger = 0.7
	b.Slot = nil
	for _, unit in b.Allies do unit.Energy = unit.UltCost end
	local fired = 0
	for _ = 1, 10 do
		b:Step(B.Tick)
		b.Boss.Stagger = math.max(b.Boss.Stagger, 0.7)
		for _, e in b:TakeEvents() do if e.K == "Act" and e.Ab == "Ultimate" then fired += 1 end end
	end
	check(fired == 0 and b:Snapshot().Ho == true and string.find(b:Snapshot().U.A1.F, "H") ~= nil, "AUTO ULT holds full Ultimates while the Shield is past 60% (cards show H)")
	b:FillStagger(b.Boss, 1)
	local times = {}
	for _ = 1, 20 do
		b:Step(B.Tick)
		for _, e in b:TakeEvents() do if e.K == "Act" and e.Ab == "Ultimate" then table.insert(times, b.Time) end end
	end
	check(#times == 2 and times[2] - times[1] >= B.BreakChainGap - 1e-6 and times[2] - times[1] < B.TeamUltimateGap, "on the break, held Ultimates fire one after another")
	local free = engine({ "rook", "hana" }, owned, 6)
	free.AutoUlt, free.HoldForBreak = true, false
	free.Boss.Stagger = 0.7
	for _, unit in free.Allies do unit.Energy = unit.UltCost end
	local any = false
	for _ = 1, 3 do
		free:Step(B.Tick)
		for _, e in free:TakeEvents() do any = any or (e.K == "Act" and e.Ab == "Ultimate") end
	end
	check(any, "with HOLD off, AUTO ULT fires at once")
end

-- 8. Passives carry no self-penalties: no self debuffs, healing locks or HP costs on any card's passive;
-- Support costs are gone (Heavenly Restriction's Weaken lands on the enemy).
do
	local clean = true
	for _, card in Cards.List do
		for _, ability in card.Abilities do
			if ability.Slot == "Passive" or ability.Slot == "Aura" or ability.Slot == "Signature" then
				for _, e in ability.Effects do
					local selfSide = e.Target == nil or e.Target == "Self" or e.Target == "All" or e.Target == "Attack"
					if e.Kind == "HealingLock" or e.Kind == "HPCost" or (e.Kind == "Buff" and selfSide and (e.Amount or 0) < 0) then
						print(`   self-penalty on {card.Id} {ability.Name}`)
						clean = false
					end
				end
			end
		end
		local support = card.Support
		if support and support.Penalty and support.Kind ~= "Dodge" then
			print(`   Support cost on {card.Id}`)
			clean = false
		end
	end
	check(clean, "no Attack, sky or Support passive carries a self-penalty")
end
