-- Phase 2: foils, Awakening, Momentum and surges, Pack Alchemy, Deck Cost, Trait Shard sources, and the
-- battle upgrades (Stagger, Slot Links, unit effects, the 400% bond).
local Config = MODULES.Config
local Cards = MODULES.Cards
local Deck = MODULES.Deck
local Foils = MODULES.Foils
local Awaken = MODULES.Awaken
local RollBoost = MODULES.RollBoost
local Packs = MODULES.Packs
local Rewards = MODULES.Rewards
local Tower = MODULES.Tower
local Raid = MODULES.Raid
local Traits = MODULES.Traits
local Meta = MODULES.Meta
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. Foils ---------------------------------------------------------------------------------------
local fc = Foils.Chances()
check(near(fc.standard, 0.88) and near(fc.aura, 0.1) and near(fc.golden, 0.019) and near(fc.demon, 0.001), "foil odds: 88 / 10 / 1.9 / 0.1%")
local doubled = Foils.Chances(2)
check(near(doubled.demon, 0.002) and near(doubled.standard, 1 - 2 * 0.12), "a perfect surge doubles the foil odds")
local rng = Random.new(7)
local seen = {}
for _ = 1, 200000 do
	local foil = Foils.Pick(rng:NextNumber())
	seen[foil] = (seen[foil] or 0) + 1
end
check(seen.aura and seen.golden and seen.demon and seen.aura > seen.golden and seen.golden > seen.demon, "sampled foils come out in their order of rarity")
check(Foils.Best({ aura = true, demon = true }) == "demon" and Foils.Best(nil) == "standard", "a card wears its best foil")

-- 2. Awakening ------------------------------------------------------------------------------------
check(Awaken.FromCopies(19) == 0 and Awaken.FromCopies(20) == 1 and Awaken.FromCopies(80) == 4 and Awaken.FromCopies(400) == 4, "every 20 copies open a node, up to 4 before fusing")
check(Awaken.Level({ Copies = 5, Awaken = 3 }) == 3, "a node stays open after the copies are spent")
check(Awaken.Level({ Copies = 1, Fusion = 1 }) == 5, "a fused card has node 5")
local card = Cards.Get("tomo")
check(Cards.Stat(card, 100, 0, 0, nil, 1) == 110 and Cards.Stat(card, 100, 0, 0, nil, 0) == 100, "node 1 adds +10% base stats")

-- 3. Momentum and surges -----------------------------------------------------------------------------
local speed, luck = RollBoost.MomentumBonus(500)
check(near(speed, 0.5) and near(luck, 0.5), "a 500-roll chain gives +50% roll speed and +0.5x luck")
local s2, l2 = RollBoost.MomentumBonus(5000)
check(near(s2, 0.5) and near(l2, 0.5) and near((RollBoost.MomentumBonus(19)), 0.01), "the chain caps at 500 and steps every 10")
check(RollBoost.IsSurge(25) and RollBoost.IsSurge(50) and not RollBoost.IsSurge(24), "every 25th roll is an Overcharge Surge")
check(RollBoost.UntilSurge(24) == 1 and RollBoost.UntilSurge(25) == 25, "the HUD counts down to the next surge")
local plain = Meta.Cooldown({}, {})
check(Meta.Cooldown({}, {}, nil, nil, nil, { Momentum = 0.5 }) < plain and Meta.Cooldown({}, {}, nil, nil, nil, { Pass = 0.3 }) < plain, "Momentum and the Fast Roll pass shorten the cooldown")
check(Meta.Cooldown({ RollSpeed = 10 }, { speed = 60 }, 0.4, nil, nil, { Momentum = 0.5, Pass = 0.3 }) >= 0.4, "the cooldown never drops under 0.4 s")
check(near(Meta.BaseLuck({}, {}, nil, nil, nil, 0.55), 1.55), "Awakening and Momentum luck add to base luck")

-- 4. Pack Alchemy ---------------------------------------------------------------------------------------
check(Packs.Condense["10"].To == "100" and Packs.Condense["100"].To == "1000" and Packs.Condense["10"].Need == 10, "10 packs condense into the next size")
local infused = Packs.ById[Packs.InfusedId("Flame") or ""]
check(infused ~= nil and infused.Rolls == 1000 and infused.Element == "Flame" and Packs.InfusedId("Cosmic") == nil, "Mega Packs infuse with a base element")
check(Packs.Count({ ["1000:Void"] = 2, ["10"] = 1 }) == 3, "infused packs count as packs")

-- 5. Deck Cost and Trait Shards ------------------------------------------------------------------------
check(Cards.Cost(Cards.Get("rook")) == 1 and Cards.Cost(Cards.Get("raijen")) == 8 and Cards.Cost(Cards.Get("noa")) == 6, "Deck Cost by base rarity")
local starterCost = Deck.Cost(F.deck({ "tomo", "mirai", "rook", "kaede" }, { "suzu", "ibuki", "hana", "goro" }))
check(starterCost == 8, "the Common + Uncommon starter deck costs 8")
local topCost = Deck.Cost(F.deck(F.FIGHTS[12].Attack, F.FIGHTS[12].Support))
check(topCost > Config.Deck.CostCap, `a Secret / Mythic deck ({topCost}) breaks the {Config.Deck.CostCap}-point Cost Challenge`)
check(Rewards.TraitShards(1, false) == 1 and Rewards.TraitShards(12, false) == 5 and Rewards.TraitShards(6, true) == 2 * Rewards.TraitShards(6, false), "bosses pay 1-5 Trait Shards by D, doubled on a first clear")
check(Tower.Reward(3).TraitShards >= 1 and Tower.Reward(10).TraitShards >= 10 and Tower.Reward(50).TraitShards > Tower.Reward(10).TraitShards, "every tower floor pays Trait Shards, Guardians a big bundle")
local raidClear = Raid.Reward(true, 1e9, 30000, false)
local raidTop = Raid.Reward(true, 1e9, 30000, true)
check(raidClear.TraitShards > Raid.Reward(false, 1e9, 30000, false).TraitShards and raidTop.TraitShards == raidClear.TraitShards + Raid.TopTraitShards, "raids pay Trait Shards, more on a clear and for the top hitter")
local anyQuest, anyGift, anyWheel = false, false, false
for _, q in Meta.Quests do
	anyQuest = anyQuest or (q.Reward.TraitShards or 0) > 0
end
for _, g in Meta.Playtime do
	anyGift = anyGift or (g.Reward.TraitShards or 0) > 0
end
for _, prize in Meta.Wheel.Prizes do
	anyWheel = anyWheel or (prize.Reward.TraitShards or 0) > 0
end
check(anyQuest and anyGift and anyWheel, "quests, playtime gifts and the Lucky Wheel pay Trait Shards")
check(Traits.RollCost == 10 and Traits.LockCost == 25 and Traits.Slot2Node == 4, "a trait roll costs 10 Trait Shards, LOCK & ROLL 25, slot 2 opens at node 4")

-- 6. Battle --------------------------------------------------------------------------------------------
local owned = F.allOwned(0)
local function staggersWith(attackId)
	local battle = Engine.new({ Units = F.units(F.deck({ attackId }, {}), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(3), Guards = {} })
	local fill = 0
	for _ = 1, 20 do
		battle:HitEnemy(battle.ById.A1, battle.Boss, 0.01)
		fill = battle.Boss.Stagger + battle.Boss.Staggers
	end
	return fill
end
check(near(staggersWith("mirai"), 2.5 * staggersWith("rook")), "counter-element hits fill the Stagger bar 2.5x faster")

do
	local battle = Engine.new({ Units = F.units(F.deck({ "rook" }, {}), owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(4), Guards = {} })
	local events = {}
	battle.Boss.Stagger = 0.999
	battle:HitEnemy(battle.ById.A1, battle.Boss, 0.01)
	for _, e in battle:TakeEvents() do
		events[e.K] = true
	end
	check(events.Stagger and battle.Boss.Staggered > 0 and battle:EnemyDEF(battle.Boss) == 0, "a full bar Staggers the leader: DEF 0")
	local gauge = battle.Boss.Gauge
	battle:Step(1)
	check(battle.Boss.Gauge == gauge, "a Staggered leader can't act")
end

do
	local deck = F.deck({ "rook", "tomo" }, { "suzu", "" })
	local battle = Engine.new({ Units = F.units(deck, owned), BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(5) })
	check(battle:Buff(battle.ById.A1, "ATK") >= 0.06 and #battle.Links == 1 and battle.Links[1].To == "A1", "Support slot 1's Slot Link reaches Attack slot 1")
end

do
	local units = F.units(F.deck({ "rook" }, {}), owned)
	units[1].Trait = { { Stat = "HPCost", Amount = 0.05 }, { Stat = "ATK", Amount = 0.35 } }
	local battle = Engine.new({ Units = units, BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(6) })
	local unit = battle.ById.A1
	for _ = 1, 40 do
		battle:CardAct(unit)
	end
	check(unit.Alive and unit.HP == 1 and battle:Buff(unit, "ATK") >= 0.35, "a Demon Seal costs HP every action but never KOs its own card")
end

do
	-- Node 3 lifts the bond to 400%: compare the bond hit with and without it.
	local function bondHit(node)
		local units = F.units(F.deck({ "rook", "tomo" }, {}), owned)
		units[1].Awaken = node
		local battle = Engine.new({ Units = units, BossId = "kurogane", Difficulty = "Normal", Rng = Random.new(8), Guards = {} })
		battle:FireBonds()
		for _, e in battle:TakeEvents() do
			if e.K == "Hit" then
				return e.A
			end
		end
		return 0
	end
	local base, awakened = bondHit(0), bondHit(3)
	check(awakened > base * 1.3, `Awakening node 3 lifts the bond combo (300% -> 400%: {base} -> {awakened})`)
end
