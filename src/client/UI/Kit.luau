--!nonstrict
-- Small helpers so the UI code reads like a layout, not boilerplate.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Sfx = require(script.Parent.Sfx)
local VectorStyle = require(script.Parent.VectorStyle)

local Kit = {}

-- Kit.new("Frame", { Size = ..., Parent = ... }, { childA, childB })
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				inst[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	VectorStyle.Auto(inst)
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Rounded 8–14 px surfaces. A full-round
-- radius (scale 1) stays round only on square-ish things (dots, badges, round icons); on a long bar or
-- pill it turns sharp too.
function Kit.corner(radius: UDim?): UICorner
	local corner = Kit.new("UICorner", { CornerRadius = if radius ~= nil and radius.Scale == 0 then UDim.new(0, math.clamp(radius.Offset, 8, 14)) else Theme.Corner })
	if radius ~= nil and radius.Scale >= 1 then
		local sizeConnection: RBXScriptConnection? = nil
		local function fit()
			local parent = corner.Parent
			if parent and parent:IsA("GuiObject") then
				local size = parent.AbsoluteSize
				local ratio = if size.Y > 0 then size.X / size.Y else 1
				corner.CornerRadius = if ratio > 0.75 and ratio < 1.34 then radius else Theme.Corner
			end
		end
		corner:GetPropertyChangedSignal("Parent"):Connect(function()
			if sizeConnection then
				sizeConnection:Disconnect()
				sizeConnection = nil
			end
			local parent = corner.Parent
			if parent and parent:IsA("GuiObject") then
				sizeConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
				fit()
			end
		end)
	end
	return corner
end

-- Preserve requested thickness: glossy outlines and animated rare rims use real 2.5 px strokes.
function Kit.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local asked = thickness or 2
	return Kit.new("UIStroke", {
		Color = color,
		Thickness = asked,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Outline around the letters of a TextLabel (not a box around it). It fades with the text, so a
-- hint tweened to TextTransparency 1 doesn't leave its outline behind as ghost letters.
function Kit.textStroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local base = 0
	local stroke = Kit.new("UIStroke", {
		Color = Color3.fromRGB(15, 15, 20),
		Thickness = 2.5,
		Transparency = base,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
	local connection = nil
	stroke:GetPropertyChangedSignal("Parent"):Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		local label = stroke.Parent
		if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
			for _, other in label:GetChildren() do
				if other ~= stroke and other:IsA("UIStroke") and other.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then other:Destroy() end
			end
			local function follow()
				stroke.Transparency = base + (1 - base) * label.TextTransparency
			end
			connection = label:GetPropertyChangedSignal("TextTransparency"):Connect(follow)
			follow()
		end
	end)
	return stroke
end

function Kit.gradient(sequence: ColorSequence, rotation: number?): UIGradient
	return Kit.new("UIGradient", { Color = sequence, Rotation = rotation or 90 })
end

function Kit.twoTone(top: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new(top, bottom)
end

Kit.surface = VectorStyle.Surface
Kit.rareBorder = VectorStyle.Border

function Kit.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.aspect(ratio: number, dominant: Enum.DominantAxis?): UIAspectRatioConstraint
	return Kit.new("UIAspectRatioConstraint", {
		AspectRatio = ratio,
		DominantAxis = dominant or Enum.DominantAxis.Width,
		AspectType = Enum.AspectType.FitWithinMaxSize,
	})
end

function Kit.textMax(max: number, min: number?): UITextSizeConstraint
	return Kit.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 8 })
end

-- Scaled text label with a size cap so it stays crisp on big screens.
function Kit.label(props: { [string]: any }, maxText: number?): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Color.Text,
		Font = Theme.Font.Bold,
		TextScaled = true,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Kit.new("TextLabel", defaults)
	Kit.textMax(maxText or 28).Parent = label
	return label
end

-- A frame's size before any UIScale above it (panels are scaled down on phones): use it wherever a
-- measured size is turned back into offsets, e.g. grid cells.
function Kit.logicalSize(inst: GuiObject): Vector2
	local scale = 1
	local node: Instance? = inst
	while node and not node:IsA("LayerCollector") do
		local uiScale = node:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		node = node.Parent
	end
	return if scale > 0 then inst.AbsoluteSize / scale else inst.AbsoluteSize
end

-- Plays and returns a tween.
function Kit.tween(
	inst: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(inst, info, goal)
	tween:Play()
	return tween
end

-- A drawn symbol, for the glyphs some fonts can't show in game (✕ and ▾ came out as empty boxes): two thin
-- bars, crossed ("Cross") or as a down chevron ("Chevron"). Size and place the returned frame like a label;
-- recolour it with Kit.glyphColor.
function Kit.glyph(kind: string, color: Color3, props: { [string]: any }): Frame
	local holder = Kit.new("Frame", props)
	holder.BackgroundTransparency = 1
	local chevron = kind == "Chevron"
	for i, angle in { 45, -45 } do
		Kit.new("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- A chevron's bars meet at the bottom middle: each sits on its own half, tilted in.
			Position = if chevron then UDim2.fromScale(if i == 1 then 0.32 else 0.68, 0.5) else UDim2.fromScale(0.5, 0.5),
			Size = if chevron then UDim2.new(0.62, 0, 0, 2) else UDim2.new(1.15, 0, 0, 2),
			Rotation = angle,
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			ZIndex = holder.ZIndex,
			Parent = holder,
		}, { Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return holder
end

-- Recolours (or tweens, with `seconds`) a Kit.glyph.
function Kit.glyphColor(glyph: Instance, color: Color3, seconds: number?)
	for _, bar in glyph:GetChildren() do
		if bar:IsA("Frame") then
			if seconds then
				Kit.tween(bar, seconds, { BackgroundColor3 = color })
			else
				bar.BackgroundColor3 = color
			end
		end
	end
end

-- Press feedback: shrink and click on press, spring back on release. Cheap and works on touch.
function Kit.pressable(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		Kit.tween(scale, 0.08, { Scale = 0.92 })
		Sfx.Play("Click")
	end)
	local function release()
		Kit.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- Shared glossy action button; `color` and `deep` define its vertical fill.
function Kit.button(text: string, color: Color3, deep: Color3, props: { [string]: any }?): TextButton
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	local button = Kit.new("TextButton", base, { Kit.corner() })
	VectorStyle.Surface(button, color, deep)
	local label = Kit.label({
		Name = "Label",
		Text = string.upper(text),
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Text,
		Size = UDim2.fromScale(0.86, 0.56),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = button,
	}, 20)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.5).Parent = label
	VectorStyle.Surface(button, color, deep)
	Kit.pressable(button)
	return button
end

-- Greys out a Kit.button (can't afford, locked, maxed) without showing its hidden fill.
function Kit.dim(button: GuiObject, dimmed: boolean)
	Skin.SetDimmed(button, dimmed)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextTransparency = if dimmed then 0.3 else 0
	end
end

-- Glossy tile for gifts, results and rows. TextButton tiles retain press feedback.
function Kit.tile(props: { [string]: any }, edge: Color3?, className: string?): any
	local base = { BackgroundColor3 = Color3.new(1, 1, 1) }
	if className == "TextButton" then
		base.Text = ""
		base.AutoButtonColor = false
	end
	for key, value in props do
		base[key] = value
	end
	if base.BackgroundTransparency == nil then
		base.BackgroundTransparency = Theme.Glass.Frame
	end
	-- Screens such as Wheel recolour this direct stroke for selection feedback.
	local frame = Kit.new(className or "Frame", base, { Kit.corner(), Kit.stroke(edge or Theme.Color.TileEdge, 2.5, 0) })
	if className == "TextButton" then
		Kit.pressable(frame)
	end
	VectorStyle.Surface(frame, edge or Theme.Color.TileTop, Theme.Color.TileBottom)
	return frame
end

-- Greys out a Kit.tile (claimed, locked) with a dark cover, so its gradient never shows through.
-- Labels that must stay readable on top use ZIndex 6 or more.
function Kit.dimTile(frame: GuiObject, dimmed: boolean)
	local cover = frame:FindFirstChild("Dim")
	if cover == nil then
		if not dimmed then
			return
		end
		cover = Kit.new("Frame", {
			Name = "Dim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(5, 7, 12),
			BackgroundTransparency = 0.4,
			ZIndex = 5,
			Parent = frame,
		}, { Kit.corner() })
	end
	cover.Visible = dimmed
end

function Kit.screenGui(name: string, displayOrder: number, parent: Instance): ScreenGui
	return Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
end

function Kit.commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

-- "980", "2.2K", "41.9K", "1.25M": big stats in small spaces.
function Kit.short(n: number): string
	if n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- A card's battle stats as rich text: damage / HP (Attack), real Basic healing / shield / boost (Support), at its
-- stars, border and Awakening node. `long` spells the numbers out with commas.
function Kit.statsText(card, stars: number, border: string?, awaken: number?, long: boolean?): string
	local Cards = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Cards")) :: any
	local fmt = if long then Kit.commas else Kit.short
	local main = fmt(Cards.Stat(card, card.Main, stars, border, awaken))
	if card.Type == "Attack" then
		local hp = fmt(Cards.Stat(card, card.HP or 0, stars, border, awaken))
		return `<font color="#FF7A5C">⚔ DMG <b>{main}</b></font>   <font color="#5CE6A0">❤ HP <b>{hp}</b></font>`
	end
	local CardInfo = require(game:GetService("ReplicatedStorage").Shared.CardInfo)
	return `<font color="#8BDDB1"><b>{CardInfo.Headline(card, stars, border, awaken)}</b></font>`
end

return Kit
