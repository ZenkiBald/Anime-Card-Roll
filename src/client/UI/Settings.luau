--!nonstrict
-- SETTINGS: Music and Effects volume in steps (saved in the player's profile through MetaService)
-- and effects quality (HIGH / LOW, for this session; phones start on LOW).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Controls = require(script.Parent.Controls)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local MetaClient = require(script.Parent.Parent.MetaClient)

local Settings = {}

local modal
local rows = {} -- [key] = { [value] = set(on) }
local volume = { Music = 1, Effects = 1 }

local function stepText(step: number): string
	return if step == 0 then "OFF" else `{math.floor(step * 100 + 0.5)}%`
end

-- Lights the pill for `value` in a row and greys the rest.
local function show(key: string, value: any)
	for option, set in rows[key] do
		set(option == value)
	end
end

local function apply()
	Sfx.SetMusicVolume(volume.Music)
	Sfx.SetEffectsVolume(volume.Effects)
end

-- A captioned row of pills; `onPick` gets the option tapped.
local function row(order: number, key: string, caption: string, color: Color3, options: { any }, label: (any) -> string, onPick: (any) -> ())
	local frame = Kit.new("Frame", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
		Parent = modal.Body,
	})
	local title = Kit.label({
		Text = caption,
		Font = Theme.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 4, 0, 0),
		Size = UDim2.new(1, -8, 0, 32),
		Parent = frame,
	}, 28)
	Kit.textStroke(Color3.fromRGB(30, 12, 70), 2, 0).Parent = title
	local pills = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	rows[key] = {}
	for i, option in options do
		local button, set = Controls.Tab(pills, label(option), color, i)
		button.Size = UDim2.new(1 / #options, -8 * (#options - 1) / #options, 1, 0)
		button.Activated:Connect(function()
			onPick(option)
		end)
		rows[key][option] = set
	end
end

local function pickVolume(key: string, step: number)
	volume[key] = step
	apply()
	show(key, step)
	if key == "Effects" then
		Sfx.Play("Chime") -- hear the new level
	end
	task.spawn(MetaClient.Call, if key == "Music" then "SetMusic" else "SetEffects", step)
end

-- Takes the saved levels from the player's state (call after it loads).
function Settings.Load()
	local saved = State.Meta and State.Meta.Volume
	if saved then
		volume.Music = if type(saved.Music) == "number" then saved.Music else 1
		volume.Effects = if type(saved.Effects) == "number" then saved.Effects else 1
	end
	apply()
	if modal then
		show("Music", volume.Music)
		show("Effects", volume.Effects)
	end
end

function Settings.Init(playerGui: Instance)
	modal = Modal.new(playerGui, "SettingsGui", "SETTINGS", Vector2.new(0.56, 0.62), Vector2.new(640, 440))
	Kit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), Parent = modal.Body })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = modal.Body })
	row(1, "Music", "🎵  MUSIC", Theme.Color.Auto, Config.VolumeSteps, stepText, function(step)
		pickVolume("Music", step)
	end)
	row(2, "Effects", "🔊  SOUND EFFECTS", Theme.Color.Quick, Config.VolumeSteps, stepText, function(step)
		pickVolume("Effects", step)
	end)
	row(3, "Quality", "✨  EFFECTS QUALITY", Theme.Color.Gold, { "HIGH", "LOW" }, function(option)
		return option
	end, function(option)
		Theme.FxLow = option == "LOW"
		show("Quality", option)
	end)
	modal.OnOpen = function()
		show("Music", volume.Music)
		show("Effects", volume.Effects)
		show("Quality", if Theme.FxLow then "LOW" else "HIGH")
	end
	Settings.Load()
end

function Settings.Toggle()
	modal:Toggle()
end

return Settings
