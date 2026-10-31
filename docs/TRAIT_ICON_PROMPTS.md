# Trait icon artwork

There are 16 traits. Generate one image per prompt, then send the files with the matching trait names.
Use the same model, style reference and lighting for the whole set. These are standalone icons; the
game supplies the rarity frame and trait name. The 2026-10-31 stat bonuses below are already implemented;
these prompts are for artwork only. Keep the thirteen existing names and use the three new Secret names.

All traits boost both DMG and HP. The strongest unlocked trait in a column supplies that multiplier;
Attack / Support slots do not multiply those bonuses together. Their other battle specialties combine.

| Tier | DMG / HP | Tier odds | Chance for each trait |
| --- | --- | --- | --- |
| Rare | 1.10× | 70% | 17.5% |
| Epic | 1.20× | 25% | 6.25% |
| Legendary | 1.40× | 4.5% | 1.5% |
| Mythic | 1.75× | 0.45% | 0.225% |
| Secret | Apex 1.90×; Sovereign / Eternal 2× | 0.05% | 1 in 6,000 |

For every image, copy this style paragraph followed by that trait's subject paragraph:

> Square 1024 × 1024 transparent PNG game icon for a polished Roblox anime card simulator. One bold,
> centered object, filling 78% of the canvas with clear padding on every side. Glossy illustrated 3D
> vector style, sculpted shapes, crisp dark contour, beveled highlights, rich saturated colors, soft
> shadow directly beneath the object. Clean silhouette readable at 32 pixels. Consistent upper-left
> light and slight three-quarter perspective. Isolated object with transparent negative space.
> No words, letters, numbers, emoji, watermark, background scene, outer frame, badge or border.
> No character portrait. Avoid excessive tiny details and broad glow that obscures the silhouette.

| File | Trait | Subject paragraph |
| --- | --- | --- |
| `swift.png` | Swift · Rare | A compact silver winged boot swept forward by three cyan wind ribbons. Rounded steel toe and bright blue accents. Emphasize quick movement with a clear horizontal silhouette. |
| `keen.png` | Keen · Rare | One luminous cyan precision eye set inside a silver aiming reticle with four short points. Dark navy iris, bright focused pupil, clean symmetrical construction. Precision rather than a realistic eyeball. |
| `sturdy.png` | Sturdy · Rare | A broad solid shield carved from dark blue stone, with a silver rim and a single glowing cyan seam. Thick, compact and dependable, with two large stone facets. |
| `eager.png` | Eager · Rare | A small polished silver energy vessel holding a bright cyan rising spark. Three simple energy segments inside the vessel, with a dynamic spark lifting from the top. It should read as starting energy, not a modern battery emoji. |
| `fleet.png` | Fleet · Epic | Two swept-back silver feather wings forming a forward arrow, wrapped in one violet wind ribbon. More elegant and aerodynamic than the Swift boot, with broad readable feathers. |
| `sharp.png` | Sharp · Epic | A single angled obsidian dagger with a silver cutting edge and a bright violet slash glint. Thick, dramatic blade silhouette; one clean star-shaped glint on its tip. |
| `stalwart.png` | Stalwart · Epic | A layered silver tower shield with two violet crystal braces and a dark purple center. Heavy protective silhouette, visibly more reinforced than Sturdy, with broad armor plates. |
| `charged.png` | Charged · Epic | A faceted violet power crystal enclosed by two curved silver conductor prongs. Two short violet lightning forks arc into the crystal. Compact stored energy with a bright white core. |
| `tempest.png` | Tempest · Legendary | A gold-edged twisting storm funnel with one bright amber lightning bolt spiraling through its center. Three broad curved bands, dramatic but legible; a single metallic gold fin at the top. |
| `assassin.png` | Assassin · Legendary | Two crossed dark daggers behind a gold crescent blade, with a small crimson focus gem at their intersection. Elegant stealth equipment, polished gold cutting edges, no face or person. |
| `bulwark.png` | Bulwark · Legendary | A broad dark-metal fortress shield with three golden battlements across its top and a glowing amber central core. Unmistakable defensive wall silhouette, substantial layered metal. |
| `godspeed.png` | Godspeed · Mythic | A radiant white-gold winged lightning spear encircled by a crimson energy arc. Two bold swept wings and a long lightning tip; restrained purple edge glow. Powerful ascending movement, with no crown or text. |
| `executioner.png` | Executioner · Mythic | A massive obsidian execution blade crossing a curved crimson scythe edge, a bright red gem at the joint and sharp white-gold bevels. Formidable clean equipment silhouette, no blood, gore, skull or person. |
| `apex.png` | Apex · Secret | An obsidian falcon crest with two sharply swept wings, a brilliant violet diamond core and three short magenta speed trails. White platinum cutting edges. A powerful predatory silhouette representing speed and precision, without a face, letters or surrounding badge. |
| `sovereign.png` | Sovereign · Secret | A floating black-platinum crown with five broad upward points surrounding a radiant crimson star-shaped crystal. Two short violet energy arcs curve behind it. Commanding, weighty and compact; exquisite white highlights and clean metal planes, no jewelry clutter or outer medallion. |
| `eternal.png` | Eternal · Secret | A luminous violet infinity loop forged from two intertwined platinum armor bands, protecting a small emerald energy core. Three broad protective metal fins frame the lower half. A crisp enduring defense silhouette, bright white edges, restrained magenta glow, no circular badge or outer border. |

Keep transparent backgrounds and padding in the final exports. Do not put trait names or rarity
letters inside the images. The icon integration pass will connect the supplied files to these exact
trait IDs. Save files as the exact filenames above. Until supplied, the picker uses clean text instead
of emoji stand-ins.

The subjects match the implemented specialties: Swift +5% speed; Keen +5% crit; Sturdy +5% damage
reduction; Eager +15% starting Ultimate charge; Fleet +10% speed; Sharp +20% crit damage; Stalwart
+10% damage reduction; Charged +30% starting charge; Tempest +10% speed / +20% starting charge;
Assassin +10% crit / +25% crit damage; Bulwark +15% damage reduction / +5% speed; Godspeed +15%
speed / +40% starting charge; Executioner +15% crit / +40% crit damage; Apex +20% speed / +10% crit;
Sovereign +20% crit / +50% crit damage; Eternal +20% damage reduction / +50% starting charge.
