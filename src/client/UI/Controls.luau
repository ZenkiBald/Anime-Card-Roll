--!nonstrict
-- Shared menu controls in the Dark Feudal style: sunken Urushi wells with Tamahagane slate bezels (gold
-- leaf when active): dropdown pills (Sort / Filter / Element), tabs with a vermilion underline, a search
-- box, section banners with a coloured bar, small square icon buttons and toggle chips.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Controls = {}

Controls.Purple = Theme.Color.Neon -- the active accent: gold leaf (kept under its old name)
Controls.PurpleDeep = Color3.fromRGB(70, 52, 20)
Controls.Outline = Color3.fromRGB(8, 10, 16)

local CORNER = UDim.new(0, 4)
local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("UITheme"))
local TILE_TOP = UITheme.Colors.UrushiInset -- a sunken well, darker at the top
local TILE_BOTTOM = UITheme.Colors.UrushiBase

local function outlined(label: TextLabel, thickness: number?)
	Kit.textStroke(Controls.Outline, math.min(thickness or 1, 1), 0.3).Parent = label
	return label
end
Controls.Outlined = outlined

-- A dark tile: the base of every control here.
local function tile(className: string, props: { [string]: any }, edge: Color3?): any
	local base = { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Text = "" }
	if className == "Frame" then
		base.AutoButtonColor = nil
		base.Text = nil
	end
	for key, value in props do
		base[key] = value
	end
	return Kit.new(className, base, {
		Kit.corner(CORNER),
		Kit.gradient(ColorSequence.new(TILE_TOP, TILE_BOTTOM), 90),
		Kit.stroke(edge or UITheme.Colors.TamahaganeSlate, 1.5, 0),
	})
end
Controls.Tile = tile

-- "Sort  Power ▾": a dropdown tile. Tap it for the list of `options`; picking one calls onChange.
local openList: Frame? = nil

local function closeList()
	if openList then
		openList:Destroy()
		openList = nil
	end
end

function Controls.Option(parent: Instance, caption: string, options: { string }, order: number, onChange: (string) -> ())
	local current = options[1]
	local button = tile("TextButton", {
		Name = caption,
		LayoutOrder = order,
		Size = UDim2.new(0, 132, 1, 0),
		ZIndex = 4,
		Parent = parent,
	})
	Kit.label({
		Name = "Caption",
		Text = string.upper(caption),
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 10, 0.08, 0),
		Size = UDim2.new(1, -30, 0.36, 0),
		ZIndex = 5,
		Parent = button,
	}, 11)
	local value = Kit.label({
		Name = "Value",
		Text = current,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 10, 0.42, 0),
		Size = UDim2.new(1, -30, 0.5, 0),
		ZIndex = 5,
		Parent = button,
	}, 16)
	-- The ▾ is drawn (the character shows as an empty box in game).
	Kit.glyph("Chevron", Theme.Color.Neon, {
		Name = "Arrow",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(12, 8),
		ZIndex = 5,
		Parent = button,
	})
	Kit.pressable(button)
	button.Activated:Connect(function()
		local wasMine = openList and openList.Parent == button
		closeList()
		if wasMine then
			return
		end
		button.UIStroke.Color = Theme.Color.Neon
		local list = tile("Frame", {
			Name = "List",
			Position = UDim2.new(0, 0, 1, 4),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 40,
			Parent = button,
		}, Theme.Color.Neon)
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = list })
		for i, option in options do
			local item = Kit.new("TextButton", {
				LayoutOrder = i,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Theme.Color.Neon,
				BackgroundTransparency = if option == current then 0.82 else 1,
				Font = Theme.Font.Heavy,
				Text = "  " .. option,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if option == current then Theme.Color.Neon else Theme.Color.Text,
				TextSize = 15,
				ZIndex = 41,
				Parent = list,
			})
			item.Activated:Connect(function()
				current = option
				value.Text = option
				closeList()
				onChange(option)
			end)
		end
		-- Near the bottom of the screen the list opens upward instead.
		local screen = button:FindFirstAncestorWhichIsA("LayerCollector")
		local height = #options * 28 + 6
		if screen and button.AbsolutePosition.Y + button.AbsoluteSize.Y + height + 8 > screen.AbsoluteSize.Y then
			list.AnchorPoint = Vector2.new(0, 1)
			list.Position = UDim2.new(0, 0, 0, -4)
		end
		openList = list
		list.Destroying:Connect(function()
			if button.Parent then
				button.UIStroke.Color = Theme.Color.Line
			end
		end)
	end)
	return button
end

-- A tab: dark tile, neon underline and bright text when on. Returns the button and its on / off setter.
function Controls.Tab(parent: Instance, text: string, color: Color3, order: number, width: number?)
	local button = tile("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, width or 140, 1, 0),
		Parent = parent,
	})
	local label = Kit.label({
		Text = string.upper(text),
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.86, 0.5),
		Parent = button,
	}, 18)
	local bar = Kit.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -8, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = button,
	})
	Kit.pressable(button)
	local function set(on: boolean)
		bar.Visible = on
		button.UIStroke.Color = if on then color else Theme.Color.Line
		label.TextColor3 = if on then Theme.Color.Text else Theme.Color.Muted
	end
	return button, set
end

-- Dark search box with a neon edge while typing. onChange gets the lower-cased text.
function Controls.Search(parent: Instance, props: { [string]: any }, onChange: (string) -> ()): TextBox
	local frame = tile("Frame", { Name = "Search", Parent = parent })
	for key, value in props do
		frame[key] = value
	end
	local box = Kit.new("TextBox", {
		Name = "Box",
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.Color.Muted,
		TextColor3 = Theme.Color.Text,
		Font = Theme.Font.Heavy,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = frame,
	})
	box.Focused:Connect(function()
		frame.UIStroke.Color = Theme.Color.Neon
	end)
	box.FocusLost:Connect(function()
		frame.UIStroke.Color = Theme.Color.Line
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		onChange(string.lower(box.Text))
	end)
	return box
end

-- A section banner: dark metal with the text in caps and a sharp neon bar in `color` under it.
function Controls.Header(parent: Instance, text: string, color: Color3, props: { [string]: any }?): Frame
	local header = tile("Frame", { Name = "Header", Parent = parent })
	if props then
		for key, value in props do
			header[key] = value
		end
	end
	Kit.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = header,
	}, {
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 0.9) }),
		}),
	})
	Kit.new("Frame", {
		Name = "Tick",
		Position = UDim2.new(0, 8, 0.2, 0),
		Size = UDim2.new(0, 3, 0.5, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Parent = header,
	})
	Kit.label({
		Name = "Text",
		Text = string.upper(text),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 18, 0.12, 0),
		Size = UDim2.new(1, -26, 0.66, 0),
		Parent = header,
	}, 20)
	return header
end

-- Small square icon button (◀ ▶ ✕ ...): dark tile, the glyph in `color`.
function Controls.Icon(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ())
	local button = tile("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, 40, 1, 0),
		Parent = parent,
	}, color:Lerp(Theme.Color.Line, 0.5))
	if text == "✕" then
		Kit.glyph("Cross", color:Lerp(Color3.new(1, 1, 1), 0.3), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = button,
		})
	else
		Kit.label({
			Text = text,
			Font = Theme.Font.Heavy,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			Parent = button,
		}, 20)
	end
	Kit.pressable(button)
	button.Activated:Connect(onClick)
	return button
end

-- A toggle chip ("★5", "GOLD"): returns the button and its on / off setter; onToggle gets the new state.
function Controls.Chip(parent: Instance, text: string, color: Color3, order: number, onToggle: (boolean) -> ())
	local on = false
	local button = tile("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Font.Heavy,
		Text = text,
		TextSize = 14,
		TextColor3 = Theme.Color.Muted,
		Parent = parent,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = button })
	local function set(value: boolean)
		on = value
		button.UIStroke.Color = if on then color else Theme.Color.Line
		button.TextColor3 = if on then color:Lerp(Color3.new(1, 1, 1), 0.25) else Theme.Color.Muted
	end
	Kit.pressable(button)
	button.Activated:Connect(function()
		set(not on)
		onToggle(on)
	end)
	return button, set
end

return Controls
