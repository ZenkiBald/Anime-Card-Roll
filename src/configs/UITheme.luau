--!strict
-- Design tokens for the Dark Feudal Occult look: Urushi black lacquer panels, Tamahagane steel frames,
-- Washi parchment text, Vermilion seals for calls to action, and colour only where spirit glows (element
-- auras, border tiers, the Surge meter). UI/Theme reads its panel, edge, text and header tokens from here,
-- so every screen follows it.
-- Element glows come from Elements.luau (one source, keyed by the game's element ids); border glows are
-- keyed by Borders.luau ids ("Normal" is the Base border).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Elements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Elements"))

local elementColors: { [string]: Color3 } = {}
for _, element in Elements.List do
	elementColors[element.Id] = element.Color
end

local UITheme = {
	Colors = {
		-- Surfaces: Urushi lacquer, three depths.
		UrushiBase = Color3.fromRGB(11, 11, 14), -- #0B0B0E base panel background
		UrushiRaised = Color3.fromRGB(20, 20, 26), -- #14141A tiles and slots, one step up
		UrushiInset = Color3.fromRGB(7, 7, 9), -- #070709 sunken tracks and recessed buttons
		-- Text: Washi parchment.
		WashiParchment = Color3.fromRGB(236, 229, 216), -- #ECE5D8 primary labels and text
		WashiGhost = Color3.fromRGB(140, 133, 123), -- #8C857B secondary labels, stats, counts
		-- Frames: Tamahagane folded steel.
		TamahaganeSlate = Color3.fromRGB(44, 48, 56), -- #2C3038 bezels and thin edges
		TamahaganeEdge = Color3.fromRGB(86, 92, 104), -- #565C68 highlights, notches
		TamahaganeRust = Color3.fromRGB(26, 28, 34), -- #1A1C22 the dark side of a bevel
		-- Calls to action: Vermilion wax seal.
		VermilionWax = Color3.fromRGB(201, 59, 43), -- #C93B2B
		VermilionHover = Color3.fromRGB(230, 75, 58), -- #E64B3A its rim and hover
		VermilionDeep = Color3.fromRGB(92, 16, 20),
		-- The Surge talisman's three states (Hud): charging, imminent, sealed.
		SpiritCyan = Color3.fromRGB(79, 195, 247), -- #4FC3F7 charging (rolls 0-19 of the cycle)
		VoidSurge = Color3.fromRGB(126, 87, 194), -- #7E57C2 imminent (20-23)
		SurgeGold = Color3.fromRGB(255, 215, 0), -- #FFD700 sealed: the next roll is the surge
		SpiritSheen = Color3.fromRGB(236, 229, 216), -- the flowing sheen on JuicyButton rims (parchment, not cyan)
		-- Older names, the same values, so every screen built on them follows the new tokens.
		UrushiBlack = Color3.fromRGB(11, 11, 14), -- = UrushiBase
		Tamahagane = Color3.fromRGB(44, 48, 56), -- = TamahaganeSlate
		TamahaganeLight = Color3.fromRGB(86, 92, 104), -- = TamahaganeEdge
		VermilionSeal = Color3.fromRGB(201, 59, 43), -- = VermilionWax
		TextMuted = Color3.fromRGB(140, 133, 123), -- = WashiGhost

		-- Element glow tints, by Elements.luau id (Flame, Frost, Storm, Light, Void, Cosmic).
		Elements = elementColors,

		-- Border tier glows, by Borders.luau id.
		Borders = {
			Normal = Color3.fromRGB(122, 106, 88), -- Base: tainted bronze #7A6A58
			Gold = Color3.fromRGB(255, 215, 0), -- gold leaf #FFD700
			Rainbow = Color3.fromRGB(255, 105, 180),
			Secret = Color3.fromRGB(170, 0, 255), -- cosmic void purple #AA00FF
		} :: { [string]: Color3 },
	},

	-- How each border tier frames a card tile (the border IS the tier): stroke colour and thickness.
	-- Rainbow uses Borders.luau's prismatic gradient; Secret pairs the void purple with a singularity core.
	BorderTiers = {
		Normal = { Color = Color3.fromRGB(122, 106, 88), Thickness = 1 },
		Gold = { Color = Color3.fromRGB(255, 215, 0), Thickness = 2, Glow = true },
		Rainbow = { Color = Color3.fromRGB(255, 105, 180), Thickness = 2.5, Glow = true, Prismatic = true },
		Secret = { Color = Color3.fromRGB(170, 0, 255), Core = Color3.fromRGB(11, 0, 20), Thickness = 3, Glow = true },
	} :: { [string]: { Color: Color3, Thickness: number, Glow: boolean?, Prismatic: boolean?, Core: Color3? } },

	-- Battle roles (Cards.luau `Role`): badge glyph and glow.
	Roles = {
		Striker = { Icon = "⚔️", Color = Color3.fromRGB(255, 75, 45) },
		Hexer = { Icon = "🔮", Color = Color3.fromRGB(160, 45, 255) },
		Mender = { Icon = "✚", Color = Color3.fromRGB(90, 230, 150) },
		Warder = { Icon = "🛡️", Color = Color3.fromRGB(45, 200, 255) },
	} :: { [string]: { Icon: string, Color: Color3 } },

	Fonts = {
		Header = Enum.Font.FredokaOne, -- chunky shonen headers
		Body = Enum.Font.GothamMedium,
		Stats = Enum.Font.GothamBold,
	},
}

return UITheme
