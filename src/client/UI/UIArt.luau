--!nonstrict
-- Illustrated Urushi kit. Source PNGs and atlas coordinates live in art/ui/occult/.
-- Four shared textures, live text, and 9-sliced panels keep the kit inexpensive to draw.
local UIArt = {}
UIArt.Enabled = false -- clean panels let the character illustrations carry the visual detail

UIArt.Icons = "rbxassetid://97204181847223"
UIArt.Panel = "rbxassetid://96750861620965"
UIArt.Roll = "rbxassetid://89350893336373"
UIArt.Items = "rbxassetid://72589476591756"

local ICONS = {
	BATTLE = 0, SQUAD = 1, DECK = 1, INDEX = 1, BAG = 2, QUESTS = 3, GIFTS = 3,
	TRAVEL = 4, STORE = 5, AUTO = 6, QUICK = 7, DASH = 8, MOUNT = 9,
	Shard = 10, Shards = 10, TraitShards = 11, Rolls = 12, SETTINGS = 13, DEV = 13,
	["Element:Flame"] = 14, ["Role:Mender"] = 15,
	["Role:Striker"] = 0, ["Store:VIP"] = 5, ["Store:FastRoll"] = 7,
	["Store:AutoRoll"] = 6, ["Store:TripleRoll"] = 1,
	["Artifact:stormcrown"] = 5, ["Artifact:prism"] = 10, ["Artifact:emberheart"] = 14,
	["💎"] = 10, ["🧬"] = 11, ["🎲"] = 12, ["⚔️"] = 0,
	["🔥"] = 14, ["✚"] = 15,
}

local ITEMS = {
	["Artifact:clover"] = 0, ["Artifact:hourglass"] = 1, ["Artifact:coin"] = 2, ["Artifact:tome"] = 3,
	["Artifact:prism"] = 4, ["Artifact:moonstone"] = 5, ["Artifact:emberheart"] = 6, ["Artifact:frostsigil"] = 7,
	["Artifact:voideye"] = 8, ["Artifact:stormcrown"] = 9, ["TowerArtifact:hundredcrown"] = 10,
	["Pack:10"] = 11, ["Pack:100"] = 11, ["Pack:1000"] = 11,
	["Potion:luck"] = 12, ["Potion:speed"] = 13, ["Potion:superluck"] = 14, ["Potion:mythic"] = 15,
}

local function sprite(key: string?): (number?, boolean)
	if key == nil then
		return nil, false
	end
	local item = ITEMS[key] or ITEMS[string.match(key, "^(Pack:%d+):") or ""]
	if item ~= nil then
		return item, true
	end
	return ICONS[key], false
end

function UIArt.HasIcon(key: string?): boolean
	if not UIArt.Enabled then return false end
	local index = sprite(key)
	return index ~= nil
end

function UIArt.Icon(parent: Instance?, key: string, props: { [string]: any }?): ImageLabel?
	if not UIArt.Enabled then return nil end
	local index, item = sprite(key)
	if index == nil then
		return nil
	end
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Image = if item then UIArt.Items else UIArt.Icons
	-- Roblox serves the 1254 px masters at 1024 px: atlas coordinates use the served texture.
	local x, y = index % 4, index // 4
	icon.ImageRectOffset = Vector2.new(x * 256, y * 256)
	icon.ImageRectSize = Vector2.new(256, 256)
	if item and index == 11 then
		-- The pack's tassel is close to the next row's potion stoppers; crop its own safe area.
		icon.ImageRectOffset = Vector2.new(784, 520)
		icon.ImageRectSize = Vector2.new(224, 216)
	end
	icon.ScaleType = Enum.ScaleType.Fit
	if props then
		for name, value in props do
			if name ~= "Parent" then
				icon[name] = value
			end
		end
	end
	icon.Parent = parent
	return icon
end

function UIArt.Replace(label: TextLabel, key: string): ImageLabel?
	local icon = UIArt.Icon(label.Parent, key, {
		Name = label.Name, AnchorPoint = label.AnchorPoint, Position = label.Position,
		Size = label.Size, ZIndex = label.ZIndex,
	})
	if icon then
		label:Destroy()
	end
	return icon
end

function UIArt.Plate(target: GuiObject, primary: boolean?): ImageLabel?
	if not UIArt.Enabled then return nil end
	local old = target:FindFirstChild("Skin")
	if old and old:IsA("ImageLabel") then
		return old
	end
	target.BackgroundTransparency = 1
	for _, child in target:GetChildren() do
		if child:IsA("UIGradient") then
			child.Enabled = false
		elseif child:IsA("UIStroke") then
			child.Transparency = 1 -- keep it available for the existing state / hover code
		elseif child:IsA("GuiObject") and (child.Name == "Gloss" or child.Name == "Trim" or child.Name == "Rim" or child.Name == "Glow") then
			child.Visible = false
		end
	end
	local art = Instance.new("ImageLabel")
	art.Name = "Skin"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = if primary then UIArt.Roll else UIArt.Panel
	art.ScaleType = Enum.ScaleType.Slice
	art.ZIndex = 0
	if primary then
		-- Crop the transparent top / bottom padding without altering the source PNG.
		art.ImageRectOffset = Vector2.new(0, 66)
		art.ImageRectSize = Vector2.new(1024, 364)
		art.SliceCenter = Rect.new(220, 69, 804, 295)
		art.ScaleType = Enum.ScaleType.Stretch -- the blossom branches keep their proportions at summon-button size
	else
		art.SliceCenter = Rect.new(204, 204, 820, 820)
	end
	local function fit()
		local size = art.AbsoluteSize
		art.SliceScale = if primary then math.min(size.Y / 364, size.X / 448)
			else math.min(0.22, size.Y / 416, size.X / 416)
	end
	art:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local function loaded()
		target.BackgroundColor3 = if primary then Color3.fromRGB(153, 43, 33) else Color3.fromRGB(11, 13, 15)
		target.BackgroundTransparency = if art.IsLoaded then 1 else 0
	end
	art:GetPropertyChangedSignal("IsLoaded"):Connect(loaded)
	art.Parent = target
	fit()
	loaded()
	return art
end

return UIArt
