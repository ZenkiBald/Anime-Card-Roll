--!strict
-- The HUD's "Next Goal" pill: the reward closest to landing right now, so the player always sees a bar
-- filling toward something. Pure (no services): the client feeds it its own state on every roll, and
-- tests/meta_test.luau runs it headless.
--
-- Candidates, each with a progress 0-1 from the previous step to the next one:
--   Fusion     a card's pile at one border toward Config.FusionCopies (100 -> 1 at the next border)
--   Awakening  a card's copies toward its next node (20 / 40 / 60 / 80)
--   Milestone  total rolls toward the next unclaimed roll milestone (Meta.Milestones)
--   Upgrade    Shards toward the next Shard Shop level (Meta.Upgrades)
-- A fusion that is ready wins outright (it's an action: "see Hoshi"); otherwise the highest progress.

local Config = require(script.Parent.Config)
local Borders = require(script.Parent.Borders)
local Cards = require(script.Parent.Cards)
local Awaken = require(script.Parent.Awaken)
local Meta = require(script.Parent.Meta)

local Goals = {}

export type Goal = {
	Kind: string, -- "Fusion" | "Awakening" | "Milestone" | "Upgrade"
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
}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

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
				if pile >= Config.FusionCopies then
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
						Text = `Next Fusion: {name} ({pile}/{Config.FusionCopies})`,
						Progress = pile / Config.FusionCopies,
						Ready = false,
					})
				end
			end
		end
		-- Awakening: copies toward the next node (nodes 1-4; node 5 is fusion, above).
		local copies = if type(entry.Copies) == "number" then entry.Copies else 0
		local level = Awaken.Level(entry)
		local nextNode = Awaken.Nodes[level + 1]
		if nextNode and nextNode.Node <= 4 then
			local from = if level > 0 then Awaken.Nodes[level].Copies else 0
			local span = math.max(1, nextNode.Copies - from)
			best = better(best, {
				Kind = "Awakening",
				Text = `Next Awakening: {card.Name} ({copies}/{nextNode.Copies})`,
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
	-- Shard Shop upgrades: Shards toward the next level of each.
	for _, upgrade in Meta.Upgrades do
		local level = (info.Upgrades or {})[upgrade.Id] or 0
		local cost = Meta.UpgradeCost(upgrade.Id, level)
		if cost then
			local progress = math.clamp(info.Shards / cost, 0, 1)
			best = better(best, {
				Kind = "Upgrade",
				Text = `Next Upgrade: {upgrade.Name} {ROMAN[level + 1] or tostring(level + 1)} ({math.floor(progress * 100)}%)`,
				-- An affordable upgrade is a nudge, not an alarm: just under a ready fusion.
				Progress = math.min(progress, 0.999),
				Ready = progress >= 1,
			})
		end
	end
	return best
end

return Goals
