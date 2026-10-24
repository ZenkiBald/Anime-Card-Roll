--!nonstrict
-- Deck presets: save, switch and auto-build. Every deck a client sends goes through
-- Deck.Validate (4 + 4 slots, right types, no copies, owned cards only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Deck = require(Shared.Deck)
local Bosses = require(Shared.Bosses)
local Tower = require(Shared.Tower)
local Raid = require(Shared.Raid)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)
local MonetizationService = require(script.Parent.MonetizationService)

local DeckService = {}

local limiter = RateLimit.new(8, 16)

-- How many presets a player has (the VIP pass adds Config.Deck.VipPresets).
function DeckService.PresetCount(player: Player?): number
	return Config.Deck.Presets + (if player then MonetizationService.ExtraPresets(player) else 0)
end

-- What the client gets: all presets (cleaned of cards no longer owned) and the active one.
function DeckService.State(data, player: Player?)
	local presets = {}
	for i = 1, DeckService.PresetCount(player) do
		presets[i] = Deck.Clean(data.Decks.Presets[i] or Deck.Empty(), data.Cards)
	end
	return { Active = data.Decks.Active, Presets = presets }
end

-- The deck a fight starts with.
function DeckService.Active(data)
	return Deck.Clean(data.Decks.Presets[data.Decks.Active] or Deck.Empty(), data.Cards)
end

local function validPreset(player: Player, preset: unknown): boolean
	return type(preset) == "number" and preset == math.floor(preset) and preset >= 1 and preset <= DeckService.PresetCount(player)
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
		if not validPreset(player, preset) then
			return { Ok = false, Reason = "BadRequest" }
		end
		local data = profile.Data
		if action == "Save" then
			local clean, reason = Deck.Validate(deck, data.Cards)
			if clean == nil then
				return { Ok = false, Reason = reason, Decks = DeckService.State(data, player) }
			end
			data.Decks.Presets[preset] = clean
		elseif action == "Select" then
			data.Decks.Active = preset
		elseif action == "AutoBuild" then
			-- `deck` may name the fight to counter-build for: a boss id, the tower (its next floor) or the raid.
			local against = nil
			if type(deck) == "string" then
				if deck == Tower.Id or deck == Tower.PagodaId then
					local floor = if deck == Tower.Id
						then Tower.FloorAt(data.Tower.Run + 1)
						else Tower.FloorAt(math.min(Tower.Pagoda.Floors, data.Pagoda.Floor + 1), nil, nil, Tower.PagodaId)
					against = Bosses.SquadElements(floor.Boss, floor.Guards)
				elseif deck == Raid.Id then
					local forced = ReplicatedStorage:GetAttribute("DevRaidEnds")
					local w = Raid.At(workspace:GetServerTimeNow(), if type(forced) == "number" then { Ends = forced } else nil)
					against = Bosses.SquadElements(w.Colossus.Boss, {})
				elseif Bosses.Get(deck) then
					against = Bosses.SquadElements(deck)
				end
			end
			data.Decks.Presets[preset] = Deck.AutoBuild(data.Cards, against)
		else
			return { Ok = false, Reason = "BadRequest" }
		end
		return { Ok = true, Decks = DeckService.State(data, player) }
	end
end

return DeckService
