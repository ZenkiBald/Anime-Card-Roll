--!nonstrict
-- The roll bank on the client: reward rolls from boss and tower wins are saved as tickets on the server
-- (Rewards.luau has the format). Open asks the server to roll some of them and keeps the client's copy
-- of the bank in step; the caller plays the results with RewardReveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local State = require(script.Parent.Parent.State)

local RollBank = {}

local REASONS = {
	TooFast = "One moment...",
	InBattle = "Finish the fight first",
	NoTickets = "No saved rolls of that kind",
	Loading = "Still loading",
}

-- Opens up to `count` saved rolls of rarity floor `floor`. Returns the server's result (Results for
-- RewardReveal.Play), or nil and a message.
function RollBank.Open(floor: string, count: number): (any, string?)
	local ok, result = pcall(function()
		return Remotes.OpenRolls:InvokeServer(floor, count)
	end)
	if not ok or result == nil or not result.Ok then
		return nil, if ok and result then REASONS[result.Reason] or "Couldn't open them" else "Couldn't open them, try again"
	end
	State.ApplyBank(result.Bank)
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	return result, nil
end

return RollBank
