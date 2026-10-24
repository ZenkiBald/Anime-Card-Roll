--!nonstrict
-- Robux passes and the Server Luck Totem (MonetizationConfig.luau has the ids, prices and perk numbers).
--
--   * Owns(player, key): the pass is owned (MarketplaceService, cached per session) or was mock-bought
--     (Studio / test mode while the id is 0: saved in MockPasses so it survives a rejoin).
--   * Perk(player, key, random): owns it, and for a Random perk only where paid random items are allowed
--     (PolicyService ArePaidRandomItemsRestricted, fetched once per player; unknown counts as restricted).
--   * The totem: ProcessReceipt grants it once per purchase id (saved in Purchases), stands a totem model
--     in town and runs server luck x2 (attribute TotemLuckEnds, read by MetaService.Luck and the HUD).
--   * Shard bundles: ProcessReceipt grants their Shards once per purchase id, like the totem; sold only
--     where paid random items are allowed (Shards buy luck potions and upgrades).
-- STORE remote (RemoteFunction "Store"): "State" | "Buy" (pass key) | "BuyTotem" | "BuyShards" (bundle
-- key). StoreState (event) pushes the new state after a real purchase lands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MonetizationConfig = require(Shared.MonetizationConfig)

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local DevAccess = require(script.Parent.DevAccess)
local RateLimit = require(script.Parent.RateLimit)

local MonetizationService = {}

local owned = {} -- [Player] = { [key] = true } from MarketplaceService
local restricted = {} -- [Player] = boolean (nil until the policy arrives)
local limiter = RateLimit.new(2, 4)
local totemModel = nil

-- Pays the totem's buyer bundle (set by Main.server to MetaService.Grant, which needs this module).
local granter: ((data: any, bundle: any, player: Player?) -> any)? = nil

function MonetizationService.SetGranter(fn)
	granter = fn
end

-- Mock buys (free, saved in MockPasses) only for test tool users (DevAccess): never for players in a
-- published game, even one left in test mode.
local function mockAllowed(player: Player, id: number): boolean
	return DevAccess.Allowed(player) and (id == 0 or MonetizationConfig.MockPurchases)
end

function MonetizationService.Restricted(player: Player): boolean
	local value = restricted[player]
	return value ~= false -- unknown (still loading, or the call failed) counts as restricted
end

function MonetizationService.Owns(player: Player, key: string): boolean
	if owned[player] and owned[player][key] then
		return true
	end
	local profile = DataService.Get(player)
	return profile ~= nil and profile.Data.MockPasses ~= nil and profile.Data.MockPasses[key] == true
end

-- A perk of pass `key`: owned, and if `random` (a paid random item), allowed for this player.
function MonetizationService.Perk(player: Player, key: string, random: boolean?): boolean
	if not MonetizationService.Owns(player, key) then
		return false
	end
	return not random or not MonetizationService.Restricted(player)
end

-- Perk numbers --------------------------------------------------------------------------------------

function MonetizationService.CooldownCut(player: Player): number
	return if MonetizationService.Perk(player, "FastRoll") then MonetizationConfig.FastRollCut else 0
end

function MonetizationService.VipLuck(player: Player): number
	return if MonetizationService.Perk(player, "VIP", true) then MonetizationConfig.VipLuck else 1
end

function MonetizationService.ShardBonus(player: Player?): number
	return if player and MonetizationService.Perk(player, "VIP") then MonetizationConfig.VipShards else 0
end

function MonetizationService.XPBonus(player: Player?): number
	return if player and MonetizationService.Perk(player, "VIP") then MonetizationConfig.VipXP else 0
end

function MonetizationService.TraitShardBonus(player: Player?): number
	return if player and MonetizationService.Perk(player, "VIP", true) then MonetizationConfig.VipTraitShards else 0
end

function MonetizationService.ExtraPresets(player: Player): number
	return if MonetizationService.Perk(player, "VIP") then Config.Deck.VipPresets else 0
end

-- The server-wide totem luck right now.
function MonetizationService.TotemLuck(): number
	local ends = ReplicatedStorage:GetAttribute("TotemLuckEnds")
	return if type(ends) == "number" and ends > workspace:GetServerTimeNow() then MonetizationConfig.Totem.Luck else 1
end

-- State for the STORE -------------------------------------------------------------------------------

function MonetizationService.State(player: Player)
	local passes = {}
	for _, pass in MonetizationConfig.Passes do
		passes[pass.Key] = MonetizationService.Owns(player, pass.Key)
	end
	local ends = ReplicatedStorage:GetAttribute("TotemLuckEnds")
	return {
		Ok = true,
		Passes = passes,
		Restricted = MonetizationService.Restricted(player),
		Mock = mockAllowed(player, 0),
		TotemEnds = if type(ends) == "number" then ends else nil,
	}
end

local function refreshPlayer(player: Player)
	player:SetAttribute("VIP", MonetizationService.Perk(player, "VIP"))
	if player.Parent == Players then
		Remotes.StoreState:FireClient(player, MonetizationService.State(player))
	end
end

-- The totem ------------------------------------------------------------------------------------------

-- A glowing stone totem by the town spawn while the luck runs.
local function showTotem()
	if totemModel and totemModel.Parent then
		return
	end
	local hub = workspace:FindFirstChild("Hub")
	local spawn = hub and hub:FindFirstChild("Spawn")
	local base = if spawn and spawn:IsA("BasePart") then spawn.CFrame * CFrame.new(0, 0, -14) else CFrame.new(0, 3, -14)
	local model = Instance.new("Model")
	model.Name = "LuckTotem"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, neon: boolean)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = if neon then Enum.Material.Neon else Enum.Material.Slate
		part.Parent = model
		return part
	end
	block("Base", Vector3.new(5, 1, 5), base, Color3.fromRGB(70, 60, 90), false)
	for i = 1, 3 do
		block(`Stone{i}`, Vector3.new(3 - i * 0.5, 2.2, 3 - i * 0.5), base * CFrame.new(0, 1.6 + (i - 1) * 2.2, 0), Color3.fromRGB(110, 96, 140), false)
	end
	local gem = block("Gem", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 8.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(110, 255, 160), true)
	gem:SetAttribute("Spin", true) -- HubFx spins parts marked Spin
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(110, 255, 160)
	light.Range = 18
	light.Parent = gem
	model.Parent = hub or workspace
	totemModel = model
end

local function startTotem(buyer: Player?)
	local now = workspace:GetServerTimeNow()
	local ends = ReplicatedStorage:GetAttribute("TotemLuckEnds")
	local from = if type(ends) == "number" and ends > now then ends else now
	local cfg = MonetizationConfig.Totem
	ReplicatedStorage:SetAttribute("TotemLuckEnds", math.min(now + cfg.MaxSeconds, from + cfg.Seconds))
	ReplicatedStorage:SetAttribute("TotemBuyer", if buyer then buyer.DisplayName else nil)
	showTotem()
	-- Everyone hears about it (the HUD's luck pill shows the timer from the attribute).
	Remotes.StoreState:FireAllClients({ Totem = { Buyer = if buyer then buyer.DisplayName else "Someone", Ends = ReplicatedStorage:GetAttribute("TotemLuckEnds") } })
end

-- Gives the buyer their totem bundle (deterministic for the buyer: fixed packs and Trait Shards).
local function payTotem(player: Player)
	local profile = DataService.Get(player)
	if profile and granter then
		granter(profile.Data, { Packs = MonetizationConfig.Totem.Packs, TraitShards = MonetizationConfig.Totem.TraitShards }, player)
	end
	startTotem(player)
end

-- The bundle a product id sells (nil = not a Shard bundle).
local function bundleFor(productId: number)
	for _, bundle in MonetizationConfig.ShardBundles do
		if bundle.ProductId ~= 0 and bundle.ProductId == productId then
			return bundle
		end
	end
	return nil
end

local function payShards(player: Player, bundle)
	local profile = DataService.Get(player)
	if profile and granter then
		granter(profile.Data, { Shards = bundle.Shards }, player)
	end
end

local function processReceipt(receipt)
	local bundle = bundleFor(receipt.ProductId)
	local totem = MonetizationConfig.SERVER_TOTEM_PRODUCT_ID ~= 0 and receipt.ProductId == MonetizationConfig.SERVER_TOTEM_PRODUCT_ID
	if not totem and bundle == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Get(player)
	if player == nil or profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	local purchases = profile.Data.Purchases
	if purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already paid out
	end
	purchases[receipt.PurchaseId] = os.time()
	if bundle then
		payShards(player, bundle)
	else
		payTotem(player)
	end
	refreshPlayer(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Remotes ---------------------------------------------------------------------------------------------

local function buy(player: Player, key: unknown)
	local pass = if type(key) == "string" then MonetizationConfig.PassByKey[key] else nil
	if pass == nil then
		return { Ok = false, Reason = "BadRequest" }
	end
	if MonetizationService.Owns(player, pass.Key) then
		return { Ok = false, Reason = "Owned" }
	end
	local id = MonetizationConfig.PassId(pass.Key)
	if mockAllowed(player, id) then
		local profile = DataService.Get(player)
		if profile == nil then
			return { Ok = false, Reason = "Loading" }
		end
		profile.Data.MockPasses[pass.Key] = true
		refreshPlayer(player)
		return { Ok = true, Mock = true, State = MonetizationService.State(player) }
	end
	if id == 0 then
		return { Ok = false, Reason = "NotForSale" }
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
	return { Ok = true, Prompted = true }
end

local function buyTotem(player: Player)
	if MonetizationService.Restricted(player) then
		return { Ok = false, Reason = "Restricted" } -- random rewards for Robux: not offered here
	end
	local id = MonetizationConfig.SERVER_TOTEM_PRODUCT_ID
	if mockAllowed(player, id) then
		payTotem(player)
		return { Ok = true, Mock = true, State = MonetizationService.State(player) }
	end
	if id == 0 then
		return { Ok = false, Reason = "NotForSale" }
	end
	MarketplaceService:PromptProductPurchase(player, id)
	return { Ok = true, Prompted = true }
end

local function buyShards(player: Player, key: unknown)
	local bundle = if type(key) == "string" then MonetizationConfig.BundleByKey[key] else nil
	if bundle == nil then
		return { Ok = false, Reason = "BadRequest" }
	end
	if MonetizationService.Restricted(player) then
		return { Ok = false, Reason = "Restricted" } -- Shards buy luck: not sold for Robux here
	end
	if mockAllowed(player, bundle.ProductId) then
		payShards(player, bundle)
		return { Ok = true, Mock = true, State = MonetizationService.State(player) }
	end
	if bundle.ProductId == 0 then
		return { Ok = false, Reason = "NotForSale" }
	end
	MarketplaceService:PromptProductPurchase(player, bundle.ProductId)
	return { Ok = true, Prompted = true }
end

local function loadPlayer(player: Player)
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		restricted[player] = if ok and info then info.ArePaidRandomItemsRestricted == true else true
		refreshPlayer(player)
	end)
	task.spawn(function()
		local found = {}
		for _, pass in MonetizationConfig.Passes do
			local id = MonetizationConfig.PassId(pass.Key)
			if id ~= 0 then
				local ok, has = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
				end)
				if ok and has then
					found[pass.Key] = true
				end
			end
		end
		owned[player] = found
		DataService.WaitFor(player, 20)
		refreshPlayer(player)
	end)
end

function MonetizationService.Start()
	Remotes.Store.OnServerInvoke = function(player: Player, action: unknown, key: unknown)
		if action ~= "State" and not limiter:Allow(player) then
			return { Ok = false, Reason = "TooFast" }
		end
		if action == "State" then
			return MonetizationService.State(player)
		elseif action == "Buy" then
			return buy(player, key)
		elseif action == "BuyTotem" then
			return buyTotem(player)
		elseif action == "BuyShards" then
			return buyShards(player, key)
		end
		return { Ok = false, Reason = "BadRequest" }
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		for _, pass in MonetizationConfig.Passes do
			if MonetizationConfig.PassId(pass.Key) == passId then
				owned[player] = owned[player] or {}
				owned[player][pass.Key] = true
			end
		end
		refreshPlayer(player)
	end)
	MarketplaceService.ProcessReceipt = processReceipt

	for _, player in Players:GetPlayers() do
		loadPlayer(player)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
		restricted[player] = nil
	end)

	-- The totem stands while its luck runs.
	task.spawn(function()
		while true do
			task.wait(2)
			if totemModel and MonetizationService.TotemLuck() <= 1 then
				totemModel:Destroy()
				totemModel = nil
			end
		end
	end)
end

return MonetizationService
