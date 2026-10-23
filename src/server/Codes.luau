--!strict
-- Redeem codes (the CODES button). Server-only, so players can't read the list. Each code works once
-- per player; Expires (optional) is a Unix time after which it stops working. A reward is a Meta bundle
-- (Shards, TraitShards, Potions, Packs, Artifacts). Add a code = add one entry; codes are matched without caring
-- about upper / lower case.

export type Code = { Code: string, Reward: { [string]: any }, Expires: number? }

return {
	{ Code = "RELEASE", Reward = { Shards = 250, Packs = { ["10"] = 3 }, TraitShards = 20 } },
	{ Code = "LUCKY", Reward = { Potions = { luck = 3, superluck = 1 } } },
	{ Code = "TOWER", Reward = { Packs = { ["100"] = 1 } } },
	{ Code = "SQUAD", Reward = { Shards = 500, Potions = { speed = 2 } } },
	{ Code = "TRAITS", Reward = { TraitShards = 50 } },
	{ Code = "AWAKEN", Reward = { TraitShards = 25, Packs = { ["10"] = 5 } } },
} :: { Code }
