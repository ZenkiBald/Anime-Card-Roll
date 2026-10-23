--!strict
-- Elements, team synergies and bonds: the strategy layer of a fight (design bible v2, "Elements &
-- Team Synergy Matrix", made our own).
--
--   * Every card, boss and guard has an element. Flame melts Frost, Frost grounds Storm, Storm douses
--     Flame; Light and Void beat each other; Cosmic (the Secret cards) beats every other element and
--     is weak to none.
--   * A hit from an element that beats the target's deals Strong (x1.3); a hit into an element that
--     beats the attacker's deals Weak (x0.85). Both ways: bosses and guards hit your cards by the same
--     rule. The numbers are picked so rarity still wins: a tier is 1.6x the one below, and 1.6 x 0.85
--     (1.36) is still more than 1.3, so a card one tier up wins even when the matchup is against it.
--   * Synergies: 2 or 4 cards of one element anywhere in the deck (Attack and Support rows together)
--     give the whole deck a small bonus for the fight; 4 replaces 2. Cosmic counts for none.
--   * Bonds: two named cards in the same deck. Once a fight, when the enemy leader first drops to half
--     HP (or BondAt seconds in, whichever comes first) and both cards still stand, they fire a Dual
--     Ultimate: Pct x both cards' ATK / PWR at the leader.
-- A new element, synergy or bond is one entry below (BattleEngine reads them as data).

local Elements = {}

export type Element = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Beats: { string },
	Text: string,
}

export type SynergyTier = {
	Count: number, -- cards of the element needed
	Text: string,
	Effects: { { Kind: string, Stat: string, Amount: number, Target: string } },
}

export type Synergy = { Element: string, Name: string, Tiers: { SynergyTier } }

export type Bond = { Id: string, Name: string, Cards: { string }, Pct: number, Text: string }

Elements.Strong = 1.3
Elements.Weak = 0.85
Elements.BondAt = 45 -- seconds: bonds fire by now even if the leader is still above half HP

Elements.List = {
	{ Id = "Flame", Name = "Flame", Icon = "🔥", Color = Color3.fromRGB(255, 75, 45), Beats = { "Frost" }, Text = "Melts Frost. Doused by Storm." },
	{ Id = "Frost", Name = "Frost", Icon = "❄️", Color = Color3.fromRGB(45, 200, 255), Beats = { "Storm" }, Text = "Grounds Storm. Melted by Flame." },
	{ Id = "Storm", Name = "Storm", Icon = "⚡", Color = Color3.fromRGB(255, 215, 0), Beats = { "Flame" }, Text = "Douses Flame. Grounded by Frost." },
	{ Id = "Light", Name = "Light", Icon = "☀️", Color = Color3.fromRGB(255, 240, 170), Beats = { "Void" }, Text = "Light and Void beat each other." },
	{ Id = "Void", Name = "Void", Icon = "🌑", Color = Color3.fromRGB(160, 45, 255), Beats = { "Light" }, Text = "Void and Light beat each other." },
	{
		Id = "Cosmic",
		Name = "Cosmic",
		Icon = "✨",
		Color = Color3.fromRGB(255, 130, 220),
		Beats = { "Flame", "Frost", "Storm", "Light", "Void" },
		Text = "Secret cards only: beats every element, weak to none.",
	},
} :: { Element }

Elements.ById = {} :: { [string]: Element }
for _, element in Elements.List do
	Elements.ById[element.Id] = element
end

-- Synergies: whole-deck bonuses for the fight, in the battle effect format (Cards.luau). They never
-- touch HP and stay small next to a rarity step.
Elements.Synergies = {
	{
		Element = "Flame",
		Name = "Wildfire",
		Tiers = {
			{ Count = 2, Text = "Attack cards +5% ATK", Effects = { { Kind = "Buff", Stat = "ATK", Amount = 0.05, Target = "Attack" } } },
			{ Count = 4, Text = "Attack cards +12% ATK", Effects = { { Kind = "Buff", Stat = "ATK", Amount = 0.12, Target = "Attack" } } },
		},
	},
	{
		Element = "Frost",
		Name = "Permafrost",
		Tiers = {
			{ Count = 2, Text = "Attack cards take 5% less damage", Effects = { { Kind = "Buff", Stat = "Guard", Amount = 0.05, Target = "Attack" } } },
			{
				Count = 4,
				Text = "Attack cards take 10% less damage, enemies -8% SPD",
				Effects = {
					{ Kind = "Buff", Stat = "Guard", Amount = 0.1, Target = "Attack" },
					{ Kind = "Debuff", Stat = "SPD", Amount = 0.08, Target = "Enemies" },
				},
			},
		},
	},
	{
		Element = "Storm",
		Name = "Tempest",
		Tiers = {
			{ Count = 2, Text = "Every card +5% SPD", Effects = { { Kind = "Buff", Stat = "SPD", Amount = 0.05, Target = "All" } } },
			{
				Count = 4,
				Text = "Every card +10% SPD and starts with 25 energy",
				Effects = {
					{ Kind = "Buff", Stat = "SPD", Amount = 0.1, Target = "All" },
					{ Kind = "Energy", Stat = "", Amount = 25, Target = "All" },
				},
			},
		},
	},
	{
		Element = "Light",
		Name = "Radiance",
		Tiers = {
			{ Count = 2, Text = "Attack cards +5% crit chance", Effects = { { Kind = "Buff", Stat = "Crit", Amount = 0.05, Target = "Attack" } } },
			{
				Count = 4,
				Text = "Attack cards +10% crit chance, +20% crit damage",
				Effects = {
					{ Kind = "Buff", Stat = "Crit", Amount = 0.1, Target = "Attack" },
					{ Kind = "Buff", Stat = "CritDamage", Amount = 0.2, Target = "Attack" },
				},
			},
		},
	},
	{
		Element = "Void",
		Name = "Abyss",
		Tiers = {
			{ Count = 2, Text = "Enemies take 4% more damage", Effects = { { Kind = "Debuff", Stat = "Vuln", Amount = 0.04, Target = "Enemies" } } },
			{
				Count = 4,
				Text = "Enemies take 10% more damage and deal 6% less",
				Effects = {
					{ Kind = "Debuff", Stat = "Vuln", Amount = 0.1, Target = "Enemies" },
					{ Kind = "Debuff", Stat = "ATK", Amount = 0.06, Target = "Enemies" },
				},
			},
		},
	},
} :: { Synergy }

Elements.SynergyByElement = {} :: { [string]: Synergy }
for _, synergy in Elements.Synergies do
	Elements.SynergyByElement[synergy.Element] = synergy
end

-- Bonds: pairs with a story. Pct is a share of both cards' ATK / PWR added together.
Elements.Bonds = {
	{ Id = "village", Name = "Martial Oath", Cards = { "rook", "tomo" }, Pct = 3, Text = "The brawler and the lantern swordsman swore to guard Ember Village together." },
	{ Id = "mist", Name = "Shadow and Mist", Cards = { "kaede", "ibuki" }, Pct = 3, Text = "Kunai fly out of Ibuki's fog where no one can see them coming." },
	{ Id = "drum", Name = "Thunder Rhythm", Cards = { "mirai", "suzu" }, Pct = 3, Text = "Suzu drums the rhythm, Mirai looses on the beat." },
	{ Id = "tempest", Name = "Rival Tempest", Cards = { "sora", "hayate" }, Pct = 3, Text = "Two storm blades, one wind: rivals since the dojo." },
	{ Id = "crimson", Name = "Pride & Lightning", Cards = { "akane", "kaito" }, Pct = 3, Text = "The copy blade and the golden warrior never agree, except on who falls first." },
	{ Id = "starfall", Name = "Celestial Gambit", Cards = { "noa", "luna" }, Pct = 3, Text = "Luna reads the stars, Noa drops them." },
	{ Id = "skyfall", Name = "Sky Sovereigns", Cards = { "tsubasa", "amaya" }, Pct = 3, Text = "The sky knight rides the oracle's lightning down." },
	{ Id = "duskdawn", Name = "Cosmic Supremacy", Cards = { "raijen", "aurelia" }, Pct = 3, Text = "Eclipse and sunrise: the two Secret sovereigns, finally on one side." },
} :: { Bond }

Elements.BondById = {} :: { [string]: Bond }
for _, bond in Elements.Bonds do
	Elements.BondById[bond.Id] = bond
end

function Elements.Get(id: string?): Element?
	return if id then Elements.ById[id] else nil
end

local function beats(a: string, b: string): boolean
	local element = Elements.ById[a]
	return element ~= nil and table.find(element.Beats, b) ~= nil
end

-- The damage multiplier for a hit from element `attacker` into element `defender`.
function Elements.Multiplier(attacker: string?, defender: string?): number
	if attacker == nil or defender == nil then
		return 1
	end
	if beats(attacker, defender) then
		return Elements.Strong
	end
	if defender ~= "Cosmic" and beats(defender, attacker) then
		return Elements.Weak
	end
	return 1
end

-- "Strong" | "Weak" | nil, for labels.
function Elements.Matchup(attacker: string?, defender: string?): string?
	local m = Elements.Multiplier(attacker, defender)
	return if m > 1 then "Strong" elseif m < 1 then "Weak" else nil
end

-- How many cards of each element a list of card elements holds (Cosmic counts for none).
function Elements.Count(elements: { string }): { [string]: number }
	local counts = {}
	for _, id in elements do
		if id ~= "Cosmic" then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

export type ActiveSynergy = { Synergy: Synergy, Tier: SynergyTier, Count: number }

-- The synergies a deck's elements switch on (the best tier of each), plus the next one within reach.
function Elements.ActiveSynergies(elements: { string }): { ActiveSynergy }
	local counts = Elements.Count(elements)
	local active = {}
	for _, synergy in Elements.Synergies do
		local count = counts[synergy.Element] or 0
		local best = nil
		for _, tier in synergy.Tiers do
			if count >= tier.Count then
				best = tier
			end
		end
		if best then
			table.insert(active, { Synergy = synergy, Tier = best, Count = count })
		end
	end
	return active
end

-- The bonds whose two cards are both in `cardIds`.
function Elements.ActiveBonds(cardIds: { string }): { Bond }
	local active = {}
	for _, bond in Elements.Bonds do
		if table.find(cardIds, bond.Cards[1]) and table.find(cardIds, bond.Cards[2]) then
			table.insert(active, bond)
		end
	end
	return active
end

-- The bonds a card is part of, and its partner in each.
function Elements.BondsOf(cardId: string): { { Bond: Bond, Partner: string } }
	local list = {}
	for _, bond in Elements.Bonds do
		if bond.Cards[1] == cardId then
			table.insert(list, { Bond = bond, Partner = bond.Cards[2] })
		elseif bond.Cards[2] == cardId then
			table.insert(list, { Bond = bond, Partner = bond.Cards[1] })
		end
	end
	return list
end

-- The elements that beat `defender` (what to bring against it).
function Elements.Counters(defender: string): { string }
	local list = {}
	for _, element in Elements.List do
		if element.Id ~= "Cosmic" and table.find(element.Beats, defender) then
			table.insert(list, element.Id)
		end
	end
	return list
end

-- "🔥 Flame"
function Elements.Label(id: string?): string
	local element = Elements.Get(id)
	return if element then `{element.Icon} {element.Name}` else ""
end

return Elements
