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
		Kenji = "Every legend starts with a pull. Open your starter Roll Pack in BAG, or press ROLL and see who answers!",
		Hint = "Press ROLL at the bottom",
		Check = "Rolls",
		Goal = 5,
		Reward = { Shards = 50, Potions = { superluck = 1 } },
	},
	{
		Id = "line",
		Name = "Assemble the Line",
		Text = "Fill your deck: 4 Attack + 4 Support",
		Kenji = "Attack cards fight and take hits. Support cards are passive bonuses, with no damage or HP. Matching slot numbers pair them; effects have limits shown in VIEW SKILLS. Use BEST DECK, then tap a card > VIEW SKILLS to see what it does.",
		Hint = "SQUAD > DECK > BEST DECK",
		Check = "Deck",
		Goal = 8,
		Reward = { Packs = { ["10"] = 1 } },
	},
	{
		Id = "flame",
		Name = "Trial by Flame",
		Text = "Beat the Tailed Beast Calamity on Normal",
		Kenji = "The Tailed Beast Calamity waits in Ember Village. Build a full team and focus its guards before the warned attack.",
		Hint = "BATTLE > World 1, or walk through the Ember Village portal",
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
		Hint = "Walk to Kenshin the Trait Master, beside Hoshi in town",
		Check = "Flag",
		Goal = 1,
		Flag = "TraitRoll",
		Reward = { TraitShards = 15 },
	},
	{
		Id = "alchemy",
		Name = "Alchemy Master",
		Text = "Condense 10 Roll Packs into a Big Roll Pack",
		Kenji = "Ten small packs make one big one. Here, I'll top you up to ten: Hoshi does the alchemy.",
		Hint = "Walk to Hoshi in town > PACK ALCHEMY > CONDENSE",
		Check = "Flag",
		Goal = 1,
		Flag = "Condense",
		Supply = { Pack = "10", Count = 10 },
		Reward = { Packs = { ["100"] = 1 } },
	},
	{
		Id = "stagger",
		Name = "The Stagger Window",
		Text = "Break a boss’s Stagger bar",
		Kenji = "Keep attacking to fill the boss’s Stagger bar. When it breaks, unleash your charged Ultimates!",
		Hint = "Watch the boss's warned move and save your Ultimate for Stagger",
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
