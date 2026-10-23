--!strict
-- Roll Packs: boss wins and some Infinite Tower floors drop packs of 10, 100 or 1000 rolls instead of
-- rolling on the spot. A pack has no rarity of its own: it's just rolls, made at the player's luck when
-- they open it (potions, LUCKY STORM and pity all count then), so saving packs for a boost pays off.
-- Saved as Packs[id] = count; opened from BAG > PACKS (RollService "OpenPack"). Shared so the BAG, the
-- boss / tower screens and the server agree. A new pack size is one entry in Packs.List.
--
-- Pack Alchemy (BAG, RollService "Alchemy"): CONDENSE 10 Roll Packs into a Big Roll Pack and 10 Big Roll
-- Packs into a Mega Roll Pack; INFUSE a Mega Roll Pack with an element for InfuseCost Shards. An infused
-- pack ("1000:Flame") weights that element's cards x1.5 inside each rolled rarity, and doubles border
-- odds when it's opened during LUCKY STORM, Raid Luck or a Luck Totem.

local Packs = {}

export type Pack = {
	Id: string,
	Name: string,
	Rolls: number,
	Icon: string,
	Color: Color3,
	Element: string?, -- infused packs only
}

Packs.List = {
	{ Id = "10", Name = "Roll Pack", Rolls = 10, Icon = "🎴", Color = Color3.fromRGB(86, 180, 255) },
	{ Id = "100", Name = "Big Roll Pack", Rolls = 100, Icon = "📦", Color = Color3.fromRGB(190, 110, 255) },
	{ Id = "1000", Name = "Mega Roll Pack", Rolls = 1000, Icon = "🎁", Color = Color3.fromRGB(255, 196, 46) },
} :: { Pack }

-- Element-infused Mega Packs (Cosmic isn't offered: only Secret cards are Cosmic).
Packs.InfuseElements = {
	{ Id = "Flame", Icon = "🔥", Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "Frost", Icon = "❄️", Color = Color3.fromRGB(120, 210, 255) },
	{ Id = "Storm", Icon = "⚡", Color = Color3.fromRGB(255, 220, 70) },
	{ Id = "Light", Icon = "☀️", Color = Color3.fromRGB(255, 240, 170) },
	{ Id = "Void", Icon = "🌑", Color = Color3.fromRGB(180, 90, 255) },
}
for _, element in Packs.InfuseElements do
	table.insert(Packs.List, {
		Id = `1000:{element.Id}`,
		Name = `{element.Id} Mega Pack`,
		Rolls = 1000,
		Icon = element.Icon,
		Color = element.Color,
		Element = element.Id,
	})
end

Packs.ById = {} :: { [string]: Pack }
for _, pack in Packs.List do
	Packs.ById[pack.Id] = pack
end

-- CONDENSE: Need of a pack become one of To.
Packs.Condense = {
	["10"] = { To = "100", Need = 10 },
	["100"] = { To = "1000", Need = 10 },
} :: { [string]: { To: string, Need: number } }

Packs.InfuseCost = 2500 -- Shards to infuse one Mega Roll Pack
Packs.InfuseWeight = 1.5 -- the element's cards weigh this much inside a rarity
Packs.InfuseBorderMult = 2 -- border odds when opened under LUCKY STORM, Raid Luck or a Luck Totem

-- The infused pack id for an element ("1000:Flame"), or nil for an element that can't be infused.
function Packs.InfusedId(element: string): string?
	local id = `1000:{element}`
	return if Packs.ById[id] then id else nil
end

-- The reveal flips this many of a pack's pulls (the rarest) and sums up the rest.
Packs.ShowCards = 10

-- A boss win: one Roll Pack per 10 of the old reward rolls (3 + 2D, rounded up), +1 on a first clear.
function Packs.ForBoss(d: number, firstClear: boolean): { [string]: number }
	return { ["10"] = math.ceil((3 + 2 * d) / 10) + (if firstClear then 1 else 0) }
end

-- Tower floors that drop packs (each floor pays once): every 5th a Roll Pack, every 10th (a Guardian)
-- two, every 25th a Big Roll Pack, every 100th a Mega Roll Pack. Other floors pay Shards and gear only.
function Packs.ForFloor(floor: number): { [string]: number }?
	if floor % 100 == 0 then
		return { ["1000"] = 1 }
	elseif floor % 25 == 0 then
		return { ["100"] = 1 }
	elseif floor % 10 == 0 then
		return { ["10"] = 2 }
	elseif floor % 5 == 0 then
		return { ["10"] = 1 }
	end
	return nil
end

-- The next floor at or above `floor` that drops a pack of `id` (for "Big Roll Pack on floor 25").
function Packs.NextFloorWith(floor: number, id: string): number
	local f = math.max(1, math.floor(floor))
	for _ = 1, 1000 do
		local drop = Packs.ForFloor(f)
		if drop and drop[id] then
			return f
		end
		f += 1
	end
	return f
end

-- Total packs held.
function Packs.Count(held: { [string]: number }?): number
	local n = 0
	for id, count in (held or {}) :: { [string]: number } do
		if Packs.ById[id] then
			n += count
		end
	end
	return n
end

-- "2x Roll Pack, 1x Big Roll Pack" (biggest last), or "" for none.
function Packs.Describe(held: { [string]: number }?): string
	local parts = {}
	for _, pack in Packs.List do
		local count = held and held[pack.Id] or 0
		if count > 0 then
			table.insert(parts, `{pack.Icon} {count}x {pack.Name}`)
		end
	end
	return table.concat(parts, ", ")
end

return Packs
