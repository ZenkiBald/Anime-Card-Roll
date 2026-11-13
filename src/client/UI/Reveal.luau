--!nonstrict
-- The reveal ladder: every border (the tier) gets a bigger show than the one below it
-- (Borders.RevealTier). Every reveal stands on a backdrop in the tier's colour (radial glow + rising
-- motes) and the card flips over, then sways.
--   Base      quick pop, soft rays
--   Gold      coloured build-up pulses, screen shake + sparks
--   Rainbow   + cinematic letterbox, full-screen cut-in banner, light burst before the flip
--   Secret    + blackout heartbeat, prismatic frame

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local RevealPolicy=require(Shared.RevealPolicy)
local State=require(script.Parent.Parent.State)
local Borders = require(Shared.Borders)
local Foils = require(Shared.Foils)
local Awaken = require(Shared.Awaken)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local RollCard = require(script.Parent.RollCard)
local Abilities = require(script.Parent.Abilities)
local Sfx = require(script.Parent.Sfx)
local Director = require(script.Parent.SecretRevealDirector)
local VfxAssets = require(script.Parent.VfxAssets)
local StatLine = require(script.Parent.StatLine)

local Reveal = {}

local gui: ScreenGui
local toastArea: Frame
local queue = {}
local running = false
local toastOrder = 0

-- Called with true when full reveals start showing and false when the last one closes
-- (Main hides the HUD meanwhile).
Reveal.OnBusy = nil :: ((boolean) -> ())?
-- True while quick pops should wait (Main: a panel is open).
Reveal.Muted = nil :: (() -> boolean)?

local BUILD_PULSES ={ Rare = 1, Epic = 2, Legendary = 3, Mythic = 3, Secret = 4 }

local function outcomeText(result): string
	local text
	if result.Outcome == "New" then
		text = "NEW CARD!"
	elseif result.Outcome == "Star" then
		text = `Copy bonus increased: +{result.Stars * 5}% stats`
	else
		text = ""
	end
	-- A foil found for the first time, and an Awakening node this pull opened.
	if result.NewFoil and result.Foil and result.Foil ~= "standard" then
		local foil = Foils.Get(result.Foil)
		text ..= `   ·   {string.upper(foil.Name)}!`
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
	for _ = 1, 3 do
		if skipped() then
			break
		end
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

-- Border sting on top of the rarity's: brighter and bigger for rarer borders.
local function borderSting(borderId: string)
	if borderId == "Gold" then
		Sfx.Play("Reward", 1.15)
	elseif borderId == "Rainbow" then
		Sfx.Play("Upgrade", 1.1)
		Sfx.Play("Reward", 1.3)
	end
end

-- `item.Batch` (a pack's cinematic run, PackOpen): { Index, Total, Skipped }. SKIP ALL ends the current
-- reveal, drops every queued one and tells the batch to stop, so a huge opening goes straight to its summary.
local function playFull(result, item)
	local card = Cards.Get(result.CardId)
	if card == nil then
		return
	end
	local batch = item and item.Batch
	local borderId = result.Border or "Normal"
	local fakeout = Director.Fakeout(borderId)
	local tease = Borders.Get(if fakeout then "Gold" else borderId)
	local tier = Borders.RevealTier(borderId)
	local intro = if fakeout then Borders.RevealTier("Gold") else tier
	local idx = tier.Index

	local root = Kit.new("Frame", {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local releaseSecret = if borderId == "Secret" then Director.SecretSession(root) else nil
	if releaseSecret then item.ReleaseSecret = releaseSecret end
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
	scene(root, intro)
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
	local skipAllFlag = false
	local closeSignal = Instance.new("BindableEvent")
	closeSignal.Parent = root
	local function skipped(): boolean
		return skippedFlag or skipAllFlag
	end
	-- SKIP ALL: shown whenever more reveals wait behind this one (queued, or the rest of a pack's batch).
	local remaining = #queue + (if batch then math.max(0, batch.Total - batch.Index) else 0)
	if remaining > 0 then
		local skipAll = Kit.button(`SKIP ALL ({remaining})  ▶▶▶`, Theme.Color.Danger, Color3.fromRGB(110, 20, 40), {
			Name = "SkipAll",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -164, 1, -24),
			Size = UDim2.fromOffset(190, 46),
			ZIndex = 80,
			Parent = root,
		})
		skipAll.Activated:Connect(function()
			if skipAllFlag then
				return
			end
			skipAllFlag = true
			if batch then
				batch.Skipped = true
			end
			Reveal.SkipQueue()
			closeSignal:Fire()
		end)
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

	local special = Borders.Index(borderId) >= 2
	local endHold = Director.Hold(stage, borderId, tease.Color, if idx >= 6 then 1.8 else 0.8)

	-- Mythic and Secret open with their own intro.
	if intro.Index == 6 then
		cutInBanner(root, intro, skipped)
	elseif intro.Index == 7 then
		heartbeat(root, skipped)
	end

	-- Face-down card drops in.
	local back = CardView.back()
	unlock(back)
	back.Parent = flip
	waitFor(Kit.tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back), skipped)

	-- Build-up: the back glows in the tier's colour and pulses faster for rarer cards.
	local pulses = BUILD_PULSES[tier.Sting]
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
	if special and not skipped() then
		local stroke = back:FindFirstChild("BackStroke")
		if stroke then
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 7
			stroke.Transparency = 0
			local gradient = stroke:FindFirstChildOfClass("UIGradient") or Kit.gradient(tease.Gradient, 45)
			gradient.Color = tease.Gradient
			gradient.Parent = stroke
			if borderId ~= "Gold" then
				Effects.Spin(gradient, 240)
			end
		end
		Sfx.Play("Chime", 1.3 + Borders.Index(borderId) * 0.1)
		Effects.Sparks(stage, Borders.Get(borderId).Color, 14, 0.5)
		pulse(scale, 0.4, 0.14, skipped)
		if fakeout and not skipped() then
			Director.Crack(back)
			waitFor(0.16, skipped)
		end
	end
	endHold()
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
	if borderId == "Secret" then
		if not skipAllFlag then Sfx.SecretDip(); Director.Flash(stage, flashColor, 0.55) end
	else
		Effects.Flash(root, flashColor, 0.4 + idx * 0.06, if idx >= 5 then 0 else 0.4)
	end
	if not skipAllFlag then Director.Snap(stage, borderId) end
	if borderId ~= "Secret" then Sfx.Sting(tier.Sting) end
	if closeBars then
		closeBars()
	end
	back:Destroy()
	local front = RollCard.new(card.Id, borderId, RollCard.IsNew(result))
	unlock(front)
	front.Parent = flip
	-- DMG / HP under the card, with the sword / heart icons (at its border and current duplicate bonus).
	if card.Type == "Attack" then
		local entry = State.Cards[card.Id]
		local pill = Kit.new("Frame", {
			Name = "Stats",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 10),
			Size = UDim2.new(0.96, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(7, 9, 14),
			BackgroundTransparency = 0.12,
			ZIndex = 20,
			Parent = holder,
		}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Borders.Get(borderId).Color, 2, 0.2) })
		StatLine.new(card, 0, borderId, if entry then Awaken.Level(entry) else 0, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -20, 1, -8),
			ZIndex = 21,
			Parent = pill,
		}, true, Cards.CopiesAt(entry, borderId))
	end
	Kit.tween(flip, 0.16, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	scale.Scale = 1.3
	Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if special then
		borderSting(borderId)
		task.delay(0.22, function()
			if holder.Parent then
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
		-- "RAINBOW BORDER!" in the border's own colours.
		local text = `{string.upper(Borders.Get(borderId).Name)} BORDER!`
		local label = callout(root, text, Color3.new(1, 1, 1), 0.81, callSize + 0.01, 72)
		Kit.gradient(Borders.Get(borderId).Gradient, 0).Parent = label
	else
		callout(root, string.upper(card.Name), tier.Color, 0.81, callSize, 70)
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
	if borderId == "Secret" then
		local claim = Kit.button("CLAIM", Theme.Color.Gold, Theme.Color.Panel, {
			Name = "Claim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.945),
			Size = UDim2.fromScale(0.24, 0.075), ZIndex = 65, Parent = root,
		})
		claim.Activated:Connect(function() closeSignal:Fire() end)
	else
		Kit.label({ Text = "Tap to continue", Font = Theme.Font.Medium, TextColor3 = Theme.Color.Muted,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.925),
			Size = UDim2.fromScale(0.4, 0.03), ZIndex = 30, Parent = root }, 20)
		local shownAt = os.clock()
		dim.Activated:Connect(function()
			if os.clock() - shownAt > 0.35 then closeSignal:Fire() end
		end)
		task.delay(if special then 6 elseif idx <= 2 then 1.3 elseif idx == 3 then 2.2 else 6, function()
			if closeSignal.Parent then closeSignal:Fire() end
		end)
	end
	if not skipAllFlag then closeSignal.Event:Wait() end
	if releaseSecret then releaseSecret(); item.ReleaseSecret = nil end
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
			local ok, err = pcall(playFull, item.Result, item)
			if not ok then
				if item.ReleaseSecret then item.ReleaseSecret() end
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

-- Quick-roll pops sit above the HUD's Next Goal pill: a little higher and smaller on a short (phone)
-- screen, where the HUD's stack starts higher up.
local function placeToasts()
	local height = gui.AbsoluteSize.Y
	local short = height > 0 and height < 500
	-- A screen-space tray beside the avatar, clear of the central camera and bottom roll controls.
	toastArea.AnchorPoint = Vector2.new(1, 1)
	toastArea.Position = UDim2.fromScale(0.97, if short then 0.63 else 0.68)
	toastArea.Size = UDim2.fromOffset(if short then 148 else 224, if short then 90 else 142)
end

-- Centre stage ----------------------------------------------------------------------------------------
-- Every roll lands in the middle of the screen (QUICK off): a face-down card drops in the moment ROLL is
-- pressed, turns over when the server answers, then flies off toward the pull feed. Nothing is dimmed or
-- blocked, so the next roll simply replaces it. The size of the moment follows the pull's rarity number
-- (RevealPolicy.Heat): a soft glow, then sparks, then a swell + rays + a callout, then a screen flash.
-- Plain frames and tweens only, like the rest of the reveals.
local stageArea: Frame
local show: any = nil -- the show on stage: { Root, RootScale, Row, Slots, Revealed }
local preloaded: { Instance } = {} -- unparented ImageLabels that keep the pool's art loaded

-- Per card count: { x offset in card widths, size, tilt }. The rarest card of a batch takes slot 1.
local FAN = {
	{ { 0, 1, 0 } },
	{ { -0.56, 0.94, -4 }, { 0.56, 0.94, 4 } },
	{ { 0, 1, 0 }, { -1, 0.84, -6 }, { 1, 0.84, 6 } },
}
local CENTRE = Vector2.new(0.5, 0.5)

local function placeStage()
	local height = gui.AbsoluteSize.Y
	local short = height > 0 and height < 500
	-- Between the top HUD strip and the avatar's shoulders; a little lower and larger on a phone.
	stageArea.Position = UDim2.fromScale(0.5, if short then 0.43 else 0.38)
	stageArea.Size = UDim2.fromScale(1, if short then 0.4 else 0.34)
end

local function stageOpen(): boolean
	if gui == nil or running or State.InBattle or State.Meta.QuickRoll == true then
		return false
	end
	return not (Reveal.Muted and Reveal.Muted())
end

-- Sends the show off: toward the pull feed when its time is up, or out of the way of a newer roll.
local function leaveStage(replaced: boolean?)
	local old = show
	if old == nil then
		return
	end
	show = nil
	if old.EndHold then old.EndHold() end
	if old.ReleaseSecret then old.ReleaseSecret() end
	local seconds = if replaced then 0.1 else 0.24
	if not replaced then
		Kit.tween(old.Root, seconds, { Position = UDim2.fromScale(0.86, 0.62) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	Kit.tween(old.RootScale, seconds, { Scale = if replaced then 0.55 else 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(seconds, function()
		old.Root:Destroy()
	end)
end

local function newShow(count: number)
	leaveStage(true)
	placeStage()
	local root = Kit.new("Frame", {
		Name = "Show",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = stageArea,
	})
	-- One card wide and as tall as the stage: the slots fan out from it.
	local row = Kit.new("Frame", {
		Name = "Row",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = root,
	}, { Kit.aspect(0.72, Enum.DominantAxis.Height) })
	local item = { Root = root, RootScale = Kit.new("UIScale", { Scale = 1, Parent = root }), Row = row, Slots = {}, Revealed = false }
	for i, spec in FAN[count] do
		local frame = Kit.new("Frame", {
			Name = "Slot",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5 + spec[1], 0.5),
			Size = UDim2.fromScale(spec[2], spec[2]),
			Rotation = spec[3],
			BackgroundTransparency = 1,
			ZIndex = if i == 1 then 3 else 2,
			Parent = row,
		})
		local flip = Kit.new("Frame", {
			Name = "Flip",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		local back = CardView.back()
		unlock(back)
		back.Parent = flip
		local scale = Kit.new("UIScale", { Scale = 0, Parent = frame })
		Kit.tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
		-- It rocks while the answer is on its way.
		frame.Rotation = spec[3] - 4
		local wobble = TweenService:Create(
			frame,
			TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = spec[3] + 4 }
		)
		wobble:Play()
		item.Slots[i] = { Frame = frame, Flip = flip, Back = back, Scale = scale, Tilt = spec[3], Wobble = wobble }
	end
	show = item
	return item
end

local function stageGlow(item, color: Color3, heat: number)
	for i, spec in { { 1.75, 0.9 }, { 1.35, 0.86 }, { 1, 0.8 } } do
		local circle = Kit.new("Frame", {
			Name = "Glow",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(spec[1], spec[1]),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = item.Root,
		}, { Kit.corner(UDim.new(1, 0)), Kit.aspect(1, Enum.DominantAxis.Height) })
		Kit.tween(circle, 0.18 + i * 0.05, { BackgroundTransparency = spec[2] - heat * 0.035 })
	end
end

local function stageCaption(item, text: string, color: Color3, gradient: ColorSequence?)
	local label = Kit.label({
		Name = "Caption",
		Text = text,
		Font = Theme.Font.Display,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromScale(0.7, 0.17),
		ZIndex = 8,
		Parent = item.Root,
	}, 44)
	Kit.textStroke(Color3.new(0, 0, 0), 3, 0.1).Parent = label
	if gradient then
		Kit.gradient(gradient, 0).Parent = label
	end
	local scale = Kit.new("UIScale", { Scale = 0.4, Parent = label })
	Kit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Turns one slot over to its pull; `onFace(heat)` runs the moment its face shows.
local function turnOver(slot, result, delay: number, onFace: ((number) -> ())?)
	local card = Cards.Get(result.CardId)
	local borderId = result.Border or "Normal"
	local border = Borders.Get(borderId)
	local special = Borders.Index(borderId) >= 2
	local heat = RevealPolicy.Heat(Cards.Rarity(card.Id, borderId))
	local color = if special then border.Color else CardView.Glow(card.Id)
	local owner = show
	local leadSpecial = special and onFace ~= nil
	local fakeout = leadSpecial and Director.Fakeout(borderId)
	local tease = if fakeout then Borders.Get("Gold") else border
	local swell = if heat >= 2 then 0.14 + heat * 0.04 else 0
	-- The art starts loading under the face-down card straight away, so the face never turns up empty.
	local warm = if card.Image
		then Kit.new("ImageLabel", {
			Name = "Warm",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Image = card.Image,
			ZIndex = 0,
			Parent = slot.Flip,
		})
		else nil
	task.spawn(function()
		if delay > 0 then
			task.wait(delay)
		end
		if show ~= owner or slot.Frame.Parent == nil then return end
		if leadSpecial and borderId == "Secret" then owner.ReleaseSecret = Director.SecretSession(owner.Root) end
		if leadSpecial then owner.EndHold = Director.Hold(slot.Frame, borderId, tease.Color, math.max(0.15, swell)) end
		slot.Wobble:Cancel()
		slot.Frame.Rotation = slot.Tilt
		-- The tease: the back takes the pull's colour, and a rare one swells before it turns.
		if heat >= 1 then
			local stroke = slot.Back:FindFirstChild("BackStroke")
			if stroke then
				stroke.Color = if special then Color3.new(1, 1, 1) else color
				stroke.Thickness = 5 + heat
				stroke.Transparency = 0
				if special then
					Kit.gradient(tease.Gradient, 45).Parent = stroke
				end
			end
			local emblem = slot.Back:FindFirstChild("Emblem")
			if emblem then
				emblem.BackgroundColor3 = color
				emblem.BackgroundTransparency = 0.25
			end
		end
		if swell > 0 then
			if not special then Sfx.Play("Riser", 1.15 + heat * 0.15) end
			Kit.tween(slot.Scale, swell, { Scale = 1.1 + heat * 0.03 }, Enum.EasingStyle.Sine).Completed:Wait()
			if slot.Frame.Parent == nil then
				return
			end
		end
		-- A beat longer, at most, for art that is still on its way.
		local deadline = os.clock() + 0.35
		while warm and not warm.IsLoaded and os.clock() < deadline and slot.Frame.Parent do
			task.wait()
		end
		if show ~= owner or not slot.Frame.Parent then return end
		if fakeout then
			Director.Crack(slot.Back)
			task.wait(0.14)
			if show ~= owner then return end
		end
		if leadSpecial and owner.EndHold then owner.EndHold() end
		Sfx.Play("Flip", 1.1 + math.random() * 0.2)
		Kit.tween(slot.Flip, 0.07, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		if leadSpecial and borderId == "Secret" and show == owner then Sfx.SecretDip() end
		if show ~= owner or slot.Frame.Parent == nil then return end
		if leadSpecial then Director.Snap(slot.Frame, borderId) end
		slot.Back:Destroy()
		local front = RollCard.new(card.Id, borderId, RollCard.IsNew(result))
		unlock(front)
		front.Parent = slot.Flip
		if warm then
			warm:Destroy()
		end
		Kit.tween(slot.Flip, 0.13, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
		slot.Scale.Scale = 1.18 + heat * 0.07
		Kit.tween(slot.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		if borderId ~= "Secret" then Sfx.Sting(border.Sting, true) end
		if special then
			borderSting(borderId)
		end
		if heat >= 1 then
			Effects.Sparks(slot.Frame, color, 4 + heat * 6, 0.8 + heat * 0.25)
		end
		if heat >= 3 then
			Effects.Shimmer(front, 1)
		end
		if onFace then
			onFace(heat)
		end
	end)
end

-- Shows a click's cards (rarest first, at most three) on the stage, reusing the face-down card that
-- Reveal.Anticipate dropped when it fits.
local function stage(cards)
	if not stageOpen() then
		leaveStage(true)
		return
	end
	local count = math.min(3, #cards)
	local item = show
	local lead = 0
	if item == nil or item.Revealed or #item.Slots ~= count then
		item = newShow(count)
		lead = 0.12 -- let the back land before it turns
	end
	item.Revealed = true
	-- The backdrop and callout follow the rarest card of the batch, the moment it turns face up.
	local best = cards[1]
	local card = Cards.Get(best.CardId)
	local borderId = best.Border or "Normal"
	local border = Borders.Get(borderId)
	local special = Borders.Index(borderId) >= 2
	local color = if special then border.Color else CardView.Glow(card.Id)
	local function onFace(heat: number)
		if show ~= item then
			return
		end
		stageGlow(item, color, heat)
		if heat >= 2 then
			local rays = Effects.Rays(item.Root, color, 5 + heat * 2)
			rays.ZIndex = 2
			if special then
				stageCaption(item, `{string.upper(border.Name)} BORDER!`, Color3.new(1, 1, 1), border.Gradient)
			elseif card.SkyOneIn then
				stageCaption(item, "CELESTIAL PULL!", color)
			else
				stageCaption(item, "RARE PULL!", color)
			end
		end
		if heat >= 3 then
			if borderId == "Secret" then Director.Flash(item.Root, color, 0.45) else Effects.Flash(gui, color, 0.45, 0.6) end
			Effects.Shake(item.Row, 7, 0.35)
		end
		task.delay(RevealPolicy.HeatHold[heat], function()
			if show == item then
				leaveStage(false)
			end
		end)
	end
	for i, slot in item.Slots do
		turnOver(slot, cards[i], lead + (i - 1) * 0.07, if i == 1 then onFace else nil)
	end
	-- Whatever happens, a show never outstays its welcome.
	task.delay(6, function()
		if show == item then
			leaveStage(false)
		end
	end)
end

-- ROLL was pressed: a face-down card drops onto the stage at once, before the server answers.
function Reveal.Anticipate(count: number?)
	if not stageOpen() then
		return
	end
	local item = newShow(math.clamp(count or 1, 1, 3))
	-- A refused or lost roll never leaves a face-down card behind.
	task.delay(4, function()
		if show == item and not item.Revealed then
			leaveStage(true)
		end
	end)
end

function Reveal.CancelAnticipate()
	if show and not show.Revealed then
		leaveStage(true)
	end
end

function Reveal.Init(playerGui: Instance)
	task.spawn(VfxAssets.Preload)
	task.spawn(Sfx.Preload)
	gui = Kit.screenGui("RevealGui", 20, playerGui)
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea = false

	stageArea = Kit.new("Frame", {
		Name = "Stage",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(1, 0.34),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- The normal pool's art loads in the background, so a card never turns over to an empty frame the
	-- first time it is rolled. (Sky cards are rare and load when they appear.)
	task.spawn(function()
		for _, card in Cards.List do
			if card.Image and not card.SkyOneIn then
				table.insert(preloaded, Kit.new("ImageLabel", { Image = card.Image }))
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(preloaded)
		end)
	end)

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
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		placeToasts()
		placeStage()
	end)
	placeToasts()
	placeStage()
end

function Reveal.IsBusy(): boolean
	return running or #queue > 0
end

-- Full reveal. Queued, so several can arrive at once (e.g. Auto Roll hits).
-- Drops every queued full reveal (SKIP ALL); their OnDone still runs so callers carry on.
function Reveal.SkipQueue()
	local dropped = queue
	queue = {}
	for _, item in dropped do
		if item.OnDone then
			task.spawn(item.OnDone)
		end
	end
end

-- `batch` (optional): a pack's cinematic run { Index, Total, Skipped } so SKIP ALL can stop it.
function Reveal.Full(result, onDone: (() -> ())?, batch: { Index: number, Total: number, Skipped: boolean? }?)
	leaveStage(true) -- the full show takes the screen
	table.insert(queue, { Result = result, OnDone = onDone, Batch = batch })
	pump()
end

-- Fast pop near the buttons; saved threshold / duplicate choices select the full show.
function Reveal.Quick(result, batchSize: number?)
	local card = Cards.Get(result.CardId)
	if card == nil then
		return
	end
	local tier = Borders.RevealTier(result.Border)
	local borderId = result.Border or "Normal"
	if RevealPolicy.Eligible(result,State.Meta) then
		Reveal.Full(result)
		return
	end
	if running or (Reveal.Muted and Reveal.Muted()) then
		return -- a full reveal or a panel is on screen: the pull still lands in the feed, without a pop over it
	end
	if not batchSize and gui.AbsoluteSize.Y < 540 and result.Outcome ~= "New" and result.Outcome ~= "Star" and borderId == "Normal" then
		return -- routine Base copies already appear in the phone's feed
	end

	placeToasts()
	local limit = math.clamp(batchSize or 2, 2, 3)
	if batchSize then
		local size = toastArea.Size
		toastArea.Size = UDim2.fromOffset(size.Y.Offset * .72 * limit + 8 * (limit - 1), size.Y.Offset)
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
	local view = RollCard.new(card.Id, borderId, RollCard.IsNew(result))
	view.Parent = slot

	if borderId ~= "Normal" then
		borderSting(borderId)
		if borderId == "Secret" then
			Director.SecretSession(slot)
			task.spawn(function()
				Sfx.SecretDip()
				if slot.Parent then Director.Snap(slot, borderId) end
			end)
		else
			Director.Snap(slot, borderId)
		end
	end

	Kit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	Sfx.Play("Flip", 1.1 + math.random() * 0.2)
	if borderId ~= "Secret" then Sfx.Sting(tier.Sting, true) end
	if tier.Index >= 4 then
		if borderId == "Secret" then Director.Flash(slot, tier.Color, 0.35) else Effects.Flash(gui, tier.Color, 0.35, 0.65) end
		Effects.Sparks(slot, tier.Color, 10, 0.9)
	end
	if tier.Index >= 5 then
		Effects.Shimmer(view, 1)
	end

	-- Keep the tray bounded: two cards fit without spreading back across the avatar.
	local toasts = {}
	for _, child in toastArea:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - limit do
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

-- One click is one visual batch: rarest qualifying reveal first, otherwise its cards on the centre stage
-- (or, with QUICK on, in the compact tray on the right).
local lastQuickBatch = -math.huge
function Reveal.Batch(result, onDone: (() -> ())?): boolean
	if not (Reveal.Muted and Reveal.Muted()) then Sfx.RollWhoosh() end
	local cards = { result }
	for _, extra in result.Extra or {} do table.insert(cards, extra) end
	table.sort(cards, function(a, b) return Cards.Rarity(a.CardId, a.Border) > Cards.Rarity(b.CardId, b.Border) end)
	local full = {}
	for _, card in cards do if RevealPolicy.Eligible(card, State.Meta) then table.insert(full, card) end end
	if #full > 0 then
		for i, card in full do
			Reveal.Full(card, if i == #full then onDone else nil, { Index = i, Total = #full })
		end
		return true
	end
	if State.Meta.QuickRoll ~= true then
		stage(cards)
		return false
	end
	leaveStage(true)
	-- The feed records every pull; a fast auto batch must not replace a just-arrived tray mid-entry.
	if os.clock()-lastQuickBatch < 1.4 then return false end
	lastQuickBatch = os.clock()
	for i = 1, math.min(3, #cards) do Reveal.Quick(cards[i], if #cards > 1 then #cards else nil) end
	return false
end

return Reveal
