--!nonstrict
-- Sound effects, rarity stings and background music.
-- Everything is a licensed Creator Store sound (Pro Sound Effects and APM Music, shared by Roblox for
-- every experience) or one that ships with Roblox, so nothing needs uploading. To swap a sound, change
-- its id here: every screen plays sounds by name.
--
-- A sound entry: Id, Volume, Pitch (playback speed), Region (seconds to play, for long files) and Gap
-- (the shortest time between two plays, so a burst of battle hits doesn't stack into noise).
-- A layered entry lists other entries to fire together (or slightly after: Delay).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sfx = {}

local function asset(id: number): string
	return `rbxassetid://{id}`
end

local SOUNDS = {
	-- Interface
	Click = { Id = asset(9113885290), Volume = 0.55, Gap = 0.04 }, -- PSE: track ball button click
	Whoosh = { Id = asset(9126229267), Volume = 0.55, Gap = 0.05 }, -- PSE: fast airy whoosh by
	Flip = { Id = asset(9126229267), Volume = 0.45, Pitch = 1.8, Gap = 0.05 }, -- the same whoosh, quick: a card snapping over
	Riser = { Id = asset(9125807267), Volume = 0.5 }, -- PSE: rising whoosh burst (reveal build-up)
	Reward = { Id = asset(9116164116), Volume = 0.55, Region = 2.2 }, -- PSE: bright metal dings / chimes
	Chime = { Id = asset(9116163448), Volume = 0.45 }, -- PSE: short dings
	Potion = { Layers = { { "Glug" }, { "Chime", Pitch = 1.3, Delay = 0.35 } } },
	Glug = { Id = asset(9117641945), Volume = 0.6, Region = 1.1, Pitch = 1.25 }, -- PSE: liquid glugs
	Upgrade = { Layers = { { "Riser", Pitch = 1.25 }, { "Chime", Pitch = 1.1, Delay = 0.3 } } },

	-- Impacts
	Hit = { Id = asset(9126229601), Volume = 0.5, Gap = 0.06 }, -- PSE: whoosh into a pounding thud
	Boom = { Id = asset(9125484367), Volume = 0.75 }, -- PSE: deep reverberant boom
	LowHit = { Id = asset(1846902250), Volume = 0.8 }, -- APM: single powerful low orchestral hit
	HeavyHit = { Layers = { { "Hit", Pitch = 0.75 }, { "Boom", Pitch = 1.35, Volume = 0.45 } } },
	KO = { Layers = { { "Boom", Pitch = 1.6, Volume = 0.5 }, { "Hit", Pitch = 0.6 } } },
	Ultimate = { Layers = { { "Riser", Pitch = 1.4 }, { "LowHit", Delay = 0.25 } } },
	Heal = { Id = asset(9116163448), Volume = 0.4, Pitch = 1.35, Gap = 0.1 },
	Shield = { Id = asset(9116163448), Volume = 0.35, Pitch = 0.9, Gap = 0.1 },
	Victory = { Id = asset(1836860398), Volume = 0.7 }, -- APM: Winning Spirit
	Defeat = { Id = asset(1839909504), Volume = 0.6 }, -- APM: Shock Sting
	Thunder = { Id = asset(9116282544), Volume = 0.55, Region = 6, Gap = 1 }, -- PSE: lightning strike, sharp crack + rolling decay

	-- Kept for older calls: the sounds that ship with Roblox.
	Impact = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.4 },
	Thud = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.45 },

	-- Rarity stings (APM Music), rising with the tier; long ones fade out at Region.
	StingRare = { Id = asset(9048757954), Volume = 0.55, Region = 3.6 }, -- magical piano and bells
	StingEpic = { Id = asset(9039637427), Volume = 0.6, Region = 4.2 }, -- uplifting horn sting
	StingLegendary = { Id = asset(9042409054), Volume = 0.7, Region = 6 }, -- fanfare sting
	StingMythic = { Id = asset(1835295395), Volume = 0.75, Region = 7 }, -- The Uprising sting
	StingSecret = { Id = asset(1835323400), Volume = 0.8, Region = 8 }, -- Villain's Lair sting
}

-- What each rarity plays the moment its card turns over.
local STINGS = {
	Common = { { "Chime", Pitch = 1.5, Volume = 0.3 } },
	Uncommon = { { "Chime", Pitch = 1.3, Volume = 0.4 }, { "Chime", Pitch = 1.7, Volume = 0.3, Delay = 0.12 } },
	Rare = { { "StingRare" }, { "Chime", Pitch = 1.2, Volume = 0.35 } },
	Epic = { { "StingEpic" }, { "Reward", Volume = 0.4 } },
	Legendary = { { "StingLegendary" }, { "LowHit", Volume = 0.55 } },
	Mythic = { { "LowHit" }, { "Boom", Volume = 0.6 }, { "StingMythic", Delay = 0.15 } },
	Secret = { { "LowHit", Pitch = 0.85 }, { "Boom", Pitch = 0.8 }, { "StingSecret", Delay = 0.2 } },
}

-- Background music per zone (APM Music), plus the battle track.
local MUSIC = {
	Town = { Id = asset(1837777641), Volume = 0.3 }, -- Lightly Magical
	EmberVillage = { Id = asset(9042756391), Volume = 0.32 }, -- Asian Aroma: flute and light percussion
	FrostfangPeaks = { Id = asset(1837145328), Volume = 0.32 }, -- Milarepa
	NeonAbyss = { Id = asset(9112795463), Volume = 0.45 }, -- PSE: deep foreboding drone
	StormspireIsle = { Id = asset(1846428560), Volume = 0.34 }, -- APM: Forces Of Nature
	Battle = { Id = asset(9045929119), Volume = 0.35 }, -- Ancient Grounds: fast action adventure
}

local groups = {}
local function group(name: string): SoundGroup
	local g = groups[name]
	if g == nil then
		g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = SoundService
		groups[name] = g
	end
	return g
end

local cache = {}
local lastPlayed = {}

local function makeSound(def, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.5
	sound.SoundGroup = group("Effects")
	sound.Parent = SoundService
	return sound
end

local playOne

-- Long sounds play on their own copy so they can fade out at Region without cutting other plays.
local function playRegion(def, name: string, pitch: number, volume: number)
	local sound = makeSound(def, name)
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound:Play()
	local seconds = def.Region / pitch
	task.delay(math.max(0, seconds - 0.6), function()
		TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
	end)
	task.delay(seconds + 0.1, function()
		sound:Destroy()
	end)
end

function playOne(name: string, pitch: number?, volumeScale: number?)
	local def = SOUNDS[name]
	if def == nil then
		return
	end
	if def.Layers then
		for _, layer in def.Layers do
			local layerPitch = (layer.Pitch or 1) * (pitch or 1)
			if layer.Delay then
				task.delay(layer.Delay, playOne, layer[1], layerPitch, layer.Volume)
			else
				playOne(layer[1], layerPitch, layer.Volume)
			end
		end
		return
	end
	local now = os.clock()
	if def.Gap and now - (lastPlayed[name] or 0) < def.Gap then
		return
	end
	lastPlayed[name] = now
	local speed = (def.Pitch or 1) * (pitch or 1)
	local volume = (def.Volume or 0.5) * (volumeScale or 1)
	if def.Region then
		playRegion(def, name, speed, volume)
		return
	end
	local sound = cache[name]
	if sound == nil then
		sound = makeSound(def, name)
		cache[name] = sound
	end
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	SoundService:PlayLocalSound(sound)
end

-- Plays a named sound; `pitch` multiplies its playback speed (higher = brighter and shorter).
function Sfx.Play(name: string, pitch: number?)
	playOne(name, pitch)
end

-- The reveal sting for a rarity. `short` (quick rolls, reward fans) skips the long music stings.
function Sfx.Sting(rarity: string, short: boolean?)
	local layers = STINGS[rarity]
	if layers == nil then
		return
	end
	for _, layer in layers do
		local def = SOUNDS[layer[1]]
		if short and def and def.Region and def.Region > 3 then
			continue
		end
		if layer.Delay then
			task.delay(layer.Delay, playOne, layer[1], layer.Pitch, layer.Volume)
		else
			playOne(layer[1], layer.Pitch, layer.Volume)
		end
	end
	if short and (rarity == "Epic" or rarity == "Legendary") then
		playOne("Reward", if rarity == "Legendary" then 1.15 else 1)
	end
end

-- Music ------------------------------------------------------------------------------------------
local musicTracks = {} -- [key] = Sound
local zoneTrack = "Town"
local override: string? = nil
local playing: string? = nil

local function track(key: string): Sound?
	local def = MUSIC[key]
	if def == nil then
		return nil
	end
	local sound = musicTracks[key]
	if sound == nil then
		sound = Instance.new("Sound")
		sound.Name = `Music{key}`
		sound.SoundId = def.Id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = group("Music")
		sound.Parent = SoundService
		musicTracks[key] = sound
	end
	return sound
end

local function refreshMusic()
	local want = override or zoneTrack
	if want == playing then
		return
	end
	local old = if playing then musicTracks[playing] else nil
	playing = want
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 })
		fade:Play()
		fade.Completed:Connect(function()
			if playing ~= old.Name:sub(6) then
				old:Pause()
			end
		end)
	end
	local sound = track(want)
	if sound then
		if not sound.IsPlaying then
			sound:Resume()
			if not sound.IsPlaying then
				sound:Play()
			end
		end
		TweenService:Create(sound, TweenInfo.new(1.5), { Volume = MUSIC[want].Volume }):Play()
	end
end

-- The zone the player is standing in picks the music (Town, EmberVillage, FrostfangPeaks, NeonAbyss).
function Sfx.SetZone(zone: string)
	zoneTrack = if MUSIC[zone] then zone else "Town"
	refreshMusic()
end

-- A screen that brings its own music (the battle) sets it here; nil goes back to the zone's track.
function Sfx.SetMusicOverride(key: string?)
	override = key
	refreshMusic()
end

function Sfx.SetMusicVolume(scale: number)
	group("Music").Volume = scale
end

function Sfx.SetEffectsVolume(scale: number)
	group("Effects").Volume = scale
end

return Sfx
