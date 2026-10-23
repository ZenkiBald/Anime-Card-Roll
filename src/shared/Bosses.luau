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
--
-- Squads (4v4): every fight is the boss (the leader) and its three Guards (Bosses.GuardTypes below).
-- The fight is won when the leader falls; guards are there to make that hard. Guard moves use the same
-- format, plus two support moves that target the guard's own side:
--   Heal = share of the leader's max HP, given to the most hurt enemy (Target "Ally")
--   Rally = { Amount, Turns }: every enemy +ATK (Target "Ally")
-- A guard type with Taunt draws your cards' attacks (unless you tap another target), and Protect makes
-- the leader take that much less damage while it stands.
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
	Heal: number?,
	Rally: Rally?,
}

export type Rally = { Amount: number, Turns: number }

export type GuardType = {
	Id: string,
	Name: string,
	Icon: string,
	Role: string, -- Striker | Hexer | Mender | Warder (what it's for, shown on its tile)
	World: number, -- the world it belongs to (the tower mixes guards from worlds the floor has reached)
	Element: string, -- Elements.luau: its world's, except Menders, which are Light (Void cards cut them down)
	Color: Color3,
	HP: number, -- share of the leader's HP
	ATK: number, -- share of the leader's ATK
	SPD: number,
	DEF: number,
	Taunt: boolean?,
	Protect: number?,
	Moves: { Move },
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
	Element: string, -- Elements.luau
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
	Guards: { string }, -- three Bosses.GuardTypes ids, in slot order (a Warder stands in front, last)
	Moves: { Move },
	Difficulties: { [string]: Difficulty },
}

local Bosses = {}

Bosses.DifficultyOrder = { "Normal", "Hard", "Nightmare" }

-- HP / ATK per difficulty are the leader's and are tuned with tests/battle_test.luau (guards included:
-- their HP / ATK are shares of these) so a deck at the recommended power wins in 60-90 seconds and
-- usually loses a card on the way.
local list: { Boss } = {
	{
		Id = "kurogane",
		Element = "Flame",
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
		Guards = { "ashigaru", "embermonk", "ironclad" },
		Moves = {
			{ Name = "Ash Storm", Target = "All", Pct = 0.55, Every = 4, Phase = 2, Warn = true, Burn = { Pct = 0.1, Turns = 2 } },
			{ Name = "Twin Ember", Target = "Single", Pct = 0.8, Hits = 2, Every = 6, MinDifficulty = "Hard", Burn = { Pct = 0.1, Turns = 2 } },
			{ Name = "Ember Iaido", Target = "Single", Pct = 2.2, Every = 5, Warn = true, Burn = { Pct = 0.15, Turns = 2 } },
			{ Name = "Ash Cut", Target = "Single", Pct = 1, Burn = { Pct = 0.15, Turns = 2 } },
		},
		Difficulties = {
			Normal = { D = 1, Recommended = 12000, HP = 19500, ATK = 102, WarnSeconds = 2 },
			Hard = { D = 2, Recommended = 18000, HP = 24500, ATK = 123, WarnSeconds = 2 },
			Nightmare = { D = 3, Recommended = 24000, HP = 54500, ATK = 243, WarnSeconds = 1 },
		},
	},
	{
		Id = "rimeveil",
		Element = "Frost",
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
		Guards = { "frostarcher", "snowmaiden", "glaciergolem" },
		Moves = {
			{ Name = "Glacier Veil", Target = "All", Pct = 0.45, Every = 4, Phase = 2, Warn = true, Slow = { Amount = 0.25, Turns = 3 } },
			{ Name = "Hailstorm", Target = "Random", Pct = 0.7, Hits = 3, Every = 6, MinDifficulty = "Hard", Freeze = true },
			{ Name = "Rime Spear", Target = "Single", Pct = 1.8, Every = 4, Warn = true, Freeze = true },
			{ Name = "Ice Shard", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			Normal = { D = 4, Recommended = 28000, HP = 47500, ATK = 432, WarnSeconds = 2 },
			Hard = { D = 5, Recommended = 42000, HP = 146500, ATK = 534, WarnSeconds = 2 },
			Nightmare = { D = 6, Recommended = 56000, HP = 196500, ATK = 655, WarnSeconds = 1 },
		},
	},
	{
		Id = "vex",
		Element = "Void",
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
		Guards = { "shade", "nullwitch", "voidknight" },
		Moves = {
			{ Name = "Collapse", Target = "All", Pct = 0.6, Every = 4, Phase = 2, Warn = true },
			{ Name = "Zero Point", Target = "Single", Pct = 3, Every = 7, MinDifficulty = "Hard", Warn = true },
			{ Name = "Null Barrier", Target = "Self", Pct = 0, Every = 5, Barrier = 0.06 },
			{ Name = "Void Slash", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			Normal = { D = 7, Recommended = 50000, HP = 163500, ATK = 600, WarnSeconds = 2 },
			Hard = { D = 8, Recommended = 75000, HP = 458500, ATK = 640, WarnSeconds = 2 },
			Nightmare = { D = 9, Recommended = 100000, HP = 1460500, ATK = 950, WarnSeconds = 1 },
		},
	},
	{
		Id = "tenrai",
		Element = "Storm",
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
		Guards = { "thunderhawk", "stormpriest", "raiju" },
		Moves = {
			{ Name = "Thunderclap", Target = "All", Pct = 0.5, Every = 5, Phase = 2, Warn = true, Freeze = true },
			{ Name = "Sky Rend", Target = "Single", Pct = 3.2, Every = 7, MinDifficulty = "Hard", Warn = true, Burn = { Pct = 0.12, Turns = 2 } },
			{ Name = "Chain Lightning", Target = "Random", Pct = 0.55, Hits = 4, Every = 3 },
			{ Name = "Bolt", Target = "Single", Pct = 1 },
		},
		Difficulties = {
			-- Nightmare's recommended deck needs a few fusions (see tests/fixtures.luau).
			Normal = { D = 10, Recommended = 140000, HP = 2352500, ATK = 3400, WarnSeconds = 2 },
			Hard = { D = 11, Recommended = 172000, HP = 3008000, ATK = 3480, WarnSeconds = 2 },
			Nightmare = { D = 12, Recommended = 205000, HP = 3280500, ATK = 4485, WarnSeconds = 1 },
		},
	},
}

-- Guards ----------------------------------------------------------------------------------------
-- HP and ATK are shares of the leader's (so they scale with every difficulty and tower floor).
local GUARD = {
	Striker = { HP = 0.12, ATK = 0.4, SPD = 105, DEF = 0.05 },
	Hexer = { HP = 0.1, ATK = 0.3, SPD = 100, DEF = 0.05 },
	Mender = { HP = 0.09, ATK = 0.2, SPD = 90, DEF = 0.05 },
	Warder = { HP = 0.2, ATK = 0.25, SPD = 90, DEF = 0.15 },
}

local function guard(id: string, name: string, icon: string, role: string, world: number, element: string, color: Color3, moves: { Move }, extra: { [string]: any }?): GuardType
	local base = GUARD[role]
	local g = {
		Id = id,
		Name = name,
		Icon = icon,
		Role = role,
		World = world,
		Element = element,
		Color = color,
		HP = base.HP,
		ATK = base.ATK,
		SPD = base.SPD,
		DEF = base.DEF,
		Moves = moves,
	}
	for key, value in extra or {} do
		(g :: any)[key] = value
	end
	return g :: GuardType
end

-- Every Mender heals the most hurt enemy for 1.2% of the leader's HP every other action and rallies
-- the squad every 5th; every Warder taunts and cuts the leader's damage taken by 30%.
local function mender(spell: string, rally: string, hit: string)
	return {
		{ Name = rally, Target = "Ally", Pct = 0, Every = 5, Rally = { Amount = 0.15, Turns = 2 } },
		{ Name = spell, Target = "Ally", Pct = 0, Every = 2, Heal = 0.012 },
		{ Name = hit, Target = "Single", Pct = 0.8 },
	}
end
local WARDER = { Taunt = true, Protect = 0.3 }

local guardList: { GuardType } = {
	guard("ashigaru", "Ash Ashigaru", "🗡️", "Striker", 1, "Flame", Color3.fromRGB(255, 120, 70), {
		{ Name = "Ember Thrust", Target = "Single", Pct = 1.8, Every = 4, Warn = true, Burn = { Pct = 0.1, Turns = 2 } },
		{ Name = "Spear Jab", Target = "Single", Pct = 1 },
	}),
	guard("embermonk", "Ember Monk", "🔥", "Mender", 1, "Light", Color3.fromRGB(255, 170, 90), mender("Cinder Prayer", "War Chant", "Palm Strike")),
	guard("ironclad", "Ironclad", "🛡️", "Warder", 1, "Flame", Color3.fromRGB(170, 120, 100), {
		{ Name = "Quake Stomp", Target = "All", Pct = 0.4, Every = 4 },
		{ Name = "Shield Bash", Target = "Single", Pct = 0.8 },
	}, WARDER),
	guard("frostarcher", "Frost Archer", "🏹", "Hexer", 2, "Frost", Color3.fromRGB(140, 220, 255), {
		{ Name = "Rime Volley", Target = "Random", Pct = 0.6, Hits = 2, Every = 4, Freeze = true },
		{ Name = "Ice Arrow", Target = "Single", Pct = 1 },
	}),
	guard("snowmaiden", "Snow Maiden", "❄️", "Mender", 2, "Light", Color3.fromRGB(200, 235, 255), mender("Frost Bloom", "Winter Hymn", "Snow Lash")),
	guard("glaciergolem", "Glacier Golem", "🧊", "Warder", 2, "Frost", Color3.fromRGB(110, 170, 220), {
		{ Name = "Permafrost", Target = "All", Pct = 0.35, Every = 4, Slow = { Amount = 0.15, Turns = 2 } },
		{ Name = "Ice Fist", Target = "Single", Pct = 0.8 },
	}, WARDER),
	guard("shade", "Void Shade", "🌑", "Striker", 3, "Void", Color3.fromRGB(190, 80, 255), {
		{ Name = "Umbral Rend", Target = "Single", Pct = 2, Every = 4, Warn = true },
		{ Name = "Shadow Claw", Target = "Single", Pct = 1 },
	}),
	guard("nullwitch", "Null Witch", "🔮", "Hexer", 3, "Void", Color3.fromRGB(230, 110, 255), {
		{ Name = "Entropy", Target = "All", Pct = 0.35, Every = 4, Slow = { Amount = 0.2, Turns = 2 } },
		{ Name = "Hex Bolt", Target = "Single", Pct = 1, Burn = { Pct = 0.08, Turns = 2 } },
	}),
	guard("voidknight", "Void Knight", "⚔️", "Warder", 3, "Void", Color3.fromRGB(120, 70, 170), {
		{ Name = "Gravity Well", Target = "All", Pct = 0.4, Every = 4 },
		{ Name = "Null Blade", Target = "Single", Pct = 0.8 },
	}, WARDER),
	guard("thunderhawk", "Thunder Hawk", "🦅", "Striker", 4, "Storm", Color3.fromRGB(255, 230, 90), {
		{ Name = "Talon Storm", Target = "Random", Pct = 0.7, Hits = 3, Every = 4 },
		{ Name = "Dive", Target = "Single", Pct = 1 },
	}, { SPD = 120 }),
	guard("stormpriest", "Storm Priest", "⛈️", "Mender", 4, "Light", Color3.fromRGB(150, 170, 255), mender("Rain of Life", "Thunder Hymn", "Static Touch")),
	guard("raiju", "Raiju", "⚡", "Hexer", 4, "Storm", Color3.fromRGB(255, 210, 60), {
		{ Name = "Paralyze", Target = "Single", Pct = 0.8, Every = 3, Freeze = true },
		{ Name = "Spark Bite", Target = "Random", Pct = 0.5, Hits = 2 },
	}),
}

Bosses.GuardTypes = {} :: { [string]: GuardType }
Bosses.GuardList = guardList
for _, g in guardList do
	assert(Bosses.GuardTypes[g.Id] == nil, `Duplicate guard id "{g.Id}"`)
	Bosses.GuardTypes[g.Id] = g
end

Bosses.List = list
Bosses.ById = {} :: { [string]: Boss }
for _, boss in list do
	assert(Bosses.ById[boss.Id] == nil, `Duplicate boss id "{boss.Id}"`)
	Bosses.ById[boss.Id] = boss
	for _, id in boss.Guards do
		assert(Bosses.GuardTypes[id], `{boss.Id}: unknown guard "{id}"`)
	end
end

function Bosses.Get(id: string): Boss?
	return Bosses.ById[id]
end

-- The elements of a fight's squad, one per enemy, the leader twice (it's the one that must fall):
-- what counter-building weighs cards against. `guards` replaces the boss's own (tower floors, raids).
function Bosses.SquadElements(bossId: string, guards: { string }?): { string }
	local boss = Bosses.Get(bossId)
	if boss == nil then
		return {}
	end
	local list = { boss.Element, boss.Element }
	for _, id in guards or boss.Guards do
		local g = Bosses.GuardTypes[id]
		if g then
			table.insert(list, g.Element)
		end
	end
	return list
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
