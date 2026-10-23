-- Logic checks for the shared modules: border odds (the tiers; pure luck, no pity), the card pool and
-- card stat rules.
local Config = MODULES.Config
local Cards = MODULES.Cards
local Odds = MODULES.Odds
local Borders = MODULES.Borders

local function sum(t)
	local s = 0
	for _, id in Borders.Order do
		s += t[id]
	end
	return s
end

-- 1. Base border odds: 98.4 / 1.5 / 0.099 / 0.001.
local base = Odds.Chances(1)
check(near(base.Gold, 1.5, 1e-9) and near(base.Rainbow, 0.099, 1e-9) and near(base.Secret, 0.001, 1e-9) and near(base.Normal, 98.4, 1e-9), "1x border odds = 98.4 / 1.5 / 0.099 / 0.001")

-- 2. Luck: each special border's chance is base x luck ^ its exponent (Gold 0.6, Rainbow 0.8, Secret 1).
local two = Odds.Chances(2)
check(near(two.Gold, 1.5 * 2 ^ 0.6, 1e-9) and near(two.Rainbow, 0.099 * 2 ^ 0.8, 1e-9) and near(two.Secret, 0.002, 1e-9), "2x luck weights every border by luck ^ its exponent")
check(two.Secret / base.Secret > two.Gold / base.Gold, "the rarest borders gain the most from luck")

-- 3. Every combination sums to 100 and never goes negative; Base never drops under half.
local allSum, noneNegative, baseKept = true, true, true
for _, luck in { 1, 1.35, 2, 3.45, 5, 9, 25 } do
	for _, boost in { 0, 0.5, 2, 5, 40 } do
		local c = Odds.Chances(luck, boost)
		allSum = allSum and near(sum(c), 100, 1e-6)
		for _, id in Borders.Order do
			noneNegative = noneNegative and c[id] >= 0
		end
		baseKept = baseKept and c.Normal >= 50 - 1e-9
	end
end
check(allSum, "border odds always sum to 100% (luck 1-25, any boost)")
check(noneNegative, "no negative chances at any luck or boost")
check(baseKept, "however much is stacked, Base keeps at least half")
check(near(Odds.Chances(100).Secret, Odds.Chances(Config.Roll.LuckCap).Secret), "luck past the cap does nothing")

-- 4. Sampled frequencies match the table (1,000,000 pulls at 25x luck, where every border shows up).
local rng = Random.new(42)
local luck = Config.Roll.LuckCap
local chances = Borders.Chances(0, luck)
local counts = { Normal = 0, Gold = 0, Rainbow = 0, Secret = 0 }
local N = 1000000
for _ = 1, N do
	local b = Borders.Pick(rng:NextNumber(), 0, luck)
	counts[b] += 1
end
local sampledOk = true
for _, id in Borders.Order do
	local expected = chances[id] * N
	local sd = math.sqrt(expected * (1 - chances[id]))
	if math.abs(counts[id] - expected) > 5 * sd + 1 then
		sampledOk = false
		print(`   {id}: got {counts[id]}, expected {expected}`)
	end
end
check(sampledOk, "1,000,000 sampled pulls match the border odds (within 5 sigma)")

-- 5. The card pool: every card has a Weight; boss cards join after their boss's first Normal clear.
local startPool = Cards.Pool({})
local bosses = 0
for _, card in Cards.List do
	if card.Boss then
		bosses += 1
	end
end
check(bosses == 4 and #startPool == #Cards.List - 4, "4 boss cards, out of the pool until unlocked")
check(#Cards.Pool({ ["kurogane:Normal"] = true }) == #startPool + 1, "beating Kurogane on Normal adds Kurogane's card to the pool")
local pc = Cards.PullChances(startPool)
local pcSum = 0
for _, chance in pc do
	pcSum += chance
end
check(near(pcSum, 1, 1e-9), "card pull chances add up to 100%")
local infused = Cards.PullChances(startPool, "Flame", 1.5)
check(infused.rook > pc.rook and infused.kaede < pc.kaede, "an infused pack leans to its element")

-- 6. Stats: every base card sits on the same line (ATK 500 +-10%, HP = 2 x ATK; Support PWR 300 +-10%,
-- no HP), so the border decides power.
local bandOk = true
for _, card in Cards.List do
	if card.Type == "Attack" then
		bandOk = bandOk and card.Main >= 450 and card.Main <= 600 and card.HP == 2 * card.Main
	else
		bandOk = bandOk and card.HP == nil and card.Main >= 270 and card.Main <= 330
	end
	bandOk = bandOk and card.Weight > 0
end
check(bandOk, "ATK 450-600 with HP = 2 x ATK; Support PWR 270-330 with no HP; every card has a Weight")
local ROLES = { Striker = true, Hexer = true, Mender = true, Warder = true }
local rolesOk = true
for _, card in Cards.List do
	if not ROLES[card.Role] then
		rolesOk = false
		print(`   {card.Id}: Role {card.Role}`)
	end
end
check(rolesOk, "every card declares its Role: Striker / Hexer / Mender / Warder")

-- 7. The border always wins: 4x steps, and the best card at max stars and Awakening node 4 on one border
-- never reaches the weakest 0-star card on the next.
check(Borders.Multiplier("Normal") == 1 and Borders.Multiplier("Gold") == 4 and Borders.Multiplier("Rainbow") == 16 and Borders.Multiplier("Secret") == 64, "border multipliers 1 / 4 / 16 / 64")
local winsOk = true
for _, typ in { "Attack", "Support" } do
	for i = 1, #Borders.Order - 1 do
		local lowBest, highWorst = 0, math.huge
		for _, card in Cards.List do
			if card.Type == typ then
				lowBest = math.max(lowBest, Cards.Power(card, Config.MaxStars, Borders.Order[i], 4))
				highWorst = math.min(highWorst, Cards.Power(card, 0, Borders.Order[i + 1]))
			end
		end
		if lowBest >= highWorst then
			winsOk = false
			print(`   {typ}: best {Borders.Order[i]} {lowBest} >= weakest {Borders.Order[i + 1]} {highWorst}`)
		end
	end
end
check(winsOk, "a maxed card on one border never out-powers a 0-star card on the next")
local rook = Cards.Get("rook") :: any
check(Cards.Stat(rook, rook.Main, 0, "Gold") == 4 * rook.Main and Cards.Stat(rook, rook.HP, 0, "Secret") == 64 * rook.HP, "a Gold card has 4x, a Secret card 64x the base stats")

-- 8. Borders: helpers.
check(Borders.Best({ Gold = true, Secret = true }) == "Secret" and Borders.Best(nil) == "Normal", "a card wears its best border")
check(Borders.Next("Normal") == "Gold" and Borders.Next("Rainbow") == "Secret" and Borders.Next("Secret") == nil, "fusion goes Base -> Gold -> Rainbow -> Secret")
check(Borders.BestOwned({ Normal = 3, Gold = 0, Rainbow = 1 }) == "Rainbow", "the best border it still holds copies of")
check(Borders.Label("Gold") == "Gold Border · 4x", "border labels")
check(Borders.Get("Normal").Name == "Base", "the Normal save key shows as Base")
check(Cards.Cost("Normal") == 2 and Cards.Cost("Secret") == 8, "Deck Cost by border: Base 2 ... Secret 8")

-- 9. Display formatting.
check(Odds.FormatOneIn(0.099) == "1 in 1,010", "1 in N formatting (Rainbow = 1 in 1,010)")
check(Odds.FormatOneIn(0.001) == "1 in 100,000", "1 in N formatting (Secret = 1 in 100,000)")
check(Odds.FormatPercent(0.01) == "0.0100%", "small percentages keep 4 decimals")
