--!strict
-- Many independent pulls at once, in a fixed amount of work: opening 100 Mega Packs (100,000 pulls) or a
-- million costs the same handful of binomial draws as opening one. Pure (the caller passes a Random), so
-- tests/bulk_test.luau checks the counts headless.
--
-- Binomial(n, p): exact for small expected counts (geometric skips between successes, n * p < 30),
-- otherwise the normal approximation with a continuity correction, clamped to [0, n]. Multinomial splits
-- n over categories by conditional binomials, so the counts always add up to exactly n.
local BulkRoll = {}

local function gaussian(rng: Random): number
	local u = 1 - rng:NextNumber() -- (0, 1]
	local v = rng:NextNumber()
	return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v)
end

function BulkRoll.Binomial(rng: Random, n: number, p: number): number
	n = math.floor(n)
	if n <= 0 or p <= 0 then
		return 0
	end
	if p >= 1 then
		return n
	end
	if p > 0.5 then
		return n - BulkRoll.Binomial(rng, n, 1 - p)
	end
	local mean = n * p
	if mean < 30 then
		-- Count successes by skipping ahead a geometric number of trials each time.
		local logq = if p < 1e-12 then -p else math.log(1 - p)
		local count, position = 0, 0
		while true do
			position += math.floor(math.log(1 - rng:NextNumber()) / logq) + 1
			if position > n then
				return count
			end
			count += 1
		end
	end
	local spread = math.sqrt(mean * (1 - p))
	return math.clamp(math.floor(mean + spread * gaussian(rng) + 0.5), 0, n)
end

-- `probs[i]` is category i's chance per pull; whatever is left over (1 - their sum) is "none".
-- Returns counts[i] (0 when a category gets nothing), summing to at most n (exactly n when probs sum to 1).
function BulkRoll.Multinomial(rng: Random, n: number, probs: { number }): { number }
	local counts = table.create(#probs, 0)
	local remaining = math.floor(n)
	local mass = 1
	for i, p in probs do
		if remaining <= 0 or mass <= 0 then
			break
		end
		local share = if p >= mass then 1 else p / mass
		local got = BulkRoll.Binomial(rng, remaining, share)
		counts[i] = got
		remaining -= got
		mass -= p
	end
	return counts
end

return BulkRoll
