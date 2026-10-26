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
	return if card.Support then card.Support.Name else "Passive for its paired attacker"
end

function CardInfo.SupportDescription(card: Cards.Card, stars: number, border: string?, awaken: number?): string
	local effect = card.Support
	if not effect then return "" end
	local amount = percent(Cards.SupportValue(card, stars, border, awaken))
	local kind = effect.Kind
	local detail = ""
	if kind == "LowHeal" then detail = `Below {percent(effect.Threshold or 0.4)} HP, restore {amount} of max HP. Once per battle; cannot revive.`
	elseif kind == "Guard" then detail = `Take {amount} less damage for the whole battle.`
	elseif kind == "Haste" then detail = `Act {amount} faster for the whole battle.`
	elseif kind == "Dodge" then detail = `{amount} chance to dodge an enemy hit. Does not dodge burn ticks.`
	elseif kind == "Weaken" then detail = `Skill or Ultimate hits reduce that enemy's damage by {amount} for 2 turns. Up to {effect.Uses or 4} triggers per battle; once per cast.`
	elseif kind == "OpeningShield" then detail = `Start with a shield worth {amount} of max HP. Once per battle; never refreshes.`
	elseif kind == "Critical" then detail = `Gain {amount} critical hit chance for the whole battle.`
	elseif kind == "StartEnergy" then detail = `Start with {amount} of Ultimate energy already charged. Requires an Ultimate.`
	elseif kind == "LastStand" then detail = "Survive one fatal hit at 1 HP. Once per battle; the next hit can defeat the attacker."
	elseif kind == "Cleanse" then detail = `Clear burn and freeze when they land. Up to {effect.Uses or 2} applications per battle.`
	elseif kind == "Lifesteal" then detail = `Heal for {amount} of direct damage dealt. Total healing is capped at {percent(effect.Threshold or 0.2)} of max HP per battle. Overkill does not count.`
	end
	return "Paired attacker only: " .. detail
end

local statNames: { [string]: string } = {
	ATK = "damage", SPD = "action speed", DEF = "defense", Crit = "critical chance",
	CritDamage = "critical damage", Guard = "damage reduction", Vuln = "damage taken",
	StartEnergy = "starting ultimate charge", SkillDMG = "skill damage",
}

function CardInfo.Link(card: Cards.Card, _border: string?): string
	return if card.Support then "Passive effect on the matching Attack slot only. No damage, HP or action bar." else ""
end

local allyTargets: { [string]: string } = {
	Self = "this card", Lowest = "the most hurt attacker", Attack = "every attacker",
	All = "every attacker", Random = "a random ally",
}
local enemyTargets: { [string]: string } = { Enemies = "every enemy", RandomEnemy = "a random enemy" }

function CardInfo.Describe(card: Cards.Card, ability: Cards.Ability, stars: number, border: string?, awaken: number?): string
	if card.Support then return CardInfo.SupportDescription(card, stars, border, awaken) end
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
	local effect = card.Support
	if not effect then return "PASSIVE" end
	local labels: { [string]: string } = { LowHeal = "HEAL", Guard = "GUARD", Haste = "SPEED", Dodge = "DODGE", Weaken = "WEAKEN", OpeningShield = "SHIELD", Critical = "CRIT", StartEnergy = "ENERGY", Lifesteal = "LIFESTEAL" }
	if effect.Kind == "LastStand" then return "LAST STAND · ONCE" end
	if effect.Kind == "Cleanse" then return `CLEANSE · {effect.Uses or 2} USES` end
	return `{labels[effect.Kind] or "BOOST"} {percent(Cards.SupportValue(card, stars, border, awaken))}`
end

function CardInfo.BorderHelp(card: Cards.Card, border: string?): string
	local tier = Borders.Get(border)
	if card.Support and card.Support.Amount == 0 then return `{tier.Name}: fixed passive trigger; limits stay the same at every border.` end
	return if card.Type == "Support"
		then `{tier.Name}: {Cards.SupportBoost(card, border)}x passive strength. Trigger limits and healing caps stay the same; no damage or HP.`
		else `{tier.Name}: {tier.Multiplier}x damage and health. Timings stay the same.`
end

return CardInfo
