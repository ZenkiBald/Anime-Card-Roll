--!nonstrict
-- IconBadge: wraps an icon (an image asset id, or a glyph / emoji) in a small occult plate, so no icon floats
-- on bare space. Used for roles, elements and currencies (HUD, card tiles, tooltips, the DECK screen).
--   1. Base plate: a diamond (a square turned 45°) of Urushi black lacquer.
--   2. Bezel: a 2 px Tamahagane steel UIStroke on the plate, with a thin inner rim in the glow colour.
--   3. Corner accents: four 1 px steel-light notches, one at each point of the diamond.
--   4. Glow backlight: a round tint in the element / tier colour behind the icon (0.7 transparency).
--   5. The icon: centred and upright (it's a sibling of the plate, never rotated).
-- Every layer is a sibling inside an unrotated, square root, so nothing inherits the 45° turn. The plate's
-- side is 1/√2 of the root, so its points touch the root's edges and never clip outside it; the icon is
-- sized to the square that fits inside the diamond (half the root, a little more for glyphs).
--
-- IconBadge.new(props: { IconAsset: string, ArtKey: string?, ElementColor: Color3?, GlowColor: Color3?, Size: UDim2,
--   Parent: Instance?, Position: UDim2?, AnchorPoint: Vector2?, ZIndex: number?, Name: string?,
--   LayoutOrder: number?, DominantAxis: Enum.DominantAxis? }) -> Frame
-- The returned frame has children Plate, Glow and Icon (an ImageLabel for "rbxassetid://..." /
-- "rbxasset://..." / "http..." assets, else a TextLabel showing the glyph).

local Kit = require(script.Parent.Parent.Kit)
local Skin = require(script.Parent.Parent.Skin)
local Theme = require(script.Parent.Parent.Theme)
local UIArt = require(script.Parent.Parent.UIArt)
local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("UITheme"))

local IconBadge = {}

-- A soft radial texture for the backlight. Empty: the glow is a round tint with a brighter core (no
-- texture to load). Set it to an uploaded radial gradient id to use that instead.
IconBadge.GlowImage = ""

local PLATE = 1 / math.sqrt(2) -- diamond side, as a share of the root (its points reach the edges)

local function isAsset(icon: string): boolean
	return string.find(icon, "^rbxasset") ~= nil or string.find(icon, "^https?://") ~= nil
end

-- Swaps a badge's icon or glow colour after it was built (e.g. a tile reused for another card).
function IconBadge.Set(badge: Frame, icon: string?, glow: Color3?)
	local current = badge:FindFirstChild("Icon")
	if icon and current then
		if current:IsA("ImageLabel") and isAsset(icon) then
			current.Image = icon
		elseif current:IsA("TextLabel") and not isAsset(icon) then
			current.Text = icon
		end
	end
	if glow then
		local glowFrame = badge:FindFirstChild("Glow")
		if glowFrame and glowFrame:IsA("GuiObject") then
			glowFrame.BackgroundColor3 = glow
			if glowFrame:IsA("ImageLabel") then
				glowFrame.ImageColor3 = glow
			end
			local core = glowFrame:FindFirstChild("Core")
			if core and core:IsA("GuiObject") then
				core.BackgroundColor3 = glow
			end
		end
		local plate = badge:FindFirstChild("Plate")
		local rim = plate and plate:FindFirstChild("Rim")
		local rimStroke = rim and rim:FindFirstChildOfClass("UIStroke")
		if rimStroke then
			rimStroke.Color = glow
		end
	end
end

function IconBadge.new(props: { [string]: any }): Frame
	local glow: Color3 = props.ElementColor or props.GlowColor or UITheme.Colors.TamahaganeLight
	local z: number = props.ZIndex or 1
	local root = Kit.new("Frame", {
		Name = props.Name or "IconBadge",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundTransparency = 1,
		ZIndex = z,
	}, {
		Kit.aspect(1, props.DominantAxis or Enum.DominantAxis.Width),
	})

	-- 4. Glow backlight (behind the plate's lacquer edge, under the icon).
	local glowLabel = Kit.new("ImageLabel", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Image = IconBadge.GlowImage,
		ImageColor3 = glow,
		ImageTransparency = 0.9,
		BackgroundColor3 = glow,
		BackgroundTransparency = if IconBadge.GlowImage == "" then 0.9 else 1,
		ZIndex = z + 2,
		Parent = root,
	}, { Kit.corner(UDim.new(1, 0)) })
	if IconBadge.GlowImage == "" then
		-- A brighter core, so the round tint reads as a soft radial light.
		Kit.new("Frame", {
			Name = "Core",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.55, 0.55),
			BackgroundColor3 = glow,
			BackgroundTransparency = 0.6,
			ZIndex = z + 2,
			Parent = glowLabel,
		}, { Kit.corner(UDim.new(1, 0)) })
	end

	-- 1 + 2. Diamond plate with its steel bezel and a thin inner rim in the glow colour.
	local plate = Kit.new("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(PLATE, PLATE),
		Rotation = 45,
		BackgroundColor3 = UITheme.Colors.UrushiBlack,
		BackgroundTransparency = 0,
		ZIndex = z + 1,
		Parent = root,
	}, {
		Kit.corner(UDim.new(0, 2)),
	})
	local bezel = Instance.new("UIStroke")
	bezel.Name = "Bezel"
	bezel.Thickness = 1
	bezel.Color = UITheme.Colors.Tamahagane
	bezel.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bezel.Parent = plate
	local rim = Kit.new("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -5, 1, -5),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = plate,
	}, { Kit.corner(UDim.new(0, 1)) })
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Thickness = 1
	rimStroke.Color = glow
	rimStroke.Transparency = 0.45
	rimStroke.Parent = rim

	-- 3. Corner accents: a 1 px notch at each point of the diamond (top, right, bottom, left).
	for _, notch in
		{
			{ UDim2.fromScale(0.5, 0.02), UDim2.new(0.16, 0, 0, 1) },
			{ UDim2.fromScale(0.98, 0.5), UDim2.new(0, 1, 0.16, 0) },
			{ UDim2.fromScale(0.5, 0.98), UDim2.new(0.16, 0, 0, 1) },
			{ UDim2.fromScale(0.02, 0.5), UDim2.new(0, 1, 0.16, 0) },
		}
	do
		Kit.new("Frame", {
			Name = "Notch",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = notch[1],
			Size = notch[2],
			BorderSizePixel = 0,
			BackgroundColor3 = UITheme.Colors.TamahaganeLight,
			ZIndex = z + 3,
			Parent = root,
		})
	end

	-- 5. The icon, upright in the square that fits inside the diamond.
	local icon: string = Skin.Art(props.ArtKey) or props.IconAsset or "" -- uploaded art (Skin.Icons) beats the glyph
	if not UIArt.Enabled then icon = ({Shard="SH",Shards="SH",TraitShards="TS",Rolls="#"})[props.ArtKey] or string.upper(string.sub((props.ArtKey or "?"):match(":([^:]+)$") or props.ArtKey or "?", 1, 2)) end
	local artKey = if UIArt.HasIcon(props.ArtKey) then props.ArtKey else props.IconAsset
	if UIArt.HasIcon(artKey) then
		UIArt.Icon(root, artKey, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.68, 0.68), ZIndex = z + 4,
		})
	elseif isAsset(icon) then
		Kit.new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = z + 4,
			Parent = root,
		})
	else
		Kit.label({
			Name = "Icon",
			Text = icon,
			Font = Theme.Font.Heavy,
			TextColor3 = UITheme.Colors.WashiParchment,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.54, 0.54),
			ZIndex = z + 4,
			Parent = root,
		}, 40)
	end

	if props.Parent then
		root.Parent = props.Parent
	end
	return root
end

return IconBadge
