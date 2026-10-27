--!strict
-- Shared glossy vector palette and chunky display fonts. Legacy token names remain compatible.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))
local C = UITheme.Colors

local Theme = {}

Theme.Font = {
	Display = UITheme.Fonts.Header, -- big headings, tier callouts
	Heavy = Enum.Font.FredokaOne,
	Bold = Enum.Font.FredokaOne,
	Medium = Enum.Font.Gotham,
}

Theme.Color = {
	Backdrop = Color3.fromRGB(5, 5, 7),
	Panel = C.UrushiBlack, -- main panel lacquer
	PanelLight = C.UrushiRaised, -- cards, slots, items
	Line = C.Tamahagane, -- every thin steel edge
	Text = C.WashiParchment,
	Muted = C.TextMuted,
	Neon = Color3.fromRGB(120, 255, 208),
	Accent = C.SpiritCyan, -- Shards and info highlights: soft spirit blue
	AccentDeep = Color3.fromRGB(16, 60, 90),
	Roll = Color3.fromRGB(255, 92, 70),
	RollDeep = Color3.fromRGB(150, 28, 40),
	Auto = Color3.fromRGB(83, 210, 255),
	AutoDeep = Color3.fromRGB(20, 50, 130),
	Quick = Color3.fromRGB(68, 244, 143),
	QuickDeep = Color3.fromRGB(10, 100, 76),
	Attack = Color3.fromRGB(255, 108, 76),
	Support = Color3.fromRGB(70, 210, 200),
	Gold = Color3.fromRGB(220, 183, 107),
	Danger = Color3.fromRGB(255, 70, 90),
	-- Tiles inside panels: a slate step above the panel glass, with a thin edge (recoloured neon when
	-- rare or active).
	TileTop = Color3.fromRGB(85, 88, 148),
	TileBottom = C.UrushiBlack,
	TileEdge = C.Tamahagane,
}

-- Glass: how see-through panels and the frames inside them are.
Theme.Glass = {
	Panel = 0,
	Frame = 0,
}

Theme.Corner = UDim.new(0, 10)
Theme.Stroke = 2.5

-- Effects quality. Low keeps the same reveals with fewer sparks and rays.
Theme.FxLow = false

return Theme
