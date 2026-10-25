# Card art prompts: the current roster

One prompt per card, written for the cards as they are now in `src/shared/Cards.luau`: each card's **name**,
**subtitle**, **element** and **signature move**, so the art tells you what the card does at a glance. Names,
subtitles and moves are original Dark Feudal Occult ones (renamed 2026-10-26 from the prototype's anime-style
epithets), and every design below is original too (archetype, outfit, pose and move are ours).

Works in Niji Journey, Midjourney (`--niji 6`), ForgeGUI / Stable Diffusion (an anime checkpoint), Leonardo,
ChatGPT / Gemini image generation.

## How to use

1. Paste **Style** + the card's **prompt**; put **Avoid** in the negative prompt.
2. Generate 4 per card and keep the best. Use your favourite result as a **style reference** (Midjourney
   `--sref`, Niji style reference, ForgeGUI IP-Adapter) for every other card so the set matches.
3. Square PNG, 1024 x 1024, face in the upper middle (name and rarity sit on the bottom edge). Name it after
   the card id (`rook.png`) and drop it in `art/cards/`.
4. No frame in the art: the game draws the border (Base / Gold / Rainbow / Secret), so one image serves every
   border.
5. Rarer cards get more spectacle: commons a clean action pose, the Weight 1-2.5 cards a full-power moment,
   Secrets and boss cards a world-ending scene.

## Style (add to every prompt)

> anime gacha card illustration, shonen battle anime style, single character, upper body to knees, dynamic
> action pose, dramatic rim lighting, glowing {ELEMENT} aura with energy particles, detailed background,
> vibrant saturated colours, sharp clean lineart, cel shading with soft gradients, expressive eyes,
> character centred, square 1:1

**Avoid:** text, letters, logo, watermark, signature, border, frame, card template, multiple characters,
blurry, extra fingers, deformed hands, cropped head, existing anime character, copyrighted character,
recognisable costume from an existing series

| Element | {ELEMENT} aura |
| --- | --- |
| Flame | roaring orange-red fire |
| Frost | pale blue ice crystals and frost mist |
| Storm | crackling yellow-white lightning |
| Light | warm golden sunlight and feathers of light |
| Void | violet-black shadow tendrils and dark stars |
| Cosmic | swirling galaxy light with a black eclipse halo |

## Commons (Weight 8-10): the starter squad

**rook · Ashen Bulwark, The Ember-Plated Vanguard (Flame, Attack Warder; Colossal Stomp).**
> towering young warrior in heavy ember-red plate armour with glowing seams, shoulders like fortress walls,
> stamping the ground so a ring of fire and cracked stone bursts outward, burning gate behind him

**kaede · Gravethread Maiden, Mender of Torn Souls (Void, Attack Mender; Soul-Thread Ward).**
> calm girl with long navy hair and a violet hair cord, sleeves trailing glowing soul threads that knit a
> translucent shield around her allies, a swarm of shadow sparks, moonlit shrine courtyard

**tomo · Dawnfire Ronin, Blade of the First Light (Flame, Attack Striker; Dawnfire Dance).**
> earnest young swordsman in a long amber coat, a straight blade trailing a spiral of
> sun-fire as he spins through a dance-like cut, dawn breaking over a mountain village

**noa · Starfall Witch, Mistress of Hounds (Void, Attack Hexer; Garden of Black Thorns).**
> smug young witch with wild violet hair and a crescent-pinned hat, two hounds made of shadow lunging from
> her cape, a garden of black thorns blooming under a ruined neon skyline

**hana · Lotus Shrine Healer, Hundred-Petal Mender (Light, Support Mender; Hundred Petals).**
> kind healer with a soft green braid and lotus pins, white field-medic coat, palms glowing gold as a
> hundred lotus petals of light heal the wounded around her, temple garden

**suzu · Thunderclap Duelist, The Sleepwalking Storm (Storm, Support Striker; Thunder Clap).**
> sleepy-eyed swordswoman with short copper hair, teal-and-white travelling coat, half asleep yet already mid-draw,
> a single lightning-fast cut leaving a crack of thunder, rain-soaked wooden bridge

**ibuki · Mistveil Shinobi, Cloud-Step Assassin (Frost, Support Warder; Playful Cloud Strike).**
> masked assassin in a grey hooded cloak, stepping on drifting frost clouds, a thin blade hidden in the mist
> as afterimages fan out around him, misty bamboo forest

**luna · Celestial Strategist, Reader of the Star Charts (Light, Support Mender; Star-Needle Sting).**
> elegant strategist with long black hair and star hairpins, layered white-and-lilac robes, a slim
> needle-blade glowing with light, wisteria petals and a floating star map around her, night garden

## Uncommons (Weight 4-6)

**sora · Hexblood Prodigy, Master of Storm Shikigami (Storm, Attack Striker; Hundred Familiars).**
> cool, sharp-eyed prodigy in a dark high-collared uniform, hand sign raised as familiars made of crackling
> storm shadows (wolves, a great bird) charge out of his shadow, stormy rooftop

**hayate · Pyregate Warden, Keeper of the Funeral Flame (Flame, Attack Striker; Purgatory Gate).**
> stern warden in black armour with a flowing crimson cape, a burning gate of hellfire opening behind him,
> sweeping a long blade so flames wash over every enemy, ash falling over a ruined citadel

**tetsu · Blacksand Bastion, The Living Rampart (Void, Support Warder; Black Sand Tomb).**
> silent guardian in dark iron armour, violet-black sand rising from the ground that rises
> into walls and shields, desert fortress at dusk

**amane · Stormstring Puppeteer, Mistress of Strings (Storm, Support Mender; Puppet Theater).**
> composed puppeteer with grey-blue hair, gloves trailing lightning-charged strings tied to wooden puppets
> that shield her allies, a stage curtain of storm clouds

**goro · Iron-Vow Monk, Bearer of the Blood Oath (Light, Support Warder; Severing Pact).**
> huge scarred brawler with a shaved head and prayer beads, fists wrapped in glowing gold seals, punching
> through the air so a wall of golden light shields his team, mountain temple gate

**amaya · Storm Oracle, Voice of the Storm (Storm, Support Warder; Oracle's Tempest).**
> commanding oracle woman with white hair in a crown braid and a storm-cloud cloak, eyes glowing yellow,
> calling a tempest down on her enemies while lightning shields wrap her allies, eye of a storm

## Rares (Weight 1.5-2.5): full-power moments

**kaito · Frostcrown Prince, Pride of the Glacier Blade (Frost, Attack Striker; Frostfall Barrage).**
> proud warrior prince with long hair blazing gold, a frost-blue aura crackling with golden sparks around
> him, unleashing a barrage of glowing ki blasts across a frozen battlefield, arrogant smirk

**tsubasa · Moonlit Executioner, Crescent of the Last Rite (Light, Attack Hexer; Moonfall Cleave).**
> fierce reaper with short golden hair and a black-and-white hakama, a huge crescent-shaped blade of
> moonlight, cleaving a glowing crescent wave down from the sky, full moon behind

**orin · Time Weaver, Keeper of Hours (Void, Support Mender; Rewind).**
> ageless hermit with long silver hair, robes stitched with clock faces, a violet hourglass turning in
> mid-air as fallen allies reform from light, broken clock tower

**mirai · Stillstorm Hermit, Sage of the Unbroken Ward (Storm, Attack Hexer; Stillstorm Convergence).**
> carefree sage with storm-blue glowing eyes and a light grey travelling coat, untouched by the attacks freezing in mid-air around him,
> two orbs of crackling lightning and void colliding into one blinding sphere, shattered city

**akane · Crimson Oni Warlord, Lord of the Burning Shrine (Flame, Attack Hexer; Thousand Cuts).**
> menacing warlord with a cruel grin, crimson runes burning along his arms, a cloak of shadow and flame,
> invisible slashes carving a storm of cuts through the air, a shrine of skulls burning behind him

**yume · Moon-Mirror Priestess, Keeper of Frozen Dreams (Frost, Support Mender; Frozen Lullaby).**
> serene priestess with long silver-blue hair and indigo robes, holding a moon mirror that reflects a frozen
> dream world, enemies drifting asleep in frost mist, lotus pond under a full moon

## Sovereigns (Weight 1): the Secret chase

**raijen · Eclipse Sovereign, The Thoughtless Blade (Cosmic, Attack Striker; Moving Without Thought).**
> calm martial artist with dark hair turning to starlight at the tips, a galaxy aura, dodging every strike without
> looking, afterimages and a black eclipse halo behind him, floating above a shattered battlefield

**aurelia · Dawn Empress, Vessel of the Sealed Dawn (Cosmic, Support Mender; Last Light Oath).**
> radiant young sovereign with golden hair, nine tails of cosmic fire spreading behind her like wings, a
> glowing seal-ring half-open around her wrist, shielding her allies as dawn breaks over a war-torn world

## The Four Calamities (boss cards, rarer than any Sovereign)

**kurogane_card · Kurogane, The Ash Ronin (Flame, Attack Hexer; Ashen Slagfall).**
> colossal beast of molten magma with burning tails, roaring as slag rains from the sky, a
> burning village far below

**rimeveil_card · Rimeveil, The Glacier Queen (Frost, Attack Hexer; Crystal Sovereignty).**
> cold, regal alien emperor in crystal-plated armour and a crystal crown, one finger raised as a lance of
> ice pierces the sky, frozen soldiers kneeling, endless blizzard

**vex_card · Vex, The Void Tyrant (Void, Attack Hexer; Devour All).**
> serene, smiling overlord in layered violet robes, a shattered mirror of void flowers reflecting
> a false world around him, the real one dissolving behind, broken neon city

**tenrai_card · Tenrai, The Storm Sovereign (Storm, Attack Striker; Judgment Bolt).**
> ancient demon lord in an immaculate black-and-gold formal coat, burning eyes, flesh-like whips of storm lightning lashing out
> from his back, a thousand-year storm over a sky island, cold contempt

## Making new characters later (paste into ChatGPT / Gemini)

> You write anime gacha card prompts for my Roblox game "Anime Card Roll". Each card has a name (an
> original dark-feudal epithet), a subtitle, an element (Flame, Frost, Storm, Light, Void or Cosmic), a role
> (Striker, Hexer, Mender or Warder) and a signature move. Create {N} NEW cards. For each give: card id
> (lowercase), name, subtitle, element, role, a 2-5 word signature move, and a 2-3 line image prompt (look,
> outfit, pose doing the signature move, background). The more spectacular the move, the rarer the card.
> Classic shonen archetypes, but never copy any existing character's design, costume, markings,
> hairstyle combination or name.

Then add the card to `src/shared/Cards.luau` (one entry; `docs/CARD_DESIGNER_ASSISTANT.md` has the rules) and
drop its PNG in `art/cards/`.
