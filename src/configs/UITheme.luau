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
		UrushiBlack = Color3.fromRGB(11, 11, 14), -- #0B0B0E base panel background
		UrushiRaised = Color3.fromRGB(19, 19, 24), -- tiles and slots, one step up from the panel
		Tamahagane = Color3.fromRGB(38, 44, 54), -- #262C36 bevelled steel frames
		TamahaganeLight = Color3.fromRGB(62, 72, 88), -- border highlights, notches
		WashiParchment = Color3.fromRGB(222, 206, 175), -- #DECEAF primary labels and text
		VermilionSeal = Color3.fromRGB(192, 41, 43), -- #C0292B call-to-action buttons, ink stamps
		VermilionDeep = Color3.fromRGB(92, 16, 20),
		TextMuted = Color3.fromRGB(120, 130, 145), -- secondary labels and stats
		SpiritCyan = Color3.fromRGB(24, 229, 213), -- #18E5D5 the Surge meter, empty end
		SurgeGold = Color3.fromRGB(255, 215, 0), -- #FFD700 the Surge meter, full end
		SpiritSheen = Color3.fromRGB(210, 240, 255), -- the flowing sheen on JuicyButton rims

		-- Element glow tints, by Elements.luau id (Flame, Frost, Storm, Light, Void, Cosmic).
		Elements = elementColors,

		-- Border tier glows, by Borders.luau id.
		Borders = {
			Normal = Color3.fromRGB(180, 160, 140), -- Base
			Gold = Color3.fromRGB(255, 215, 0),
			Rainbow = Color3.fromRGB(255, 105, 180),
			Secret = Color3.fromRGB(140, 20, 255),
		} :: { [string]: Color3 },
	},

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
