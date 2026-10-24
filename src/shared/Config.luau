--!strict
-- Game-wide tuning. Every number the design doc calls "tunable" lives here.

local Config = {}

Config.GameName = "Anime Card Roll"

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
	LuckCap = 25, -- tiered luck (Odds.Chances): Commons stay about 28% even at the cap
}

Config.Unlocks = {
	-- Off during the test phase: Roll, Quick Roll and Auto Roll all work from the start.
	-- Turns on by itself when TestMode is switched off.
	Enabled = not Config.TestMode,
	QuickRoll = { Rolls = 20, Seconds = 180 },
	AutoRoll = { Rolls = 50, Seconds = 600 },
}

Config.MaxStars = 5
Config.StarBonus = 0.05 -- +5% stats per star

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
	PerPWR = 24, -- Support: PWR x 24 (the first all-Base deck is about 52k)
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
	TurnSeconds = 2, -- a SPD 100 card acts once per turn; buff, burn and shield durations count turns
	Tick = 0.1, -- simulation step, in battle seconds
	TimeLimit = 180, -- lose when the 3-minute timer ends
	IntroSeconds = 2, -- "FIGHT!" banner before the first tick
	UltimateCost = 100,
	EnergyPerAction = 20,
	EnergyPerHit = 10,
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
