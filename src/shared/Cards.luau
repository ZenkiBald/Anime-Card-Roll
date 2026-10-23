--!strict
-- The 18 starter cards from the concept doc, plus the World 4 (Stormspire Isle) cards. All characters are original.
-- Adding a card = adding one entry here (plus art later). No other code changes.
--
-- Attack cards (front row) have ATK and HP: they deal the damage and take the enemies' hits.
-- Support cards (back row) have PWR only: no HP, never hit, never KO'd. They cast heals, shields,
-- buffs, debuffs and chip damage, and each casts its Basic once as the fight opens.
-- Stats stay within +-10% of their tier's base, so rarity always decides power.

-- What an ability does in battle, built from the effect library (BattleEngine runs them).
-- Pct is a share of the caster's ATK (Attack) or PWR (Support).
--   Damage  Pct per hit, Hits, IgnoreDef                Burn    Pct per turn, Turns, Chance
--   Heal    Pct                                         Shield  Pct (lasts Config.Battle.ShieldTurns)
--   Buff    Stat ATK | Crit | CritDamage | SPD | Guard (less damage taken), Amount, Turns (nil = whole battle)
--   Debuff  enemy Stat DEF | ATK | SPD | Vuln (takes more damage), Amount, Turns (nil = whole battle)
--   Energy  Amount, ResetSkill                          Cleanse Amount (burns/freezes removed per card)
--   Taunt   Turns                                       Revive  Pct of max HP
--   Evade   Hits (enemy hits that miss)
-- Target: the enemy side for Damage/Burn/Debuff: nil = the current target (the player's focus, else a
--   taunting guard, else the weakest enemy) | Enemies (every enemy) | RandomEnemy (each hit picks again).
--   The player's side for the rest: Self | Lowest | Attack | All | Random.
--   Heals, shields, cleanses and evades only reach Attack cards (Support cards have no HP).
-- When (Passive only): BossAbove50 | SelfBelow50 | OnAct | OnHit; nil = always on.
-- Secret signatures are the only coded mechanics: Kind = Eclipse | DawnOath.
export type Effect = {
	Kind: string,
	Pct: number?,
	Hits: number?,
	Target: string?,
	Stat: string?,
	Amount: number?,
	Turns: number?,
	Chance: number?,
	When: string?,
	IgnoreDef: boolean?,
	ResetSkill: boolean?,
	Every: number?,
}

export type Ability = {
	Slot: string, -- Basic | Skill | Passive | Ultimate | Aura | Signature
	Name: string,
	Text: string,
	Effects: { Effect },
	Every: number?, -- Skill: used instead of the Basic every N actions
}

export type Card = {
	Id: string,
	Name: string,
	Title: string,
	Type: string, -- "Attack" | "Support"
	Rarity: string,
	Element: string, -- Elements.luau: Flame | Frost | Storm | Light | Void | Cosmic
	Main: number, -- ATK for Attack, PWR for Support
	HP: number?, -- Attack cards only
	SPD: number,
	Glyph: string, -- initials, used where the 3D art isn't drawn
	Accent: Color3, -- portrait background colour
	Image: string?, -- the card's 2D illustration ("rbxassetid://..."); cards without one show their glyph
	Abilities: { Ability },
}

local Config = require(script.Parent.Config)
local Rarity = require(script.Parent.Rarity)
local Borders = require(script.Parent.Borders)

local function ability(slot: string, name: string, text: string, effects: { Effect }, every: number?): Ability
	return { Slot = slot, Name = name, Text = text, Effects = effects, Every = every }
end

local list: { Card } = {
	-- ATTACK -------------------------------------------------------------
	{
		Id = "rook",
		Name = "Rook",
		Title = "Village Brawler",
		Type = "Attack",
		Rarity = "Common",
		Element = "Flame",
		Main = 110,
		HP = 360,
		SPD = 95,
		Glyph = "RK",
		Accent = Color3.fromRGB(196, 120, 72),
		Abilities = { ability("Basic", "Heavy Jab", "100% ATK", { { Kind = "Damage", Pct = 1 } }) },
	},
	{
		Id = "kaede",
		Name = "Kaede",
		Title = "Kunai Thrower",
		Type = "Attack",
		Rarity = "Common",
		Element = "Void",
		Main = 95,
		HP = 420,
		SPD = 115,
		Glyph = "KD",
		Accent = Color3.fromRGB(120, 140, 170),
		Abilities = { ability("Basic", "Twin Kunai", "2 hits x 50% ATK on random enemies", { { Kind = "Damage", Pct = 0.5, Hits = 2, Target = "RandomEnemy" } }) },
	},
	{
		Id = "tomo",
		Name = "Tomo",
		Title = "Lantern Swordsman",
		Type = "Attack",
		Rarity = "Uncommon",
		Element = "Flame",
		Main = 165,
		HP = 620,
		SPD = 100,
		Glyph = "TM",
		Accent = Color3.fromRGB(255, 160, 70),
		Abilities = {
			ability("Basic", "Slash", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Passive", "Opening Cut", "+15% damage while the enemy leader is above 50% HP", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.15, When = "BossAbove50" },
			}),
		},
	},
	{
		Id = "mirai",
		Name = "Mirai",
		Title = "Spark Archer",
		Type = "Attack",
		Rarity = "Uncommon",
		Element = "Storm",
		Main = 150,
		HP = 680,
		SPD = 110,
		Glyph = "MR",
		Accent = Color3.fromRGB(255, 220, 90),
		Abilities = {
			ability("Basic", "Spark Arrow", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Passive", "Live Wire", "15% chance to Burn (5% ATK per turn, 3 turns)", {
				{ Kind = "Burn", Pct = 0.05, Turns = 3, Chance = 0.15, When = "OnHit" },
			}),
		},
	},
	{
		Id = "sora",
		Name = "Sora Ikazuchi",
		Title = "Storm Blade",
		Type = "Attack",
		Rarity = "Rare",
		Element = "Storm",
		Main = 270,
		HP = 1000,
		SPD = 120,
		Glyph = "SI",
		Accent = Color3.fromRGB(90, 180, 255),
		Abilities = {
			ability("Basic", "Slash", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Thunder Rush", "Every 3 actions: 3 hits x 80% ATK", {
				{ Kind = "Damage", Pct = 0.8, Hits = 3 },
			}, 3),
		},
	},
	{
		Id = "akane",
		Name = "Akane",
		Title = "Crimson Lancer",
		Type = "Attack",
		Rarity = "Epic",
		Element = "Flame",
		Main = 430,
		HP = 1700,
		SPD = 105,
		Glyph = "AK",
		Accent = Color3.fromRGB(230, 60, 70),
		Abilities = {
			ability("Basic", "Thrust", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Piercing Spiral", "Every 3 actions: 250% ATK + target DEF -15% for 2 turns", {
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 2 },
				{ Kind = "Damage", Pct = 2.5 },
			}, 3),
			ability("Passive", "Killer Edge", "Crits deal 200% instead of 150%", {
				{ Kind = "Buff", Stat = "CritDamage", Amount = 0.5 },
			}),
		},
	},
	{
		Id = "kaito",
		Name = "Kaito Ryuzen",
		Title = "Dragon-Eye Ronin",
		Type = "Attack",
		Rarity = "Legendary",
		Element = "Frost",
		Main = 720,
		HP = 2700,
		SPD = 110,
		Glyph = "KR",
		Accent = Color3.fromRGB(70, 200, 160),
		Abilities = {
			ability("Basic", "Cut", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Dragon Draw", "Every 3 actions: 300% ATK", { { Kind = "Damage", Pct = 3 } }, 3),
			ability("Passive", "Cornered Dragon", "+20% ATK below 50% HP", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.2, When = "SelfBelow50" },
			}),
			ability("Ultimate", "Thousand Dragon Cut", "8 hits x 90% ATK on random enemies", {
				{ Kind = "Damage", Pct = 0.9, Hits = 8, Target = "RandomEnemy" },
			}),
		},
	},
	{
		Id = "noa",
		Name = "Noa",
		Title = "Starfall Witch",
		Type = "Attack",
		Rarity = "Mythic",
		Element = "Void",
		Main = 1250,
		HP = 4600,
		SPD = 100,
		Glyph = "NO",
		Accent = Color3.fromRGB(150, 110, 255),
		Abilities = {
			ability("Basic", "Star Bolt", "120% ATK", { { Kind = "Damage", Pct = 1.2 } }),
			ability("Skill", "Comet Rain", "Every 3 actions: 4 hits x 100% ATK on random enemies", {
				{ Kind = "Damage", Pct = 1, Hits = 4, Target = "RandomEnemy" },
			}, 3),
			ability("Ultimate", "Meteor Requiem", "900% ATK + the target takes +25% damage for 3 turns", {
				{ Kind = "Damage", Pct = 9 },
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.25, Turns = 3 },
			}),
			ability("Aura", "Night Sky", "All Attack cards +10% ATK", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "raijen",
		Name = "Raijen",
		Title = "Eclipse Sovereign",
		Type = "Attack",
		Rarity = "Secret",
		Element = "Cosmic",
		Main = 2050,
		HP = 8100,
		SPD = 115,
		Glyph = "RJ",
		Accent = Color3.fromRGB(40, 30, 70),
		Abilities = {
			ability("Basic", "Shadow Edge", "120% ATK", { { Kind = "Damage", Pct = 1.2 } }),
			ability("Skill", "Umbra Cross", "Every 3 actions: 400% ATK", { { Kind = "Damage", Pct = 4 } }, 3),
			ability("Ultimate", "Black Sun", "1,500% ATK, ignores DEF and Warders", {
				{ Kind = "Damage", Pct = 15, IgnoreDef = true },
			}),
			ability("Signature", "Eclipse", "Every 5th action, he acts again at once", {
				{ Kind = "Eclipse", Every = 5 },
			}),
		},
	},

	-- SUPPORT ------------------------------------------------------------
	{
		Id = "hana",
		Name = "Hana",
		Title = "Herb Healer",
		Type = "Support",
		Rarity = "Common",
		Element = "Light",
		Main = 60,
		SPD = 100,
		Glyph = "HN",
		Accent = Color3.fromRGB(120, 200, 110),
		Abilities = {
			ability("Basic", "Herbal Mend", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
		},
	},
	{
		Id = "goro",
		Name = "Goro",
		Title = "Shield Monk",
		Type = "Support",
		Rarity = "Common",
		Element = "Light",
		Main = 55,
		SPD = 90,
		Glyph = "GR",
		Accent = Color3.fromRGB(200, 170, 110),
		Abilities = {
			ability("Basic", "Stone Palm", "Shield the most hurt Attack card 150% PWR", {
				{ Kind = "Shield", Pct = 1.5, Target = "Lowest" },
			}),
		},
	},
	{
		Id = "suzu",
		Name = "Suzu",
		Title = "Shrine Drummer",
		Type = "Support",
		Rarity = "Uncommon",
		Element = "Flame",
		Main = 100,
		SPD = 105,
		Glyph = "SZ",
		Accent = Color3.fromRGB(240, 110, 150),
		Abilities = {
			ability("Basic", "War Drum", "All Attack cards +8% ATK for 1 turn", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.08, Turns = 1, Target = "Attack" },
			}),
			ability("Passive", "Rhythm", "+5 energy to a random card with an Ultimate each time she acts", {
				{ Kind = "Energy", Amount = 5, Target = "Random", When = "OnAct" },
			}),
		},
	},
	{
		Id = "ibuki",
		Name = "Ibuki",
		Title = "Fog Weaver",
		Type = "Support",
		Rarity = "Uncommon",
		Element = "Frost",
		Main = 92,
		SPD = 100,
		Glyph = "IB",
		Accent = Color3.fromRGB(150, 170, 200),
		Abilities = {
			ability("Basic", "Mist Veil", "60% PWR damage + target -10% ATK for 1 turn", {
				{ Kind = "Damage", Pct = 0.6 },
				{ Kind = "Debuff", Stat = "ATK", Amount = 0.1, Turns = 1 },
			}),
			ability("Passive", "Ghost Step", "The first enemy hit on each Attack card misses", {
				{ Kind = "Evade", Hits = 1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "yume",
		Name = "Yume Aoi",
		Title = "Moonlight Priestess",
		Type = "Support",
		Rarity = "Rare",
		Element = "Frost",
		Main = 160,
		SPD = 110,
		Glyph = "YA",
		Accent = Color3.fromRGB(150, 200, 255),
		Abilities = {
			ability("Basic", "Moon Touch", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
			ability("Skill", "Moon Bloom", "Every 3 actions: heal all Attack cards 120% PWR + cleanse 1 debuff", {
				{ Kind = "Heal", Pct = 1.2, Target = "All" },
				{ Kind = "Cleanse", Amount = 1, Target = "All" },
			}, 3),
		},
	},
	{
		Id = "tetsu",
		Name = "Tetsu",
		Title = "Iron Wall Guardian",
		Type = "Support",
		Rarity = "Epic",
		Element = "Void",
		Main = 245,
		SPD = 85,
		Glyph = "TS",
		Accent = Color3.fromRGB(140, 150, 165),
		Abilities = {
			ability("Basic", "Guard", "Shield the most hurt Attack card 150% PWR", {
				{ Kind = "Shield", Pct = 1.5, Target = "Lowest" },
			}),
			ability("Skill", "Iron Bastion", "Every 3 actions: shield all Attack cards 100% PWR + they take 20% less damage for 2 turns", {
				{ Kind = "Shield", Pct = 1, Target = "All" },
				{ Kind = "Buff", Stat = "Guard", Amount = 0.2, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Passive", "Iron Wall", "Attack cards take 10% less damage", {
				{ Kind = "Buff", Stat = "Guard", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "luna",
		Name = "Luna Mei",
		Title = "Celestial Strategist",
		Type = "Support",
		Rarity = "Legendary",
		Element = "Light",
		Main = 430,
		SPD = 115,
		Glyph = "LM",
		Accent = Color3.fromRGB(110, 140, 255),
		Abilities = {
			ability("Basic", "Field Care", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
			ability("Skill", "Battle Plan", "Every 3 actions: all Attack cards +25% ATK for 2 turns", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.25, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Passive", "Tempo", "+5 energy to every card each time she acts", {
				{ Kind = "Energy", Amount = 5, Target = "All", When = "OnAct" },
			}),
			ability("Ultimate", "Grand Formation", "Reset all Attack Skill cooldowns + 30 energy each", {
				{ Kind = "Energy", Amount = 30, Target = "Attack", ResetSkill = true },
			}),
		},
	},
	{
		Id = "orin",
		Name = "Orin",
		Title = "Time Weaver",
		Type = "Support",
		Rarity = "Mythic",
		Element = "Void",
		Main = 740,
		SPD = 100,
		Glyph = "OR",
		Accent = Color3.fromRGB(90, 220, 220),
		Abilities = {
			ability("Basic", "Gentle Hours", "Heal all Attack cards 60% PWR", {
				{ Kind = "Heal", Pct = 0.6, Target = "All" },
			}),
			ability("Skill", "Haste", "Every 3 actions: every card +20% SPD for 2 turns", {
				{ Kind = "Buff", Stat = "SPD", Amount = 0.2, Turns = 2, Target = "All" },
			}, 3),
			ability("Ultimate", "Rewind", "Revive all KO'd Attack cards at 40% HP + heal them 200% PWR", {
				{ Kind = "Revive", Pct = 0.4 },
				{ Kind = "Heal", Pct = 2, Target = "All" },
			}),
			ability("Aura", "Slow Clock", "Every enemy -15% SPD", { { Kind = "Debuff", Stat = "SPD", Amount = 0.15, Target = "Enemies" } }),
		},
	},
	{
		Id = "aurelia",
		Name = "Aurelia",
		Title = "Dawn Empress",
		Type = "Support",
		Rarity = "Secret",
		Element = "Cosmic",
		Main = 1230,
		SPD = 110,
		Glyph = "AU",
		Accent = Color3.fromRGB(255, 214, 140),
		Abilities = {
			ability("Basic", "Radiant Heal", "Heal all Attack cards 80% PWR", {
				{ Kind = "Heal", Pct = 0.8, Target = "All" },
			}),
			ability("Skill", "Sunshield", "Every 3 actions: shield all Attack cards 200% PWR", {
				{ Kind = "Shield", Pct = 2, Target = "All" },
			}, 3),
			ability("Ultimate", "Radiant Crown", "All Attack cards +50% damage for 2 turns", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.5, Turns = 2, Target = "Attack" },
			}),
			ability(
				"Signature",
				"Dawn Oath",
				"Once per battle, an Attack card that would be KO'd survives at 1 HP, invulnerable for 1 turn",
				{ { Kind = "DawnOath", Turns = 1 } }
			),
		},
	},

	-- World 4 (Stormspire Isle) cards. New cards go at the end: the leaderboards store list positions.
	{
		Id = "hayate",
		Name = "Hayate",
		Title = "Gale Dancer",
		Type = "Attack",
		Rarity = "Rare",
		Element = "Storm",
		Main = 255,
		HP = 1040,
		SPD = 128,
		Glyph = "HY",
		Accent = Color3.fromRGB(110, 220, 170),
		Abilities = {
			ability("Basic", "Wind Cut", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Cyclone", "Every 3 actions: 2 hits x 70% ATK on every enemy + this card +20% SPD for 2 turns", {
				{ Kind = "Damage", Pct = 0.7, Hits = 2, Target = "Enemies" },
				{ Kind = "Buff", Stat = "SPD", Amount = 0.2, Turns = 2, Target = "Self" },
			}, 3),
		},
	},
	{
		Id = "amane",
		Name = "Amane",
		Title = "Rain Priestess",
		Type = "Support",
		Rarity = "Epic",
		Element = "Storm",
		Main = 250,
		SPD = 105,
		Glyph = "AM",
		Accent = Color3.fromRGB(100, 160, 240),
		Abilities = {
			ability("Basic", "Rain Prayer", "Heal the most hurt Attack card 120% PWR", {
				{ Kind = "Heal", Pct = 1.2, Target = "Lowest" },
			}),
			ability("Skill", "Clearing Rain", "Every 3 actions: cleanse every Attack card + heal them 60% PWR", {
				{ Kind = "Cleanse", Amount = 2, Target = "All" },
				{ Kind = "Heal", Pct = 0.6, Target = "All" },
			}, 3),
			ability("Passive", "Calm Skies", "Every enemy -8% ATK", { { Kind = "Debuff", Stat = "ATK", Amount = 0.08, Target = "Enemies" } }),
		},
	},
	{
		Id = "tsubasa",
		Name = "Tsubasa",
		Title = "Sky Knight",
		Type = "Attack",
		Rarity = "Legendary",
		Element = "Light",
		Main = 700,
		HP = 2800,
		SPD = 112,
		Glyph = "TB",
		Accent = Color3.fromRGB(250, 210, 90),
		Abilities = {
			ability("Basic", "Lance Strike", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Thunder Dive", "Every 3 actions: 280% ATK + the target takes 10% more damage for 2 turns", {
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.1, Turns = 2 },
				{ Kind = "Damage", Pct = 2.8 },
			}, 3),
			ability("Passive", "Sky Sight", "+15% crit chance", { { Kind = "Buff", Stat = "Crit", Amount = 0.15 } }),
			ability("Ultimate", "Skyfall Lance", "5 hits x 140% ATK, ignoring DEF and Warders", {
				{ Kind = "Damage", Pct = 1.4, Hits = 5, IgnoreDef = true },
			}),
		},
	},
	{
		Id = "amaya",
		Name = "Amaya",
		Title = "Storm Oracle",
		Type = "Support",
		Rarity = "Mythic",
		Element = "Storm",
		Main = 760,
		SPD = 105,
		Glyph = "AY",
		Accent = Color3.fromRGB(255, 220, 80),
		Abilities = {
			ability("Basic", "Static Ward", "Shield the most hurt Attack card 180% PWR", {
				{ Kind = "Shield", Pct = 1.8, Target = "Lowest" },
			}),
			ability("Skill", "Stormcall", "Every 3 actions: 100% PWR to every enemy + all Attack cards +15% crit for 2 turns", {
				{ Kind = "Damage", Pct = 1, Target = "Enemies" },
				{ Kind = "Buff", Stat = "Crit", Amount = 0.15, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Ultimate", "Eye of the Storm", "All Attack cards dodge the next 2 enemy hits + 40 energy each", {
				{ Kind = "Evade", Hits = 2, Target = "All" },
				{ Kind = "Energy", Amount = 40, Target = "Attack" },
			}),
			ability("Aura", "Charged Air", "All Attack cards +10% ATK", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
}

local Cards = {}

Cards.List = list
Cards.ById = {} :: { [string]: Card }
Cards.ByRarity = {} :: { [string]: { Card } }

for _, card in list do
	assert(Cards.ById[card.Id] == nil, `Duplicate card id "{card.Id}"`)
	Cards.ById[card.Id] = card
	local pool = Cards.ByRarity[card.Rarity]
	if pool == nil then
		pool = {}
		Cards.ByRarity[card.Rarity] = pool
	end
	table.insert(pool, card)
end

function Cards.Get(id: string): Card?
	return Cards.ById[id]
end

-- The card's ability in a slot ("Basic", "Skill", "Ultimate", ...), or nil.
function Cards.Ability(card: Card, slot: string): Ability?
	for _, ability in card.Abilities do
		if ability.Slot == slot then
			return ability
		end
	end
	return nil
end

-- Stat with the star bonus applied (+5% per star, max 5 stars).
function Cards.StatWithStars(base: number, stars: number): number
	return math.floor(base * (1 + 0.05 * math.clamp(stars, 0, 5)) + 0.5)
end

-- Fusion ----------------------------------------------------------------------------------------
-- Each fusion moves a card one rarity up. A fused card has the power a card of its new rarity would
-- have (its stats scaled by the two tiers' multipliers), so rarity still decides power.

-- The card's rarity after `fusion` fusions.
function Cards.FusedRarity(card: Card, fusion: number?): string
	local index = Rarity.Index(card.Rarity) + (fusion or 0)
	return Rarity.Order[math.clamp(index, 1, #Rarity.Order)]
end

-- How many times this card can fuse in total (a Common can go all the way to Secret).
function Cards.MaxFusion(card: Card): number
	return #Rarity.Order - Rarity.Index(card.Rarity)
end

-- A stat with stars, fusion and the card's best border (Borders.luau: a small bonus) applied.
function Cards.Stat(card: Card, base: number, stars: number, fusion: number?, border: string?): number
	local scale = Rarity.Get(Cards.FusedRarity(card, fusion)).Multiplier / Rarity.Get(card.Rarity).Multiplier
	return Cards.StatWithStars(base * scale * Borders.Multiplier(border), stars)
end

-- Deck Power used for boss recommendations: Attack = ATK x 10 + HP, Support = PWR x 24.
function Cards.Power(card: Card, stars: number, fusion: number?, border: string?): number
	local main = Cards.Stat(card, card.Main, stars, fusion, border)
	if card.Type == "Attack" then
		return main * Config.Power.PerATK + Cards.Stat(card, card.HP or 0, stars, fusion, border)
	end
	return main * Config.Power.PerPWR
end

function Cards.MainLabel(card: Card): string
	return if card.Type == "Attack" then "ATK" else "PWR"
end

return Cards
