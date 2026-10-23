--!strict
-- Rideable pets. A new mount is one entry here plus its model in ReplicatedStorage.MountKit (named
-- after Model; models live in the place file, not Rojo). Mounts only change how fast you get around:
-- they give no battle power. Every mount is earned in game: the starter is free and each world's boss
-- unlocks one on its first Normal clear.

local Bosses = require(script.Parent.Bosses)

export type Mount = {
	Id: string,
	Name: string,
	Model: string, -- child of ReplicatedStorage.MountKit
	Speed: number, -- walk speed while riding (on foot it's 16)
	Jump: number, -- jump power while riding (on foot it's 50)
	Seat: number, -- rider's hip height while riding: about the saddle's height above the ground + 0.8
	Float: number?, -- studs the mount hovers above the ground (Void Ray)
	Forward: number?, -- studs the model sits ahead of the rider, so the saddle ends up under them
	Yaw: number?, -- degrees to turn the model so it faces forward
	Accent: Color3,
	Boss: string?, -- boss whose first Normal clear unlocks it; nil = free
	Text: string,
}

local Mounts = {}

Mounts.List = {
	{
		Id = "pup",
		Name = "Sakura Pup",
		Model = "SakuraPup",
		Speed = 26,
		Jump = 55,
		Seat = 4.6,
		Forward = -2,
		Accent = Color3.fromRGB(255, 160, 200),
		Text = "A loyal pup that follows you from day one.",
	},
	{
		Id = "ember",
		Name = "Ember Fox",
		Model = "EmberFox",
		Speed = 29,
		Jump = 58,
		Seat = 4.4,
		Forward = -1.4,
		Accent = Color3.fromRGB(255, 120, 60),
		Boss = "kurogane",
		Text = "Its tail never stops burning.",
	},
	{
		Id = "frost",
		Name = "Frost Wolf",
		Model = "FrostWolf",
		Speed = 32,
		Jump = 60,
		Seat = 4.8,
		Forward = -0.8,
		Accent = Color3.fromRGB(140, 210, 255),
		Boss = "rimeveil",
		Text = "Runs over snow without leaving tracks.",
	},
	{
		Id = "void",
		Name = "Void Ray",
		Model = "VoidRay",
		Speed = 35,
		Jump = 62,
		Seat = 1.8,
		Float = 2.5,
		Accent = Color3.fromRGB(220, 80, 255),
		Boss = "vex",
		Text = "Glides a little above the ground.",
	},
	{
		Id = "storm",
		Name = "Storm Kirin",
		Model = "StormKirin",
		Speed = 38,
		Jump = 66,
		Seat = 4.6,
		Forward = -1.8,
		Accent = Color3.fromRGB(255, 222, 70),
		Boss = "tenrai",
		Text = "The fastest steed under the storm.",
	},
} :: { Mount }

Mounts.ById = {} :: { [string]: Mount }
for _, mount in Mounts.List do
	assert(Mounts.ById[mount.Id] == nil, `Duplicate mount id "{mount.Id}"`)
	Mounts.ById[mount.Id] = mount
end

function Mounts.Get(id: string): Mount?
	return Mounts.ById[id]
end

-- Whether a save (its Progress.Cleared table) has unlocked this mount.
function Mounts.Unlocked(mount: Mount, cleared: { [string]: boolean }): boolean
	return mount.Boss == nil or cleared[Bosses.FightKey(mount.Boss, "Normal")] == true
end

-- "Beat Kurogane on Normal", for the locked label.
function Mounts.UnlockText(mount: Mount): string
	local boss = mount.Boss and Bosses.Get(mount.Boss)
	return if boss then `Beat {boss.Name} on Normal` else "Free"
end

return Mounts
