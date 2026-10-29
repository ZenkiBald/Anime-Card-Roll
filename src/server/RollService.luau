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
local PackBatch = require(Shared.PackBatch)
local Collections = require(Shared.Collections)
local Weather = require(Shared.Weather)
local WeatherService = require(script.Parent.WeatherService)
local CelestialRolls=require(Shared.CelestialRolls)
local BulkRoll = require(Shared.BulkRoll)
local RevealPolicy=require(Shared.RevealPolicy)


local Remotes = ReplicatedStorage.Remotes
local GlobalAnnounce = require(script.Parent.GlobalAnnounce)
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
local DevAccess = require(script.Parent.DevAccess)
local DevCommands = require(Shared.DevCommands)

local RollService = {}

local rng = Random.new()
-- While a sky is active, every normal pull searches it once (CelestialRolls): `searches` at once, with
-- the player's luck lifting the chance a little. Returns { [card] = finds }; empty in Quiet Skies.
local function skyFinds(luck: number, searches: number): { [any]: number }
	if not Config.CelestialCardsReady or searches <= 0 then return {} end
	local state = WeatherService.State()
	if state.Id == "clear" then return {} end
	return CelestialRolls.Search(Cards.WeatherPool(state.Id), searches, luck, rng)
end

local lastRoll = {} -- [Player] = os.clock() of their last roll
local openLimiter = RateLimit.new(1, 2) -- opening Roll Packs: one a second
local fastOpenLimiter = RateLimit.new(MonetizationConfig.TriplePackSpeed, MonetizationConfig.TriplePackSpeed * 2) -- Triple Roll pass
local alchemyLimiter = RateLimit.new(4, 8)
-- A big open (over BIG_OPEN rolls in one call, e.g. OPEN ALL on Mega Packs) costs real server time, so those
-- come at most one per 4 s on top of the normal open limit.
local BIG_OPEN = 1000
local bigOpenLimiter = RateLimit.new(0.25, 1)
local stateLimiter = RateLimit.new(0.5, 3) -- GetState builds the whole save's state
local devLimiter = RateLimit.new(3,8)
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
		SelectedCollection = data.SelectedCollection or "normal",
		Shards = data.Shards,
		Fragments = data.Celestial and data.Celestial.Fragments or 0,
		Luck = luckFor(player, data),
		Cooldown = cooldownFor(data, player),
		TraitShards = data.TraitShards or 0,
		Momentum = Momentum.State(player),
		UntilSurge = RollBoost.UntilSurge(data.TotalRolls),
		SurgeProgress = RollBoost.SurgeProgress(data.TotalRolls), -- 0-24: the surge meter (TotalRolls % 25)
		IsSurgeRoll = RollBoost.IsSurgeRoll(data.TotalRolls), -- the last roll was a surge
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
		Tower = { Best = data.Tower.Floor, Run = data.Tower.Run, Pagoda = data.Pagoda.Floor },
		Packs = data.Packs,
		Battle = { AutoUlt = data.Settings.AutoUlt, Speed = data.Settings.BattleSpeed },
		Mount = data.Settings.Mount,
		Meta = MetaService.State(player, data),
		TestMode = Config.TestMode,
		Dev = DevAccess.Allowed(player), -- may use the DEV panel
	}
end

export type RollOptions = {
	CelestialId: string?, -- internal only: a server-picked weather bonus, never supplied by a remote
	BorderMult: number?, -- x border odds (surges, infused packs under a luck boost)
	FoilMult: number?, -- x foil odds (perfect surges)
	Element: string?, -- infused packs: this element's cards weigh Packs.InfuseWeight in the pool
	Surge: string?, -- "Plain" | "Perfect": tagged on the result for the reveal
}

-- A card from the player's pool by Weight (the infused element's cards and the week's Featured Card
-- weighted up).
local function pickCard(data, element: string?)
	local pool = Collections.Pool(data.SelectedCollection, data.Progress.Cleared)
	local chances = Cards.PullChances(pool, element, Packs.InfuseWeight, Cards.FeaturedAt(os.time()))
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

	local card = if o.CelestialId then Cards.Get(o.CelestialId) else pickCard(data, o.Element)
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

	-- Mastery comes only from server-recorded story challenges.
	entry.Stars = 0
	local newNode = nil

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
		GlobalAnnounce.Pull(player, card.Id, border, foil)
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
		Mastery = entry.Mastery,
		Trait2Unlocked = entry.Trait2Unlocked,
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
	-- Every card of the click (Triple Roll included) searches the active sky once.
	for card, n in skyFinds(luckFor(player, data), count) do
		for _ = 1, n do
			table.insert(extra, doRoll(player, profile, nil, nil, { CelestialId = card.Id }))
		end
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
-- (sure, or by chance) and Trait Shards. `relicFloor`: an Infinite Tower win on that floor also rolls for
-- a relic (Items.RollDrops: only from Items.RelicFloor up). `towerArtifact`: a finite tower's artifact.
local function payWin(player: Player, profile, packs: { [string]: number }?, shards: number, potion: string?, potionChance: number, traitShards: number?, relicFloor: number?, towerArtifact: string?, fragments: number?, supplies: {[string]:number}?)
	local held = profile.Data.Packs
	for id, count in (packs or {}) :: { [string]: number } do
		held[id] = (held[id] or 0) + count
	end
	local bundle = { Shards = shards, Potions = {}, TraitShards = traitShards, Fragments=fragments, Celestial=supplies }
	if potion and rng:NextNumber() < potionChance then
		bundle.Potions[potion] = 1
	end
	if relicFloor then
		bundle.Artifacts = Items.RollDrops(relicFloor, rng).Artifacts
	end
	if towerArtifact and Items.TowerArtifactById[towerArtifact] then
		bundle.TowerArtifacts = { [towerArtifact] = true }
	end
	bundle = MetaService.Grant(profile.Data, bundle, player) -- the screen shows the Shard Gain bonus too
	return {
		NewPacks = packs, -- what this win dropped
		Packs = held, -- everything held now
		Bundle = bundle,
		Summary = summary(player, profile.Data),
		Meta = MetaService.State(player, profile.Data),
	}
end

-- Adds `n` pulls of one card at once (bulk pack opening): splits them over borders and foils with one
-- multinomial draw each, applies copies / found borders / foils to the save and records one receipt group
-- per border. Returns how many were new cards (0 or 1) and how many rolled a special border.
local function addBulk(player: Player, profile, card, n: number, borderChances, batch, xp)
	local data = profile.Data
	local entry = data.Cards[card.Id]
	local isNew = entry == nil
	if isNew then
		entry = { Copies = 0, Stars = 0 }
		data.Cards[card.Id] = entry
	end
	entry.Copies += n
	entry.Stars = 0
	-- Borders, rarest first; whatever's left is Base.
	local order, probs = {}, {}
	for i = #Borders.List, 2, -1 do
		table.insert(order, Borders.List[i].Id)
		table.insert(probs, borderChances[Borders.List[i].Id] or 0)
	end
	local split = BulkRoll.Multinomial(rng, n, probs)
	local counts, special = {}, 0
	for i, id in order do
		if split[i] > 0 then counts[id] = split[i]; special += split[i] end
	end
	if n - special > 0 then counts.Normal = n - special end
	-- Foils: only whether each one turned up matters (the card keeps every foil it has found).
	local foilProbs = {}
	for i, foil in Foils.List do foilProbs[i] = foil.Chance end
	local bestFoil, newFoil = nil, false
	for i, got in BulkRoll.Multinomial(rng, n, foilProbs) do
		local foil = Foils.List[i].Id
		if got > 0 and foil ~= "standard" then
			entry.Foils = entry.Foils or {}
			newFoil = newFoil or entry.Foils[foil] ~= true
			entry.Foils[foil] = true
			bestFoil = foil
		end
	end
	local first = true
	for i = #Borders.List, 1, -1 do
		local id = Borders.List[i].Id
		local got = counts[id]
		if got then
			entry.BorderCopies = entry.BorderCopies or {}
			entry.BorderCopies[id] = (entry.BorderCopies[id] or 0) + got
			local newBorder = false
			if id ~= "Normal" then
				entry.Borders = entry.Borders or {}
				newBorder = entry.Borders[id] ~= true
				entry.Borders[id] = true
			end
			if newBorder and data.Settings.Avatar == card.Id then
				AvatarService.Apply(player)
			end
			PackBatch.AddGroup(batch, card.Id, id, got, if isNew then "New" else "Copy", newBorder,
				if first then bestFoil else nil, if first then newFoil else nil)
			first = false
		end
	end
	xp.XP += Meta.XP.Roll * n + (if isNew then Meta.XP.NewCard else 0)
	return special
end

-- One non-yielding pass for the whole selection, however big: the pool's card counts come from one
-- multinomial draw over the total (packs x rolls), then each card's borders / foils. Luck is sampled
-- once, XP paid once, and while a sky is active every pull also searches it (the same bulk draw).
local function openPack(player: Player, profile, pack: Packs.Pack, count: number)
	local data = profile.Data
	local xp = { XP = 0 }
	local luck = luckFor(player, data)
	local borderMult = nil
	if pack.Element then
		local event = MetaService.Event()
		local boosted = (event ~= nil and event.Luck ~= nil) or MetaService.ServerLuck() > 1
		borderMult = if boosted then Packs.InfuseBorderMult else nil
	end
	local total = count * pack.Rolls
	local pool = Collections.Pool(data.SelectedCollection, data.Progress.Cleared)
	local chances = Cards.PullChances(pool, pack.Element, Packs.InfuseWeight, Cards.FeaturedAt(os.time()))
	local probs, commonest = {}, 1
	for i, card in pool do
		probs[i] = chances[card.Id]
		if probs[i] > probs[commonest] then commonest = i end
	end
	local split = BulkRoll.Multinomial(rng, total, probs)
	local assigned = 0
	for _, n in split do assigned += n end
	split[commonest] += total - assigned -- float rounding: every pull lands somewhere
	local borderBoost = (1 + Meta.Bonus(data.Stats, data.Gear, "Border")) * (borderMult or 1) - 1
	local borderChances = Borders.Chances(borderBoost, luck)
	local batch = PackBatch.New()
	local touched = {}
	local special = 0
	for i, card in pool do
		if split[i] > 0 then
			special += addBulk(player, profile, card, split[i], borderChances, batch, xp)
			touched[card.Id] = true
		end
	end
	-- Sky finds are bonus cards on top of the pack's pulls.
	local skyBorders = Borders.Chances(Meta.Bonus(data.Stats, data.Gear, "Border"), luck)
	for card, n in skyFinds(luck, total) do
		special += addBulk(player, profile, card, n, skyBorders, batch, xp)
		touched[card.Id] = true
	end
	data.TotalRolls += batch.Rolls
	MetaService.Track(player, "Rolls", batch.Rolls)
	if special > 0 then MetaService.Track(player, "EpicPulls", special) end
	MetaService.AddXP(player, data, xp.XP)
	PackBatch.Finish(batch)
	RollService.AnnounceBatch(player, batch)
	local cards = {}
	for id in touched do cards[id] = DataService.CardState(data.Cards[id]) end
	return batch, cards, luck
end

-- A bulk opening's announcements: every highlight at or past Config.ChatAnnounceFrom (1 in 10,000,000),
-- at most three, else its best pull if that border is announced anyway (Rainbow+).
function RollService.AnnounceBatch(player: Player, batch)
	local said = 0
	for _, pull in batch.Results do
		if said < 3 and (pull.Rarity or 0) >= Config.ChatAnnounceFrom then
			GlobalAnnounce.Pull(player, pull.CardId, pull.Border, pull.Foil)
			said += 1
		end
	end
	local best = batch.Results[1]
	if said == 0 and best and Borders.Index(best.Border) >= Borders.Index(Config.AnnounceFrom) then
		GlobalAnnounce.Pull(player, best.CardId, best.Border)
	end
end

function RollService.RewardRolls(player: Player, d: number, firstClear: boolean, costChallenge: boolean?, corrupted: boolean?)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	-- Every win drops Roll Packs, pays Shards and Trait Shards (x2 on a Cost Challenge) and may drop a
	-- potion. No relics or artifacts: those come from the towers only.
	local reward = Rewards.For(d)
	local traitShards = Rewards.TraitShards(d, firstClear) * (if costChallenge then Config.Deck.CostTraitShards else 1)
	return payWin(player, profile, Packs.ForBoss(d, firstClear), reward.Shards, reward.Potion, Config.Rewards.PotionChance, traitShards,nil,nil,if corrupted then 5 else nil)
end

-- A won tower floor. The Infinite Tower (Tower.Reward): every floor of a run pays, run milestones drop
-- Roll Packs, floors from Items.RelicFloor roll for a relic, and a Guardian on a record floor (`record`)
-- adds more Shards and a sure potion. The Pagoda (Tower.PagodaReward, each floor once): milestones add
-- packs and Trait Shards, floor 100 its artifact (its title is saved by BattleService).
function RollService.TowerRewards(player: Player, floor: number, mode: string, record: boolean)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local reward = if mode == Tower.PagodaId then Tower.PagodaReward(floor) else Tower.Reward(floor, record)
	local pagoda = mode == Tower.PagodaId
	local artifact = if reward.Milestone then reward.Milestone.Artifact else nil
	local result = payWin(player, profile, reward.Packs, reward.Shards, reward.Potion, 1, reward.TraitShards, if pagoda then nil else floor, artifact,if record and floor%10==0 then 3 else nil,if record and floor%25==0 then {orb=1} else nil)
	result.Milestone = reward.Milestone
	return result
end

-- A raid payout for a hitter who left before the raid ended: the same reward, built into one bundle and
-- sent to their save as a message; it lands when they next play.
function RollService.RaidRewardsOffline(userId: number, reward, name: string)
	local bundle = { Shards = reward.Shards, TraitShards = reward.TraitShards, Packs = reward.Packs, Fragments=5, Celestial={orb=1} }
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
	return payWin(player, profile, reward.Packs, reward.Shards, nil, 0, reward.TraitShards,nil,nil,5,{orb=1})
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

			-- Only pulls eligible under the saved reveal choice hold Auto; filtered copies keep rolling.
			local big = false
			for _, r in { result, table.unpack(result.Extra or {}) } do
				big = big or RevealPolicy.Eligible(r,profile.Data.Settings)
			end
			Remotes.AutoResult:FireClient(player, result)
			if big then
				task.wait(Config.AutoBigRevealHold)
			end
		end
		if autoGeneration[player] == generation then
			autoActive[player] = nil
		end
	end)
end

function RollService.OpenPacks(player: Player, packId: unknown, count: unknown)
	local pack = if type(packId) == "string" then Packs.ById[packId] else nil
	if pack == nil then
		return { Ok = false, Reason = "BadRequest" }
	end
	if count ~= nil and count ~= "all" and (type(count) ~= "number" or count ~= count or math.abs(count) == math.huge or count < 1) then
		return { Ok = false, Reason = "BadRequest" }
	end
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	if BattleService.InBattle(player) then
		return { Ok = false, Reason = "InBattle" }
	end
	local limiter = if MonetizationService.Perk(player, "TripleRoll") then fastOpenLimiter else openLimiter
	if not limiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	local held = profile.Data.Packs
	local have = held[pack.Id] or 0
	if have <= 0 then
		return { Ok = false, Reason = "NoPacks" }
	end
	local n = PackBatch.OpenCount(pack.Id, count, have)
	if n == nil or n < 1 then return { Ok = false, Reason = "BadRequest" } end
	if n * pack.Rolls > BIG_OPEN and not bigOpenLimiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	held[pack.Id] = have - n
	if held[pack.Id] <= 0 then
		held[pack.Id] = nil
	end
	local batch, cards, luck = openPack(player, profile, pack, n)
	return {
		Ok = true,
		PackId = pack.Id,
		Opened = n,
		Results = batch.Results,
		Reveals = batch.Reveals,
		TotalCards = batch.Rolls,
		Groups = batch.Groups,
		Counts = batch.Counts,
		New = batch.New,
		Remaining = held[pack.Id] or 0,
		Rolls = pack.Rolls * n,
		Luck = luck,
		Cards = cards,
		Packs = held,
		Summary = summary(player, profile.Data),
		Quests = MetaService.QuestState(player, profile.Data),
		Meta = MetaService.State(player, profile.Data),
	}
end

function RollService.Start()
	Remotes.GetState.OnServerInvoke = function(player: Player)
		if not stateLimiter:Allow(player) then
			return { Ok = false, Reason = "Loading" } -- the client asks again
		end
		local profile = DataService.WaitFor(player, 20)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		return fullState(player, profile.Data)
	end

	-- OpenPack(packId, count?): opens `count` of the player's Roll Packs of that kind (1 by default; a number,
	-- or "all"). Works while Auto Roll runs: a pack opens in one go, with no yield an Auto Roll pull could
	-- land in. "all" opens the whole pile in one bulk draw, however many packs it holds.
	Remotes.OpenPack.OnServerInvoke = RollService.OpenPacks

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
			return {Ok=false,Reason="Retired"}
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

	Remotes.SetAuto.OnServerEvent:Connect(function(player: Player, on: unknown)
		local profile = DataService.Get(player)
		if profile == nil then
			return
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

	-- Test-phase tools: only for DevAccess (TestMode on, and Studio / the owner / a listed tester).
	RollService.HandleDev = function(player: Player, action: unknown, value: unknown)
		if not DevAccess.Allowed(player) then
			return { Ok = false, Reason = "Disabled" }
		end
		if not devLimiter:Allow(player) then return {Ok=false,Reason="TooFast"} end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if action == "SetLuck" then
			local checked=DevCommands.Validate(action,value)
			if not checked then return {Ok=false,Reason="BadRequest"} end
			MetaService.SetDevLuck(player,checked.Luck)
		elseif action=="ClearDevLuck" then
			MetaService.SetDevLuck(player,nil)
		elseif action=="GrantCard" or action=="GrantResource" or action=="GrantPack" or action=="SetWeather" or action=="SetLevel" then
			local checked=DevCommands.Validate(action,value)
			if not checked then return {Ok=false,Reason="BadRequest"} end
			local data=profile.Data
			if action=="GrantCard" then
				local entry=data.Cards[checked.CardId]
				if not entry then entry={Copies=0,Stars=0,BorderCopies={},Borders={}};data.Cards[checked.CardId]=entry end
				for _=1,checked.Count do addCopy(entry,checked.Border) end
				entry.Copies+=checked.Count
			elseif action=="GrantResource" then
				MetaService.Grant(data,{[checked.Kind]=checked.Amount})
			elseif action=="GrantPack" then
				MetaService.Grant(data,{Packs={[checked.Id]=checked.Count}})
			elseif action=="SetWeather" then
				WeatherService.DevSet(checked.Id,checked.Seconds)
			elseif action=="SetLevel" then
				data.Level=checked.Level;data.XP=0
			end
		elseif action=="GiveSkyItems" then
			local stock={orb=10,hourglass=10}
			for _,sky in Weather.List do if sky.Id~="clear" then stock[`sigil:{sky.Id}`]=10 end end
			MetaService.Grant(profile.Data,{Fragments=100,Celestial=stock})
		elseif action=="ClearBossCooldowns" then
			profile.Data.Progress.RewardAt={}
		elseif action == "GrantAll" or action == "GrantStarter" then
			-- GrantStarter: just the most common cards (1 in 60 or commoner), a first deck; GrantAll: the whole pool.
			for _, card in Cards.Pool(profile.Data.Progress.Cleared) do
				local include = action == "GrantAll" or card.Weight >= Cards.WeightTotal / 60
				if include and profile.Data.Cards[card.Id] == nil then
					profile.Data.Cards[card.Id] = { Copies = 1, Stars = 0, BorderCopies = { Normal = 1 } }
				end
			end
		elseif action == "MaxStars" then
			-- Legacy developer action id: now grants only fusion copies.
			for _, entry in profile.Data.Cards do
				entry.Copies += 5
				entry.BorderCopies = entry.BorderCopies or {}
				entry.BorderCopies.Normal = (entry.BorderCopies.Normal or 0) + 5
				entry.Stars = 0
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
			-- One of every relic and every artifact, to try the BAG.
			local bundle = { Artifacts = {}, TowerArtifacts = {} }
			for _, relic in Items.Artifacts do
				bundle.Artifacts[relic.Id] = 1
			end
			for _, artifact in Items.TowerArtifacts do
				bundle.TowerArtifacts[artifact.Id] = true
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
			-- Skips 10 floors of the tower run and of the Pagoda (no rewards), to try the higher floors.
			local tower = profile.Data.Tower
			tower.Run += 10
			tower.Floor = math.max(tower.Floor, tower.Run)
			profile.Data.Pagoda.Floor = math.min(Tower.Pagoda.Floors - 1, profile.Data.Pagoda.Floor + 10)
		elseif action == "TowerReset" then
			profile.Data.Tower.Floor = 0
			profile.Data.Tower.Run = 0
			profile.Data.Pagoda.Floor = 0
		elseif action == "GiveTraitShards" then
			MetaService.Grant(profile.Data, { TraitShards = 200 })
		elseif action == "GiveCopies" then
			-- Fusion copies only; developer copy grants cannot grant mastery.
			for _, entry in profile.Data.Cards do
				entry.Copies += Awaken.Every
				entry.BorderCopies = entry.BorderCopies or {}
				entry.BorderCopies.Normal = (entry.BorderCopies.Normal or 0) + Awaken.Every
				entry.Stars = 0
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

	Remotes.Dev.OnServerInvoke=RollService.HandleDev
	Players.PlayerRemoving:Connect(function(player: Player)
		stopAuto(player)
		lastRoll[player] = nil
		autoGeneration[player] = nil
	end)
end

return RollService
