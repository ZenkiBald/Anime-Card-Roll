--!strict
-- Server entry point.

local Meta = require(game:GetService("ReplicatedStorage").Shared.Meta)
local World = require(script.Parent.World)
local DataService = require(script.Parent.DataService)
local RollService = require(script.Parent.RollService)
local DeckService = require(script.Parent.DeckService)
local BattleService = require(script.Parent.BattleService)
local MetaService = require(script.Parent.MetaService)
local TravelService = require(script.Parent.TravelService)
local FusionService = require(script.Parent.FusionService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MountService = require(script.Parent.MountService)
local NameTagService = require(script.Parent.NameTagService)
local AvatarService = require(script.Parent.AvatarService)
local ProfileService = require(script.Parent.ProfileService)
local CodeService = require(script.Parent.CodeService)
local RaidService = require(script.Parent.RaidService)
local MonetizationService = require(script.Parent.MonetizationService)
local TraitService = require(script.Parent.TraitService)
local Momentum = require(script.Parent.Momentum)
local TutorialService = require(script.Parent.TutorialService)
local GlobalAnnounce = require(script.Parent.GlobalAnnounce)
local CollectionService = require(script.Parent.CollectionService)
local WeatherService = require(script.Parent.WeatherService)

World.Build()
GlobalAnnounce.Start()
BattleService.SetRewardHandler(RollService.RewardRolls, RollService.TowerRewards)
RaidService.SetPayer(RollService.RaidRewards, RollService.RaidRewardsOffline)
-- Saved messages (e.g. a raid payout from while the player was away) are granted as they load.
DataService.SetMessageHandler(function(player, profile, message)
	if type(message) == "table" and message.Kind == "Grant" and type(message.Bundle) == "table" then
		local granted = MetaService.Grant(profile.Data, message.Bundle, nil)
		task.delay(8, function() -- after the client has loaded
			if player.Parent then
				game:GetService("ReplicatedStorage").Remotes.RaidState:FireClient(player, {
					Payout = {
						Cleared = true,
						Offline = true,
						Name = message.Note or "the raid",
						Reward = {
							Bundle = granted,
							NewPacks = message.Bundle.Packs,
							Packs = profile.Data.Packs,
							Meta = MetaService.State(player, profile.Data),
						},
					},
				})
				RollService.PushSummary(player) -- the top bar's Shards
			end
		end)
	end
end)
-- While you were away: Roll Packs and Shards for time offline (Meta.OfflineReward), shown once loaded.
DataService.SetAwayHandler(function(player: Player, profile: any, seconds: number)
	local reward = Meta.OfflineReward(seconds)
	if reward == nil then
		return
	end
	local granted = MetaService.Grant(profile.Data, { Shards = reward.Shards, Packs = reward.Packs }, player)
	task.delay(8, function() -- after the client has loaded
		if player.Parent then
			game:GetService("ReplicatedStorage").Remotes.RaidState:FireClient(player, {
				Payout = {
					Away = reward.Seconds,
					Reward = {
						Bundle = granted,
						NewPacks = reward.Packs,
						Packs = profile.Data.Packs,
						Meta = MetaService.State(player, profile.Data),
					},
				},
			})
			RollService.PushSummary(player)
		end
	end)
end)
MonetizationService.SetGranter(MetaService.Grant)
Momentum.Configure(BattleService.InBattle, function(player)
	RollService.PushSummary(player) -- the chain broke: the HUD meter drops
end)
RollService.Start()
CollectionService.Start()
WeatherService.Start()
DeckService.Start()
MetaService.Start()
BattleService.Start()
TravelService.Start()
FusionService.Start()
LeaderboardService.Start()
MountService.Start()
NameTagService.Start()
AvatarService.Start()
ProfileService.Start()
CodeService.Start()
RaidService.Start()
MonetizationService.Start()
TraitService.Start()
Momentum.Start()
TutorialService.Start()
DataService.Start()
