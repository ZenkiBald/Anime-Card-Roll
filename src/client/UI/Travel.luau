--!nonstrict
-- TRAVEL: jump to the town or a boss zone. The server picks the spot and moves you (TravelService);
-- this panel only asks. One tile per stop: the town, then every boss's world from Bosses.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared.Bosses)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)
local ZoneFx = require(script.Parent.Parent.ZoneFx)
local HubFx = require(script.Parent.Parent.HubFx)

local Travel = {}

local modal
local hint: (string) -> () = function() end
local here = {} -- [zone] = "YOU ARE HERE" label
local lastTravel = -math.huge
local COOLDOWN = 2 -- matches the server's rate limit

-- Emoji per boss particle theme (no icon art for worlds yet).
local WORLD_ICONS = { Embers = "🏮", Snow = "🏔️", Motes = "🌌", Rain = "⚡" }

local function stops()
	local list = {
		{ Id = "Town", Zone = "Town", Name = "Spawn Town", Sub = "Fountain plaza · Kenji the Card Sage", Accent = Theme.Color.Gold, Icon = "⛲" },
	}
	for _, boss in Bosses.List do
		table.insert(list, {
			Id = boss.Id,
			Zone = (boss.WorldName:gsub(" ", "")), -- ZoneFx names zones like "EmberVillage"
			Name = boss.WorldName,
			Sub = `World {boss.World} · {boss.Name}`,
			Accent = boss.Accent,
			Icon = WORLD_ICONS[boss.Particles] or "⚔️",
		})
	end
	return list
end

local function go(stop)
	if State.InBattle then
		return
	end
	if os.clock() - lastTravel < COOLDOWN then
		hint("Catching your breath...")
		return
	end
	lastTravel = os.clock()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position
	Remotes.Travel:FireServer(stop.Id)
	modal:Close()
	hint(`Traveling to {stop.Name}`)
	-- Once the server has moved us, swing the camera round to face the boss (or the fountain).
	if root and from then
		task.spawn(function()
			local deadline = os.clock() + 4
			while os.clock() < deadline and root.Parent and (root.Position - from).Magnitude < 20 do
				task.wait(0.1)
			end
			if root.Parent and (root.Position - from).Magnitude >= 20 then
				HubFx.CameraBehind(character)
			end
		end)
	end
end

function Travel.Init(playerGui: Instance, showHint: (string) -> ())
	hint = showHint
	-- Two stops per row; the panel grows a row for every two worlds.
	local rows = math.ceil(#stops() / 2)
	modal = Modal.new(
		playerGui,
		"TravelGui",
		"TRAVEL",
		Vector2.new(0.62, math.min(0.9, 0.24 + 0.2 * rows)),
		Vector2.new(700, 110 + 175 * rows)
	)
	local grid = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -7, 1 / rows, -9),
			CellPadding = UDim2.fromOffset(14, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 6),
		}),
	})
	for i, stop in stops() do
		local tile = Kit.tile({ Name = stop.Id, LayoutOrder = i, Parent = grid }, stop.Accent, "TextButton")
		Kit.label({
			Text = stop.Icon,
			Font = Theme.Font.Heavy,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.new(0.26, 0, 0.62, 0),
			Parent = tile,
		}, 64)
		local name = Kit.label({
			Text = stop.Name,
			Font = Theme.Font.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0.3, 0, 0.2, 0),
			Size = UDim2.new(0.66, 0, 0.3, 0),
			Parent = tile,
		}, 32)
		Kit.textStroke(Color3.fromRGB(13, 17, 27), 2.5, 0).Parent = name
		Kit.label({
			Text = stop.Sub,
			Font = Theme.Font.Heavy,
			TextColor3 = stop.Accent:Lerp(Color3.new(1, 1, 1), 0.45),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0.3, 0, 0.52, 0),
			Size = UDim2.new(0.66, 0, 0.17, 0),
			Parent = tile,
		}, 17)
		here[stop.Zone] = Kit.label({
			Text = "YOU ARE HERE",
			Font = Theme.Font.Heavy,
			TextColor3 = Color3.fromRGB(120, 240, 160),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0.3, 0, 0.72, 0),
			Size = UDim2.new(0.66, 0, 0.13, 0),
			Visible = false,
			Parent = tile,
		}, 14)
		tile.Activated:Connect(function()
			go(stop)
		end)
	end
	modal.OnOpen = function()
		local current = ZoneFx.Current()
		for zone, label in here do
			label.Visible = zone == current
		end
	end
end

function Travel.Toggle()
	if State.InBattle then
		return
	end
	modal:Toggle()
end

return Travel
