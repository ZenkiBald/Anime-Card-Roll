--!strict
-- World bosses. A new boss or difficulty is one entry here; the battle engine reads it as data.
-- Boss models for the hub and the battle screen are built from BossModels.luau.
--
-- Moves are checked top to bottom each time the boss acts; the first one that is due is used,
-- and the last move (no Every) is the default. Every = N fires on every Nth boss action
-- (counted from the start of its phase). Warn = true shows a warning marker first
-- (Difficulty.WarnSeconds long). MinDifficulty = "Hard" adds the move on Hard and Nightmare only.
-- Target: Single (a random Attack card, or the taunting one) | Random (each hit picks again) | All | Self.
-- Pct is a share of the boss's ATK. Optional riders on each hit:
--   Burn = { Pct, Turns }   damage over time      Freeze = true   the card skips its next action
--   Slow = { Amount, Turns } every card loses SPD  Barrier = share of max HP (Target Self): only
--   Skills and Ultimates break it, everything else deals Config.Battle.BarrierLeak of its damage.
-- OnPhase.Steal: at 50% and 20% HP the boss steals the biggest buff from each Attack card and gains ATK.

export type Burn = { Pct: number, Turns: number }
export type Slow = { Amount: number, Turns: number }

export type Move = {
	Name: string,
	Target: string,
	Pct: number,
	Hits: number?,
	Every: number?,
	Phase: number?, -- 2 = only from 50% HP
	MinDifficulty: string?,
	Warn: boolean?,
	Burn: Burn?,
	Freeze: boolean?,
	Slow: Slow?,
	Barrier: number?,
}

export type Difficulty = {
	D: number, -- difficulty score: rewards scale with it (Rewards.luau)
	Recommended: number, -- recommended Deck Power
	HP: number,
	ATK: number,
	WarnSeconds: number,
}

export type Boss = {
	Id: string,
	World: number,
	WorldName: string,
	Name: string,
	Title: string,
	Glyph: string,
	Accent: Color3, -- main colour
	Deep: Color3, -- dark backdrop colour for the world
	Particles: string, -- battle backdrop: Embers | Snow | Motes | Rain
	Mechanic: string,
	DEF: number, -- 0 to 0.4
	SPD: number,
	OnPhase: { Steal: number? }?,
	Moves: { Move },
	Difficulties: { [string]: Difficulty },
}

local Bosses = {}

Bosses.DifficultyOrder = { "Normal", "Hard", "Nightmare" }

-- HP / ATK per difficulty are tuned with tests/battle_test.luau so a deck at the recommended
-- power wins in 60-90 seconds and usually loses a card or two on the way.
local list: { Boss } = {
	{
		Id = "kurogane",
		World = 1,
		WorldName = "Ember Village",
		Name = "Kurogane",
		Title = "the Ash Ronin",
		Glyph = "KG",
		Accent = Color3.fromRGB(255, 104, 56),
		Deep = Color3.fromRGB(70, 22, 14),
		Particles = "Embers",
		Mechanic = "His hits Burn their target. At 50% HP he adds Ash Storm, which hits every Attack card.",
		DEF = 0.1,
		SPD = 95,
		Moves = {
			{ Name = "Ash Storm", Target = "All", Pct = 0.55, Every = 4, Phase = 2, Warn = true, Burn = { Pct = 0.1, Turns = 2 } },
			{ Name = "Twin Ember", Target = "Single", Pct = 0.8, Hits = 2, Every = 6, MinDifficulty = "Hard", Burn = { Pct = 0.1, Turns = 2 } },
			{ Name = "Ember Iaido", Target = "Single", Pct = 2.2, Every = 5, Warn = true, Burn = { Pct = 0.15, Turns = 2 } },
			{ Name = "Ash Cut", Target = "Single", Pct = 1, Burn = { Pct = 0.15, Turns = 2 } },
		},
		Difficulties = {
			Normal = { D = 1, Recommended = 12000, HP = 21000, ATK = 120, WarnSeconds = 2 },
			Hard = { D = 2, Recommended = 18000, HP = 28000, ATK = 145, WarnSeconds = 2 },
			Nightmare = { D = 3, Recommended = 24000, HP = 63500, ATK = 270, WarnSeconds = 1 },
		},
	},
	{
		Id = "rimeveil",
		World = 2,
		WorldName = "Frostfang Peaks",
		Name = "Rimeveil",
		Title = "the Glacier Queen",
		Glyph = "RV",
		Accent = Color3.fromRGB(120, 210, 255),
		Deep = Color3.fromRGB(12, 30, 62),
		Particles = "Snow",
		Mechanic = "Rime Spear Freezes a card so it skips its next action. At 50% HP Glacier Veil slows your whole deck.",
		DEF = 0.15,
		SPD = 100,
		Moves = {
			{ Name = "Glacier Veil", Target = "All", Pct = 0.45, Every = 4, Phase = 2, Warn = true, Slow = { Amount = 0.25, Turns = 3 } },
			{ Name = "Hailstorm", Target = "Random", Pct = 0.7, Hits = 3, Every = 6, MinDifficulty = "Hard", Freeze = true },
			{ Name = "Rime Spear", Target = "Single", Pct = 1.8, Every = 4, Warn = true, Freeze = true },
			{ Name = "Ice Shard", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			Normal = { D = 4, Recommended = 28000, HP = 57000, ATK = 360, WarnSeconds = 2 },
			Hard = { D = 5, Recommended = 42000, HP = 182000, ATK = 445, WarnSeconds = 2 },
			Nightmare = { D = 6, Recommended = 56000, HP = 249000, ATK = 595, WarnSeconds = 1 },
		},
	},
	{
		Id = "vex",
		World = 3,
		WorldName = "Neon Abyss",
		Name = "Null Emperor Vex",
		Title = "the Void Tyrant",
		Glyph = "VX",
		Accent = Color3.fromRGB(220, 70, 255),
		Deep = Color3.fromRGB(26, 8, 44),
		Particles = "Motes",
		Mechanic = "Null Barrier blocks most damage until Skills or Ultimates break it. At 50% and 20% HP he steals your buffs.",
		DEF = 0.2,
		SPD = 105,
		OnPhase = { Steal = 0.1 },
		Moves = {
			{ Name = "Collapse", Target = "All", Pct = 0.6, Every = 4, Phase = 2, Warn = true },
			{ Name = "Zero Point", Target = "Single", Pct = 3, Every = 7, MinDifficulty = "Hard", Warn = true },
			{ Name = "Null Barrier", Target = "Self", Pct = 0, Every = 5, Barrier = 0.06 },
			{ Name = "Void Slash", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			Normal = { D = 7, Recommended = 50000, HP = 190000, ATK = 700, WarnSeconds = 2 },
			Hard = { D = 8, Recommended = 75000, HP = 546000, ATK = 760, WarnSeconds = 2 },
			Nightmare = { D = 9, Recommended = 100000, HP = 1500000, ATK = 1000, WarnSeconds = 1 },
		},
	},
	{
		Id = "tenrai",
		World = 4,
		WorldName = "Stormspire Isle",
		Name = "Tenrai",
		Title = "the Storm Sovereign",
		Glyph = "TR",
		Accent = Color3.fromRGB(255, 222, 70),
		Deep = Color3.fromRGB(16, 20, 44),
		Particles = "Rain",
		Mechanic = "Chain Lightning strikes random cards again and again. At 50% HP Thunderclap stuns your whole deck: bring cleanses and shields.",
		DEF = 0.25,
		SPD = 110,
		Moves = {
			{ Name = "Thunderclap", Target = "All", Pct = 0.5, Every = 5, Phase = 2, Warn = true, Freeze = true },
			{ Name = "Sky Rend", Target = "Single", Pct = 3.2, Every = 7, MinDifficulty = "Hard", Warn = true, Burn = { Pct = 0.12, Turns = 2 } },
			{ Name = "Chain Lightning", Target = "Random", Pct = 0.55, Hits = 4, Every = 3 },
			{ Name = "Bolt", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			-- Nightmare's recommended deck needs a few fusions (see tests/fixtures.luau).
			Normal = { D = 10, Recommended = 140000, HP = 1950000, ATK = 4000, WarnSeconds = 2 },
			Hard = { D = 11, Recommended = 172000, HP = 2440000, ATK = 4640, WarnSeconds = 2 },
			Nightmare = { D = 12, Recommended = 205000, HP = 2750000, ATK = 5980, WarnSeconds = 1 },
		},
	},
}

Bosses.List = list
Bosses.ById = {} :: { [string]: Boss }
for _, boss in list do
	assert(Bosses.ById[boss.Id] == nil, `Duplicate boss id "{boss.Id}"`)
	Bosses.ById[boss.Id] = boss
end

function Bosses.Get(id: string): Boss?
	return Bosses.ById[id]
end

-- "kurogane:Normal": the key for saved clears and best times.
function Bosses.FightKey(bossId: string, difficulty: string): string
	return `{bossId}:{difficulty}`
end

function Bosses.DifficultyIndex(difficulty: string): number
	return table.find(Bosses.DifficultyOrder, difficulty) or 1
end

-- Progression: Normal needs the previous world's Normal; Hard and Nightmare need the
-- difficulty below on the same boss. `cleared` is the saved Progress.Cleared table.
function Bosses.IsUnlocked(cleared: { [string]: boolean }, bossId: string, difficulty: string): boolean
	local boss = Bosses.Get(bossId)
	if boss == nil then
		return false
	end
	local index = Bosses.DifficultyIndex(difficulty)
	if index > 1 then
		return cleared[Bosses.FightKey(bossId, Bosses.DifficultyOrder[index - 1])] == true
	end
	for _, other in list do
		if other.World == boss.World - 1 then
			return cleared[Bosses.FightKey(other.Id, "Normal")] == true
		end
	end
	return true
end

-- What the player must beat first, for the locked label.
function Bosses.UnlockHint(bossId: string, difficulty: string): string
	local boss = Bosses.Get(bossId)
	if boss == nil then
		return ""
	end
	local index = Bosses.DifficultyIndex(difficulty)
	if index > 1 then
		return `Beat {boss.Name} on {Bosses.DifficultyOrder[index - 1]}`
	end
	for _, other in list do
		if other.World == boss.World - 1 then
			return `Beat {other.Name} on Normal`
		end
	end
	return ""
end

return Bosses
