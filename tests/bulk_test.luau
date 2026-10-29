-- Instant bulk pack opening (BulkRoll) and the 2026-10-30 Support border values.
do
	local Bulk, Batch, Cards = MODULES.BulkRoll, MODULES.PackBatch, MODULES.Cards
	local rng = Random.new(12345)

	-- Binomial: exact edges, and means / spreads that match n * p for small and huge counts.
	check(Bulk.Binomial(rng, 0, 0.5) == 0 and Bulk.Binomial(rng, 100, 0) == 0 and Bulk.Binomial(rng, 100, 1) == 100, "binomial edges: no trials, p 0 and p 1")
	local meansOk = true
	for _, case in { { 1000, 0.002 }, { 100000, 0.0002 }, { 1e7, 1 / 5000 }, { 1e9, 2e-6 }, { 5000, 0.7 } } do
		local n, p = case[1], case[2]
		local total, runs = 0, 200
		for _ = 1, runs do
			local k = Bulk.Binomial(rng, n, p)
			meansOk = meansOk and k >= 0 and k <= n and k == math.floor(k)
			total += k
		end
		local mean, sd = n * p, math.sqrt(n * p * (1 - p))
		meansOk = meansOk and math.abs(total / runs - mean) < 5 * sd / math.sqrt(runs) + 0.05
	end
	check(meansOk, "binomial draws are whole numbers in [0, n] whose average is n x p, from 1,000 to 1,000,000,000 trials")

	-- Multinomial: the counts always add up to exactly n when the chances sum to 1, at any size.
	local exact = true
	for _, n in { 1, 10, 1000, 100000, 1e8 } do
		local counts = Bulk.Multinomial(rng, n, { 0.5, 0.3, 0.15, 0.05 })
		local sum = 0
		for _, c in counts do sum += c end
		exact = exact and sum == n
	end
	check(exact, "a multinomial split of n pulls always adds up to n")

	-- 100,000 pulls of the real pool: every card's share is within a few standard deviations of its chance.
	local pool = Cards.Pool({})
	local chances = Cards.PullChances(pool)
	local probs = {}
	for i, card in pool do probs[i] = chances[card.Id] end
	local n = 100000
	local split = Bulk.Multinomial(Random.new(99), n, probs)
	local fair, sum = true, 0
	for i, card in pool do
		local p = chances[card.Id]
		sum += split[i]
		fair = fair and math.abs(split[i] - n * p) < 6 * math.sqrt(n * p * (1 - p)) + 1
	end
	check(fair and math.abs(sum - n) <= 1, "100,000 bulk pulls land on each card at its pull chance")

	-- The work doesn't grow with the size of the opening.
	local start = os.clock()
	for _ = 1, 20 do Bulk.Multinomial(rng, 1e9, probs) end
	check(os.clock() - start < 1, "a billion-pull split costs the same handful of draws (20 of them in under a second)")

	-- Bulk receipts: one group per card / border, highlights rarest first.
	local batch = Batch.New()
	Batch.AddGroup(batch, "hana", "Normal", 90000, "Copy", false)
	Batch.AddGroup(batch, "hana", "Gold", 450, "Copy", true)
	Batch.AddGroup(batch, "raijen", "Secret", 1, "New", true, "demon", true)
	Batch.Finish(batch)
	check(batch.Rolls == 90451 and batch.Counts.Gold == 450 and batch.Results[1].CardId == "raijen" and batch.Results[1].Border == "Secret", "a bulk receipt counts every pull and leads with its rarest")
end

-- Support passives grow at every border (no repeats), and the Eight Trigrams cloak by 15 points.
do
	local Cards = MODULES.Cards
	local ok = true
	for _, card in Cards.List do
		if card.Support then
			local last = -1
			for _, b in { "Normal", "Gold", "Rainbow", "Secret" } do
				local v = Cards.SupportValue(card, 0, b)
				ok = ok and v > last
				last = v
			end
		end
	end
	check(ok, "every Support's strength rises at each border (Base < Gold < Rainbow < Secret)")
	local seal = Cards.Get("beast_seal") :: any
	check(Cards.SupportValue(seal, 0, "Normal") == 0.55 and Cards.SupportValue(seal, 0, "Secret") == 1, "Eight Trigrams Seal returns at 55% (Base) up to 100% (Secret)")
end
