--!strict
-- Transparent HUD illustrations. Originals / prompts are archived in art/ui/hud-20261027.
local HudArt = {}
HudArt.Images = {
	["Shards"] = "rbxassetid://104477532061320",
	["TraitShards"] = "rbxassetid://80305379140804",
	["Rolls"] = "rbxassetid://92265987310575",
	["BATTLE"] = "rbxassetid://114549229091042",
	["SQUAD"] = "rbxassetid://121303037435507",
	["BAG"] = "rbxassetid://111424587919185",
	["QUESTS"] = "rbxassetid://77899831063484",
	["TRAVEL"] = "rbxassetid://107396879277204",
	["STORE"] = "rbxassetid://98574282654920",
	["DEV"] = "rbxassetid://130478163417782",
} :: { [string]: string }
function HudArt.Get(key: string): string?
	return HudArt.Images[key]
end
return HudArt
