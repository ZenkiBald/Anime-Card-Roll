--!nonstrict
-- REDEEM CODES (the bottom of the STORE): type a code, REDEEM, and its reward lands at once (a toast
-- shows what). Each code works once per player; the server checks everything (CodeService, codes kept
-- server-side in Codes.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Codes = {}

local REASONS = {
	Invalid = "That code doesn't exist",
	Used = "You already used that code",
	Expired = "That code has expired",
	TooFast = "Slow down a little",
	Loading = "Still loading",
}

local holder: Frame
local box: TextBox
local result: TextLabel
local busy = false

local function redeem()
	if busy then
		return
	end
	local text = box.Text
	if text == "" then
		result.Text = "Type a code first"
		result.TextColor3 = Theme.Color.Muted
		return
	end
	busy = true
	local ok, answer = pcall(function()
		return Remotes.Redeem:InvokeServer(text)
	end)
	busy = false
	if ok and answer and answer.Ok then
		if answer.Meta then
			State.ApplyMeta(answer.Meta)
		end
		local got = if answer.Granted then Meta.Describe(answer.Granted) else ""
		result.Text = `REDEEMED!  {got}`
		result.TextColor3 = Theme.Color.Gold
		box.Text = ""
		Sfx.Play("Reward", 1.1)
		Effects.Sparks(holder, Theme.Color.Gold, 24, 1)
		if MetaClient.OnGranted and answer.Granted then
			MetaClient.OnGranted(answer.Granted)
		end
	else
		local reason = if ok and answer then answer.Reason else nil
		result.Text = REASONS[reason] or "Couldn't redeem it, try again"
		result.TextColor3 = Theme.Color.Danger
	end
end

-- Builds the codes box into `parent` (a list) at LayoutOrder `order`.
function Codes.Build(parent: Instance, order: number)
	holder = Kit.tile({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 150), Parent = parent }, Theme.Color.Gold)
	Kit.label({
		Text = "Got a code? Type it here for free packs, potions and Shards!",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 16, 0, 12),
		Size = UDim2.new(1, -32, 0, 22),
		Parent = holder,
	}, 18)
	local field = Kit.new("Frame", {
		Position = UDim2.new(0, 16, 0, 44),
		Size = UDim2.new(1, -230, 0, 50),
		BackgroundColor3 = Theme.Color.Panel,
		Parent = holder,
	}, { Kit.corner(), Kit.stroke(Theme.Color.Line, 1.2, 0) })
	box = Kit.new("TextBox", {
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Theme.Color.Muted,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Display,
		TextSize = 24,
		ClearTextOnFocus = false,
		Parent = field,
	})
	box.Focused:Connect(function()
		field.UIStroke.Color = Theme.Color.Neon
	end)
	box.FocusLost:Connect(function(enter)
		field.UIStroke.Color = Theme.Color.Line
		if enter then
			redeem()
		end
	end)
	local button = Kit.button("REDEEM", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 44),
		Size = UDim2.fromOffset(190, 50),
		Parent = holder,
	})
	button.Activated:Connect(redeem)
	result = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 16, 0, 104),
		Size = UDim2.new(1, -32, 0, 34),
		Parent = holder,
	}, 18)
end

-- Clears the last result (the STORE calls this when it opens).
function Codes.Reset()
	if result then
		result.Text = ""
	end
end

return Codes
