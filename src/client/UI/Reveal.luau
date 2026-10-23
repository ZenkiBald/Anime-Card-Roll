--!nonstrict
-- The reveal ladder: every rarity gets a bigger show than the one below it. Every reveal stands on
-- a backdrop in the tier's colour (radial glow + rising motes) and the card flips over, then sways.
--   Common / Uncommon  quick pop, soft rays
--   Rare               coloured build-up pulse + light rays
--   Epic               + screen shake + sparks
--   Legendary          + cinematic letterbox, longer build-up, gold flash, foil shimmer
--   Mythic             + full-screen cut-in banner, light burst before the flip
--   Secret             + blackout heartbeat, prismatic frame

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Borders = require(Shared.Borders)
local Traits = require(Shared.Traits)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local Abilities = require(script.Parent.Abilities)
local Sfx = require(script.Parent.Sfx)

local Reveal = {}

local gui: ScreenGui
local toastArea: Frame
local queue = {}
local running = false
local toastOrder = 0

-- Called with true when full reveals start showing and false when the last one closes
-- (Main hides the HUD meanwhile).
Reveal.OnBusy = nil :: ((boolean) -> ())?

local BUILD_PULSES ={ Rare = 1, Epic = 2, Legendary = 3, Mythic = 3, Secret = 4 }

local function outcomeText(result): string
	local text
	if result.Outcome == "New" then
		text = "NEW CARD!"
	elseif result.Outcome == "Star" then
		text = `★ Star up!  {result.Stars}/{Config.MaxStars}`
	else
		text = "Duplicate"
	end
	-- A foil found for the first time, and an Awakening node this pull opened.
	if result.NewFoil and result.Foil and result.Foil ~= "standard" then
		local foil = Foils.Get(result.Foil)
		text ..= `   ·   {foil.Icon} {string.upper(foil.Name)}!`
	end
	if result.NewNode then
		local node = Awaken.Nodes[result.NewNode]
		text ..= `   ·   ✴️ AWAKENING {result.NewNode}: {if node then node.Text else ""}`
	end
	return text
end

local function callout(parent: Instance, text: string, color: Color3, y: number, size: number, maxText: number)
	local label = Kit.label({
		Text = text,
		Font = Theme.Font.Display,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.8, size),
		ZIndex = 30,
		Parent = parent,
	}, maxText)
	Kit.textStroke(Color3.new(0, 0, 0), 3, 0.2).Parent = label
	local scale = Kit.new("UIScale", { Scale = 0.4, Parent = label })
	Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	return label
end

-- Waits for a tween (or a number of seconds) unless the player hits SKIP.
local function waitFor(thing: any, skipped: () -> boolean) -- a Tween, or a number of seconds
	local deadline = if type(thing) == "number" then os.clock() + thing else nil
	while not skipped() do
		if deadline then
			if os.clock() >= deadline then
				return
			end
		elseif thing.PlaybackState ~= Enum.PlaybackState.Playing and thing.PlaybackState ~= Enum.PlaybackState.Begin then
			return
		end
		task.wait()
	end
end

local function pulse(scale: UIScale, period: number, amount: number, skipped: () -> boolean)
	waitFor(Kit.tween(scale, period * 0.5, { Scale = 1 + amount }, Enum.EasingStyle.Sine), skipped)
	waitFor(Kit.tween(scale, period * 0.5, { Scale = 1 }, Enum.EasingStyle.Sine), skipped)
end

local function cutInBanner(root: Instance, tier, skipped: () -> boolean)
	local banner = Kit.new("Frame", {
		Name = "CutIn",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.7, 0.44),
		Size = UDim2.fromScale(1.4, 0.2),
		Rotation = -5,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 60,
		Parent = root,
	}, {
		Kit.gradient(ColorSequence.new(tier.Dark, tier.Color), 0),
	})
	local label = Kit.label({
		Text = string.upper(tier.Name),
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.8),
		ZIndex = 61,
		Parent = banner,
	}, 110)
	Kit.textStroke(Color3.new(0, 0, 0), 4, 0.1).Parent = label
	Sfx.Play("Whoosh", 0.8)
	waitFor(Kit.tween(banner, 0.3, { Position = UDim2.fromScale(0.5, 0.44) }, Enum.EasingStyle.Quart), skipped)
	if not skipped() then
		Sfx.Play("Boom", 1.1)
		Effects.Shake(banner, 10, 0.4)
		waitFor(0.75, skipped)
		waitFor(Kit.tween(banner, 0.28, { Position = UDim2.fromScale(1.7, 0.44) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In), skipped)
	end
	banner:Destroy()
end

local function heartbeat(root: Instance, skipped: () -> boolean)
	local label = Kit.label({
		Text = "? ? ?",
		Font = Theme.Font.Display,
		TextColor3 = Color3.fromRGB(219, 230, 254),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.5, 0.18),
		ZIndex = 60,
		Parent = root,
	}, 110)
	local scale = Kit.new("UIScale", { Scale = 1, Parent = label })
	for beat = 1, 3 do
		if skipped() then
			break
		end
		Sfx.Play("LowHit", 0.55 + beat * 0.05) -- heartbeat
		pulse(scale, 0.55, 0.25, skipped)
	end
	label:Destroy()
end

-- The tier's backdrop: three stacked soft circles make a radial glow behind the card, and motes
-- in the tier's colour drift up the screen. Everything lives under `root` and goes with it.
local function scene(root: Instance, tier)
	for i, spec in { { 1.3, 0.94 }, { 1.05, 0.92 }, { 0.82, 0.89 }, { 0.62, 0.86 }, { 0.44, 0.82 } } do
		local circle = Kit.new("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(spec[1], spec[1]),
			BackgroundColor3 = tier.Color,
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = root,
		}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height) })
		Kit.tween(circle, 0.4 + i * 0.1, { BackgroundTransparency = spec[2] })
	end
	local count = if Theme.FxLow then 6 else 16
	for _ = 1, count do
		local size = math.random(5, 11)
		local x = math.random()
		local mote = Kit.new("Frame", {
			Name = "Mote",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 1.05),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = if math.random() < 0.3 then Color3.new(1, 1, 1) else tier.Color,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = root,
		})
		local seconds = 3 + math.random() * 3
		TweenService:Create(
			mote,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, math.random() * seconds),
			{ Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, -0.05), Rotation = 225 }
		):Play()
	end
end

-- Black bars that slide in from the top and bottom: the "cinematic" frame for Legendary and up.
local function letterbox(root: Instance)
	local bars = {}
	for _, top in { true, false } do
		local bar = Kit.new("Frame", {
			Name = "Letterbox",
			AnchorPoint = Vector2.new(0, if top then 1 else 0),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.fromScale(1, 0.11),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 70,
			Parent = root,
		})
		Kit.tween(bar, 0.35, { Position = UDim2.fromScale(0, if top then 0.11 else 0.89) }, Enum.EasingStyle.Quart)
		table.insert(bars, bar)
	end
	return function()
		for _, bar in bars do
			local top = bar.AnchorPoint.Y == 1
			Kit.tween(bar, 0.25, { Position = UDim2.fromScale(0, if top then 0 else 1) }, Enum.EasingStyle.Quart)
		end
	end
end

-- A ring of light bursting out from the card, just before a Mythic or Secret turns over.
local function burst(root: Instance, color: Color3)
	local ring = Kit.new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.1, 0.1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		ZIndex = 55,
		Parent = root,
	}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height), Kit.stroke(Color3.new(1, 1, 1), 6, 0) })
	Kit.tween(ring, 0.5, { Size = UDim2.fromScale(2.6, 2.6), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad).Completed:Connect(function()
		ring:Destroy()
	end)
	Kit.tween(ring.UIStroke, 0.5, { Transparency = 1 })
end

-- Lets a card squash sideways for the flip (it keeps its 0.72 shape through the holder instead).
local function unlock(card: Frame)
	local aspect = card:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
end

-- The slanted red ribbon that slams onto the card's corner for a special border: "NEW RAINBOW!".
local function borderRibbon(holder: Instance, borderId: string, isNew: boolean)
	local border = Borders.Get(borderId)
	local ribbon = Kit.new("Frame", {
		Name = "BorderRibbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.78, 0.04),
		Size = UDim2.fromScale(0.95, 0.13),
		Rotation = 11,
		BackgroundColor3 = Color3.fromRGB(232, 36, 56),
		ZIndex = 40,
		Parent = holder,
	}, {
		Kit.corner(UDim.new(0.25, 0)),
		Kit.stroke(Color3.fromRGB(40, 6, 16), 4, 0),
	})
	-- A strip of the border's own colours along the ribbon's bottom edge.
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.92, 0.16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 41,
		Parent = ribbon,
	}, { Kit.corner(UDim.new(1, 0)), Kit.gradient(border.Gradient, 0) })
	local label = Kit.label({
		Text = if isNew then `NEW {string.upper(border.Name)}!` else `{string.upper(border.Name)}!`,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.92, 0.72),
		ZIndex = 42,
		Parent = ribbon,
	}, 60)
	Kit.textStroke(Color3.fromRGB(40, 6, 16), 3, 0).Parent = label
	local scale = Kit.new("UIScale", { Scale = 2.4, Parent = ribbon })
	Kit.tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	return ribbon
end

-- Border sting on top of the rarity's: brighter and bigger for rarer borders.
local function borderSting(borderId: string)
	if borderId == "Gold" then
		Sfx.Play("Reward", 1.15)
	elseif borderId == "Rainbow" then
		Sfx.Play("Upgrade", 1.1)
		Sfx.Play("Reward", 1.3)
	elseif borderId == "Secret" then
		Sfx.Play("Boom", 0.85)
		Sfx.Play("LowHit", 0.8)
		Sfx.Play("Reward", 0.9)
	end
end

local function playFull(result)
	local card = Cards.Get(result.CardId)
	if card == nil then
		return
	end
	local tier = Rarity.Get(result.Rarity)
	local idx = tier.Index

	local root = Kit.new("Frame", {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local dim = Kit.new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Backdrop,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = root,
	})
	local dimTarget = if idx >= 7 then 0 elseif idx >= 5 then 0.15 else 0.35
	Kit.tween(dim, 0.25, { BackgroundTransparency = dimTarget })
	scene(root, tier)
	local closeBars = if idx >= 5 then letterbox(root) else nil

	local stage = Kit.new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.62, 0.6),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = root,
	})
	local holder = Kit.new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = stage,
	}, { Kit.aspect(0.72, Enum.DominantAxis.Height) })
	local scale = Kit.new("UIScale", { Scale = 0, Parent = holder })
	-- The card sits in `flip`, which squashes sideways to turn it over.
	local flip = Kit.new("Frame", {
		Name = "Flip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = holder,
	})

	-- SKIP jumps straight to the card for the long build-ups (Rare and up).
	local skippedFlag = false
	local function skipped(): boolean
		return skippedFlag
	end
	local skipButton = nil
	if idx >= 3 then
		skipButton = Kit.button("SKIP  ▶▶", Theme.Color.PanelLight, Theme.Color.Panel, {
			Name = "Skip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -24),
			Size = UDim2.fromOffset(130, 46),
			ZIndex = 80,
			Parent = root,
		})
		skipButton.Activated:Connect(function()
			skippedFlag = true
		end)
	end

	-- Mythic and Secret open with their own intro.
	if idx == 6 then
		cutInBanner(root, tier, skipped)
	elseif idx == 7 then
		heartbeat(root, skipped)
	end

	-- Face-down card drops in.
	local back = CardView.back()
	unlock(back)
	back.Parent = flip
	waitFor(Kit.tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back), skipped)

	-- Build-up: the back glows in the tier's colour and pulses faster for rarer cards.
	local pulses = BUILD_PULSES[tier.Name]
	if pulses then
		local stroke = back:FindFirstChild("BackStroke")
		if stroke then
			Kit.tween(stroke, 0.3, { Color = tier.Color, Thickness = 6, Transparency = 0 })
		end
		local emblem = back:FindFirstChild("Emblem")
		if emblem then
			Kit.tween(emblem, 0.3, { BackgroundColor3 = tier.Color })
		end
		for i = 1, pulses do
			if skipped() then
				break
			end
			local period = math.max(0.22, 0.55 - i * 0.1)
			Sfx.Play("Riser", 0.85 + i * 0.15 + (idx - 3) * 0.05) -- climbs with each pulse and each tier
			if idx >= 5 then
				Effects.Sparks(stage, tier.Color, 6, 0.35)
			end
			pulse(scale, period, 0.07 + i * 0.02, skipped)
		end
	else
		Kit.tween(holder, 0.07, { Rotation = -5 }).Completed:Wait()
		Kit.tween(holder, 0.07, { Rotation = 5 }).Completed:Wait()
		Kit.tween(holder, 0.07, { Rotation = 0 }).Completed:Wait()
	end
	-- A special border teases itself before the flip: the back takes on the border's colours.
	local borderId = result.Border or "Normal"
	local special = Borders.Index(borderId) >= 2
	if special and not skipped() then
		local stroke = back:FindFirstChild("BackStroke")
		if stroke then
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 7
			stroke.Transparency = 0
			local gradient = stroke:FindFirstChildOfClass("UIGradient") or Kit.gradient(Borders.Get(borderId).Gradient, 45)
			gradient.Color = Borders.Get(borderId).Gradient
			gradient.Parent = stroke
			if borderId ~= "Gold" then
				Effects.Spin(gradient, 240)
			end
		end
		Sfx.Play("Chime", 1.3 + Borders.Index(borderId) * 0.1)
		Effects.Sparks(stage, Borders.Get(borderId).Color, 14, 0.5)
		pulse(scale, 0.4, 0.14, skipped)
	end
	if skipButton then
		skipButton:Destroy()
	end
	dim.BackgroundTransparency = dimTarget
	holder.Rotation = 0

	-- The reveal: Mythic and Secret burst with light first, then the card turns over.
	local flashColor = if idx == 7 then Color3.new(1, 1, 1) else tier.Color
	if idx >= 6 then
		burst(root, flashColor)
	end
	Sfx.Play("Flip")
	Kit.tween(flip, 0.09, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	Effects.Flash(root, flashColor, 0.4 + idx * 0.06, if idx >= 5 then 0 else 0.4)
	Sfx.Sting(tier.Name)
	if closeBars then
		closeBars()
	end
	back:Destroy()
	local front = CardView.new(card.Id, {
		Owned = true,
		Stars = result.Stars,
		Animate = true,
		Border = borderId,
		Trait = result.CardTrait,
		Foil = Foils.Best(result.Foils),
	})
	unlock(front)
	front.Parent = flip
	Kit.tween(flip, 0.16, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	scale.Scale = 1.3
	Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if special then
		borderSting(borderId)
		task.delay(0.22, function()
			if holder.Parent then
				borderRibbon(holder, borderId, result.NewBorder ~= false)
				Effects.Sparks(stage, Borders.Get(borderId).Color, if borderId == "Gold" then 16 else 28, 0.9)
			end
		end)
		if borderId ~= "Gold" then
			Effects.Rays(stage, Borders.Get(borderId).Color, 10)
		end
	end
	-- A slow sway while it's on show.
	holder.Rotation = -2
	TweenService:Create(holder, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 2 }):Play()

	Effects.Rays(stage, if idx == 7 then Color3.new(1, 1, 1) else tier.Color, if idx >= 3 then 4 + idx * 2 else 6)
	if idx >= 4 then
		Effects.Shake(stage, 4 + (idx - 4) * 5, 0.45)
		Effects.Sparks(stage, tier.Color, 10 * (idx - 2), 0.75)
	end
	if idx >= 5 then
		Effects.Shimmer(front, 3)
	end
	if idx == 7 then
		local stroke = front:FindFirstChild("RarityStroke")
		local gradient = stroke and stroke:FindFirstChild("RarityGradient")
		if gradient then
			Effects.Spin(gradient, 140)
		end
	end

	-- Its abilities slide in beside the card, so you see what you pulled can do.
	task.delay(0.35, function()
		if root.Parent == nil then
			return
		end
		local screen = root.AbsoluteSize
		local cardHalf = holder.AbsoluteSize.X / 2
		local left = screen.X / 2 + cardHalf + 22
		local width = math.min(380, screen.X - left - 16)
		if width < 200 then
			return -- no room beside the card (narrow phone): the Index shows them
		end
		local panel = Kit.new("Frame", {
			Name = "Abilities",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, left + 40, 0.44, 0),
			Size = UDim2.fromOffset(width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(7, 9, 14),
			BackgroundTransparency = 0.15,
			ZIndex = 21,
			Parent = root,
		}, {
			Kit.corner(UDim.new(0, 16)),
			Kit.stroke(tier.Color, 2, 0.2),
			Kit.padding(10),
			Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		})
		Abilities.List(card, panel, 0, "small")
		Kit.tween(panel, 0.3, { Position = UDim2.new(0, left, 0.44, 0) }, Enum.EasingStyle.Back)
	end)

	-- Text under the card.
	local callSize = 0.06 + idx * 0.008
	if special then
		-- "RAINBOW LEGENDARY!" in the border's own colours.
		local text = `{string.upper(Borders.Get(borderId).Name)} {string.upper(tier.Name)}!`
		local label = callout(root, text, Color3.new(1, 1, 1), 0.81, callSize + 0.01, 72)
		Kit.gradient(Borders.Get(borderId).Gradient, 0).Parent = label
	else
		callout(root, if idx >= 4 then string.upper(tier.Name) .. "!" else string.upper(tier.Name), tier.Color, 0.81, callSize, 70)
	end
	local outcome = Kit.label({
		Text = outcomeText(result),
		Font = Theme.Font.Heavy,
		TextColor3 = if result.Outcome == "New" then Theme.Color.Gold else Theme.Color.Text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.875),
		Size = UDim2.fromScale(0.7, 0.045),
		TextTransparency = 1,
		ZIndex = 30,
		Parent = root,
	}, 30)
	Kit.tween(outcome, 0.3, { TextTransparency = 0 })
	local hint = Kit.label({
		Text = "Tap to continue",
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.925),
		Size = UDim2.fromScale(0.4, 0.03),
		TextTransparency = 1,
		ZIndex = 30,
		Parent = root,
	}, 20)
	task.delay(0.6, function()
		if hint.Parent then
			Kit.tween(hint, 0.3, { TextTransparency = 0.2 })
		end
	end)

	-- Close on tap, or by itself after a while.
	local shownAt = os.clock()
	local closeSignal = Instance.new("BindableEvent")
	local tapConnection = dim.Activated:Connect(function()
		if os.clock() - shownAt > 0.35 then
			closeSignal:Fire()
		end
	end)
	local autoClose = if special then 6 elseif idx <= 2 then 1.3 elseif idx == 3 then 2.2 else 6
	task.delay(autoClose, function()
		closeSignal:Fire()
	end)
	closeSignal.Event:Wait()
	tapConnection:Disconnect()
	closeSignal:Destroy()

	Kit.tween(scale, 0.18, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.tween(dim, 0.2, { BackgroundTransparency = 1 })
	for _, child in root:GetDescendants() do
		if child:IsA("TextLabel") then
			Kit.tween(child, 0.15, { TextTransparency = 1 })
		end
	end
	task.wait(0.2)
	root:Destroy()
end

local function pump()
	if running then
		return
	end
	running = true
	if Reveal.OnBusy then
		Reveal.OnBusy(true)
	end
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			local ok, err = pcall(playFull, item.Result)
			if not ok then
				warn("Reveal failed:", err)
			end
			if item.OnDone then
				item.OnDone()
			end
		end
		running = false
		if Reveal.OnBusy then
			Reveal.OnBusy(false)
		end
	end)
end

function Reveal.Init(playerGui: Instance)
	gui = Kit.screenGui("RevealGui", 20, playerGui)
	gui.IgnoreGuiInset = true

	toastArea = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(0.7, 0.16),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
end

function Reveal.IsBusy(): boolean
	return running or #queue > 0
end

-- Full reveal. Queued, so several can arrive at once (e.g. Auto Roll hits).
function Reveal.Full(result, onDone: (() -> ())?)
	table.insert(queue, { Result = result, OnDone = onDone })
	pump()
end

-- Fast pop near the buttons (Quick Roll and Auto Roll). Mythic and up always get the full show.
function Reveal.Quick(result)
	local card = Cards.Get(result.CardId)
	if card == nil then
		return
	end
	local tier = Rarity.Get(result.Rarity)
	local borderId = result.Border or "Normal"
	if tier.Index >= 6 or Borders.Index(borderId) >= Borders.Index("Rainbow") then
		Reveal.Full(result) -- Mythic and up, and any Rainbow / Secret border, always get the full show
		return
	end

	toastOrder += 1
	local slot = Kit.new("Frame", {
		Name = "Toast",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = toastOrder,
		Parent = toastArea,
	}, { Kit.aspect(0.72, Enum.DominantAxis.Height) })
	local scale = Kit.new("UIScale", { Scale = 0, Parent = slot })
	local view = CardView.new(card.Id, { Owned = true, Stars = result.Stars, Compact = true, Border = borderId })
	view.Parent = slot

	local badgeText = if borderId ~= "Normal"
		then `{string.upper(borderId)}!`
		elseif result.Outcome == "New" then "NEW"
		elseif result.Outcome == "Star" then `★{result.Stars}`
		else "DUPE"
	local badge = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.7, 0.16),
		BackgroundColor3 = if borderId ~= "Normal"
			then Borders.Get(borderId).Color
			elseif result.Outcome == "New" then Theme.Color.Gold
			else Theme.Color.PanelLight,
		ZIndex = 20,
		Parent = slot,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	if borderId ~= "Normal" then
		borderSting(borderId)
	end
	Kit.label({
		Text = badgeText,
		Font = Theme.Font.Heavy,
		TextColor3 = if result.Outcome == "New" or borderId ~= "Normal" then Color3.fromRGB(40, 24, 0) else Theme.Color.Text,
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.05, 0.1),
		ZIndex = 21,
		Parent = badge,
	}, 18)

	Kit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	Sfx.Play("Flip", 1.1 + math.random() * 0.2)
	Sfx.Sting(tier.Name, true)
	if tier.Index >= 4 then
		Effects.Flash(gui, tier.Color, 0.35, 0.65)
		Effects.Sparks(slot, tier.Color, 10, 0.9)
	end
	if tier.Index >= 5 then
		Effects.Shimmer(view, 1)
	end

	-- Keep at most five on screen.
	local toasts = {}
	for _, child in toastArea:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 5 do
		toasts[i]:Destroy()
	end

	task.delay(if tier.Index >= 4 then 2.2 else 1.4, function()
		if slot.Parent == nil then
			return
		end
		Kit.tween(scale, 0.18, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		slot:Destroy()
	end)
end

return Reveal
