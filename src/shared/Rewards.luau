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

-- Boss luck x the player's own luck, under the overall cap.
function Rewards.TotalLuck(bossLuck: number, playerLuck: number): number
	return math.min(Config.Roll.LuckCap, bossLuck * playerLuck)
end

return Rewards
