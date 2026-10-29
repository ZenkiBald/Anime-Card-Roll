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
	Attack = Color3.fromRGB(255, 78, 91),
	AttackDeep = Color3.fromRGB(133, 24, 43),
	Support = Color3.fromRGB(69, 224, 128),
	SupportDeep = Color3.fromRGB(14, 99, 61),
	Health = Color3.fromRGB(83, 240, 138),
	Luck = Color3.fromRGB(83, 240, 138),
	Info = Color3.fromRGB(78, 175, 255),
	InfoDeep = Color3.fromRGB(25, 70, 135),
	Gold = Color3.fromRGB(220, 183, 107),
	Danger = Color3.fromRGB(255, 70, 90),
	-- Tiles inside panels: a slate step above the panel glass, with a thin edge (recoloured neon when
	-- rare or active).
	TileTop = Color3.fromRGB(38, 56, 75),
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

-- A stable meaning across window titles, tabs and buttons; neutral surfaces stay quiet.
function Theme.Section(text: string): Color3
	local key=string.upper(text)
	if key:find("ATTACK") or key:find("BATTLE") then return Theme.Color.Attack end
	if key:find("SUPPORT") or key:find("LUCK") or key:find("QUEST") or key:find("GOAL") then return Theme.Color.Support end
	if key:find("TRAIN") or key:find("UPGRADES") or key:find("SHOP") or key:find("STORE") then return Theme.Color.Gold end
	if key:find("BAG") or key:find("BACKPACK") or key:find("INDEX") then return Color3.fromRGB(173,123,255) end
	return Theme.Color.Info
end

-- Effects quality. Low keeps the same reveals with fewer sparks and rays.
Theme.FxLow = false

return Theme
