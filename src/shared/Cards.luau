--!strict
-- The 18 starter cards from the concept doc, plus the World 4 (Stormspire Isle) cards.
-- Adding a card = adding one entry here (plus art later). No other code changes.
--
-- Attack cards (front row) have ATK and HP: they deal the damage and take the enemies' hits.
-- Support cards (back row) have PWR only: no HP, never hit, never KO'd. They cast heals, shields,
-- buffs, debuffs and chip damage, and each casts its Basic once as the fight opens.
--
-- There are no card rarities: the BORDER is the tier (Borders.luau). Every card's base stats sit near
-- the same line (ATK ~500 +-10%, HP = 2 x ATK; Support PWR ~300 +-10%), and the border it wears
-- multiplies them: Base 1x, Gold 4x, Rainbow 16x, Secret 64x. Cards differ by element, abilities and how
-- often they're pulled (Weight: relative pull weight; the chase cards have the lowest).
-- Boss cards (Boss = a boss id) join the roll pool once that boss is beaten on Normal (Cards.Pool).

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
	Role: string, -- "Striker" | "Hexer" | "Mender" | "Warder": its battle job, shown on the card tooltip
	Weight: number, -- relative pull weight inside the roll pool
	Element: string, -- Elements.luau: Flame | Frost | Storm | Light | Void | Cosmic
	Main: number, -- ATK for Attack, PWR for Support
	HP: number?, -- Attack cards only
	SPD: number,
	Glyph: string, -- initials, used where the 3D art isn't drawn
	Accent: Color3, -- portrait background colour
	Image: string?, -- the card's 2D illustration ("rbxassetid://..."); cards without one show their glyph
	Abilities: { Ability },
	-- Support cards: the Slot Link passive given to the Attack card in the matching front slot (Support
	-- slot 1 links to Attack slot 1, ...). Stat is a trait stat (Traits.luau); BattleEngine applies it.
	Link: { Name: string, Stat: string, Amount: number, Text: string }?,
	Boss: string?, -- a boss card: joins the pool after this boss's first Normal clear
}

local Config = require(script.Parent.Config)
local Borders = require(script.Parent.Borders)
local Awaken = require(script.Parent.Awaken)
local Odds = require(script.Parent.Odds)

local function ability(slot: string, name: string, text: string, effects: { Effect }, every: number?): Ability
	return { Slot = slot, Name = name, Text = text, Effects = effects, Every = every }
end

local list: { Card } = {
	-- ATTACK -------------------------------------------------------------
	{
		Id = "rook",
		Name = "Titan Warder",
		Title = "Iron Knuckle Brawler",
		Type = "Attack",
		Role = "Warder",
		Weight = 8,
		Element = "Flame",
		Main = 550,
		HP = 1100,
		SPD = 95,
		Glyph = "RK",
		Accent = Color3.fromRGB(196, 120, 72),
		Abilities = {
			ability("Basic", "Bulwark Jab", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Passive", "Plated Hide", "Takes 10% less damage", { { Kind = "Buff", Stat = "Guard", Amount = 0.1 } }),
		},
	},
	{
		Id = "kaede",
		Name = "Spirit Weaver",
		Title = "Kunai Thrower",
		Type = "Attack",
		Role = "Mender",
		Weight = 10,
		Element = "Void",
		Main = 475,
		HP = 950,
		SPD = 115,
		Glyph = "KD",
		Accent = Color3.fromRGB(120, 140, 170),
		Abilities = {
			ability("Basic", "Soul Thread", "2 hits x 50% ATK on random enemies", { { Kind = "Damage", Pct = 0.5, Hits = 2, Target = "RandomEnemy" } }),
			ability("Passive", "Thread of Return", "Mends herself for 12% ATK each time she acts", { { Kind = "Heal", Pct = 0.12, Target = "Self", When = "OnAct" } }),
		},
	},
	{
		Id = "tomo",
		Name = "Solar Blade",
		Title = "Lantern Swordsman",
		Type = "Attack",
		Role = "Striker",
		Weight = 8,
		Element = "Flame",
		Main = 516,
		HP = 1032,
		SPD = 100,
		Glyph = "TM",
		Accent = Color3.fromRGB(255, 160, 70),
		Abilities = {
			ability("Basic", "Dawn Slash", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Passive", "Rising Sun Rhythm", "+15% damage while the enemy leader is above 50% HP", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.15, When = "BossAbove50" },
			}),
		},
	},
	{
		Id = "mirai",
		Name = "Limitless Sage",
		Title = "Spark Archer",
		Type = "Attack",
		Role = "Hexer",
		Weight = 1.5,
		Element = "Storm",
		Main = 469,
		HP = 938,
		SPD = 110,
		Glyph = "MR",
		Accent = Color3.fromRGB(255, 220, 90),
		Abilities = {
			ability("Basic", "Hollow Orb", "120% ATK", { { Kind = "Damage", Pct = 1.2 } }),
			ability("Skill", "Void Barrage", "Every 3 actions: 4 hits x 100% ATK on random enemies", {
				{ Kind = "Damage", Pct = 1, Hits = 4, Target = "RandomEnemy" },
			}, 3),
			ability("Ultimate", "Hollow Convergence", "900% ATK + the target takes +25% damage for 3 turns", {
				{ Kind = "Damage", Pct = 9 },
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.25, Turns = 3 },
			}),
			ability("Aura", "Limitless Field", "All Attack cards +10% ATK", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "sora",
		Name = "Cursed Prodigy",
		Title = "Storm Blade",
		Type = "Attack",
		Role = "Striker",
		Weight = 4,
		Element = "Storm",
		Main = 519,
		HP = 1038,
		SPD = 120,
		Glyph = "SI",
		Accent = Color3.fromRGB(90, 180, 255),
		Abilities = {
			ability("Basic", "Cursed Slash", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Familiar's Rush", "Every 3 actions: 3 hits x 80% ATK", {
				{ Kind = "Damage", Pct = 0.8, Hits = 3 },
			}, 3),
			ability("Passive", "Familiar's Hunger", "+20% ATK below 50% HP", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.2, When = "SelfBelow50" },
			}),
		},
	},
	{
		Id = "akane",
		Name = "Crimson Scourge",
		Title = "Crimson Lance Duelist",
		Type = "Attack",
		Role = "Hexer",
		Weight = 1.5,
		Element = "Flame",
		Main = 512,
		HP = 1024,
		SPD = 105,
		Glyph = "AK",
		Accent = Color3.fromRGB(230, 60, 70),
		Abilities = {
			ability("Basic", "Rend", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Spatial Cleave", "Every 3 actions: 250% ATK + target DEF -15% for 2 turns", {
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 2 },
				{ Kind = "Damage", Pct = 2.5 },
			}, 3),
			ability("Passive", "Malice Edge", "Crits deal 200% instead of 150%", {
				{ Kind = "Buff", Stat = "CritDamage", Amount = 0.5 },
			}),
			ability("Ultimate", "Dismantle Storm", "6 hits x 130% ATK on random enemies", {
				{ Kind = "Damage", Pct = 1.3, Hits = 6, Target = "RandomEnemy" },
			}),
			ability("Aura", "Malevolent Domain", "All Attack cards +10% ATK", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "kaito",
		Name = "Ascended Golden Warrior",
		Title = "Dragon-Eye Ronin",
		Type = "Attack",
		Role = "Striker",
		Weight = 2.5,
		Element = "Frost",
		Main = 514,
		HP = 1028,
		SPD = 110,
		Glyph = "KR",
		Accent = Color3.fromRGB(70, 200, 160),
		Abilities = {
			ability("Basic", "Proud Strike", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Radiant Surge", "Every 3 actions: 300% ATK", { { Kind = "Damage", Pct = 3 } }, 3),
			ability("Passive", "Pride Awakened", "+20% ATK below 50% HP", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.2, When = "SelfBelow50" },
			}),
			ability("Ultimate", "Golden Barrage", "8 hits x 90% ATK on random enemies", {
				{ Kind = "Damage", Pct = 0.9, Hits = 8, Target = "RandomEnemy" },
			}),
		},
	},
	{
		Id = "noa",
		Name = "Starfall Witch",
		Title = "Void Hexer",
		Type = "Attack",
		Role = "Hexer",
		Weight = 8,
		Element = "Void",
		Main = 521,
		HP = 1042,
		SPD = 100,
		Glyph = "NO",
		Accent = Color3.fromRGB(150, 110, 255),
		Abilities = {
			ability("Basic", "Shade Bolt", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Passive", "Shadow Brand", "15% chance to Burn (5% ATK per turn, 3 turns)", {
				{ Kind = "Burn", Pct = 0.05, Turns = 3, Chance = 0.15, When = "OnHit" },
			}),
		},
	},
	{
		Id = "raijen",
		Name = "Autonomous God State",
		Title = "Eclipse Sovereign",
		Type = "Attack",
		Role = "Striker",
		Weight = 1,
		Element = "Cosmic",
		Main = 512,
		HP = 1024,
		SPD = 115,
		Glyph = "RJ",
		Accent = Color3.fromRGB(40, 30, 70),
		Abilities = {
			ability("Basic", "Reflex Strike", "120% ATK", { { Kind = "Damage", Pct = 1.2 } }),
			ability("Skill", "Afterimage Cross", "Every 3 actions: 400% ATK", { { Kind = "Damage", Pct = 4 } }, 3),
			ability("Ultimate", "Unthinking Divinity", "1,500% ATK, ignores DEF and Warders", {
				{ Kind = "Damage", Pct = 15, IgnoreDef = true },
			}),
			ability("Signature", "Moving Without Thought", "Every 5th action, he acts again at once", {
				{ Kind = "Eclipse", Every = 5 },
			}),
		},
	},

	-- SUPPORT ------------------------------------------------------------
	{
		Id = "hana",
		Name = "Lotus Blossom",
		Title = "Herb Healer",
		Type = "Support",
		Role = "Mender",
		Weight = 10,
		Element = "Light",
		Link = { Name = "Blossom Guard", Stat = "Guard", Amount = 0.06, Text = "The Attack card in front takes 6% less damage" },
		Main = 300,
		SPD = 100,
		Glyph = "HN",
		Accent = Color3.fromRGB(120, 200, 110),
		Abilities = {
			ability("Basic", "Blossom Palm", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
		},
	},
	{
		Id = "goro",
		Name = "Fist of Severance",
		Title = "Shield Monk",
		Type = "Support",
		Role = "Warder",
		Weight = 4,
		Element = "Light",
		Link = { Name = "Stone Shoulder", Stat = "Guard", Amount = 0.08, Text = "The Attack card in front takes 8% less damage" },
		Main = 275,
		SPD = 90,
		Glyph = "GR",
		Accent = Color3.fromRGB(200, 170, 110),
		Abilities = {
			ability("Basic", "Pummel Pact", "50% PWR damage + shield the most hurt Attack card 100% PWR", {
				{ Kind = "Damage", Pct = 0.5 },
				{ Kind = "Shield", Pct = 1, Target = "Lowest" },
			}),
			ability("Skill", "Blood Pact", "Every 3 actions: shield all Attack cards 100% PWR + they take 15% less damage for 2 turns", {
				{ Kind = "Shield", Pct = 1, Target = "All" },
				{ Kind = "Buff", Stat = "Guard", Amount = 0.15, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Passive", "Battle Hide", "Attack cards take 5% less damage", {
				{ Kind = "Buff", Stat = "Guard", Amount = 0.05, Target = "Attack" },
			}),
		},
	},
	{
		Id = "suzu",
		Name = "Thunder Flash",
		Title = "Shrine Drummer",
		Type = "Support",
		Role = "Striker",
		Weight = 10,
		Element = "Flame",
		Link = { Name = "Flash Tempo", Stat = "ATK", Amount = 0.06, Text = "The Attack card in front +6% ATK" },
		Main = 312,
		SPD = 105,
		Glyph = "SZ",
		Accent = Color3.fromRGB(240, 110, 150),
		Abilities = {
			ability("Basic", "Flash Draw", "All Attack cards +8% ATK for 1 turn", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.08, Turns = 1, Target = "Attack" },
			}),
			ability("Passive", "Flash Cadence", "+5 energy to a random card with an Ultimate each time she acts", {
				{ Kind = "Energy", Amount = 5, Target = "Random", When = "OnAct" },
			}),
		},
	},
	{
		Id = "ibuki",
		Name = "Phantom Blade",
		Title = "Fog Weaver",
		Type = "Support",
		Role = "Warder",
		Weight = 8,
		Element = "Frost",
		Link = { Name = "Shadow Cloak", Stat = "SPD", Amount = 0.06, Text = "The Attack card in front +6% SPD" },
		Main = 288,
		SPD = 100,
		Glyph = "IB",
		Accent = Color3.fromRGB(150, 170, 200),
		Abilities = {
			ability("Basic", "Hidden Blade", "60% PWR damage + target -10% ATK for 1 turn", {
				{ Kind = "Damage", Pct = 0.6 },
				{ Kind = "Debuff", Stat = "ATK", Amount = 0.1, Turns = 1 },
			}),
			ability("Passive", "Zero Presence", "The first enemy hit on each Attack card misses", {
				{ Kind = "Evade", Hits = 1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "yume",
		Name = "Dream Reaper",
		Title = "Moonlight Priestess",
		Type = "Support",
		Role = "Mender",
		Weight = 1.5,
		Element = "Frost",
		Link = { Name = "Mirror Sight", Stat = "Crit", Amount = 0.06, Text = "The Attack card in front +6% crit chance" },
		Main = 308,
		SPD = 110,
		Glyph = "YA",
		Accent = Color3.fromRGB(150, 200, 255),
		Abilities = {
			ability("Basic", "Reflected Mercy", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
			ability("Skill", "Mirror Realm", "Every 3 actions: heal all Attack cards 120% PWR + cleanse 1 debuff + every enemy -10% SPD for 2 turns", {
				{ Kind = "Heal", Pct = 1.2, Target = "All" },
				{ Kind = "Cleanse", Amount = 1, Target = "All" },
				{ Kind = "Debuff", Stat = "SPD", Amount = 0.1, Turns = 2, Target = "Enemies" },
			}, 3),
			ability("Ultimate", "Total Hypnosis", "Heal all Attack cards 200% PWR + every enemy -20% ATK for 3 turns", {
				{ Kind = "Heal", Pct = 2, Target = "All" },
				{ Kind = "Debuff", Stat = "ATK", Amount = 0.2, Turns = 3, Target = "Enemies" },
			}),
			ability("Aura", "Mirage Veil", "Every enemy -8% SPD", { { Kind = "Debuff", Stat = "SPD", Amount = 0.08, Target = "Enemies" } }),
		},
	},
	{
		Id = "tetsu",
		Name = "Iron Bastion",
		Title = "Iron Wall Guardian",
		Type = "Support",
		Role = "Warder",
		Weight = 6,
		Element = "Void",
		Link = { Name = "Iron Back", Stat = "Guard", Amount = 0.1, Text = "The Attack card in front takes 10% less damage" },
		Main = 292,
		SPD = 85,
		Glyph = "TS",
		Accent = Color3.fromRGB(140, 150, 165),
		Abilities = {
			ability("Basic", "Sand Shield", "Shield the most hurt Attack card 150% PWR", {
				{ Kind = "Shield", Pct = 1.5, Target = "Lowest" },
			}),
			ability("Skill", "Iron Sand Wall", "Every 3 actions: shield all Attack cards 100% PWR + they take 20% less damage for 2 turns", {
				{ Kind = "Shield", Pct = 1, Target = "All" },
				{ Kind = "Buff", Stat = "Guard", Amount = 0.2, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Passive", "Floating Wall", "Attack cards take 10% less damage", {
				{ Kind = "Buff", Stat = "Guard", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	{
		Id = "luna",
		Name = "Celestial Strategist",
		Title = "Light Mender",
		Type = "Support",
		Role = "Mender",
		Weight = 10,
		Element = "Light",
		Link = { Name = "Wing Chart", Stat = "CritDamage", Amount = 0.2, Text = "The Attack card in front +20% crit damage" },
		Main = 307,
		SPD = 115,
		Glyph = "LM",
		Accent = Color3.fromRGB(110, 140, 255),
		Abilities = {
			ability("Basic", "Butterfly Mend", "Heal the most hurt Attack card 100% PWR", {
				{ Kind = "Heal", Pct = 1, Target = "Lowest" },
			}),
		},
	},
	{
		Id = "orin",
		Name = "Time Weaver",
		Title = "Void Mender",
		Type = "Support",
		Role = "Mender",
		Weight = 2.5,
		Element = "Void",
		Link = { Name = "Borrowed Time", Stat = "StartEnergy", Amount = 0.25, Text = "The Attack card in front starts with 25 Ultimate energy" },
		Main = 308,
		SPD = 100,
		Glyph = "OR",
		Accent = Color3.fromRGB(90, 220, 220),
		Abilities = {
			ability("Basic", "Gentle Gears", "Heal all Attack cards 60% PWR", {
				{ Kind = "Heal", Pct = 0.6, Target = "All" },
			}),
			ability("Skill", "Quickened Gears", "Every 3 actions: every card +20% SPD for 2 turns", {
				{ Kind = "Buff", Stat = "SPD", Amount = 0.2, Turns = 2, Target = "All" },
			}, 3),
			ability("Passive", "Slow Clock", "Every enemy -15% SPD", { { Kind = "Debuff", Stat = "SPD", Amount = 0.15, Target = "Enemies" } }),
			ability("Ultimate", "Rewind", "Revive all KO'd Attack cards at 40% HP + heal them 200% PWR", {
				{ Kind = "Revive", Pct = 0.4 },
				{ Kind = "Heal", Pct = 2, Target = "All" },
			}),
		},
	},
	{
		Id = "aurelia",
		Name = "Nine-Tails Sovereign",
		Title = "Dawn Empress",
		Type = "Support",
		Role = "Mender",
		Weight = 1,
		Element = "Cosmic",
		Link = { Name = "Fox Mantle Link", Stat = "ATK", Amount = 0.12, Text = "The Attack card in front +12% ATK" },
		Main = 308,
		SPD = 110,
		Glyph = "AU",
		Accent = Color3.fromRGB(255, 214, 140),
		Abilities = {
			ability("Basic", "Foxfire Mend", "Heal all Attack cards 80% PWR", {
				{ Kind = "Heal", Pct = 0.8, Target = "All" },
			}),
			ability("Skill", "Fox Mantle", "Every 3 actions: shield all Attack cards 200% PWR", {
				{ Kind = "Shield", Pct = 2, Target = "All" },
			}, 3),
			ability("Ultimate", "Beast Unsealed", "All Attack cards +50% damage for 2 turns", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.5, Turns = 2, Target = "Attack" },
			}),
			ability(
				"Signature",
				"Seal's Last Gate",
				"Once per battle, an Attack card that would be KO'd survives at 1 HP, invulnerable for 1 turn",
				{ { Kind = "DawnOath", Turns = 1 } }
			),
		},
	},

	-- World 4 (Stormspire Isle) cards. New cards go at the end: the leaderboards store list positions.
	{
		Id = "hayate",
		Name = "Infernal Warden",
		Title = "Gale Dancer",
		Type = "Attack",
		Role = "Striker",
		Weight = 6,
		Element = "Storm",
		Main = 490,
		HP = 980,
		SPD = 128,
		Glyph = "HY",
		Accent = Color3.fromRGB(110, 220, 170),
		Abilities = {
			ability("Basic", "Scorching Cut", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Cinder Vow", "Every 3 actions: 2 hits x 70% ATK on every enemy, this card +20% SPD for 2 turns, and a 30% ATK shield on every Attack card", {
				{ Kind = "Damage", Pct = 0.7, Hits = 2, Target = "Enemies" },
				{ Kind = "Buff", Stat = "SPD", Amount = 0.2, Turns = 2, Target = "Self" },
				{ Kind = "Shield", Pct = 0.3, Target = "Attack" },
			}, 3),
		},
	},
	{
		Id = "amane",
		Name = "Shadow Puppeteer",
		Title = "Rain Priestess",
		Type = "Support",
		Role = "Mender",
		Weight = 6,
		Element = "Storm",
		Link = { Name = "Thread Step", Stat = "SPD", Amount = 0.08, Text = "The Attack card in front +8% SPD" },
		Main = 298,
		SPD = 105,
		Glyph = "AM",
		Accent = Color3.fromRGB(100, 160, 240),
		Abilities = {
			ability("Basic", "Puppet Mend", "Heal the most hurt Attack card 120% PWR", {
				{ Kind = "Heal", Pct = 1.2, Target = "Lowest" },
			}),
			ability("Skill", "Thread Cut", "Every 3 actions: cleanse every Attack card + heal them 60% PWR", {
				{ Kind = "Cleanse", Amount = 2, Target = "All" },
				{ Kind = "Heal", Pct = 0.6, Target = "All" },
			}, 3),
			ability("Passive", "Cursed Strings", "Every enemy -8% ATK", { { Kind = "Debuff", Stat = "ATK", Amount = 0.08, Target = "Enemies" } }),
		},
	},
	{
		Id = "tsubasa",
		Name = "Lunar Reaper",
		Title = "Sky Knight",
		Type = "Attack",
		Role = "Hexer",
		Weight = 2.5,
		Element = "Light",
		Main = 500,
		HP = 1000,
		SPD = 112,
		Glyph = "TB",
		Accent = Color3.fromRGB(250, 210, 90),
		Abilities = {
			ability("Basic", "Crescent Slash", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Soul Cleave", "Every 3 actions: 280% ATK + the target takes 10% more damage for 2 turns", {
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.1, Turns = 2 },
				{ Kind = "Damage", Pct = 2.8 },
			}, 3),
			ability("Passive", "Reaper's Sight", "+15% crit chance", { { Kind = "Buff", Stat = "Crit", Amount = 0.15 } }),
			ability("Ultimate", "Moonfall Cleave", "5 hits x 140% ATK, ignoring DEF and Warders", {
				{ Kind = "Damage", Pct = 1.4, Hits = 5, IgnoreDef = true },
			}),
		},
	},
	{
		Id = "amaya",
		Name = "Storm Oracle",
		Title = "Storm Warder",
		Type = "Support",
		Role = "Warder",
		Weight = 4,
		Element = "Storm",
		Link = { Name = "Live Current Link", Stat = "ATK", Amount = 0.1, Text = "The Attack card in front +10% ATK" },
		Main = 317,
		SPD = 105,
		Glyph = "AY",
		Accent = Color3.fromRGB(255, 220, 80),
		Abilities = {
			ability("Basic", "Voltage Ward", "Shield the most hurt Attack card 180% PWR", {
				{ Kind = "Shield", Pct = 1.8, Target = "Lowest" },
			}),
			ability("Skill", "Arc Surge", "Every 3 actions: 100% PWR to every enemy + all Attack cards +15% crit for 2 turns", {
				{ Kind = "Damage", Pct = 1, Target = "Enemies" },
				{ Kind = "Buff", Stat = "Crit", Amount = 0.15, Turns = 2, Target = "Attack" },
			}, 3),
			ability("Passive", "Live Current", "All Attack cards +10% ATK", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
			}),
		},
	},
	-- BOSS CARDS: unlocked into the pool by each boss's first Normal clear -----------------------
	{
		Id = "kurogane_card",
		Name = "Tailed Beast Calamity",
		Title = "The Ember Fox",
		Type = "Attack",
		Role = "Hexer",
		Weight = 0.9,
		Boss = "kurogane",
		Element = "Flame",
		Main = 550,
		HP = 1100,
		SPD = 102,
		Glyph = "KG",
		Accent = Color3.fromRGB(230, 90, 40),
		Abilities = {
			ability("Basic", "Magma Claw", "110% ATK", { { Kind = "Damage", Pct = 1.1 } }),
			ability("Skill", "Forge Brand", "Every 3 actions: 220% ATK and burns for 10% a turn", {
				{ Kind = "Damage", Pct = 2.2 },
				{ Kind = "Burn", Pct = 0.1, Turns = 3 },
			}, 3),
			ability("Ultimate", "Fox's Slagfall", "6 hits x 80% ATK on random enemies", {
				{ Kind = "Damage", Pct = 0.8, Hits = 6, Target = "RandomEnemy" },
			}),
		},
	},
	{
		Id = "rimeveil_card",
		Name = "Galactic Emperor",
		Title = "The Frost Tyrant",
		Type = "Attack",
		Role = "Hexer",
		Weight = 0.85,
		Boss = "rimeveil",
		Element = "Frost",
		Main = 540,
		HP = 1080,
		SPD = 98,
		Glyph = "RV",
		Accent = Color3.fromRGB(110, 190, 255),
		Abilities = {
			ability("Basic", "Rime Lance", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Stilled Hour", "Every 4 actions: 250% ATK, enemies -15% SPD for 2 turns", {
				{ Kind = "Damage", Pct = 2.5 },
				{ Kind = "Debuff", Stat = "SPD", Amount = 0.15, Turns = 2, Target = "Enemies" },
			}, 4),
			ability("Passive", "Crystal Wall", "Takes 6% less damage", { { Kind = "Buff", Stat = "Guard", Amount = 0.06 } }),
			ability("Ultimate", "Crystal Sovereignty", "350% ATK, ignores DEF", {
				{ Kind = "Damage", Pct = 3.5, IgnoreDef = true },
			}),
		},
	},
	{
		Id = "vex_card",
		Name = "Mirror Flower Overlord",
		Title = "The Hollow Betrayer",
		Type = "Attack",
		Role = "Hexer",
		Weight = 0.8,
		Boss = "vex",
		Element = "Void",
		Main = 555,
		HP = 1110,
		SPD = 104,
		Glyph = "VX",
		Accent = Color3.fromRGB(150, 70, 230),
		Abilities = {
			ability("Basic", "Void Maw", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Rend the Guard", "Every 3 actions: 180% ATK, enemy DEF -15% for 3 turns", {
				{ Kind = "Damage", Pct = 1.8 },
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 3 },
			}, 3),
			ability("Ultimate", "Devour All", "4 hits x 120% ATK, enemies take +15% damage", {
				{ Kind = "Damage", Pct = 1.2, Hits = 4 },
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.15, Turns = 3, Target = "Enemies" },
			}),
		},
	},
	{
		Id = "tenrai_card",
		Name = "Demon Progenitor",
		Title = "The Thousand-Year Storm",
		Type = "Attack",
		Role = "Striker",
		Weight = 0.6,
		Boss = "tenrai",
		Element = "Storm",
		Main = 560,
		HP = 1120,
		SPD = 110,
		Glyph = "TR",
		Accent = Color3.fromRGB(255, 220, 80),
		Abilities = {
			ability("Basic", "Static Fist", "100% ATK", { { Kind = "Damage", Pct = 1 } }),
			ability("Skill", "Forked Storm", "Every 3 actions: 4 hits x 60% ATK on random enemies", {
				{ Kind = "Damage", Pct = 0.6, Hits = 4, Target = "RandomEnemy" },
			}, 3),
			ability("Ultimate", "Judgment Bolt", "300% ATK to every enemy", {
				{ Kind = "Damage", Pct = 3, Target = "Enemies" },
			}),
		},
	},
}

local Cards = {}

Cards.List = list
Cards.ById = {} :: { [string]: Card }

for _, card in list do
	assert(Cards.ById[card.Id] == nil, `Duplicate card id "{card.Id}"`)
	Cards.ById[card.Id] = card
end

function Cards.Get(id: string): Card?
	return Cards.ById[id]
end

-- Rarer cards hit harder at the same border (the user's call, 2026-10-24): a card's stats scale by
-- (CommonWeight / its Weight) ^ Exponent, so a common card (Weight 10) is 1x, a Weight 1 card about
-- 1.41x and the boss cards (Weight 0.6-1) up to 1.53x. Still far under the next border's 4x, with
-- stars and Awakening on top (1.53 x 1.375 = 2.1x), so the border always wins.
Cards.RarityScale = { CommonWeight = 10, Exponent = 0.15 }

function Cards.Scale(card: Card): number
	local s = Cards.RarityScale
	return (s.CommonWeight / math.max(0.01, card.Weight)) ^ s.Exponent
end

-- The roll pool: every card, except boss cards whose boss hasn't been beaten on Normal yet
-- (`cleared` = Progress.Cleared, keyed "boss:Normal").
function Cards.Pool(cleared: { [string]: boolean }?): { Card }
	local pool = {}
	for _, card in list do
		if card.Boss == nil or (cleared ~= nil and cleared[`{card.Boss}:Normal`] == true) then
			table.insert(pool, card)
		end
	end
	return pool
end

-- The weekly Featured Card: one of the rare pool cards (Weight FeaturedMaxWeight or less, no boss card)
-- weighs x FeaturedBoost for a week (Monday 00:00 UTC to Monday), the same on every server: picked by a
-- seeded hash of the week number. Its border odds don't change, so it's simply easier to pull.
Cards.FeaturedBoost = 3
Cards.FeaturedMaxWeight = 2
local WEEK = 604800
local MONDAY = 345600 -- the Unix epoch was a Thursday; +4 days is the first Monday 00:00 UTC

function Cards.WeekAt(t: number): number
	return math.floor((t - MONDAY) / WEEK)
end

-- When the week of `t` ends (for countdowns).
function Cards.WeekEnds(t: number): number
	return (Cards.WeekAt(t) + 1) * WEEK + MONDAY
end

function Cards.FeaturedAt(t: number): string
	local candidates = {}
	for _, card in list do
		if card.Boss == nil and card.Weight <= Cards.FeaturedMaxWeight then
			table.insert(candidates, card.Id)
		end
	end
	local seed = (Cards.WeekAt(t) * 7919 + 104729) % 2147483647
	for _ = 1, 3 do
		seed = (seed * 48271 + 11) % 2147483647
	end
	return candidates[seed % #candidates + 1]
end

-- Each card's chance (0-1) to be the card of a pull, in `pool`. `element` (infused packs) weighs that
-- element's cards x `elementWeight`; `featured` (the week's Featured Card) weighs x FeaturedBoost.
function Cards.PullChances(pool: { Card }, element: string?, elementWeight: number?, featured: string?): { [string]: number }
	local function weight(card: Card): number
		return card.Weight
			* (if element and card.Element == element then elementWeight or 1 else 1)
			* (if featured and card.Id == featured then Cards.FeaturedBoost else 1)
	end
	local total = 0
	for _, card in pool do
		total += weight(card)
	end
	local chances = {}
	for _, card in pool do
		chances[card.Id] = weight(card) / total
	end
	return chances
end

-- A card's rarity number at one border: how many pulls one of it takes on average (1 / (its pull chance
-- x the border's chance)) at 1x luck, over the full pool (boss cards included), so the number is the
-- same for everyone. RawRarity is the exact figure; Rarity snaps it to a round number (Odds.Round:
-- 12, 50, 7,500, 6,000,000) for display: a plain number, never "1 in" (the user's call).
local fullChances: { [string]: number }? = nil
function Cards.RawRarity(cardId: string, border: string?): number
	if fullChances == nil then
		fullChances = Cards.PullChances(list)
	end
	local pull = (fullChances :: { [string]: number })[cardId] or 0
	local chance = Borders.Chances()[border or "Normal"] or 0
	if pull <= 0 or chance <= 0 then
		return 0
	end
	return 1 / (pull * chance)
end

function Cards.Rarity(cardId: string, border: string?): number
	local raw = Cards.RawRarity(cardId, border)
	return if raw > 0 then math.max(1, Odds.Round(raw)) else 0
end

-- The boss card a boss unlocks, if any.
function Cards.ForBoss(bossId: string): Card?
	for _, card in list do
		if card.Boss == bossId then
			return card
		end
	end
	return nil
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

-- A stat with stars, the border's tier multiplier (1x / 4x / 16x / 64x), the card's rarity scale
-- (Cards.Scale) and the Awakening node (node 1: +10%). The border decides power: the rarest card's scale,
-- 5 stars and node 1 together are about 2.1x, far under the next border's 4x.
function Cards.Stat(card: Card, base: number, stars: number, border: string?, awaken: number?): number
	return Cards.StatWithStars(base * Borders.Multiplier(border) * Cards.Scale(card) * Awaken.StatMultiplier(awaken), stars)
end

-- Deck Power used for boss recommendations: Attack = ATK x 10 + HP, Support = PWR x 24.
function Cards.Power(card: Card, stars: number, border: string?, awaken: number?): number
	local main = Cards.Stat(card, card.Main, stars, border, awaken)
	if card.Type == "Attack" then
		return main * Config.Power.PerATK + Cards.Stat(card, card.HP or 0, stars, border, awaken)
	end
	return main * Config.Power.PerPWR
end

-- Deck Cost (the Cost Challenge): by the border the card wears (Borders.Cost: 2 / 4 / 6 / 8).
function Cards.Cost(border: string?): number
	return Borders.Get(border).Cost
end

function Cards.MainLabel(card: Card): string
	return if card.Type == "Attack" then "ATK" else "PWR"
end

return Cards
