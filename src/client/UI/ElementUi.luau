--!nonstrict
-- Element badges and labels (Elements.luau) for cards, tiles, enemies and the scouting lines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Elements = require(Shared.Elements)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local ElementUi = {}

function ElementUi.Color(id: string?): Color3
	local element = Elements.Get(id)
	return if element then element.Color else Theme.Color.Muted
end

-- A round badge with the element's icon on a dark disc ringed in its colour. Size it with `props`
-- (it keeps itself square off its width).
function ElementUi.Badge(id: string?, props: { [string]: any }): Frame?
	local element = Elements.Get(id)
	if element == nil then
		return nil
	end
	local defaults = {
		Name = "Element",
		BackgroundColor3 = Color3.fromRGB(7, 9, 14),
		BackgroundTransparency = 0.1,
		ZIndex = 6,
	}
	for key, value in props do
		defaults[key] = value
	end
	local badge = Kit.new("Frame", defaults, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Width),
		Kit.stroke(element.Color, 2, 0),
	})
	Kit.label({
		Text = element.Icon,
		Font = Theme.Font.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = (defaults.ZIndex :: number) + 1,
		Parent = badge,
	}, 40)
	return badge
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
