--!nonstrict
-- JuicyButton: the occult action button feel, shared by the roll console and the battle unit pods.
--   * Spirit sheen: a "Sheen" rim over the button's own border, whose UIStroke carries a UIGradient (a
--     narrow bright band) that sweeps Offset -1 -> 1 forever (one engine tween, no script loop; still
--     when effects are LOW).
--   * Spring scale (a UIScale on the button, or on `ScaleTarget` so it stacks with a scale the button
--     already animates): hover 1.05 (Quad Out 0.15 s, the sheen goes fully opaque), press 0.95 (Quad Out
--     0.08 s), release springs back to 1.05 (Back Out 0.25 s), or to 1 on touch, where there is no hover.
--   * Sound: a high spirit shimmer on hover, a heavy blade knock on press (Sfx SpiritHover / BladeClick).
--   * Content: JuicyButton.new puts its contents in a CanvasGroup ("Content", same corner as the button),
--     so cooldown sweeps and drain fills clip cleanly against the border, without pixel bleed past the
--     corners. JuicyButton.Content(button) adds one to an existing button.
-- Don't combine it with Kit.pressable on the same button: both drive the press scale.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Sfx)
local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("UITheme"))

local JuicyButton = {}

local HOVER = 1.05
local PRESS = 0.95
local SWEEP_SECONDS = 2.4
local SHEEN_REST = 0.55 -- the sheen rim's transparency when not hovered

local hoverInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local pressInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local releaseInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function cornerOf(button: GuiObject): UDim
	local corner = button:FindFirstChildOfClass("UICorner")
	return if corner then corner.CornerRadius else Theme.Corner
end

-- The flowing rim: a transparent frame over the button with a stroke whose gradient band sweeps across.
local function sheen(button: GuiObject, color: Color3, thickness: number): UIStroke
	local rim = Kit.new("Frame", {
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = button.ZIndex + 8,
		Parent = button,
	}, { Kit.new("UICorner", { CornerRadius = cornerOf(button) }) })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Transparency = SHEEN_REST
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = rim
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = stroke
	if not Theme.FxLow then
		TweenService:Create(gradient, TweenInfo.new(SWEEP_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Offset = Vector2.new(1, 0),
		}):Play()
	end
	return stroke
end

-- Hooks the sheen, the spring scale and the sounds onto a button. Options: SheenColor, SheenThickness,
-- ScaleTarget (the GuiObject that gets the UIScale; default the button), Silent (no sounds).
-- Returns { Scale, Sheen }.
function JuicyButton.Apply(button: GuiButton, options: { [string]: any }?)
	local o = options or {}
	local target: GuiObject = o.ScaleTarget or button
	local scale = target:FindFirstChild("JuicyScale") or Kit.new("UIScale", { Name = "JuicyScale", Scale = 1, Parent = target })
	local rim = sheen(button, o.SheenColor or UITheme.Colors.SpiritSheen, o.SheenThickness or 2)
	local hovering = false
	local function to(value: number, info: TweenInfo)
		TweenService:Create(scale, info, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		if touchOnly() then
			return
		end
		hovering = true
		to(HOVER, hoverInfo)
		TweenService:Create(rim, hoverInfo, { Transparency = 0 }):Play()
		if not o.Silent then
			Sfx.Play("SpiritHover")
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		to(1, hoverInfo)
		TweenService:Create(rim, hoverInfo, { Transparency = SHEEN_REST }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		to(PRESS, pressInfo)
		if not o.Silent then
			Sfx.Play("BladeClick")
		end
	end)
	button.MouseButton1Up:Connect(function()
		if touchOnly() or not hovering then
			-- Touch: spring past rest, then settle (there's no hover to stay in).
			to(HOVER, releaseInfo)
			task.delay(0.25, function()
				if not hovering then
					to(1, hoverInfo)
				end
			end)
		else
			to(HOVER, releaseInfo)
		end
	end)
	return { Scale = scale, Sheen = rim }
end

-- Moves a button's visual contents into a CanvasGroup with the button's corner, so fills and sweeps
-- inside clip to its shape. `keep` names children that stay outside (strokes, overlays that pulse past
-- the edge). Returns the CanvasGroup.
function JuicyButton.Content(button: GuiObject, keep: { [string]: boolean }?): CanvasGroup
	local group = Kit.new("CanvasGroup", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = button.ZIndex,
	}, { Kit.new("UICorner", { CornerRadius = cornerOf(button) }) })
	for _, child in button:GetChildren() do
		if child:IsA("GuiObject") and not (keep and keep[child.Name]) then
			child.Parent = group
		end
	end
	group.Parent = button
	return group
end

-- A new button in the occult style: Urushi lacquer face, a Tamahagane steel border, the sheen, the
-- spring, and a CanvasGroup "Content" holding the label. props: Text, Color (the accent: trim and
-- label glow), Size, Position, AnchorPoint, LayoutOrder, Name, ZIndex, Parent, TextSize.
function JuicyButton.new(props: { [string]: any }): TextButton
	local accent: Color3 = props.Color or UITheme.Colors.VermilionSeal
	local button = Kit.new("TextButton", {
		Name = props.Name or "JuicyButton",
		Size = props.Size or UDim2.fromOffset(160, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, {
		Kit.corner(),
		Kit.gradient(ColorSequence.new(UITheme.Colors.UrushiRaised:Lerp(accent, 0.18), UITheme.Colors.UrushiBlack), 90),
	})
	local steel = Instance.new("UIStroke")
	steel.Name = "Steel"
	steel.Thickness = 2
	steel.Color = UITheme.Colors.Tamahagane
	steel.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	steel.Parent = button
	local content = JuicyButton.Content(button)
	Kit.new("Frame", {
		Name = "Trim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = accent,
		Parent = content,
	})
	local label = Kit.label({
		Name = "Label",
		Text = string.upper(props.Text or ""),
		Font = Theme.Font.Display,
		TextColor3 = UITheme.Colors.WashiParchment,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.86, 0.56),
		Parent = content,
	}, props.TextSize or 22)
	Kit.textStroke(Color3.new(0, 0, 0), 1, 0.4).Parent = label
	Kit.surface(button, accent, accent:Lerp(Color3.fromRGB(24, 22, 65), .6))
	JuicyButton.Apply(button, { SheenColor = accent:Lerp(Color3.new(1, 1, 1), 0.5) })
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

return JuicyButton
