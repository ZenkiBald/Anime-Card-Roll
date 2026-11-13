--!nonstrict
-- The town shows off the game's art. A slow carousel of chase cards floats over the fountain rim (the
-- week's Featured Card, each world's boss card, then the rarest of the rest) and each world gate flies its
-- boss's card as a banner. Everything is built at start from Cards / Bosses, so a new card or boss shows
-- up by itself. Parts are anchored, never collide and cast no shadow; clients turn the carousel (HubFx
-- "Orbit") and cull its sparkles with the other town effects ("TownFxRange").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)

local Showcase = {}

Showcase.CarouselCards = 6
Showcase.CardHeight = 10.5 -- studs; width follows the card shape
Showcase.OrbitSpeed = 0.1 -- radians a second (about a minute a turn)

local CARD_RATIO = 0.72
local GOLD = Color3.fromRGB(255, 205, 80)
local APEX = Color3.fromRGB(190, 120, 255)
local INK = Color3.fromRGB(14, 12, 22)

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function slab(props: { [string]: any }, parent: Instance): Part
	local part = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Material = Enum.Material.SmoothPlastic,
	}, nil)
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function label(parent: Instance, props: { [string]: any }, cap: number): TextLabel
	local text = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 4,
	}, nil)
	for key, value in props do
		(text :: any)[key] = value
	end
	make("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = cap }, text)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }, text)
	text.Parent = parent
	return text
end

-- One painted face: the card's art edge to edge, a tag on top, its name and odds at the bottom.
local function face(board: BasePart, side: Enum.NormalId, card, tag: string, color: Color3, footer: string)
	local gui = make("SurfaceGui", {
		Name = if side == Enum.NormalId.Front then "Art" else "ArtBack",
		Face = side,
		CanvasSize = Vector2.new(360, 500),
		LightInfluence = 0,
		Brightness = 1.15,
		MaxDistance = 320,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, board)
	make("ImageLabel", {
		Name = "Illustration",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Image = card.Image or "",
		ScaleType = Enum.ScaleType.Crop,
	}, gui)
	local shade = make("Frame", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.34),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, gui)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1) }, shade)
	local pill = make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.025),
		Size = UDim2.fromScale(0.78, 0.085),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }, pill)
	label(pill, { Name = "Text", Text = tag, Size = UDim2.fromScale(1, 1) }, 30)
	label(gui, { Name = "CardName", Text = string.upper(card.Name), Position = UDim2.fromScale(0.05, 0.78), Size = UDim2.fromScale(0.9, 0.11) }, 44)
	label(gui, { Name = "Odds", Text = footer, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), Position = UDim2.fromScale(0.05, 0.89), Size = UDim2.fromScale(0.9, 0.08) }, 32)
end

-- A standing card: the painted board inside a glowing rim, readable from both sides.
local function board(parent: Instance, name: string, cf: CFrame, height: number, card, tag: string, color: Color3, footer: string): BasePart
	local width = height * CARD_RATIO
	local panel = slab({ Name = name, Size = Vector3.new(width, height, 0.3), CFrame = cf, Color = INK }, parent)
	slab({
		Name = "Rim",
		Size = Vector3.new(width + 0.55, height + 0.55, 0.16),
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Neon,
	}, parent)
	face(panel, Enum.NormalId.Front, card, tag, color, footer)
	face(panel, Enum.NormalId.Back, card, tag, color, footer)
	return panel
end

local function odds(card): string
	return `1 IN {Cards.Rarity(card.Id, "Normal")}`
end

-- The chase cards, in the order they go round: the Featured Card, the boss cards by world, then the
-- rarest normal cards that are left.
function Showcase.Pick(now: number, count: number): { { Card: any, Tag: string, Color: Color3 } }
	local picks, taken = {}, {}
	local function add(card, tag: string, color: Color3)
		if card and card.Image and not taken[card.Id] and #picks < count then
			taken[card.Id] = true
			table.insert(picks, { Card = card, Tag = tag, Color = color })
		end
	end
	add(Cards.Get(Cards.FeaturedAt(now)), "FEATURED x3", GOLD)
	for _, boss in Bosses.List do
		add(Cards.ForBoss(boss.Id), `WORLD {boss.World} BOSS`, boss.Accent)
	end
	local rest = {}
	for _, card in Cards.List do
		if card.Type == "Attack" and card.Boss == nil and card.Weather == nil and card.Weight > 0 then
			table.insert(rest, card)
		end
	end
	table.sort(rest, function(a, b)
		if a.Weight ~= b.Weight then
			return a.Weight < b.Weight
		end
		return a.Id < b.Id
	end)
	for _, card in rest do
		add(card, "APEX", APEX)
	end
	return picks
end

-- `centre` is the middle of the ring at the height of the cards' middles.
function Showcase.Carousel(parent: Instance, centre: Vector3, radius: number)
	local model = make("Model", { Name = "CardCarousel" }, nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local spindle = slab({ Name = "Spindle", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(centre), Transparency = 1 }, model)
	model.PrimaryPart = spindle
	local picks = Showcase.Pick(os.time(), Showcase.CarouselCards)
	for i, pick in picks do
		local angle = (i - 1) / #picks * math.pi * 2
		local spot = centre + Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		-- Front faces away from the fountain.
		local cf = CFrame.lookAt(spot, spot + (spot - centre))
		local panel = board(model, `Card{i}`, cf, Showcase.CardHeight, pick.Card, pick.Tag, pick.Color, odds(pick.Card))
		local sparkle = make("ParticleEmitter", {
			Name = "Sparkle",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(pick.Color, Color3.new(1, 1, 1)),
			LightEmission = 1,
			Rate = 3,
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(0.6, 1.6),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		}, panel)
		sparkle:SetAttribute("TownFxRange", 110)
	end
	model:SetAttribute("Orbit", Showcase.OrbitSpeed)
	model.Parent = parent
	return model
end

-- A cloth banner of the world's boss card, hung in the middle of its town gate.
function Showcase.GateBanner(parent: Instance, gate: Model, boss)
	local card = Cards.ForBoss(boss.Id)
	if card == nil or card.Image == nil then
		return nil
	end
	local box, size = gate:GetBoundingBox()
	local height = math.clamp(size.Y * 0.4, 8, 12)
	local width = height * CARD_RATIO
	-- Under the two crossbeams, leaving room to walk and ride through.
	local top = size.Y / 2 - size.Y * 0.27
	local cf = box * CFrame.new(0, top - height / 2, 0)
	local model = make("Model", { Name = `GateBanner_{boss.Id}` }, nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local panel = board(model, "Banner", cf, height, card, `WORLD {boss.World}`, boss.Accent, string.upper(boss.WorldName))
	model.PrimaryPart = panel
	local wood = Color3.fromRGB(52, 34, 28)
	slab({ Name = "Rod", Size = Vector3.new(width + 1.6, 0.4, 0.4), CFrame = cf * CFrame.new(0, height / 2 + 0.45, 0), Color = wood, Material = Enum.Material.Wood }, model)
	for _, x in { -width / 2, width / 2 } do
		local rope = size.Y * 0.27 - 0.6
		if rope > 0.2 then
			slab({ Name = "Cord", Size = Vector3.new(0.14, rope, 0.14), CFrame = cf * CFrame.new(x, height / 2 + 0.6 + rope / 2, 0), Color = wood, Material = Enum.Material.Fabric }, model)
		end
	end
	model.Parent = parent
	return model
end

local function nearestGate(town: Instance, spot: Vector3): Model?
	local best, bestDistance = nil, 40
	for _, child in town:GetChildren() do
		if child:IsA("Model") and string.find(child.Name, "Torii") then
			local pivot = child:GetPivot().Position
			local distance = (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude
			if distance < bestDistance then
				best, bestDistance = child, distance
			end
		end
	end
	return best
end

-- `gateSigns` maps a boss id to the spot above its town gateway (World reads them from the map's signs).
function Showcase.Build(hub: Instance, town: Instance?, gateSigns: { [string]: CFrame })
	if town == nil then
		return
	end
	local fountain = town:FindFirstChild("Fountain")
	if fountain and fountain:IsA("Model") then
		local box, size = fountain:GetBoundingBox()
		local radius = math.min(size.X, size.Z) / 2 - 2.8 -- over the basin's rim
		local rim = box.Position.Y - size.Y / 2 + size.Y * 0.31 -- the rim sits a little under a third of the way up
		Showcase.Carousel(hub, Vector3.new(box.Position.X, rim + 0.7 + Showcase.CardHeight / 2, box.Position.Z), radius)
	end
	for _, boss in Bosses.List do
		local spot = gateSigns[boss.Id]
		local gate = spot and nearestGate(town, spot.Position)
		if gate then
			Showcase.GateBanner(hub, gate, boss)
		end
	end
end

return Showcase
