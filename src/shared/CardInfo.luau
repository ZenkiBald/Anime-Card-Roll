--!strict
-- Player-facing facts computed from the same card effects and border formulas as the server.
local Cards = require(script.Parent.Cards)
local Borders = require(script.Parent.Borders)
local CardInfo = {}

local function number(value: number): string
	local s = tostring(math.floor(value + 0.5))
	while true do
		local nextText, count = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		s = nextText
		if count == 0 then return s end
	end
end

local function percent(value: number): string
	return tostring(math.floor(value * 1000 + 0.5) / 10) .. "%"
end

function CardInfo.CopyBonus(stars: number): string
	return `Copy bonus +{math.clamp(stars, 0, 5) * 5}%`
end

function CardInfo.Job(card: Cards.Card): string
	if card.Type == "Attack" then return "Fights and takes enemy hits" end
	local found: { [string]: boolean } = {}
	for _, a in card.Abilities do
		for _, e in a.Effects do found[e.Kind] = true end
	end
	if found.Heal then return "Heals your attackers" end
	if found.Shield then return "Shields your attackers" end
	if found.Buff then return "Boosts your attackers" end
	return "Weakens enemies"
end

local statNames: { [string]: string } = {
	ATK = "damage", SPD = "action speed", DEF = "defense", Crit = "critical chance",
	CritDamage = "critical damage", Guard = "damage reduction", Vuln = "damage taken",
	StartEnergy = "starting ultimate charge", SkillDMG = "skill damage",
}

function CardInfo.Link(card: Cards.Card, border: string?): string
	local link = card.Link
	if not link then return "" end
	return `Paired attacker: +{percent(Cards.LinkAmount(card, border))} {statNames[link.Stat] or link.Stat}`
end

local allyTargets: { [string]: string } = {
	Self = "this card", Lowest = "the most hurt attacker", Attack = "every attacker",
	All = "every attacker", Random = "a random ally",
}
local enemyTargets: { [string]: string } = { Enemies = "every enemy", RandomEnemy = "a random enemy" }

function CardInfo.Describe(card: Cards.Card, ability: Cards.Ability, stars: number, border: string?, awaken: number?): string
	local main = Cards.Stat(card, card.Main, stars, border, awaken)
	local lines = {}
	for _, e in ability.Effects do
		local kind = e.Kind
		local ally = allyTargets[e.Target or ""] or (if kind == "Buff" then "this card" else "the most hurt attacker")
		local enemy = enemyTargets[e.Target or ""] or "the focused enemy"
		local value = number(main * (e.Pct or 0))
		local amount = Cards.EffectAmount(card, e, border)
		local text = ""
		if kind == "Heal" then text = `Heal {ally} for up to {value} HP`
		elseif kind == "Shield" then text = `Give {ally} a {value} shield`
		elseif kind == "Damage" then
			text = `Deal {value} base damage to {enemy}`
			if (e.Hits or 1) > 1 then text ..= `, {e.Hits} hits` end
			if e.IgnoreDef then text ..= " (ignores defense)" end
		elseif kind == "Burn" then text = `Burn {enemy} for {value} damage per tick`
		elseif kind == "Buff" then text = `Give {ally} +{percent(amount)} {statNames[e.Stat or ""] or e.Stat or "boost"}`
		elseif kind == "Debuff" then
			text = if e.Stat == "Vuln" then `{enemy} takes {percent(amount)} more damage`
				else `Reduce {enemy}'s {statNames[e.Stat or ""] or e.Stat or "stats"} by {percent(amount)}`
		elseif kind == "Cleanse" then text = `Remove {e.Amount or 1} harmful effect(s) from {ally}`
		elseif kind == "Energy" then
			-- Energy can reach supports as well as attackers.
			local who = if e.Target == "All" then "every ally" else ally
			text = `Give {who} {e.Amount or 0} ultimate energy`
			if e.ResetSkill then text ..= " and ready their skill" end
		elseif kind == "Revive" then text = `Revive fallen attackers at {percent(e.Pct or 0)} HP`
		elseif kind == "Evade" then text = `{ally} dodges the next {e.Hits or 1} hit(s)`
		elseif kind == "Taunt" then text = "Draw enemy hits toward this card"
		else
			-- Secret signatures have bespoke engine logic; their authored description is the source.
			return ability.Text
		end
		if e.Turns then text ..= ` for {e.Turns} turn(s)` end
		if e.Chance then text = `{percent(e.Chance)} chance: {text}` end
		if e.When == "OnAct" then text ..= " whenever this card acts"
		elseif e.When == "OnHit" then text ..= " whenever this card hits"
		elseif e.When == "BossAbove50" then text ..= " while the boss is above half HP"
		elseif e.When == "SelfBelow50" then text ..= " while this card is below half HP" end
		table.insert(lines, text .. ".")
	end
	return table.concat(lines, "\n")
end

-- A short, concrete formation stat instead of presenting supports as damage / combat power.
function CardInfo.Headline(card: Cards.Card, stars: number, border: string?, awaken: number?): string
	if card.Type == "Attack" then
		return `DMG {number(Cards.Stat(card, card.Main, stars, border, awaken))}`
	end
	local basic = Cards.Ability(card, "Basic")
	if basic then
		for _, kind in { "Heal", "Shield", "Buff", "Debuff", "Damage" } do
			for _, e in basic.Effects do
				if e.Kind == kind then
					if kind == "Heal" or kind == "Shield" or kind == "Damage" then
						local verb = if kind == "Heal" then "HEAL" elseif kind == "Shield" then "SHIELD" else "DMG"
						return `{verb} {number(Cards.Stat(card, card.Main, stars, border, awaken) * (e.Pct or 0))}`
					end
					return `{if kind == "Debuff" then "WEAKEN" else "BOOST"} {percent(Cards.EffectAmount(card, e, border))}`
				end
			end
		end
	end
	return "SUPPORT"
end

function CardInfo.BorderHelp(card: Cards.Card, border: string?): string
	local tier = Borders.Get(border)
	return if card.Type == "Support"
		then `{tier.Name}: {tier.Multiplier}x healing, shields and skill damage; {Cards.SupportBoost(card, border)}x percentage boosts. Timings stay the same.`
		else `{tier.Name}: {tier.Multiplier}x damage and health. Timings stay the same.`
end

return CardInfo
