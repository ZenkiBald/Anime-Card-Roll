--!nonstrict
-- Title screen: shows the moment the game starts, while the save loads. The town blurs behind a
-- dark wash; the logo, a fan of top cards (one 3D figure each) and PLAY. PLAY lights up once Main
-- calls Title.Ready(); pressing it sweeps the screen away.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local Sfx = require(script.Parent.Sfx)

local Title = {}

-- The fan, left to right; the middle card stands tallest.
local FAN = { "noa", "kaito", "raijen", "aurelia", "amaya" }

local gui: ScreenGui? = nil
local blur: BlurEffect? = nil
local play: any = nil
local status: TextLabel? = nil
local fan: Frame? = nil
local ready = false
local onPlay: (() -> ())? = nil

local function loop(instance: Instance, goal, seconds: number)
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

function Title.Show(playerGui: Instance)
	gui = Kit.screenGui("TitleGui", 40, playerGui)
	gui.IgnoreGuiInset = true

	blur = Instance.new("BlurEffect")
	blur.Name = "TitleBlur"
	blur.Size = 20
	blur.Parent = Lighting

	Kit.new("Frame", {
		Name = "Wash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.12,
		Active = true, -- taps don't reach the world or the HUD
		Parent = gui,
	}, {
		Kit.gradient(
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 18, 86)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 10, 40)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 4, 20)),
			}),
			90
		),
	})
	-- Light rays slowly turning behind the cards.
	local rayHolder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Effects.Rays(rayHolder, Color3.fromRGB(190, 140, 255), 10)

	-- Logo: two stacked words in gold with a heavy purple outline, tilted a touch.
	local logo = Kit.new("Frame", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.8, 0.24),
		Rotation = -3,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local top = Kit.label({
		Text = "ANIME CARD",
		Font = Theme.Font.Display,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 0.52),
		Parent = logo,
	}, 96)
	Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 170, 40)), 90).Parent = top
	Kit.textStroke(Color3.fromRGB(60, 20, 120), 6, 0).Parent = top
	local bottom = Kit.label({
		Text = "ROLL",
		Font = Theme.Font.Display,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0, 0.46),
		Size = UDim2.fromScale(1, 0.56),
		Parent = logo,
	}, 110)
	Kit.gradient(ColorSequence.new(Color3.fromRGB(255, 150, 230), Color3.fromRGB(176, 92, 255)), 90).Parent = bottom
	Kit.textStroke(Color3.fromRGB(40, 12, 90), 6, 0).Parent = bottom
	local logoScale = Kit.new("UIScale", { Scale = 0.3, Parent = logo })
	Kit.tween(logoScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	loop(logo, { Rotation = 1 }, 2.4)

	-- The card fan.
	fan = Kit.new("Frame", {
		Name = "Fan",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.8, 0.36),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local middle = (#FAN + 1) / 2
	for i, id in FAN do
		local offset = i - middle
		local slot = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + offset * 0.13, 0.55 + math.abs(offset) * 0.07),
			Size = UDim2.fromScale(0.2, if offset == 0 then 1.05 else 0.9),
			Rotation = offset * 9,
			BackgroundTransparency = 1,
			ZIndex = 10 - math.floor(math.abs(offset)),
			Parent = fan,
		}, { Kit.aspect(0.72, Enum.DominantAxis.Height) })
		-- The middle card wears a Rainbow border, its neighbours Gold: a taste of what you can pull.
		local card = CardView.new(id, { Owned = true, Stars = 5, Compact = true, Border = if offset == 0 then "Rainbow" elseif math.abs(offset) == 1 then "Gold" else nil })
		card.ZIndex = slot.ZIndex
		card.Parent = slot
		local scale = Kit.new("UIScale", { Scale = 0, Parent = slot })
		task.delay(0.15 + i * 0.08, function()
			Kit.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		loop(slot, { Position = slot.Position - UDim2.fromScale(0, 0.03) }, 1.6 + i * 0.15)
	end

	-- PLAY and a status line under it.
	play = Kit.button("LOADING...", Theme.Color.Roll, Theme.Color.RollDeep, {
		Name = "Play",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromScale(0.26, 0.11),
		Parent = gui,
	})
	Kit.new("UISizeConstraint", { MinSize = Vector2.new(200, 56), MaxSize = Vector2.new(360, 96), Parent = play })
	play.Label.Size = UDim2.fromScale(0.8, 0.6)
	play.Label.UITextSizeConstraint.MaxTextSize = 46
	Kit.dim(play, true)
	play.Activated:Connect(function()
		if ready then
			Title.Close()
		end
	end)
	status = Kit.label({
		Text = "Roll · Collect · Fuse · Fight",
		Font = Theme.Font.Heavy,
		TextColor3 = Color3.fromRGB(210, 196, 255),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromScale(0.6, 0.04),
		Parent = gui,
	}, 22)
end

-- The game has loaded: PLAY lights up and pulses. `callback` runs when the player presses it.
function Title.Ready(callback: (() -> ())?)
	onPlay = callback
	if gui == nil then
		if callback then
			callback()
		end
		return
	end
	ready = true
	play.Label.Text = "PLAY"
	Kit.dim(play, false)
	local scale = play:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = play })
	loop(scale, { Scale = 1.06 }, 0.55)
	Effects.Sparks(play, Theme.Color.Gold, 14, 0.9)
end

function Title.IsOpen(): boolean
	return gui ~= nil
end

function Title.Close()
	local closing = gui
	if closing == nil then
		return
	end
	gui = nil
	Sfx.Play("Whoosh", 0.8)
	-- Cards fly apart, everything fades, the world comes into focus.
	if fan then
		for _, slot in fan:GetChildren() do
			if slot:IsA("GuiObject") then
				local away = if slot.Position.X.Scale < 0.5 then -0.6 elseif slot.Position.X.Scale > 0.5 then 0.6 else 0
				Kit.tween(slot, 0.45, { Position = slot.Position + UDim2.fromScale(away, -0.8), Rotation = slot.Rotation + away * 60 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
	end
	local wash = closing:FindFirstChild("Wash")
	if wash then
		Kit.tween(wash, 0.5, { BackgroundTransparency = 1 })
	end
	for _, d in closing:GetDescendants() do
		if d:IsA("TextLabel") then
			Kit.tween(d, 0.35, { TextTransparency = 1 })
		end
	end
	if blur then
		Kit.tween(blur, 0.5, { Size = 0 })
	end
	task.delay(0.55, function()
		closing:Destroy()
		if blur then
			blur:Destroy()
			blur = nil
		end
		if onPlay then
			onPlay()
		end
	end)
end

return Title
