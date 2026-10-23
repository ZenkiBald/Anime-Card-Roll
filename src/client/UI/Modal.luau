--!nonstrict
-- A centred panel over a blurred game world: purple gradient panel, a slanted title banner with a
-- sparkle, and a red close pill. Tap outside or press the close pill to close.

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)

local Modal = {}
Modal.__index = Modal

local openModal = nil -- only one panel open at a time
local blur: BlurEffect? = nil

local PANEL_TOP = Color3.fromRGB(62, 32, 128)
local PANEL_BOTTOM = Color3.fromRGB(22, 13, 50)
local PANEL_EDGE = Color3.fromRGB(150, 110, 255)
local BANNER_LEFT = Color3.fromRGB(150, 100, 255)
local BANNER_RIGHT = Color3.fromRGB(80, 40, 210)

export type Modal = {
	Gui: ScreenGui,
	Panel: Frame,
	Body: Frame,
	Header: Frame,
	IsOpen: boolean,
	Open: (self: Modal) -> (),
	Close: (self: Modal) -> (),
	OnOpen: (() -> ())?,
}

-- The game world behind an open panel goes soft (skipped on low effects).
local function setBlur(on: boolean)
	local effect = blur
	if effect == nil then
		effect = Instance.new("BlurEffect")
		effect.Name = "MenuBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
	end
	local goal = if on and not Theme.FxLow then 14 else 0
	Kit.tween(effect, 0.25, { Size = goal })
end

-- Slanted title banner with a sparkle, used by every panel (and the deck screen).
function Modal.Banner(parent: Instance, title: string, textSize: number?): any -- children read by name
	local banner = Kit.new("Frame", {
		Name = "Banner",
		Position = UDim2.fromOffset(-14, -16),
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -3,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0, 12)),
		Kit.gradient(ColorSequence.new(BANNER_LEFT, BANNER_RIGHT), 0),
		Kit.stroke(Color3.fromRGB(230, 220, 255), 2.5, 0),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 52), PaddingRight = UDim.new(0, 26) }),
	})
	local sparkle = Kit.label({
		Name = "Sparkle",
		Text = "✦",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -24, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		Rotation = 12,
		ZIndex = 7,
		Parent = banner,
	}, 52)
	Kit.textStroke(Color3.fromRGB(70, 30, 160), 2, 0).Parent = sparkle
	local label = Kit.new("TextLabel", {
		Name = "Title",
		Text = title,
		Font = Theme.Font.Display,
		TextSize = textSize or 36,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 6,
		Parent = banner,
	})
	Kit.textStroke(Color3.fromRGB(40, 14, 90), 3, 0).Parent = label
	if Skin.Apply(banner, "Banner") then
		sparkle.Visible = false -- the banner art has its own
	end
	return banner
end

-- Red pill with a cross.
function Modal.CloseButton(parent: Instance): TextButton
	local close = Kit.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -14),
		Size = UDim2.fromOffset(64, 42),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 6,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 110, 110), Color3.fromRGB(215, 40, 70)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.2),
	})
	local cross = Kit.label({
		Text = "✕",
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.7),
		ZIndex = 7,
		Parent = close,
	}, 28)
	Kit.textStroke(Color3.fromRGB(110, 10, 30), 2, 0).Parent = cross
	if Skin.Apply(close, "Close") then
		cross.Visible = false -- the button art has its own X
		close.Size = UDim2.fromOffset(46, 46)
	end
	Kit.pressable(close)
	return close
end

function Modal.new(playerGui: Instance, name: string, title: string, size: Vector2, maxSize: Vector2)
	local self = setmetatable({}, Modal)
	self.IsOpen = false

	self.Gui = Kit.screenGui(name, 10, playerGui)
	self.Gui.Enabled = false

	local backdrop = Kit.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Backdrop,
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Parent = self.Gui,
	})
	backdrop.Activated:Connect(function()
		self:Close()
	end)

	self.Panel = Kit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Active = true, -- taps on the panel don't fall through to the backdrop
		Parent = self.Gui,
	}, {
		Kit.corner(UDim.new(0, 22)),
		Kit.gradient(ColorSequence.new(PANEL_TOP, PANEL_BOTTOM), 90),
		Kit.stroke(PANEL_EDGE, 3, 0),
		Kit.new("UISizeConstraint", { MaxSize = maxSize, MinSize = Vector2.new(280, 220) }),
	})
	self.Scale = Kit.new("UIScale", { Scale = 1, Parent = self.Panel })
	Skin.Apply(self.Panel, "Panel")

	self.Header = Kit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.Panel,
	})
	self.Banner = Modal.Banner(self.Header, title)
	self.TitleLabel = self.Banner.Title
	local close = Modal.CloseButton(self.Header)
	close.Activated:Connect(function()
		self:Close()
	end)

	self.Body = Kit.new("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 16, 0, 62),
		Size = UDim2.new(1, -32, 1, -78),
		BackgroundTransparency = 1,
		Parent = self.Panel,
	})

	return self
end

function Modal:Open()
	if openModal and openModal ~= self then
		openModal:Close()
	end
	openModal = self
	self.IsOpen = true
	self.Gui.Enabled = true
	-- Pop in: the panel rises and grows a little while the backdrop fades in.
	self.Scale.Scale = 0.88
	Kit.tween(self.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	self.Panel.Position = UDim2.fromScale(0.5, 0.57)
	Kit.tween(self.Panel, 0.25, { Position = UDim2.fromScale(0.5, 0.52) }, Enum.EasingStyle.Back)
	local backdrop = self.Gui:FindFirstChild("Backdrop")
	if backdrop then
		backdrop.BackgroundTransparency = 1
		Kit.tween(backdrop, 0.2, { BackgroundTransparency = 0.45 })
	end
	setBlur(true)
	if self.OnOpen then
		self.OnOpen()
	end
end

function Modal:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	if openModal == self then
		openModal = nil
		setBlur(false)
	end
	self.Gui.Enabled = false
end

function Modal:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

return Modal
