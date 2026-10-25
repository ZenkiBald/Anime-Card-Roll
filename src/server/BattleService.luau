--!nonstrict
-- Boss fights run here, on the server, in real time. The client only asks (start, fire an
-- Ultimate, pick a target, toggle Auto, change speed, give up) and animates the events streamed back.
-- BattleStart(Tower.Id) fights the next floor of the player's Infinite Tower run (Tower.luau; a loss ends
-- the run) and BattleStart(Tower.PagodaId) the next Hundred-Floor Pagoda floor, instead of a boss, both
-- with the day's tower mutator on; BattleStart(Raid.Id) runs a raid run against the server's Colossus
-- (Raid.luau, RaidService): its damage goes into the shared pool as it lands. A boss fight can be a
-- Cost Challenge (BattleStart's 3rd argument { Cost = true }): the deck's cost must be at most
-- Config.Deck.CostCap, and a win pays Config.Deck.CostTraitShards x the Trait Shards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Bosses = require(Shared.Bosses)
local Deck = require(Shared.Deck)
local Meta = require(Shared.Meta)
local Traits = require(Shared.Traits)
local Tower = require(Shared.Tower)
local Raid = require(Shared.Raid)
local Cards = require(Shared.Cards)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)
local RaidService = require(script.Parent.RaidService)
local TutorialService = require(script.Parent.TutorialService)
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
local rewardRolls: ((player: Player, d: number, firstClear: boolean, costChallenge: boolean?) -> any)? = nil
local towerRewards: ((player: Player, floor: number, mode: string, record: boolean) -> any)? = nil

function BattleService.SetRewardHandler(handler, towerHandler)
	rewardRolls = handler
	towerRewards = towerHandler
end

function BattleService.TowerOpen(data): boolean
	return not Config.Unlocks.Enabled or data.Progress.Cleared[Tower.UnlockAfter] == true
end

-- Both towers' progress, for the client: { Best, Run, Pagoda }.
function BattleService.TowerState(data)
	return { Best = data.Tower.Floor, Run = data.Tower.Run, Pagoda = data.Pagoda.Floor }
end

-- Fights are staged in 3D at the boss's own spot in its world (the client's Arena). With streaming on,
-- the client only has the area around its focus, so the fight moves the focus to the boss's marker
-- (and asks for the area at once); it goes back to the character when the fight ends.
local function setArenaFocus(player: Player, bossId: string?)
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Markers")
	local marker = if bossId and markers then markers:FindFirstChild(`Boss_{bossId}`) else nil
	if marker and marker:IsA("BasePart") then
		player.ReplicationFocus = marker
		task.spawn(pcall, player.RequestStreamAroundAsync, player, marker.Position, 5)
	else
		player.ReplicationFocus = nil
	end
end

local function recordResult(player: Player, state)
	local battle = state.Engine
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local data = profile.Data
	local record = { FirstClear = false, NewBest = false }
	if state.Raid then
		-- A raid run: its damage already went into the pool; the payout comes when the raid ends. Only a
		-- run that was fought (not given up at once) counts for the daily quest.
		if battle.Result ~= "Forfeit" and state.Raid.Reported > 0 then
			MetaService.Track(player, "RaidRuns")
		end
		record.Progress = data.Progress
		record.SpeedUnlocked = speedAllowed(data, 2)
		return record
	end
	if state.Floor and state.Mode == Tower.PagodaId then
		-- A Pagoda floor: a win clears it for good (milestones and floor 100's title come with the pay);
		-- a loss changes nothing.
		if battle.Result == "Win" and state.Floor == data.Pagoda.Floor + 1 then
			data.Pagoda.Floor = state.Floor
			record.FirstClear = true
			local milestone = Tower.PagodaMilestones[state.Floor]
			if milestone and milestone.Title then
				data.Titles[milestone.Title] = true
				data.Settings.Title = milestone.Title -- the Pagoda's crown is worn at once (name tag, profile)
			end
			MetaService.Track(player, "TowerFloors")
			MetaService.AddXP(player, data, math.ceil(Meta.XP.BossWinPerD * Tower.PagodaReward(state.Floor).D))
		end
		record.Progress = data.Progress
		record.Tower = BattleService.TowerState(data)
		record.SpeedUnlocked = speedAllowed(data, 2)
		return record
	end
	if state.Floor then
		-- An Infinite Tower floor: a win climbs the run one floor (a floor above the best run is a record:
		-- its Guardian bonuses pay); a loss or GIVE UP ends the run.
		data.Tower.Live = nil
		if battle.Result == "Win" and state.Floor == data.Tower.Run + 1 then
			data.Tower.Run = state.Floor
			record.FirstClear = state.Floor > data.Tower.Floor -- a record floor
			if record.FirstClear then
				data.Tower.Floor = state.Floor
				record.NewBest = true
			end
			MetaService.Track(player, "TowerFloors")
			MetaService.AddXP(player, data, math.ceil(Meta.XP.BossWinPerD * Tower.Reward(state.Floor).D))
		elseif battle.Result ~= "Win" then
			record.RunEnded = data.Tower.Run -- floors this run climbed
			data.Tower.Run = 0
		end
		record.Progress = data.Progress
		record.Tower = BattleService.TowerState(data)
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
		local raid = state.Raid
		if raid and (battle.Over or sinceFlush >= FLUSH_SECONDS) then
			-- Raid damage drains the server's pool as it lands; the run ends once the raid is over.
			local dealt = battle.Boss.MaxHP - battle.Boss.HP
			if dealt > raid.Reported then
				RaidService.AddDamage(player, raid.Index, dealt - raid.Reported)
				raid.Reported = dealt
			end
			if not battle.Over and RaidService.Done(raid.Index) then
				battle:Finish(if RaidService.Cleared(raid.Index) then "Win" else "Timeout")
			end
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
	setArenaFocus(player, nil)
	local summary = battle:Summary()
	if (summary.CounterStaggers or 0) > 0 then
		TutorialService.Note(player, "CounterStagger") -- Kenji's last quest
	end
	local record = recordResult(player, state)
	if record then
		summary.FirstClear = record.FirstClear
		summary.NewBest = record.NewBest
		summary.Progress = record.Progress
		summary.Tower = record.Tower
		summary.Floor = state.Floor
		summary.Mode = state.Mode
		summary.RunEnded = record.RunEnded
		summary.SpeedUnlocked = record.SpeedUnlocked
		if state.Raid then
			summary.Raid = { Dealt = state.Raid.Reported, Name = state.Raid.Name, State = RaidService.Public() }
		end
		local boss = Bosses.Get(battle.BossId)
		if state.Raid then
			-- paid by RaidService when the raid ends
		elseif state.Floor then
			if battle.Result == "Win" and towerRewards then
				summary.Rewards = towerRewards(player, state.Floor, state.Mode, record.FirstClear)
			end
		elseif battle.Result == "Win" and rewardRolls and boss then
			summary.Rewards = rewardRolls(player, boss.Difficulties[battle.Difficulty].D, record.FirstClear, state.Cost)
			summary.CostChallenge = state.Cost
			-- A first Normal clear puts the boss's own card into this player's roll pool (Cards.Pool).
			local bossCard = Cards.ForBoss(boss.Id)
			if record.FirstClear and battle.Difficulty == "Normal" and bossCard then
				summary.CardUnlocked = bossCard.Id
			end
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
		setArenaFocus(player, nil)
		Remotes.BattleEvent:FireClient(player, { Done = { Result = "Stopped" } })
	end
end

-- The saved deck is checked again here: the fight only ever uses owned cards. `mutator` (the tower's
-- daily one) adds its boon to the matching cards like an extra trait.
local function deckUnits(data, deck, mutator: Tower.Mutator?)
	local units = {}
	for _, row in Deck.Rows do
		for i, id in deck[row] do
			if id ~= "" then
				local owned = data.Cards[id]
				local card = Cards.Get(id)
				local node = Awaken.Level(owned)
				-- Unit effects: both trait slots (slot 2 once it's open), the best foil, Awakening, mutator.
				local slot2 = if node >= Traits.Slot2Node then owned.Trait2 else nil
				local effects = Traits.SlotEffects(owned.Trait, slot2)
				for _, list in { Foils.Effects(Foils.Best(owned.Foils)), Awaken.Effects(node), Tower.MutatorEffects(mutator, card and card.Element or "") } do
					for _, effect in list do
						table.insert(effects, effect)
					end
				end
				table.insert(units, {
					Id = `{string.sub(row, 1, 1)}{i}`,
					CardId = id,
					Stars = owned.Stars,
					Border = Deck.PlayBorder(owned),
					Awaken = node,
					Trait = effects,
				})
			end
		end
	end
	return units
end

local function start(player: Player, bossId: unknown, difficulty: unknown, options: unknown)
	if type(bossId) ~= "string" then
		return { Ok = false, Reason = "BadRequest" }
	end
	local isTower = bossId == Tower.Id or bossId == Tower.PagodaId
	local isRaid = bossId == Raid.Id
	local boss = Bosses.Get(bossId)
	if not isTower and not isRaid and (boss == nil or type(difficulty) ~= "string" or boss.Difficulties[difficulty] == nil) then
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

	-- The Infinite Tower fights the next floor of the run, the Pagoda its next floor.
	local floor = nil
	local stats = nil
	local mutator = nil
	if isRaid then
		local reason = RaidService.CanJoin()
		if reason then
			return { Ok = false, Reason = reason }
		end
	elseif isTower then
		if not BattleService.TowerOpen(data) then
			return { Ok = false, Reason = "Locked" }
		end
		if bossId == Tower.PagodaId then
			if data.Pagoda.Floor >= Tower.Pagoda.Floors then
				return { Ok = false, Reason = "Conquered" }
			end
			floor = Tower.FloorAt(data.Pagoda.Floor + 1, nil, nil, Tower.PagodaId)
		else
			floor = Tower.FloorAt(data.Tower.Run + 1)
		end
		local devMutator = ReplicatedStorage:GetAttribute("DevMutator")
		mutator = Tower.MutatorToday(Meta.DayNumber(os.time()), if Config.TestMode and type(devMutator) == "string" then devMutator else nil)
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
	local deckPower = Deck.Power(deck, data.Cards)

	-- The Cost Challenge: boss fights only, and the deck must fit the cap.
	local cost = type(options) == "table" and (options :: any).Cost == true and boss ~= nil and not isTower and not isRaid
	if cost and Deck.Cost(deck, data.Cards) > Config.Deck.CostCap then
		return { Ok = false, Reason = "TooCostly" }
	end

	-- A raid run: the Colossus alone, sized to this deck, for Raid.FightSeconds.
	local raid = nil
	if isRaid then
		raid = RaidService.Join(player, deckPower)
		boss = Bosses.Get(raid.Boss)
		difficulty = Raid.Difficulty
		stats = { HP = raid.Stats.HP, ATK = raid.Stats.ATK, WarnSeconds = raid.Stats.WarnSeconds, BarrierHP = raid.Stats.Base }
	end

	local battle = Engine.new({
		Units = deckUnits(data, deck, mutator),
		BossId = boss.Id,
		Difficulty = difficulty,
		Rng = Random.new(),
		Stats = stats,
		Guards = if raid then {} else floor and floor.Guards,
		TimeLimit = if raid then Raid.FightSeconds else nil,
	})
	battle.AutoUlt = data.Settings.AutoUlt == true
	local speed = if speedAllowed(data, data.Settings.BattleSpeed) then data.Settings.BattleSpeed else 1
	local state = {
		Engine = battle,
		Speed = speed,
		Started = false,
		Floor = floor and floor.Floor,
		Mode = floor and floor.Mode,
		Cost = cost or nil,
		Raid = if raid then { Index = raid.Index, Name = raid.Name, Reported = 0 } else nil,
	}
	active[player] = state
	if floor and floor.Mode == Tower.Id then
		data.Tower.Live = floor.Floor -- leaving before it ends loses the run (SaveMigration)
	end
	setArenaFocus(player, boss.Id)
	task.spawn(run, player, state)

	return {
		Ok = true,
		Info = battle:Info(),
		Tower = floor, -- the floor being fought (nil for a boss fight)
		Mutator = if mutator then mutator.Id else nil, -- the day's tower mutator
		Raid = if raid then { Name = raid.Name, State = RaidService.Public() } else nil,
		Snap = battle:Snapshot(),
		AutoUlt = battle.AutoUlt,
		Speed = speed,
		SpeedUnlocked = speedAllowed(data, 2),
		Intro = B.IntroSeconds,
		DeckPower = deckPower,
		CostChallenge = cost or nil,
	}
end

function BattleService.Start()
	Remotes.BattleStart.OnServerInvoke = function(player: Player, bossId: unknown, difficulty: unknown, options: unknown)
		if not startLimiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		return start(player, bossId, difficulty, options)
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
