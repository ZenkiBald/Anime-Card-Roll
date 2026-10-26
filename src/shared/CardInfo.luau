--!strict
-- Authored card copy resolves values from the same data used by the battle engine.
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
	return tostring(math.floor(math.abs(value) * 100 + 0.5)) .. "%"
end
function CardInfo.CopyBonus(stars: number): string
	return "Duplicates are used for border fusion"
end
function CardInfo.Job(card: Cards.Card): string
	return if card.Support then card.Support.Name else card.Title
end
function CardInfo.Link(_card: Cards.Card, _border: string?): string
	return ""
end
function CardInfo.Describe(card: Cards.Card, ability: Cards.Ability, stars: number, border: string?, awaken: number?): string
	local text = ability.Text
	local support = card.Support
	if support then
		local values: { [string]: string } = {
			amount = percent(Cards.SupportValue(card, stars, border, awaken)),
			chance = percent(support.Chance or 1), threshold = percent(support.Threshold or 0.5),
			penalty = percent(support.Penalty or 0), turns = tostring(support.Turns or 1), burn = percent(support.Burn or 0),
		}
		text = text:gsub("{(%a+)}", function(key) return values[key] or `{key}` end)
	end
	text = text:gsub("{[pat]%d+}", function(token: string)
		local kind, index = token:sub(2, 2), token:sub(3, -2)
		local effect = ability.Effects[tonumber(index) :: number]
		if not effect then return "?" end
		if kind == "p" then return percent(effect.Pct or 0) end
		if kind == "a" then return percent(Cards.EffectAmount(card, effect, border)) end
		return tostring(effect.Turns or 1)
	end)
	text = text:gsub("{chance}", function() return percent(ability.Chance or 1) end)
	return text
end
function CardInfo.SupportDescription(card: Cards.Card, stars: number, border: string?, awaken: number?): string
	return if card.Support then CardInfo.Describe(card, card.Abilities[1], stars, border, awaken) else ""
end
function CardInfo.Highlight(text: string): string
	-- Percentages, turn counts and named status effects carry the emphasis; ordinary numbers do not.
	text = text:gsub("(%d+%%)", '<font color="#FFD477"><b>%1</b></font>')
	text = text:gsub("(%d+ turns?)", '<font color="#FFD477"><b>%1</b></font>')
	local colors: { [string]: string } = { Burn = "FF9A61", Bleed = "FF7085", Freeze = "8FDFFF", Stun = "F2DC81", Weaken = "C9A1F5" }
	for status, color in colors do
		text = text:gsub("%f[%a]" .. status .. "%f[%A]", `<font color="#{color}"><b>{status}</b></font>`)
	end
	return text
end
function CardInfo.Badges(card: Cards.Card, ability: Cards.Ability): { string }
	local out = {}
	local limit = if card.Support then card.Support.Uses else ability.Limit
	if limit then table.insert(out, `Activation Limit: {limit}`) end
	if card.Support and card.Support.Kind == "Lifesteal" then
		table.insert(out, `Effect Cap: {percent(card.Support.Threshold or 0.25)} HP`)
	end
	return out
end
function CardInfo.Headline(card: Cards.Card, stars: number, border: string?, awaken: number?): string
	if card.Type == "Attack" then return `DMG {number(Cards.Stat(card, card.Main, stars, border, awaken))}` end
	local effect = card.Support
	if not effect then return "PASSIVE" end
	local labels: { [string]: string } = { LowHeal = "MEND", Counter = "COUNTER", Haste = "SPEED", Dodge = "EVADE", Weaken = "WEAKEN", OpeningShield = "SHIELD", KillMend = "RECOVER", StartEnergy = "CHARGE", Lifesteal = "DRAIN", LastStand = "REVIVE", Cleanse = "REFLECT" }
	return `{labels[effect.Kind] or "PASSIVE"} {percent(Cards.SupportValue(card, stars, border, awaken))}`
end
function CardInfo.BorderHelp(card: Cards.Card, border: string?): string
	local tier = Borders.Get(border)
	return if card.Type == "Attack" then `{tier.Name} · {tier.Multiplier}x DMG and HP` else tier.Name
end
return CardInfo
