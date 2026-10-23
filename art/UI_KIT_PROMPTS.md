# UI kit prompt pack

Every image the game's screens need. Generate these in ForgeGUI (GUI / icon mode), upload them,
and paste each asset id into `src/client/UI/Skin.luau` next to its **Key**. Anything you haven't made
yet keeps the current built-in look, so you can do them in any order (start with **Must have**).

## Rules for every image

- **No text, letters or numbers** in any image: the game draws the words on top, so they can change.
- **Transparent background** (PNG), the piece centred and filling the canvas edge to edge.
- **Same style for all of them.** Add this to every prompt:

> mobile game UI asset, glossy cartoon style, thick dark navy outline, soft bevel and top highlight shine,
> vibrant saturated colours, clean vector look, anime gacha game, isolated on transparent background,
> no text, no letters, centred

- Export at the **size** listed. Panels, banners, buttons and card frames are stretched from their middle
  (9-slice), so keep **all the detail in the corners and edges** and the middle plain.

## Must have

| Key | Size | Prompt |
| --- | --- | --- |
| `Panel` | 1024 x 1024 | large rounded-rectangle game window, deep purple to dark indigo gradient fill, thick glowing violet border, small gold ornaments in the four corners, plain empty middle |
| `Banner` | 1024 x 256 | slanted ribbon title banner, bright purple gradient, white outline, a four-point sparkle star on the left end, empty middle for a title |
| `Close` | 256 x 256 | round glossy red close button with a bold white X |
| `ButtonPurple` | 1024 x 384 | glossy pill-shaped game button, violet gradient, empty middle |
| `ButtonRed` | 1024 x 384 | glossy pill-shaped game button, red-orange gradient, empty middle |
| `ButtonGreen` | 1024 x 384 | glossy pill-shaped game button, emerald green gradient, empty middle |
| `ButtonBlue` | 1024 x 384 | glossy pill-shaped game button, sky blue gradient, empty middle |
| `ButtonGold` | 1024 x 384 | glossy pill-shaped game button, shiny gold gradient, empty middle |
| `RollButton` | 1024 x 512 | big chunky glossy roll button, fiery orange to hot pink gradient, small sparkles around the edge, empty middle |
| `AutoButton` | 1024 x 512 | big chunky glossy button, electric blue gradient, small circular arrows motif in the corners, empty middle |
| `QuickButton` | 1024 x 512 | big chunky glossy button, lime to emerald gradient, small lightning motif in the corners, empty middle |
| `MenuButton` | 512 x 512 | rounded square glossy menu tile, dark purple with a glowing violet edge, empty middle |

### Menu icons (512 x 512 each)

| Key | Prompt |
| --- | --- |
| `BATTLE` | game icon, two crossed swords with a fiery glow |
| `DECK` | game icon, a fanned hand of three glowing trading cards |
| `INDEX` | game icon, an open magic book with a glowing card floating above it |
| `POTIONS` | game icon, a round glass potion flask with bubbling green liquid and a cork |
| `SHOP` | game icon, a shining purple crystal shard with sparkles |
| `GIFTS` | game icon, a red gift box with a gold ribbon, lid popping open with light |
| `FX` | game icon, a cluster of bright sparkles and stars |
| `DEV` | game icon, a wrench and gear |

## Card frames (1024 x 1024 each, transparent middle)

Drawn on top of the card art. Prompt: **ornate square trading card border frame, {MATERIAL}, gems in
the four corners, completely transparent empty middle, thin elegant inner edge**.

| Key | {MATERIAL} |
| --- | --- |
| `Common` | brushed silver steel |
| `Uncommon` | polished green jade |
| `Rare` | blue sapphire and silver |
| `Epic` | purple amethyst crystal |
| `Legendary` | gold with filigree and small wings at the top |
| `Mythic` | crimson ruby with black flames |
| `Secret` | prismatic rainbow crystal with a black eclipse ring at the top |

## Nice to have

| Key | Size | Prompt |
| --- | --- | --- |
| `Shard` | 256 x 256 | game currency icon, a glowing purple crystal shard |
| `Luck` | 256 x 256 | game icon, a glowing green four-leaf clover |
