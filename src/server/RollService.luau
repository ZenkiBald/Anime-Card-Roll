--!nonstrict
-- Every roll happens here, on the server. The client only asks and then animates.
-- Every pull rolls a card (Cards.Pool: each card's Weight; boss cards join after their boss's first
-- Normal clear), a border (the tier: Borders.luau, raised by luck) and a foil (Foils.luau); its copies
-- open Awakening nodes (Awaken.luau) and pile up per border for Hoshi's border fusion. Traits are not rolled here any more (TraitService).
-- Card rolls build the Momentum chain and every 25th is an Overcharge Surge (RollBoost.luau); the
-- Triple Roll pass rolls 3 per click. Roll Packs open here too, and Pack Alchemy condenses / infuses them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Rewards = require(Shared.Rewards)
local Bosses = require(Shared.Bosses)
local Tower = require(Shared.Tower)
local Packs = require(Shared.Packs)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DeckService = require(script.Parent.DeckService)
local BattleService = require(script.Parent.BattleService)
local MetaService = require(script.Parent.MetaService)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)
local Items = require(Shared.Items)
local Traits = require(Shared.Traits)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)
local RollBoost = require(Shared.RollBoost)
local MonetizationConfig = require(Shared.MonetizationConfig)
local RateLimit = require(script.Parent.RateLimit)
local RaidService = require(script.Parent.RaidService)
local MonetizationService = require(script.Parent.MonetizationService)
local Momentum = require(script.Parent.Momentum)
local TutorialService = require(script.Parent.TutorialService)
local NpcRange = require(script.Parent.NpcRange)
local AvatarService = require(script.Parent.AvatarService)

local RollService = {}

local rng = Random.new()

local lastRoll = {} -- [Player] = os.clock() of their last roll
local openLimiter = RateLimit.new(1, 2) -- opening Roll Packs: one a second
local fastOpenLimiter = RateLimit.new(MonetizationConfig.TriplePackSpeed, MonetizationConfig.TriplePackSpeed * 2) -- Triple Roll pass
local alchemyLimiter = RateLimit.new(4, 8)
local autoGeneration = {} -- [Player] = number; bumping it stops the running Auto Roll loop
local autoActive = {} -- [Player] = true while Auto Roll is running

local COOLDOWN_TOLERANCE = 0.1 -- forgive small network timing differences

-- The player's own luck: base (1x + Lucky Charm + Index rewards, or the dev panel's value)
-- times the strongest running luck potion, capped at Config.Roll.LuckCap.
local function luckFor(player: Player, data): number
	return MetaService.Luck(player, data)
end

local function cooldownFor(data, player: Player?): number
	return MetaService.Cooldown(data, player)
end

local function isUnlocked(player: Player, data, feature: string): boolean
	if not Config.Unlocks.Enabled then
		return true
	end
	if feature == "AutoRoll" and MonetizationService.Perk(player, "AutoRoll") then
		return true -- the Auto Roll pass opens it from the start
	end
	local rule = Config.Unlocks[feature]
	return data.TotalRolls >= rule.Rolls and DataService.Playtime(player) >= rule.Seconds
end

-- Everything the client needs to draw the HUD.
local function summary(player: Player, data)
	return {
		TotalRolls = data.TotalRolls,
		Shards = data.Shards,
		Luck = luckFor(player, data),
		Cooldown = cooldownFor(data, player),
		TraitShards = data.TraitShards or 0,
		Momentum = Momentum.State(player),
		UntilSurge = RollBoost.UntilSurge(data.TotalRolls),
		SurgeProgress = RollBoost.SurgeProgress(data.TotalRolls), -- 0-24: the surge meter (TotalRolls % 25)
		IsSurgeRoll = RollBoost.IsSurgeRoll(data.TotalRolls), -- the last roll was a surge
		AutoStop = data.Settings.AutoStop,
		AutoActive = autoActive[player] == true,
		Playtime = DataService.Playtime(player),
		Unlocked = {
			QuickRoll = isUnlocked(player, data, "QuickRoll"),
			AutoRoll = isUnlocked(player, data, "AutoRoll"),
		},
	}
end

local function fullState(player: Player, data)
	local cards = {}
	for id, entry in data.Cards do
		cards[id] = DataService.CardState(entry)
	end
	return {
		Ok = true,
		Cards = cards,
		Summary = summary(player, data),
		Decks = DeckService.State(data, player),
		Progress = data.Progress,
		Tower = data.Tower.Floor,
		Packs = data.Packs,
		Battle = { AutoUlt = data.Settings.AutoUlt, Speed = data.Settings.BattleSpeed },
		Mount = data.Settings.Mount,
		Meta = MetaService.State(player, data),
		TestMode = Config.TestMode,
	}
end

export type RollOptions = {
	BorderMult: number?, -- x border odds (surges, infused packs under a luck boost)
	FoilMult: number?, -- x foil odds (perfect surges)
	Element: string?, -- infused packs: this element's cards weigh Packs.InfuseWeight in the pool
	Surge: string?, -- "Plain" | "Perfect": tagged on the result for the reveal
}

-- A card from the player's pool by Weight (the infused element's cards weighted up).
local function pickCard(data, element: string?)
	local pool = Cards.Pool(data.Progress.Cleared)
	local chances = Cards.PullChances(pool, element, Packs.InfuseWeight)
	local target = rng:NextNumber()
	for _, card in pool do
		target -= chances[card.Id]
		if target < 0 then
			return card
		end
	end
	return pool[#pool]
end

-- Adds one copy of a card at a border: the per-border count (for Hoshi's border fusion) and the set of
-- borders it has found (it wears the best).
local function addCopy(entry, border: string): boolean
	entry.BorderCopies = entry.BorderCopies or {}
	entry.BorderCopies[border] = (entry.BorderCopies[border] or 0) + 1
	local new = false
	if border ~= "Normal" then
		entry.Borders = entry.Borders or {}
		new = entry.Borders[border] ~= true
		entry.Borders[border] = true
	end
	return new
end
RollService.AddCopy = addCopy

-- One roll: pick a card, roll its border (the tier; luck raises it, no pity: pure luck) and a foil, apply
-- duplicates. Duplicates add stars up to the max and pile up as copies at their border for Hoshi
-- (FusionService); every 20 copies open an Awakening node.
-- luck defaults to the player's own luck.
-- `batch` (opening a Roll Pack): XP is added up in batch.XP for one AddXP at the end, nothing is
-- announced (the pack announces its best pull), and the result skips the HUD summary and quests.
local function doRoll(player: Player, profile, luck: number?, batch: { XP: number }?, opts: RollOptions?)
	local data = profile.Data
	local o = opts or {}

	local card = pickCard(data, o.Element)
	-- The border: the tier. Luck, the Border Chance stat / artifacts and surge / pack multipliers raise it.
	local borderBoost = (1 + Meta.Bonus(data.Stats, data.Gear, "Border")) * (o.BorderMult or 1) - 1
	local rollLuck = luck or luckFor(player, data)
	local border = Borders.Pick(rng:NextNumber(), borderBoost, rollLuck)

	data.TotalRolls += 1
	MetaService.Track(player, "Rolls")
	if border ~= "Normal" then
		MetaService.Track(player, "EpicPulls") -- the "special pull" quest: any Gold or better border
	end

	local entry = data.Cards[card.Id]
	local outcome = "New"
	if entry == nil then
		entry = { Copies = 1, Stars = 0 }
		data.Cards[card.Id] = entry
	elseif entry.Stars < Config.MaxStars then
		entry.Copies += 1
		entry.Stars += 1
		outcome = "Star"
	else
		entry.Copies += 1
		outcome = "Copy"
	end
	local xp = Meta.XP.Roll + (if outcome == "New" then Meta.XP.NewCard else 0)
	if batch then
		batch.XP += xp
	else
		MetaService.AddXP(player, data, xp)
	end

	-- Awakening: every 20 copies open a node, for good.
	local oldNode = entry.Awaken or 0
	local node = math.max(oldNode, Awaken.FromCopies(entry.Copies))
	entry.Awaken = if node > 0 then node else nil
	local newNode = if node > oldNode then node else nil

	-- The copy goes on the pile of its border; the card keeps every border it has found and wears the best.
	local newBorder = addCopy(entry, border)
	if newBorder and profile.Data.Settings.Avatar == card.Id then
		AvatarService.Apply(player) -- the worn card found a better border: its trail changes now
	end

	-- And a foil (Foils.luau), kept the same way.
	local foil = Foils.Pick(rng:NextNumber(), o.FoilMult)
	local newFoil = false
	if foil ~= "standard" then
		entry.Foils = entry.Foils or {}
		newFoil = entry.Foils[foil] ~= true
		entry.Foils[foil] = true
	end

	local big = Borders.Index(border) >= Borders.Index(Config.AnnounceFrom) or foil == "demon"
	if batch == nil and big then
		Remotes.Announce:FireAllClients(player.DisplayName, card.Id, border, foil)
	end

	return {
		Ok = true,
		CardId = card.Id,
		Outcome = outcome, -- "New" | "Star" | "Copy" (toward fusion)
		Stars = entry.Stars,
		Copies = entry.Copies,
		BorderCopies = entry.BorderCopies,
		Border = border, -- the border this pull rolled (the tier)
		NewBorder = newBorder, -- first time this card got it
		Borders = entry.Borders, -- every border the card has found
		Foil = foil, -- the foil this pull rolled
		NewFoil = newFoil,
		Foils = entry.Foils,
		Awaken = entry.Awaken,
		NewNode = newNode, -- an Awakening node this pull opened
		CardTrait = entry.Trait, -- the card's trait (rolled at the Trait Master)
		Surge = o.Surge,
		Summary = if batch then nil else summary(player, data),
		Quests = if batch then nil else MetaService.QuestState(player, data), -- roll quests tick with every roll
	}
end

-- A click (or an Auto Roll step): the Momentum chain grows, and the 25th roll is an Overcharge Surge.
-- `perfect`: hit inside the surge window (or Auto with the Auto Roll pass). The Triple Roll pass adds
-- two cards to every click. Returns the main result, with the others in Extra.
local function rollClick(player: Player, profile, perfect: boolean, click: boolean)
	local data = profile.Data
	local surge = RollBoost.IsSurge(data.TotalRolls + 1)
	local cfg = RollBoost.Surge
	local main, count, mult, foilMult
	if surge and perfect then
		main = doRoll(player, profile, nil, nil, { BorderMult = cfg.PerfectBorderMult, FoilMult = cfg.PerfectFoilMult, Surge = "Perfect" })
		count, mult, foilMult = cfg.PerfectCards, cfg.PerfectBorderMult, cfg.PerfectFoilMult
	elseif surge then
		main = doRoll(player, profile, nil, nil, { BorderMult = cfg.BorderMult, FoilMult = cfg.FoilMult, Surge = "Plain" })
		count, mult = 1, nil
	else
		main = doRoll(player, profile)
		count = 1
	end
	if click and MonetizationService.Perk(player, "TripleRoll", true) then
		count = math.max(count, MonetizationConfig.TripleRollCards)
	end
	local extra = {}
	for _ = 2, count do
		table.insert(extra, doRoll(player, profile, nil, nil, { BorderMult = mult, FoilMult = foilMult }))
	end
	main.Extra = if #extra > 0 then extra else nil

	local before = Momentum.Count(player)
	local after = Momentum.Add(player, count)
	if before < 100 and after >= 100 then
		MetaService.Track(player, "Momentum100")
	end
	main.Summary = summary(player, data)
	main.Quests = MetaService.QuestState(player, data)
	return main
end

-- Pays a win: Roll Packs into the player's packs (opened later, at their luck then), Shards, a potion
-- (sure, or by chance) and a roll for an artifact at `d` (Items.RollDrops, x `boost`).
local function payWin(player: Player, profile, packs: { [string]: number }?, shards: number, potion: string?, potionChance: number, d: number, boost: number, traitShards: number?)
	local held = profile.Data.Packs
	for id, count in (packs or {}) :: { [string]: number } do
		held[id] = (held[id] or 0) + count
	end
	local bundle = { Shards = shards, Potions = {}, TraitShards = traitShards }
	if potion and rng:NextNumber() < potionChance then
		bundle.Potions[potion] = 1
	end
	local drops = Items.RollDrops(d, rng, boost)
	bundle.Artifacts = drops.Artifacts
	bundle = MetaService.Grant(profile.Data, bundle, player) -- the screen shows the Shard Gain bonus too
	return {
		NewPacks = packs, -- what this win dropped
		Packs = held, -- everything held now
		Bundle = bundle,
		Summary = summary(player, profile.Data),
		Meta = MetaService.State(player, profile.Data),
	}
end

local function rarer(a, b): boolean
	local ba, bb = Borders.Index(a.Border), Borders.Index(b.Border)
	if ba ~= bb then
		return ba > bb
	end
	return (Cards.Get(a.CardId) :: any).Weight < (Cards.Get(b.CardId) :: any).Weight -- the less likely card
end

-- Opens one Roll Pack: its rolls at the player's luck right now. Returns the rarest ShowCards pulls in
-- full (for the flip reveal), how many of each border came out, how many were new, and the touched
-- cards' new state; XP is paid once and only the best pull is announced.
local function openPack(player: Player, profile, pack: Packs.Pack)
	local data = profile.Data
	local batch = { XP = 0 }
	local luck = luckFor(player, data)
	-- An infused pack leans toward its element, and doubles border odds under a luck boost.
	local opts = nil
	if pack.Element then
		local event = MetaService.Event()
		local boosted = (event ~= nil and event.Luck ~= nil) or MetaService.ServerLuck() > 1
		opts = { Element = pack.Element, BorderMult = if boosted then Packs.InfuseBorderMult else nil }
	end
	local shown, counts, cards = {}, {}, {}
	local newCards = 0
	for _ = 1, pack.Rolls do
		local result = doRoll(player, profile, luck, batch, opts)
		counts[result.Border] = (counts[result.Border] or 0) + 1
		if result.Outcome == "New" then
			newCards += 1
		end
		cards[result.CardId] = true
		-- Keep the rarest few for the reveal.
		if #shown < Packs.ShowCards then
			table.insert(shown, result)
			table.sort(shown, rarer)
		elseif rarer(result, shown[#shown]) then
			shown[#shown] = result
			table.sort(shown, rarer)
		end
	end
	MetaService.AddXP(player, data, batch.XP)
	local best = shown[1]
	if best and Borders.Index(best.Border) >= Borders.Index(Config.AnnounceFrom) then
		Remotes.Announce:FireAllClients(player.DisplayName, best.CardId, best.Border)
	end
	local state = {}
	for id in cards do
		state[id] = DataService.CardState(data.Cards[id])
	end
	return shown, counts, newCards, state, luck
end

function RollService.RewardRolls(player: Player, d: number, firstClear: boolean, costChallenge: boolean?)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	-- Every win drops Roll Packs, pays Shards and Trait Shards (x2 on a Cost Challenge), may drop a
	-- potion, and rolls for an artifact (Items.luau: better odds and rarer artifacts on harder fights).
	local reward = Rewards.For(d)
	local traitShards = Rewards.TraitShards(d, firstClear) * (if costChallenge then Config.Deck.CostTraitShards else 1)
	return payWin(player, profile, Packs.ForBoss(d, firstClear), reward.Shards, reward.Potion, Config.Rewards.PotionChance, d, 1, traitShards)
end

-- A cleared Infinite Tower floor (paid once per floor): Tower.Reward says what. Some floors drop Roll
-- Packs; Guardians add more Shards, a sure potion and boosted gear odds.
function RollService.TowerRewards(player: Player, floor: number)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local reward = Tower.Reward(floor)
	return payWin(player, profile, reward.Packs, reward.Shards, reward.Potion, 1, reward.D, reward.DropBoost, reward.TraitShards)
end

-- A raid payout for a hitter who left before the raid ended: the same reward, built into one bundle
-- (artifact roll included) and sent to their save as a message; it lands when they next play.
function RollService.RaidRewardsOffline(userId: number, reward, name: string)
	local bundle = { Shards = reward.Shards, TraitShards = reward.TraitShards, Packs = reward.Packs }
	bundle.Artifacts = Items.RollDrops(reward.D, rng, reward.DropBoost).Artifacts
	DataService.SendMessage(userId, { Kind = "Grant", Source = "Raid", Note = name, Bundle = bundle })
end

-- Sends the HUD summary on its own (e.g. when the Momentum chain breaks).
function RollService.PushSummary(player: Player)
	local profile = DataService.Get(player)
	if profile and player.Parent == Players then
		Remotes.AutoResult:FireClient(player, { Ok = false, SummaryOnly = true, Summary = summary(player, profile.Data) })
	end
end

-- A raid's payout to one hitter (RaidService calls this when the raid ends): Raid.Reward says what.
function RollService.RaidRewards(player: Player, reward)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	return payWin(player, profile, reward.Packs, reward.Shards, nil, 0, reward.D, reward.DropBoost, reward.TraitShards)
end

local function cooldownLeft(player: Player): number
	local last = lastRoll[player]
	local profile = DataService.Get(player)
	if last == nil or profile == nil then
		return 0
	end
	return cooldownFor(profile.Data, player) - (os.clock() - last)
end

local function stopAuto(player: Player)
	autoGeneration[player] = (autoGeneration[player] or 0) + 1
	autoActive[player] = nil
end

local function startAuto(player: Player)
	stopAuto(player) -- ends any loop that is still winding down
	local generation = autoGeneration[player]
	autoActive[player] = true

	task.spawn(function()
		while autoGeneration[player] == generation and player.Parent == Players do
			local wait = cooldownLeft(player)
			if wait > 0 then
				task.wait(wait)
			end
			if autoGeneration[player] ~= generation then
				break
			end

			local profile = DataService.Get(player)
			if profile == nil then
				break
			end

			lastRoll[player] = os.clock()
			-- Surges on Auto are plain, unless the Auto Roll pass hits them perfectly.
			local result = rollClick(player, profile, MonetizationService.Perk(player, "AutoRoll", true), false)

			local stopAt = profile.Data.Settings.AutoStop
			-- A NEW Rainbow or Secret border (or Demon Seal) always stops Auto Roll, so its reveal can play.
			local hitStop = false
			for _, r in { result, table.unpack(result.Extra or {}) } do
				local bigBorder = r.NewBorder and Borders.Index(r.Border) >= Borders.Index("Rainbow")
				local bigFoil = r.NewFoil and r.Foil == "demon"
				hitStop = hitStop or (stopAt ~= "Never" and Borders.Index(r.Border) >= Borders.Index(stopAt)) or bigBorder or bigFoil
			end
			if hitStop then
				stopAuto(player)
				result.Summary.AutoActive = false
			end
			result.Stopped = hitStop
			Remotes.AutoResult:FireClient(player, result)

			if hitStop then
				break
			end
		end
		if autoGeneration[player] == generation then
			autoActive[player] = nil
		end
	end)
end

function RollService.Start()
	Remotes.GetState.OnServerInvoke = function(player: Player)
		local profile = DataService.WaitFor(player, 20)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		return fullState(player, profile.Data)
	end

	-- OpenPack(packId): opens one of the player's Roll Packs.
	Remotes.OpenPack.OnServerInvoke = function(player: Player, packId: unknown)
		local pack = if type(packId) == "string" then Packs.ById[packId] else nil
		if pack == nil then
			return { Ok = false, Reason = "BadRequest" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if BattleService.InBattle(player) then
			return { Ok = false, Reason = "InBattle" }
		end
		if autoActive[player] then
			return { Ok = false, Reason = "AutoActive" }
		end
		local limiter = if MonetizationService.Perk(player, "TripleRoll") then fastOpenLimiter else openLimiter
		if not limiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		local held = profile.Data.Packs
		if (held[pack.Id] or 0) <= 0 then
			return { Ok = false, Reason = "NoPacks" }
		end
		held[pack.Id] -= 1
		if held[pack.Id] <= 0 then
			held[pack.Id] = nil
		end
		local shown, counts, newCards, cards, luck = openPack(player, profile, pack)
		return {
			Ok = true,
			PackId = pack.Id,
			Results = shown,
			Counts = counts,
			New = newCards,
			Rolls = pack.Rolls,
			Luck = luck,
			Cards = cards,
			Packs = held,
			Summary = summary(player, profile.Data),
			Quests = MetaService.QuestState(player, profile.Data),
			Meta = MetaService.State(player, profile.Data),
		}
	end

	Remotes.Roll.OnServerInvoke = function(player: Player, mode: unknown, early: unknown)
		if mode ~= "Full" and mode ~= "Quick" then
			return { Ok = false, Reason = "BadRequest" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if autoActive[player] then
			return { Ok = false, Reason = "AutoActive" }
		end
		if mode == "Quick" and not isUnlocked(player, profile.Data, "QuickRoll") then
			return { Ok = false, Reason = "Locked" }
		end
		local left = cooldownLeft(player)
		if left > COOLDOWN_TOLERANCE then
			return { Ok = false, Reason = "Cooldown", Wait = left }
		end
		-- A surge is perfect only for a clean tap made after the cooldown came back (the client flags taps
		-- made during the cooldown as early; they queue and roll a plain surge) that lands inside the
		-- window; or with the Auto Roll pass's perfect hit.
		local perfect = RollBoost.IsPerfect(early == true, left, COOLDOWN_TOLERANCE) and lastRoll[player] ~= nil
		perfect = perfect or MonetizationService.Perk(player, "AutoRoll", true)
		lastRoll[player] = os.clock()
		return rollClick(player, profile, perfect, true)
	end

	-- Pack Alchemy: "Condense" (10 packs -> 1 of the next size) or "Infuse" (a Mega Pack + Shards ->
	-- an element-infused Mega Pack).
	Remotes.PackAlchemy.OnServerInvoke = function(player: Player, action: unknown, packId: unknown, element: unknown)
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if not alchemyLimiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		if not NpcRange.Near(player, "fuser") then
			return { Ok = false, Reason = "TooFar" } -- pack alchemy happens beside Hoshi
		end
		local data = profile.Data
		local held = data.Packs
		local made = nil
		if action == "Condense" then
			local rule = if type(packId) == "string" then Packs.Condense[packId] else nil
			if rule == nil then
				return { Ok = false, Reason = "BadRequest" }
			end
			if (held[packId] or 0) < rule.Need then
				return { Ok = false, Reason = "NotEnough" }
			end
			held[packId] -= rule.Need
			made = rule.To
			TutorialService.Note(player, "Condense")
		elseif action == "Infuse" then
			local id = if type(element) == "string" then Packs.InfusedId(element) else nil
			if packId ~= "1000" or id == nil then
				return { Ok = false, Reason = "BadRequest" }
			end
			if (held["1000"] or 0) < 1 then
				return { Ok = false, Reason = "NotEnough" }
			end
			if data.Shards < Packs.InfuseCost then
				return { Ok = false, Reason = "NoShards" }
			end
			data.Shards -= Packs.InfuseCost
			held["1000"] -= 1
			made = id
		else
			return { Ok = false, Reason = "BadRequest" }
		end
		for id, count in held do
			if count <= 0 then
				held[id] = nil
			end
		end
		held[made] = (held[made] or 0) + 1
		return { Ok = true, Made = made, Packs = held, Meta = MetaService.State(player, data), Summary = summary(player, data) }
	end

	Remotes.SetAuto.OnServerEvent:Connect(function(player: Player, on: unknown, autoStop: unknown)
		local profile = DataService.Get(player)
		if profile == nil then
			return
		end
		if type(autoStop) == "string" and table.find(Config.AutoStopOptions, autoStop) then
			profile.Data.Settings.AutoStop = autoStop
		end
		if on == true then
			if not isUnlocked(player, profile.Data, "AutoRoll") then
				Remotes.AutoResult:FireClient(player, { Ok = false, Stopped = true, Reason = "Locked" })
				return
			end
			if not autoActive[player] then
				startAuto(player)
			end
		elseif on == false then
			stopAuto(player)
		end
	end)

	-- Test-phase tools. The server refuses all of them once Config.TestMode is false.
	Remotes.Dev.OnServerInvoke = function(player: Player, action: unknown, value: unknown)
		if not Config.TestMode then
			return { Ok = false, Reason = "Disabled" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if action == "SetLuck" then
			local luck = tonumber(value) or 1
			MetaService.SetDevLuck(player, math.clamp(luck, 1, Config.Roll.LuckCap))
		elseif action == "GrantAll" or action == "GrantStarter" then
			-- GrantStarter: just the most common cards (Weight 8+), a first deck; GrantAll: the whole pool.
			for _, card in Cards.Pool(profile.Data.Progress.Cleared) do
				local include = action == "GrantAll" or card.Weight >= 8
				if include and profile.Data.Cards[card.Id] == nil then
					profile.Data.Cards[card.Id] = { Copies = 1, Stars = 0, BorderCopies = { Normal = 1 } }
				end
			end
		elseif action == "MaxStars" then
			for _, entry in profile.Data.Cards do
				if entry.Stars < Config.MaxStars then
					entry.Copies += Config.MaxStars - entry.Stars
					entry.Stars = Config.MaxStars
				end
			end
		elseif action == "FillCopies" then
			-- Every owned card gets enough copies at its best border for the next border fusion.
			for _, entry in profile.Data.Cards do
				local best = Borders.Best(entry.Borders)
				if Borders.Next(best) then
					entry.BorderCopies = entry.BorderCopies or {}
					local have = entry.BorderCopies[best] or 0
					if have < Config.FusionCopies then
						entry.BorderCopies[best] = Config.FusionCopies
						entry.Copies += Config.FusionCopies - have
					end
				end
			end
		elseif action == "StartEvent" then
			-- Runs an event now for its usual length (value = event id).
			if type(value) ~= "string" or Meta.EventById[value] == nil then
				return { Ok = false, Reason = "BadRequest" }
			end
			MetaService.ForceEvent(value, Meta.EventSeconds)
		elseif action == "GiveBorders" then
			-- Spreads borders over owned cards so every frame can be seen: each gets Gold, every second
			-- one Rainbow, every fourth Secret.
			local i = 0
			for _, card in Cards.List do
				local entry = profile.Data.Cards[card.Id]
				if entry then
					i += 1
					addCopy(entry, "Gold")
					if i % 2 == 0 then
						addCopy(entry, "Rainbow")
					end
					if i % 4 == 0 then
						addCopy(entry, "Secret")
					end
				end
			end
		elseif action == "GiveItems" then
			-- One of every artifact, to try the BAG.
			local bundle = { Artifacts = {} }
			for _, artifact in Items.Artifacts do
				bundle.Artifacts[artifact.Id] = 1
			end
			MetaService.Grant(profile.Data, bundle)
		elseif action == "GiveTraits" then
			-- A random trait on every owned card (replacing), to see them on cards and in battle.
			for _, entry in profile.Data.Cards do
				entry.Trait = Traits.Pick(rng:NextNumber(), rng:NextNumber())
			end
		elseif action == "GiveSpins" then
			profile.Data.Wheel.Spins = Meta.Wheel.MaxSpins
		elseif action == "AddXP" then
			MetaService.AddXP(player, profile.Data, 3000)
		elseif action == "UnlockFights" then
			-- Marks every fight cleared (no rewards), so every world and difficulty opens.
			for _, boss in Bosses.List do
				for _, difficulty in Bosses.DifficultyOrder do
					if boss.Difficulties[difficulty] then
						profile.Data.Progress.Cleared[Bosses.FightKey(boss.Id, difficulty)] = true
					end
				end
			end
		elseif action == "GiveLoot" then
			-- 1,000 Shards and 3 of every potion, to try the shop and boosts.
			local potions = {}
			for _, potion in Meta.Potions do
				potions[potion.Id] = 3
			end
			MetaService.Grant(profile.Data, { Shards = 1000, Potions = potions })
		elseif action == "GivePacks" then
			-- 5 Roll Packs, 2 Big Roll Packs and a Mega Roll Pack, to try opening them.
			MetaService.Grant(profile.Data, { Packs = { ["10"] = 5, ["100"] = 2, ["1000"] = 1 } })
		elseif action == "TowerUp" then
			-- Skips 10 tower floors (no rewards), to try the higher floors.
			profile.Data.Tower.Floor += 10
		elseif action == "TowerReset" then
			profile.Data.Tower.Floor = 0
		elseif action == "GiveTraitShards" then
			MetaService.Grant(profile.Data, { TraitShards = 200 })
		elseif action == "GiveCopies" then
			-- +20 copies on every owned card: an Awakening node each time.
			for _, entry in profile.Data.Cards do
				entry.Copies += Awaken.Every
				entry.BorderCopies = entry.BorderCopies or {}
				entry.BorderCopies.Normal = (entry.BorderCopies.Normal or 0) + Awaken.Every
				entry.Stars = math.max(entry.Stars, math.min(Config.MaxStars, entry.Copies - 1))
				entry.Awaken = math.max(entry.Awaken or 0, Awaken.FromCopies(entry.Copies))
			end
		elseif action == "GiveFoils" then
			-- Every foil on every owned card, to see them on cards and in battle.
			for _, entry in profile.Data.Cards do
				entry.Foils = entry.Foils or {}
				for i, foil in Foils.List do
					if i > 1 then
						entry.Foils[foil.Id] = true
					end
				end
			end
		elseif action == "StartRaid" then
			-- Opens a raid now for its usual length (every server player can join).
			RaidService.Force(true)
		elseif action == "NextMutator" then
			-- Switches the tower to the next mutator (for everyone on this server, until it restarts).
			local id = ReplicatedStorage:GetAttribute("DevMutator")
			local today = Tower.MutatorToday(Meta.DayNumber(os.time()), if type(id) == "string" then id else nil)
			local index = table.find(Tower.Mutators, today) or 0
			ReplicatedStorage:SetAttribute("DevMutator", Tower.Mutators[index % #Tower.Mutators + 1].Id)
		elseif action == "Reset" then
			stopAuto(player)
			BattleService.Stop(player)
			DataService.Reset(player)
			MetaService.ResetSession(player)
			MetaService.SetDevLuck(player, nil)
			lastRoll[player] = nil
		else
			return { Ok = false, Reason = "BadRequest" }
		end
		return fullState(player, profile.Data)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		stopAuto(player)
		lastRoll[player] = nil
		autoGeneration[player] = nil
	end)
end

return RollService
