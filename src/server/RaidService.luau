--!nonstrict
-- Server raids (Raid.luau has the rules and numbers). This keeps the server's shared pool for the
-- current window: who has joined, how much each has dealt, and whether it's cleared. BattleService runs
-- the raid fights and reports damage as it lands (AddDamage); when the pool runs dry everyone who hit
-- is paid at once and the server gets Raid Luck (ReplicatedStorage attribute RaidLuckEnds, read by
-- MetaService.Luck and the HUD). Clients get the live state on RaidState (throttled) and on RaidInfo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Raid = require(Shared.Raid)

local Remotes = ReplicatedStorage.Remotes
local RateLimit = require(script.Parent.RateLimit)

local RaidService = {}

local BROADCAST_SECONDS = 1

local current = nil -- { Window, Max, Dealt, Cleared, Settled, Hitters = { [userId] = { Name, Damage, Power } } }
local dirty = false
local lastBroadcast = 0
local infoLimiter = RateLimit.new(2, 4)

-- Pays one hitter (set by Main.server to RollService.RaidRewards): returns what the client shows.
local payer: ((player: Player, reward: Raid.Reward) -> any)? = nil

function RaidService.SetPayer(fn)
	payer = fn
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function window(): Raid.Window
	local ends = ReplicatedStorage:GetAttribute("DevRaidEnds")
	return Raid.At(now(), if type(ends) == "number" then { Ends = ends } else nil)
end

local function fresh(w: Raid.Window)
	return { Window = w, Max = 0, Dealt = 0, Cleared = false, Settled = false, Hitters = {} }
end

-- The ranked hitters (most damage first).
local function ranking()
	local list = {}
	if current then
		for userId, hitter in current.Hitters do
			table.insert(list, { UserId = userId, Name = hitter.Name, Damage = hitter.Damage })
		end
	end
	table.sort(list, function(a, b)
		return a.Damage > b.Damage
	end)
	return list
end

-- What every client sees: the window, the pool and the top hitters.
function RaidService.Public()
	local w = if current then current.Window else window()
	local list = ranking()
	local top = {}
	for i = 1, math.min(5, #list) do
		top[i] = list[i]
	end
	local luckEnds = ReplicatedStorage:GetAttribute("RaidLuckEnds")
	return {
		Index = w.Index,
		Boss = w.Colossus.Boss,
		Name = w.Colossus.Name,
		Open = w.Open and not (current and current.Settled),
		Starts = w.Starts,
		Ends = w.Ends,
		Next = w.Next,
		Max = if current then current.Max else 0,
		Dealt = if current then current.Dealt else 0,
		Cleared = current ~= nil and current.Cleared,
		Hitters = #list,
		Top = top,
		LuckEnds = if type(luckEnds) == "number" then luckEnds else nil,
	}
end

local function broadcast()
	dirty = false
	lastBroadcast = os.clock()
	Remotes.RaidState:FireAllClients({ State = RaidService.Public() })
end

-- Pays every hitter still in the server and tells them how it went.
local function settle(cleared: boolean)
	if current == nil or current.Settled then
		return
	end
	current.Settled = true
	current.Cleared = cleared
	if cleared then
		ReplicatedStorage:SetAttribute("RaidLuckEnds", now() + Raid.LuckSeconds)
	end
	local list = ranking()
	local topId = list[1] and list[1].UserId
	for _, entry in list do
		local player = Players:GetPlayerByUserId(entry.UserId)
		local hitter = current.Hitters[entry.UserId]
		if player and hitter and hitter.Damage > 0 then
			local reward = Raid.Reward(cleared, hitter.Damage, hitter.Power, entry.UserId == topId)
			local paid = if payer then payer(player, reward) else nil
			Remotes.RaidState:FireClient(player, {
				Payout = {
					Cleared = cleared,
					Name = current.Window.Colossus.Name,
					Damage = hitter.Damage,
					Rank = table.find(list, entry),
					Hitters = #list,
					Top = entry.UserId == topId,
					Reward = paid,
				},
			})
		end
	end
	broadcast()
end

-- Rolls the window over and closes a raid whose time ran out.
local function tick()
	local w = window()
	if current == nil or current.Window.Index ~= w.Index then
		if current and not current.Settled and next(current.Hitters) ~= nil then
			settle(false)
		end
		current = fresh(w)
		dirty = true
	elseif not current.Settled and now() >= current.Window.Ends then
		if next(current.Hitters) ~= nil then
			settle(false)
		else
			current.Settled = true
			dirty = true
		end
	end
	if dirty and os.clock() - lastBroadcast >= BROADCAST_SECONDS then
		broadcast()
	end
end

-- Whether a raid run can start now ("Closed" | "Cleared" | nil).
function RaidService.CanJoin(): string?
	tick()
	if current == nil or not current.Window.Open or now() >= current.Window.Ends then
		return "Closed"
	end
	if current.Settled then
		return "Cleared"
	end
	return nil
end

-- A player starts a run: their first one this window adds their share to the pool. Returns the run's
-- Colossus (boss id, name, stats) and the window index the run belongs to.
function RaidService.Join(player: Player, power: number)
	local w = current.Window
	local hitter = current.Hitters[player.UserId]
	if hitter == nil then
		hitter = { Name = player.DisplayName, Damage = 0, Power = power }
		current.Hitters[player.UserId] = hitter
		current.Max += Raid.PoolFor(power)
	end
	hitter.Power = math.max(hitter.Power, power) -- rewards follow the strongest deck they brought
	dirty = true
	return { Boss = w.Colossus.Boss, Name = w.Colossus.Name, Stats = Raid.StatsFor(power), Index = w.Index }
end

-- Damage from a run of window `index`, as it lands. Returns true when this cleared the raid.
function RaidService.AddDamage(player: Player, index: number, amount: number): boolean
	if current == nil or current.Window.Index ~= index or current.Settled or amount <= 0 then
		return false
	end
	local hitter = current.Hitters[player.UserId]
	if hitter == nil then
		return false
	end
	amount = math.min(amount, current.Max - current.Dealt)
	hitter.Damage += amount
	current.Dealt += amount
	dirty = true
	if current.Dealt >= current.Max then
		settle(true)
		return true
	end
	return false
end

-- Whether window `index` is over (cleared or closed): running raid fights end when it is.
function RaidService.Done(index: number): boolean
	return current == nil or current.Window.Index ~= index or current.Settled
end

function RaidService.Cleared(index: number): boolean
	return current ~= nil and current.Window.Index == index and current.Cleared
end

-- Test tools: open a raid now (or close the forced one).
function RaidService.Force(open: boolean)
	if open then
		ReplicatedStorage:SetAttribute("DevRaidEnds", now() + Raid.Duration)
	else
		ReplicatedStorage:SetAttribute("DevRaidEnds", nil)
	end
	tick()
	broadcast()
end

function RaidService.Start()
	Remotes.RaidInfo.OnServerInvoke = function(player: Player)
		if not infoLimiter:Allow(player) then
			return nil
		end
		tick()
		return RaidService.Public()
	end
	task.spawn(function()
		while true do
			tick()
			task.wait(0.5)
		end
	end)
	if not Config.TestMode then
		ReplicatedStorage:SetAttribute("DevRaidEnds", nil)
	end
end

return RaidService
