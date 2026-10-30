--!strict
-- Individual transparent BAG illustrations; generated sources / prompts live in art/ui/bag-20261027.
local Art = {}
Art.Images = {
	["Pack:10"] = "rbxassetid://75063773323372",
	["Pack:100"] = "rbxassetid://116467113731774",
	["Pack:1000"] = "rbxassetid://73224833848812",
	["Pack:10000"] = "rbxassetid://73224833848812",
	["Potion:luck"] = "rbxassetid://122750737102872",
	["Potion:speed"] = "rbxassetid://76106395983375",
	["Potion:superluck"] = "rbxassetid://117584023617913",
	["Potion:mythic"] = "rbxassetid://84666551247218",
	["Artifact:voideye"] = "rbxassetid://124981086592443",
	["Artifact:stormcrown"] = "rbxassetid://119274663822471",
	["Artifact:emberheart"] = "rbxassetid://100117473885658",
	["Artifact:frostsigil"] = "rbxassetid://123358194650116",
	["Artifact:prism"] = "rbxassetid://101576920018294",
	["Artifact:moonstone"] = "rbxassetid://97349712802606",
	["Artifact:clover"] = "rbxassetid://125609199905602",
	["Artifact:hourglass"] = "rbxassetid://76106395983375",
	["Artifact:coin"] = "rbxassetid://103961861780304",
	["Artifact:tome"] = "rbxassetid://137900483147880",
	["TowerArtifact:hundredcrown"] = "rbxassetid://105171321525201",
} :: { [string]: string }

function Art.Get(key: string): string?
	if string.sub(key, 1, 10) == "Pack:1000:" then return Art.Images["Pack:1000"] end
	return Art.Images[key]
end

return Art
