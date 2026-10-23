--!strict
-- Boss reward rolls, shared so the boss screen previews exactly what the server pays.
-- Each fight has a difficulty score D (World 1 Normal = 1 ... World 3 Nightmare = 9).

local Config = require(script.Parent.Config)
local Rarity = require(script.Parent.Rarity)

export type Reward = {
	Rolls: number, -- 3 + 2D
	Luck: number, -- 1 + 0.35D, capped at 4x (the player's own luck multiplies on top)
	Floor: string, -- results below this rarity are upgraded to it
	Bonus: string, -- first clear: one extra card of at least this rarity (one tier above the floor)
	Shards: number, -- 15 x D
	Potion: string, -- potion that may drop (Config.Rewards.PotionChance)
}

local Rewards = {}

function Rewards.For(d: number): Reward
	local r = Config.Rewards
	local floor = r.Floors[#r.Floors].Floor
	for _, step in r.Floors do
		if d <= step.MaxD then
			floor = step.Floor
			break
		end
	end
	local bonusIndex = math.min(#Rarity.Order, Rarity.Index(floor) + 1)
	local potion = r.PotionDrops[#r.PotionDrops].Potion
	for _, step in r.PotionDrops do
		if d <= step.MaxD then
			potion = step.Potion
			break
		end
	end
	return {
		Rolls = r.BaseRolls + r.RollsPerD * d,
		Luck = math.min(r.BossLuckCap, 1 + r.LuckPerD * d),
		Floor = floor,
		Bonus = Rarity.Order[bonusIndex],
		Shards = r.ShardsPerD * d,
		Potion = potion,
	}
end

-- The roll bank: reward rolls from boss and tower wins are saved as tickets, not rolled on the spot.
-- A ticket keeps its rarity floor and boss luck; the player's own luck is applied when it's opened, so
-- saving tickets for a luck potion or a LUCKY STORM pays off. Saved as RollBank[key] = count, where
-- key = "<floor>|<luck x 100>", e.g. "Rare|240".
Rewards.MaxOpen = 50 -- tickets opened by one OPEN press

function Rewards.TicketKey(floor: string, luck: number): string
	return `{floor}|{math.floor(luck * 100 + 0.5)}`
end

function Rewards.ParseTicket(key: string): (string?, number?)
	local floor, luck = string.match(key, "^(%a+)|(%d+)$")
	if floor == nil or table.find(Rarity.Order, floor) == nil then
		return nil, nil
	end
	return floor, tonumber(luck) / 100
end

-- Tickets per rarity floor, rarest first: { { Floor, Count, BestLuck, Keys (best luck first) } }.
function Rewards.BankGroups(bank: { [string]: number }): { { Floor: string, Count: number, BestLuck: number, Keys: { string } } }
	local byFloor = {}
	for key, count in bank do
		local floor, luck = Rewards.ParseTicket(key)
		if floor and luck and count > 0 then
			local group = byFloor[floor]
			if group == nil then
				group = { Floor = floor, Count = 0, BestLuck = 0, Keys = {} }
				byFloor[floor] = group
			end
			group.Count += count
			group.BestLuck = math.max(group.BestLuck, luck)
			table.insert(group.Keys, key)
		end
	end
	local groups = {}
	for _, group in byFloor do
		table.sort(group.Keys, function(a, b)
			local _, la = Rewards.ParseTicket(a)
			local _, lb = Rewards.ParseTicket(b)
			return (la :: number) > (lb :: number)
		end)
		table.insert(groups, group)
	end
	table.sort(groups, function(a, b)
		return Rarity.Index(a.Floor) > Rarity.Index(b.Floor)
	end)
	return groups
end

function Rewards.BankCount(bank: { [string]: number }?): number
	local n = 0
	for _, count in bank or {} do
		n += count
	end
	return n
end

-- Boss luck x the player's own luck, under the overall cap.
function Rewards.TotalLuck(bossLuck: number, playerLuck: number): number
	return math.min(Config.Roll.LuckCap, bossLuck * playerLuck)
end

return Rewards
