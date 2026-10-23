# Card art prompt pack

Prompts for ForgeGUI, Niji Journey or any anime image generator. Every character here is
original to this game: keep them that way (no real anime characters, names or signature designs),
so the game can't be taken down over the art.

## How to use

1. For each card, paste **Character** + **Style** together as the prompt (and **Avoid** as the
   negative prompt if the tool has one).
2. Generate about 4 images per card and keep the best one. If the tool supports a style reference
   or seed, reuse your favourite early result as the reference for the rest, so all 22 match.
3. Save as a **square PNG** (1024 x 1024 or 512 x 512), named after the card id: `rook.png`, `sora.png` ...
   Keep the face in the upper middle: the card shows the whole square, battle and deck tiles crop
   nothing, but the name ribbon covers the bottom edge on some screens.
4. Drop the PNGs into `art/cards/` and tell Claude. It uploads them from Studio and sets each card's
   `Image` in `src/shared/Cards.luau`; cards without a PNG keep their 3D figure, so art can arrive a few
   at a time. (By hand instead: Studio > Asset Manager > Bulk Import, then copy each asset id into the
   card's `Image = "rbxassetid://..."`.)

Art becomes live for players only after Roblox moderation approves each image (usually minutes).

## Style (add to every card prompt)

> anime gacha card illustration, single character, upper body to knees, dynamic action pose,
> dramatic rim lighting, glowing {AURA} aura with energy particles and sparks, detailed fantasy
> background with depth, vibrant saturated colors, sharp clean lineart, cel shading with soft
> gradients, high detail face and eyes, character centered, square composition 1:1

**Avoid:** text, letters, logo, watermark, signature, border, frame, card template, multiple characters,
blurry, low detail, extra fingers, deformed hands, cropped head

**{AURA} by rarity** (it tells players the rarity at a glance):

| Rarity | Aura |
| --- | --- |
| Common | soft silver-white |
| Uncommon | emerald green |
| Rare | electric blue |
| Epic | royal purple |
| Legendary | brilliant gold |
| Mythic | crimson red with black lightning |
| Secret | prismatic rainbow with a black eclipse halo |

## Attack cards

**rook — Rook, Village Brawler (Common).** Aura: soft silver-white.
> young street brawler with messy spiky brown hair and a red cloth headband, confident grin,
> orange sleeveless vest over a dark shirt, bandaged fists raised in a fighting stance, dusty
> village square at sunset behind him

**kaede — Kaede, Kunai Thrower (Common).** Aura: soft silver-white.
> agile kunoichi girl with a long navy-blue ponytail, red cloth mask over her mouth, dark navy
> stealth outfit with red trim, throwing two kunai mid-leap, moonlit rooftops and paper lanterns behind her

**tomo — Tomo, Lantern Swordsman (Uncommon).** Aura: emerald green.
> calm young swordsman with swept black hair, amber travelling coat, glowing paper lantern
> hanging from his belt, drawing a straight sword wreathed in warm lantern light, night festival
> street with floating lanterns

**mirai — Mirai, Spark Archer (Uncommon).** Aura: emerald green.
> cheerful archer girl with bright yellow twin tails, white and gold outfit, drawing a golden bow
> with an arrow made of crackling sparks, wheat fields under a stormy sky

**sora — Sora Ikazuchi, Storm Blade (Rare).** Aura: electric blue.
> fierce teen swordsman with spiky silver-blue hair, open blue jacket, sword crackling with blue
> lightning, slashing forward, storm clouds and lightning strikes behind him

**akane — Akane, Crimson Lancer (Epic).** Aura: royal purple.
> elegant warrior woman with long flowing crimson hair, crimson and gold armour, spinning a long
> spear in a spiral of red energy, ruined castle courtyard with falling petals

**kaito — Kaito Ryuzen, Dragon-Eye Ronin (Legendary).** Aura: brilliant gold.
> stoic ronin with swept dark green hair, one eye glowing gold with a dragon pupil, teal haori over
> dark kimono, half-drawn katana, a translucent golden eastern dragon coiling around him, mountain
> shrine in mist

**noa — Noa, Starfall Witch (Mythic).** Aura: crimson red with black lightning.
> young star witch with long violet hair and a wide pointed witch hat with a gold star, dark purple
> robes covered in constellations, holding a glowing violet orb, meteors falling from a starry night sky

**raijen — Raijen, Eclipse Sovereign (Secret).** Aura: prismatic rainbow with a black eclipse halo.
> imposing demon king with spiky black hair streaked with purple, two short dark horns, dark armour
> with glowing violet lines, wielding a black greatsword with a violet edge, a total solar eclipse
> behind him, shadows rising like flames

**hayate — Hayate, Gale Dancer (Rare).** Aura: electric blue.
> nimble wind ninja boy with a mint-green ponytail and white headband, white and teal outfit, spinning
> mid-air throwing glowing green kunai, swirling wind ribbons, cliffside over a stormy sea

**tsubasa — Tsubasa, Sky Knight (Legendary).** Aura: brilliant gold.
> proud young knight with swept pale-gold hair and a winged navy helmet, navy and gold armour,
> diving from the sky with a golden lance crackling with lightning, towering storm clouds below

## Support cards

**hana — Hana, Herb Healer (Common).** Aura: soft silver-white.
> gentle healer girl with a green bob haircut and pink flowers in her hair, light green apron
> dress, holding a wooden staff sprouting leaves, glowing herbs and butterflies, sunny garden

**goro — Goro, Shield Monk (Common).** Aura: soft silver-white.
> sturdy bald monk with a kind smile, orange monk robes, holding a large round bronze shield in
> front of him, stone temple steps with autumn leaves

**suzu — Suzu, Shrine Drummer (Uncommon).** Aura: emerald green.
> energetic shrine maiden with pink twin tails, white top and red hakama, beating a big red taiko
> drum with sound waves rippling outward, shrine gate and festival lights behind her

**ibuki — Ibuki, Fog Weaver (Uncommon).** Aura: emerald green.
> mysterious girl with long grey-blue hair under a hood, flowing pale blue robes, opening a
> silver folding fan that releases swirling mist, foggy bamboo forest

**yume — Yume Aoi, Moonlight Priestess (Rare).** Aura: electric blue.
> serene priestess with long pale blue hair and a glowing halo, white and blue robes, holding a
> staff topped with a crescent moon, healing light petals floating, moonlit lake

**tetsu — Tetsu, Iron Wall Guardian (Epic).** Aura: royal purple.
> towering guardian in heavy steel armour and a crested helmet, planting a huge tower shield with
> a glowing gold cross into the ground, a dome of protective light, fortress wall at dusk

**luna — Luna Mei, Celestial Strategist (Legendary).** Aura: brilliant gold.
> clever strategist with a dark blue bob and round glasses, navy coat with star embroidery, holding
> an open glowing book projecting a holographic star map, observatory with a giant telescope

**orin — Orin, Time Weaver (Mythic).** Aura: crimson red with black lightning.
> calm time mage with swept white-cyan hair and a halo of floating clock gears, teal robes, holding
> a glowing clock face, frozen raindrops and floating hourglasses around him

**aurelia — Aurelia, Dawn Empress (Secret).** Aura: prismatic rainbow with a black eclipse halo.
> radiant empress with long golden hair and a delicate crown, white and gold gown, holding a staff
> topped with a blazing sun, sunrise breaking through clouds, golden feathers drifting

**amane — Amane, Rain Priestess (Epic).** Aura: royal purple.
> gentle rain priestess with long deep-blue hair and a white flower, white and blue shrine robes,
> opening a paper fan that turns falling rain into glowing healing droplets, misty shrine in the rain

**amaya — Amaya, Storm Oracle (Mythic).** Aura: crimson red with black lightning.
> mysterious oracle girl with dark twin tails under a hood, one eye glowing gold, dark navy robes with
> gold trim, holding a crackling golden storm orb, lightning forking across a black sky

## Bosses (splash art for the boss screen)

Use the same Style, without the rarity aura, plus "menacing boss, full body, low angle".

**kurogane — Kurogane, the Ash Ronin (World 1, Ember Village).**
> towering ronin in ash-grey robes with a red sash and a wide straw hat shadowing glowing ember eyes,
> katana trailing fire, burning village and floating embers

**rimeveil — Rimeveil, the Glacier Queen (World 2, Frostfang Peaks).**
> regal ice queen with long white-blue hair and a crown of ice spikes, flowing pale blue gown,
> ice staff, freezing blizzard swirling around frozen mountain peaks

**vex — Null Emperor Vex, the Void Tyrant (World 3, Neon Abyss).**
> armoured void emperor in black armour with magenta neon lines, long dark cape, halo of floating void
> shards, glowing visor, neon abyss city collapsing into darkness

**tenrai — Tenrai, the Storm Sovereign (World 4, Stormspire Isle).**
> storm lord in navy armour with glowing yellow lightning patterns, white hair, golden horned crown,
> grey storm-cloud cape, raising a lightning spear, thunder drums circling behind him on a jagged isle

## Game icon and thumbnail

**Icon (512 x 512):**
> three glowing anime trading cards fanned out in a burst of golden light, sparkles, the middle card
> shining rainbow, vibrant purple background, bold and readable at small size

**Thumbnail (1920 x 1080, 16:9):**
> Sora, Noa and Raijen (from the prompts above) striking poses around a giant glowing card exploding with
> light, rarity colours bursting outward, vibrant purple and gold, dramatic, space on the left for a title
