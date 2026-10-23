--!nonstrict
-- Shared menu controls in the game's chunky purple style: two-line option pills (Sort / Filter),
-- coloured tab pills, a search box and slanted section headers.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)

local Controls = {}

Controls.Purple = Color3.fromRGB(60, 200, 255)
Controls.PurpleDeep = Color3.fromRGB(14, 70, 110)
Controls.Outline = Color3.fromRGB(13, 17, 27)

local function outlined(label: TextLabel, thickness: number?)
	Kit.textStroke(Controls.Outline, thickness or 2, 0).Parent = label
	return label
end
Controls.Outlined = outlined

-- "Sort / Rarity": tap to cycle through `options`; onChange gets the new value.
function Controls.Option(parent: Instance, caption: string, options: { string }, order: number, onChange: (string) -> ())
	local index = 1
	local button = Kit.new("TextButton", {
		Name = caption,
		LayoutOrder = order,
		Size = UDim2.new(0, 112, 1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.gradient(ColorSequence.new(Controls.Purple, Controls.PurpleDeep), 90),
		Kit.stroke(Color3.fromRGB(190, 235, 255), 2, 0.2),
	})
	Skin.Apply(button, "ButtonPurple")
	outlined(Kit.label({
		Name = "Caption",
		Text = caption,
		Font = Theme.Font.Heavy,
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(0.9, 0.36),
		Parent = button,
	}, 14), 1.5)
	local value = outlined(Kit.label({
		Name = "Value",
		Text = options[1],
		Font = Theme.Font.Display,
		Position = UDim2.fromScale(0.05, 0.4),
		Size = UDim2.fromScale(0.9, 0.52),
		Parent = button,
	}, 22), 2)
	Kit.pressable(button)
	button.Activated:Connect(function()
		index = index % #options + 1
		value.Text = options[index]
		onChange(options[index])
	end)
	return button
end

-- A big coloured tab pill; returns the button and a setter for its on/off look.
function Controls.Tab(parent: Instance, text: string, color: Color3, order: number, width: number?)
	local button = Kit.new("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, width or 140, 1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	local gradient = Kit.gradient(ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.35)), 90)
	gradient.Parent = button
	local stroke = Kit.stroke(Color3.new(1, 1, 1), 2, 0.2)
	stroke.Parent = button
	local skin = Skin.Apply(button, Skin.ButtonFor(color))
	local label = outlined(Kit.label({
		Text = text,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.62),
		Parent = button,
	}, 24), 2)
	Kit.pressable(button)
	local function set(on: boolean)
		if skin then
			skin.ImageColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(27, 34, 53) -- greyed when off
		else
			gradient.Color = if on
				then ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.35))
				else ColorSequence.new(Color3.fromRGB(150, 146, 170), Color3.fromRGB(22, 29, 45))
			stroke.Transparency = if on then 0 else 0.6
		end
		label.TextTransparency = if on then 0 else 0.25
	end
	return button, set
end

-- Rounded dark search box. onChange gets the lower-cased text.
function Controls.Search(parent: Instance, props: { [string]: any }, onChange: (string) -> ()): TextBox
	local frame = Kit.new("Frame", {
		Name = "Search",
		BackgroundColor3 = Color3.fromRGB(6, 8, 13),
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Color3.fromRGB(90, 170, 220), 2, 0.3) })
	for key, value in props do
		frame[key] = value
	end
	local box = Kit.new("TextBox", {
		Name = "Box",
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -32, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Color3.fromRGB(150, 175, 200),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Display,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = frame,
	})
	box:GetPropertyChangedSignal("Text"):Connect(function()
		onChange(string.lower(box.Text))
	end)
	return box
end

-- Slanted coloured header strip for a column or section.
function Controls.Header(parent: Instance, text: string, color: Color3, props: { [string]: any }?): Frame
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.3, 0)),
		Kit.gradient(ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.3),
	})
	if props then
		for key, value in props do
			header[key] = value
		end
	end
	Skin.Apply(header, Skin.ButtonFor(color))
	outlined(Kit.label({
		Name = "Text",
		Text = text,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.7),
		Parent = header,
	}, 26), 2)
	return header
end

-- Small square icon button (◀ ▶ ✕ ...).
function Controls.Icon(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ())
	local button = Kit.new("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.new(0, 44, 1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = parent,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.4)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 2, 0.3),
	})
	-- The fonts have no ✕ glyph: a remove button uses the kit's round close art instead.
	local closeArt = text == "✕" and Skin.Apply(button, "Close")
	if closeArt then
		Kit.aspect(1, Enum.DominantAxis.Height).Parent = button
	else
		Skin.Apply(button, Skin.ButtonFor(color))
		outlined(Kit.label({
			Text = text,
			Font = Theme.Font.Heavy,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			Parent = button,
		}, 24), 1.5)
	end
	Kit.pressable(button)
	button.Activated:Connect(onClick)
	return button
end

return Controls
