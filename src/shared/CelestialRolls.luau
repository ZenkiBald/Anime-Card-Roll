--!strict
-- Sky searches: while a sky is active, every normal pull (a click, each Triple Roll card, every pack pull)
-- also searches that sky once. Each card has its own authored 1 / SkyOneIn chance; luck lifts it slightly
-- (x (1 + (luck - 1) * LuckWeight)); the rest of each search is no find.
local BulkRoll = require(script.Parent.BulkRoll)
local M = {}
M.LuckWeight = 0.15
M.MaxTotal = 0.5 -- a safety ceiling for absurd dev luck: a search never finds a sky card more than half the time

-- Each card's chance per search at `luck`, in pool order.
function M.Chances(pool: { any }, luck: number?): { number }
	local factor = 1 + (math.max(1, luck or 1) - 1) * M.LuckWeight
	local chances, total = {}, 0
	for i, card in pool do
		chances[i] = factor / card.SkyOneIn
		total += chances[i]
	end
	if total > M.MaxTotal then
		for i in chances do
			chances[i] *= M.MaxTotal / total
		end
	end
	return chances
end

-- One search: the card found, or nil. `roll` in [0, 1).
function M.Pick(pool: { any }, roll: number, luck: number?): any?
	for i, chance in M.Chances(pool, luck) do
		roll -= chance
		if roll < 0 then
			return pool[i]
		end
	end
	return nil
end

-- `searches` searches at once: { [card] = finds }, for a click's few cards or a million pack pulls alike.
function M.Search(pool: { any }, searches: number, luck: number?, rng: Random): { [any]: number }
	local found = {}
	if searches <= 0 or #pool == 0 then
		return found
	end
	for i, n in BulkRoll.Multinomial(rng, searches, M.Chances(pool, luck)) do
		if n > 0 then
			found[pool[i]] = n
		end
	end
	return found
end

return M
