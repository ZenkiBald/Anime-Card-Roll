-- The strategy layer: elements, synergies, bonds (Elements.luau), the tower's daily mutators and
-- server raids (Raid.luau).
local Config = MODULES.Config
local Cards = MODULES.Cards
local Bosses = MODULES.Bosses
local Elements = MODULES.Elements
local Tower = MODULES.Tower
local Raid = MODULES.Raid
local Deck = MODULES.Deck
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. Data ----------------------------------------------------------------------------------------
local valid = true
for _, card in Cards.List do
	valid = valid and Elements.Get(card.Element) ~= nil
	-- Cosmic is the chase cards' element only (the lowest Weight, 1).
	valid = valid and (card.Element ~= "Cosmic" or (card.Weight <= 1 and card.Boss == nil))
end
for _, boss in Bosses.List do
	valid = valid and Elements.Get(boss.Element) ~= nil and boss.Element ~= "Cosmic"
end
for _, g in Bosses.GuardList do
	valid = valid and Elements.Get(g.Element) ~= nil and g.Element ~= "Cosmic"
end
check(valid, "every card, boss and guard has an element (Cosmic only on the chase cards)")

local counters = true
for _, boss in Bosses.List do
	local answers = Elements.Counters(boss.Element)
	local any = false
	for _, card in Cards.List do
		if card.Type == "Attack" and table.find(answers, card.Element) then
			any = true
		end
	end
	counters = counters and any
end
check(counters, "every boss has an Attack card whose element beats it")

check(Elements.Multiplier("Flame", "Frost") == Elements.Strong and Elements.Multiplier("Frost", "Flame") == Elements.Weak, "Flame beats Frost, Frost into Flame is weak")
check(Elements.Multiplier("Frost", "Storm") == Elements.Strong and Elements.Multiplier("Storm", "Flame") == Elements.Strong, "Frost beats Storm, Storm beats Flame")
check(Elements.Multiplier("Light", "Void") == Elements.Strong and Elements.Multiplier("Void", "Light") == Elements.Strong, "Light and Void beat each other")
check(Elements.Multiplier("Cosmic", "Void") == Elements.Strong and Elements.Multiplier("Storm", "Cosmic") == 1, "Cosmic beats every element and is weak to none")
check(Elements.Multiplier("Flame", "Flame") == 1 and Elements.Multiplier("Light", "Storm") == 1, "everything else is neutral")

-- The border still wins: a card one border up beats one below even when its matchup is against it.
local borderWins = true
local Borders = MODULES.Borders
for i = 2, #Borders.Order do
	local lower, upper = Borders.Multiplier(Borders.Order[i - 1]), Borders.Multiplier(Borders.Order[i])
	borderWins = borderWins and upper * Elements.Weak > lower * Elements.Strong
end
check(borderWins, "the border still wins: border x Weak (0.85) beats the border below x Strong (1.3)")

local syn = Elements.ActiveSynergies({ "Flame", "Flame", "Frost", "Cosmic", "Cosmic" })
check(#syn == 1 and syn[1].Synergy.Element == "Flame" and syn[1].Tier.Count == 2, "2 cards of an element switch its synergy on; Cosmic counts for none")
syn = Elements.ActiveSynergies({ "Storm", "Storm", "Storm", "Storm", "Void", "Void" })
local storm4 = false
for _, s in syn do
	storm4 = storm4 or (s.Synergy.Element == "Storm" and s.Tier.Count == 4)
end
check(#syn == 2 and storm4, "4 cards switch on the bigger tier, and two synergies can run at once")

local bondsOk = true
for _, bond in Elements.Bonds do
	bondsOk = bondsOk and Cards.Get(bond.Cards[1]) ~= nil and Cards.Get(bond.Cards[2]) ~= nil and bond.Cards[1] ~= bond.Cards[2]
end
check(bondsOk, "every bond names two real cards")
check(#Elements.ActiveBonds({ "rook", "tomo", "hana" }) == 1 and #Elements.ActiveBonds({ "rook", "hana" }) == 0, "a bond needs both its cards in the deck")

-- 2. In battle -------------------------------------------------------------------------------------
do
	-- Mirai (Storm) into Kurogane (Flame) is strong; nobody's hits on her from Flame enemies are strong.
	local owned = F.allOwned(0)
	local battle, events = F.fight("kurogane", "Normal", F.deck({ "mirai" }, {}), owned, 5)
	local strongOnFlame, weakFromFlame = false, false
	for _, e in events do
		if e.K == "Hit" and e.U == "A1" and battle.ById[e.T] and battle.ById[e.T].Element == "Flame" then
			strongOnFlame = strongOnFlame or e.El == 1
		end
		if e.K == "Hit" and e.T == "A1" and battle.ById[e.U] and battle.ById[e.U].Element == "Flame" then
			weakFromFlame = weakFromFlame or e.El == -1
		end
	end
	check(strongOnFlame, "a Storm card's hits on Flame enemies are marked strong")
	check(weakFromFlame, "Flame enemies' hits on a Storm card are marked weak")
end

do
	-- Rook + Tomo: one Dual Ultimate a fight, as the leader drops to half (or at BondAt).
	local owned = F.allOwned(0)
	local _, events = F.fight("kurogane", "Normal", F.deck({ "rook", "tomo", "mirai", "suzu" }, { "thunderclap_form", "heavenly_pact", "mitotic_seal", "blood_vow" }), owned, 9)
	local fired, once = 0, true
	local seenBond = {}
	for _, e in events do
		if e.K == "Bond" then
			fired += 1
			once = once and not seenBond[e.N]
			seenBond[e.N] = true
		end
	end
	-- Only character partners count: Rook + Tomo and Mirai + Suzu; relics are not their former owners.
	check(once and fired == 2, `each character bond in the deck fires once ({fired} of 2 fired)`)
end

do
	-- Synergies are on from the first second: 2 Flame cards = Wildfire on the Attack cards.
	local battle = Engine.new({
		Units = F.units(F.deck({ "rook", "tomo" }, {}), F.allOwned(0)),
		BossId = "kurogane",
		Difficulty = "Normal",
		Rng = Random.new(1),
	})
	check(#battle.Synergies == 1 and battle:Buff(battle.ById.A1, "ATK") > 0, "a synergy's buff is on as the fight opens")
end

-- 3. Tower mutators --------------------------------------------------------------------------------
local mutOk, seenMut = true, {}
for day = 20000, 20200 do
	local m = Tower.MutatorAt(day)
	mutOk = mutOk and m == Tower.MutatorAt(day)
	seenMut[m.Id] = true
end
for _, m in Tower.Mutators do
	mutOk = mutOk and seenMut[m.Id] == true and (m.Element == nil or Elements.Get(m.Element) ~= nil)
	for _, effect in m.Effects do
		-- Mutators only help, so the tuning tests (run without one) are the hardest case.
		mutOk = mutOk and effect.Amount > 0 and effect.Stat ~= "HP"
	end
end
check(mutOk, "the day's tower mutator is the same everywhere, every mutator shows up and only ever helps")
check(#Tower.MutatorEffects(Tower.MutatorById.wildfire, "Flame") == 1 and #Tower.MutatorEffects(Tower.MutatorById.wildfire, "Frost") == 0, "an element's mutator reaches only that element's cards")
check(#Tower.MutatorEffects(Tower.MutatorById.haste, "Void") == 1, "an every-card mutator reaches every card")
check(Tower.FloorForPower(Tower.Recommended(19)) == 19 and Tower.FloorForPower(1) == 1, "the floor for a power matches the tower's recommended power")

-- 4. Raids -----------------------------------------------------------------------------------------
local w = Raid.At(Raid.Offset + 5)
check(w.Open and w.Ends - w.Starts == Raid.Duration, "a raid opens on the clock for its duration")
local closed = Raid.At(Raid.Offset + Raid.Duration + 5)
check(not closed.Open and closed.Index == w.Index and closed.Next == w.Starts + Raid.Every, "between raids the window is closed and says when the next opens")
check(Raid.At(Raid.Offset + Raid.Every + 1).Index == w.Index + 1, "each hour is a new raid")
local forced = Raid.At(100, { Ends = 700 })
check(forced.Open and forced.Index ~= Raid.At(100).Index, "the test tools can open a raid now")

local cleared = Raid.Reward(true, 1e9, 30000, true)
local failed = Raid.Reward(false, 1e9, 30000, false)
check(cleared.Shards > failed.Shards and cleared.Packs and cleared.Packs["100"] == 1 and failed.Packs == nil, "a cleared raid pays more than a failed one; the top hitter gets a Big Roll Pack")
check(Raid.Reward(true, 0, 30000, false).Shards < Raid.Reward(true, 1e9, 30000, false).Shards, "more damage pays more")
check(Raid.Reward(true, 1e12, 30000, false).Shards == Raid.Reward(true, 1e13, 30000, false).Shards, "raid rewards are capped (no endless farming in one raid)")
check(Raid.LuckAt(10, 20) == Raid.LuckBoost and Raid.LuckAt(30, 20) == 1, "Raid Luck runs until it ends")

do
	-- A run: the Colossus alone, sized to the deck, lasts Raid.FightSeconds and can't be felled solo;
	-- a deck at its power drains its share of the pool in two-four runs, against every Colossus.
	-- (Up to fixture 9: the World 4 fixtures (10-12) are the Cosmic / Light lineup, which counters every
	-- Colossus and drains its share in about one run, on purpose; Awakening nodes 2-3 also add damage Deck
	-- Power doesn't count. Nobody fells the Colossus solo either way.)
	local runsOk, shareOk = true, true
	for _, i in { 1, 3, 5, 8, 9 } do
		local deck, owned = F.fixtureDeck(F.FIGHTS[i])
		local power = Deck.Power(deck, owned)
		local line = string.format("   raid runs to drain a share at %6d power:", power)
		for _, colossus in Raid.Colossi do
			local stats = Raid.StatsFor(power)
			local dealt = 0
			for seed = 1, 4 do
				local battle = Engine.new({
					Units = F.units(deck, owned),
					BossId = colossus.Boss,
					Difficulty = Raid.Difficulty,
					Rng = Random.new(seed * 31 + i),
					Stats = { HP = stats.HP, ATK = stats.ATK, WarnSeconds = stats.WarnSeconds, BarrierHP = stats.Base },
					Guards = {},
					TimeLimit = Raid.FightSeconds,
				})
				battle.AutoUlt = true
				while not battle.Over do
					battle:Step(Config.Battle.Tick)
					battle:TakeEvents()
				end
				dealt += battle.Boss.MaxHP - battle.Boss.HP
				runsOk = runsOk and #battle.Enemies == 1 and battle.Result ~= "Win" and battle.Time <= Raid.FightSeconds + 0.1
			end
			local runs = Raid.PoolFor(power, colossus) / math.max(1, dealt / 4)
			line ..= string.format("  %s %.1f", colossus.Name, runs)
			shareOk = shareOk and runs >= 1 and runs <= 5
		end
		print(line)
	end
	check(runsOk, "a raid run is the Colossus alone, 60 s, and nobody fells it solo")
	check(shareOk, "a deck at its power drains its share of the pool in about 1-5 runs, against every Colossus")
end
