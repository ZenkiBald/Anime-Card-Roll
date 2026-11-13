--!nonstrict
-- Matching transparent icons; sources, prompts and receipts live in art/ui/traits-20261113.
local Kit = require(script.Parent.Kit)
local Art = {}
Art.Images = {
	eager = "rbxassetid://97038139511218",
	charged = "rbxassetid://75031846068424",
	fleet = "rbxassetid://123180438967045",
	sturdy = "rbxassetid://94409701219530",
	sharp = "rbxassetid://136257003568581",
	keen = "rbxassetid://107837530998657",
	swift = "rbxassetid://135973696132504",
	stalwart = "rbxassetid://110680453605726",
	tempest = "rbxassetid://134067588643187",
	eternal = "rbxassetid://135837378388872",
	assassin = "rbxassetid://79703869659632",
	apex = "rbxassetid://80106047555083",
	executioner = "rbxassetid://84368299925530",
	godspeed = "rbxassetid://78768396963901",
	sovereign = "rbxassetid://85247668188414",
	bulwark = "rbxassetid://135485470568415",
}

function Art.Get(id: string?): string?
	return if id then Art.Images[id] else nil
end

function Art.Icon(parent: Instance, id: string?, props): ImageLabel
	local options = {Name="TraitIcon", BackgroundTransparency=1, Image=Art.Get(id) or "",
		ScaleType=Enum.ScaleType.Fit, Size=UDim2.fromOffset(40,40), Parent=parent}
	for key,value in props or {} do options[key]=value end
	return Kit.new("ImageLabel", options)
end

function Art.Preload()
	task.spawn(function()
		local images = {}
		for _,image in Art.Images do table.insert(images,image) end
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(images) end)
	end)
end

return Art
