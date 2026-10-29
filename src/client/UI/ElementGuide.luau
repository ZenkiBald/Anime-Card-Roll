--!nonstrict
-- ELEMENTS: how the strategy layer works, in one panel (Elements.luau): the wheel, every synergy tier,
-- every bond (and whether you own both cards), and a few tactics. Opened from the BATTLE screen's SCOUT
-- box and the deck screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)

local ElementGuide = {}

local modal
local list: ScrollingFrame

local function line(order: number, text: string, color: Color3, size: number, font: Enum.Font?)
	return Kit.label({
		LayoutOrder = order,
		Text = text,
		RichText = true,
		Font = font or Theme.Font.Bold,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = size,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
		Parent = list,
	}, size)
end

local function draw()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function add(text: string, color: Color3?, size: number?, font: Enum.Font?)
		order += 1
		return line(order, text, color or Theme.Color.Text, size or 17, font)
	end

	add("BUILD YOUR FOUR COLUMNS",Theme.Color.Gold,22,Theme.Font.Display)
	add("Attack cards fight and take hits. A Support changes the Attack card directly above it. Supports work with any attacker; a familiar partner adds the bond bonus listed below.",Theme.Color.Text,17)
	add("FAMILIAR BONDS",Theme.Color.Gold,22,Theme.Font.Display)
	for _,bond in require(Shared.ColumnBonds).List do
		local attack,support=Cards.Get(bond.Attack),Cards.Get(bond.Support)
		add(attack.Name.." + "..support.Name,Theme.Color.Quick,18,Theme.Font.Heavy)
		add(bond.Text,Theme.Color.Text,16)
	end
	add("BATTLE RHYTHM",Theme.Color.Gold,22,Theme.Font.Display)
	add("Basic attacks follow the blue action bar. Skills wait at least 8 seconds. Ultimates need full charge and a 22-second cooldown; changing speed accelerates the whole simulation.",Theme.Color.Text,17)
	add("Focus a Warder to break its protection or a Mender to stop enemy healing. The leader falling wins the fight. Familiar column combos fire once as the leader weakens.",Theme.Color.Text,17)
	add("STATUS EFFECTS",Theme.Color.Gold,22,Theme.Font.Display)
	add("Burn, Bleed, Freeze, Stun and Weaken work exactly as the card's technique describes. Inspect the ability and its activation-limit pills before choosing your four columns.",Theme.Color.Muted,16)

end

function ElementGuide.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "ElementGuideGui", "BONDS & TACTICS", Vector2.new(0.8, 0.84), Vector2.new(900, 640))
	list = Kit.new("ScrollingFrame", {
		Name = "Guide",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})
	modal.OnOpen = draw
end

function ElementGuide.Open()
	if modal then
		modal:Open()
	end
end

return ElementGuide
