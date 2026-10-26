--!strict
-- The 18 starter cards from the concept doc, plus the World 4 (Stormspire Isle) cards.
-- Adding a card = adding one entry here (plus art later). No other code changes.
--
-- Attack cards (front row) have ATK and HP: they deal the damage and take the enemies' hits.
-- Support cards (back row) are passive modifiers: no damage, HP or action speed. Each attaches
-- only to the matching Attack slot; its Support data declares strength, trigger and battle limit.
--
-- There are no card rarities: the BORDER is the tier (Borders.luau). Every card's base stats sit near
-- the same line (ATK ~500 +-10%, HP = 2 x ATK), and the border an Attack card wears
-- multiplies them: Base 1x, Gold 4x, Rainbow 16x, Secret 64x. Cards differ by element, abilities and how
-- often they're pulled (Weight: relative pull weight; the chase cards have the lowest).
-- Boss cards (Boss = a boss id) join the roll pool once that boss is beaten on Normal (Cards.Pool).

-- What an ability does in battle, built from the effect library (BattleEngine runs them).
-- Pct is a share of the Attack card's ATK. Support uses its separate passive definition.
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
-- Trigger bundles: OnEntry | OnHit | OnCrit | OnKill | OnAct | BelowHalf. Chance and Limit apply to the whole bundle.
-- Text tokens {pN}/{aN}/{tN} read Pct/Amount/Turns from effect N; CardInfo resolves them.
-- Bleed shares the damage-over-time scheduler with Burn, while retaining its own status. HealingLock blocks HP recovery.
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
	MaxHP: boolean?,
	IgnoreDef: boolean?,
	ResetSkill: boolean?,
	Every: number?,
}

export type Ability = {
	Slot: string, -- Basic | Skill | Passive | Ultimate | Aura | Signature
	Name: string,
	Text: string,
	Effects: { Effect },
	Every: number?, -- Skill cooldown, or a passive action interval
	Trigger: string?,
	Chance: number?,
	Limit: number?,
}

export type Card = {
	Id: string,
	Name: string,
	Title: string,
	Type: string, -- "Attack" | "Support"
	Role: string, -- "Striker" | "Hexer" | "Mender" | "Warder": its battle job, shown on the card tooltip
	Weight: number, -- relative pull weight inside the roll pool
	Element: string, -- Elements.luau: Flame | Frost | Storm | Light | Void | Cosmic
	Main: number, -- ATK for Attack, 0 for passive Support
	HP: number?, -- Attack cards only
	SPD: number,
	Glyph: string, -- initials, used where the 3D art isn't drawn
	Accent: Color3, -- portrait background colour
	Image: string?, -- the card's 2D illustration ("rbxassetid://..."); cards without one show their glyph
	Abilities: { Ability },
	Support: { Name: string, Kind: string, Amount: number, Uses: number?, Threshold: number?, Stat: string?, Trigger: string, Text: string, Chance: number?, Penalty: number?, Turns: number?, Burn: number?, Fixed: boolean? }?,
	-- Support cards: the Slot Link passive given to the Attack card in the matching front slot (Support
	-- slot 1 links to Attack slot 1, ...). Stat is a trait stat (Traits.luau); BattleEngine applies it.
	Link: { Name: string, Stat: string, Amount: number, Text: string }?,
	Boss: string?, -- a boss card: joins the pool after this boss's first Normal clear
}

local Config = require(script.Parent.Config)
local Borders = require(script.Parent.Borders)
local Awaken = require(script.Parent.Awaken)
local Odds = require(script.Parent.Odds)

local function ability(slot: string, name: string, text: string, effects: { Effect }, every: number?, rules: { Trigger: string?, Chance: number?, Limit: number? }?): Ability
	return { Slot = slot, Name = name, Text = text, Effects = effects, Every = every,
		Trigger = if rules then rules.Trigger else nil, Chance = if rules then rules.Chance else nil,
		Limit = if rules then rules.Limit else nil }
end

local list: { Card } = {
	-- ATTACK -------------------------------------------------------------
	{
		Id = "rook",
		Name = "Titan Warder",
		Title = "Armored Colossus",
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
			ability("Basic", "Colossus Fist", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Wallbreaker Rush", "Draw enemy attacks for {t1} turns, then charge for {p2} DMG.", {
				{ Kind = "Taunt", Turns = 2 },
				{ Kind = "Damage", Pct = 1.6 },
			}, 3),
			ability("Passive", "Armored Advance", "On entry, harden this card's armor to reduce incoming DMG by {a1}, but lose {a2} attack speed.", {
				{ Kind = "Buff", Stat = "Guard", Amount = 0.15 },
				{ Kind = "Buff", Stat = "SPD", Amount = -0.1 },
			}, nil, { Trigger = "OnEntry" }),
			ability("Ultimate", "Crushing Footfall", "Crush every enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1.8, Target = "Enemies" },
			}),
		},
	},
	{
		Id = "kaede",
		Name = "Spirit Weaver",
		Title = "Soul-Thread Medic",
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
			ability("Basic", "Spirit Thread", "Send out two soul threads, each dealing {p1} DMG to a random enemy.", {
				{ Kind = "Damage", Pct = 0.5, Hits = 2, Target = "RandomEnemy" },
			}),
			ability("Skill", "Soul Rejection", "Weave a shield worth {p1} DMG around every ally.", {
				{ Kind = "Shield", Pct = 0.8, Target = "Attack" },
			}, 3),
			ability("Passive", "Thread of Renewal", "After attacking, a {chance} chance to mend this card for {p1} DMG and remove a Burn or Freeze.", {
				{ Kind = "Heal", Pct = 0.15, Target = "Self" },
				{ Kind = "Cleanse", Amount = 1, Target = "Self" },
			}, nil, { Trigger = "OnAct", Chance = 0.25, Limit = 5 }),
		},
	},
	{
		Id = "tomo",
		Name = "Solar Blade",
		Title = "Dawn Swordsman",
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
			ability("Basic", "Sunlit Edge", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Flowing Sun", "Cut through an enemy twice, dealing {p1} DMG with each slash.", {
				{ Kind = "Damage", Pct = 0.9, Hits = 2 },
			}, 3),
			ability("Passive", "Ember Breathing", "Critical hits ignite the enemy with Burn, dealing {p1} DMG each turn for {t1} turns.", {
				{ Kind = "Burn", Pct = 0.1, Turns = 3 },
			}, nil, { Trigger = "OnCrit" }),
			ability("Ultimate", "Dance of Dawn", "Unleash a {p1} DMG sun slash and inflict Burn for {p2} DMG each turn for {t2} turns.", {
				{ Kind = "Damage", Pct = 4 },
				{ Kind = "Burn", Pct = 0.05, Turns = 3 },
			}),
		},
	},
	{
		Id = "mirai",
		Name = "Limitless Sage",
		Title = "The Untouchable",
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
			ability("Basic", "Repulsion Palm", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1.2 },
			}),
			ability("Skill", "Infinity Collapse", "Fold space around random enemies with four strikes, each dealing {p1} DMG.", {
				{ Kind = "Damage", Pct = 1, Hits = 4, Target = "RandomEnemy" },
			}, 3),
			ability("Ultimate", "Void Convergence", "Collapse the void for {p1} DMG. The enemy takes {a2} more DMG for {t2} turns.", {
				{ Kind = "Damage", Pct = 9 },
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.25, Turns = 3 },
			}),
			ability("Aura", "Infinite Pressure", "On entry, grant every ally {a1} DMG. Maintaining the field costs this card {a2} attack speed.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
				{ Kind = "Buff", Stat = "SPD", Amount = -0.1, Target = "Self" },
			}, nil, { Trigger = "OnEntry" }),
		},
	},
	{
		Id = "sora",
		Name = "Cursed Prodigy",
		Title = "Shadow Familiar Tamer",
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
			ability("Basic", "Cursed Edge", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Shadow Familiar Rush", "A shadow familiar tears into the enemy three times for {p1} DMG each.", {
				{ Kind = "Damage", Pct = 0.8, Hits = 3 },
			}, 3),
			ability("Passive", "Ravenous Pact", "When this card defeats an opponent, its familiar grants {a1} DMG for {t1} turns, but this card takes {a2} more DMG for {t2} turns.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.25, Turns = 3 },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1, Turns = 3 },
			}, nil, { Trigger = "OnKill", Limit = 3 }),
			ability("Ultimate", "Chimera Procession", "Release three familiars at random enemies, each dealing {p1} DMG.", {
				{ Kind = "Damage", Pct = 0.8, Hits = 3, Target = "RandomEnemy" },
			}),
		},
	},
	{
		Id = "akane",
		Name = "Crimson Scourge",
		Title = "King of Malice",
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
			ability("Basic", "Rending Cut", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Spatial Severance", "Cut through the enemy's defenses by {a1} for {t1} turns, then deal {p2} DMG.", {
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 2 },
				{ Kind = "Damage", Pct = 2.5 },
			}, 3),
			ability("Passive", "Cursed Incision", "Critical hits carve a Bleed into the enemy, dealing {p1} DMG each turn for {t1} turns.", {
				{ Kind = "Bleed", Pct = 0.15, Turns = 3 },
			}, nil, { Trigger = "OnCrit" }),
			ability("Ultimate", "Malevolent Barrage", "Rain down six cursed slashes on random enemies, each dealing {p1} DMG.", {
				{ Kind = "Damage", Pct = 1.3, Hits = 6, Target = "RandomEnemy" },
			}),
			ability("Aura", "Shrine of Malice", "On entry, every ally gains {a1} DMG, but the shrine makes them take {a2} more DMG.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1, Target = "Attack" },
			}, nil, { Trigger = "OnEntry" }),
		},
	},
	{
		Id = "kaito",
		Name = "Ascended Golden Warrior",
		Title = "Prince of Pride",
		Type = "Attack",
		Role = "Striker",
		Weight = 2.5,
		Element = "Frost",
		Main = 514,
		HP = 1028,
		SPD = 110,
		Glyph = "KR",
		Accent = Color3.fromRGB(255, 200, 70),
		Abilities = {
			ability("Basic", "Royal Strike", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Pride Breaker", "Unleash a royal Ki blast for {p1} DMG.", {
				{ Kind = "Damage", Pct = 3 },
			}, 3),
			ability("Passive", "Unbroken Pride", "When below 50% HP, awaken golden Ki for {a1} DMG. Reckless pride makes this card take {a2} more DMG.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.25 },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1 },
			}, nil, { Trigger = "BelowHalf", Limit = 1 }),
			ability("Ultimate", "Golden Ki Barrage", "Fire eight Ki blasts at random enemies for {p1} DMG each.", {
				{ Kind = "Damage", Pct = 0.9, Hits = 8, Target = "RandomEnemy" },
			}),
		},
	},
	{
		Id = "noa",
		Name = "Starfall Witch",
		Title = "Mistress of Hounds",
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
			ability("Basic", "Shadow Fang", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Hound Pursuit", "Three shadow hounds pursue random enemies, each dealing {p1} DMG.", {
				{ Kind = "Damage", Pct = 0.7, Hits = 3, Target = "RandomEnemy" },
			}, 3),
			ability("Passive", "Shadow Bind", "On a hit, a {chance} chance for the hounds to Weaken the enemy by {a1} for {t1} turns.", {
				{ Kind = "Debuff", Stat = "ATK", Amount = 0.15, Turns = 2 },
			}, nil, { Trigger = "OnHit", Chance = 0.2 }),
			ability("Ultimate", "Chimera Garden", "Drown the enemy in shadows, lowering defense by {a1} for {t1} turns before dealing {p2} DMG.", {
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 3 },
				{ Kind = "Damage", Pct = 3.5 },
			}),
		},
	},
	{
		Id = "raijen",
		Name = "Autonomous God State",
		Title = "The Silver Instinct",
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
			ability("Basic", "Instinct Strike", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1.2 },
			}),
			ability("Skill", "Afterimage Assault", "Disappear beyond sight, then strike for {p1} DMG.", {
				{ Kind = "Damage", Pct = 4 },
			}, 3),
			ability("Ultimate", "Limit-Breaking Fist", "Break through defense and protection with a {p1} DMG strike.", {
				{ Kind = "Damage", Pct = 15, IgnoreDef = true },
			}),
			ability("Signature", "Perfect Instinct", "After every 5 attacks, a {chance} chance to land a {p1} DMG afterimage strike and evade the next enemy hit.", {
				{ Kind = "Damage", Pct = 1.25 },
				{ Kind = "Evade", Hits = 1, Target = "Self" },
			}, 5, { Trigger = "OnAct", Chance = 0.5 }),
		},
	},

	-- SUPPORT ------------------------------------------------------------
	{
		Id = "hana",
		Name = "Lotus Blossom",
		Title = "Hundred-Healing Medic",
		Type = "Support",
		Role = "Mender",
		Weight = 10,
		Element = "Light",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "HN",
		Accent = Color3.fromRGB(120, 200, 110),
		Support = {
			Name = "Hundred-Petal Renewal",
			Kind = "LowHeal",
			Trigger = "BelowHalf",
			Amount = 0.2,
			Threshold = 0.5,
			Uses = 1,
			Turns = 2,
			Text = "When below {threshold} HP, the supported card cleanses Burn and Freeze and recovers {amount} of its max HP. It cannot be healed for {turns} turns.",
		},
		Abilities = {
			ability("Passive", "Hundred-Petal Renewal", "When below {threshold} HP, the supported card cleanses Burn and Freeze and recovers {amount} of its max HP. It cannot be healed for {turns} turns.", {  }),
		},
	},
	{
		Id = "goro",
		Name = "Fist of Severance",
		Title = "Blood-Pact Brawler",
		Type = "Support",
		Role = "Warder",
		Weight = 4,
		Element = "Light",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "GR",
		Accent = Color3.fromRGB(200, 170, 110),
		Support = {
			Name = "Severing Counter",
			Kind = "Counter",
			Trigger = "OnDamaged",
			Amount = 0.15,
			Chance = 0.25,
			Uses = 4,
			Text = "After an enemy attack, the supported card has a {chance} chance to return {amount} of the DMG taken as a counterstrike.",
		},
		Abilities = {
			ability("Passive", "Severing Counter", "After an enemy attack, the supported card has a {chance} chance to return {amount} of the DMG taken as a counterstrike.", {  }),
		},
	},
	{
		Id = "suzu",
		Name = "Thunder Flash",
		Title = "Sleeping Lightning",
		Type = "Support",
		Role = "Striker",
		Weight = 10,
		Element = "Storm",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "SZ",
		Accent = Color3.fromRGB(255, 210, 70),
		Support = {
			Name = "Thunder Breathing",
			Kind = "Haste",
			Trigger = "OnEntry",
			Amount = 0.2,
			Penalty = 0.1,
			Turns = 3,
			Uses = 1,
			Text = "On entry, the supported card gains {amount} attack speed for {turns} turns. Lightning-fast cuts deal {penalty} less DMG during that time.",
		},
		Abilities = {
			ability("Passive", "Thunder Breathing", "On entry, the supported card gains {amount} attack speed for {turns} turns. Lightning-fast cuts deal {penalty} less DMG during that time.", {  }),
		},
	},
	{
		Id = "ibuki",
		Name = "Phantom Blade",
		Title = "Cloud-Step Assassin",
		Type = "Support",
		Role = "Warder",
		Weight = 8,
		Element = "Frost",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "IB",
		Accent = Color3.fromRGB(150, 170, 200),
		Support = {
			Name = "Cloud-Step Feint",
			Kind = "Dodge",
			Trigger = "OnAttacked",
			Amount = 0.1,
			Penalty = 0.1,
			Turns = 1,
			Uses = 4,
			Text = "When attacked, the supported card has a {amount} chance to evade. Each successful feint inflicts Weaken, reducing the attacker's DMG by {penalty} for {turns} turn.",
		},
		Abilities = {
			ability("Passive", "Cloud-Step Feint", "When attacked, the supported card has a {amount} chance to evade. Each successful feint inflicts Weaken, reducing the attacker's DMG by {penalty} for {turns} turn.", {  }),
		},
	},
	{
		Id = "yume",
		Name = "Dream Reaper",
		Title = "Mirror of Hypnosis",
		Type = "Support",
		Role = "Mender",
		Weight = 1.5,
		Element = "Frost",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "YA",
		Accent = Color3.fromRGB(150, 200, 255),
		Support = {
			Name = "Illusion of Crows",
			Kind = "Weaken",
			Trigger = "OnSkillHit",
			Amount = 0.15,
			Chance = 0.25,
			Burn = 0.1,
			Turns = 2,
			Uses = 4,
			Text = "The supported card's Skill or Ultimate has a {chance} chance to summon Crows. They inflict Weaken for {amount} less enemy DMG over {turns} turns, and Black Flames Burn for {burn} DMG each turn for 3 turns.",
		},
		Abilities = {
			ability("Passive", "Illusion of Crows", "The supported card's Skill or Ultimate has a {chance} chance to summon Crows. They inflict Weaken for {amount} less enemy DMG over {turns} turns, and Black Flames Burn for {burn} DMG each turn for 3 turns.", {  }),
		},
	},
	{
		Id = "tetsu",
		Name = "Iron Bastion",
		Title = "Living Sand Fortress",
		Type = "Support",
		Role = "Warder",
		Weight = 6,
		Element = "Void",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "TS",
		Accent = Color3.fromRGB(140, 150, 165),
		Support = {
			Name = "Living Sand Armor",
			Kind = "OpeningShield",
			Trigger = "OnEntry",
			Amount = 0.25,
			Penalty = 0.1,
			Turns = 2,
			Uses = 1,
			Text = "On entry, sand shields the supported card for {amount} of its max HP. The heavy armor reduces attack speed by {penalty} for {turns} turns.",
		},
		Abilities = {
			ability("Passive", "Living Sand Armor", "On entry, sand shields the supported card for {amount} of its max HP. The heavy armor reduces attack speed by {penalty} for {turns} turns.", {  }),
		},
	},
	{
		Id = "luna",
		Name = "Celestial Strategist",
		Title = "Wisteria Tactician",
		Type = "Support",
		Role = "Mender",
		Weight = 10,
		Element = "Light",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "LM",
		Accent = Color3.fromRGB(110, 140, 255),
		Support = {
			Name = "Wisteria Antidote",
			Kind = "KillMend",
			Trigger = "OnKill",
			Amount = 0.2,
			Penalty = 0.1,
			Turns = 2,
			Uses = 3,
			Text = "When the supported card defeats an opponent, recover {amount} of its max HP. The antidote dulls its next attacks, reducing DMG by {penalty} for {turns} turns.",
		},
		Abilities = {
			ability("Passive", "Wisteria Antidote", "When the supported card defeats an opponent, recover {amount} of its max HP. The antidote dulls its next attacks, reducing DMG by {penalty} for {turns} turns.", {  }),
		},
	},
	{
		Id = "orin",
		Name = "Time Weaver",
		Title = "Keeper of Hours",
		Type = "Support",
		Role = "Mender",
		Weight = 2.5,
		Element = "Void",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "OR",
		Accent = Color3.fromRGB(90, 220, 220),
		Support = {
			Name = "Borrowed Tomorrow",
			Kind = "StartEnergy",
			Trigger = "OnEntry",
			Amount = 0.25,
			Penalty = 0.1,
			Turns = 2,
			Uses = 1,
			Text = "On entry, the supported card gains {amount} Ultimate charge, but borrowing time reduces its attack speed by {penalty} for {turns} turns.",
		},
		Abilities = {
			ability("Passive", "Borrowed Tomorrow", "On entry, the supported card gains {amount} Ultimate charge, but borrowing time reduces its attack speed by {penalty} for {turns} turns.", {  }),
		},
	},
	{
		Id = "aurelia",
		Name = "Nine-Tails Sovereign",
		Title = "Vessel of the Nine Tails",
		Type = "Support",
		Role = "Mender",
		Weight = 1,
		Element = "Cosmic",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "AU",
		Accent = Color3.fromRGB(255, 214, 140),
		Support = {
			Name = "Crimson Chakra Cloak",
			Kind = "LastStand",
			Trigger = "OnFatal",
			Amount = 0.85,
			Penalty = 0.25,
			Uses = 1,
			Fixed = true,
			Text = "Upon a fatal blow, the supported card releases its sealed Chakra and returns at {amount} HP. The Crimson Cloak costs {penalty} DMG and prevents further healing.",
		},
		Abilities = {
			ability("Passive", "Crimson Chakra Cloak", "Upon a fatal blow, the supported card releases its sealed Chakra and returns at {amount} HP. The Crimson Cloak costs {penalty} DMG and prevents further healing.", {  }),
		},
	},

	-- World 4 (Stormspire Isle) cards. New cards go at the end: the leaderboards store list positions.
	{
		Id = "hayate",
		Name = "Infernal Warden",
		Title = "Purgatory Flamekeeper",
		Type = "Attack",
		Role = "Striker",
		Weight = 6,
		Element = "Flame",
		Main = 490,
		HP = 980,
		SPD = 128,
		Glyph = "HY",
		Accent = Color3.fromRGB(255, 110, 50),
		Abilities = {
			ability("Basic", "Flame Arc", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Blazing Resolve", "Slash every enemy twice for {p1} DMG each. Gain {a2} attack speed for {t2} turns and shield every ally for {p3} DMG.", {
				{ Kind = "Damage", Pct = 0.7, Hits = 2, Target = "Enemies" },
				{ Kind = "Buff", Stat = "SPD", Amount = 0.2, Turns = 2 },
				{ Kind = "Shield", Pct = 0.3, Target = "Attack" },
			}, 3),
			ability("Passive", "Scorching Wake", "On a hit, a {chance} chance to leave Burn behind, dealing {p1} DMG each turn for {t1} turns.", {
				{ Kind = "Burn", Pct = 0.1, Turns = 3 },
			}, nil, { Trigger = "OnHit", Chance = 0.2 }),
			ability("Ultimate", "Purgatory Dance", "Sweep every enemy for {p1} DMG and inflict Burn for {p2} DMG each turn for {t2} turns.", {
				{ Kind = "Damage", Pct = 1.6, Target = "Enemies" },
				{ Kind = "Burn", Pct = 0.1, Turns = 3, Target = "Enemies" },
			}),
		},
	},
	{
		Id = "amane",
		Name = "Shadow Puppeteer",
		Title = "Mistress of Strings",
		Type = "Support",
		Role = "Mender",
		Weight = 6,
		Element = "Storm",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "AM",
		Accent = Color3.fromRGB(100, 160, 240),
		Support = {
			Name = "Puppet Reversal",
			Kind = "Cleanse",
			Trigger = "OnStatus",
			Amount = 0.15,
			Uses = 2,
			Text = "When the supported card receives Burn or Freeze, sever the strings: cleanse those effects and reflect them onto the attacker. Reflected Burn deals {amount} DMG for 3 turns.",
		},
		Abilities = {
			ability("Passive", "Puppet Reversal", "When the supported card receives Burn or Freeze, sever the strings: cleanse those effects and reflect them onto the attacker. Reflected Burn deals {amount} DMG for 3 turns.", {  }),
		},
	},
	{
		Id = "tsubasa",
		Name = "Lunar Reaper",
		Title = "Crescent Soul Blade",
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
			ability("Basic", "Soul Slash", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Crescent Severance", "Mark an enemy to take {a1} more DMG for {t1} turns, then sever its soul for {p2} DMG.", {
				{ Kind = "Debuff", Stat = "Vuln", Amount = 0.1, Turns = 2 },
				{ Kind = "Damage", Pct = 2.8 },
			}, 3),
			ability("Passive", "Reaper's Mark", "Critical hits scar the enemy's soul with Weaken, reducing its DMG by {a1} for {t1} turns.", {
				{ Kind = "Debuff", Stat = "ATK", Amount = 0.15, Turns = 2 },
			}, nil, { Trigger = "OnCrit" }),
			ability("Ultimate", "Moonless Sky", "Send five crescent blades through defense and protection for {p1} DMG each.", {
				{ Kind = "Damage", Pct = 1.4, Hits = 5, IgnoreDef = true },
			}),
		},
	},
	{
		Id = "amaya",
		Name = "Storm Oracle",
		Title = "Voice of the Storm",
		Type = "Support",
		Role = "Warder",
		Weight = 4,
		Element = "Storm",
		Main = 0, -- passive: no damage stat
		SPD = 0, -- passive: no action bar
		Glyph = "AY",
		Accent = Color3.fromRGB(255, 220, 80),
		Support = {
			Name = "Stormheart Siphon",
			Kind = "Lifesteal",
			Trigger = "OnHit",
			Amount = 0.1,
			Chance = 0.25,
			Threshold = 0.25,
			Text = "When the supported card deals direct DMG, a {chance} chance to drain {amount} of that DMG as HP.",
		},
		Abilities = {
			ability("Passive", "Stormheart Siphon", "When the supported card deals direct DMG, a {chance} chance to drain {amount} of that DMG as HP.", {  }),
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
			ability("Basic", "Chakra Claw", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1.1 },
			}),
			ability("Skill", "Chakra Eruption", "Burst through the enemy for {p1} DMG. Searing Chakra inflicts Burn for {p2} DMG each turn for {t2} turns.", {
				{ Kind = "Damage", Pct = 2.2 },
				{ Kind = "Burn", Pct = 0.1, Turns = 3 },
			}, 3),
			ability("Passive", "Crimson Cloak", "When below 50% HP, unleash the beast's Chakra for {a1} DMG, but the unstable cloak makes this card take {a2} more DMG.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.25 },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1 },
			}, nil, { Trigger = "BelowHalf", Limit = 1 }),
			ability("Ultimate", "Beast Bomb Barrage", "Launch six Beast Bombs at random enemies for {p1} DMG each.", {
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
			ability("Basic", "Death Ray", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Emperor's Command", "Deal {p1} DMG and suppress every enemy's attack speed by {a2} for {t2} turns.", {
				{ Kind = "Damage", Pct = 2.5 },
				{ Kind = "Debuff", Stat = "SPD", Amount = 0.15, Turns = 2, Target = "Enemies" },
			}, 4),
			ability("Passive", "Golden Tyranny", "When this card defeats an opponent, recover {p1} HP. Its arrogance makes it take {a2} more DMG for {t2} turns.", {
				{ Kind = "Heal", Pct = 0.15, MaxHP = true, Target = "Self" },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1, Turns = 2 },
			}, nil, { Trigger = "OnKill", Limit = 3 }),
			ability("Ultimate", "Planet Breaker", "Erase an enemy with a {p1} DMG blast that ignores defense.", {
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
			ability("Basic", "Illusion Cut", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Shattered Reflection", "Deal {p1} DMG and expose a false opening, lowering defense by {a2} for {t2} turns.", {
				{ Kind = "Damage", Pct = 1.8 },
				{ Kind = "Debuff", Stat = "DEF", Amount = 0.15, Turns = 3 },
			}, 3),
			ability("Passive", "Perfect Hypnosis", "On entry, create two Illusions to evade incoming hits. Maintaining them makes this card take {a2} more DMG for {t2} turns.", {
				{ Kind = "Evade", Hits = 2, Target = "Self" },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1, Turns = 2 },
			}, nil, { Trigger = "OnEntry" }),
			ability("Ultimate", "False Heaven", "Strike through four false realities for {p1} DMG each. Every enemy takes {a2} more DMG for {t2} turns.", {
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
			ability("Basic", "Blood Whip", "Strike an enemy for {p1} DMG.", {
				{ Kind = "Damage", Pct = 1 },
			}),
			ability("Skill", "Thorned Blood", "Four blood thorns pierce random enemies for {p1} DMG each.", {
				{ Kind = "Damage", Pct = 0.6, Hits = 4, Target = "RandomEnemy" },
			}, 3),
			ability("Passive", "Demon Rebirth", "When below 50% HP, cleanse Burn and Freeze and regenerate {p1} HP. This card can no longer be healed.", {
				{ Kind = "Cleanse", Amount = 2, Target = "Self" },
				{ Kind = "Heal", Pct = 0.25, MaxHP = true, Target = "Self" },
				{ Kind = "HealingLock" },
			}, nil, { Trigger = "BelowHalf", Limit = 1 }),
			ability("Aura", "Progenitor's Gift", "On entry, share cursed blood for {a1} DMG on every ally. The pact makes them take {a2} more DMG.", {
				{ Kind = "Buff", Stat = "ATK", Amount = 0.1, Target = "Attack" },
				{ Kind = "Buff", Stat = "Guard", Amount = -0.1, Target = "Attack" },
			}, nil, { Trigger = "OnEntry" }),
			ability("Ultimate", "Black Blood Tempest", "Engulf every enemy in a {p1} DMG blood storm.", {
				{ Kind = "Damage", Pct = 3, Target = "Enemies" },
			}),
		},
	},
}

-- Card illustrations: paste each card's Roblox image asset id here (0 = no art yet, the card shows its
-- element-lit bust). Upload the PNG from art/cards/ in Studio (Asset Manager > Bulk Import), right-click it,
-- Copy Asset ID. The picture must belong to the same account or group that owns the game.
local ART: { [string]: number } = {
	rook = 0,
	kaede = 0,
	tomo = 0,
	mirai = 0,
	sora = 0,
	akane = 0,
	kaito = 0,
	noa = 0,
	raijen = 0,
	hana = 0,
	goro = 0,
	suzu = 0,
	ibuki = 0,
	yume = 110268918063325,
	tetsu = 136800978541718,
	luna = 0,
	orin = 0,
	aurelia = 138740646482456,
	hayate = 0,
	amane = 0,
	tsubasa = 0,
	amaya = 108312817362054,
	kurogane_card = 76633065486147,
	rimeveil_card = 0,
	vex_card = 0,
	tenrai_card = 0,
}

local Cards = {}

Cards.List = list
Cards.ById = {} :: { [string]: Card }

for _, card in list do
	assert(Cards.ById[card.Id] == nil, `Duplicate card id "{card.Id}"`)
	Cards.ById[card.Id] = card
	local art = ART[card.Id]
	if art ~= nil and art > 0 and card.Image == nil then
		card.Image = `rbxassetid://{art}`
	end
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

-- Percentage support effects grow gently; multiplying a 25% shield buff by 64 would break combat.
-- Passive strengths are percentages; damage and HP belong to Attack cards only.
function Cards.SupportBoost(card: Card, border: string?): number
	return if card.Type == "Support" then 1 + 0.25 * (Borders.Index(border or "Normal") - 1) else 1
end

function Cards.EffectAmount(card: Card, effect: Effect, border: string?): number
	local amount = effect.Amount or 0
	if effect.Kind == "Buff" or effect.Kind == "Debuff" then
		-- Only this card's own kit: shared element synergies / bonds must not inherit its border.
		for _, a in card.Abilities do
			if table.find(a.Effects, effect) then return amount * Cards.SupportBoost(card, border) end
		end
	end
	return amount
end

function Cards.LinkAmount(card: Card, border: string?): number
	return if card.Link then card.Link.Amount * Cards.SupportBoost(card, border) else 0
end

function Cards.RoundPercent(value: number): number
	if value == 0 then return 0 end
	return math.max(0.05, math.floor(math.abs(value) * 20 + 0.5) / 20) * (if value < 0 then -1 else 1)
end

function Cards.SupportValue(card: Card, stars: number, border: string?, awaken: number?): number
	if not card.Support then return 0 end
	if card.Support.Fixed then return card.Support.Amount end
	return Cards.RoundPercent(math.min(0.5, card.Support.Amount * Cards.SupportBoost(card, border)
		* (1 + Config.StarBonus * math.clamp(stars, 0, Config.MaxStars)) * Awaken.StatMultiplier(awaken)))
end

function Cards.SupportScore(card: Card, stars: number, border: string?, awaken: number?): number
	return if card.Support then Borders.Multiplier(border) * Cards.Scale(card) * (1 + 0.05 * stars) * Awaken.StatMultiplier(awaken) else 0
end

-- A stat with stars, the border's tier multiplier (1x / 4x / 16x / 64x), the card's rarity scale
-- (Cards.Scale) and the Awakening node (node 1: +10%). The border decides power: the rarest card's scale,
-- 5 stars and node 1 together are about 2.1x, far under the next border's 4x.
function Cards.Stat(card: Card, base: number, stars: number, border: string?, awaken: number?): number
	return Cards.StatWithStars(base * Borders.Multiplier(border) * Cards.Scale(card) * Awaken.StatMultiplier(awaken), stars)
end

-- Attack rating used for boss recommendations: ATK x 10 + HP. Passive supports add no rating.
function Cards.Power(card: Card, stars: number, border: string?, awaken: number?): number
	local main = Cards.Stat(card, card.Main, stars, border, awaken)
	if card.Type == "Attack" then
		return main * Config.Power.PerATK + Cards.Stat(card, card.HP or 0, stars, border, awaken)
	end
	return 0 -- passive supports have no combat stats; team rating measures the Attack row
end

-- Deck Cost (the Cost Challenge): by the border the card wears (Borders.Cost: 2 / 4 / 6 / 8).
function Cards.Cost(border: string?): number
	return Borders.Get(border).Cost
end

function Cards.MainLabel(card: Card): string
	return if card.Type == "Attack" then "ATK" else "PASSIVE"
end

return Cards
