--!nonstrict
-- Code-native glossy surfaces. Decorations live in a Folder so list/grid layouts never arrange them.
local RunService = game:GetService("RunService")
local Style = {}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(15, 15, 20)
local rotating = {}
local render = nil
local visibilityClock = 0

local function make(class, props, parent)
	local item = Instance.new(class)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end
local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end
local function stroke(parent, color, thickness, transparency)
	return make("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function decorations(target)
	local folder = target:FindFirstChild("VectorDecor")
	if not folder then folder = make("Folder", { Name = "VectorDecor" }, target) end
	return folder
end
-- UIPadding also reaches decorations through their Folder. Cancel its offset for surface edges.
local function fitDecor(target, folder)
	local padding = target:FindFirstChildOfClass("UIPadding")
	if not padding then return end
	local left, right = padding.PaddingLeft.Offset, padding.PaddingRight.Offset
	local top, bottom = padding.PaddingTop.Offset, padding.PaddingBottom.Offset
	for _, frame in folder:GetChildren() do
		if frame:IsA("Frame") then
			local inset = if frame.Name == "InnerBevel" or frame.Name == "Gloss" then 2 elseif frame.Name == "HolographicBorder" then 4 else 0
			local fraction = if frame.Name == "Gloss" then .45 else 1
			frame.Position = UDim2.fromOffset(inset-left, inset-top)
			frame.Size = UDim2.new(1,left+right-2*inset,fraction,(top+bottom)*fraction-2*inset)
		end
	end
end
local function visible(target)
	if not target:IsDescendantOf(game) or target.AbsoluteSize.X <= 0 or target.AbsoluteSize.Y <= 0 then return false end
	local low, high = target.AbsolutePosition, target.AbsolutePosition + target.AbsoluteSize
	local node = target
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then return false end
			if node ~= target and node.ClipsDescendants then
				local p, s = node.AbsolutePosition, node.AbsoluteSize
				low = Vector2.new(math.max(low.X, p.X), math.max(low.Y, p.Y))
				high = Vector2.new(math.min(high.X, p.X+s.X), math.min(high.Y, p.Y+s.Y))
			end
		elseif node:IsA("ScreenGui") then
			if not node.Enabled then return false end
			local size = node.AbsoluteSize
			return high.X > math.max(0, low.X) and high.Y > math.max(0, low.Y) and low.X < size.X and low.Y < size.Y
		elseif node:IsA("BillboardGui") or node:IsA("SurfaceGui") then
			if not node.Enabled then return false end
			local adornee = node.Adornee or node.Parent
			local camera = workspace.CurrentCamera
			if not camera or not adornee or not adornee:IsA("BasePart") then return false end
			local distance = (camera.CFrame.Position - adornee.Position).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(adornee.Position)
			return onScreen and (node.MaxDistance <= 0 or distance <= node.MaxDistance)
		end
		node = node.Parent
	end
	return false
end

-- One RenderStepped connection for every rare border, including Gold. No per-card render callbacks.
function Style.Spin(gradient, owner, speed)
	if rotating[gradient] then return end
	rotating[gradient] = { Owner = owner, Speed = speed or 65, Visible = false }
	gradient.Destroying:Once(function()
		rotating[gradient] = nil
		if next(rotating) == nil and render then render:Disconnect(); render = nil end
	end)
	if render then return end
	visibilityClock = .2
	render = RunService.RenderStepped:Connect(function(dt)
		visibilityClock += dt
		local refresh = visibilityClock >= .2
		if refresh then visibilityClock = 0 end
		for g, entry in rotating do
			if refresh then entry.Visible = visible(entry.Owner) end
			if entry.Visible then g.Rotation = (g.Rotation + dt * entry.Speed) % 360 end
		end
	end)
end

function Style.Text(label)
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 1
	if label.Font ~= Enum.Font.LuckiestGuy then label.Font = Enum.Font.FredokaOne end
	local outline = nil
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then outline = child; break end
	end
	if not outline then
		outline = make("UIStroke", { Name = "VectorTextOutline", ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, label)
		local connection = label:GetPropertyChangedSignal("TextTransparency"):Connect(function() outline.Transparency = label.TextTransparency end)
		outline.Destroying:Once(function() connection:Disconnect() end)
	end
	outline.Color = BLACK
	outline.Thickness = 2.5
	outline.Transparency = label.TextTransparency
end

function Style.Surface(target, color, deep, kind)
	local radius = if kind == "Window" then 14 else 10
	local rounding = target:FindFirstChildOfClass("UICorner") or corner(target, radius)
	rounding.CornerRadius = UDim.new(0, radius)
	target.BorderSizePixel = 0
	-- Keep the direct border used by existing selection / toggle callbacks.
	if not target:FindFirstChildOfClass("UIStroke") then stroke(target, BLACK, 2.5) end
	local gradient = target:FindFirstChildOfClass("UIGradient")
	if not gradient then gradient = make("UIGradient", {}, target) end
	if not color then
		color = gradient.Color.Keypoints[1].Value
		if color == WHITE then color = target.BackgroundColor3 end
		local h,s,v = color:ToHSV()
		color = if v < .35 or s < .15 then Color3.fromRGB(91, 103, 178) else Color3.fromHSV(h, math.max(s, .45), math.max(v, .72))
	end
	deep = deep or color:Lerp(Color3.fromRGB(24, 22, 65), .6)
	gradient.Color = ColorSequence.new(color, deep)
	gradient.Rotation = 90
	gradient.Enabled = true
	target.BackgroundColor3 = WHITE
	local folder = decorations(target)
	if target:IsA("TextButton") and target.Text == "" then
		local oldFill = folder:FindFirstChild("ButtonFill")
		if oldFill then oldFill:Destroy(); target.BackgroundTransparency = 0 end
	end
	-- A gradient on TextButton also tints its own text. Put that fill behind the white label.
	if target:IsA("TextButton") and target.Text ~= "" then
		local fill = folder:FindFirstChild("ButtonFill")
		if not fill then
			fill = make("Frame", { Name = "ButtonFill", Size = UDim2.fromScale(1,1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = target.ZIndex, Active = false }, folder)
			corner(fill, radius)
		end
		local previous = fill:FindFirstChildOfClass("UIGradient")
		if previous and previous ~= gradient then previous:Destroy() end
		gradient.Parent = fill
		target.BackgroundTransparency = 1
		if not folder:FindFirstChild("ButtonLabel") then
			local label = make("TextLabel", { Name = "ButtonLabel", Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, ZIndex = target.ZIndex + 4 }, folder)
			local properties = { "Text", "Font", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "RichText" }
			local connections = {}
			local function sync()
				for _, property in properties do label[property] = target[property] end
				Style.Text(label)
				label.Visible = target.Text ~= ""
			end
			for _, property in properties do table.insert(connections, target:GetPropertyChangedSignal(property):Connect(sync)) end
			label.TextTransparency = target.TextTransparency
			local changing = false
			table.insert(connections, target:GetPropertyChangedSignal("TextTransparency"):Connect(function()
				if changing then return end
				label.TextTransparency = target.TextTransparency
				changing = true; target.TextTransparency = 1; changing = false
			end))
			changing = true; target.TextTransparency = 1; changing = false
			sync()
			label.Destroying:Once(function() for _, connection in connections do connection:Disconnect() end end)
		end
	end
	if not folder:FindFirstChild("OuterEdge") then
		local outer = make("Frame", { Name = "OuterEdge", Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, ZIndex = 20, Active = false }, folder)
		corner(outer, radius); stroke(outer, BLACK, 2.5)
		local bevel = make("Frame", { Name = "InnerBevel", Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), BackgroundTransparency = 1, ZIndex = 21, Active = false }, folder)
		corner(bevel, radius-2); stroke(bevel, WHITE, 1.5, .55)
	end
	if kind ~= "Window" and not folder:FindFirstChild("Gloss") then
		local gloss = make("Frame", { Name = "Gloss", Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,.45,-2), BackgroundColor3 = WHITE, BackgroundTransparency = .88, BorderSizePixel = 0, ZIndex = 3, Active = false }, folder)
		corner(gloss, radius-2)
	end
	fitDecor(target, folder)
	return target
end

function Style.Border(target, id, sequence, color)
	local folder = decorations(target)
	local old = folder:FindFirstChild("HolographicBorder")
	if old then return old end
	local frame = make("Frame", { Name = "HolographicBorder", Position = UDim2.fromOffset(4,4), Size = UDim2.new(1,-8,1,-8), BackgroundTransparency = 1, ZIndex = 22, Active = false }, folder)
	corner(frame, 8)
	local rim = stroke(frame, WHITE, 2.5)
	-- Gold also needs multiple stops so the rotation reads as moving shine.
	local colors = if id == "Gold" then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255,151,24)), ColorSequenceKeypoint.new(.25, Color3.fromRGB(255,223,66)), ColorSequenceKeypoint.new(.5, WHITE), ColorSequenceKeypoint.new(.75, Color3.fromRGB(255,204,36)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,151,24)) }) else sequence
	local gradient = make("UIGradient", { Name = "HolographicGradient", Color = colors, Rotation = 45 }, rim)
	Style.Spin(gradient, target, if id == "Secret" then 100 else 65)
	fitDecor(target, folder)
	return frame
end

function Style.Auto(target)
	if target:IsA("GuiButton") and target.Name ~= "Backdrop" and target.BackgroundTransparency < 1 then
		Style.Surface(target)
	elseif (target:IsA("Frame") or target:IsA("CanvasGroup")) and target.BackgroundTransparency < .9 and target:FindFirstChildOfClass("UICorner") and target:FindFirstChildOfClass("UIStroke") then
		Style.Surface(target, nil, nil, if target.Name == "Panel" then "Window" else nil)
	end
	if (target:IsA("TextLabel") or target:IsA("TextButton")) and (target.Font == Enum.Font.FredokaOne or target.Font == Enum.Font.LuckiestGuy) then Style.Text(target) end
end

return Style
