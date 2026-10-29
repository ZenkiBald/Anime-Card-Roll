--!strict
-- One shared search clock for manual, automatic and consumable rolls. No banked idle attempts.
local M={}
M.Seconds=1
function M.Take(gate: any, key: string, now: number): boolean
	if gate.Key==key and now<(gate.Next or 0) then return false end
	gate.Key=key;gate.Next=now+M.Seconds
	return true
end
-- Disjoint outcomes retain each card's exact authored chance; the rest is no sky find.
function M.Pick(pool: {any}, roll: number): any?
	for _,card in pool do
		roll-=1/card.SkyOneIn
		if roll<0 then return card end
	end
	return nil
end
return M
