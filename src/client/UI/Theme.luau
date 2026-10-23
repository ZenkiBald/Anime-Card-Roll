--!strict
-- Colours and fonts for every screen.

local Theme = {}

Theme.Font = {
	Display = Enum.Font.FredokaOne, -- big headings, rarity callouts
	Heavy = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Medium = Enum.Font.BuilderSansMedium,
}

Theme.Color = {
	Backdrop = Color3.fromRGB(8, 6, 16),
	Panel = Color3.fromRGB(24, 21, 40),
	PanelLight = Color3.fromRGB(38, 34, 62),
	Line = Color3.fromRGB(70, 62, 110),
	Text = Color3.fromRGB(246, 244, 255),
	Muted = Color3.fromRGB(168, 162, 200),
	Accent = Color3.fromRGB(176, 92, 255),
	AccentDeep = Color3.fromRGB(96, 40, 190),
	Roll = Color3.fromRGB(255, 120, 70),
	RollDeep = Color3.fromRGB(220, 50, 90),
	Auto = Color3.fromRGB(64, 156, 255),
	AutoDeep = Color3.fromRGB(40, 70, 200),
	Quick = Color3.fromRGB(86, 214, 138),
	QuickDeep = Color3.fromRGB(20, 140, 110),
	Attack = Color3.fromRGB(255, 108, 76),
	Support = Color3.fromRGB(70, 210, 200),
	Gold = Color3.fromRGB(255, 196, 46),
	Danger = Color3.fromRGB(255, 80, 100),
	-- Chunky tiles inside kit panels: a lighter purple than the panel, with a bright edge.
	TileTop = Color3.fromRGB(104, 66, 196),
	TileBottom = Color3.fromRGB(54, 30, 116),
	TileEdge = Color3.fromRGB(186, 150, 255),
}

-- Effects quality. Low keeps the same reveals with fewer sparks and rays.
Theme.FxLow = false

return Theme
