--!strict
-- Avatar auras: the card a player wears as their avatar (EQUIP AS AVATAR, MetaService "SetAvatar" ->
-- Settings.Avatar) shows on their character as that card's element aura, plus fire footsteps (Rainbow
-- border) or celestial motes (Secret border) while walking (client `Avatars.luau` draws them).
-- Apply() runs the moment the avatar changes: it sets the character attributes AvatarCard /
-- AvatarElement / AvatarBorder (the state players who join later read) and fires AuraReplication to
-- every client with (character, cardId, border) so they redraw at once. It also runs on respawn and when
-- the worn card's best border changes (fusion); a slow safety pass catches anything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cards = require(Shared.Cards)
local Borders = require(Shared.Borders)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)

local AvatarService = {}

local SAFETY_SECONDS = 10

-- The aura a player should show now: (cardId, element, border), or all nil for none.
local function wanted(player: Player): (string?, string?, string?)
	local profile = DataService.Get(player)
	if profile == nil then
		return nil, nil, nil
	end
	local id = profile.Data.Settings.Avatar or ""
	local card = Cards.Get(id)
	local entry = profile.Data.Cards[id]
	if card == nil or entry == nil then
		return nil, nil, nil
	end
	return id, card.Element, Borders.Best(entry.Borders)
end

-- Puts the player's avatar aura on their character and tells every client, if it changed (`force`
-- sends it anyway, e.g. to answer an equip the client already predicted).
function AvatarService.Apply(player: Player, force: boolean?)
	local character = player.Character
	if character == nil then
		return
	end
	local id, element, border = wanted(player)
	local changed = character:GetAttribute("AvatarCard") ~= id or character:GetAttribute("AvatarBorder") ~= border
	if not changed and not force then
		return
	end
	character:SetAttribute("AvatarCard", id)
	character:SetAttribute("AvatarElement", element)
	character:SetAttribute("AvatarBorder", border)
	Remotes.AuraReplication:FireAllClients(character, id or "", border or "Normal")
end

function AvatarService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			AvatarService.Apply(player, true)
		end)
		if player.Character then
			task.spawn(AvatarService.Apply, player, true)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	-- Safety pass (sends only on a change): a profile that loaded after the character spawned, or a
	-- border found on the worn card by a roll.
	task.spawn(function()
		while true do
			task.wait(SAFETY_SECONDS)
			for _, player in Players:GetPlayers() do
				AvatarService.Apply(player)
			end
		end
	end)
end

return AvatarService
