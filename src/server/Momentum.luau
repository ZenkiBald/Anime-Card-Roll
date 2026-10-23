--!nonstrict
-- The Momentum chain per player (RollBoost.luau has the rules). RollService adds to it on every card
-- roll; MetaService reads it for luck and roll speed. Out of a fight, BreakSeconds without a roll breaks
-- it; in a fight the idle clock stands still. Session only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RollBoost = require(ReplicatedStorage.Shared.RollBoost)

local Momentum = {}

local chains = {} -- [Player] = { Count, Idle }
local inFight: ((Player) -> boolean)? = nil
local onBreak: ((Player) -> ())? = nil

-- `fighting` says whether the player is in a battle (BattleService.InBattle); `broke` is told when a
-- chain breaks (so the HUD can drop the meter).
function Momentum.Configure(fighting: (Player) -> boolean, broke: (Player) -> ())
	inFight = fighting
	onBreak = broke
end

function Momentum.Count(player: Player): number
	local chain = chains[player]
	return if chain then chain.Count else 0
end

-- One more roll in the chain; returns the new count.
function Momentum.Add(player: Player, rolls: number?): number
	local chain = chains[player]
	if chain == nil then
		chain = { Count = 0, Idle = 0 }
		chains[player] = chain
	end
	chain.Count = math.min(RollBoost.Momentum.Max, chain.Count + (rolls or 1))
	chain.Idle = 0
	return chain.Count
end

-- Roll speed and base luck from the chain right now.
function Momentum.Bonus(player: Player): (number, number)
	return RollBoost.MomentumBonus(Momentum.Count(player))
end

-- What the HUD shows.
function Momentum.State(player: Player)
	local chain = chains[player]
	local speed, luck = Momentum.Bonus(player)
	return {
		Count = if chain then chain.Count else 0,
		Idle = if chain then chain.Idle else 0,
		Speed = speed,
		Luck = luck,
		Paused = inFight ~= nil and inFight(player),
	}
end

function Momentum.Reset(player: Player)
	chains[player] = nil
end

function Momentum.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, chain in chains do
				if player.Parent ~= Players then
					chains[player] = nil
				elseif chain.Count > 0 and not (inFight and inFight(player)) then
					chain.Idle += 1
					if chain.Idle > RollBoost.Momentum.BreakSeconds then
						chains[player] = nil
						if onBreak then
							onBreak(player)
						end
					end
				end
			end
		end
	end)
end

return Momentum
