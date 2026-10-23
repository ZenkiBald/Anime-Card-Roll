--!nonstrict
-- Element and role badges (IconBadge) and element labels (Elements.luau) for cards, tiles, enemies,
-- tooltips and the scouting lines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Elements = require(Shared.Elements)

local Theme = require(script.Parent.Theme)
local IconBadge = require(script.Parent.Components.IconBadge)
local UITheme = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("UITheme"))

local ElementUi = {}

function ElementUi.Color(id: string?): Color3
	local element = Elements.Get(id)
	return if element then element.Color else Theme.Color.Muted
end

-- The element's occult badge (Components/IconBadge: diamond Urushi plate, steel bezel, a glow in the
-- element's colour, the icon upright). Place it with `props` (Position, Size, AnchorPoint, ZIndex,
-- Parent, Name); it keeps itself square off its width.
function ElementUi.Badge(id: string?, props: { [string]: any }): Frame?
	local element = Elements.Get(id)
	if element == nil then
		return nil
	end
	return IconBadge.new({
		Name = props.Name or "Element",
		IconAsset = element.Icon,
		ElementColor = element.Color,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 6,
		LayoutOrder = props.LayoutOrder,
		DominantAxis = props.DominantAxis,
		Parent = props.Parent,
	})
end

-- A role's badge (Cards.luau `Role`: Striker / Hexer / Mender / Warder), same plate as the element's.
function ElementUi.RoleBadge(role: string?, props: { [string]: any }): Frame?
	local info = role and UITheme.Roles[role]
	if info == nil then
		return nil
	end
	return IconBadge.new({
		Name = props.Name or "Role",
		IconAsset = info.Icon,
		GlowColor = info.Color,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 6,
		LayoutOrder = props.LayoutOrder,
		DominantAxis = props.DominantAxis,
		Parent = props.Parent,
	})
end

-- Rich text: "<font color=...>🔥 Flame</font>".
function ElementUi.Rich(id: string?): string
	local element = Elements.Get(id)
	if element == nil then
		return ""
	end
	return `<font color="#{element.Color:ToHex()}">{element.Icon} {element.Name}</font>`
end

-- Rich text for a list of element ids: "🔥 Flame / ❄️ Frost".
function ElementUi.RichList(ids: { string }): string
	local parts = {}
	for _, id in ids do
		table.insert(parts, ElementUi.Rich(id))
	end
	return table.concat(parts, " / ")
end

return ElementUi
