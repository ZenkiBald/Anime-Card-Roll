--!strict
-- A family changes the distribution inside the unlocked pool for singles and consumable packs.
local Cards = require(script.Parent.Cards)
local Collections = {}
Collections.List = {
	{Id="normal",Name="Normal Collection",Text="Every normal card. A good place to begin.", Unlock="", Cards={} },
	{Id="chakra",Name="Chakra Legends",Text="Ninja clans, chakra techniques and sealed beasts.", Unlock="", Cards={"rook","hana","yume","tetsu","orin","aurelia","amane","amaya"}},
	{Id="galactic",Name="Galactic Warriors",Text="Alien warriors and awakened transformations.",Unlock="kurogane:Normal",Cards={"kaito","raijen"}},
	{Id="cursed",Name="Cursed Spirits",Text="Curses, domains and binding techniques.",Unlock="rimeveil:Normal",Cards={"mirai","sora","akane","noa","goro","ibuki"}},
	{Id="hunters",Name="Demon Hunters",Text="Sword forms, demon hunters and wisteria medicine.",Unlock="vex:Normal",Cards={"tomo","suzu","luna","hayate"}},
	{Id="souls",Name="Soul Reapers",Text="Spiritual guardians and soul-born techniques.",Unlock="rimeveil:Hard",Cards={"kaede","tsubasa"}},
}
Collections.ById={} :: {[string]:any}
Collections.CardFamily={} :: {[string]:string}
for _, collection in Collections.List do
	Collections.ById[collection.Id]=collection
	for _, id in collection.Cards do
		Collections.CardFamily[id]=collection.Id
		local support=Cards.LegacySupports[id]
		if support then Collections.CardFamily[support]=collection.Id end
	end
end
function Collections.Unlocked(id: string, cleared: {[string]:boolean}): boolean
	local def=Collections.ById[id]
	return def~=nil and (def.Unlock=="" or cleared[def.Unlock]==true)
end
-- Redistribute one quarter of the original non-boss probability among the focused family.
-- This leaves every normal card available and preserves unlocked boss odds exactly.
Collections.FocusShare = 0.25
function Collections.Distribution(id: string?, cleared: {[string]:boolean}, element: string?, elementWeight: number?, featured: string?, luck: number?)
	local pool = Cards.Pool(cleared)
	local chances = Cards.PullChances(pool, element, elementWeight, featured, luck)
	if not id or id == "normal" or not Collections.Unlocked(id, cleared) then
		return pool, chances
	end

	local normalShare, familyShare = 0, 0
	for _, card in pool do
		if not card.Boss then
			normalShare += chances[card.Id]
			if Collections.CardFamily[card.Id] == id then
				familyShare += chances[card.Id]
			end
		end
	end
	if familyShare > 0 then
		for _, card in pool do
			if not card.Boss then
				local original = chances[card.Id]
				chances[card.Id] = original * (1 - Collections.FocusShare)
				if Collections.CardFamily[card.Id] == id then
					chances[card.Id] += Collections.FocusShare * normalShare * original / familyShare
				end
			end
		end
	end
	return pool, chances
end
return Collections
