--!nonstrict
-- Image skins for the UI (art/UI_KIT_PROMPTS.md lists what to make).
-- Paste each uploaded asset id ("rbxassetid://123...") next to its key. Anything left empty keeps the
-- built-in look, so the game reskins piece by piece as images arrive.
--
-- Panels, banners, buttons and card frames are 9-sliced: Size is the image's pixel size, Margin how
-- many pixels at each edge stay unstretched (or MarginX / MarginY separately), Scale how big those
-- edges draw on screen (0.25 = a quarter). Fit = true scales the edges to the element's height
-- instead (buttons: their art is almost all edge vertically, so a fixed Scale spills out of short ones).

local Skin = {}

-- Sizes and margins match the kit drawn in the "Anime Card Roll - UI Kit" Figma file (exported at 2x).
Skin.Images = {
	Panel = { Id = "rbxassetid://99549726104701", Size = Vector2.new(1024, 1024), Margin = 220, Scale = 0.22 },
	Banner = { Id = "rbxassetid://88017292818555", Size = Vector2.new(1024, 256), MarginX = 130, MarginY = 100, Scale = 0.3 },
	Close = { Id = "rbxassetid://133025751933251" }, -- stretched to fit
	ButtonPurple = { Id = "rbxassetid://91155976916866", Size = Vector2.new(1024, 384), Margin = 176, Fit = true },
	ButtonRed = { Id = "rbxassetid://83414148044207", Size = Vector2.new(1024, 384), Margin = 176, Fit = true },
	ButtonGreen = { Id = "rbxassetid://117800565483201", Size = Vector2.new(1024, 384), Margin = 176, Fit = true },
	ButtonBlue = { Id = "rbxassetid://91757618249539", Size = Vector2.new(1024, 384), Margin = 176, Fit = true },
	ButtonGold = { Id = "rbxassetid://109648775223698", Size = Vector2.new(1024, 384), Margin = 176, Fit = true },
	RollButton = { Id = "rbxassetid://134557607861668", Size = Vector2.new(1024, 512), Margin = 180, Fit = true },
	AutoButton = { Id = "rbxassetid://91673460322131", Size = Vector2.new(1024, 512), Margin = 180, Fit = true },
	QuickButton = { Id = "rbxassetid://89611639513414", Size = Vector2.new(1024, 512), Margin = 180, Fit = true },
	MenuButton = { Id = "rbxassetid://113764172105747", Size = Vector2.new(512, 512), Margin = 120, Scale = 0.3 },
}

-- Card frames by rarity, drawn over the card art (9-sliced so they fit tiles and tall cards).
Skin.Frames = {
	Common = "rbxassetid://110538208908575",
	Uncommon = "rbxassetid://139892795772037",
	Rare = "rbxassetid://83013583282176",
	Epic = "rbxassetid://123691093410661",
	Legendary = "rbxassetid://101806230893459",
	Mythic = "rbxassetid://102169641123682",
	Secret = "rbxassetid://85990645797859",
}
Skin.FrameSlice = { Size = Vector2.new(1024, 1024), Margin = 200, Scale = 0.12 }

-- Icons: menu buttons by their caption, plus currencies.
Skin.Icons = {
	BATTLE = "rbxassetid://71123240303125",
	DECK = "rbxassetid://136503784714496",
	INDEX = "rbxassetid://123000232647835",
	POTIONS = "rbxassetid://89341890216235",
	SHOP = "rbxassetid://98020168089759",
	GIFTS = "rbxassetid://126862775859746",
	FX = "rbxassetid://101163202245560",
	DEV = "rbxassetid://77762881503907",
	Shard = "rbxassetid://105504428224041",
	Luck = "rbxassetid://116998892373970",
}

local BUTTON_COLORS = {
	ButtonPurple = Color3.fromRGB(130, 90, 255),
	ButtonRed = Color3.fromRGB(255, 100, 80),
	ButtonGreen = Color3.fromRGB(86, 214, 138),
	ButtonBlue = Color3.fromRGB(64, 156, 255),
	ButtonGold = Color3.fromRGB(255, 196, 46),
}

local function image(id: string, slice): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Skin"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = id
	if slice and slice.Size then
		local mx = slice.MarginX or slice.Margin
		local my = slice.MarginY or slice.Margin
		label.ScaleType = Enum.ScaleType.Slice
		label.SliceCenter = Rect.new(mx, my, slice.Size.X - mx, slice.Size.Y - my)
		label.SliceScale = slice.Scale or 1
		if slice.Fit then
			local function fit()
				local height = label.AbsoluteSize.Y
				local width = label.AbsoluteSize.X
				if height > 0 and width > 0 then
					-- Full art height = element height; narrow elements shrink so the side edges still fit.
					label.SliceScale = math.min(height / slice.Size.Y, width / (2 * mx + 8))
				end
			end
			label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			fit()
		end
	else
		label.ScaleType = Enum.ScaleType.Stretch
	end
	return label
end

function Skin.Has(name: string): boolean
	local def = Skin.Images[name]
	return def ~= nil and def.Id ~= ""
end

-- Puts the named image behind `target`'s content and hides its built-in fill, gradient, outline and
-- gloss. Returns the image, or nil when that skin has no id yet (the built-in look stays).
function Skin.Apply(target: GuiObject, name: string): ImageLabel?
	local def = Skin.Images[name]
	if def == nil or def.Id == "" then
		return nil
	end
	target.BackgroundTransparency = 1
	for _, child in target:GetChildren() do
		if child:IsA("UIGradient") or child:IsA("UIStroke") then
			child.Enabled = false
		elseif child.Name == "Gloss" and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	local label = image(def.Id, def)
	label.ZIndex = 0 -- behind the button's own text and icons
	label.Parent = target
	return label
end

-- Greys out a skinned button (can't afford, locked, maxed). Unskinned ones fade their fill instead.
function Skin.SetDimmed(target: GuiObject, dimmed: boolean)
	local label = target:FindFirstChild("Skin")
	if label and label:IsA("ImageLabel") then
		label.ImageColor3 = if dimmed then Color3.fromRGB(125, 120, 145) else Color3.new(1, 1, 1)
		label.ImageTransparency = if dimmed then 0.15 else 0
	else
		target.BackgroundTransparency = if dimmed then 0.6 else 0
	end
end

-- The button skin closest to a colour (the game's buttons are purple, red, green, blue or gold).
function Skin.ButtonFor(color: Color3): string
	local best, bestDistance = "ButtonPurple", math.huge
	for name, swatch in BUTTON_COLORS do
		local distance = (color.R - swatch.R) ^ 2 + (color.G - swatch.G) ^ 2 + (color.B - swatch.B) ^ 2
		if distance < bestDistance then
			best, bestDistance = name, distance
		end
	end
	return best
end

-- Draws the rarity's card frame over a card or tile; returns nil when there's no frame image yet.
function Skin.Frame(target: GuiObject, rarity: string, zIndex: number): ImageLabel?
	local id = Skin.Frames[rarity]
	if id == nil or id == "" then
		return nil
	end
	for _, child in target:GetChildren() do
		if child:IsA("UIStroke") then
			child.Enabled = false
		end
	end
	local label = image(id, Skin.FrameSlice)
	label.Name = "Frame"
	label.ZIndex = zIndex
	label.Parent = target
	return label
end

-- Loads every skin image once and returns the keys that failed (a wrong id, or an image still
-- waiting for Roblox moderation). Used in test mode so a broken id shows up in the Output.
-- Checks real ImageLabels: PreloadAsync on bare id strings reports Failure even for good images.
-- Only drawn labels load, so they sit on screen at 0.99 transparency (a disabled gui, offscreen or
-- fully transparent label never reports IsLoaded).
function Skin.Verify(playerGui: Instance): { string }
	local holder = Instance.new("ScreenGui")
	holder.Name = "SkinCheck"
	holder.DisplayOrder = -100
	holder.Parent = playerGui
	local labels = {}
	local function add(key: string, id: string)
		if id ~= "" then
			local label = Instance.new("ImageLabel")
			label.Size = UDim2.fromOffset(2, 2)
			label.BackgroundTransparency = 1
			label.ImageTransparency = 0.99
			label.Image = id
			label.Parent = holder
			labels[`{key} ({id})`] = label
		end
	end
	for key, def in Skin.Images do
		add(key, def.Id)
	end
	for key, id in Skin.Frames do
		add(`{key} frame`, id)
	end
	for key, id in Skin.Icons do
		add(`{key} icon`, id)
	end
	local deadline = os.clock() + 15
	local failed
	repeat
		task.wait(0.5)
		failed = {}
		for key, label in labels do
			if not label.IsLoaded then
				table.insert(failed, key)
			end
		end
	until #failed == 0 or os.clock() > deadline
	holder:Destroy()
	return failed
end

-- Replaces an emoji icon label with the uploaded icon image, if there is one.
function Skin.Icon(label: TextLabel, key: string): ImageLabel?
	local id = Skin.Icons[key]
	if id == nil or id == "" then
		return nil
	end
	local icon = Instance.new("ImageLabel")
	icon.Name = label.Name
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = label.AnchorPoint
	icon.Position = label.Position
	icon.Size = label.Size
	icon.ZIndex = label.ZIndex
	icon.Image = id
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = label.Parent
	label:Destroy()
	return icon
end

return Skin
