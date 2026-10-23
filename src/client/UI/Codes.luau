--!nonstrict
-- CODES: type a code, REDEEM, and its reward lands at once (a toast shows what). Each code works once
-- per player; the server checks everything (CodeService, codes kept server-side in Codes.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meta = require(Shared.Meta)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
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

local modal
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
		Effects.Sparks(modal.Panel, Theme.Color.Gold, 24, 1)
		if MetaClient.OnGranted and answer.Granted then
			MetaClient.OnGranted(answer.Granted)
		end
	else
		local reason = if ok and answer then answer.Reason else nil
		result.Text = REASONS[reason] or "Couldn't redeem it, try again"
		result.TextColor3 = Theme.Color.Danger
	end
end

function Codes.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "CodesGui", "CODES", Vector2.new(0.5, 0.5), Vector2.new(560, 340))
	Kit.label({
		Text = "Got a code? Type it here for free packs, potions and Shards!",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Text,
		Position = UDim2.new(0, 0, 0, 6),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = modal.Body,
	}, 18)
	local field = Kit.new("Frame", {
		Position = UDim2.new(0.05, 0, 0, 44),
		Size = UDim2.new(0.9, 0, 0, 54),
		BackgroundColor3 = Color3.fromRGB(16, 10, 34),
		Parent = modal.Body,
	}, { Kit.corner(UDim.new(0.3, 0)), Kit.stroke(Theme.Color.Gold, 2, 0.2) })
	box = Kit.new("TextBox", {
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -32, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Color3.fromRGB(150, 140, 190),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font.Display,
		TextSize = 28,
		ClearTextOnFocus = false,
		Parent = field,
	})
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
	local button = Kit.button("REDEEM", Theme.Color.Gold, Color3.fromRGB(150, 100, 10), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.new(0.5, 0, 0, 52),
		Parent = modal.Body,
	})
	button.Activated:Connect(redeem)
	result = Kit.label({
		Text = "",
		Font = Theme.Font.Heavy,
		TextColor3 = Theme.Color.Gold,
		TextWrapped = true,
		Position = UDim2.new(0, 0, 0, 176),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = modal.Body,
	}, 20)
	modal.OnOpen = function()
		result.Text = ""
	end
end

function Codes.Toggle()
	modal:Toggle()
end

return Codes
