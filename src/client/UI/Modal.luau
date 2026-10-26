--!nonstrict
-- A centred panel over a blurred game world: dark obsidian glass with a thin edge, a sharp title tab
-- with a neon underline, and a close button. Tap outside or press close to close.
-- Modal.Tabbed is one panel with a tab strip: each tab holds pages that screens build into exactly
-- as if they were their own Modal (page.Body / page.Header / page:Open() / page.IsOpen / OnOpen), and a
-- tab can hold two pages side by side (Region "Left" / "Right").

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("UITheme"))
local Skin = require(script.Parent.Skin)

local Modal = {}
Modal.__index = Modal

local openModal = nil -- only one panel open at a time
local changed = Instance.new("BindableEvent")
-- Fires (anyOpen: boolean) when the first panel opens or the last one closes (Main hides world signs).
Modal.Changed = changed.Event
local blur: BlurEffect? = nil

local C = UITheme.Colors
local PANEL_TOP = C.UrushiRaised:Lerp(C.UrushiBase, 0.5) -- Urushi lacquer, a touch lighter at the top
local PANEL_BOTTOM = C.UrushiBase
local BANNER_LEFT = C.UrushiRaised
local BANNER_RIGHT = C.UrushiBase

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

-- Title tab used by every panel (and the deck screen): an Urushi plate with a steel edge, a vermilion
-- seal slash on its left and a vermilion underline, the title in parchment caps.
function Modal.Banner(parent: Instance, title: string, textSize: number?): any -- children read by name
	local banner = Kit.new("Frame", {
		Name = "Banner",
		Position = UDim2.fromOffset(-6, -10),
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = parent,
	}, {
		Kit.corner(),
		Kit.gradient(ColorSequence.new(BANNER_LEFT, BANNER_RIGHT), 0),
		Kit.stroke(Theme.Color.Line, 1.2, 0),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 22) }),
	})
	local sparkle = Kit.new("Frame", {
		Name = "Sparkle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -15, 0.5, 0),
		Size = UDim2.new(0, 5, 0.62, 0),
		Rotation = 14,
		BorderSizePixel = 0,
		BackgroundColor3 = C.VermilionWax,
		ZIndex = 7,
		Parent = banner,
	})
	Kit.new("Frame", {
		Name = "Underline",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -30, 1, 0),
		Size = UDim2.new(1, 52, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = C.VermilionWax,
		ZIndex = 7,
		Parent = banner,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	local label = Kit.new("TextLabel", {
		Name = "Title",
		Text = string.upper(title),
		Font = Theme.Font.Display,
		TextSize = math.floor((textSize or 36) * 0.8),
		TextColor3 = Theme.Color.Text,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 6,
		Parent = banner,
	})
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.4).Parent = label
	-- The panel supplies the artwork; keep its heading quiet and readable over a plain surface.
	banner.BackgroundTransparency = 1
	banner:FindFirstChildOfClass("UIGradient").Enabled = false
	banner:FindFirstChildOfClass("UIStroke").Enabled = false
	sparkle.BackgroundColor3 = Theme.Color.Gold
	banner.Underline.BackgroundColor3 = Theme.Color.Gold
	return banner
end

-- Close: a 32 px dark obsidian square, 4 px corners, a grey ✕ that glows red on hover.
local CLOSE_GREY = Color3.fromRGB(150, 158, 178)
local CLOSE_RED = Color3.fromRGB(255, 90, 105)

function Modal.CloseButton(parent: Instance): TextButton
	local close = Kit.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, -2),
		Size = UDim2.fromOffset(32, 32),
		AutoButtonColor = false,
		BackgroundColor3 = C.UrushiInset,
		Text = "",
		ZIndex = 6,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0, 4)),
		Kit.stroke(Theme.Color.Line, 1.2, 0),
	})
	-- The ✕ is drawn (the character shows as an empty box in game).
	local cross = Kit.glyph("Cross", CLOSE_GREY, {
		Name = "Cross",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		ZIndex = 7,
		Parent = close,
	})
	local stroke = close:FindFirstChildOfClass("UIStroke") :: UIStroke
	local function hover(on: boolean)
		Kit.glyphColor(cross, if on then CLOSE_RED:Lerp(Color3.new(1, 1, 1), 0.35) else CLOSE_GREY, 0.12)
		Kit.tween(stroke, 0.12, { Color = if on then CLOSE_RED else Theme.Color.Line })
	end
	close.MouseEnter:Connect(function()
		hover(true)
	end)
	close.MouseLeave:Connect(function()
		hover(false)
	end)
	Kit.pressable(close)
	return close
end

-- How much a panel is scaled down on this screen: 1 on a desktop or tablet, about 0.6 on a phone held
-- sideways (the HUD's left column uses the same rule).
function Modal.FitScale(view: Vector2): number
	return math.clamp(math.min(view.X / 1100, view.Y / 640), 0.6, 1)
end

-- Whether any panel is open (the quick roll pops wait while one is).
function Modal.AnyOpen(): boolean
	return openModal ~= nil
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
		BackgroundTransparency = 0.25,
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
		BackgroundTransparency = Theme.Glass.Panel,
		ZIndex = 2,
		Active = true, -- taps on the panel don't fall through to the backdrop
		Parent = self.Gui,
	}, {
		Kit.corner(),
		Kit.gradient(ColorSequence.new(PANEL_TOP, PANEL_BOTTOM), 90),
		Kit.stroke(C.TamahaganeSlate, 2, 0),
		Kit.new("UISizeConstraint", { Name = "Limit", MaxSize = maxSize, MinSize = Vector2.new(280, 220) }),
	})
	self.Scale = Kit.new("UIScale", { Scale = 1, Parent = self.Panel })
	Skin.Apply(self.Panel, "Panel")
	-- Phones: the panel is laid out at desktop size and scaled down to the screen (Modal.FitScale), so a
	-- short landscape screen shows the same layout smaller instead of squashing rows to nothing. It
	-- also takes almost the whole screen there.
	self.Fit = 1
	local function fit()
		local view = self.Gui.AbsoluteSize
		if view.X < 1 or view.Y < 1 then
			return
		end
		local scale = Modal.FitScale(view)
		local compact = scale < 0.85
		local width = if compact then math.max(size.X, 0.97) else size.X
		local height = if compact then math.max(size.Y, 0.96) else size.Y
		self.Fit = scale
		self.Panel.Size = UDim2.fromScale(width / scale, height / scale)
		-- A phone is wide for its height: let the panel run a little wider than on a desktop.
		self.Panel.Limit.MaxSize = if compact then Vector2.new(maxSize.X * 1.25, maxSize.Y) else maxSize
		self.Scale.Scale = scale
	end
	self.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

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
	local was = openModal
	openModal = self
	if was == nil then
		changed:Fire(true)
	end
	self.IsOpen = true
	self.Gui.Enabled = true
	-- Pop in: the panel rises and grows a little while the backdrop fades in.
	local rest = if self.Fit < 0.85 then 0.5 else 0.52
	self.Scale.Scale = 0.88 * self.Fit
	Kit.tween(self.Scale, 0.25, { Scale = self.Fit }, Enum.EasingStyle.Back)
	self.Panel.Position = UDim2.fromScale(0.5, rest + 0.05)
	Kit.tween(self.Panel, 0.25, { Position = UDim2.fromScale(0.5, rest) }, Enum.EasingStyle.Back)
	local backdrop = self.Gui:FindFirstChild("Backdrop")
	if backdrop then
		backdrop.BackgroundTransparency = 1
		Kit.tween(backdrop, 0.2, { BackgroundTransparency = 0.38 })
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
		changed:Fire(false)
	end
	self.Gui.Enabled = false
	if self.OnClose then
		self.OnClose()
	end
end

function Modal:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

-- Tabbed panels ------------------------------------------------------------------------------------

local Page = {}
Page.__index = Page

-- Active: a raised Urushi plate with a vermilion edge along its bottom; inactive: bare ghost text.
local function styleTab(button: TextButton, on: boolean)
	button.TextColor3 = if on then C.WashiParchment else C.WashiGhost
	button.BackgroundTransparency = if on then 0 else 1
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.TamahaganeSlate
		stroke.Transparency = if on then 0 else 1
	end
	local bar = button:FindFirstChild("Bar")
	if bar then
		bar.Visible = on
	end
end

-- One panel, `tabs` along the top of its body (in order). Build pages into it with host:Page(tab).
function Modal.Tabbed(playerGui: Instance, name: string, title: string, size: Vector2, maxSize: Vector2, tabs: { string })
	local host = Modal.new(playerGui, name, title, size, maxSize)
	host.TabOrder = tabs
	host.TabButtons = {}
	host.Pages = {} -- [tab] = { page }
	host.Current = tabs[1]
	local strip = Kit.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = host.Body,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	host.Content = Kit.new("Frame", {
		Name = "Content",
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		Parent = host.Body,
	})
	for i, tab in tabs do
		local button = Kit.new("TextButton", {
			Name = tab,
			LayoutOrder = i,
			AutoButtonColor = false,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.UrushiRaised,
			Font = Theme.Font.Heavy,
			Text = tab,
			TextSize = 17,
			Parent = strip,
		}, {
			Kit.corner(),
			Kit.stroke(Theme.Color.Line, 1.2, 0),
			Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		})
		Kit.new("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 36, 0, 2),
			BorderSizePixel = 0,
			BackgroundColor3 = C.VermilionWax,
			Visible = false,
			Parent = button,
		})
		styleTab(button, false)
		button.Activated:Connect(function()
			host:Show(tab)
		end)
		Kit.pressable(button)
		host.TabButtons[tab] = button
		host.Pages[tab] = {}
	end
	host.OnOpen = function()
		host:ApplyTab()
	end
	host.OnClose = function()
		for _, pages in host.Pages do
			for _, page in pages do
				if page.IsOpen then
					page.IsOpen = false
					if page.OnClose then
						page.OnClose()
					end
				end
			end
		end
	end
	return host
end

-- Opens the panel on `tab` (or switches to it).
function Modal:Show(tab: string)
	self.Current = tab
	if self.IsOpen then
		self:ApplyTab()
	else
		self:Open() -- OnOpen applies the tab
	end
end

function Modal:ApplyTab()
	for _, tab in self.TabOrder do
		local on = tab == self.Current
		styleTab(self.TabButtons[tab], on)
		for _, page in self.Pages[tab] do
			page.Frame.Visible = on
			page.Header.Visible = on
			local was = page.IsOpen
			page.IsOpen = on
			if on and not was and page.OnOpen then
				page.OnOpen()
			elseif was and not on and page.OnClose then
				page.OnClose()
			end
		end
	end
end

-- Relabels a tab (e.g. a ✓ once Kenji's path is done).
function Modal:SetTabText(tab: string, text: string)
	local button = self.TabButtons[tab]
	if button then
		button.Text = text
	end
end

-- A page on `tab`. Without `region` it fills the tab and its Header overlays the panel's header;
-- with region "Left" / "Right" it takes that half, under its own small header titled `heading`.
function Modal:Page(tab: string, region: string?, heading: string?)
	local frame = Kit.new("Frame", {
		Name = tab .. (region or ""),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.Content,
	})
	local header, body
	if region then
		frame.Size = UDim2.new(0.5, -8, 1, 0)
		frame.Position = if region == "Right" then UDim2.new(0.5, 8, 0, 0) else UDim2.new()
		header = Kit.new("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Kit.label({
			Name = "Heading",
			Text = string.upper(heading or tab),
			Font = Theme.Font.Display,
			TextColor3 = C.WashiParchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.5, 0, 0, 22),
			Parent = header,
		}, 18)
		body = Kit.new("Frame", {
			Name = "Body",
			Position = UDim2.new(0, 0, 0, 56),
			Size = UDim2.new(1, 0, 1, -56),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		-- A thin rule between the two halves.
		if region == "Right" then
			Kit.new("Frame", {
				Name = "Rule",
				Position = UDim2.new(0, -8, 0, 0),
				Size = UDim2.new(0, 1, 1, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Theme.Color.Line,
				Parent = frame,
			})
		end
	else
		header = Kit.new("Frame", {
			Name = tab,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = self.Header,
		})
		body = frame
	end
	local page = setmetatable({
		Host = self,
		Tab = tab,
		Gui = self.Gui,
		Panel = self.Panel,
		Frame = frame,
		Header = header,
		Body = body,
		IsOpen = false,
	}, Page)
	table.insert(self.Pages[tab], page)
	return page
end

function Page:Open()
	self.Host:Show(self.Tab)
end

function Page:Close()
	if self.IsOpen then
		self.Host:Close()
	end
end

function Page:Toggle()
	if self.IsOpen then
		self.Host:Close()
	else
		self.Host:Show(self.Tab)
	end
end

return Modal
