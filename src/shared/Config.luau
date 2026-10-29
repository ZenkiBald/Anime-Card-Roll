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
	TurnSeconds = 2.5, -- a SPD 100 card acts once per turn; durations count battle seconds
	SkillMinSeconds = 8,
	UltimateMinSeconds = 22,
	TeamUltimateGap = 3,
	HitEnergyInterval = 2,
	Tick = 0.1, -- simulation step, in battle seconds
	TimeLimit = 180, -- lose when the 3-minute timer ends
	IntroSeconds = 2, -- "FIGHT!" banner before the first tick
	QuickIntroSeconds = 0.3, -- chained fights (AUTO CLIMB / AUTO-RETRY, BattleStart { Quick = true }): no curtain
	-- Tower sweep (BattleStart { Sweep = true } in a tower): floors where the deck has at least SweepPower x the
	-- floor's recommended power are won at once and paid in full, up to SweepFloors per start.
	SweepPower = 3,
	SweepFloors = 5,
	-- Rhythm: action bars start part-filled (StartGauge, by SPD and slot) so a fight opens with units acting
	-- one after another, and at most one unit acts per tick (the rest keep a full bar and go next tick).
	StartGauge = { Min = 0.2, Max = 0.75 },
	OneActionPerTick = true,
	-- Threat: an enemy hit always takes at least this share of the target card's max HP (before Guard), so
	-- even a deck far above a fight's power feels its hits; a leader's warned move also pierces shields.
	MinHit = { Guard = 0.01, Leader = 0.02, LeaderSkill = 0.06 },
	SkillPierce = 0.4, -- share of a leader's warned move that goes through shields
	UltimateCost = 100,
	EnergyPerAction = 10,
	EnergyPerHit = 3,
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
	-- Stagger bar (leaders and raid Colossi): each card hit on the leader fills StaggerPerHit, x2.5 from an
	-- element that beats it (x1.5 for Cosmic), x0.5 from one it beats. Full = Staggered for StaggerSeconds:
	-- its warned move is cancelled, it can't act, its DEF is 0 and Ultimates hit it for +50%.
	StaggerPerHit = 0.012,
	StaggerCounter = 2.5,
	StaggerCosmic = 1.5,
	StaggerWeak = 0.5,
	StaggerSeconds = 5,
	StaggerUltBonus = 0.5,
	Speeds = { 1, 2 }, -- 2x unlocks after clearing World 1 Normal (always on while unlock rules are off)
	SpeedUnlock = "kurogane:Normal",
}

return Config
