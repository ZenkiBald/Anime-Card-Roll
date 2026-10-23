--!nonstrict
-- Deck presets: save, switch and auto-build. Every deck a client sends goes through
-- Deck.Validate (4 + 4 slots, right types, no copies, owned cards only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)

local DeckService = {}

local limiter = RateLimit.new(8, 16)

-- What the client gets: all presets (cleaned of cards no longer owned) and the active one.
function DeckService.State(data)
	local presets = {}
	for i = 1, Config.Deck.Presets do
		presets[i] = Deck.Clean(data.Decks.Presets[i] or Deck.Empty(), data.Cards)
	end
	return { Active = data.Decks.Active, Presets = presets }
end

-- The deck a fight starts with.
function DeckService.Active(data)
	return Deck.Clean(data.Decks.Presets[data.Decks.Active] or Deck.Empty(), data.Cards)
end

local function validPreset(preset: unknown): boolean
	return type(preset) == "number" and preset == math.floor(preset) and preset >= 1 and preset <= Config.Deck.Presets
end

function DeckService.Start()
	Remotes.Deck.OnServerInvoke = function(player: Player, action: unknown, preset: unknown, deck: unknown)
		if not limiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		if not validPreset(preset) then
			return { Ok = false, Reason = "BadRequest" }
		end
		local data = profile.Data
		if action == "Save" then
			local clean, reason = Deck.Validate(deck, data.Cards)
			if clean == nil then
				return { Ok = false, Reason = reason, Decks = DeckService.State(data) }
			end
			data.Decks.Presets[preset] = clean
		elseif action == "Select" then
			data.Decks.Active = preset
		elseif action == "AutoBuild" then
			data.Decks.Presets[preset] = Deck.AutoBuild(data.Cards)
		else
			return { Ok = false, Reason = "BadRequest" }
		end
		return { Ok = true, Decks = DeckService.State(data) }
	end
end

return DeckService
