# Illustrated Urushi UI kit

Implemented 2026-10-26 from the user's approved black / antique-gold / vermilion HUD concept.
Generated with the built-in imagegen tool, uploaded through the Roblox Studio connector, and consumed by
`src/client/UI/UIArt.luau`. Text, counters, controls, state and rarity frames remain live Roblox UI.
These textures are used now; they are not mockups waiting to be wired in.

| Source PNG | Source dimensions | Roblox asset |
| --- | --- | --- |
| icons-v1.png | 1254 x 1254 | rbxassetid://97204181847223 |
| items-v1.png | 1254 x 1254 | rbxassetid://72589476591756 |
| panel-v1.png | 1254 x 1254 | rbxassetid://96750861620965 |
| roll-v1.png | 1774 x 887 | rbxassetid://89350893336373 |

Roblox serves these masters at 1024 px on the long edge. Atlas coordinates use the served 1024-square
texture (256 px cells), not the larger source. The card-pack cell has a tighter safe crop to exclude
the next row's potion stopper. The summon button crops its transparent top / bottom padding and uses
stretch sampling; the panel uses 9-slice sampling with a quiet center. Do not enable the retired cartoon
kit or apply universal gold frames over cards: each card's border still conveys its tier.

## Prompt set

All assets: premium Japanese fantasy game UI, Urushi lacquer, restrained antique gold, ivory highlights,
subtle engraved waves / cherry blossoms, front-on 2D art, transparent outside the object, no text, no
numbers or labels. Keep runtime labels editable. Generated PNGs are preserved without destructive edits.

### Navigation atlas

Square transparent PNG, exact 4 x 4 evenly spaced icon grid, equally weighted icons centered within each
cell with transparent safe margins. Warm gold illustrated silhouettes, subtle engraving, recognizable at
24 px; no emoji, background, dividers, frames or glow crossing cells. Row order:

1. Crossed katana, fanned cards, travel satchel, quest scroll.
2. Torii gate, crown, repeat arrows, quick chevrons.
3. Running figure, horse head, faceted shard, double helix.
4. Die, settings cog, flame, healing lotus.

### Inventory atlas

Square transparent PNG, exact 4 x 4 grid with 24 px safe margins. Illustrated gold / brass inventory
emblems with restrained colored enamel, crisp at 32 px. Row order:

1. Green clover, hourglass, engraved coin, navy magical tome.
2. Blue-violet prism, purple crescent moonstone, fiery ember heart, pale-blue snowflake sigil.
3. Violet eye medallion, crown with violet gems, golden pagoda coronet, sealed red-and-gold card pack.
4. Green luck flask, blue lightning flask, amber super-luck flask, violet mythic flask.

### Lacquer panel

One square, flat rectangular panel with clipped corners, thin antique-gold double rim and restrained
seigaiha waves confined to the outer corners. Dark Urushi lacquer / subtle ink grain. Large empty near-black
center for 9-slice expansion. No gems, floating ornaments, dramatic lighting or external shadow. Tiny
transparent outer margin only.

### Vermilion button

One wide front-facing rectangular summon button, clipped corners, thin antique-gold double rim. Rich
muted vermilion with darker crimson edges and subtle ink texture. Delicate cherry-blossom branches at
the side edges and wave details in the bottom corners. Broad empty warm-red center for live text. No
central icon, letters, numbers, thick black outlines, rainbow glow or external shadow.
