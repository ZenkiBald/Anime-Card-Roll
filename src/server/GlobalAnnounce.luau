--!strict
-- Big pull announcements. Rainbow+ borders and Demon Seals go to everyone on this server (the HUD banner);
-- a SECRET border also goes to every other live server through MessagingService, so the whole game sees
-- "[GLOBAL] {Player} rolled a SECRET BORDER {Card}!". Secrets are 1 in 500,000 at base luck, far under
-- MessagingService's publish limits; every message from another server is checked before it's shown.

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)

local Remotes = ReplicatedStorage.Remotes

local GlobalAnnounce = {}

local TOPIC = "SecretPulls"
local GLOBAL_FROM = "Secret" -- borders from here up are announced in every server

-- Announces a big pull: this server always, every server for a Secret border.
function GlobalAnnounce.Pull(player: Player, cardId: string, border: string, foil: string?)
	Remotes.Announce:FireAllClients(player.DisplayName, cardId, border, foil)
	if Borders.Index(border) >= Borders.Index(GLOBAL_FROM) then
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(TOPIC, { Name = player.DisplayName, Card = cardId, Border = border, Job = game.JobId })
			end)
		end)
	end
end

function GlobalAnnounce.Start()
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) ~= "table" or data.Job == game.JobId then
					return -- this server already showed it
				end
				local name, cardId, border = data.Name, data.Card, data.Border
				if type(name) ~= "string" or #name > 40 or type(cardId) ~= "string" or Cards.Get(cardId) == nil then
					return
				end
				if type(border) ~= "string" or Borders.Index(border) < Borders.Index(GLOBAL_FROM) then
					return
				end
				Remotes.Announce:FireAllClients(name, cardId, border, nil, true)
			end)
		end)
	end)
end

return GlobalAnnounce
