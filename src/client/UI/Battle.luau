--!nonstrict
-- Battle screen. The fight runs on the server; this draws the snapshots it streams
-- (HP, shields, action bars, energy) and animates its events (hits, heals, warnings).
-- The player only taps charged cards to fire Ultimates, toggles Auto and speed, or gives up.
-- Plain Frames + tweens and one 3D boss in a ViewportFrame, so it stays cheap on phones.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Bosses = require(Shared.Bosses)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Tower = require(Shared.Tower)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Modal = require(script.Parent.Modal)
local Effects = require(script.Parent.Effects)
local ModelView = require(script.Parent.ModelView)
local CardView = require(script.Parent.CardView)
local RewardReveal = require(script.Parent.RewardReveal)
local Abilities = require(script.Parent.Abilities)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local Battle = {}

export type Hooks = {
	OnStart: () -> (), -- battle screen opened (hide the roll HUD)
	OnEnd: () -> (), -- back to the hub
}

local hooks: Hooks
local gui: ScreenGui
local backdrop: any -- children read by name
local particles: Frame
local stage: Frame -- everything inside the safe area
local fxLayer: Frame -- bolts, slashes and cut-ins, positioned in screen pixels
local bossName: TextLabel
local bossChip: any
local bossHpFill: Frame
local bossHpTrail: Frame
local bossBarrier: Frame
local bossHpText: TextLabel
local bossGauge: Frame
local bossStatus: TextLabel
local bossHolder: Frame
local arena: any -- the boss's platform (children read by name)
local barrierRing: Frame
local bossView = nil -- ModelView
local timerLabel: TextLabel
local calloutLabel: TextLabel
local warnBanner: Frame
local warnLabel: TextLabel
local hintLabel: TextLabel
local frontRow: Frame
local backRow: Frame
local autoButton: any -- children read by name
local speedButton: any
local forfeitButton: any
local intro: Frame
local results: Frame

local tiles = {} -- [unitId] = tile table (see makeTile)
local current = nil -- the fight on screen
local lastSnap = nil
local calloutToken = 0
local hintToken = 0
local warnToken = 0
local trailTokens = {} -- [fill] = number
local ultTapped = {} -- [unitId] = os.clock(); stops double taps until the server answers

local FLUSH_SPACING = 0.14 -- spread a batch of events over about one server flush
local BOLT_TIME = 0.14
local SHIELD_COLOR = Color3.fromRGB(150, 210, 255)
local ICE_COLOR = Color3.fromRGB(150, 230, 255)

local REASONS = {
	NoAttack = "Put at least one Attack card in your deck first",
	Locked = "Beat the previous fight first",
	InBattle = "Already in a fight",
	TooFast = "Slow down a little",
	Loading = "Still loading your cards",
}

local STATUS = { B = "BURN", Z = "FROZEN", T = "TAUNT", U = "BUFFED", S = "SLOWED", G = "GUARDED", I = "SAFE" }
local BOSS_STATUS = {
	D = "DEF DOWN",
	A = "ATK DOWN",
	S = "SLOWED",
	V = "VULNERABLE",
	B = "BURNING",
	E = "ENRAGED",
	W = "CHARGING",
	R = "BARRIER",
}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function hint(text: string)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintLabel.TextTransparency = 0
	task.delay(2.2, function()
		if token == hintToken then
			Kit.tween(hintLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function callout(text: string, color: Color3, seconds: number?)
	calloutToken += 1
	local token = calloutToken
	calloutLabel.Text = text
	calloutLabel.TextColor3 = color
	calloutLabel.TextTransparency = 0
	local scale = calloutLabel:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.5
		Kit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(seconds or 1.4, function()
		if token == calloutToken then
			Kit.tween(calloutLabel, 0.3, { TextTransparency = 1 })
		end
	end)
end

-- Number or word that pops, floats up off a tile or the boss, and fades.
local function float(parent: GuiObject?, text: string, color: Color3, big: boolean?)
	if parent == nil or parent.Parent == nil then
		return
	end
	local label = Kit.label({
		Name = "Float",
		Text = text,
		Font = Theme.Font.Display,
		TextColor3 = if big then Color3.new(1, 1, 1) else color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.25 + math.random() * 0.5, 0.42),
		Size = UDim2.fromScale(if big then 1.4 else 1, if big then 0.6 else 0.4),
		Rotation = math.random(-6, 6),
		ZIndex = 40,
		Parent = parent,
	}, if big then 58 else 34)
	Kit.textStroke(Color3.fromRGB(20, 8, 30), if big then 3.5 else 2.5, 0).Parent = label
	if big then
		-- Crits: bright top fading into their colour, popping in from oversized.
		Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 252, 220), color), 90).Parent = label
	end
	local scale = Kit.new("UIScale", { Scale = if big then 1.9 else 0.3, Parent = label })
	Kit.tween(scale, if big then 0.22 else 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.tween(label, 0.9, { Position = label.Position - UDim2.fromScale(0, 0.5) }, Enum.EasingStyle.Quad)
	task.delay(0.5, function()
		if label.Parent then
			Kit.tween(label, 0.4, { TextTransparency = 1 }).Completed:Connect(function()
				label:Destroy()
			end)
		end
	end)
end

-- A big pill over a card naming the ability it just used, in its slot's colour (SKILL blue ...).
local function castTag(tile, name: string, slot: string)
	local info = Abilities.Slots[slot] or Abilities.Slots.Skill
	local old = tile.Slot:FindFirstChild("CastTag")
	if old then
		old:Destroy()
	end
	local tag = Kit.new("Frame", {
		Name = "CastTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1.1, 0, 0, 30),
		BackgroundColor3 = info.Color:Lerp(Color3.new(0, 0, 0), 0.35),
		ZIndex = 30,
		Parent = tile.Slot,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(info.Color:Lerp(Color3.new(1, 1, 1), 0.3), 2, 0) })
	local label = Kit.label({
		Text = `{info.Label} · {name}`,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.78),
		ZIndex = 31,
		Parent = tag,
	}, 20)
	Kit.textStroke(Color3.fromRGB(16, 8, 30), 2, 0).Parent = label
	local scale = Kit.new("UIScale", { Scale = 0.4, Parent = tag })
	Kit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.4, function()
		if tag.Parent then
			Kit.tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
				tag:Destroy()
			end)
		end
	end)
end

local cardInfo: Frame? = nil

-- Tapping a card mid-fight shows what it does; tapping anywhere closes it.
local function showCardInfo(cardId: string)
	if cardInfo then
		cardInfo:Destroy()
	end
	local card = Cards.Get(cardId)
	if card == nil then
		return
	end
	local entry = State.Cards[cardId]
	local tier = Rarity.Get(Cards.FusedRarity(card, entry and entry.Fusion))
	local cover = Kit.new("TextButton", {
		Name = "CardInfo",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 60,
		Parent = gui,
	})
	cardInfo = cover
	local panel = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 460, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 61,
		Parent = cover,
	}, {
		Kit.corner(UDim.new(0, 18)),
		Kit.gradient(ColorSequence.new(Theme.Color.TileTop:Lerp(tier.Dark, 0.35), Theme.Color.TileBottom), 90),
		Kit.stroke(tier.Color, 3, 0),
		Kit.padding(12),
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }),
	})
	local title = Kit.new("TextLabel", {
		LayoutOrder = 0,
		Text = `{card.Name}  <font color="#{tier.Color:ToHex()}">{string.upper(tier.Name)}</font>`,
		RichText = true,
		Font = Theme.Font.Display,
		TextSize = 28,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		ZIndex = 62,
		Parent = panel,
	})
	Kit.textStroke(Color3.fromRGB(16, 8, 30), 2.5, 0).Parent = title
	Abilities.List(card, panel, 0, "small")
	for _, d in panel:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 62)
		end
	end
	local scale = Kit.new("UIScale", { Scale = 0.85, Parent = panel })
	Kit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	cover.Activated:Connect(function()
		cover:Destroy()
		if cardInfo == cover then
			cardInfo = nil
		end
	end)
end

local function bump(scale: UIScale?, amount: number)
	if scale then
		task.spawn(Effects.Pulse, scale, 1, 0.22, amount)
	end
end

-- Shakes can overlap, so the stage is put back at its home position afterwards.
local STAGE_HOME: UDim2
local function shakeStage(intensity: number, duration: number)
	Effects.Shake(stage, intensity, duration)
	task.delay(duration + 0.05, function()
		stage.Position = STAGE_HOME
	end)
end

-- Same idea for a card face inside its slot.
local function shakeCard(tile, intensity: number)
	Effects.Shake(tile.Card, intensity, 0.22)
	task.delay(0.27, function()
		tile.Card.Position = UDim2.fromScale(0.5, 0.5)
	end)
end

-- Bars --------------------------------------------------------------------------------------

local function bar(parent: Instance, name: string, y: number, height: number, color: Color3, trail: boolean?)
	local track = Kit.new("Frame", {
		Name = name,
		Position = UDim2.fromScale(0, y),
		Size = UDim2.fromScale(1, height),
		BackgroundColor3 = Color3.fromRGB(10, 8, 20),
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Parent = parent,
	}, { Kit.corner(UDim.new(1, 0)) })
	local trailFrame = nil
	if trail then
		trailFrame = Kit.new("Frame", {
			Name = "Trail",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 240, 220),
			BorderSizePixel = 0,
			Parent = track,
		}, { Kit.corner(UDim.new(1, 0)) })
	end
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)) })
	return track, fill, trailFrame
end

-- Damage drops the bar at once and the light trail follows a moment later; heals just grow.
local function setHp(fill: Frame, trail: Frame?, ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	local goal = UDim2.fromScale(ratio, 1)
	trailTokens[fill] = (trailTokens[fill] or 0) + 1
	local token = trailTokens[fill]
	if ratio < fill.Size.X.Scale - 0.0005 then
		Kit.tween(fill, 0.1, { Size = goal })
		if trail then
			task.delay(0.35, function()
				if trailTokens[fill] == token then
					Kit.tween(trail, 0.45, { Size = goal }, Enum.EasingStyle.Quad)
				end
			end)
		end
	else
		Kit.tween(fill, 0.25, { Size = goal })
		if trail then
			Kit.tween(trail, 0.25, { Size = goal })
		end
	end
end

local function hpColor(ratio: number): Color3
	if ratio > 0.5 then
		return Theme.Color.Quick
	elseif ratio > 0.25 then
		return Theme.Color.Gold
	end
	return Theme.Color.Danger
end

-- Screen-space effects --------------------------------------------------------------------------

local function centerOf(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2 - fxLayer.AbsolutePosition
end

local function ring(at: Vector2, color: Color3, size: number)
	local circle = Kit.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = fxLayer,
	}, { Kit.corner(UDim.new(1, 0)) })
	local stroke = Kit.stroke(color, 4, 0)
	stroke.Parent = circle
	Kit.tween(circle, 0.32, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quad)
	Kit.tween(stroke, 0.32, { Transparency = 1, Thickness = 1 }).Completed:Connect(function()
		circle:Destroy()
	end)
end

-- A glowing streak from a card to the boss, ending in an impact ring.
local function bolt(from: GuiObject, to: GuiObject, color: Color3, thick: number?)
	if Theme.FxLow and math.random() < 0.5 then
		return
	end
	local a, b = centerOf(from), centerOf(to)
	b += Vector2.new(math.random(-18, 18), math.random(-22, 10))
	local delta = b - a
	local streak = Kit.new("Frame", {
		Name = "Bolt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(a.X, a.Y),
		Size = UDim2.fromOffset(18, thick or 6),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = fxLayer,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.2),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
	Kit.tween(streak, BOLT_TIME, {
		Position = UDim2.fromOffset(b.X, b.Y),
		Size = UDim2.fromOffset(46, thick or 6),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		streak:Destroy()
		ring(b, color, 70)
	end)
end

-- Two crossing slashes over a card the boss hits.
local function slash(tile, color: Color3)
	for i, angle in { 32, -28 } do
		local line = Kit.new("Frame", {
			Name = "Slash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 0, 4),
			Rotation = angle,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = tile.Card,
		}, { Kit.corner(UDim.new(1, 0)) })
		task.delay((i - 1) * 0.06, function()
			Kit.tween(line, 0.12, { Size = UDim2.new(1.25, 0, 0, 4) }, Enum.EasingStyle.Quad)
			task.delay(0.12, function()
				Kit.tween(line, 0.2, { BackgroundTransparency = 1 }).Completed:Connect(function()
					line:Destroy()
				end)
			end)
		end)
	end
end

local function glow(tile, color: Color3)
	local flash = tile.Flash
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.45
	Kit.tween(flash, 0.35, { BackgroundTransparency = 1 })
end

-- A band across the screen naming an Ultimate.
local function cutIn(cardId: string, ultName: string)
	local card = Cards.Get(cardId)
	if card == nil then
		return
	end
	local tier = Rarity.Get(card.Rarity)
	local band = Kit.new("Frame", {
		Name = "CutIn",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.8, 0.46),
		Size = UDim2.fromScale(1.5, 0.17),
		Rotation = -5,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 70,
		Parent = fxLayer,
	}, { Kit.gradient(ColorSequence.new(tier.Dark, card.Accent), 0) })
	local portrait = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.33, 0.5),
		Size = UDim2.fromScale(0.1, 1.15),
		BackgroundColor3 = card.Accent,
		ZIndex = 71,
		Parent = band,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.aspect(1, Enum.DominantAxis.Height),
		Kit.stroke(tier.Color, 4, 0),
	})
	Kit.label({
		Text = card.Glyph,
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.5),
		ZIndex = 72,
		Parent = portrait,
	}, 60)
	local name = Kit.label({
		Text = string.upper(ultName),
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.4, 0.12),
		Size = UDim2.fromScale(0.42, 0.55),
		ZIndex = 72,
		Parent = band,
	}, 64)
	Kit.textStroke(Color3.new(0, 0, 0), 3, 0.1).Parent = name
	Kit.label({
		Text = `{card.Name} · ULTIMATE`,
		Font = Theme.Font.Heavy,
		TextColor3 = tier.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.4, 0.66),
		Size = UDim2.fromScale(0.42, 0.24),
		ZIndex = 72,
		Parent = band,
	}, 26)
	Kit.tween(band, 0.22, { Position = UDim2.fromScale(0.5, 0.46) }, Enum.EasingStyle.Quart).Completed:Connect(function()
		task.delay(0.55, function()
			Kit.tween(band, 0.2, { Position = UDim2.fromScale(1.8, 0.46) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In).Completed
				:Connect(function()
					band:Destroy()
				end)
		end)
	end)
end

-- Tiles ---------------------------------------------------------------------------------------------

local function pulseForever(instance: Instance, goal: { [string]: any }, period: number)
	TweenService:Create(instance, TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

-- One card in the fight. Attack: portrait, name, status, HP / shield, action and energy bars.
-- Support: portrait, name, what it casts, action and energy bars (no HP).
local function makeTile(unit, order: number)
	local card = Cards.Get(unit.CardId)
	local stars = 0
	local entry = State.Cards[unit.CardId]
	if entry then
		stars = entry.Stars
	end
	local rarity = Cards.FusedRarity(card, entry and entry.Fusion)
	local tier = Rarity.Get(rarity)
	local isAttack = card.Type == "Attack"

	local slot = Kit.new("Frame", {
		Name = unit.Id,
		LayoutOrder = order,
		Size = UDim2.new(0.25, -8, 1, 0),
		BackgroundTransparency = 1,
	})
	local button = Kit.new("TextButton", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = slot,
	}, {
		Kit.corner(UDim.new(0.12, 0)),
		Kit.gradient(ColorSequence.new(tier.Dark:Lerp(Color3.new(1, 1, 1), 0.12), tier.Dark:Lerp(Color3.new(0, 0, 0), 0.35)), 90),
	})
	local stroke = Kit.stroke(Color3.new(1, 1, 1), 2, 0)
	local strokeGradient = Kit.gradient(Rarity.Gradient(rarity), 45)
	strokeGradient.Parent = stroke
	stroke.Parent = button
	if rarity == "Secret" then
		Effects.Spin(strokeGradient, 90)
	end
	local scale = Kit.new("UIScale", { Scale = 1, Parent = button })

	local portrait = Kit.new("Frame", {
		Name = "Portrait",
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.new(0.36, 0, 1, -8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = button,
	}, {
		Kit.corner(UDim.new(0.16, 0)),
		Kit.aspect(1, Enum.DominantAxis.Height),
		Kit.gradient(ColorSequence.new(card.Accent, tier.Dark), 120),
	})
	Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundColor3 = tier.Color,
		BackgroundTransparency = 0.7,
		Parent = portrait,
	}, { Kit.corner(UDim.new(1, 0)) })
	local art = CardView.Art(unit.CardId, true, false)
	if art then
		-- A 2D illustration fills the portrait; the 3D figure is framed a little larger and lower.
		art.Size = if card.Image then UDim2.fromScale(1, 1) else UDim2.fromScale(1.25, 1.25)
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = if card.Image then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.58)
		art.Parent = portrait
	else
		Kit.label({
			Name = "Glyph",
			Text = card.Glyph,
			Font = Theme.Font.Display,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.85, 0.5),
			Parent = portrait,
		}, 40)
	end
	if stars > 0 then
		Kit.label({
			Name = "Stars",
			Text = string.rep("★", stars),
			Font = Theme.Font.Heavy,
			TextColor3 = Theme.Color.Gold,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(0.9, 0.2),
			ZIndex = 3,
			Parent = portrait,
		}, 14)
	end

	local info = Kit.new("Frame", {
		Name = "Info",
		Position = UDim2.new(0.4, 0, 0, 4),
		Size = UDim2.new(0.6, -6, 1, -8),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Kit.label({
		Name = "CardName",
		Text = card.Name,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, if isAttack then 0.24 else 0.32),
		Parent = info,
	}, 18)
	local status = Kit.label({
		Name = "Status",
		Text = if isAttack then "" else (if card.Abilities[1] then card.Abilities[1].Name else ""),
		Font = Theme.Font.Heavy,
		TextColor3 = if isAttack then Theme.Color.Gold else Theme.Color.Support,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0, if isAttack then 0.25 else 0.34),
		Size = UDim2.fromScale(1, if isAttack then 0.17 else 0.22),
		Parent = info,
	}, 13)

	local tile = {
		Slot = slot,
		Card = button,
		Scale = scale,
		Status = status,
		IsAttack = isAttack,
		MaxHP = unit.MaxHP,
		HasUlt = unit.Ultimate ~= nil,
		UltName = unit.Ultimate,
		Accent = card.Accent,
		TierColor = tier.Color,
		CardId = unit.CardId,
		BaseStatus = status.Text,
	}

	if isAttack then
		local hpTrack, hpFill, hpTrail = bar(info, "HP", 0.45, 0.25, Theme.Color.Quick, true)
		hpFill.Size = UDim2.fromScale(1, 1)
		tile.HpFill, tile.HpTrail = hpFill, hpTrail
		tile.Shield = Kit.new("Frame", {
			Name = "Shield",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = SHIELD_COLOR,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = hpTrack,
		}, { Kit.corner(UDim.new(1, 0)) })
		tile.HpText = Kit.label({
			Name = "HpText",
			Text = "",
			Font = Theme.Font.Heavy,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = hpTrack,
		}, 13)
		Kit.textStroke(Color3.new(0, 0, 0), 1, 0.25).Parent = tile.HpText
	end
	local _, gauge = bar(info, "Action", if isAttack then 0.76 else 0.62, if isAttack then 0.09 else 0.12, Color3.fromRGB(232, 228, 255))
	tile.Gauge = gauge
	if unit.Ultimate then
		local _, energy = bar(info, "Energy", if isAttack then 0.89 else 0.8, if isAttack then 0.09 else 0.12, Theme.Color.Gold)
		tile.Energy = energy
	end

	tile.Flash = Kit.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = button,
	}, { Kit.corner(UDim.new(0.12, 0)) })

	tile.Ready = Kit.new("Frame", {
		Name = "Ready",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Gold,
		BackgroundTransparency = 0.85,
		Visible = false,
		ZIndex = 10,
		Parent = button,
	}, { Kit.corner(UDim.new(0.12, 0)) })
	local readyStroke = Kit.stroke(Theme.Color.Gold, 3, 0)
	readyStroke.Parent = tile.Ready
	pulseForever(readyStroke, { Transparency = 0.75, Thickness = 5 }, 0.45)
	local readyLabel = Kit.label({
		Text = "TAP: ULTIMATE",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -14),
		Size = UDim2.new(0.9, 0, 0, 18),
		ZIndex = 11,
		Parent = tile.Ready,
	}, 16)
	Kit.textStroke(Color3.new(0, 0, 0), 2, 0.1).Parent = readyLabel

	tile.Warn = Kit.new("Frame", {
		Name = "Warn",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Danger,
		BackgroundTransparency = 0.78,
		Visible = false,
		ZIndex = 12,
		Parent = button,
	}, { Kit.corner(UDim.new(0.12, 0)) })
	local warnStroke = Kit.stroke(Theme.Color.Danger, 3, 0)
	warnStroke.Parent = tile.Warn
	pulseForever(warnStroke, { Transparency = 0.6 }, 0.2)
	Kit.label({
		Text = "!",
		Font = Theme.Font.Display,
		TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromScale(0.2, 0.5),
		ZIndex = 13,
		Parent = tile.Warn,
	}, 30)

	tile.Frozen = Kit.new("Frame", {
		Name = "Frozen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ICE_COLOR,
		BackgroundTransparency = 0.6,
		Visible = false,
		ZIndex = 13,
		Parent = button,
	}, { Kit.corner(UDim.new(0.12, 0)), Kit.stroke(Color3.new(1, 1, 1), 2, 0.3) })
	Kit.label({
		Text = "FROZEN",
		Font = Theme.Font.Display,
		TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.4),
		ZIndex = 14,
		Parent = tile.Frozen,
	}, 28)

	tile.Ko = Kit.new("Frame", {
		Name = "KO",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 8, 14),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 15,
		Parent = button,
	}, { Kit.corner(UDim.new(0.12, 0)) })
	Kit.label({
		Text = "KO",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Danger,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		ZIndex = 16,
		Parent = tile.Ko,
	}, 44)

	tiles[unit.Id] = tile

	button.Activated:Connect(function()
		if current == nil or current.Ended then
			return
		end
		-- Not charged (or no Ultimate): show what the card does instead.
		if not tile.HasUlt or not tile.Ready.Visible then
			showCardInfo(unit.CardId)
			return
		end
		ultTapped[unit.Id] = os.clock()
		tile.Ready.Visible = false
		Sfx.Play("Click", 1.3)
		Remotes.BattleInput:FireServer("Ultimate", unit.Id)
	end)
	return slot
end

-- Snapshots -------------------------------------------------------------------------------

local function flagWords(flags: string, names): string
	local words = {}
	for flag in string.gmatch(flags, ".") do
		if names[flag] then
			table.insert(words, names[flag])
		end
	end
	return table.concat(words, " · ")
end

local function applySnapshot(snap)
	if current == nil then
		return
	end
	lastSnap = snap
	local cost = current.Info.UltimateCost
	for id, s in snap.U do
		if id == "Boss" then
			local maxHP = current.Info.Boss.MaxHP
			setHp(bossHpFill, bossHpTrail, s.H / maxHP)
			local barrier = s.Bar or 0
			Kit.tween(bossBarrier, 0.2, { Size = UDim2.fromScale(math.min(1, barrier / maxHP * 8), 1) })
			bossHpText.Text = if barrier > 0
				then `{Kit.commas(s.H)} / {Kit.commas(maxHP)}   ·   BARRIER {Kit.commas(barrier)}`
				else `{Kit.commas(s.H)} / {Kit.commas(maxHP)}`
			barrierRing.Visible = barrier > 0
			Kit.tween(bossGauge, 0.15, { Size = UDim2.fromScale(s.G, 1) }, Enum.EasingStyle.Linear)
			bossStatus.Text = flagWords(s.F, BOSS_STATUS)
		else
			local tile = tiles[id]
			if tile then
				local alive = true
				if tile.IsAttack and s.H then
					local ratio = s.H / tile.MaxHP
					setHp(tile.HpFill, tile.HpTrail, ratio)
					tile.HpFill.BackgroundColor3 = hpColor(ratio)
					tile.Shield.Size = UDim2.fromScale(math.min(1, (s.S or 0) / tile.MaxHP), 1)
					tile.HpText.Text = if (s.S or 0) > 0 then `{Kit.commas(s.H)} +{Kit.commas(s.S)}` else Kit.commas(s.H)
					alive = s.H > 0
					tile.Status.Text = flagWords(s.F, STATUS)
					tile.Status.TextColor3 = if string.find(s.F, "B") then Theme.Color.Roll
						elseif string.find(s.F, "Z") then ICE_COLOR
						else Theme.Color.Gold
				else
					local words = flagWords(s.F, STATUS)
					tile.Status.Text = if words ~= "" then words else tile.BaseStatus
				end
				local gaugeGoal = UDim2.fromScale(s.G, 1)
				if s.G < tile.Gauge.Size.X.Scale then
					tile.Gauge.Size = gaugeGoal -- it just acted: snap back
				else
					Kit.tween(tile.Gauge, 0.15, { Size = gaugeGoal }, Enum.EasingStyle.Linear)
				end
				if tile.Energy then
					Kit.tween(tile.Energy, 0.15, { Size = UDim2.fromScale(s.E / cost, 1) })
				end
				if tile.Ko.Visible ~= not alive then
					tile.Ko.Visible = not alive
					tile.Card.BackgroundTransparency = if alive then 0 else 0.4
				end
				tile.Frozen.Visible = alive and string.find(s.F, "Z") ~= nil
				local tapped = ultTapped[id]
				local waiting = tapped ~= nil and os.clock() - tapped < 0.6
				tile.Ready.Visible = alive and tile.HasUlt and s.E >= cost and not waiting and not current.AutoUlt
			end
		end
	end
	timerLabel.Text = clock(current.Info.TimeLimit - snap.T)
	timerLabel.TextColor3 = if current.Info.TimeLimit - snap.T <= 30 then Theme.Color.Danger else Theme.Color.Text
end

-- Events ------------------------------------------------------------------------------------

local function targetFrame(id: string): GuiObject?
	if id == "Boss" then
		return bossHolder
	end
	local tile = tiles[id]
	return if tile then tile.Card else nil
end

local function showWarning(event)
	warnToken += 1
	local token = warnToken
	for _, id in event.T do
		local tile = tiles[id]
		if tile then
			tile.Warn.Visible = true
		end
	end
	local seconds = event.S / math.max(1, current.Speed)
	warnLabel.Text = `{string.upper(event.N)} INCOMING`
	warnBanner.Visible = true
	if bossView then
		bossView:Flash(Color3.fromRGB(255, 120, 120), seconds)
	end
	task.delay(seconds, function()
		if token ~= warnToken then
			return
		end
		warnBanner.Visible = false
		for _, tile in tiles do
			tile.Warn.Visible = false
		end
	end)
end

local function playEvent(event)
	if current == nil then
		return
	end
	local kind = event.K
	if kind == "Act" then
		if event.U == "Boss" then
			if bossView then
				bossView:Lunge()
			end
			if event.Ab == "Skill" then
				callout(event.N .. "!", Theme.Color.Danger, 1.1)
				shakeStage(9, 0.35)
				Sfx.Play("HeavyHit", 0.9)
			else
				Sfx.Play("Whoosh", 0.75)
			end
			return
		end
		local tile = tiles[event.U]
		if tile == nil then
			return
		end
		if event.Ab == "Ultimate" then
			cutIn(tile.CardId, event.N)
			Effects.Flash(gui, tile.TierColor, 0.45, 0.55)
			Sfx.Play("Ultimate")
			bump(tile.Scale, 0.15)
			if tile.IsAttack then
				for i = 1, 3 do
					task.delay(i * 0.05, bolt, tile.Card, bossHolder, tile.TierColor, 10)
				end
			end
		elseif tile.IsAttack then
			-- Lunge up and fire at the boss.
			tile.Card.Position = UDim2.new(0.5, 0, 0.5, 0)
			Kit.tween(tile.Card, 0.08, { Position = UDim2.new(0.5, 0, 0.5, -12) }, Enum.EasingStyle.Quad).Completed:Connect(function()
				Kit.tween(tile.Card, 0.18, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
			end)
			bolt(tile.Card, bossHolder, tile.Accent, if event.Ab == "Skill" then 9 else 6)
			Sfx.Play("Whoosh", if event.Ab == "Skill" then 1.05 else 1.25 + math.random() * 0.15)
			if event.Ab == "Skill" then
				castTag(tile, event.N, "Skill")
				task.delay(0.06, bolt, tile.Card, bossHolder, tile.TierColor, 9)
			end
		else
			-- Support: a soft glow and a lift as it casts.
			glow(tile, tile.Accent)
			bump(tile.Scale, 0.06)
			if event.Ab == "Skill" or event.Ab == "Opening" then
				castTag(tile, event.N, if event.Ab == "Opening" then "Basic" else "Skill")
			end
		end
	elseif kind == "Hit" or kind == "Burn" then
		local frame = targetFrame(event.T)
		if event.T == "Boss" then
			local color = if kind == "Burn" then Theme.Color.Roll
				elseif event.Bl then SHIELD_COLOR
				elseif event.C then Theme.Color.Gold
				else Color3.new(1, 1, 1)
			local text = if event.C then `{Kit.commas(event.A)}!` else Kit.commas(event.A)
			float(frame, text, color, event.C)
			if kind == "Hit" then
				if event.C then
					Sfx.Play("HeavyHit", 1.1)
				else
					Sfx.Play("Hit", 0.95 + math.random() * 0.2)
				end
			end
			if kind == "Hit" and bossView then
				bossView:Kick(if event.C then 1.1 else 0.45)
				bossView:Flash(if event.C then Color3.fromRGB(255, 220, 160) else Color3.fromRGB(255, 190, 190), 0.18)
				-- Sparks in the world's colour (embers, ice, void, lightning); crits burst and shake.
				local spark = current.BossColor:Lerp(Color3.new(1, 1, 1), 0.25)
				if event.C then
					ring(centerOf(bossHolder), Theme.Color.Gold, 140)
					Effects.Sparks(bossHolder, spark, 14, 0.7)
					Effects.Flash(gui, current.BossColor, 0.2, 0.85)
					shakeStage(5, 0.18)
				elseif math.random() < 0.5 then
					Effects.Sparks(bossHolder, spark, 4, 0.5)
				end
			end
		else
			local tile = tiles[event.T]
			if tile == nil then
				return
			end
			if event.A == 0 then
				float(tile.Card, "SAFE", Theme.Color.Gold)
			elseif kind == "Burn" then
				float(tile.Card, `-{Kit.commas(event.A)}`, Theme.Color.Roll)
			else
				float(tile.Card, `-{Kit.commas(event.A)}`, if event.Sh then SHIELD_COLOR else Theme.Color.Danger)
				Sfx.Play("Hit", 0.7)
				slash(tile, if event.Sh then SHIELD_COLOR else Color3.fromRGB(255, 90, 90))
				glow(tile, Theme.Color.Danger)
				shakeCard(tile, 6)
			end
		end
	elseif kind == "Heal" then
		local tile = tiles[event.T]
		if tile and event.A > 0 then
			float(tile.Card, `+{Kit.commas(event.A)}`, Theme.Color.Quick)
			glow(tile, Theme.Color.Quick)
			Sfx.Play("Heal")
		end
	elseif kind == "Shield" then
		local tile = tiles[event.T]
		if tile then
			Sfx.Play("Shield")
			float(tile.Card, `+{Kit.commas(event.A)}`, SHIELD_COLOR)
			glow(tile, SHIELD_COLOR)
		end
	elseif kind == "Buff" then
		local tile = tiles[event.U]
		if tile then
			local label = if event.Stat == "Guard" then "GUARD" else event.Stat
			float(tile.Card, `{label} +{math.floor(event.A * 100 + 0.5)}%`, Theme.Color.Gold)
		end
		for _, id in event.T or {} do
			local target = tiles[id]
			if target and target ~= tile then
				glow(target, Theme.Color.Gold)
			end
		end
	elseif kind == "Debuff" then
		local label = if event.Stat == "Vuln" then "DMG TAKEN" else event.Stat
		local sign = if event.Stat == "Vuln" then "+" else "-"
		float(bossHolder, `{label} {sign}{math.floor(event.A * 100 + 0.5)}%`, Theme.Color.Support)
	elseif kind == "Energy" then
		for _, id in event.T or {} do
			local tile = tiles[id]
			if tile and tile.HasUlt then
				glow(tile, Theme.Color.Gold)
			end
		end
	elseif kind == "Burned" then
		float(targetFrame(event.T), "BURN", Theme.Color.Roll)
	elseif kind == "Miss" then
		float(targetFrame(event.T), "MISS", Theme.Color.Muted, true)
	elseif kind == "KO" then
		local tile = tiles[event.T]
		if tile then
			float(tile.Card, "KO!", Theme.Color.Danger, true)
			shakeCard(tile, 10)
			Sfx.Play("KO")
		end
	elseif kind == "Revive" then
		local tile = tiles[event.T]
		if tile then
			float(tile.Card, "REVIVED", Theme.Color.Quick, true)
			glow(tile, Theme.Color.Quick)
		end
	elseif kind == "Taunt" then
		float(targetFrame(event.U), "TAUNT", Theme.Color.Gold)
	elseif kind == "Cleanse" then
		float(targetFrame(event.T), "CLEANSED", Theme.Color.Support)
	elseif kind == "Frozen" then
		local tile = tiles[event.T]
		if tile then
			float(tile.Card, "FROZEN", ICE_COLOR, true)
			glow(tile, ICE_COLOR)
			tile.Frozen.Visible = true
		end
	elseif kind == "Thaw" then
		local tile = tiles[event.U]
		if tile then
			float(tile.Card, "SKIPPED", ICE_COLOR)
			tile.Frozen.Visible = false
		end
	elseif kind == "Slow" then
		callout(`DECK SLOWED -{math.floor(event.A * 100 + 0.5)}% SPD`, ICE_COLOR, 1.5)
		for _, tile in tiles do
			glow(tile, ICE_COLOR)
		end
	elseif kind == "Barrier" then
		callout("NULL BARRIER! Break it with Skills and Ultimates", Color3.fromRGB(230, 130, 255), 2)
		if bossView then
			bossView:Flash(Color3.fromRGB(220, 140, 255), 0.5)
		end
	elseif kind == "Break" then
		callout("BARRIER BROKEN!", Theme.Color.Gold, 1.4)
		Effects.Sparks(bossHolder, Color3.fromRGB(230, 130, 255), 22, 0.9)
		Effects.Flash(gui, Color3.fromRGB(230, 130, 255), 0.35, 0.6)
		Sfx.Play("HeavyHit", 1.3)
	elseif kind == "Steal" then
		callout(`{string.upper(current.BossName)} STEALS YOUR BUFFS!`, Color3.fromRGB(230, 130, 255), 1.6)
	elseif kind == "Opening" then
		callout("SUPPORT OPENING!", Theme.Color.Support, 1.2)
	elseif kind == "Signature" then
		callout(event.N .. "!", Color3.fromRGB(240, 236, 255), 1.2)
		if event.T then
			float(targetFrame(event.T), "SAVED", Theme.Color.Gold, true)
		end
	elseif kind == "Warn" then
		showWarning(event)
	elseif kind == "Phase" then
		callout(`{string.upper(current.BossName)} UNLEASHES {string.upper(event.N)}!`, current.BossColor, 2)
		shakeStage(12, 0.5)
		Sfx.Play("Boom")
		if bossView then
			bossView:Flash(current.BossColor, 0.6)
		end
	elseif kind == "Enrage" then
		callout(`ENRAGED! +{math.floor(Config.Battle.EnrageATK * 100)}% ATK`, Theme.Color.Danger, 2)
		Effects.Flash(gui, Theme.Color.Danger, 0.5, 0.5)
		if bossView then
			bossView:SetTint(Color3.fromRGB(255, 170, 170))
		end
	end
end

local function playBatch(events)
	-- Spread the batch out so actions don't all land on the same frame, and let a card's
	-- hits land when its bolt reaches the boss.
	local groups = 0
	for _, event in events do
		if event.K == "Act" then
			groups += 1
		end
	end
	local spacing = if groups > 1 then FLUSH_SPACING / groups else 0
	local group = 0
	local shooter = nil
	for _, event in events do
		if event.K == "Act" then
			group += 1
			local tile = tiles[event.U]
			shooter = if tile and tile.IsAttack then event.U else nil
		end
		local delay = math.max(0, group - 1) * spacing
		if (event.K == "Hit" or event.K == "Burned") and event.T == "Boss" and event.U == shooter then
			delay += BOLT_TIME
		end
		if delay > 0 then
			task.delay(delay, playEvent, event)
		else
			playEvent(event)
		end
	end
end

-- Backdrop particles -----------------------------------------------------------------------------

local function spawnParticles(kind: string, color: Color3)
	for _, child in particles:GetChildren() do
		child:Destroy()
	end
	local count = if Theme.FxLow then 8 else 20
	for _ = 1, count do
		local size = math.random(3, 8)
		local x = math.random()
		local mote = Kit.new("Frame", {
			Name = "Mote",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			Rotation = math.random(0, 90),
			BackgroundColor3 = if math.random() < 0.25 then Color3.new(1, 1, 1) else color,
			BackgroundTransparency = 0.25 + math.random() * 0.35,
			BorderSizePixel = 0,
			Parent = particles,
		})
		if kind == "Snow" then
			Kit.corner(UDim.new(1, 0)).Parent = mote
		elseif kind == "Rain" then
			-- Long thin streaks, slanted, falling fast.
			mote.Size = UDim2.fromOffset(2, math.random(18, 34))
			mote.Rotation = 15
			mote.BackgroundColor3 = if math.random() < 0.15 then color else Color3.fromRGB(190, 205, 240)
		end
		local duration = 5 + math.random() * 6
		local from, to
		if kind == "Rain" then
			from, to = UDim2.fromScale(x + 0.1, -0.08), UDim2.fromScale(x - 0.15, 1.08)
			duration *= 0.18
			mote.Position = from
			local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, math.random() * duration)
			TweenService:Create(mote, info, { Position = to }):Play()
			continue
		elseif kind == "Snow" then
			from, to = UDim2.fromScale(x, -0.05), UDim2.fromScale(x + (math.random() - 0.5) * 0.2, 1.05)
		elseif kind == "Motes" then
			from = UDim2.fromScale(x, math.random())
			to = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, math.random())
			duration *= 0.8
		else
			from, to = UDim2.fromScale(x, 1.05), UDim2.fromScale(x + (math.random() - 0.5) * 0.25, -0.05)
		end
		mote.Position = from
		local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, kind == "Motes", math.random() * duration)
		TweenService:Create(mote, info, { Position = to, Rotation = mote.Rotation + 180 }):Play()
	end
end

-- Intro ------------------------------------------------------------------------------------------

local function playIntro(boss, subtitle: string, deckPower: number, seconds: number)
	for _, child in intro:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	intro.Visible = true
	intro.BackgroundTransparency = 0.35
	local function panel(fromLeft: boolean, color: Color3, deep: Color3, title: string, sub: string)
		local frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if fromLeft then -0.4 else 1.4, if fromLeft then 0.38 else 0.62),
			Size = UDim2.fromScale(0.7, 0.2),
			Rotation = -6,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = intro,
		}, { Kit.gradient(ColorSequence.new(deep, color), if fromLeft then 0 else 180) })
		local name = Kit.label({
			Text = title,
			Font = Theme.Font.Display,
			TextXAlignment = if fromLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.08, 0.1),
			Size = UDim2.fromScale(0.84, 0.55),
			Parent = frame,
		}, 56)
		Kit.textStroke(Color3.new(0, 0, 0), 3, 0.1).Parent = name
		Kit.label({
			Text = sub,
			Font = Theme.Font.Heavy,
			TextXAlignment = if fromLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.08, 0.66),
			Size = UDim2.fromScale(0.84, 0.26),
			Parent = frame,
		}, 24)
		Kit.tween(frame, 0.32, { Position = UDim2.fromScale(0.5, if fromLeft then 0.38 else 0.62) }, Enum.EasingStyle.Quart)
		return frame
	end
	local left = panel(true, Theme.Color.Accent, Theme.Color.AccentDeep, "YOUR DECK", `Deck Power {Kit.commas(deckPower)}`)
	local right = panel(false, boss.Accent, boss.Deep, string.upper(current.BossName), subtitle)
	local vs = Kit.label({
		Text = "VS",
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.16),
		ZIndex = 5,
		Parent = intro,
	}, 90)
	Kit.textStroke(Color3.new(0, 0, 0), 4, 0).Parent = vs
	local vsScale = Kit.new("UIScale", { Scale = 0, Parent = vs })
	task.delay(0.25, function()
		Kit.tween(vsScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		Sfx.Play("LowHit")
	end)
	task.delay(math.max(0.6, seconds - 0.7), function()
		Kit.tween(left, 0.25, { Position = UDim2.fromScale(-0.5, 0.38) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		Kit.tween(right, 0.25, { Position = UDim2.fromScale(1.5, 0.62) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		vs.Text = "FIGHT!"
		vs.TextColor3 = Color3.new(1, 1, 1)
		vsScale.Scale = 1.6
		Kit.tween(vsScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.tween(intro, 0.4, { BackgroundTransparency = 1 })
	end)
	task.delay(seconds, function()
		Kit.tween(vs, 0.2, { TextTransparency = 1 }).Completed:Connect(function()
			intro.Visible = false
		end)
	end)
end

-- Results ----------------------------------------------------------------------------------------

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local exit -- forward declarations
local startFight

local function showResults(summary)
	current.Ended = true
	warnBanner.Visible = false
	clearChildren(results)
	results.Visible = true
	results.BackgroundTransparency = 1
	Kit.tween(results, 0.3, { BackgroundTransparency = 0.25 })

	local titles = {
		Win = { "VICTORY!", Theme.Color.Gold },
		Lose = { "DEFEAT", Theme.Color.Danger },
		Timeout = { "TIME UP", Theme.Color.Danger },
		Forfeit = { "GAVE UP", Theme.Color.Muted },
	}
	local title = titles[summary.Result] or titles.Lose
	local rewards = summary.Rewards
	local hasRewards = rewards ~= nil and rewards.Results ~= nil and #rewards.Results > 0

	-- Kit panel: the same purple panel art and slanted title banner as every other screen.
	local panel = Kit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(if hasRewards then 0.9 else 0.55, 0.86),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = results,
	}, {
		Kit.corner(UDim.new(0, 22)),
		Kit.gradient(ColorSequence.new(Color3.fromRGB(62, 32, 128), Color3.fromRGB(22, 13, 50)), 90),
		Kit.stroke(title[2], 3, 0),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(if hasRewards then 1100 else 560, 620), MinSize = Vector2.new(300, 280) }),
	})
	Skin.Apply(panel, "Panel")
	local panelScale = Kit.new("UIScale", { Scale = 0.85, Parent = panel })
	Kit.tween(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	local banner = Modal.Banner(panel, title[1], 40)
	if summary.Result ~= "Win" then
		-- Lost fights get a red banner.
		local art = banner:FindFirstChild("Skin")
		if art then
			art.ImageColor3 = Color3.fromRGB(255, 130, 140)
		end
		banner.UIGradient.Color = ColorSequence.new(Theme.Color.Danger, Theme.Color.RollDeep)
	end
	local bannerScale = Kit.new("UIScale", { Scale = 0.4, Parent = banner })
	Kit.tween(bannerScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- Between the banner and the buttons: the summary (left) and, after a win, the reward fan (right).
	local content = Kit.new("Frame", {
		Name = "Content",
		Position = UDim2.new(0, 22, 0, 62),
		Size = UDim2.new(1, -44, 1, -144),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local list = Kit.new("ScrollingFrame", {
		Name = "Summary",
		Size = UDim2.new(if hasRewards then 0.38 else 1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		Kit.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 8) }),
	})
	local order = 0
	local function line(text: string, color: Color3, height: number, font: Enum.Font?)
		order += 1
		return Kit.label({
			Text = text,
			RichText = true,
			Font = font or Theme.Font.Heavy,
			TextColor3 = color,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			Parent = list,
		}, height)
	end

	-- Big-number stat tiles, two per row.
	local stats = nil
	local function stat(caption: string, value: string, edge: Color3, iconKey: string?, sub: string?)
		if stats == nil then
			order += 1
			stats = Kit.new("Frame", {
				Name = "Stats",
				LayoutOrder = order,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = list,
			}, {
				Kit.new("UIGridLayout", {
					CellSize = UDim2.new(0.5, -5, 0, 74),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
		end
		local icon = iconKey and Skin.Icons[iconKey]
		local hasIcon = icon ~= nil and icon ~= ""
		local chip = Kit.tile({ LayoutOrder = #stats:GetChildren(), Parent = stats }, edge)
		Kit.label({
			Text = caption,
			Font = Theme.Font.Heavy,
			TextColor3 = Color3.fromRGB(214, 200, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 7),
			Size = UDim2.new(1, -24, 0, 15),
			Parent = chip,
		}, 15)
		local valueLabel = Kit.label({
			Text = value,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 0, 22),
			Size = UDim2.new(1, if hasIcon then -58 else -24, 0, if sub then 32 else 42),
			Parent = chip,
		}, 34)
		Kit.textStroke(Color3.fromRGB(30, 12, 70), 2, 0).Parent = valueLabel
		if sub then
			Kit.label({
				Text = sub,
				RichText = true,
				Font = Theme.Font.Heavy,
				TextColor3 = Theme.Color.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 12, 1, -20),
				Size = UDim2.new(1, -24, 0, 14),
				Parent = chip,
			}, 14)
		end
		if hasIcon then
			Kit.new("ImageLabel", {
				Image = icon,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(42, 42),
				BackgroundTransparency = 1,
				Parent = chip,
			})
		end
	end

	local timeText = string.format("%d:%04.1f", summary.Time // 60, summary.Time % 60)
	local tower = current.Tower
	line(if tower then `{current.BossName} · Floor {tower.Floor}` else `{current.BossName} · {current.Difficulty}`, Theme.Color.Text, 24, Theme.Font.Heavy)
	if summary.Tower then
		State.ApplyTower(summary.Tower)
	end
	if summary.Result == "Win" then
		local notes = {}
		if tower then
			table.insert(notes, `Floor {tower.Floor} cleared!`)
		elseif summary.FirstClear then
			table.insert(notes, "First clear!")
		end
		if summary.NewBest and not summary.FirstClear and not tower then
			table.insert(notes, "New best time!")
		end
		if summary.SpeedUnlocked and not current.SpeedUnlocked then
			table.insert(notes, "2x speed unlocked!")
		end
		if #notes > 0 then
			line(table.concat(notes, "  ·  "), Theme.Color.Gold, 20)
		end
		stat("TIME", timeText, Theme.Color.Auto)
		if hasRewards then
			local floor = rewards.Floor and Rarity.Get(rewards.Floor)
			local floorText = if floor then `<font color="#{floor.Color:ToHex()}">{rewards.Floor}+</font> cards` else nil
			stat("REWARD ROLLS", tostring(#rewards.Results), Theme.Color.Gold, nil, floorText)
			stat("LUCK", string.format("%.2fx", rewards.Luck or 1), Theme.Color.Quick, "Luck")
			local bundle = rewards.Bundle
			if bundle and bundle.Shards and bundle.Shards > 0 then
				local potions = if bundle.Potions then Meta.Describe({ Potions = bundle.Potions }) else ""
				stat("SHARDS", `+{Kit.commas(bundle.Shards)}`, Theme.Color.Accent, "Shard", if potions ~= "" then `+ {potions}` else nil)
			elseif bundle then
				line(`Loot: {Meta.Describe(bundle)}`, Theme.Color.Gold, 20)
			end
			-- Gear drops get their own loud line (they go in the BAG).
			if bundle and (bundle.Artifacts or bundle.Accessories) then
				local gearText = Meta.Describe({ Artifacts = bundle.Artifacts, Accessories = bundle.Accessories })
				local isArtifact = bundle.Artifacts ~= nil
				line(`{if isArtifact then "ARTIFACT DROP!" else "NEW GEAR!"}  {gearText}`, if isArtifact then Color3.fromRGB(255, 120, 220) else Theme.Color.Gold, 24)
				task.delay(0.5, function()
					Sfx.Sting(if isArtifact then "Legendary" else "Epic", true)
					Effects.Sparks(panel, if isArtifact then Color3.fromRGB(255, 120, 220) else Theme.Color.Gold, 24, 1)
				end)
			end
			if rewards.Meta then
				State.ApplyMeta(rewards.Meta)
			end
		end
		Effects.Sparks(panel, Theme.Color.Gold, 30, 0.8)
		Sfx.Play("Victory")
	else
		Sfx.Play("Defeat")
		local left = summary.BossHP and summary.BossMaxHP and math.floor(summary.BossHP / summary.BossMaxHP * 100 + 0.5)
		stat("BOSS HP LEFT", `{left or "?"}%`, Theme.Color.Danger)
		stat("TIME", timeText, Theme.Color.Auto)
		line("Roll for stronger cards, tune your deck, then try again.", Theme.Color.Muted, 17, Theme.Font.Bold)
	end

	-- Damage dealt by each card, biggest first, as small bars.
	if summary.Units then
		local rows = {}
		local top = 1
		for id, u in summary.Units do
			table.insert(rows, { Id = id, Dealt = u.Dealt, Healed = u.Healed, Alive = u.Alive })
			top = math.max(top, u.Dealt, u.Healed)
		end
		table.sort(rows, function(a, b)
			if a.Dealt ~= b.Dealt then
				return a.Dealt > b.Dealt
			end
			return a.Healed > b.Healed
		end)
		local damageHeading = line("YOUR CARDS", Color3.fromRGB(214, 200, 255), 18)
		damageHeading.TextXAlignment = Enum.TextXAlignment.Left
		for i, row in rows do
			local card = Cards.Get(current.CardOf[row.Id])
			if card then
				order += 1
				local value = if card.Type == "Attack" then row.Dealt else row.Healed
				local holder = Kit.new("Frame", {
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Theme.Color.TileBottom,
					BackgroundTransparency = 0.15,
					Parent = list,
				}, { Kit.corner(UDim.new(0.4, 0)), Kit.stroke(Theme.Color.TileEdge, 1.5, 0.7) })
				local fill = Kit.new("Frame", {
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = if card.Type == "Attack" then Theme.Color.Attack else Theme.Color.Support,
					BackgroundTransparency = 0.35,
					Parent = holder,
				}, { Kit.corner(UDim.new(0.4, 0)) })
				task.delay(0.1 + i * 0.05, function()
					Kit.tween(fill, 0.5, { Size = UDim2.fromScale(math.max(0.02, value / top), 1) }, Enum.EasingStyle.Quad)
				end)
				local mvp = if i == 1 and row.Dealt > 0 then ' <font color="#FFC42E">MVP</font>' else ""
				local ko = if row.Alive then "" else ' <font color="#FF5064">KO</font>'
				local what = if card.Type == "Attack" then "dmg" else "healed + shielded"
				Kit.label({
					Text = `  {card.Name}{mvp}{ko}  <font color="#E6E2FF">{Kit.commas(value)} {what}</font>`,
					RichText = true,
					Font = Theme.Font.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.fromScale(1, 0.76),
					Position = UDim2.fromScale(0, 0.12),
					ZIndex = 2,
					Parent = holder,
				}, 17)
			end
		end
	end

	-- Rewards on the right.
	local buttons = Kit.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -44, 0, 52),
		BackgroundTransparency = 1,
		Visible = not hasRewards,
		Parent = panel,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	if hasRewards then
		-- A dark inset: REWARDS on the left of its header row, the fan's SKIP button on the right.
		local box = Kit.new("Frame", {
			Name = "Rewards",
			Position = UDim2.fromScale(0.4, 0),
			Size = UDim2.fromScale(0.6, 1),
			BackgroundColor3 = Color3.fromRGB(16, 9, 38),
			BackgroundTransparency = 0.2,
			Parent = content,
		}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(Theme.Color.TileEdge, 2, 0.5) })
		local rewardsTitle = Kit.label({
			Text = "REWARDS",
			Font = Theme.Font.Display,
			TextColor3 = Theme.Color.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 16, 0, 8),
			Size = UDim2.new(0.5, 0, 0, 30),
			Parent = box,
		}, 30)
		Kit.textStroke(Color3.fromRGB(70, 40, 0), 2, 0).Parent = rewardsTitle
		local area = Kit.new("Frame", {
			Name = "Fan",
			Position = UDim2.new(0, 12, 0, 48),
			Size = UDim2.new(1, -24, 1, -60),
			BackgroundTransparency = 1,
			Parent = box,
		})
		RewardReveal.Play(area, rewards, function()
			if buttons.Parent then
				buttons.Visible = true
			end
		end)
	end

	local back = Kit.button("BACK TO HUB", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 1,
		Size = UDim2.new(0, 210, 1, 0),
		Parent = buttons,
	})
	back.Activated:Connect(function()
		exit()
	end)
	-- In the tower, a win moves on to the next floor and a loss retries the same one.
	local againText = if tower == nil then "FIGHT AGAIN" elseif summary.Result == "Win" then "NEXT FLOOR" else "TRY AGAIN"
	local again = Kit.button(againText, Theme.Color.Roll, Theme.Color.RollDeep, {
		LayoutOrder = 2,
		Size = UDim2.new(0, 210, 1, 0),
		Parent = buttons,
	})
	local bossId, difficulty = if tower then Tower.Id else current.BossId, current.Difficulty
	again.Activated:Connect(function()
		local ok, message = startFight(bossId, difficulty)
		if not ok and message then
			hint(message)
		end
	end)
end

-- Scene -----------------------------------------------------------------------------------------

local function setAutoLabel()
	local on = current ~= nil and current.AutoUlt
	autoButton.Label.Text = if on then "AUTO ULT: ON" else "AUTO ULT: OFF"
	autoButton.UIStroke.Transparency = if on then 0 else 0.75
	autoButton.UIStroke.Thickness = if on then 3 else 1.5
end

local function setSpeedLabel()
	local speed = if current then current.Speed else 1
	speedButton.Label.Text = `SPEED {speed}x`
	speedButton.Label.TextTransparency = if current and current.SpeedUnlocked then 0 else 0.5
end

local function begin(start, bossId: string, difficulty: string)
	-- A tower floor fights a boss's echo (start.Tower: Tower.FloorAt): its model, moves and backdrop.
	local tower = start.Tower
	local boss = Bosses.Get(if tower then tower.Boss else bossId)
	current = {
		Info = start.Info,
		BossId = boss.Id,
		Difficulty = if tower then tower.Difficulty else difficulty,
		Tower = tower,
		BossName = if tower then tower.Name else boss.Name,
		BossColor = boss.Accent,
		Speed = start.Speed,
		SpeedUnlocked = start.SpeedUnlocked,
		AutoUlt = start.AutoUlt,
		Ended = false,
		CardOf = {},
	}
	State.InBattle = true
	table.clear(tiles)
	table.clear(ultTapped)
	clearChildren(frontRow)
	clearChildren(backRow)
	clearChildren(fxLayer)
	results.Visible = false
	warnBanner.Visible = false
	calloutLabel.TextTransparency = 1

	-- World theme.
	backdrop.UIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, boss.Deep:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 12, 26)),
		ColorSequenceKeypoint.new(1, boss.Deep),
	})
	spawnParticles(boss.Particles, boss.Accent)
	arena.Halo.BackgroundColor3 = boss.Accent
	arena.Disc.UIGradient.Color = ColorSequence.new(boss.Accent:Lerp(Color3.new(1, 1, 1), 0.2), boss.Deep)
	arena.Disc.UIStroke.Color = boss.Accent:Lerp(Color3.new(1, 1, 1), 0.35)
	arena.Inner.BackgroundColor3 = boss.Deep:Lerp(Color3.new(0, 0, 0), 0.3)

	-- The boss, live in 3D.
	if bossView then
		bossView.Frame:Destroy()
	end
	bossView = ModelView.new(boss.Id, {
		Name = "BossView",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.6, 1.25),
		ZIndex = 2,
		Parent = bossHolder,
	}, 10)
	if tower then
		bossView:SetTint(if tower.Guardian then Color3.fromRGB(255, 226, 150) else Color3.fromRGB(170, 240, 255)) -- an echo
	end
	barrierRing.Visible = false

	for i, unit in start.Info.Allies do
		current.CardOf[unit.Id] = unit.CardId
		local tile = makeTile(unit, i)
		tile.Parent = if string.sub(unit.Id, 1, 1) == "A" then frontRow else backRow
	end
	local diffIndex = Bosses.DifficultyIndex(current.Difficulty)
	local subtitle = `{boss.Title} · {string.upper(current.Difficulty)}`
	if tower then
		local affix = tower.Affix and Tower.AffixById[tower.Affix]
		subtitle = `Infinite Tower · Floor {tower.Floor}` .. (if affix then ` · {string.upper(affix.Name)}` else "")
		bossName.Text = `{string.upper(tower.Name)}  <font color="#A8A2C8">{if affix then `{affix.Icon} {affix.Name}` else boss.Title}</font>`
		bossChip.Label.Text = `FLOOR {tower.Floor}`
		bossChip.BackgroundColor3 = if tower.Guardian then Theme.Color.Gold else Color3.fromRGB(40, 170, 165)
	else
		bossName.Text = `{string.upper(boss.Name)}  <font color="#A8A2C8">{boss.Title}</font>`
		bossChip.Label.Text = string.upper(difficulty)
		bossChip.BackgroundColor3 = if diffIndex == 3 then Theme.Color.Danger elseif diffIndex == 2 then Theme.Color.Roll else Theme.Color.Quick
	end
	bossHpFill.Size = UDim2.fromScale(1, 1)
	bossHpTrail.Size = UDim2.fromScale(1, 1)
	bossBarrier.Size = UDim2.fromScale(0, 1)
	bossGauge.Size = UDim2.fromScale(0, 1)
	bossStatus.Text = ""
	setAutoLabel()
	setSpeedLabel()
	applySnapshot(start.Snap)

	gui.Enabled = true
	hooks.OnStart()
	playIntro(boss, subtitle, start.DeckPower or 0, start.Intro or 2)
end

function startFight(bossId: string, difficulty: string?)
	if current and not current.Ended then
		return false, nil
	end
	local ok, result = pcall(function()
		return Remotes.BattleStart:InvokeServer(bossId, difficulty)
	end)
	if not ok or not result or not result.Ok then
		local reason = if ok and result then result.Reason else nil
		return false, REASONS[reason] or "Couldn't start the fight"
	end
	begin(result, bossId, difficulty)
	return true, nil
end

function exit()
	if cardInfo then
		cardInfo:Destroy()
		cardInfo = nil
	end
	current = nil
	lastSnap = nil
	State.InBattle = false
	gui.Enabled = false
	results.Visible = false
	if bossView then
		bossView.Frame:Destroy()
		bossView = nil
	end
	for _, child in particles:GetChildren() do
		child:Destroy()
	end
	hooks.OnEnd()
end

function Battle.Init(playerGui: Instance, battleHooks: Hooks)
	hooks = battleHooks
	gui = Kit.screenGui("BattleGui", 4, playerGui) -- below the HUD so the Auto Roll feed stays visible
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	backdrop = Kit.new("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.02,
		Active = true,
		ZIndex = 1,
		Parent = gui,
	}, {
		Kit.gradient(ColorSequence.new(Color3.fromRGB(20, 14, 30), Color3.fromRGB(70, 26, 20)), 90),
	})
	particles = Kit.new("Frame", {
		Name = "Particles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = gui,
	})
	-- Soft spotlight behind the boss.
	Kit.new("Frame", {
		Name = "Spotlight",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.55, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		ZIndex = 2,
		Parent = gui,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Vignette: the edges fall off into shadow so the eye goes to the boss and the cards.
	for _, side in {
		{ AnchorPoint = Vector2.new(0, 0), Size = UDim2.fromScale(1, 0.22), Rotation = 90 },
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.2), Rotation = -90 },
		{ AnchorPoint = Vector2.new(0, 0), Size = UDim2.fromScale(0.16, 1), Rotation = 0 },
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.16, 1), Rotation = 180 },
	} do
		Kit.new("Frame", {
			Name = "Vignette",
			AnchorPoint = side.AnchorPoint,
			Position = side.Position or UDim2.fromScale(0, 0),
			Size = side.Size,
			BackgroundColor3 = Color3.fromRGB(4, 2, 10),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = gui,
		}, {
			Kit.new("UIGradient", {
				Rotation = side.Rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	local inset = GuiService:GetGuiInset()
	STAGE_HOME = UDim2.new(0, 0, 0, inset.Y + 4)
	stage = Kit.new("Frame", {
		Name = "Stage",
		Position = STAGE_HOME,
		Size = UDim2.new(1, 0, 1, -inset.Y - 10),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	})

	-- Boss panel: name + difficulty, HP bar (trail, barrier, 50% / 20% markers), action bar, status.
	local bossArea = Kit.new("Frame", {
		Name = "Boss",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.6, 0.17),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = stage,
	}, { Kit.new("UISizeConstraint", { MaxSize = Vector2.new(820, 112) }) })
	bossName = Kit.label({
		Name = "BossName",
		Text = "",
		RichText = true,
		Font = Theme.Font.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.62, 0.3),
		Parent = bossArea,
	}, 22)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = bossName
	bossChip = Kit.new("Frame", {
		Name = "Difficulty",
		Position = UDim2.fromScale(0.63, 0.02),
		Size = UDim2.fromScale(0.15, 0.25),
		BackgroundColor3 = Theme.Color.Quick,
		Parent = bossArea,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.label({
		Name = "Label",
		Text = "NORMAL",
		Font = Theme.Font.Heavy,
		Size = UDim2.fromScale(0.9, 0.75),
		Position = UDim2.fromScale(0.05, 0.12),
		Parent = bossChip,
	}, 14)
	timerLabel = Kit.label({
		Name = "Timer",
		Text = "3:00",
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.2, 0.3),
		Parent = bossArea,
	}, 26)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = timerLabel
	local hpTrack
	hpTrack, bossHpFill, bossHpTrail = bar(bossArea, "BossHP", 0.34, 0.34, Color3.new(1, 1, 1), true)
	bossHpFill.Size = UDim2.fromScale(1, 1)
	Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(220, 50, 60)), 0).Parent = bossHpFill
	bossBarrier = Kit.new("Frame", {
		Name = "Barrier",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(220, 140, 255),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = hpTrack,
	}, { Kit.corner(UDim.new(1, 0)) })
	for _, at in { Config.Battle.PhaseAt, Config.Battle.EnrageAt } do
		Kit.new("Frame", {
			Name = "Marker",
			Position = UDim2.fromScale(at, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = hpTrack,
		})
	end
	bossHpText = Kit.label({
		Name = "HpText",
		Text = "",
		Font = Theme.Font.Heavy,
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.05),
		ZIndex = 5,
		Parent = hpTrack,
	}, 18)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.2).Parent = bossHpText
	local _, gaugeFill = bar(bossArea, "BossAction", 0.72, 0.08, Theme.Color.Danger)
	bossGauge = gaugeFill
	bossStatus = Kit.label({
		Name = "Status",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Support,
		Position = UDim2.fromScale(0, 0.82),
		Size = UDim2.fromScale(1, 0.18),
		Parent = bossArea,
	}, 15)

	-- Arena: a glowing platform the boss stands on, recoloured for each world in begin().
	arena = Kit.new("Frame", {
		Name = "Arena",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.06),
		BackgroundTransparency = 1,
		Parent = stage,
	})
	local halo = Kit.new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.5, 2.6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.86,
		Parent = arena,
	}, { Kit.corner(UDim.new(1, 0)) })
	pulseForever(halo, { BackgroundTransparency = 0.93, Size = UDim2.fromScale(1.62, 2.8) }, 1.6)
	Kit.new("Frame", {
		Name = "Disc",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = arena,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.gradient(ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), 90),
		Kit.stroke(Color3.new(1, 1, 1), 3, 0),
	})
	Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.74, 0.58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Parent = arena,
	}, { Kit.corner(UDim.new(1, 0)) })

	-- The boss figure sits in this holder; floats and hit rings anchor to it.
	bossHolder = Kit.new("Frame", {
		Name = "BossHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.26, 0.26),
		BackgroundTransparency = 1,
		Parent = stage,
	}, { Kit.aspect(1, Enum.DominantAxis.Height) })
	barrierRing = Kit.new("Frame", {
		Name = "BarrierRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.15, 1.15),
		BackgroundColor3 = Color3.fromRGB(200, 120, 255),
		BackgroundTransparency = 0.88,
		Visible = false,
		ZIndex = 3,
		Parent = bossHolder,
	}, { Kit.corner(UDim.new(1, 0)) })
	local barrierStroke = Kit.stroke(Color3.fromRGB(230, 150, 255), 3, 0.1)
	barrierStroke.Parent = barrierRing
	pulseForever(barrierStroke, { Transparency = 0.6, Thickness = 6 }, 0.6)

	calloutLabel = Kit.label({
		Name = "Callout",
		Text = "",
		Font = Theme.Font.Display,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.75, 0.065),
		ZIndex = 30,
		Parent = stage,
	}, 40)
	Kit.textStroke(Color3.new(0, 0, 0), 2.5, 0.1).Parent = calloutLabel
	Kit.new("UIScale", { Scale = 1, Parent = calloutLabel })

	warnBanner = Kit.new("Frame", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.06),
		BackgroundColor3 = Theme.Color.Danger,
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 25,
		Parent = stage,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(220, 28), MaxSize = Vector2.new(560, 52) }),
	})
	pulseForever(warnBanner, { BackgroundTransparency = 0.45 }, 0.25)
	warnLabel = Kit.label({
		Name = "Text",
		Text = "",
		Font = Theme.Font.Display,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.7),
		ZIndex = 26,
		Parent = warnBanner,
	}, 28)

	-- Card rows: Attack (front) above Support (back, slimmer: no HP).
	local rowsFrame = Kit.new("Frame", {
		Name = "Rows",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.64, 0.46),
		BackgroundTransparency = 1,
		Parent = stage,
	}, { Kit.new("UISizeConstraint", { MaxSize = Vector2.new(980, 320) }) })
	local function rowLabel(text: string, y: number, color: Color3)
		Kit.label({
			Text = text,
			Font = Theme.Font.Heavy,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(0.6, 0.07),
			Parent = rowsFrame,
		}, 14)
	end
	local function row(name: string, y: number, height: number): Frame
		return Kit.new("Frame", {
			Name = name,
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, height),
			BackgroundTransparency = 1,
			Parent = rowsFrame,
		}, {
			Kit.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		})
	end
	rowLabel("ATTACK · FRONT ROW", 0, Theme.Color.Attack)
	frontRow = row("Front", 0.08, 0.5)
	rowLabel("SUPPORT · BACK ROW · CAN'T BE HIT", 0.6, Theme.Color.Support)
	backRow = row("Back", 0.68, 0.32)

	-- Controls down the left edge (where the main menu sits outside battle).
	local controlsFrame = Kit.new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.66, 0),
		Size = UDim2.fromScale(0.15, 0.4),
		BackgroundTransparency = 1,
		Parent = stage,
	}, {
		Kit.new("UISizeConstraint", { MinSize = Vector2.new(96, 120), MaxSize = Vector2.new(170, 220) }),
		Kit.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	autoButton = Kit.button("AUTO ULT: OFF", Theme.Color.Accent, Theme.Color.AutoDeep, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0.28, 0),
		Parent = controlsFrame,
	})
	autoButton.Activated:Connect(function()
		if current == nil or current.Ended then
			return
		end
		current.AutoUlt = not current.AutoUlt
		State.Battle.AutoUlt = current.AutoUlt
		Remotes.BattleInput:FireServer("Auto", current.AutoUlt)
		setAutoLabel()
		if lastSnap then
			applySnapshot(lastSnap)
		end
	end)
	speedButton = Kit.button("SPEED 1x", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0.28, 0),
		Parent = controlsFrame,
	})
	speedButton.Activated:Connect(function()
		if current == nil or current.Ended then
			return
		end
		if not current.SpeedUnlocked then
			hint("2x speed unlocks after clearing World 1 Normal")
			return
		end
		local speeds = Config.Battle.Speeds
		local index = table.find(speeds, current.Speed) or 1
		current.Speed = speeds[index % #speeds + 1]
		State.Battle.Speed = current.Speed
		Remotes.BattleInput:FireServer("Speed", current.Speed)
		setSpeedLabel()
	end)
	forfeitButton = Kit.button("GIVE UP", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0.28, 0),
		Parent = controlsFrame,
	})
	local armed = false
	forfeitButton.Activated:Connect(function()
		if current == nil or current.Ended then
			return
		end
		if not armed then
			armed = true
			forfeitButton.Label.Text = "TAP AGAIN"
			task.delay(2.5, function()
				armed = false
				forfeitButton.Label.Text = "GIVE UP"
			end)
			return
		end
		armed = false
		forfeitButton.Label.Text = "GIVE UP"
		Remotes.BattleInput:FireServer("Forfeit")
	end)

	hintLabel = Kit.label({
		Name = "Hint",
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.6, 0.05),
		ZIndex = 30,
		Parent = stage,
	}, 20)
	Kit.textStroke(Color3.new(0, 0, 0), 1.5, 0.3).Parent = hintLabel

	fxLayer = Kit.new("Frame", {
		Name = "Fx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	})
	intro = Kit.new("Frame", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 45,
		Parent = gui,
	})
	results = Kit.new("Frame", {
		Name = "Results",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Backdrop,
		BackgroundTransparency = 0.25,
		Visible = false,
		Active = true,
		ZIndex = 50,
		Parent = gui,
	})

	Remotes.BattleEvent.OnClientEvent:Connect(function(message)
		if current == nil then
			return
		end
		if message.Events then
			playBatch(message.Events)
		end
		if message.Snap then
			applySnapshot(message.Snap)
		end
		if message.Done then
			if message.Done.Progress then
				State.ApplyProgress(message.Done.Progress)
			end
			if message.Done.Result == "Stopped" then
				exit()
				return
			end
			-- Let the last hits land before the results panel.
			task.delay(0.9, function()
				if current and not current.Ended then
					showResults(message.Done)
				end
			end)
		end
	end)
end

-- Starts a fight. Returns false and a message when the server refuses.
-- bossId is a boss id, or Tower.Id for the next tower floor (then difficulty is ignored).
function Battle.Start(bossId: string, difficulty: string?): (boolean, string?)
	return startFight(bossId, difficulty)
end

function Battle.IsActive(): boolean
	return current ~= nil
end

return Battle
