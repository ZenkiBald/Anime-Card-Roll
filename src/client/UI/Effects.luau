--!nonstrict
-- 2D effects built from plain frames and tweens: no textures, no 3D particles,
-- so they cost almost nothing on low-end phones.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Effects = {}

local function fxCount(high: number): number
	return if Theme.FxLow then math.max(1, math.floor(high * 0.4)) else high
end

-- Full-screen colour flash that fades out.
function Effects.Flash(parent: Instance, color: Color3, duration: number, startTransparency: number?)
	local flash = Kit.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = startTransparency or 0.1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = parent,
	})
	Kit.tween(flash, duration, { BackgroundTransparency = 1 }).Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Shakes a GuiObject around its current position, then puts it back.
function Effects.Shake(target: GuiObject, intensity: number, duration: number)
	local origin = target.Position
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= duration or target.Parent == nil then
			connection:Disconnect()
			target.Position = origin
			return
		end
		local falloff = 1 - elapsed / duration
		local dx = (math.random() * 2 - 1) * intensity * falloff
		local dy = (math.random() * 2 - 1) * intensity * falloff
		target.Position = origin + UDim2.fromOffset(dx, dy)
	end)
end

-- Little diamonds that burst outward from the centre of `parent` and fade.
function Effects.Sparks(parent: GuiObject, color: Color3, count: number, spread: number?)
	local n = fxCount(count)
	local reach = spread or 0.6
	for _ = 1, n do
		local size = math.random(6, 14)
		local spark = Kit.new("Frame", {
			Name = "Spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = if math.random() < 0.3 then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
			ZIndex = 40,
			Parent = parent,
		})
		local angle = math.random() * math.pi * 2
		local distance = (0.35 + math.random() * 0.65) * reach
		local goal = UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.5 + math.sin(angle) * distance)
		local time = 0.6 + math.random() * 0.5
		Kit.tween(spark, time, {
			Position = goal,
			BackgroundTransparency = 1,
			Rotation = 45 + math.random(-180, 180),
		}, Enum.EasingStyle.Quart).Completed:Connect(function()
			spark:Destroy()
		end)
	end
end

-- Light rays behind the card. Returns the container; destroy it to remove the rays.
function Effects.Rays(parent: GuiObject, color: Color3, count: number): Frame
	local n = fxCount(count)
	local container = Kit.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = parent,
	}, { Kit.aspect(1, Enum.DominantAxis.Height) })
	for i = 1, n do
		local ray = Kit.new("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.07, 1.9),
			Rotation = (i - 1) * (180 / n),
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = container,
		})
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(0.65, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
	end

	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if container.Parent == nil then
			spin:Disconnect()
			return
		end
		container.Rotation = (container.Rotation + dt * 18) % 360
	end)

	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(0.2, 0.2)
	Kit.tween(container, 0.5, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	return container
end

-- Sweeps the foil band across a card's Shine layer.
function Effects.Shimmer(card: Frame, times: number)
	local shine = card:FindFirstChild("Shine")
	local gradient = shine and shine:FindFirstChild("ShineGradient")
	if not gradient then
		return
	end
	task.spawn(function()
		for _ = 1, times do
			if card.Parent == nil then
				return
			end
			gradient.Offset = Vector2.new(-1, 0)
			Kit.tween(gradient, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine).Completed:Wait()
			task.wait(0.6)
		end
	end)
end

-- Keeps a gradient rotating (prismatic Secret frames). Stops when the gradient is removed.
function Effects.Spin(gradient: UIGradient, degreesPerSecond: number)
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if gradient.Parent == nil then
			connection:Disconnect()
			return
		end
		gradient.Rotation = (gradient.Rotation + dt * degreesPerSecond) % 360
	end)
end

-- Scale pulses on a UIScale.
function Effects.Pulse(scale: UIScale, times: number, period: number, amount: number)
	for _ = 1, times do
		Kit.tween(scale, period * 0.5, { Scale = 1 + amount }, Enum.EasingStyle.Sine).Completed:Wait()
		Kit.tween(scale, period * 0.5, { Scale = 1 }, Enum.EasingStyle.Sine).Completed:Wait()
	end
end

return Effects
