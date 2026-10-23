--!strict
-- Robux passes and products, in one place. Paste the live ids from the Creator Dashboard over the 0s.
-- While an id is 0 (or MockPurchases is on in Studio / test mode), BUY grants the pass for this save
-- without Robux (MonetizationService), so every perk can be tried before the passes exist.
--
-- Paid random items (Roblox policy, see CLAUDE.md): anything bought with Robux that changes odds or hands
-- out random rewards is a paid random item. Every perk marked Random below only works when
-- PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted is false for that
-- player; where it's true they still get the deterministic perks (Shards, XP, presets, name tag, speed),
-- the random ones are shown greyed out, and the Luck Totem can't be bought there at all. Odds stay
-- visible in the ODDS panel (every outcome, summing to 100%), and the STORE links to it.

local MonetizationConfig = {}

MonetizationConfig.FAST_ROLL_PASS_ID = 0
MonetizationConfig.AUTO_ROLL_PASS_ID = 0
MonetizationConfig.TRIPLE_ROLL_PASS_ID = 0
MonetizationConfig.VIP_PASS_ID = 0
MonetizationConfig.SERVER_TOTEM_PRODUCT_ID = 0

-- Studio / test mode: BUY grants without Robux when the id is still 0, or always when this is on.
MonetizationConfig.MockPurchases = true

export type Perk = { Text: string, Random: boolean? }
export type Pass = {
	Key: string,
	Name: string,
	Icon: string,
	Price: number, -- Robux, shown on the button (set it to the dashboard price)
	Color: Color3,
	Perks: { Perk },
}

MonetizationConfig.Passes = {
	{
		Key = "FastRoll",
		Name = "Fast Roll",
		Icon = "⚡",
		Price = 149,
		Color = Color3.fromRGB(80, 180, 255),
		Perks = { { Text = "-30% roll cooldown" } },
	},
	{
		Key = "AutoRoll",
		Name = "Auto Roll+",
		Icon = "🔁",
		Price = 199,
		Color = Color3.fromRGB(86, 214, 138),
		Perks = {
			{ Text = "Auto Roll open from the start" },
			{ Text = "Auto Roll hits every Overcharge Surge perfectly (3 cards, Epic+)", Random = true },
		},
	},
	{
		Key = "TripleRoll",
		Name = "Triple Roll",
		Icon = "🎴",
		Price = 399,
		Color = Color3.fromRGB(190, 110, 255),
		Perks = {
			{ Text = "Every ROLL click rolls 3 cards", Random = true },
			{ Text = "Roll Packs open 3x faster" },
		},
	},
	{
		Key = "VIP",
		Name = "VIP",
		Icon = "👑",
		Price = 799,
		Color = Color3.fromRGB(255, 196, 46),
		Perks = {
			{ Text = "+25% Shards" },
			{ Text = "+25% XP" },
			{ Text = "+2 deck presets" },
			{ Text = "Golden name tag" },
			{ Text = "+25% Trait Shards", Random = true },
			{ Text = "x2 luck", Random = true },
		},
	},
} :: { Pass }

MonetizationConfig.PassByKey = {} :: { [string]: Pass }
for _, pass in MonetizationConfig.Passes do
	MonetizationConfig.PassByKey[pass.Key] = pass
end

-- Which id each pass uses.
function MonetizationConfig.PassId(key: string): number
	if key == "FastRoll" then
		return MonetizationConfig.FAST_ROLL_PASS_ID
	elseif key == "AutoRoll" then
		return MonetizationConfig.AUTO_ROLL_PASS_ID
	elseif key == "TripleRoll" then
		return MonetizationConfig.TRIPLE_ROLL_PASS_ID
	elseif key == "VIP" then
		return MonetizationConfig.VIP_PASS_ID
	end
	return 0
end

-- The perks' numbers (MonetizationService and the shared formulas read these).
MonetizationConfig.FastRollCut = 0.3
MonetizationConfig.TripleRollCards = 3
MonetizationConfig.TriplePackSpeed = 3
MonetizationConfig.VipShards = 0.25
MonetizationConfig.VipXP = 0.25
MonetizationConfig.VipTraitShards = 0.25
MonetizationConfig.VipLuck = 2

-- The Server Luck Totem (a repeatable developer product): it stands in town and gives the whole server
-- x2 luck for TotemSeconds (a second one adds time); the buyer also gets TotemPacks + TotemTraitShards.
MonetizationConfig.Totem = {
	Name = "Server Luck Totem",
	Icon = "🗿",
	Price = 99,
	Luck = 2,
	Seconds = 600,
	MaxSeconds = 3600, -- stacked totems run at most an hour ahead
	Packs = { ["100"] = 2 },
	TraitShards = 50,
}

return MonetizationConfig
