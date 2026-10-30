--!nonstrict
-- Inline reward art for quest rows and notifications. Payout text still comes from shared data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)
local Items = require(Shared.Items)
local Packs = require(Shared.Packs)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local HudArt = require(script.Parent.HudArt)
local BagArt = require(script.Parent.BagArt)

local RewardLine = {}
local replacements = {}
local function add(token, asset)
	if asset then table.insert(replacements, { Token = token, Image = asset }) end
end
-- Match full named items first; several relics share a potion's emoji.
for _, item in Items.Artifacts do add(`{item.Icon} {item.Name}`, BagArt.Get(`Artifact:{item.Id}`)) end
for _, item in Items.TowerArtifacts do add(`{item.Icon} {item.Name}`, BagArt.Get(`TowerArtifact:{item.Id}`)) end
add("💎", HudArt.Get("Shards"))
add("🧬", HudArt.Get("TraitShards"))
for _, potion in Meta.Potions do add(potion.Icon, BagArt.Get(`Potion:{potion.Id}`)) end
-- Speed has no dedicated art yet; the existing hourglass communicates its shorter cooldown.
add("⚡", BagArt.Get("Artifact:hourglass"))
for _, pack in Packs.List do add(pack.Icon, BagArt.Get(`Pack:{pack.Id}`)) end

function RewardLine.Set(frame, text: string)
	if frame:GetAttribute("RewardText") == text then return end
	frame:SetAttribute("RewardText", text)
	local old = frame:FindFirstChild("RewardContents")
	if old then old:Destroy() end
	local size = frame:GetAttribute("RewardSize") or 18
	local inner = Kit.new("Frame", {
		Name = "RewardContents", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, size + 6), ZIndex = frame.ZIndex, Parent = frame,
	})
	local layout = Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2), Parent = inner })
	local scale = Kit.new("UIScale", { Parent = inner })
	local order = 0
	local function word(value)
		if value == "" then return end
		order += 1
		Kit.label({ Text = value, TextScaled = false, TextWrapped = false, TextSize = size, Font = Theme.Font.Heavy,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 6),
			LayoutOrder = order, ZIndex = frame.ZIndex, Parent = inner }, size)
	end
	local cursor = 1
	while cursor <= #text do
		local first, last, found
		for _, replacement in replacements do
			local a, b = string.find(text, replacement.Token, cursor, true)
			if a and (not first or a < first) then first, last, found = a, b, replacement end
		end
		if not first then word(string.sub(text, cursor)); break end
		word(string.sub(text, cursor, first - 1))
		order += 1
		Kit.new("ImageLabel", { Name = "RewardArt", Image = found.Image, ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1, Size = UDim2.fromOffset(size + 6, size + 6),
			LayoutOrder = order, ZIndex = frame.ZIndex, Parent = inner })
		-- Keep named relics readable beside their illustration.
		local name = string.match(found.Token, "^%S+ (.+)$")
		if name then word(" " .. name) end
		cursor = last + 1
	end
	local function fit()
		local available = Kit.logicalSize(frame)
		scale.Scale = math.min(1, available.X / math.max(1, Kit.logicalSize(inner).X), available.Y / (size + 6))
	end
	local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	inner.Destroying:Once(function() connection:Disconnect() end)
	fit()
end

function RewardLine.new(props, text: string, size: number?)
	local frame = Kit.new("Frame", props)
	frame.BackgroundTransparency = 1
	frame:SetAttribute("RewardSize", size or 18)
	RewardLine.Set(frame, text)
	return frame
end

return RewardLine
