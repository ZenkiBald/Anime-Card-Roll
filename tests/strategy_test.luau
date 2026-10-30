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
	-- Cosmic is the chase cards' element only (1 in 200 or rarer, or a sky card; never a boss card).
	valid = valid and (card.Element ~= "Cosmic" or ((card.Weather ~= nil or card.Weight <= 50) and card.Boss == nil))
end
for _, boss in Bosses.List do
	valid = valid and Elements.Get(boss.Element) ~= nil and boss.Element ~= "Cosmic"
end
for _, g in Bosses.GuardList do
	valid = valid and Elements.Get(g.Element) ~= nil and g.Element ~= "Cosmic"
end
check(valid, "every card, boss and guard has an element (Cosmic only on the chase cards)")

-- Themes remain for art/statuses but do not create elemental advantages or hidden team buffs.
local neutral=true
for _,a in Elements.List do
 for _,b in Elements.List do neutral=neutral and Elements.Multiplier(a.Id,b.Id)==1 end
end
check(neutral,"every elemental matchup is neutral")
check(#Elements.ActiveSynergies({"Flame","Flame","Storm","Storm","Storm","Storm"})==0,"theme counts grant no combat synergy")
local Bonds=MODULES.ColumnBonds
for _,bond in Bonds.List do
 check(Cards.Get(bond.Attack).Type=="Attack" and Cards.Get(bond.Support).Type=="Support","familiar bond has a real attacker and relic: "..bond.Name)
 local owned=F.own({bond.Attack,bond.Support})
 local battle=Engine.new({Units=F.units(F.deck({bond.Attack},{bond.Support}),owned),BossId="kurogane",Difficulty="Normal",Rng=Random.new(5)})
 local mod=battle.ById.S1.Modifier
 local def=Cards.Get(bond.Support).Support
 local applied=if bond.Stat=="Amount" then math.abs(mod.Amount-(Cards.SupportValue(Cards.Get(bond.Support),0,"Normal")+bond.Amount))<1e-8
  elseif bond.Stat=="Chance" then math.abs(mod.Def.Chance-(def.Chance+bond.Amount))<1e-8
  elseif bond.Stat=="Uses" then mod.Def.Uses==def.Uses+bond.Amount
  else battle.ById.A1.Buffs["Bond:S1"].Amount==bond.Amount
 check(applied,"familiar bonus changes the actual battle modifier: "..bond.Name)
end
check(#Bonds.Active(F.deck({"hana"},{"mitotic_seal"}))==1 and #Bonds.Active(F.deck({"hana","rook"},{"","mitotic_seal"}))==0,"familiar bonds require the matching column")
do
 -- Gold, so the squad lives long enough against Kurogane Normal's 250,000 HP for both combos.
 local owned=F.own({"hana","suzu","rook","tomo","mitotic_seal","thunderclap_form"},0,{hana="Gold",suzu="Gold",rook="Gold",tomo="Gold"})
 local battle,events=F.fight("kurogane","Normal",F.deck({"hana","suzu","rook","tomo"},{"mitotic_seal","thunderclap_form","",""}),owned,9)
 local seen,fired={},0
 local once=true
 for _,e in events do
  if e.K=="Bond" then fired+=1;once=once and not seen[e.N];seen[e.N]=true end
  if e.K=="Hit" then check(e.El==nil or e.El==0,"theme does not mark a hit strong or weak") end
 end
 check(once and fired==2,"each familiar column combo fires only once")
 check(#battle.Synergies==0,"no obsolete elemental synergy is installed")
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
