--!strict
-- Collection packs select the normal pool; consumable Roll Packs merely supply pulls from it.
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
function Collections.Pool(id: string?, cleared: {[string]:boolean}): {Cards.Card}
	local selected=if id and Collections.Unlocked(id,cleared) then id else "normal"
	local pool={}
	for _, card in Cards.Pool(cleared) do
		if selected=="normal" or card.Boss~=nil or Collections.CardFamily[card.Id]==selected then table.insert(pool,card) end
	end
	return pool
end
return Collections
