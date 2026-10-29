--!strict
-- Game-wide tuning. Every number the design doc calls "tunable" lives here.

local Config = {}

Config.GameName = "Anime Card Roll"
Config.CelestialCardsReady = true -- all 16 clothed portraits loaded in Studio

-- TEST PHASE SWITCH
-- true  = dev panel on, all roll buttons unlocked, saves go to a separate test store.
-- false = launch behaviour (unlock rules apply, dev tools are refused by the server).
Config.TestMode = true
-- Who may use the test tools while TestMode is on (DevAccess, server): anyone in Studio, the game's owner
-- (a group game: rank DevGroupRank or higher in the owning group), and these user ids (testers).
Config.DevUserIds = {} :: { number }
Config.DevGroupRank = 254

Config.Roll = {
	Cooldown = 1.2, -- seconds between rolls, enforced on the server
	LuckSoftStart = 5,
	LuckSoftScale = 10,
	DevLuckMax = 1000000, -- test input bound; earned luck has diminishing returns, not this cap
}

Config.Unlocks = {
	-- Off during the test phase: Roll, Quick Roll and Auto Roll all work from the start.
	-- Turns on by itself when TestMode is switched off.
	Enabled = not Config.TestMode,
	QuickRoll = { Rolls = 20, Seconds = 180 },
	AutoRoll = { Rolls = 50, Seconds = 600 },
}

Config.MaxStars = 5
Config.StarBonus = 0 -- legacy save field; duplicates grant no combat stats

-- Fusion (Hoshi in town): this many copies of one card at one border fuse into 1 copy at the next
-- border (Base -> Gold -> Rainbow -> Secret).
Config.FusionCopies = 100

-- Auto Roll never stops by itself (user's call, 2026-10-24: players want to pull every second). A
-- Rainbow / Secret border or a Demon Seal pulled on Auto holds the next roll this long, so its full reveal
-- plays, then rolling carries on.
Config.AutoBigRevealHold = 6

-- Music / Effects volume steps in SETTINGS (saved per player).
Config.VolumeSteps = { 0, 0.25, 0.5, 0.75, 1 }

-- Pulls of this rarity or better are announced to the whole server.
Config.AnnounceFrom = "Rainbow" -- borders this good are announced to the server
-- Pulls this rare (combined card x border rarity, Cards.Rarity) also post a server chat line; from
-- ChatBillionFrom it's the highlighted BILLION-tier line.
Config.ChatAnnounceFrom = 10000000
Config.ChatBillionFrom = 1000000000

Config.Deck = {
	Slots = 4, -- per row: 4 Attack (front) + 4 Support (back)
	Presets = 3,
	VipPresets = 2, -- the VIP pass adds this many (MonetizationConfig)
	CostCap = 30, -- the Cost Challenge: total Deck Cost (Cards.Cost) at most this
	CostTraitShards = 2, -- and it pays this many times the Trait Shards
}

-- Deck Power per card. Support cards have no HP (they can't be hit), so their power is PWR only.
Config.Power = {
	PerATK = 10, -- Attack: ATK x 10 + HP
	-- Supports are passive equipment and add no combat rating.
}

-- Boss reward rolls (design doc, "Boss reward rolls"). D is the fight's difficulty score, 1 to 9.
Config.Rewards = {
	BaseRolls = 3, -- rolls = 3 + 2D
	RollsPerD = 2,
	LuckPerD = 0.35, -- boss luck = 1 + 0.35D, capped at 4x; the player's own luck multiplies on top (total cap 25x)
	BossLuckCap = 4,
	ShardsPerD = 15, -- every win also pays 15 x D Shards
	PotionChance = 0.5, -- and has this chance to drop a potion, better ones at higher D
	PotionDrops = {
		{ MaxD = 3, Potion = "luck" },
		{ MaxD = 6, Potion = "superluck" },
		{ MaxD = math.huge, Potion = "mythic" },
	},
}

-- Battle rules from the design doc. Boss stats live in Bosses.luau.
Config.Battle = {
	TurnSeconds = 2.5, -- enemies: a SPD 100 bar fills once per turn; status durations count turns of this length
	-- Attack cards act in real time by archetype (Cards.Archetype, from SPD): each Basic on its own interval,
	-- each Skill on its own cooldown, each Ultimate when its energy is full. Within a band the faster card
	-- gets the shorter interval / cooldown and the rarer card the higher damage. Damage totals are per cast
	-- (all hits); Cards.luau fits every Attack ability into its band (per-hit multiples of 5%).
	Archetypes = {
		Fast = { SPD = { 120, 135 }, Interval = { 1.2, 1.0 }, Basic = { 0.65, 0.75 }, Cooldown = { 7.5, 6.5 }, Skill = { 2.4, 2.7 }, UltCost = 80, Ult = { 4.8, 5.4 }, SkillShield = 1 },
		Balanced = { SPD = { 105, 119 }, Interval = { 1.8, 1.5 }, Basic = { 1.0, 1.1 }, Cooldown = { 10.5, 9 }, Skill = { 2.8, 3.2 }, UltCost = 100, Ult = { 5.8, 6.5 }, SkillShield = 1 },
		Heavy = { SPD = { 85, 104 }, Interval = { 2.8, 2.3 }, Basic = { 1.5, 1.8 }, Cooldown = { 14, 12 }, Skill = { 3.4, 4.0 }, UltCost = 135, Ult = { 7.5, 9.0 }, SkillShield = 2 },
	},
	SlotOffsets = { 0, 0.35, 0.7, 1.05 }, -- each Attack slot's first Basic, in seconds: the squad attacks in a ripple
	EnergyPerSecond = 5.4, -- every card charges its Ultimate in real time (Fast ~15 s, Balanced ~18.5 s, Heavy ~25 s)
	EnergyPerHit = 3, -- plus a little from enemy hits (at most once per HitEnergyInterval)
	HitEnergyInterval = 2,
	TeamUltimateGap = 3, -- AUTO ULT fires at most one Ultimate per this many seconds...
	BreakChainGap = 0.5, -- ...except during a Shield Break, when held Ultimates fire one after another
	HoldAbove = 0.6, -- HOLD ULT FOR BREAK: AUTO ULT holds full Ultimates while the Shield bar is over 60%
	Tick = 0.1, -- simulation step, in battle seconds
	TimeLimit = 180, -- lose when the 3-minute timer ends
	IntroSeconds = 2, -- "FIGHT!" banner before the first tick
	QuickIntroSeconds = 0.3, -- chained fights (AUTO CLIMB / AUTO-RETRY, BattleStart { Quick = true }): no curtain
	-- Tower sweep (BattleStart { Sweep = true } in a tower): floors where the deck has at least SweepPower x the
	-- floor's recommended power are won at once and paid in full, up to SweepFloors per start.
	SweepPower = 3,
	SweepFloors = 5,
	-- Enemy rhythm: enemy action bars start part-filled (StartGauge) and at most one enemy acts per tick.
	StartGauge = { Min = 0.2, Max = 0.75 },
	OneActionPerTick = true,
	-- Threat: an enemy hit always takes at least this share of the target card's max HP (before Guard), so
	-- even a deck far above a fight's power feels its hits; a leader's warned move also pierces shields.
	MinHit = { Guard = 0.01, Leader = 0.02, LeaderSkill = 0.06 },
	SkillPierce = 0.4, -- share of a leader's warned move that goes through shields
	-- Vanguard: Attack slot 1 draws this share of single-target enemy attacks (WarderVanguard if it's a Warder).
	Vanguard = 0.5,
	WarderVanguard = 0.8,
	-- Boss Clash: when a leader's warned move finishes winding up, a ClashWindow-second ring opens. A tap /
	-- Space in time sends the strongest card in: it reflects ClashReflect x its ATK, the move's damage to the
	-- squad is cut by ClashCut and the Shield bar fills ClashShield. Ignored, the move lands as normal.
	ClashWindow = 1.2,
	ClashReflect = 2,
	ClashCut = 0.75,
	ClashShield = 0.3,
	CritChance = 0.1,
	CritDamage = 1.5,
	ShieldTurns = 2,
	BarrierLeak = 0.3, -- while a boss barrier is up, Basic hits and burns deal only 30%; Skills and Ultimates break it
	BreakVuln = 0.25, -- a broken barrier leaves the boss taking +25% damage
	BreakTurns = 2,
	MaxDEF = 0.4, -- boss DEF runs 0-40%
	PhaseAt = 0.5, -- boss adds its phase-2 move at 50% HP
	EnrageAt = 0.2, -- and enrages at 20%
	EnrageATK = 0.3,
	-- Boss Shield (the leader's Stagger bar): while it stands the leader takes ShieldTaken damage. Card hits
	-- fill the bar by their DMG % x ShieldFill[slot] (Heavy Skills x their archetype's SkillShield), a guard
	-- KO adds GuardKOShield and a Warder standing absorbs WarderAbsorb of the fill. Full = Shield Break: the
	-- leader is stunned for StaggerSeconds (its warned move cancelled) and takes BrokenTaken damage.
	ShieldTaken = 0.5,
	BrokenTaken = 1.5,
	ShieldFill = { Basic = 0.005, Skill = 0.008, Ultimate = 0.004, Clash = 0 },
	GuardKOShield = 0.25,
	WarderAbsorb = 0.3,
	StaggerSeconds = 6,
	-- Guard roles: a Warder links to the leader (Protect, Bosses.luau); a Mender mends it every MendSeconds
	-- for MendHeal of its max HP and cleanses its debuffs; Strikers / Hexers stack Expose (more DMG taken) /
	-- Weaken (less DMG dealt) on your highest-ATK card, up to HexStacks, each refreshing HexSeconds.
	MendSeconds = 8,
	MendHeal = 0.03,
	HexStack = 0.05,
	HexStacks = 5,
	HexSeconds = 8,
	Speeds = { 1, 2 }, -- 2x unlocks after clearing World 1 Normal (always on while unlock rules are off)
	SpeedUnlock = "kurogane:Normal",
}

return Config
