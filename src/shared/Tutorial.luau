--!strict
-- Kenji's first-session questline: six quests in order, each claimed for its reward before the next
-- opens. Shared so the HUD tracker shows exactly what the server counts (TutorialService).
--   Check kinds:  Rolls (lifetime rolls), Deck (cards in the active deck, Attack + Support),
--                 Clear (a fight key cleared), Flag (something the server noted: a Trait Master roll, a
--                 pack condensed, a Stagger broken by a counter element).
-- Saved as Tutorial = { Step, Flags, Supplied }; flags count whenever they happen, so doing a quest early
-- finishes it the moment it opens. Supply: given once when the quest opens, if the player is short
-- (the alchemy quest needs 10 Roll Packs, more than a new player has by then).
-- A new quest is one entry in Tutorial.Steps.

local Tutorial = {}

export type Bundle = { Shards: number?, TraitShards: number?, Potions: { [string]: number }?, Packs: { [string]: number }? }
export type Step = {
	Id: string,
	Name: string,
	Text: string,
	Kenji: string, -- what Kenji says when the quest opens
	Hint: string, -- where to go
	Check: string, -- Rolls | Deck | Clear | Flag
	Goal: number,
	Fight: string?, -- Clear: the Bosses.FightKey
	Flag: string?, -- Flag: the flag's name
	Supply: { Pack: string, Count: number }?, -- topped up to Count when the quest opens
	Reward: Bundle,
	Title: string?, -- a title the reward also unlocks
}

Tutorial.Steps = {
	{
		Id = "summon",
		Name = "First Summon",
		Text = "Roll 5 cards",
		Kenji = "Every legend starts with a pull. Press ROLL and see who answers!",
		Hint = "Press ROLL at the bottom",
		Check = "Rolls",
		Goal = 5,
		Reward = { Shards = 50, Potions = { superluck = 1 } },
	},
	{
		Id = "line",
		Name = "Assemble the Line",
		Text = "Fill your deck: 4 Attack + 4 Support",
		Kenji = "Four in front to fight, four behind to support. AUTO-BUILD does it in one tap.",
		Hint = "SQUAD > DECK > AUTO-BUILD",
		Check = "Deck",
		Goal = 8,
		Reward = { Packs = { ["10"] = 1 } },
	},
	{
		Id = "flame",
		Name = "Trial by Flame",
		Text = "Beat Kurogane on Normal",
		Kenji = "Kurogane waits in Ember Village. Storm cards burn brightest against Flame.",
		Hint = "BATTLE > BOSSES > World 1",
		Check = "Clear",
		Goal = 1,
		Fight = "kurogane:Normal",
		Reward = { TraitShards = 25, Shards = 100 },
	},
	{
		Id = "awaken",
		Name = "Awaken Potential",
		Text = "Roll a trait at Kenshin the Trait Master",
		Kenji = "Kenshin, beside Hoshi, turns Trait Shards into traits. Bring him the shards you just earned.",
		Hint = "Walk to Kenshin, or SQUAD > TRAITS",
		Check = "Flag",
		Goal = 1,
		Flag = "TraitRoll",
		Reward = { TraitShards = 15 },
	},
	{
		Id = "alchemy",
		Name = "Alchemy Master",
		Text = "Condense 10 Roll Packs into a Big Roll Pack",
		Kenji = "Ten small packs make one big one. Here, I'll top you up to ten: try it in the BAG.",
		Hint = "HUB > BAG > Roll Pack > CONDENSE",
		Check = "Flag",
		Goal = 1,
		Flag = "Condense",
		Supply = { Pack = "10", Count = 10 },
		Reward = { Packs = { ["100"] = 1 } },
	},
	{
		Id = "stagger",
		Name = "The Stagger Window",
		Text = "Stagger a boss with an element that beats it",
		Kenji = "Hit a boss with its weakness and its Stagger bar fills fast. When it breaks, unleash your Ultimates!",
		Hint = "SCOUT shows each boss's weakness",
		Check = "Flag",
		Goal = 1,
		Flag = "CounterStagger",
		Reward = { Shards = 500 },
		Title = "Apprentice",
	},
} :: { Step }

-- The facts a quest's progress is read from.
export type Facts = {
	TotalRolls: number,
	DeckCards: number, -- filled slots in the active deck
	Cleared: { [string]: boolean },
	Flags: { [string]: boolean },
}

-- Progress on quest `step` (index): count so far (capped at the goal) and the goal.
function Tutorial.Progress(step: number, facts: Facts): (number, number)
	local quest = Tutorial.Steps[step]
	if quest == nil then
		return 0, 0
	end
	local count = 0
	if quest.Check == "Rolls" then
		count = facts.TotalRolls
	elseif quest.Check == "Deck" then
		count = facts.DeckCards
	elseif quest.Check == "Clear" then
		count = if quest.Fight and facts.Cleared[quest.Fight] then 1 else 0
	elseif quest.Check == "Flag" then
		count = if quest.Flag and facts.Flags[quest.Flag] then 1 else 0
	end
	return math.min(count, quest.Goal), quest.Goal
end

function Tutorial.Ready(step: number, facts: Facts): boolean
	local count, goal = Tutorial.Progress(step, facts)
	return goal > 0 and count >= goal
end

function Tutorial.Done(step: number): boolean
	return step > #Tutorial.Steps
end

return Tutorial
