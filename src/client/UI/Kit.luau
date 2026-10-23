--!nonstrict
-- Small helpers so the UI code reads like a layout, not boilerplate.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Sfx = require(script.Parent.Sfx)

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
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Sharp 5 px corners everywhere (Theme.Corner), or a smaller offset when one is asked for. A full-round
-- radius (scale 1) stays round only on square-ish things (dots, badges, round icons); on a long bar or
-- pill it turns sharp too.
function Kit.corner(radius: UDim?): UICorner
	local small = radius ~= nil and radius.Scale == 0 and radius.Offset <= 6 -- a sharper corner asked for
	local corner = Kit.new("UICorner", { CornerRadius = if small then radius else Theme.Corner })
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

-- Thin edges: anything up to 2 px draws at Theme.Stroke (1.2); heavier (an active or rare highlight)
-- at 2. The colour is the caller's: slate for plain frames, neon for rare / active ones.
function Kit.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local asked = thickness or 2
	return Kit.new("UIStroke", {
		Color = color,
		Thickness = if asked <= 2 then Theme.Stroke else 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Outline around the letters of a TextLabel (not a box around it). It fades with the text, so a
-- hint tweened to TextTransparency 1 doesn't leave its outline behind as ghost letters.
function Kit.textStroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local base = transparency or 0
	local stroke = Kit.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
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

-- Standard panel button with a label: dark metallic body (a bevel: lighter top edge, darker base) with
-- neon trim and a glowing base line in `color`. `deep` tints the body.
local METAL_TOP = Color3.fromRGB(34, 40, 58)
local METAL_BOTTOM = Color3.fromRGB(12, 15, 23)

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
	local button = Kit.new("TextButton", base, {
		Kit.corner(),
		Kit.gradient(Kit.twoTone(METAL_TOP:Lerp(deep, 0.35), METAL_BOTTOM:Lerp(deep, 0.12)), 90),
		Kit.stroke(color, 1.2, 0.05),
	})
	-- Bevel: a faint light line along the top edge, and the neon glow line along the base.
	Kit.new("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 3, 0, 1),
		Size = UDim2.new(1, -6, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Parent = button,
	})
	Kit.new("Frame", {
		Name = "Trim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -10, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Parent = button,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.8) }),
		}),
	})
	Skin.Apply(button, Skin.ButtonFor(color)) -- uploaded button art, when there is some
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

-- Tile for inside panels (gift boxes, result stats, rows): slate glass a step above the panel, a thin
-- edge (pass a neon `edge` for rare / active ones) and a hairline of light along the top. `edge` recolours the outline; `className` "TextButton" makes the
-- whole tile tappable (with the usual press bounce).
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
	local frame = Kit.new(className or "Frame", base, {
		Kit.corner(),
		Kit.gradient(ColorSequence.new(Theme.Color.TileTop, Theme.Color.TileBottom), 90),
		Kit.stroke(edge or Theme.Color.TileEdge, 1.2, 0.1),
	})
	Kit.new("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 4, 0, 1),
		Size = UDim2.new(1, -8, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		Parent = frame,
	})
	if className == "TextButton" then
		Kit.pressable(frame)
	end
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

return Kit
