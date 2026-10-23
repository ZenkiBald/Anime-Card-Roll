--!nonstrict
-- Test-phase tools. Only shown when Config.TestMode is on, and the server
-- refuses every request once it's off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Meta = require(Shared.Meta)
local Borders = require(Shared.Borders)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Reveal = require(script.Parent.Reveal)
local State = require(script.Parent.Parent.State)

local DevPanel = {}

local modal

local function section(parent: Instance, order: number, title: string): Frame
	Kit.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 15,
		Text = title,
		Parent = parent,
	}, 15)
	return Kit.new("Frame", {
		LayoutOrder = order + 1,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			Wraps = true,
		}),
	})
end

local function devCall(action: string, value: any?)
	local ok, result = pcall(function()
		return Remotes.Dev:InvokeServer(action, value)
	end)
	if ok and result and result.Ok then
		State.ApplyFull(result)
		return true
	end
	return false
end

function DevPanel.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "DevGui", "TEST TOOLS", Vector2.new(0.62, 0.8), Vector2.new(640, 560))

	local list = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = modal.Body,
	}, {
		Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})

	-- Luck
	local luckRow = section(list, 1, "LUCK (server-side, this session only)")
	for i, luck in { 1, 2, 3, Config.Roll.LuckCap } do
		local button = Kit.button(`{luck}x`, Theme.Color.Quick, Theme.Color.QuickDeep, {
			LayoutOrder = i,
			Size = UDim2.fromOffset(72, 36),
			Parent = luckRow,
		})
		button.Activated:Connect(function()
			devCall("SetLuck", luck)
		end)
	end

	-- Reveal previews (client only, nothing is saved)
	local previewRow = section(list, 3, "PREVIEW A REVEAL (not saved)")
	previewRow.Size = UDim2.new(1, 0, 0, 80)
	for i, name in Rarity.Order do
		local tier = Rarity.Get(name)
		local top = if name == "Secret" then Color3.fromRGB(150, 110, 255) else tier.Color
		local button = Kit.button(string.upper(name), top, tier.Dark, {
			LayoutOrder = i,
			Size = UDim2.fromOffset(110, 36),
			Parent = previewRow,
		})
		button.Activated:Connect(function()
			local pool = Cards.ByRarity[name]
			local card = pool[math.random(1, #pool)]
			modal:Close()
			Reveal.Full({
				CardId = card.Id,
				Rarity = name,
				Outcome = "New",
				Stars = 0,
				Copies = 1,
				PityTriggered = false,
			})
		end)
	end

	-- Border reveal previews: a random Legendary-or-lower card wearing a NEW border.
	local borderRow = section(list, 9, "PREVIEW A BORDER (not saved)")
	for i, id in { "Gold", "Rainbow", "Secret" } do
		local border = Borders.Get(id)
		local button = Kit.button(string.upper(id), border.Color, border.Color:Lerp(Color3.new(0, 0, 0), 0.5), {
			LayoutOrder = i,
			Size = UDim2.fromOffset(120, 36),
			Parent = borderRow,
		})
		button.Activated:Connect(function()
			local rarity = Rarity.Order[math.random(1, 5)]
			local pool = Cards.ByRarity[rarity]
			local card = pool[math.random(1, #pool)]
			modal:Close()
			Reveal.Full({
				CardId = card.Id,
				Rarity = rarity,
				Outcome = "New",
				Stars = 0,
				Copies = 1,
				Border = id,
				NewBorder = true,
				Borders = { [id] = true },
				PityTriggered = false,
			})
		end)
	end
	local giveBorders = Kit.button("GIVE BORDERS", Color3.fromRGB(255, 110, 200), Color3.fromRGB(140, 40, 110), {
		LayoutOrder = 4,
		Size = UDim2.fromOffset(160, 36),
		Parent = borderRow,
	})
	giveBorders.Activated:Connect(function()
		devCall("GiveBorders") -- Gold on every owned card, Rainbow on every 2nd, Secret on every 4th
	end)

	-- Data
	local dataRow = section(list, 5, "MY DATA")
	local grant = Kit.button("GIVE ALL CARDS", Theme.Color.Auto, Theme.Color.AutoDeep, {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(160, 36),
		Parent = dataRow,
	})
	grant.Activated:Connect(function()
		devCall("GrantAll")
	end)

	-- The 8 Commons + Uncommons: the ~14.6k first deck World 1 Normal is tuned around.
	local starter = Kit.button("GIVE STARTER 8", Theme.Color.Quick, Theme.Color.QuickDeep, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(160, 36),
		Parent = dataRow,
	})
	starter.Activated:Connect(function()
		devCall("GrantStarter")
	end)

	-- Fights: open every world / difficulty, and max out stars to try the late fights.
	local fightRow = section(list, 7, "FIGHTS")
	local unlock = Kit.button("UNLOCK ALL FIGHTS", Theme.Color.Roll, Theme.Color.RollDeep, {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(180, 36),
		Parent = fightRow,
	})
	unlock.Activated:Connect(function()
		devCall("UnlockFights")
	end)
	local maxStars = Kit.button("MAX MY STARS", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(160, 36),
		Parent = fightRow,
	})
	maxStars.Activated:Connect(function()
		devCall("MaxStars")
	end)
	local loot = Kit.button("GIVE LOOT", Color3.fromRGB(176, 92, 255), Theme.Color.AccentDeep, {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(140, 36),
		Parent = fightRow,
	})
	loot.Activated:Connect(function()
		devCall("GiveLoot") -- 1,000 Shards and 3 of every potion
	end)
	local fill = Kit.button("FILL FUSION", Color3.fromRGB(255, 138, 61), Color3.fromRGB(170, 60, 20), {
		LayoutOrder = 4,
		Size = UDim2.fromOffset(150, 36),
		Parent = fightRow,
	})
	fill.Activated:Connect(function()
		devCall("FillCopies") -- every owned card gets enough copies to fuse
	end)
	local items = Kit.button("GIVE ITEMS", Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 40, 110), {
		LayoutOrder = 5,
		Size = UDim2.fromOffset(150, 36),
		Parent = fightRow,
	})
	items.Activated:Connect(function()
		devCall("GiveItems") -- one of every artifact, two of every accessory
	end)

	-- Events, wheel and levels.
	local eventRow = section(list, 11, "EVENTS · WHEEL · LEVEL")
	eventRow.Size = UDim2.new(1, 0, 0, 84) -- two rows of buttons
	for i, event in Meta.Events do
		local button = Kit.button(event.Name, event.Color, event.Color:Lerp(Color3.new(0, 0, 0), 0.45), {
			LayoutOrder = i,
			Size = UDim2.fromOffset(150, 36),
			Parent = eventRow,
		})
		button.Activated:Connect(function()
			devCall("StartEvent", event.Id)
		end)
	end
	local spins = Kit.button("5 SPINS", Theme.Color.Gold, Color3.fromRGB(170, 110, 0), {
		LayoutOrder = 10,
		Size = UDim2.fromOffset(110, 36),
		Parent = eventRow,
	})
	spins.Activated:Connect(function()
		devCall("GiveSpins")
	end)
	local xp = Kit.button("+3000 XP", Theme.Color.Quick, Theme.Color.QuickDeep, {
		LayoutOrder = 11,
		Size = UDim2.fromOffset(120, 36),
		Parent = eventRow,
	})
	xp.Activated:Connect(function()
		devCall("AddXP")
	end)

	-- Infinite Tower: jump 10 floors up (no rewards) to try the high floors, or start again from floor 1.
	local towerRow = section(list, 13, "INFINITE TOWER")
	local towerUp = Kit.button("+10 FLOORS", Color3.fromRGB(40, 170, 165), Color3.fromRGB(16, 90, 90), {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(150, 36),
		Parent = towerRow,
	})
	towerUp.Activated:Connect(function()
		devCall("TowerUp")
	end)
	local towerReset = Kit.button("TOWER TO FLOOR 1", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(180, 36),
		Parent = towerRow,
	})
	towerReset.Activated:Connect(function()
		devCall("TowerReset")
	end)

	local reset = Kit.button("RESET MY DATA", Theme.Color.Danger, Color3.fromRGB(120, 20, 40), {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(160, 36),
		Parent = dataRow,
	})
	local armed = false
	reset.Activated:Connect(function()
		if not armed then
			armed = true
			reset.Label.Text = "TAP AGAIN"
			task.delay(2.5, function()
				armed = false
				reset.Label.Text = "RESET MY DATA"
			end)
			return
		end
		armed = false
		reset.Label.Text = "RESET MY DATA"
		devCall("Reset")
	end)

	Kit.label({
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Font.Medium,
		TextColor3 = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 14,
		Text = "Set Config.TestMode to false in ReplicatedStorage > Shared > Config before launch. "
			.. "That hides this panel, turns the unlock rules on and makes the server refuse these tools.",
		Parent = list,
	}, 14)
end

function DevPanel.Toggle()
	modal:Toggle()
end

return DevPanel
