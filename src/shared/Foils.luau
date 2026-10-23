--!strict
-- Foil Editions: every pull also rolls a foil, on its own (like Borders). A card keeps every foil it
-- has found (Cards[id].Foils) and wears the best one. Foils are battle-only (applied as unit effects in
-- BattleEngine, like traits): they never change Cards.Stat or Deck Power, so "rarity always wins" holds
-- for stats; a Demon Seal's ATK is paid for in HP every action.
-- Perfect Overcharge Surges double the foil odds (RollBoost.luau). A new foil is one entry in Foils.List.

local Foils = {}

-- Effect stats: the trait stats (Traits.luau) plus SkillDMG (Skill and Ultimate damage), ATK (battle
-- only) and HPCost (share of max HP lost on each of the card's actions, never below 1 HP).
export type Effect = { Stat: string, Amount: number }
export type Foil = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Chance: number, -- per pull, at no boost
	Effects: { Effect },
	Text: string,
}

Foils.List = {
	{ Id = "standard", Name = "Standard", Icon = "▫️", Color = Color3.fromRGB(200, 200, 214), Chance = 0.88, Effects = {}, Text = "No foil" },
	{
		Id = "aura",
		Name = "Aura Foil",
		Icon = "🌀",
		Color = Color3.fromRGB(120, 220, 255),
		Chance = 0.1,
		Effects = { { Stat = "SkillDMG", Amount = 0.08 } },
		Text = "+8% Skill and Ultimate damage",
	},
	{
		Id = "golden",
		Name = "Golden Ki",
		Icon = "🌟",
		Color = Color3.fromRGB(255, 205, 60),
		Chance = 0.019,
		Effects = { { Stat = "StartEnergy", Amount = 0.15 } },
		Text = "Starts with +15 Ultimate energy",
	},
	{
		Id = "demon",
		Name = "Demon Seal",
		Icon = "👹",
		Color = Color3.fromRGB(230, 40, 80),
		Chance = 0.001,
		Effects = { { Stat = "ATK", Amount = 0.35 }, { Stat = "HPCost", Amount = 0.05 } },
		Text = "+35% ATK in battle, costs 5% HP per action",
	},
} :: { Foil }

Foils.ById = {} :: { [string]: Foil }
for i, foil in Foils.List do
	Foils.ById[foil.Id] = foil
end

function Foils.Get(id: string?): Foil
	return Foils.ById[id or "standard"] or Foils.ById.standard
end

-- 1 = Standard ... 4 = Demon Seal.
function Foils.Index(id: string?): number
	for i, foil in Foils.List do
		if foil.Id == (id or "standard") then
			return i
		end
	end
	return 1
end

-- Each foil's chance with a multiplier on the special ones (2 on a perfect surge). Standard takes the rest.
function Foils.Chances(mult: number?): { [string]: number }
	local chances = {}
	local special = 0
	for i, foil in Foils.List do
		if i > 1 then
			chances[foil.Id] = foil.Chance * (mult or 1)
			special += chances[foil.Id]
		end
	end
	chances.standard = math.max(0, 1 - special)
	return chances
end

-- Which foil a roll in [0, 1) gives, rarest checked first.
function Foils.Pick(roll: number, mult: number?): string
	local chances = Foils.Chances(mult)
	for i = #Foils.List, 2, -1 do
		local id = Foils.List[i].Id
		roll -= chances[id]
		if roll < 0 then
			return id
		end
	end
	return "standard"
end

-- The best foil a card has found ({ aura = true, ... }), or "standard".
function Foils.Best(found: { [string]: boolean }?): string
	local best = "standard"
	for id, has in (found or {}) :: { [string]: boolean } do
		if has and Foils.ById[id] and Foils.Index(id) > Foils.Index(best) then
			best = id
		end
	end
	return best
end

function Foils.Effects(id: string?): { Effect }
	return Foils.Get(id).Effects
end

return Foils
