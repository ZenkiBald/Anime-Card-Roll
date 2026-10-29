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
local Kit = require(script.Parent.Kit)

function ElementUi.Color(id: string?): Color3
	local element = Elements.Get(id)
	return if element then element.Color else Theme.Color.Muted
end

-- Transparent illustrated element art, kept square without a text tag or surrounding diamond.
function ElementUi.Badge(id: string?, props: { [string]: any }): Frame?
	if not Elements.CombatEnabled then return nil end
	local element = Elements.Get(id)
	if element == nil then
		return nil
	end
	local visual = Elements.Visuals[element.Id]
	local root = Kit.new("Frame", {
		Name = props.Name or "Element",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 6,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { Kit.aspect(1, props.DominantAxis or Enum.DominantAxis.Width) })
	Kit.new("ImageLabel", { Name="Icon", Image=visual.Image, BackgroundTransparency=1,
		Size=UDim2.fromScale(1,1), ScaleType=Enum.ScaleType.Fit, ZIndex=props.ZIndex or 6, Parent=root })
	return root
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
		ArtKey = `Role:{role}`,
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
	if not Elements.CombatEnabled then return "" end
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
