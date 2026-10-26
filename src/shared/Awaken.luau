--!strict
-- Battle mastery. Module name retained for consumers; copies never grant combat bonuses.
local Awaken = {}
export type Node = { Node: number, Challenges: number, Name: string, Text: string }
Awaken.Every = 20 -- developer copy tool only
Awaken.StatBonus = 0
Awaken.SkillBonus = 0.1
Awaken.BondPct = 3.5
Awaken.Nodes = {
	{ Node = 1, Challenges = 1, Name = "Battle Rhythm", Text = "+5% attack speed" },
	{ Node = 2, Challenges = 3, Name = "Practiced Technique", Text = "+10% Skill and Ultimate damage" },
	{ Node = 3, Challenges = 6, Name = "Trusted Partner", Text = "Bond combo deals 350% instead of 300%" },
	{ Node = 4, Challenges = 10, Name = "Second Nature", Text = "Opens trait slot 2" },
} :: { Node }
function Awaken.FromCopies(_copies: number): number
	return 0
end
function Awaken.Count(entry: any): number
	local count = 0
	for _, cleared in if entry and type(entry.Mastery) == "table" then entry.Mastery else {} do
		if cleared == true then count += 1 end
	end
	return count
end
function Awaken.Level(entry: any): number
	local count, level = Awaken.Count(entry), 0
	for _, node in Awaken.Nodes do if count >= node.Challenges then level = node.Node end end
	return level
end
function Awaken.StatMultiplier(_level: number?): number
	return 1
end
function Awaken.Effects(level: number?): { { Stat: string, Amount: number } }
	local effects = {}
	if (level or 0) >= 1 then table.insert(effects, { Stat = "SPD", Amount = 0.05 }) end
	if (level or 0) >= 2 then table.insert(effects, { Stat = "SkillDMG", Amount = Awaken.SkillBonus }) end
	return effects
end
function Awaken.Next(entry: any): Node?
	return Awaken.Nodes[Awaken.Level(entry) + 1]
end
-- One mark per story boss/difficulty with this card equipped; repeats, towers and losses grant none.
function Awaken.Award(entry: any, challenge: string): boolean
	entry.Mastery = if type(entry.Mastery) == "table" then entry.Mastery else {}
	if entry.Mastery[challenge] then return false end
	entry.Mastery[challenge] = true
	return true
end
return Awaken
