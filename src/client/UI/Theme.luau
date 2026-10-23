--!strict
-- Colours and fonts for every screen: dark obsidian glass, sharp 5 px corners, thin slate edges, and
-- neon (cyan, gold, red) only where something is rare, active or wants a tap. Heavy Gotham type.

local Theme = {}

Theme.Font = {
	Display = Enum.Font.GothamBlack, -- big headings, rarity callouts
	Heavy = Enum.Font.GothamBold,
	Bold = Enum.Font.GothamMedium,
	Medium = Enum.Font.Gotham,
}

Theme.Color = {
	Backdrop = Color3.fromRGB(4, 6, 10),
	Panel = Color3.fromRGB(11, 14, 22), -- main panel glass
	PanelLight = Color3.fromRGB(18, 22, 34), -- cards, slots, items
	Line = Color3.fromRGB(45, 55, 80), -- every thin edge
	Text = Color3.fromRGB(236, 240, 250),
	Muted = Color3.fromRGB(138, 148, 172),
	Neon = Color3.fromRGB(60, 220, 255), -- the active / selected trim
	Accent = Color3.fromRGB(60, 200, 255),
	AccentDeep = Color3.fromRGB(14, 70, 110),
	Roll = Color3.fromRGB(255, 92, 70),
	RollDeep = Color3.fromRGB(150, 28, 40),
	Auto = Color3.fromRGB(64, 156, 255),
	AutoDeep = Color3.fromRGB(20, 50, 130),
	Quick = Color3.fromRGB(70, 224, 150),
	QuickDeep = Color3.fromRGB(10, 100, 76),
	Attack = Color3.fromRGB(255, 108, 76),
	Support = Color3.fromRGB(70, 210, 200),
	Gold = Color3.fromRGB(255, 196, 46),
	Danger = Color3.fromRGB(255, 70, 90),
	-- Tiles inside panels: a slate step above the panel glass, with a thin edge (recoloured neon when
	-- rare or active).
	TileTop = Color3.fromRGB(24, 29, 44),
	TileBottom = Color3.fromRGB(15, 18, 28),
	TileEdge = Color3.fromRGB(45, 55, 80),
}

-- Glass: how see-through panels and the frames inside them are.
Theme.Glass = {
	Panel = 0.15,
	Frame = 0.1,
}

Theme.Corner = UDim.new(0, 5)
Theme.Stroke = 1.2

-- Effects quality. Low keeps the same reveals with fewer sparks and rays.
Theme.FxLow = false

return Theme
