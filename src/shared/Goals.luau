--!strict
-- The HUD's "Next Goal" pill: the reward closest to landing right now, so the player always sees a bar
-- filling toward something. Pure (no services): the client feeds it its own state on every roll, and
-- tests/meta_test.luau runs it headless.
--
-- Candidates, each with a progress 0-1 from the previous step to the next one:
--   Fusion     a card's pile at one border toward Cards.FusionCost (100 -> 1 at the next border)
--   Mastery    different story boss challenges completed with a card (1 / 3 / 6 / 10)
--   Milestone  total rolls toward the next unclaimed roll milestone (Meta.Milestones)
--   Upgrade    Shards toward the next Shard Shop level (Meta.Upgrades)
-- A fusion that is ready wins outright (it's an action: "see Hoshi"); otherwise the highest progress.

local Borders = require(script.Parent.Borders)
local Cards = require(script.Parent.Cards)
local Awaken = require(script.Parent.Awaken)
local Meta = require(script.Parent.Meta)
local Bosses = require(script.Parent.Bosses)
local Tower = require(script.Parent.Tower)
local Items = require(script.Parent.Items)

local Goals = {}

export type Goal = {
	Kind: string, -- "Fusion" | "Mastery" | "Milestone" | "Upgrade"
	Text: string, -- "Next Fusion: Celestial Strategist Gold (86/100)"
	Progress: number, -- 0-1
	Ready: boolean, -- it can be claimed / done now
}

export type Info = {
	Cards: { [string]: any }, -- the player's card entries (Copies, BorderCopies)
	Rolls: number,
	Claimed: { [string]: boolean }?, -- roll milestones claimed, keyed by tostring(Rolls)
	Shards: number,
	Upgrades: { [string]: number }?, -- Shard Shop levels
	Weather: any?,
	Now: number?,
}


local function better(a: Goal?, b: Goal): Goal
	if a == nil then
		return b
	end
	return if b.Progress > a.Progress then b else a
end

function Goals.Next(info: Info): Goal?
	local best: Goal? = nil
	local ready: Goal? = nil
	local readyPile = 0
	for id, entry in info.Cards do
		local card = Cards.Get(id)
		if card == nil or type(entry) ~= "table" then
			continue
		end
		-- Fusion: every border with a border above it.
		for border, pile in (entry.BorderCopies or {}) :: { [string]: number } do
			local nextBorder = Borders.Next(border)
			if nextBorder and pile > 0 then
				local name = `{card.Name} {Borders.Get(border).Name}`
				if pile >= Cards.FusionCost(card) then
					if pile > readyPile then
						readyPile = pile
						ready = {
							Kind = "Fusion",
							Text = `FUSE READY: {name} x{pile} · see Hoshi`,
							Progress = 1,
							Ready = true,
						}
					end
				else
					best = better(best, {
						Kind = "Fusion",
						Text = `Next Fusion: {name} ({pile}/{Cards.FusionCost(card)})`,
						Progress = pile / Cards.FusionCost(card),
						Ready = false,
					})
				end
			end
		end
		-- Mastery: distinct boss challenges, never duplicate rolls.
		local copies = Awaken.Count(entry)
		local level = Awaken.Level(entry)
		local nextNode = Awaken.Nodes[level + 1]
		if nextNode and nextNode.Node <= 4 then
			local from = if level > 0 then Awaken.Nodes[level].Challenges else 0
			local span = math.max(1, nextNode.Challenges - from)
			best = better(best, {
				Kind = "Mastery",
				Text = `Next Mastery: {card.Name} ({copies}/{nextNode.Challenges})`,
				Progress = math.clamp((copies - from) / span, 0, 0.999),
				Ready = false,
			})
		end
	end
	if ready then
		return ready
	end
	-- Roll milestones: the first one not claimed yet.
	local claimed = info.Claimed or {}
	local previous = 0
	for _, milestone in Meta.Milestones do
		if not claimed[tostring(milestone.Rolls)] then
			if info.Rolls < milestone.Rolls then
				best = better(best, {
					Kind = "Milestone",
					Text = `Next Milestone: {milestone.Rolls} rolls ({info.Rolls}/{milestone.Rolls})`,
					Progress = math.clamp((info.Rolls - previous) / math.max(1, milestone.Rolls - previous), 0, 0.999),
					Ready = false,
				})
			end
			break
		end
		previous = milestone.Rolls
	end
	return best
end

-- The nearest distinct targets; completed mastery and capped borders do not create dead-end bars.
function Goals.Closest(info: Info): {Goal}
	local best: {[string]:Goal}={}
	local function add(goal: Goal)
		best[goal.Kind]=better(best[goal.Kind],goal)
	end
	local total,found=0,0
	for _,card in Cards.List do
		if not card.Weather and not card.Boss then total+=1; if info.Cards[card.Id] then found+=1 end end
	end
	if found<total then add({Kind="Collection",Text=`Vault: {found}/{total} normal cards`,Progress=found/total,Ready=false}) end
	for id,entry in info.Cards do
		local card=Cards.Get(id)
		if card then
			for border,pile in entry.BorderCopies or {} do
				if Borders.Next(border) and pile>0 then
					add({Kind="Fusion",Text=`Fusion: {card.Name} {pile}/{Cards.FusionCost(card)}`,Progress=math.min(1,pile/Cards.FusionCost(card)),Ready=pile>=Cards.FusionCost(card)})
				end
			end
			local node=Awaken.Nodes[Awaken.Level(entry)+1]
			if node then add({Kind="Mastery",Text=`Mastery: {card.Name} {Awaken.Count(entry)}/{node.Challenges}`,Progress=math.min(.999,Awaken.Count(entry)/node.Challenges),Ready=false}) end
		end
	end
	local sky=info.Weather
	if sky and sky.Next and info.Now and sky.Id=="clear" then
		local left=math.max(0,sky.Next.Starts-info.Now)
		add({Kind="Weather",Text=`Next sky: {math.ceil(left/60)} min`,Progress=math.clamp(1-left/900,0,.999),Ready=false})
	end
	local nextGoal=Goals.Next(info)
	if nextGoal then add(nextGoal) end
	local sorted={}
	for _,goal in best do table.insert(sorted,goal) end
	table.sort(sorted,function(a,b) if a.Progress~=b.Progress then return a.Progress>b.Progress end;return a.Kind<b.Kind end)
	while #sorted>3 do table.remove(sorted) end
	return sorted
end

-- Visible long-term targets, derived from existing server snapshots; this page awards nothing.
function Goals.Journey(info: any): { any }
	local cleared = info.Cleared or {}
	local tower = info.Tower or {}
	local rows: { any } = {}
	local count, targetBoss, targetDifficulty = 0, nil, nil
	for _, difficulty in Bosses.DifficultyOrder do
		for _, boss in Bosses.List do
			if cleared[Bosses.FightKey(boss.Id, difficulty)] then
				count += 1
			elseif not targetBoss and Bosses.IsUnlocked(cleared, boss.Id, difficulty) then
				targetBoss, targetDifficulty = boss, difficulty
			end
		end
	end
	local total = #Bosses.List * #Bosses.DifficultyOrder
	local bossCard = targetBoss and Cards.ForBoss(targetBoss.Id)
	table.insert(rows, {
		Title = "CONQUER THE WORLDS", Count = `{count}/{total} challenges`, Progress = count / total,
		Text = if targetBoss then `Next: {targetBoss.Name} · {targetDifficulty}` else "Every story challenge cleared. Try new cards to build their mastery.",
		Reward = if targetDifficulty == "Normal" and bossCard then `Unlock {bossCard.Name} in the roll pool. Then roll to find it.` else "Earn packs and Trait Shards; each new challenge also trains the cards you bring.",
		Action = "Story", Boss = targetBoss and targetBoss.Id, Difficulty = targetDifficulty,
		Image = bossCard and bossCard.Image, ArtKey = "BATTLE",
	})
	local cards = info.Cards or {}
	local chosen, entry, node
	for _, id in info.Attack or {} do
		local card = Cards.Get(id)
		local owned = cards[id]
		local nextNode = owned and Awaken.Next(owned)
		if card and nextNode then chosen, entry, node = card, owned, nextNode; break end
	end
	table.insert(rows, {
		Title = "TRAIN YOUR TEAM", Count = if node then `{Awaken.Count(entry)}/{node.Challenges} wins` else "Choose your team",
		Progress = if node then Awaken.Count(entry) / node.Challenges else 0,
		Text = if chosen then `Next: {chosen.Name} · {node.Name}` else "Equip Attack cards in SQUAD and try different story challenges.",
		Reward = if node then `{node.Text}. Win different boss/difficulty fights with this card equipped; repeats do not count.` else "Mastery gives attack speed, stronger skills, a better bond combo and trait slot 2.",
		Action = "Squad", Image = chosen and chosen.Image, ArtKey = "SQUAD",
	})
	local pagoda = tower.Pagoda or 0
	local nextFloor = Tower.Pagoda.Floors
	for _, floor in { 25, 50, 75, Tower.Pagoda.Floors } do
		if pagoda < floor then nextFloor = floor; break end
	end
	local milestone = Tower.PagodaMilestones[nextFloor]
	table.insert(rows, {
		Title = "EARN THE PAGODA CROWN", Count = `{pagoda}/{Tower.Pagoda.Floors} floors`,
		Progress = math.clamp(pagoda / Tower.Pagoda.Floors, 0, 1),
		Text = if pagoda < Tower.Pagoda.Floors then `Next milestone: floor {nextFloor}. Cleared floors stay cleared.` else "Crown earned. Your Pagoda progress is complete.",
		Reward = if pagoda < Tower.Pagoda.Floors then `Floor {nextFloor}: {math.ceil(milestone.Shards/Meta.ShardExchange)+milestone.TraitShards} Trait Shards and packs. Crown + Pagoda Master title at floor {Tower.Pagoda.Floors}.` else "The Crown of the Hundred Floors is always active; no relic slot needed.",
		Action = "Pagoda", ArtKey = "TowerArtifact:hundredcrown",
	})
	local best = tower.Best or 0
	table.insert(rows, {
		Title = "HUNT TOWER RELICS", Count = `Best floor {best}`,
		Progress = math.clamp(best / Items.RelicFloor, 0, 1),
		Text = `Reach floor {Items.RelicFloor}, then fight eligible floors for wearable relics. Wear up to {Items.ArtifactSlots}.`,
		Reward = "Packs every 5 floors; Big Packs every 25. Relics are rare random drops, not guaranteed at floor 50. Losing ends the run.",
		Action = "Tower", ArtKey = "Artifact:voideye",
	})
	return rows
end

return Goals
