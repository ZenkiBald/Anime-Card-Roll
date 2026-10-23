--!nonstrict
-- Boss fights run here, on the server, in real time. The client only asks (start, fire an
-- Ultimate, pick a target, toggle Auto, change speed, give up) and animates the events streamed back.
-- BattleStart(Tower.Id) fights the player's next Infinite Tower floor (Tower.luau) instead of a boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Bosses = require(Shared.Bosses)
local Deck = require(Shared.Deck)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local Tower = require(Shared.Tower)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)
local Engine = require(script.Parent.BattleEngine)

local BattleService = {}

local B = Config.Battle
local FLUSH_SECONDS = 0.15 -- how often event batches go to the client

local active = {} -- [Player] = { Engine, Speed, Started }
local startLimiter = RateLimit.new(1, 3)
local inputLimiter = RateLimit.new(15, 30)

local function speedAllowed(data, speed: unknown): boolean
	if speed == 1 then
		return true
	end
	if not table.find(B.Speeds, speed) then
		return false
	end
	return not Config.Unlocks.Enabled or data.Progress.Cleared[B.SpeedUnlock] == true
end

-- Pays boss and tower rewards; set by Main.server to RollService.RewardRolls / TowerRewards
-- (RollService needs this module).
local rewardRolls: ((player: Player, d: number, firstClear: boolean) -> any)? = nil
local towerRewards: ((player: Player, floor: number) -> any)? = nil

function BattleService.SetRewardHandler(handler, towerHandler)
	rewardRolls = handler
	towerRewards = towerHandler
end

function BattleService.TowerOpen(data): boolean
	return not Config.Unlocks.Enabled or data.Progress.Cleared[Tower.UnlockAfter] == true
end

local function recordResult(player: Player, state)
	local battle = state.Engine
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local data = profile.Data
	local record = { FirstClear = false, NewBest = false }
	if state.Floor then
		-- A tower floor: a win moves the player up one (only the next floor can be fought, so every
		-- win is a first clear and pays once).
		if battle.Result == "Win" and state.Floor == data.Tower.Floor + 1 then
			data.Tower.Floor = state.Floor
			record.FirstClear = true
			record.NewBest = true
			MetaService.Track(player, "TowerFloors")
			MetaService.AddXP(player, data, math.ceil(Meta.XP.BossWinPerD * Tower.Reward(state.Floor).D))
		end
		record.Progress = data.Progress
		record.Tower = data.Tower.Floor
		record.SpeedUnlocked = speedAllowed(data, 2)
		return record
	end
	local key = Bosses.FightKey(battle.BossId, battle.Difficulty)
	if battle.Result == "Win" then
		record.FirstClear = data.Progress.Cleared[key] ~= true
		data.Progress.Cleared[key] = true
		local time = math.floor(battle.Time * 10) / 10
		local best = data.Progress.BestTime[key]
		if best == nil or time < best then
			data.Progress.BestTime[key] = time
			record.NewBest = true
		end
		MetaService.Track(player, "BossWins")
		local fight = Bosses.Get(battle.BossId)
		local d = fight and fight.Difficulties[battle.Difficulty] and fight.Difficulties[battle.Difficulty].D or 1
		MetaService.AddXP(player, data, Meta.XP.BossWinPerD * d)
		if battle.Difficulty ~= "Normal" then
			MetaService.Track(player, "HardWins")
		end
	end
	record.Progress = data.Progress
	record.SpeedUnlocked = speedAllowed(data, 2)
	return record
end

local function run(player: Player, state)
	local battle = state.Engine
	task.wait(B.IntroSeconds)
	state.Started = true

	local pending = 0 -- battle seconds not yet simulated
	local sinceFlush = 0
	while active[player] == state and player.Parent == Players do
		local dt = RunService.Heartbeat:Wait()
		pending += dt * state.Speed
		sinceFlush += dt
		while pending >= B.Tick and not battle.Over do
			battle:Step(B.Tick)
			pending -= B.Tick
		end
		if battle.Over or sinceFlush >= FLUSH_SECONDS then
			sinceFlush = 0
			Remotes.BattleEvent:FireClient(player, { Events = battle:TakeEvents(), Snap = battle:Snapshot() })
		end
		if battle.Over then
			break
		end
	end

	if active[player] ~= state then
		return -- stopped from outside (player left, test-data reset)
	end
	active[player] = nil
	local summary = battle:Summary()
	local record = recordResult(player, state)
	if record then
		summary.FirstClear = record.FirstClear
		summary.NewBest = record.NewBest
		summary.Progress = record.Progress
		summary.Tower = record.Tower
		summary.Floor = state.Floor
		summary.SpeedUnlocked = record.SpeedUnlocked
		local boss = Bosses.Get(battle.BossId)
		if state.Floor then
			if record.FirstClear and towerRewards then
				summary.Rewards = towerRewards(player, state.Floor)
			end
		elseif battle.Result == "Win" and rewardRolls and boss then
			summary.Rewards = rewardRolls(player, boss.Difficulties[battle.Difficulty].D, record.FirstClear)
		end
	end
	if player.Parent == Players then
		Remotes.BattleEvent:FireClient(player, { Done = summary })
	end
end

function BattleService.InBattle(player: Player): boolean
	return active[player] ~= nil
end

-- Ends a fight without a result (used by the test-data reset).
function BattleService.Stop(player: Player)
	if active[player] then
		active[player] = nil
		Remotes.BattleEvent:FireClient(player, { Done = { Result = "Stopped" } })
	end
end

-- The saved deck is checked again here: the fight only ever uses owned cards.
local function deckUnits(data, deck)
	local units = {}
	for _, row in Deck.Rows do
		for i, id in deck[row] do
			if id ~= "" then
				local owned = data.Cards[id]
				table.insert(units, {
					Id = `{string.sub(row, 1, 1)}{i}`,
					CardId = id,
					Stars = owned.Stars,
					Fusion = owned.Fusion,
					Border = Borders.Best(owned.Borders),
					Trait = Traits.Effects(owned.Trait),
				})
			end
		end
	end
	return units
end

local function start(player: Player, bossId: unknown, difficulty: unknown)
	if type(bossId) ~= "string" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local isTower = bossId == Tower.Id
	local boss = Bosses.Get(bossId)
	if not isTower and (boss == nil or type(difficulty) ~= "string" or boss.Difficulties[difficulty] == nil) then
		return { Ok = false, Reason = "BadRequest" }
	end
	if active[player] then
		return { Ok = false, Reason = "InBattle" }
	end
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	local data = profile.Data

	-- The tower always fights the floor above the player's best: the server picks it, not the client.
	local floor = nil
	local stats = nil
	if isTower then
		if not BattleService.TowerOpen(data) then
			return { Ok = false, Reason = "Locked" }
		end
		floor = Tower.FloorAt(data.Tower.Floor + 1)
		boss = Bosses.Get(floor.Boss)
		difficulty = floor.Difficulty
		stats = { HP = floor.HP, ATK = floor.ATK, WarnSeconds = floor.WarnSeconds, DEF = floor.DEF, SPD = floor.SPD }
	elseif not Bosses.IsUnlocked(data.Progress.Cleared, boss.Id, difficulty) then
		return { Ok = false, Reason = "Locked" }
	end

	local deck = DeckService.Active(data)
	if Deck.Count(deck, "Attack") == 0 then
		return { Ok = false, Reason = "NoAttack" }
	end

	local battle = Engine.new({
		Units = deckUnits(data, deck),
		BossId = boss.Id,
		Difficulty = difficulty,
		Rng = Random.new(),
		Stats = stats,
		Guards = floor and floor.Guards,
	})
	battle.AutoUlt = data.Settings.AutoUlt == true
	local speed = if speedAllowed(data, data.Settings.BattleSpeed) then data.Settings.BattleSpeed else 1
	local state = { Engine = battle, Speed = speed, Started = false, Floor = floor and floor.Floor }
	active[player] = state
	task.spawn(run, player, state)

	return {
		Ok = true,
		Info = battle:Info(),
		Tower = floor, -- the floor being fought (nil for a boss fight)
		Snap = battle:Snapshot(),
		AutoUlt = battle.AutoUlt,
		Speed = speed,
		SpeedUnlocked = speedAllowed(data, 2),
		Intro = B.IntroSeconds,
		DeckPower = Deck.Power(deck, data.Cards),
	}
end

function BattleService.Start()
	Remotes.BattleStart.OnServerInvoke = function(player: Player, bossId: unknown, difficulty: unknown)
		if not startLimiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		return start(player, bossId, difficulty)
	end

	Remotes.BattleInput.OnServerEvent:Connect(function(player: Player, action: unknown, value: unknown)
		if not inputLimiter:Allow(player) then
			return
		end
		local state = active[player]
		local profile = DataService.Get(player)
		if action == "Auto" then
			if type(value) ~= "boolean" or profile == nil then
				return
			end
			profile.Data.Settings.AutoUlt = value
			if state then
				state.Engine.AutoUlt = value
			end
		elseif action == "Speed" then
			if profile == nil or not speedAllowed(profile.Data, value) then
				return
			end
			profile.Data.Settings.BattleSpeed = value
			if state then
				state.Speed = value
			end
		elseif state == nil then
			return
		elseif action == "Ultimate" then
			-- The engine checks the card is alive, has an Ultimate and 100 energy.
			if type(value) == "string" and state.Started then
				state.Engine:UseUltimate(value)
			end
		elseif action == "Target" then
			-- Focus fire: an enemy id (the engine checks it's a living enemy) or nil to let cards pick.
			if value == nil or type(value) == "string" then
				state.Engine:SetFocus(value)
			end
		elseif action == "Forfeit" then
			state.Engine:Forfeit()
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		active[player] = nil
	end)
end

return BattleService
