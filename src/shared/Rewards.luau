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
	TraitShards: number, -- 1 at D 1 up to 5 at D 12 (Rewards.TraitShards)
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
		TraitShards = Rewards.TraitShards(d, false),
	}
end

-- Trait Shards for a boss win: 1 at D 1 up to 5 at D 12, doubled on a first clear.
function Rewards.TraitShards(d: number, firstClear: boolean): number
	local shards = 1 + math.floor((math.clamp(d, 1, 12) - 1) * 4 / 11 + 0.5)
	return if firstClear then shards * 2 else shards
end

-- Boss luck x the player's own luck, under the overall cap.
function Rewards.TotalLuck(bossLuck: number, playerLuck: number): number
	return math.min(Config.Roll.LuckCap, bossLuck * playerLuck)
end

return Rewards
