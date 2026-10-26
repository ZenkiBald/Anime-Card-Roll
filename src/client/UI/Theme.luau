--!strict
-- Colours and fonts for every screen, in the Dark Feudal Occult look (Configs/UITheme holds the tokens):
-- Urushi black lacquer panels, Tamahagane steel edges, Washi parchment text, sharp 5 px corners, and
-- colour (spirit blue, gold leaf, vermilion, element glows) only where something is rare, active or wants a
-- tap. Clear Gotham headings and body type; the illustrated kit supplies the ornament.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))
local C = UITheme.Colors

local Theme = {}

Theme.Font = {
	Display = UITheme.Fonts.Header, -- big headings, tier callouts
	Heavy = Enum.Font.GothamBold,
	Bold = Enum.Font.GothamMedium,
	Medium = Enum.Font.Gotham,
}

Theme.Color = {
	Backdrop = Color3.fromRGB(5, 5, 7),
	Panel = C.UrushiBlack, -- main panel lacquer
	PanelLight = C.UrushiRaised, -- cards, slots, items
	Line = C.Tamahagane, -- every thin steel edge
	Text = C.WashiParchment,
	Muted = C.TextMuted,
	Neon = Color3.fromRGB(232, 196, 120), -- the active / selected trim: warm gold leaf, not electric cyan
	Accent = C.SpiritCyan, -- Shards and info highlights: soft spirit blue
	AccentDeep = Color3.fromRGB(16, 60, 90),
	Roll = Color3.fromRGB(255, 92, 70),
	RollDeep = Color3.fromRGB(150, 28, 40),
	Auto = Color3.fromRGB(210, 180, 122),
	AutoDeep = Color3.fromRGB(20, 50, 130),
	Quick = Color3.fromRGB(210, 180, 122),
	QuickDeep = Color3.fromRGB(10, 100, 76),
	Attack = Color3.fromRGB(255, 108, 76),
	Support = Color3.fromRGB(70, 210, 200),
	Gold = Color3.fromRGB(220, 183, 107),
	Danger = Color3.fromRGB(255, 70, 90),
	-- Tiles inside panels: a slate step above the panel glass, with a thin edge (recoloured neon when
	-- rare or active).
	TileTop = Color3.fromRGB(24, 24, 30),
	TileBottom = C.UrushiBlack,
	TileEdge = C.Tamahagane,
}

-- Glass: how see-through panels and the frames inside them are.
Theme.Glass = {
	Panel = 0.05,
	Frame = 0.1,
}

Theme.Corner = UDim.new(0, 5)
Theme.Stroke = 1.2

-- Effects quality. Low keeps the same reveals with fewer sparks and rays.
Theme.FxLow = false

return Theme
