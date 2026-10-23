-- Logic checks for the shared modules: odds math, pity, card stat rules.
local Config = MODULES.Config
local Rarity = MODULES.Rarity
local Cards = MODULES.Cards
local Odds = MODULES.Odds

local function sum(t)
	local s = 0
	for _, name in Rarity.Order do
		s += t[name]
	end
	return s
end

-- 1. Base odds match the design doc.
local base = Odds.Chances(1)
check(near(base.Common, 60) and near(base.Uncommon, 25) and near(base.Rare, 10) and near(base.Epic, 4)
	and near(base.Legendary, 0.9) and near(base.Mythic, 0.09) and near(base.Secret, 0.01), "1x odds = 60/25/10/4/0.9/0.09/0.01")

-- 2. 2x luck example from the doc.
local two = Odds.Chances(2)
check(near(two.Rare, 20) and near(two.Epic, 8) and near(two.Legendary, 1.8) and near(two.Mythic, 0.18)
	and near(two.Secret, 0.02) and near(two.Uncommon, 25) and near(two.Common, 45), "2x odds match the doc example")

-- 3. Every combination sums to 100 and never goes negative.
local allSum, noneNegative = true, true
for _, luck in { 1, 1.35, 2, 3.45, 4, 5, 9 } do
	for _, floor in { false, "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
		local c = Odds.Chances(luck, if floor then floor else nil)
		if not near(sum(c), 100, 1e-6) then
			allSum = false
		end
		for _, name in Rarity.Order do
			if c[name] < 0 then
				noneNegative = false
			end
		end
	end
end
check(allSum, "odds always sum to 100% (luck 1-9, every floor)")
check(noneNegative, "no negative chances, luck capped at 5x")
check(near(Odds.Chances(5).Common, 0), "Common reaches 0% at the 5x cap")

-- 4. Floor upgrades low results instead of removing them: Legendary+ stays 1% x luck.
local f = Odds.Chances(4, "Epic")
check(near(f.Legendary + f.Mythic + f.Secret, 4, 1e-6) and near(f.Epic, 96, 1e-6), "Epic floor at 4x: Epic 96%, Legendary+ 4%")

-- 5. Sampled frequencies match the table (1,000,000 rolls at 1x).
local rng = Random.new(42)
local counts = {}
for _, name in Rarity.Order do
	counts[name] = 0
end
local N = 1000000
for _ = 1, N do
	local t = Odds.PickTier(base, rng)
	counts[t] += 1
end
local sampledOk = true
for _, name in Rarity.Order do
	local expected = base[name] / 100 * N
	local sd = math.sqrt(expected * (1 - base[name] / 100))
	if math.abs(counts[name] - expected) > 5 * sd + 1 then
		sampledOk = false
		print(`   {name}: got {counts[name]}, expected {expected}`)
	end
end
check(sampledOk, "1,000,000 sampled rolls match the odds (within 5 sigma)")

-- 6. Pity: never more than 50 rolls without Epic+, or 300 without Legendary+.
local pity = { Epic = 0, Legendary = 0 }
local sinceEpic, sinceLegendary, worstEpic, worstLegendary = 0, 0, 0, 0
for _ = 1, 300000 do
	local floor = Odds.PityFloor(pity)
	local tier = Odds.PickTier(Odds.Chances(1, floor), rng)
	Odds.UpdatePity(pity, tier)
	sinceEpic += 1
	sinceLegendary += 1
	if Rarity.AtLeast(tier, "Epic") then
		worstEpic = math.max(worstEpic, sinceEpic)
		sinceEpic = 0
	end
	if Rarity.AtLeast(tier, "Legendary") then
		worstLegendary = math.max(worstLegendary, sinceLegendary)
		sinceLegendary = 0
	end
end
check(worstEpic <= Config.Pity.Epic, `Epic pity holds (longest wait {worstEpic} of {Config.Pity.Epic})`)
check(worstLegendary <= Config.Pity.Legendary, `Legendary pity holds (longest wait {worstLegendary} of {Config.Pity.Legendary})`)

-- 7. Card set shape: the 18 starters (2+2 Common and Uncommon per type, 1 per type above) plus the
-- World 4 cards (Rare + Legendary Attack, Epic + Mythic Support).
check(#Cards.List == 22, "22 cards: 18 starters + 4 from World 4")
local WORLD4 = { Attack = { Rare = 1, Legendary = 1 }, Support = { Epic = 1, Mythic = 1 } }
local shapeOk = true
for _, typ in { "Attack", "Support" } do
	for _, name in Rarity.Order do
		local n = 0
		for _, card in Cards.List do
			if card.Type == typ and card.Rarity == name then
				n += 1
			end
		end
		local want = (if name == "Common" or name == "Uncommon" then 2 else 1) + (WORLD4[typ][name] or 0)
		if n ~= want then
			shapeOk = false
			print(`   {typ} {name}: {n} (want {want})`)
		end
	end
end
check(shapeOk, "each type has 2 Common, 2 Uncommon, 1 of every higher rarity (+ the World 4 cards)")

-- 8. Stats inside the +-10% band of their tier, and rarity always wins at max stars.
-- Support cards have no HP.
local BASE = { Attack = { Main = 100, HP = 400 }, Support = { Main = 60 } }
local bandOk = true
for _, card in Cards.List do
	local m = Rarity.Get(card.Rarity).Multiplier
	if card.Type == "Support" and card.HP ~= nil then
		bandOk = false
		print(`   {card.Id} is a Support card with HP`)
	end
	for _, stat in if card.Type == "Attack" then { "Main", "HP" } else { "Main" } do
		local center = BASE[card.Type][stat] * m
		local value = card[stat]
		if value < center * 0.9 - 1e-6 or value > center * 1.1 + 1e-6 then
			bandOk = false
			print(`   {card.Id} {stat} {value} outside {center * 0.9}-{center * 1.1}`)
		end
	end
end
check(bandOk, "every card's ATK/PWR (and Attack HP) sit within +-10% of its tier; Support cards have no HP")

local winsOk = true
for _, typ in { "Attack", "Support" } do
	for i = 1, #Rarity.Order - 1 do
		local lowBest, highWorst = 0, math.huge
		for _, card in Cards.List do
			if card.Type == typ and card.Rarity == Rarity.Order[i] then
				-- 5 stars and the best border (Secret) still can't reach the next rarity.
				lowBest = math.max(lowBest, Cards.Power(card, Config.MaxStars, 0, "Secret"))
			elseif card.Type == typ and card.Rarity == Rarity.Order[i + 1] then
				highWorst = math.min(highWorst, Cards.Power(card, 0))
			end
		end
		if lowBest >= highWorst then
			winsOk = false
			print(`   {typ}: best 5-star {Rarity.Order[i]} {lowBest} >= weakest {Rarity.Order[i + 1]} {highWorst}`)
		end
	end
end
check(winsOk, "a 5-star Secret-border card never out-powers a 0-star card of the next rarity")

-- Borders: odds add up, rarer ones are rarer, the stat raises them, and picks follow the odds.
local Borders = MODULES.Borders
local bc = Borders.Chances(0)
local bsum = 0
for _, id in Borders.Order do
	bsum += bc[id]
end
check(math.abs(bsum - 1) < 1e-9, "border chances add up to 100%")
check(bc.Gold > bc.Rainbow and bc.Rainbow > bc.Secret and bc.Secret > 0, "Gold > Rainbow > Secret")
check(Borders.Chances(0.9).Secret > bc.Secret, "Border Chance raises the special borders")
check(Borders.Pick(0, 0) == "Secret" and Borders.Pick(0.999999, 0) == "Normal", "border picks span Secret to Normal")
local brng = Random.new(7)
local golds = 0
for _ = 1, 200000 do
	if Borders.Pick(brng:NextNumber(), 0) == "Gold" then
		golds += 1
	end
end
check(math.abs(golds / 200000 - bc.Gold) < 0.003, "Gold borders come up at their listed chance")
check(Borders.Best({ Gold = true, Secret = true }) == "Secret" and Borders.Best(nil) == "Normal", "a card wears its best border")

-- 9. Display formatting.
check(Odds.FormatOneIn(0.0009 * 100) == "1 in 1,111", "1 in N formatting (Mythic = 1 in 1,111)")
check(Odds.FormatOneIn(0.01) == "1 in 10,000", "1 in N formatting (Secret = 1 in 10,000)")
check(Odds.FormatPercent(0.01) == "0.0100%", "small percentages keep 4 decimals")
