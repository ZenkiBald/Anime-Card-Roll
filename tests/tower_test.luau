-- The Infinite Tower (Tower.luau): floors, picks, rewards, and the tuning target: a deck at a floor's
-- recommended power beats every enemy that floor can roll, in a sensible time.
local Config = MODULES.Config
local Bosses = MODULES.Bosses
local Deck = MODULES.Deck
local Items = MODULES.Items
local Meta = MODULES.Meta
local Tower = MODULES.Tower
local Engine = MODULES.BattleEngine
local F = FIXTURES

-- 1. Floors ------------------------------------------------------------------------------------
local same = true
for floor = 1, 80 do
	local a, b = Tower.FloorAt(floor), Tower.FloorAt(floor)
	if a.Boss ~= b.Boss or a.Affix ~= b.Affix or a.HP ~= b.HP then
		same = false
	end
end
check(same, "a floor is the same fight every time (server, client and retries agree)")

local growing, statsGrow = true, true
local lastHP, lastATK = 0, 0
for floor = 1, 150 do
	if not Tower.IsGuardian(floor) and not Tower.IsGuardian(floor - 1) and floor > 1 then
		growing = growing and Tower.Recommended(floor) > Tower.Recommended(floor - 1)
	end
	local hp, atk = Tower.StatsAt(Tower.Recommended(floor))
	if not Tower.IsGuardian(floor) then
		statsGrow = statsGrow and hp >= lastHP and atk >= lastATK
		lastHP, lastATK = hp, atk
	end
end
check(growing, "recommended power climbs every floor")
check(statsGrow, "boss HP and ATK never drop as the floors climb")
check(Tower.Recommended(10) > Tower.Recommended(11) * 0.98, "a Guardian floor asks for more power than its neighbours")
check(Tower.Recommended(300) > 1e7, "the tower has no top: floor 300 still asks for more")

local poolOk, seen, affixSeen, guardianAffix, earlyAffix = true, {}, {}, false, false
for floor = 1, 120 do
	local fl = Tower.FloorAt(floor)
	local enemy
	for _, e in Tower.Enemies do
		if e.Boss == fl.Boss then
			enemy = e
		end
	end
	if enemy == nil or floor < enemy.MinFloor or Bosses.Get(fl.Boss) == nil then
		poolOk = false
	end
	seen[fl.Boss] = true
	if fl.Affix then
		affixSeen[fl.Affix] = true
		guardianAffix = guardianAffix or fl.Guardian
		earlyAffix = earlyAffix or floor < Tower.AffixFrom
	end
	local tier = if floor >= Tower.NightmareFrom then "Nightmare" elseif floor >= Tower.HardFrom then "Hard" else "Normal"
	poolOk = poolOk and fl.Difficulty == tier and Bosses.Get(fl.Boss).Difficulties[fl.Difficulty] ~= nil
end
local allSeen = true
for _, e in Tower.Enemies do
	allSeen = allSeen and seen[e.Boss] == true
end
local allAffixes = true
for _, a in Tower.Affixes do
	allAffixes = allAffixes and affixSeen[a.Id] == true
end
check(poolOk, "every floor's enemy is a real boss from its pool (MinFloor) with the right move set")
check(allSeen and allAffixes, "every enemy and every affix shows up in the first 120 floors")
check(not guardianAffix and not earlyAffix, `affixes start at floor {Tower.AffixFrom} and never land on a Guardian`)

-- 2. Rewards ---------------------------------------------------------------------------------------
local Packs = MODULES.Packs
local rewardsOk = true
local lastShards = 0
for floor = 1, 120 do
	local r = Tower.Reward(floor)
	local art = Tower.ArtifactChance(floor)
	if art > 1 or art <= 0 then
		rewardsOk = false
	end
	for id, count in r.Packs or {} do
		rewardsOk = rewardsOk and Packs.ById[id] ~= nil and count >= 1
	end
	if Tower.IsGuardian(floor) then
		rewardsOk = rewardsOk and r.Potion ~= nil and Meta.PotionById[r.Potion] ~= nil and art > Items.ArtifactChance(r.D) and r.Packs ~= nil
	else
		rewardsOk = rewardsOk and r.Shards > lastShards and r.Potion == nil
		lastShards = r.Shards
	end
end
check(rewardsOk, "floor rewards: Shards grow every floor; Guardians pay a potion, packs and better artifact odds")
check(Tower.Reward(48).D == 12 and Tower.Reward(4).D == 1, "reward score: floor 4 pays like World 1 Normal, floor 48 like World 4 Nightmare")
check(Packs.ForFloor(1) == nil and Packs.ForFloor(5)["10"] == 1 and Packs.ForFloor(10)["10"] == 2, "every 5th floor drops a Roll Pack, Guardians two")
check(Packs.ForFloor(25)["100"] == 1 and Packs.ForFloor(100)["1000"] == 1, "floor 25 drops a Big Roll Pack, floor 100 a Mega Roll Pack")
check(Packs.NextFloorWith(26, "100") == 50 and Packs.NextFloorWith(1, "1000") == 100, "the next floor with a pack size is found")
check(Packs.ForBoss(1, false)["10"] == 1 and Packs.ForBoss(1, true)["10"] == 2 and Packs.ForBoss(12, false)["10"] == 3, "boss wins drop Roll Packs, +1 on a first clear")
check(Packs.Count({ ["10"] = 2, ["100"] = 1, junk = 5 }) == 3, "pack counts ignore unknown ids")
local q = Meta.QuestById.tower
check(q ~= nil and q.Stat == "TowerFloors", "a daily quest counts tower floors")

-- 3. Tuning ------------------------------------------------------------------------------------
local function campaign(fl, deck, owned, n)
	local wins, times = 0, {}
	for seed = 1, n do
		local battle = Engine.new({
			Units = F.units(deck, owned),
			BossId = fl.Boss,
			Difficulty = fl.Difficulty,
			Rng = Random.new(seed * 7919),
			Stats = { HP = fl.HP, ATK = fl.ATK, WarnSeconds = fl.WarnSeconds, DEF = fl.DEF, SPD = fl.SPD },
			Guards = fl.Guards,
		})
		battle.AutoUlt = true
		while not battle.Over do
			battle:Step(Config.Battle.Tick)
			battle:TakeEvents()
		end
		if battle.Result == "Win" then
			wins += 1
			table.insert(times, battle.Time)
		end
	end
	table.sort(times)
	return wins / n, F.percentile(times, 0.5)
end

-- The floor (Guardians included or not) whose recommended power is nearest `power`.
local function floorFor(power, guardian)
	local best, gap = 1, math.huge
	for floor = 1, 150 do
		if Tower.IsGuardian(floor) == guardian and math.abs(Tower.Recommended(floor) - power) < gap then
			best, gap = floor, math.abs(Tower.Recommended(floor) - power)
		end
	end
	return best, gap / power
end

local withAffixes = { [2] = true, [5] = true, [8] = true, [11] = true }
for i, fx in F.FIGHTS do
	local deck, owned = F.fixtureDeck(fx)
	local power = Deck.Power(deck, owned)
	local floor = floorFor(power, false)
	local worst, slowest, line = 1, 0, ""
	for _, enemy in Tower.Enemies do
		if floor >= enemy.MinFloor then
			local rate, median = campaign(Tower.FloorAt(floor, enemy, false), deck, owned, 24)
			worst, slowest = math.min(worst, rate), math.max(slowest, median)
			line ..= string.format(" %s %d%% %.0fs", enemy.Name, rate * 100, median)
		end
	end
	if withAffixes[i] and floor >= Tower.AffixFrom then
		for _, affix in Tower.Affixes do
			local rate, median = campaign(Tower.FloorAt(floor, Tower.Enemies[1], affix), deck, owned, 16)
			worst, slowest = math.min(worst, rate), math.max(slowest, median)
			line ..= string.format(" +%s %d%% %.0fs", affix.Id, rate * 100, median)
		end
	end
	print(string.format("   deck %6d -> floor %2d (rec %6d):%s", power, floor, Tower.Recommended(floor), line))
	check(worst >= 0.9 and slowest <= 100, `tower floor {floor}: a {math.floor(power / 1000)}k deck beats every enemy it can roll (90%+, median under 100 s)`)
end

-- Guardians: the fixture decks nearest a Guardian's power beat it too.
for _, fx in F.FIGHTS do
	local deck, owned = F.fixtureDeck(fx)
	local power = Deck.Power(deck, owned)
	local floor, gap = floorFor(power, true)
	if gap <= 0.08 then
		local worst = 1
		for _, enemy in Tower.Enemies do
			if floor >= enemy.MinFloor then
				worst = math.min(worst, (campaign(Tower.FloorAt(floor, enemy, false), deck, owned, 16)))
			end
		end
		check(worst >= 0.9, `Guardian floor {floor}: a deck at its power ({math.floor(power / 1000)}k) beats it`)
	end
end

-- A deck far below a floor's power doesn't walk through it.
do
	local deck, owned = F.fixtureDeck(F.FIGHTS[1])
	local rate = campaign(Tower.FloorAt(30, Tower.Enemies[1], false), deck, owned, 10)
	check(rate == 0, "a World 1 deck can't climb to floor 30")
end
