--!nonstrict
-- ELEMENTS: how the strategy layer works, in one panel (Elements.luau): the wheel, every synergy tier,
-- every bond (and whether you own both cards), and a few tactics. Opened from the BATTLE screen's SCOUT
-- box and the deck screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Elements = require(Shared.Elements)
local Cards = require(Shared.Cards)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local ElementUi = require(script.Parent.ElementUi)
local State = require(script.Parent.Parent.State)

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

	add("THE ELEMENT WHEEL", Theme.Color.Gold, 22, Theme.Font.Display)
	add(
		`Every card, boss and guard has an element. A hit from an element that beats the target's deals <b>x{Elements.Strong}</b> (▲); into one that beats yours, <b>x{Elements.Weak}</b> (▼). Enemies hit your cards by the same rule. A higher rarity still wins any matchup.`,
		Theme.Color.Muted,
		16
	)
	for _, element in Elements.List do
		local weakTo = {}
		for _, other in Elements.List do
			if other.Id ~= "Cosmic" and table.find(other.Beats, element.Id) then
				table.insert(weakTo, other.Id)
			end
		end
		local weakText = if element.Id == "Cosmic" or #weakTo == 0 then "nothing" else ElementUi.RichList(weakTo)
		add(`<b>{ElementUi.Rich(element.Id)}</b>   beats {ElementUi.RichList(element.Beats)}   ·   weak to {weakText}`, Theme.Color.Text, 17, Theme.Font.Heavy)
	end

	add("SYNERGIES", Theme.Color.Gold, 22, Theme.Font.Display)
	add("Cards of one element anywhere in your deck (Attack and Support together) power the whole deck for the fight. 4 replaces 2. Cosmic counts for none.", Theme.Color.Muted, 16)
	for _, synergy in Elements.Synergies do
		local tiers = {}
		for _, tier in synergy.Tiers do
			table.insert(tiers, `<b>{tier.Count}</b>: {tier.Text}`)
		end
		add(`{ElementUi.Rich(synergy.Element)} <b>{string.upper(synergy.Name)}</b>   {table.concat(tiers, "   ·   ")}`, Theme.Color.Text, 16, Theme.Font.Bold)
	end

	add("BONDS", Theme.Color.Gold, 22, Theme.Font.Display)
	add(
		`Two named cards in one deck: when the enemy leader first drops to half HP (or {Elements.BondAt} s in), and both still stand, they fire a Dual Ultimate together, once a fight.`,
		Theme.Color.Muted,
		16
	)
	for _, bond in Elements.Bonds do
		local names = {}
		for _, id in bond.Cards do
			local card = Cards.Get(id)
			local have = State.Cards[id] ~= nil
			table.insert(names, `{if have then "✓ " else ""}{if card then card.Name else id}`)
		end
		add(`🤝 <b>{string.upper(bond.Name)}</b>  ({table.concat(names, " + ")})  {math.floor(bond.Pct * 100)}% of both cards' power`, Color3.fromRGB(255, 200, 140), 16, Theme.Font.Heavy)
		add(bond.Text, Theme.Color.Muted, 14)
	end

	add("TACTICS", Theme.Color.Gold, 22, Theme.Font.Display)
	for _, tip in {
		"Scout first: the BATTLE screen shows the leader's and each guard's element. COUNTER-BUILD fills your deck with the cards that beat them.",
		"The Warder (🛡️) shields the leader while it stands: tap it to focus it down first.",
		"Menders are Light: Void cards cut them down fast (and Light cards break Void Warders).",
		"Bonds fire as the leader hits half HP: keep both cards alive until then.",
		"The tower's daily mutator boosts one element: switch decks to ride it.",
	} do
		add(`• {tip}`, Theme.Color.Text, 16)
	end
end

function ElementGuide.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "ElementGuideGui", "ELEMENTS", Vector2.new(0.8, 0.84), Vector2.new(900, 640))
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
