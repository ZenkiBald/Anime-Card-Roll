# Story card prompt pack: allies, rivals, mentors and villains

A shonen story told through the cards, so players read every card at a glance by its **role in the story**
(the hot-headed hero, the cool rival, the masked mentor, the tyrant) instead of by stats. Every character
is original: familiar archetypes, never a copy of a real anime character's design, outfit, markings or
name. That's what keeps the game safe from takedowns while still feeling like a classic anime.

Works in Niji Journey, Midjourney (`--niji 6`), ForgeGUI / Stable Diffusion (an anime checkpoint), Leonardo,
ChatGPT / Gemini image generation.

## The story: Shards of the Four Calamities

The Four Spirits once sealed the world's elements. Four Calamities broke the seal: **Kurogane** the Ash
Ronin burned Ember Village, **Rimeveil** the Glacier Queen froze Frostfang Peaks, **Vex** the Void Tyrant
swallowed the Neon Abyss, and **Tenrai** the Storm Sovereign rules Stormspire Isle. Every card is a fighter
who joined (or opposed) the hunt for the shards. Factions, shown in each card's background:

| Faction | Story role | Look |
| --- | --- | --- |
| **Ember Squad** | the heroes: young fighters from the burned village | warm sunset, village rooftops, red cloth details |
| **Storm Academy** | the rivals: elite students who look down on the squad | white-and-blue uniforms, sky arenas, wind |
| **Wandering Masters** | the mentors and legends | worn travelling clothes, temples, mountains, calm power |
| **The Four Calamities** | the villains (the bosses) and their generals | dark armour, ruined worlds, oppressive skies |
| **Fallen / Ascended** | the Secret-tier sovereigns, beyond sides | cosmic skies, eclipses, divine light |

## How to use

1. Paste **Style** + the card's **prompt**, and put **Avoid** in the negative prompt.
2. Generate 4 per card, keep the best. Reuse your favourite image as a **style reference** (Midjourney
   `--sref`, Niji style reference, ForgeGUI IP-Adapter) for every other card, so the whole set matches.
3. Square PNG, 1024 x 1024, face in the upper middle (the name and rarity sit on the bottom edge).
   Name it after the card id (`rook.png`) and drop it in `art/cards/`.
4. The game adds the border (Base / Gold / Rainbow / Secret) itself, so the art never shows a frame, and the
   same art works for every border.

## Style (add to every prompt)

> anime gacha card illustration, shonen battle anime style, single character, upper body to knees,
> dynamic action pose, dramatic rim lighting, glowing {ELEMENT} aura with energy particles, detailed
> background showing their story faction, vibrant saturated colours, sharp clean lineart, cel shading
> with soft gradients, expressive eyes, character centred, square 1:1

**Avoid:** text, letters, logo, watermark, signature, border, frame, card template, multiple characters,
blurry, extra fingers, deformed hands, cropped head, famous anime character, copyrighted character,
recognisable costume from an existing series

**{ELEMENT} aura** (matches the card's element in the game):

| Element | Aura |
| --- | --- |
| Flame | roaring orange-red fire |
| Frost | pale blue ice crystals and frost mist |
| Storm | crackling yellow-white lightning |
| Light | warm golden sunlight and feathers of light |
| Void | violet-black shadow tendrils and dark stars |
| Cosmic | swirling galaxy light with a black eclipse halo |

## Ember Squad (the heroes)

**rook: Rook, Iron Knuckle Brawler (Flame, hero / protagonist).**
> loud, fearless teen brawler, wild red-brown hair, scarred knuckles wrapped in burnt cloth, torn red
> jacket over a dark shirt, mid-punch with fire exploding from his fist, burning village gate behind him,
> determined grin, the "I'll protect everyone" hero

**kaede: Kaede, Kunai Thrower (Void, hero's best friend).**
> quick-witted kunoichi girl, long navy ponytail, half-mask, dark violet stealth outfit with red cord,
> flipping backwards while throwing shadow-wrapped kunai, moonlit rooftops of the ruined village

**tomo: Tomo, Lantern Swordsman (Flame, the calm senpai).**
> gentle older teen swordsman, swept black hair, long amber coat, a paper lantern at his belt, drawing a
> straight sword trailing warm lantern fire, night festival street being rebuilt behind him

**mirai: Mirai, Spark Archer (Storm, the joker).**
> cheeky archer boy, messy blond hair under a goggles headband, mismatched jacket covered in patches,
> drawing a bow of crackling lightning with a wink, village watchtower at dusk

**hana: Hana, Herb Healer (Light, the heart of the squad).**
> kind healer girl, soft green braid with flower pins, apron over a white kimono, herb satchel, raising
> glowing hands of golden light over the wounded, herb garden among village ruins

**suzu: Suzu, Shrine Drummer (Flame, the hype-man).**
> energetic shrine drummer girl, short orange hair, red-and-white shrine outfit with rolled sleeves,
> striking a big taiko drum that bursts into fire rings, shrine steps at sunrise

## Storm Academy (the rivals)

**sora: Sora Ikazuchi, Storm Blade (Storm, the hero's rival).**
> cool, arrogant prodigy swordsman, sharp silver hair, white-and-blue academy uniform with a high
> collar, lightning running along a thin blade, one eye half-closed in contempt, sky arena above clouds

**hayate: Hayate, Gale Dancer (Storm, the rival's partner).**
> graceful twin-blade dancer, long teal hair tied high, flowing academy sash, spinning mid-air in a
> cyclone of wind and sparks, floating academy towers

**tsubasa: Tsubasa, Sky Knight (Light, the academy champion).**
> noble knight with short golden hair, polished white armour with feathered pauldrons, diving with a
> radiant lance, wings of light behind her, academy colosseum in the sky

**amane: Amane, Rain Priestess (Storm, the academy healer).**
> serene priestess with long grey-blue hair, academy robes soaked by rain, holding a bell staff that calls
> a cleansing lightning storm, rain-washed academy courtyard

**amaya: Amaya, Storm Oracle (Storm, the academy headmistress).**
> commanding oracle woman, white hair in a crown braid, storm-cloud cloak, eyes glowing yellow, raising a
> shield of lightning around her students, eye of a storm over the academy

## Wandering Masters (the mentors and legends)

**goro: Goro, Shield Monk (Light, the first mentor).**
> huge, kind bald monk with a long beard, prayer beads, raising a palm that forms a golden barrier, calm
> smile, mountain temple gate

**kaito: Kaito, Dragon-Eye Ronin (Frost, the legendary swordsman).**
> wandering ronin, long white hair tied back, one icy glowing eye, tattered grey haori, mid-slash
> releasing an ice dragon, snowstorm on a mountain pass

**akane: Akane, Crimson Lance Duelist (Flame, the villain who switched sides).**
> fierce duelist woman, short crimson hair, black-and-red armour with a broken Calamity crest, spinning a
> spiral lance wrapped in flame, burning bridge behind her, defiant stare

**yume: Yume Aoi, Moonlight Priestess (Frost, the quiet sage).**
> serene priestess, long silver-blue hair, white-and-indigo robes, moon-shaped mirror glowing with frost
> light, lotus pond under a full moon

**ibuki: Ibuki, Fog Weaver (Frost, the spy master).**
> mysterious masked figure, grey hooded cloak, fingers weaving threads of frost fog that hide allies,
> misty bamboo forest

**tetsu: Tetsu, Iron Wall Guardian (Void, the unbreakable wall).**
> towering guardian in dark iron armour, huge tower shield cracked with violet light, planting it in the
> ground against a shadow storm, ruined fortress gate

**luna: Luna Mei, Celestial Strategist (Light, the tactician).**
> elegant strategist, long black hair with star hairpins, layered white-and-gold robes, moving glowing
> constellation pieces on a floating star map, observatory at night

**orin: Orin, Time Weaver (Void, the hermit who can rewind battles).**
> ageless hermit, long silver hair, robes stitched with clock patterns, hourglass of violet sand turning
> in mid-air, fallen allies reforming from light, broken clock tower

**noa: Noa, Starfall Witch (Void, the anti-hero).**
> smug young witch, wild violet hair, black witch hat with a crescent pin, calling down a meteor storm,
> ruined Neon Abyss skyline, fights the Calamities for her own reasons

## Fallen / Ascended (the Secret sovereigns)

**raijen: Raijen, Eclipse Sovereign (Cosmic, the fallen hero).**
> former hero who ascended, long black hair turning to starlight at the tips, ornate black-and-gold robes,
> a black sun burning behind him, cold eyes, floating above a shattered battlefield

**aurelia: Aurelia, Dawn Empress (Cosmic, the goddess of the dawn).**
> radiant empress, long golden hair flowing into sunrise light, white-and-gold armour gown, a crown of
> light rays, raising her hand as dawn breaks over a war-torn world

## The Four Calamities (the villains: bosses and boss cards)

Same prompts for the boss card art (`kurogane_card.png` ...) and for promo art.

**Kurogane, the Ash Ronin (Flame).**
> towering demon samurai in blackened armour, burning crown-like helmet horns, a giant cleaver dripping
> embers, ash storm over a burning village, glowing red eyes behind the mask

**Rimeveil, the Glacier Queen (Frost).**
> cold, beautiful ice queen, towering crystal crown, gown of glacier shards, frozen soldiers kneeling
> around her throne, endless blizzard, icy contempt

**Vex, the Void Tyrant (Void).**
> tall void emperor with a featureless mask split by a violet eye, robes of living shadow, floating
> broken neon city around him, a barrier of black glass

**Tenrai, the Storm Sovereign (Storm).**
> massive storm god warlord, long white hair whipping in the wind, armour of thunderclouds and gold,
> drums of lightning circling him, a sky island torn by hurricanes

**Generals (the 12 guards, optional promo art).** Use this template with each guard's name, element and
role from `src/shared/Bosses.luau`:
> elite general of {Calamity}, {role: brutal warrior / dark sorcerer / battle healer / shield bearer},
> {element} themed armour in that Calamity's colours, menacing pose, {Calamity's world} behind

## Making new characters later (paste into ChatGPT / Gemini)

> You write anime gacha card prompts for my Roblox game "Anime Card Roll". The story: Shards of the Four
> Calamities (Ember Squad heroes, Storm Academy rivals, Wandering Masters, the Four Calamities villains,
> the Fallen / Ascended sovereigns). Create {N} NEW original characters for the {faction} faction. For
> each give: card id (lowercase), name (Japanese-style, original), a 2-5 word title, element (Flame,
> Frost, Storm, Light, Void or Cosmic), story role in one line, and a 2-3 line image prompt (look, outfit,
> pose, signature move, background). Use classic shonen archetypes, but never copy or closely resemble any
> existing anime character's design, costume, markings, hairstyle combination or name.

Then add each character to `src/shared/Cards.luau` (one entry) and drop the PNG in `art/cards/`.
