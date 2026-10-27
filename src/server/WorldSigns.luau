--!nonstrict
-- Small nearby NPC plates and physical gate plaques. The client fades them together with the HUD.
local CollectionService = game:GetService("CollectionService")
local Signs = {}

local function make(class, props, parent)
	local item = Instance.new(class)
	for key,value in props do item[key] = value end
	item.Parent = parent
	return item
end

local function text(parent, name, value, y, height, cap, color)
	local label = make("TextLabel", { Name = name, Text = value, Font = Enum.Font.FredokaOne,
		BackgroundTransparency = 1, TextColor3 = color, TextScaled = true, TextWrapped = true,
		Position = UDim2.fromScale(.04,y), Size = UDim2.fromScale(.92,height), ZIndex = 2 }, parent)
	make("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = cap }, label)
	make("UIStroke", { Color = Color3.fromRGB(10,13,21), Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, label)
	return label
end

function Signs.Npc(parent, offset, title, sub, color)
	local gui = make("BillboardGui", { Name = "Sign", Size = UDim2.fromOffset(178,48),
		StudsOffset = Vector3.new(0,math.min(offset,4.3),0), MaxDistance = 76,
		LightInfluence = 0, AlwaysOnTop = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parent)
	gui:SetAttribute("NearTitle",title)
	gui:SetAttribute("ShortTitle",if title == "HOSHI" then "FUSION" elseif title == "KENSHIN" then "TRAITS" elseif title == "KENJI" then "GUIDE" else title)
	gui:SetAttribute("DetailRange",38)
	local plate = make("CanvasGroup", { Name = "Plate", Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(23,30,45), BackgroundTransparency = .08 }, gui)
	make("UICorner", { CornerRadius = UDim.new(0,9) }, plate)
	make("UIStroke", { Color = color, Thickness = 1.5, Transparency = .2 }, plate)
	text(plate,"Title",title,.03,.51,21,Color3.new(1,1,1))
	text(plate,"Sub",sub,.56,.35,15,color:Lerp(Color3.new(1,1,1),.25))
	CollectionService:AddTag(gui,"FadeSign")
	return gui
end

function Signs.Plaque(parent, name, cf, size, title, sub, color)
	local board = make("Part", { Name = name, CFrame = cf, Size = size,
		Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		Material = Enum.Material.Wood, Color = Color3.fromRGB(28,36,44),
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, parent)
	for _,face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = make("SurfaceGui", { Name = if face == Enum.NormalId.Front then "Sign" else "SignBack",
			Face = face, CanvasSize = Vector2.new(720,160), LightInfluence = 0,
			AlwaysOnTop = false, MaxDistance = 145 }, board)
		local plate = make("CanvasGroup", { Name = "Plate", Size = UDim2.fromScale(1,1), BackgroundTransparency = 1 }, gui)
		make("Frame", { Position = UDim2.fromScale(.025,.04), Size = UDim2.fromScale(.95,.035),
			BackgroundColor3 = color, BorderSizePixel = 0 }, plate)
		text(plate,"Title",title,.1,.51,64,Color3.fromRGB(255,240,201))
		text(plate,"Sub",sub,.65,.26,35,color:Lerp(Color3.new(1,1,1),.3))
		CollectionService:AddTag(gui,"FadeSign")
	end
	return board
end

return Signs
