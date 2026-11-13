--!strict
-- Each board offers two permanent, one-time Gold cards. Guard numbers are the actual battle slots.
type Hunt = {Card: string, Guard: string}
local Hunts = {}
Hunts.ByWorld = {
	kurogane = { { Card = "yume", Guard = "G2" }, { Card = "ocular_seal", Guard = "G1" } },
	rimeveil = { { Card = "kaito", Guard = "G1" }, { Card = "raijen", Guard = "G3" } },
	vex = { { Card = "kaede", Guard = "G2" }, { Card = "tsubasa", Guard = "G3" } },
	tenrai = { { Card = "suzu", Guard = "G1" }, { Card = "thunderclap_form", Guard = "G2" } },
} :: { [string]: {Hunt} }

function Hunts.Find(world: string, cardId: unknown): Hunt?
	local choices = Hunts.ByWorld[world]
	if not choices then return nil end
	for _, hunt in choices do
		if hunt.Card == cardId then return hunt end
	end
	return nil
end

function Hunts.Award(data: any, world: string, id: string, battle: any): boolean
	local hunt = Hunts.Find(world, id)
	if not hunt or data.Progress.Hunts[id] then return false end
	local guard = battle.ById[hunt.Guard]
	if battle.BossId ~= world or battle.Result ~= "Win" or battle.HuntGuard ~= hunt.Guard
		or not battle.HuntMarked or not guard or guard.Alive then return false end

	local entry = data.Cards[id] or { Copies = 0, Stars = 0 }
	entry.BorderCopies = entry.BorderCopies or { Normal = entry.Copies }
	entry.Borders = entry.Borders or {}
	entry.BorderCopies.Gold = (entry.BorderCopies.Gold or 0) + 1
	entry.Borders.Gold = true
	entry.Copies += 1
	data.Cards[id] = entry
	data.Progress.Hunts[id] = true
	return true
end
return Hunts
