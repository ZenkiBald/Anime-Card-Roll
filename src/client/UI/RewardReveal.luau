--!nonstrict
-- Boss reward reveal: the reward cards fan out face down and flip one by one, sorted so the
-- rarest flips last. Each flip applies the result to the client's state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Borders = require(Shared.Borders)

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local CardView = require(script.Parent.CardView)
local RollCard = require(script.Parent.RollCard)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)

local RewardReveal = {}

-- Cards keep a 0.72 shape by default; the grid cell already has that shape, so dropping the
-- constraint lets the flip squash the card sideways instead of shrinking it.
function RewardReveal.Unlock(card: Frame)
	local aspect = card:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
end

-- Only Index discoveries get a NEW! badge; first-clear rewards keep a separate footer ribbon.
function RewardReveal.Badges(slot, result)
	if RollCard.IsNew(result) then RollCard.NewBadge(slot.Holder) end
	if result.Bonus then
		local ribbon = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1.06),
			Size = UDim2.fromScale(1.05, 0.14),
			BackgroundColor3 = Theme.Color.Roll,
			ZIndex = 20,
			Parent = slot.Holder,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.label({
			Text = "FIRST CLEAR",
			Font = Theme.Font.Heavy,
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			ZIndex = 21,
			Parent = ribbon,
		}, 14)
	end
end

-- Plays the reveal inside `parent`. Calls onDone when every card has flipped.
function RewardReveal.Play(parent: Frame, rewards, onDone: (() -> ())?)
	local results = table.clone(rewards.Results or {})
	table.sort(results, function(a, b)
		local ra, rb = Borders.Index(a.Border), Borders.Index(b.Border)
		if ra ~= rb then
			return ra < rb
		end
		return (a.Bonus and 1 or 0) < (b.Bonus and 1 or 0)
	end)
	local count = #results
	-- The cards are already the player's: record them now, so leaving early loses nothing.
	for _, result in rewards.Results or {} do
		State.ApplyRoll(result)
	end
	if rewards.Summary then
		State.ApplyRoll({ Summary = rewards.Summary })
	end
	local columns = if count <= 7 then count else math.ceil(count / 2)
	local rows = math.ceil(count / math.max(1, columns))

	local area = Kit.new("Frame", {
		Name = "RewardCards",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local grid = Kit.new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = area,
	})
	local function size()
		local w, h = area.AbsoluteSize.X, area.AbsoluteSize.Y
		if w <= 0 then
			return
		end
		local gap = 8
		local cellW = math.floor((w - gap * (columns - 1)) / math.max(1, columns))
		local cellH = math.floor((h - gap * (rows - 1)) / math.max(1, rows))
		-- Reserve space above / below the art for NEW and first-clear labels, even in two rows.
		cellW = math.min(cellW, math.floor(cellH * 0.72 * 0.78), 130)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.CellSize = UDim2.fromOffset(cellW, math.floor(cellW / 0.72 / 0.78))
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	task.defer(size)

	-- Face-down cards deal in.
	local slots = {}
	for i = 1, count do
		local slot = Kit.new("Frame", {
			Name = `Reward{i}`,
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Parent = area,
		})
		local holder = Kit.new("Frame", {
			Name = "Holder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.78),
			BackgroundTransparency = 1,
			Parent = slot,
		})
		local scale = Kit.new("UIScale", { Scale = 0, Parent = holder })
		local back = CardView.back()
		RewardReveal.Unlock(back)
		back.Parent = holder
		slots[i] = { Slot = slot, Holder = holder, Scale = scale, Back = back }
		task.delay(i * 0.04, function()
			Kit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end

	-- SKIP flips everything that's left at once.
	local skipped = false
	local skipButton = Kit.button("SKIP  ▶▶", Theme.Color.PanelLight, Theme.Color.Panel, {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(110, 30),
		ZIndex = 30,
		Parent = parent,
	})
	skipButton.Activated:Connect(function()
		skipped = true
		skipButton.Visible = false
	end)

	task.spawn(function()
		task.wait(0.35 + count * 0.04)
		for i, result in results do
			if area.Parent == nil then
				return
			end
			local slot = slots[i]
			local tier = Borders.RevealTier(result.Border)
			local idx = tier.Index
			if skipped then
				slot.Back:Destroy()
				local front = RollCard.new(result.CardId, result.Border)
				RewardReveal.Unlock(front)
				front.Parent = slot.Holder
				slot.Scale.Scale = 1
				slot.Holder.Size = UDim2.fromScale(1, 0.78)
				RewardReveal.Badges(slot, result)
				continue
			end
			-- Build-up for the rare ones.
			if idx >= 4 then
				local stroke = slot.Back:FindFirstChild("BackStroke")
				if stroke then
					Kit.tween(stroke, 0.25, { Color = tier.Color, Thickness = 6, Transparency = 0 })
				end
				Effects.Pulse(slot.Scale, 1, 0.3 + (idx - 4) * 0.08, 0.12)
			end
			-- Flip: squash to nothing, swap faces, spring back.
			Kit.tween(slot.Holder, 0.12, { Size = UDim2.fromScale(0, 0.78) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			slot.Back:Destroy()
			local front = RollCard.new(result.CardId, result.Border)
			RewardReveal.Unlock(front)
			front.Parent = slot.Holder
			Kit.tween(slot.Holder, 0.2, { Size = UDim2.fromScale(1, 0.78) }, Enum.EasingStyle.Back)
			Sfx.Play("Flip", 0.9 + idx * 0.06)
			Sfx.Sting(tier.Sting, true)
			if result.Border and result.Border ~= "Normal" then
				Sfx.Play("Reward", 1.2)
				Effects.Sparks(slot.Slot, Color3.fromRGB(255, 200, 60), 12, 0.9)
			end
			RewardReveal.Badges(slot, result)
			if idx >= 3 then
				Effects.Sparks(slot.Slot, tier.Color, 6 + idx * 3, 0.9)
			end
			if idx >= 4 then
				Effects.Flash(parent, tier.Color, 0.35, 0.6)
			end
			if idx >= 5 then
				Effects.Shimmer(front, 2)
				Effects.Shake(parent, 4 + (idx - 5) * 4, 0.3)
				Sfx.Play("LowHit", 1.1)
			end
			task.wait(if idx >= 5 then 0.5 elseif idx >= 4 then 0.32 else 0.16)
		end
		skipButton.Visible = false
		if onDone then
			onDone()
		end
	end)
	return area
end

return RewardReveal
