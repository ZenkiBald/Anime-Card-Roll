# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses, climb an endless
tower and join server raids. Original design doc (it predates the border tiers, so its rarity sections are out of date):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

This file describes the game as it is now (2026-10-30, after the luck / odds / boss HP / fusion pass). How it got here is in `git log` (one commit per pass).
Launch steps: `docs/LAUNCH_CHECKLIST.md`.
Two AIs share this repo, one at a time (Claude Code and ChatGPT / Codex): `AGENTS.md` is the common brief. Read
`docs/HANDOFF.md` first (branch, status, open asks) and add a log entry there when you finish a pass.

## How the game works

**Studio status.** The 2026-10-22 world / UI / sound pass was verified in Studio. Everything after it was built in cloud
sessions with headless tests + luau-lsp only; the user has since play-tested the HUD, deck screen, Index, quests and a
tower fight (screenshots 2026-10-24) and the fixes from that are in (the second round's list is in the checklist,
section 5). The user confirmed the town is bright again on 2026-10-26 and supplied iPhone HUD / SQUAD / BAG / tower
screenshots. The resulting readability pass was checked in Studio's iPhone 14 landscape emulator (HUD, SQUAD, BAG,
one Normal fight; no new runtime errors). All 27 owned vault tile names and current BAG names fit there.
The updated layout still needs a real iPhone check; per-world transitions remain unconfirmed. Treat anything not named here as unseen.
The subsequent illustrated UI kit was implemented and checked in desktop Studio (HUD, SQUAD, BAG, battle controls /
intro): the uploaded textures loaded, names and filter chips fit, and there were no new runtime errors.
The 2026-10-30 real-time battle pass (archetype timers, Boss Shield, Clash ring, HOLD ULT, guard links, card
animations) was built headless only: its battle screen and Arena beams are unseen in Studio. So is the following
luck / odds / boss HP / fusion pass (cinematic reveal DMG / HP pill and SKIP ALL, Clash jump hold).
The following first-session pass was reviewed in desktop Studio using an isolated in-memory profile
with normal unlocks. Ten starter-pack pulls produced four Attack cards / three Supports and one Gold:
World 1 Normal won in 22.3 s, Corrupted Hard in 66.8 s. These are observed runs, not fixture medians.
The former eight-card guide gate stalled at7/8 despite a capable team; it now counts four equipped
Attack cards only. First-boss quest claiming / title, fixed battle footer and actual team counts were
checked. A real Space press won a Clash at1x; JumpPower / JumpHeight were0 during the prompt and restored
to50 /7.2 after. Original save card / deck tables were verified unchanged before restoring accessors.

**World.** A big Studio-built map (terrain, Creator Store models, AI meshes, StreamingEnabled): spawn town in the middle,
Ember Village (W), Frostfang Peaks (N), Neon Abyss (E), Stormspire Isle (S, over a second bridge), each with a portal and
its boss. Town NPCs: Kenji (guide), Hoshi (fusion + pack alchemy), Kenshin (traits), Madame Fortuna (Lucky Wheel), the
tower gate and leaderboards. The spawn plaza has a thin stone fountain border, short service approaches and two
wooden benches with flower planters. Stalls / services sit around the edge; an explicit Tower marker puts the
an endless jade-roofed pagoda northwest of the fountain. `tools/studio/town-polish.luau` applies the plaza's place-only edits once
and keeps a reversible backup in ServerStorage. The local saved place is under `studio-local/` (ignored by Git).
The service figures / workbenches / wheel canopy are runtime parts built by `World`, `TownModels` and
`TownServices`, so those changes travel through Git / Rojo. Infinite Tower uses the user's existing 22-floor
Studio Assistant model, refined in place: a 52.7-stud grand first hall, floor two at 60% width, then 0.94x
taper; named foundation / roof stacking, curved Slate eaves, corner ridges, base gables, recessed amber
windows, timber framing, lanterns, entrance steps and embers. An upper mist bank obscures the skyline.
It stands outside the lobby at (-135, 7.4, -95), with a 46-stud local night zone and the existing tower
prompt / BoardSpot. No global Lighting settings are changed. The anchored model and untouched original
are versioned in `assets/models/infinite-tower-20261029`; Rojo loads a ServerStorage template. World keeps
an existing refined workspace model or restores the template in floor-sized chunks, reconnects its
entrance / zone and moves intersecting trees. TownServices skips the older generated tower when this
model is active; the older builder remains a fallback. Floors stream atomically. HubFx distance-culls
the two emitters, pauses them behind panels and reduces rates to 25% on LOW; only the closest six
lantern lights within 75 studs run, with none on LOW. Tower progression / rewards are unchanged.
Four original R15 service rigs have colored outfits / welded themed tools and Roblox idle animation 507766666
(played locally by HubFx); only their root is anchored. Hoshi has a card workbench, Kenshin scrolls / crystals,
and Kenji a lectern. Avatar-service failure retains the old procedural figure so prompts still exist. Boss models
are unchanged. Town services only work beside their NPC (server `NpcRange`, 24 studs). `WorldSigns` restores
floating town / world-door titles in white outlined FredokaOne, with a smaller colored subtitle and 600-stud
visibility; the saved map's old labels are disabled only in the running copy. Wheel / tower plaques remain
physical and double-sided (145 studs). Compact NPC plates show within 76 studs, with the name / role inside 38 and a short
service label farther out. Closest visible NPC plates take priority when their screen rectangles overlap;
plates stay below the top HUD. All labels stay opaque through 80% of their range, fade at the edge (HubFx),
never draw over the world, and hide with player name tags while a panel,
fight or reveal is up (`Modal.Changed`, `HubFx.SetWorldLabelsHidden`). TRAVEL fast-travels (server-owned). Mounts (5, G to ride), a shoulder pet, dash (Q, two charges) and a
double jump. Lighting: a bright town afternoon (`LightingSetup`); each world has its own theme (`ZoneFx` moods: Ember golden sunset, Frostfang snowy morning, Neon Abyss violet night, Stormspire grey storm with lightning) and zone music.

**Rolling.** The server owns every roll. Each pull picks a card by its `Weight` from the selected collection (`Collections.Pool`; a boss's
own card joins after that boss's first Normal clear) and rolls its **border**, which is the tier: Base ("Normal" in
saves) 1x / Gold 4x / Rainbow 16x / Secret 64x stats, base odds 1 in 200 / 5,000 / 500,000 (rare on purpose: story
bosses are beaten with Base + Gold, Rainbow and Secret are the tower chase). Luck raises each special border by luck ^
0.6 / 0.8 / 1 (Border Chance and surges multiply them; the specials are capped at 50% together). Total luck = (earned base + strongest potion bonus + active sky bonus) x event / Raid Luck / Totem / VIP
(`Meta.TotalLuck`), without a hard total-luck cap. Borders use raw luck through 35x (`Config.Roll.LuckSoftStart`), then
`35 + 10 * log(1 + (luck - 35) / 10)`; the 50% combined special-border safety limit remains. ODDS uses the same formula.
**Luck also tilts the card pick** (`Cards.LuckTilt`, `Cards.Tilt`): a card of 1 in 100 or rarer weighs
`1 + (effective luck - 1) x 0.12 x rareness` (rareness 0 at 1 in 100, 1 at 1 in 800+; at most 5x), so at 35-40x
high cards come ~2.5x as often, elite ~3.5x, apex ~4x, the W4 boss card ~4.5x; `PullChances(..., luck)` in
RollService single / bulk pulls and the ODDS panel. A maxed player (Training + 3 best relics + both artifacts +
Potion III + Blood Moon x Raid Luck x Lucky Storm) reaches ~54x effective luck (meta_test). Pure luck: no pity. Every card shows its **rarity number** per border (`Cards.Rarity`: 1 / (pull
chance x border chance) at 1x luck, snapped to a round number by `Odds.Round` like "7,500,000", never "1 in"; it is the
big number on card tiles; `Odds.FormatRarity` for the ODDS panel). Every pull also rolls a foil (Aura / Golden Ki /
Demon Seal, battle-only). ROLL (R), QUICK toggle (T: ROLL plays the short reveal, saved), AUTO (E; never stops by
itself: a pull eligible under saved reveal preferences holds the next roll `Config.AutoBigRevealHold` s, then it
rolls on). Momentum chain: +1% speed / +0.01x luck per 10 rolls, max 500, breaks after 30 s idle. Overcharge Surge every
25th roll (`TotalRolls % 25`): 5x border odds, or 3 cards at 6x on a perfect tap; HUD meter binds to `SurgeProgress`.
A pull of combined rarity 1 in 10,000,000 or rarer (`Config.ChatAnnounceFrom`) also posts a system chat line
(`Main.client` chatAnnounce), and 1 in 1,000,000,000+ a highlighted BILLION PULL line; a bulk opening announces
up to three such highlights. Rainbow+ pulls are announced; a Secret gets "[SERVER] {Player} rolled a SECRET BORDER {Card}!" here and "[GLOBAL] ..."
in every other live server (`GlobalAnnounce`, MessagingService). Weekly **Featured Card** (`Cards.FeaturedAt`): one rare
non-boss card weighs x3 for a week (Monday 00:00 UTC), the same on every server; the event pill, ODDS and Index show it.

**Collections and Celestial Skies.** The CARD PACKS keeper near spawn selects a saved normal-card pool.
Normal Collection includes every normal card; Chakra Legends is available immediately. Galactic Warriors,
Cursed Spirits, Demon Hunters and Soul Reapers unlock from the displayed boss clears. ROLL, AUTO and every
consumable Roll Pack use that selection; any unlocked boss card remains eligible. Existing cards stay owned
and decks may mix collections. The selector shows contents and exact featured-adjusted card chances; ACTIVE
PACK appears over ROLL. Selection requires the keeper's 24-stud server range. A brand-new empty save receives
one ten-card Roll Pack once, and Kenji explains opening it / BEST DECK / the first boss.
The first tracker points at that starter pack. Kenji's second quest requires four Attack cards;
Supports are optional and never block advancing to the first boss. Claiming Trial by Flame also
unlocks the permanent First Victory title, worn automatically only if no title is equipped. Existing
players who already claimed that quest receive the title through an idempotent SaveMigration backfill;
pending claimants still use the ordinary claim. No existing quest step or supply is reset.

`Weather` hashes server time and seed 731947 into shared 15-minute slots. Events start at a varied offset
inside each slot, with a 150-second forecast. Quiet Skies is the default. Limitbreak Skies (Dragon Ball),
Soulfall (Bleach), Cursed Night (Jujutsu Kaisen) and Blood Moon (Demon Slayer) each last 5 minutes and
add +0.5 / +1 / +1 / +2 luck; per slot Limitbreak 30% / Soulfall 20% / Cursed Night 20% / Blood Moon 5% / none 25%. Each has four separate Attack cards and cohesive clothed portrait art in
`art/cards/celestial-clothed-20261029/`. Seven background / atmosphere edits live in
`art/cards/celestial-reframed-20261030/` (exact built-in imagegen prompts, hashes, old / new asset ids);
the other nine original portraits stay unchanged. All retain the original pulled-back 2:3 composition,
poses and covered outfits: no zoomed bust replacements. Blood Moon has crimson moons, Soulfall spectral
silver-blue skies, Cursed Night violet storms; each character keeps its own power colors. `CardView.Art`
covers sky thumbnails from the top at the original aspect ratio, preserving heads without changing the
source artwork; full portrait cards retain the wider original composition. The sky HUD uses that same
renderer and actual display names, never names derived from internal ids. `CelestialArt` maps the assets;
`Config.CelestialCardsReady=true`. All sixteen Celestial display names and technique labels use the user's
approved epithet direction (short names such as Silver Sovereign / All-Seeing Emperor / Crescent Demon).
Their original ids, series grouping, ownership and mechanical kits remain intact. No save-format migration
is required for display renames; save_test checks all sixteen saved copy piles / selected borders survive.
Authored base ATK (`ATK` in each `CelestialCards` spec) and twice that HP range from Emerald Titan's 2,750
to Immortal Progenitor's 6,000.
Their Basic / Skill / Ultimate damage and timers follow their archetype band like every Attack card (see Deck
and battle; the rarest sky cards sit at the top of their band). They retain
borders, 100:1 fusion, traits, mastery and their own Codex section;
they do not count toward normal completion rewards. No event Supports or same-weather column sync.

Normal pulls keep their usual rates / quantities. While a sky is active, every normal pull (a click, each
Triple Roll card, every pack pull) also searches it once; there is no time throttle. `CelestialRolls.Search`
draws all of a click's or a pack's searches at once (BulkRoll multinomial), with disjoint per-card chances
`1 / SkyOneIn x (1 + (luck - 1) x 0.35)` (`CelestialRolls.LuckWeight`, 2026-10-30) and a no-find remainder (capped
at 50% a search for absurd luck). The user's 2026-10-30 odds: Limitbreak: Emerald Titan 300 / Azure Fusion 400 /
Ego Sovereign 500 / Silver Sovereign 650; Soulfall: Hollow Ascendant 600 / Chrysalis Overlord 800 /
Sunblade Patriarch 1,000 / All-Seeing Emperor 1,250; Cursed Night: Nullborn Hunter 600 / Bound Prodigy 800 /
Honored Anomaly 1,000 / Four-Armed Calamity 1,250; Blood Moon: Shattering Compass 1,200 / Crimson Frost
Sovereign 1,500 / Crescent Demon 2,000 / Immortal Progenitor 2,500. Displayed border rarity uses that base
chance and border odds (Crescent Demon Secret 1 in 1 billion, Immortal Progenitor 1 in 1.25 billion). Rarer sky cards have greater actual stats, and each outstats every
normal / boss card that is no rarer. Bulk receipts include every normal and
bonus card in the same rarest-first highlights / complete grouped summary. No out-of-weather event drops.
Matching sky cards gain +20% ATK / max HP in every battle, reverting when it ends; transitions preserve HP
percentage and never provide free healing. BEST DECK accounts for the active sky.

`WeatherService` owns natural / local state and the rate-limited Weather remote. Celestial Orb summons a
random sky locally for 3 minutes (45 / 25 / 25 / 5%). Sky Sigils summon their named sky and craft in BAG from
10 Fragments (Blood Moon 25). Celestial Hourglass extends a sky once by 2 minutes. Owned Sigils / Orbs
can immediately replace or refresh any active sky, including Blood Moon; no gameplay summon cooldown.
Each use consumes one item; remote rate limiting still applies. Expired overrides return to the shared
schedule. A named banner announces summons.
Fragments / supplies are earned through daily / streak / playtime / milestone / quest / wheel rewards,
raids, new tower records and Corrupted Hard / Nightmare bosses (+20% leader HP during an active sky).
The sky HUD is read-only: anime, green luck bonus, remaining time and four eligible slots, or a forecast.
Unowned slots have dark mystery art / ??? names; ownership reveals their portrait / name immediately.
Each slot shows its base rarity, and the hint states the shared search pace. Items / crafting stay in
BAG > SKY ITEMS. Illustrated active-potion / worn-relic icons sit at
bottom RIGHT with hover / tap details. Short screens use one compact icon row and separate progress bars.
`SkyFx` adds subtle camera-local grading / bounded motes (12/s, 3/s on LOW), paused behind panels / fights;
it never overwrites world or tower-night lighting. The tower-night `ZoneFx.InfiniteTower` mood from Studio
Assistant is preserved in source. World reconnects its marker / radius to the refined tower entrance;
the lobby stays outside that zone. Save the open Studio place to preserve the original-model / marker /
scenery backups in ServerStorage; the exported tower itself travels through Git / Rojo.

**Cards.** 37 normal cards: 26 character Attacks (including 4 boss cards) + 11 relic / technique Supports.
A separate event pool adds 16 Celestial Attack cards (53 cards total). Normal cards retain their anime-style
epithet names for the private prototype (see Rules). **Rarity tiers (2026-10-30):** `Weight` is a pull chance out of
`Cards.WeightTotal` (10,000; weights are written `10000 / N`), and every card's base ATK is authored (HP = 2 x ATK,
`Cards.Scale` = 1). The user's 2026-10-30 odds: starters 1 in 10-16 / 450-500 ATK (Lotus Blossom, Spirit Weaver,
Thunder Flash, Celestial Strategist + Wisteria Vial, Thunderclap, Mitotic Seal: they take what's left of the pool,
so they can't reach the asked 7-10), lower-mid 1 in 20-30 / 700-800, mid 1 in 50-70 / 1,050-1,200, upper-mid
1 in 100-140 / 1,450-1,600, high 1 in 200-250 / 1,850-2,050, elite 1 in 350 / 2,200-2,400 (Secret 1 in 175M), apex
1 in 500 / 2,600-2,700 (Secret 1 in 250M), boss cards W1-W4 1 in 400 / 500 / 650 / 800 (Secret 200M-400M) /
2,650-3,250. Among normal cards a rarer card never has less ATK; boss cards are ranked among themselves (W1's
1 in 400 / 2,650 sits beside the 1 in 500 apex cards). A rare Gold can outdo a common Rainbow. Each has an
`Element`, a `Role` (Striker / Hexer / Mender / Warder) and abilities built from the effect library at the top of
`Cards.luau`; All 11 former character Supports now have a damaging Basic / Skill / Ultimate and a triggered Passive, keeping their ids, names and character art. The other Attack kits retain their previous abilities. **Archetypes (2026-10-30):** `Cards.Archetype` sorts every Attack card by SPD into
Fast (120-135) / Balanced (105-119) / Heavy (85-104); a post-build pass in `Cards.luau` sets `BasicInterval`,
`SkillCooldown` (seconds) and `UltimateCost` (80 / 100 / 135) from `Config.Battle.Archetypes` and fits each
Basic / Skill / Ultimate's per-cast damage into its band (Fast 65-75 / 240-270 / 480-540%, Balanced 100-110 /
280-320 / 580-650%, Heavy 150-180 / 340-400 / 750-900%), keeping hit counts, every per-hit % a multiple of 5;
faster cards get the shorter timers and rarer cards the higher damage. Skills no longer count actions
(`Ability.Every` is only an OnAct passive interval). Support relics have one passive definition
and its subtitle (`Title`) and colour (`Accent`) fit its name and element. **Duplicates (2026-10-30):** every copy
past the first at the border a card fights at adds +0.5% ATK / HP, up to +25% (`Cards.DupeBonus`, `Cards.Stat` /
`Power` take `copies`; BattleService sends `Copies` per unit; Deck Power, the inspector, tooltips and reveals show
it). Stars remain a legacy save field, always zero on normal rolls, and copy-based Awakening is retired.
Copies pile up per border (`BorderCopies`); each owned border has its own tile, and the deck fights at the chosen
border (`Deck.PlayBorder`, save `Play`). **Border fusion** at Hoshi costs 100 copies of one border (`Config.FusionCopies`,
read through `Cards.FusionCost`; the same for every card and step, the user's call after a short 50 / 25 try) for
one copy at the next border, with no extra reward.

**Battle Mastery** replaces copy upgrades (`Awaken.luau` retains its old module name). Each participating Attack
and paired Support earns one mark for winning each distinct story boss/difficulty, even if previously cleared
with another card. Repeated clears, losses, raids and towers grant no marks. Marks are saved as the card's
`Mastery` map keyed by `Bosses.FightKey`. At 1 / 3 / 6 / 10 challenges: +5% attack speed, +10% Skill / Ultimate
damage, a 350% bond combo instead of 300%, then trait slot 2. Mastery never multiplies base ATK / HP or passive
percentages. Existing second-slot access survives migration (`Trait2Unlocked`); old copies grant no free mastery.
Cards, borders, copies, traits and presets are preserved by the idempotent SaveMigration steps.

Traits are bought at Kenshin with Trait Shards (battle-only: SPD / crit / guard / energy, never ATK /
HP); AUTO continues until a ticked trait lands, Stop, closing the panel, insufficient shards or leaving Kenshin.
Each server request validates / charges at most `Traits.AutoMax` rolls; Stop finishes the current batch. The UI
shows cumulative rolls and spending for the run. A miss keeps the old trait. Every action is rate-limited. The Index lists
every card by best border with completion rewards per border. A card can be worn as your avatar (element aura; Rainbow
fire footsteps, Secret celestial motes). That same equip choice adds a double-sided Showcase Flex Card
measuring 3.8 x 5.4 x 0.12 studs at HumanoidRootPart-local (3.2, 2.6, 2.8), tilted -15 degrees in yaw /
6 degrees in roll, behind / beside the shoulder. Both art faces have LightInfluence 0 / Brightness 2.
`client/Showcase` supplies three element / border-colored 3D layers (core glow 18/s, rising wisps 35/s,
theme particles 25/s) and a shadowless light (brightness 3, range 14). Only the local player / nearest
three visible showcases get full rates and lights; others get 20% rates, offscreen ones pause. LOW
effects uses 25% of those rates and no showcase light. A 220 x 75 billboard above the card shows border /
name / "1 in" rarity, visible to 90 studs; Rainbow / Secret tags animate via the shared gradient loop.
It uses the existing server-owned AvatarCard / AvatarBorder attributes; no new save field. Client visuals
are culled at 120 studs and cleaned on unequip / respawn / leaving range.

**Deck and battle.** 4 Attack + 4 Support, 3 saved presets (+2 VIP), weather-aware BEST DECK.
Each Support works with any Attack in its numbered column. `ColumnBonds` adds one authored familiar bonus
when its matching character occupies that column: +5 percentage points to healing / speed / shield / evade,
+10 points to counter / drain chance or opening charge, one extra curse / reflection activation, or +5% guard
for the beast-seal pair. Fatal-blow return stays once; drain healing caps do not rise. Skill sheets and
hover tooltips put FAMILIAR BOND first: exact partner, ACTIVE / NOT ACTIVE, actual before / after values
at the Support's inspected or equipped border, and the combo trigger. Opening charge still caps at 50%
(Secret Blink Kunai 45% -> 50%). Ordinary column links say SUPPORT; only matching familiars say BOND ACTIVE.
A familiar pair gets one 300% combo (350% at Mastery 3), when the boss reaches half HP or after 45 seconds. Each Support modifies the
Attack card with the matching slot number. Supports have no damage, HP, action bar, Skill or Ultimate; counters,
reflected statuses and Black Flames belong to the supported Attack card. Original character ownership, ids, names and portraits remain. On first load, `SupportRelicsVersion = 1` grants each owned former Support's replacement relic an independent copy of its saved collection (copies / borders / traits / foil / Mastery / selected border), without overwriting an already-owned relic. All preset Support positions and the older single deck map to the replacement; Attack lineups stay as chosen. Compensation runs once, before deck cleanup; further rolls award only the card rolled.
`Cards.Support` owns the trigger, effect, cost, chance, limits and authored text. `Cards.SupportValue` applies border
strength (Base 1 / Gold 1.25 / Rainbow 1.5 / Secret 1.75x), then rounds the **actual server
value** to the nearest 5 percentage points (positive minimum 5%, maximum 50%), at least 5 points above the border
below so no two borders repeat. Authored `Values` override that: Eight Trigrams Seal's Crimson Chakra Cloak returns
at 55% / 70% / 85% / 100% HP on Base / Gold / Rainbow / Secret. Trigger counts, chances, secondary Burns and healing caps
are fixed. **No passive carries a self-penalty** (the user's call, 2026-10-30): Attack, sky and Support passives lost
their DMG / speed / guard costs and healing locks; Heavenly Restriction's Weaken lands on the enemy. Passive cards add no Attack rating; BEST DECK ranks them separately by border / rarity. Support traits, foils and mastery affect the supported Attack
card; they no longer sit unused on a passive unit.

Support kits (base strengths; inspect the card for its rounded value at another border):

| Card | Passive |
| --- | --- |
| Diamond Mitotic Seal | Below 50% HP, cleanse Burn / Freeze and heal 20% max HP; 1 activation. |
| Binding Blood Vow | After an enemy hit, 25% chance to return 15% of DMG taken as an Attack-card counter; 4 activations. |
| First Form: Thunderclap | On entry, +20% attack speed for 3 turns; 1 activation. |
| Heavenly Restriction | 10% evade chance; successful evades Weaken the attacker by 10% for 1 turn; 4 activations. |
| Cursed Ocular Seal | Skills / Ultimates roll once per cast: 25% chance to Weaken by 15% for 2 turns and Burn for 10% DMG each turn for 3 turns; 4 activations. |
| Gourd of Living Sand | On entry, 25% max HP shield; 1 activation. |
| Wisteria Antidote Vial | On defeating an opponent, heal 20% max HP; 3 activations. |
| Blink Kunai Seal | On entry, 25% Ultimate charge; 1 activation, requires an Ultimate. |
| Eight Trigrams Seal | Upon a fatal blow, return at 55% (Base) to 100% (Secret) HP; 1 activation. |
| Chakra Puppet Threads | Cleanse and reflect Burn / Freeze; reflected Burn is 15% DMG for 3 turns; 2 applications. |
| Stormheart Mantle | Direct hits have a 25% chance to drain 10% of actual DMG as HP; capped at 25% max HP per fight; overkill excluded. |

Attack passives, Auras and Signatures are generic triggered bundles (`Ability.Trigger`, `Chance`, `Limit`, optional
`Every`). `BattleEngine:Trigger` handles OnEntry / OnHit / OnCrit / OnKill / OnAct / BelowHalf, tracks activations and
prevents reentry into the same bundle. On-hit effects roll for every actual hit; Crows explicitly share one roll per
Skill / Ultimate cast. Every passive combines a trigger with a bound (a chance, an activation limit or a condition)
and no self-penalty. Energy effects grant a % of the card's own Ultimate cost. `Bleed` and `Burn` share the
timed-damage scheduler but have separate status flags / text. The engine still honours `HealingLock` (HEAL BLOCK
badge, snapshot N) though no card applies one now. Reflected Freeze costs the enemy its next action (snapshot Z); Bleed is L.
Posthumous damage cannot consume a healing activation or heal a defeated card.
Elements are internal visual / ability themes only (`Elements.CombatEnabled=false`): neutral damage, no counter
multiplier, elemental stagger bonus or element-count synergy. Familiar bonds use matching columns only. Every fight is the leader +
3 guards (Striker / Hexer / Mender / Warder); tap an enemy to focus it; win when the leader falls.
**Real-time rules (2026-10-30, `Config.Battle`):** each Attack card runs its own Basic interval, Skill cooldown and
energy (5.4/s, plus 3 per enemy hit at most every 2 s); a Skill whose cooldown is full goes before a due Basic; SPD
buffs / slows scale both timers; the four slots open their first Basics 0 / 0.35 / 0.7 / 1.05 s in (`SlotOffsets`).
Enemies keep SPD action bars (`TurnSeconds` 2.5, one enemy per tick), and status durations still count 2.5 s turns.
Ultimates: tap a full card (BattleInput Ultimate) or AUTO ULT (default on, saved `Settings.AutoUlt`; one at a time,
3 s apart). **HOLD ULT FOR BREAK** (default on, `Settings.HoldUlt`, BattleInput HoldUlt) keeps full Ultimates
while the leader's Shield bar is over 60% (cards show HOLD / flag H, snapshot Ho), then chains them 0.5 s apart
into the break. Server-side, so AFK and HIDE BATTLE keep firing; `BattleControlsVersion` switched both on once.
**Boss Shield** (the leader's old Stagger bar, snapshot St / Br): the leader takes 0.5x while it stands (muted 🛡
numbers, event Sd) and 1.5x once broken (big gold numbers, Bk). Hits fill it by DMG % x `ShieldFill` (Basic 0.5%,
Skill 0.8%, Heavy Skills x2, Ultimate 0.4% per 100%), a guard KO adds 25%, a standing Warder absorbs 30% of hit
fill; full = glass-shatter break, 6 s stun, its warned move cancelled. **Boss Clash:** a leader's warned move that
hits the squad opens a 1.2 s window (event ClashOpen, snapshot Cl) when its warning runs out; the CLICK / SPACE TO
CLASH! ring (Space / gamepad A / X via ContextActionService at High priority, sunk, never bound while hidden; the
character's JumpHeight / JumpPower are zeroed while it shows and restored after) sends BattleInput Clash
(own 2/s limiter). In time, the strongest standing card dashes in: 200% ATK back at the leader, the move's damage
-75%, +30% Shield. Ignored, it lands as normal. **Guards link to the leader** (Arena beams in role colours): a
Warder's Protect cuts its damage taken 40%; a Mender mends it 3% max HP every 8 s and wipes its debuffs / burns
(its old heal move is gone, the rally stays); each Striker / Hexer action stacks Expose (+5% DMG taken) / Weaken
(-5% DMG dealt, plus a Burn) on your highest-ATK card, up to 5, lasting 8 s from the last stack. **Vanguard:**
Attack slot 1 draws 50% of single-target enemy attacks (80% if its Role is Warder). Every enemy hit still takes
at least MinHit of the card's max HP (guard 1%, leader 2%, leader's warned move 6% and SkillPierce 40% through
shields). At 2x, simulation timers advance twice as fast. Attack cards show "SKILL 4.2s" / SKILL READY (snapshot
`K` seconds, `NextIn` to the next Basic); blue bars are Basic progress, gold bars Ultimate charge (`EC` cost).
Card animations (`UI/Battle` `animateAttack`): Fast Basics tilt 15° and dart, Heavy Basics wind up to 1.25x and
slam with a 0.06 s hit-stop and camera shake, Balanced Basics lunge; Skills spin 360° (Heavy: lunge with a border
flash); Ultimates rise 1.4x with an aura flare under a 0.5 s cut-in, then recoil; hit cards flash white then red,
squash and shake; full cards hover and shiver. Support chips show passive status / remaining uses, with no action or energy bar. Results show passive triggers / dodges
or actual healing / shields instead of assigning every support a healing score.
The boss bar shows its next big move (snapshot Nx). Cost Challenge (Deck Cost by border 2/4/6/8, cap 30) for x2 Trait Shards.
The engine (`BattleEngine`) is pure and runs headless in tests. Fights are staged in 3D at the boss's spot in its world
(`UI/Arena`, low cinematic camera, guards as separate faction / role models, with model portraits in their target panels; beams fly from the card slots to the 3D figures,
hits flash and recoil, guards lunge, boss skills and crits shake the camera; a defeated guard or leader topples
and fades in dark red; callouts show one at a time with at most three queued); no map = the 2D fallback. Damage
numbers have bounded pixel sizes and at most two per target; on the squad's cards they spawn above the frame.
On short phone screens, guard target panels sit in a fixed right rail and the duplicate leader plate hides;
Action countdowns use the line below each Attack card's name. Auto Roll continues with its feed hidden during fights,
and DASH hides while watching. HIDE BATTLE restores the normal camera, movement, dash, zone effects and HUD
while the server fight continues. A RETURN TO BATTLE widget shows leader HP / time, or VIEW RESULT when finished.
Hidden auto-climb / retry stays hidden; results do not interrupt exploration. A validated, rate-limited BattleInput
View action restores character streaming focus while exploring. Supports have no cast tags.

Story retinues now have distinct names / moves / models: Crimson-Eye clan guards in Ember, Frost Court, Void Court
and Storm Court. Guard ids / roles / effects remain compatible with mixed tower squads. The Rojo-managed
`assets/models/bosses-20261027/BossKit.rbxm` supplies the user's selected boss appearances: kurogane uses
Naruto Kurama Avatar, rimeveil uses R6 Golden Frieza Rig, vex uses Madara Susanoo, and tenrai uses Muzan [R6].
Existing boss / card names, ids, stats and retinues remain. Imported scripts / remotes / GUI / sounds / emitters
were removed; clones also strip executable / interactive content. Cosmetic Humanoids retain clothing with
state evaluation disabled. Templates face -Z; Susanoo's shell uses shaded blue rather than dark Neon.
ModelView fits tails / wings to viewport width; arena ground rays ignore the world boss NPC. The former kit
is archived beside the new asset as `PreviousBossKit.rbxm`; the installer and manifest document provenance.

**Content.** 4 worlds x Normal / Hard / Nightmare (D 1-12). Boss HP (the user's second 2026-10-30 table, every
fight winnable): World 1 60k / 220k / 750k, World 2 900k / 2.8M / 7.5M, World 3 4.5M / 12M / 32M, World 4 14M / 45M
/ 125M; ATK = 4% of the fixture squad's average card HP. Recommended Attack rating 22.5k ... 16.5M = each fixture
squad's power (`tests/fixtures.luau`): W1 four Base starters (~57 s, window 50-90), 2 Gold + 2 Base, 4 Gold; W2
4 Gold, 2 Rainbow + 2 Gold, 4 Rainbow; W3 2 Rainbow + 2 Gold, 4 Rainbow, 1 Secret + 3 Rainbow (~98 s with the
strongest such squad, window 60-100); W4 4 Rainbow apex / boss, 2 Secret + 2 Rainbow, 4 Secret Blood Moon (~119 s,
window 110-140). Any all-Base starter squad clears World 1 Normal. Boss wins pay Roll Packs, Trait Shards and potions (no gear). A rewarded win starts a persisted five-minute
cooldown for that boss/difficulty. Fighting again during it is PRACTICE: no rewards, XP, mastery or clear
progress. Losses do not start a cooldown. Story wins return to results; AUTO CLIMB remains opt-in for towers. With it on, a win shows a 1 s banner (no
results panel unless it's a milestone, relic / artifact or boss-card unlock) and the next fight starts with a 0.3 s
FIGHT! (BattleStart `{ Quick = true }`, `Config.Battle.QuickIntroSeconds`); in a tower it also sweeps: floors the deck
overpowers by `Config.Battle.SweepPower` (3x) are won and paid at once, up to `SweepFloors` (5) per start (BattleService,
same recordResult + towerRewards as a fought win; never the Pagoda's floor 100). Results show a pack progress bar and
the streak's totals when no pack dropped. SCOUT is four unit cards (leader + guards: crests, role, big move, affix). Two towers (BATTLE > TOWER / PAGODA), each floor an echo of a world boss with
affixes, Guardians every 10th, the daily mutator. Infinite Tower: a run (recommended 16.5k x 1.068^(floor-1); `Tower.Curve.Points`
re-measured for the new boss HP, floor 6 is a World 1 Normal squad, floor 23 World 1 Hard, floor 106 World 4 Nightmare); every floor
pays, Roll Packs every 5th floor (Big every 25th); one loss, GIVE UP or leaving mid-fight (`Tower.Live`, ended by
SaveMigration on load) sends the run back to floor 1; the best run is the leaderboard and Guardian bonuses only pay past
it; from floor 50 every win has a 0.1% random relic drop (`Items.RelicFloor` / `RelicChance`).
Guaranteed first-clear checkpoints (`Tower.Checkpoints`) also pay once at floors 5 / 10 / 25 / 50 / 75 / 100:
five Roll Packs + Potion I; a Big Pack + Four-Leaf Relic + Skyward title; three Big Packs + Potion II + Orb;
a Mega Pack + Prism Shard relic; three Mega Packs + Potion III + 25 Fragments; a Colossal Pack + the existing
Spire Heart artifact + Endless Ascendant title. Claims persist in `Tower.Checkpoints` across lost runs.
SaveMigration initializes missing claim maps without resetting records; prior best runs collect all earned
new checkpoints on their next tower win. Server grants / receipts use MetaService once and checkpoints stop
auto-climb for a result screen. The tower preview and QUESTS > GOALS show the next exact guaranteed reward.
Hundred-Floor Pagoda: 100 kept floors (16.5k x 1.053^(floor-1), floor 100 is a full Secret deck's fight), each paid once,
milestones at 25 / 50 / 75 (packs, Trait Shards) and 100 (the Pagoda's artifact, the Crown of the Hundred Floors, and
the worn "Pagoda Master" title). Server raids every hour at :30 (a shared Colossus pool, Raid Luck x2 when cleared).
Roll Packs (10 / 100 / 1000 / 10000 rolls) open 1 / 5 / 10 / ALL at your luck, also during Auto Roll; Pack Alchemy
condenses them. Element infusion is retired; old infused packs retain their rolls and their infusion spend is refunded as Trait Shards. One OpenPack request consumes the selected packs and rolls count × pack size in one non-yielding
server pass however large: `BulkRoll.Multinomial` splits packs x rolls over the pool's card chances, then
each card's count over borders and foils (a fixed handful of binomial draws, so 100 Mega Packs = 100,000 pulls
or a billion cost the same). Luck and the active sky are sampled once; XP, quest counts and announcements once. `Shared/PackBatch` ranks by actual card rarity and returns five compact
highlights, one reveal candidate per card / border, grouped quantities, border counts and final ownership.
`PackOpen.Open` applies snapshots once. USE ALL exists on each owned pack tile and its details and opens the
whole pile in that one request (one retry if the open limiter answers TooFast), then shows one combined
summary: total cards, the five rarest groups first, every card / border stack.
Saved SETTINGS: full reveal minimum All / Gold+ / Rainbow+ / Secret+ / Off; pack animation Pack Flip or
the existing manual Cinematic; duplicates New Only or Include Copies. Defaults Rainbow+ / Pack / New Only.
Pack reveals are unique per card / border, use discovery flags from the server and skip directly to
the complete quantity summary when nothing qualifies. Repeated copies in later chunks preserve a real
discovery's one reveal. The cinematic reveal shows the card's DMG / HP (sword / heart StatLine pill under it, with
the duplicate bonus) and, while more reveals wait (queued, or the rest of a pack's batch), a SKIP ALL button that
ends the run and drops straight to the pack summary (`Reveal.SkipQueue`, `Reveal.Full(..., batch)`). Manual / AUTO obey the same threshold / duplicate choice; filtered pulls still
get their cards / feed. AUTO holds only for eligible reveals. Preferences migrate / validate on the server.
BAG blocks repeated clicks during requests / animation; reveals never reapply old per-roll ownership.

**Progression and retention.** Levels 1-100 with stat points; earned potions; gear in two sets
(`Items.luau`): **relics** (the 10 wearable items, `Items.Artifacts` / `Gear.Artifacts` in code, wear 3, Infinite Tower
drops and guaranteed checkpoints; each adds fixed Luck and Border Chance by tier, Rare +0.75x / +15% up to Void Eye +2.5x / +35%, the
best three +6.5x / +90%; Hourglass / Coin / Tome / Frost Sigil keep a specialty that duplicates level, others melt)
and **artifacts** (`Items.TowerArtifacts`, always on: the Pagoda's floor-100 Crown, +3x luck / +50% border chance /
+15% squad ATK as a whole-fight ATK buff on every Attack card; the Infinite Tower's Heart of the Endless Spire,
+2x luck / 15% faster rolls, for the first record run to floor `Items.InfiniteArtifactFloor` 100). TRAINING: Luck
+0.05x a point (2x at 40), Border Chance +1% a point (30% at 30). TRAINING has a typed AMOUNT, a per-row
allocation button and MAX. The server clamps the request to unspent points / the stat cap, rejects invalid
numbers and unknown IDs, and retains the existing action rate limit. The row previews the full requested
increase. Ten Mega Packs condense into one 10000-roll Colossal Pack at Hoshi; its tile reuses Mega artwork
with the correct name / roll count. Daily streak,
daily quests, playtime gifts, time-away rewards (`Meta.OfflineReward`: a Roll Pack per 30 min and a converted Trait Shard reward
offline, after 10 min, up to 8 h; `LastSeen` in the save), roll milestones, Lucky Wheel, server events (LUCKY STORM /
ROLL RUSH / DOUBLE XP), codes, Kenji's 6-step path and titles. Nudges (`Main.client`): a SQUAD badge + hint when BEST DECK would
beat the active deck by 5%, and a hint when a card can fuse at Hoshi. `Goals.Closest` shows up to three nearest distinct progress bars: fusion, battle mastery, normal collection,
roll milestone, tower checkpoint or next sky. Their bottom-left rows have separate vertical slots rather
than covering the primary goal. The first 50-roll milestone also grants the First Light title. Social: server list with favourite cards, profiles, name
tags, three town leaderboards.

QUESTS opens on **GOALS** (`UI/Journey`, `Goals.Journey`): four live targets show the next unlocked story
challenge / boss-card pool unlock, an equipped Attack card's next mastery rank, the next Pagoda milestone
and crown / title, and the next guaranteed Infinite Tower checkpoint. Buttons open the selected story difficulty, tower /
Pagoda or SQUAD. Progress comes from existing server snapshots; viewing goals grants nothing. Kenji's
tracker still opens his path; DAILY & GIFTS remains its own tab. Longer-session reward pacing still needs
ordinary-play review (docs/PROGRESSION_PLAN.md).

The general Shard shop and SQUAD upgrade purchase tab are retired; SQUAD TRAINING allocates earned stat
points. `EconomyVersion=1` converts old balances at 20:1 (rounded up) to Trait Shards, retains every purchased
permanent upgrade effect and compensates infused-pack spending. Authored legacy Shard reward bundles are
converted by `Meta.RetireShards` before grant / display. A normal trait reroll costs 1 Trait Shard; locking costs 2.
Luck Potion I / II / III add +1.5 / +3 / +6 luck for 5 / 10 / 15 minutes (2026-10-30). Only the strongest active luck potion
counts; same-kind uses add time up to an hour. Running old II / III timers are extended once on migration.

CLAIM ALL on DAILY & GIFTS pays every ready daily streak, playtime gift, roll milestone, daily quest and
Index reward using the same individual server eligibility / paid flags. Gifts are processed before
quests so gift-related quests can finish in the same call. INDEX has a collection-only CLAIM ALL.
KENJI'S PATH has CLAIM ALL READY, advancing only consecutive ready steps, bounded by the quest count.
Claims remain rate-limited / idempotent; no unready rewards or repeat payments. Receipts merge paid
bundles without reapplying reward multipliers.

**Store.** Passes (Fast Roll, Auto Roll+, Triple Roll, VIP) and Server Luck Totem. Shard bundle sales are hidden /
rejected; receipts for old purchases still compensate the buyer. Weather items are earned only in v1. Every perk that touches
odds or random rewards is gated by PolicyService (`ArePaidRandomItemsRestricted`). Ids are 0 (placeholders) until launch.
Triple Roll applies three normal pulls to both ROLL and AUTO, retaining the same PolicyService gate.
Every normal pull still gets its sky search. The HUD says ROLL x3; quick results show three cards together,
and qualifying full reveals run rarest first under the existing preferences / SKIP ALL. Sky bonuses are
identified separately from Triple Roll; every result still updates ownership and the feed.

BAG inventory tabs omit unowned items; a running potion can remain visible without an x0 count. SKY ITEMS
keeps text crafting buttons even with no Sigils owned. Trait Master balances / reroll costs use the current
Trait Shard image, with slot names above the cost. All 13 trait icon subjects and a shared art prompt are
in `docs/TRAIT_ICON_PROMPTS.md`; their existing icons remain until the user supplies the new artwork.
Holographic rarity rims follow the outside silhouette at zero inset, retaining the inner white bevel.
The hidden-battle return / result widget sits at top-center below the event strip, clear of the sky panel.

**Look.** Character artwork sits in glossy simulator-style vector controls. `UI/VectorStyle` supplies
8–14 px rounded surfaces, saturated vertical gradients, black 2.5 px outer edges and inset white
1.5 px bevels at 0.55 transparency. Headers / buttons have a white top-45% gloss at 0.88 transparency.
FredokaOne labels and LuckiestGuy titles use white text with black 2.5 px outlines; body copy stays Gotham.
`UIArt.Enabled = false` disables the old panel,
summon-button and icon atlases without deleting them; `Skin` keeps the existing code-native controls and frames.
`src/configs/UITheme.luau` feeds Theme with navy / lilac surfaces and element / border colours where meaningful.
The earlier image kit remains archived under `art/ui/occult/` for reference.

The HUD has a vertical menu with 20 px FredokaOne labels and distinct saturated gradients: crimson BATTLE,
royal-blue SQUAD, violet BAG, emerald QUESTS, cyan TRAVEL, gold STORE and orange DEV.
Sidebar notification badges are plain crimson 26 px circles with a 1.2 px text outline and no inner bevel.
It has an opaque currency group, a quiet Kenji tracker / claim seal,
XP and nearest-progress bars at bottom-left on desktop, and AUTO / ROLL / QUICK at bottom-centre with Momentum and Surge in one
band. The server list starts folded (tap to expand). RECENT PULLS shows up to three rows, two on short screens.
Surge still charges spirit blue, shivers void purple for the last four rolls, and seals gold (UNLEASH SURGE!).
AUTO / QUICK light their bezel when active. Short screens keep the earlier scaling / compact layout, with Next Goal
over the roll console. Quick-roll cards use a bounded two-card 2D tray on the right, clear of the avatar's torso
and bottom controls. `UI/RollCard` gives quick / full / reward reveals an art-first face: FredokaOne name
top-left, element top-right, plain rarity at the bottom over a short vignette. No type line, rarity pill,
DUPE / COPY badge or border ribbon covers the art. Only a new card or newly discovered Index border
(server Outcome / NewBorder flags) gets a gold NEW! badge above it. Rewards reserve label gutters;
first-clear bonuses retain their own footer ribbon. Collection / inspector layouts stay separate.
Automatic roll reveals stay muted while panels or fights are open; away rewards use one compact toast.

Panels (`Modal`) use navy gradients, glossy purple headers and rounded selected tabs. An invisible button
behind their contents catches empty-space clicks; outside clicks and the close button still dismiss them.
`UI/RewardLine` replaces emoji reward tokens with the current HUD / BAG illustrations in daily quests,
milestones, gift extras, Kenji reward rows and HUD reward notifications. It fits the complete inline row
to its available logical size, including scaled panels. Speed rewards reuse the hourglass illustration
until dedicated speed-potion art exists. Reward descriptions / server payouts are unchanged.
On phones, `Modal.FitScale` lays out the panel at desktop size and scales it down (~0.6 sideways); turn
measured sizes back into offsets with `Kit.logicalSize`. The HUD, server list and quick pops hide behind panels.
Search / dropdowns and formation trays are quiet sunken wells. SQUAD has separate ATTACK / SUPPORT tabs above CARD VAULT, without an All-type tab. Clicking a formation slot
selects its matching vault tab. Background rolling updates cached tiles in place; sorting / inserting tiles waits
while a tooltip is open. Selection, filters, scrolling and inspected abilities survive routine rolls; panels mute
automatic reveals. The deck screen retains spirit-blue Slot Links
(gold for bonds), its Cost Challenge meter and familiar bond tags, with a vermilion BEST DECK. Border-filter chips
draw labels above their background gradient so they remain visible.

`UITheme.BorderTiers` still identifies border tiers. Gold, Rainbow and Secret receive white 2.5 px strokes
with rotating multi-stop gradients. One shared RenderStepped loop rotates visible borders, skips hidden /
clipped cards, culls world-space SurfaceGui / BillboardGui gradients by distance / camera view, and
disconnects when its last gradient is destroyed. Decorations live in a Folder to keep
them out of grid / list layouts. TextButton labels are mirrored above their fill so gradients cannot tint
or cover white text; existing text changes / selection strokes continue to work.
Tiles show art, a plain ATTACK / SUPPORT label, element, name, xN, FUSE! at 100 copies and the
rarity number, with no combat stats. A black transparent-to-dark vignette covers the bottom 38%; centered
names end at 82% height and gold / cyan rarity numbers end at 96%, in separate rows. Names scale 6–14
to fit the smallest profile deck tiles; stats live in the inspector / tooltip. Vault tiles are
larger; the phone inspector collapses until selection; deck thumbnails omit duplicate tiny name / rarity labels.
DECK explains the two card types and numbered pairs. Attack slots show damage / HP; Support slots show their actual
passive strength instead of generic power. The 26 normal characters and 16 event characters belong to ATTACK; the 11 relics belong to SUPPORT. Only attackers contribute to ATTACK RATING. Tapping a
vault card only selects it; EQUIP / REMOVE is explicit. The inspector prioritizes the authored passive effect or Attack Basic and action / Skill timing
and fusion copy counts. VIEW SKILLS / MASTERY opens the scrollable Index detail sheet at the selected border, with a visible
BACK TO CARDS button. `Shared/CardInfo` resolves authored ability templates from the same server data (`{pN}`, `{aN}`, `{tN}` read effect
N; Support tokens read the rounded percentage, chance, threshold and cost). Copy uses supported card / DMG / named
techniques and statuses, with no system-job boilerplate or stagger diagnostics. Only percentages, turn counts and
Burn / Bleed / Freeze / Stun / Weaken are highlighted. `CardInfo.Badges` supplies Activation Limit / Effect Cap pills;
`UI/Abilities` draws a check from Frames and reuses the same rendering in tooltips, Index, reveals and battle popups.
Hover cards are dark, scrollable and bounded to the viewport; pointer movement into them keeps them open. The skill
sheet shows techniques first; COLLECTION & MASTERY expands odds, fusion, traits, battle mastery and other collection data. Advanced traits / mastery
remain in the details. Battle skill popups scroll within the viewport. HUD refresh waits for initialization so an
early StoreState update cannot access missing currency chips.
The three opaque HUD currency chips and seven colored menu buttons use individual transparent illustrations
through `UI/HudArt`; sources, exact built-in ImageGen prompts, hashes, ids and 384 px uploads are in
`art/ui/hud-20261027/`. Battle results reuse this currency art and BAG pack art, with a larger pack picture,
short save / luck hint and a separate three-line new-card announcement. Reward actions and payouts are unchanged.
`Elements.Visuals` centrally maps Flame / Frost / Storm / Void / Cosmic / Light to six transparent illustrated
assets and primary / accent colors. `ElementUi.Badge` renders the icon itself in card / formation / inspector /
battle / reveal badges, without the old two-letter diamond tag. Element ids and visual colors remain; combat matchups / synergies are disabled. Exact built-in ImageGen prompts, originals, hashes, ids and 384 px upload copies are in
`art/ui/elements-20261027/`.
BAG uses 17 individual transparent AI illustrations for the requested packs, potions, relics and Pagoda crown
in both tiles and details, with separate names / counts / status lines. `UI/BagArt` maps item keys to uploaded
images; infused Mega Packs reuse Mega art. Sources, exact built-in imagegen prompts, hashes, uploaded ids
and 512 px RGBA upload copies are in `art/ui/bag-20261027/`. Unmapped items retain the existing marker fallback.
Relic-rarity frames remain (bronze / purple / gold / crimson); packs keep their roll counts. BOSS SCOUT retains its unit trays and
shows actual equipped Attack / optional Support counts and familiar-column bond bonuses. Obsolete elemental
strong / weak / synergy advice is removed. EDIT DECK / FIGHT sit in a fixed footer on story / tower / Pagoda /
raid screens, visible while their details scroll. The tactics guide describes current archetype timers /
energy / HOLD ULT behavior. Battle intros use smaller straight lacquer / vermilion panels, with matching
controls, enemy target panels and result frames. The current triggered ability kits are described above.

`JuicyButton` still supplies sheen, spring and sounds; `IconBadge` carries element / role crests.
All 26 character Attack portraits use a cohesive AI illustration set in `art/cards/cohesive-20261026/`, generated with the
built-in image tool from the three approved previews. Each source PNG is 1254 x 1254; the existing card frames
crop it to their shape. `manifest.json` records card ids, inspirations, dimensions, hashes, Roblox image ids and
the five previous image ids. `generation-plan.json` stores the production prompts. The older five portrait PNGs
in `art/cards/` remain untouched. `Cards.ART` connects the uploaded images; the procedural bust remains a fallback.
The character artwork pass did not change identities. The later character-to-Attack conversion keeps those same portraits and adds 11 separately named Supports; see `docs/CARD_CONVERSION.md`. All 11 Support relics now have their own approved AI artwork under `art/cards/support-20261027/`: square 1254 x 1254 sources, uploaded ids / hashes in the manifest and production / preview / cleanup prompts alongside them. The three approved examples are kept exactly; eight matching relic / technique images complete the series. Existing card frames supply portrait crops, labels and borders. All 11 actual tiles, tall cards and the normal SQUAD Support tab visibly rendered in Studio. A plain monogram remains the fallback for future Supports without art.

## Layout (Rojo project, `default.project.json`)

- `src/configs` -> ReplicatedStorage.Configs: `UITheme` (design tokens, client UI only).
- `src/shared` -> ReplicatedStorage.Shared (both sides; pure data + formulas, tested headless): `Config` (tuning,
  `TestMode`, dev access lists, deck and battle rules), `Cards` (card data + `Pool`, `PullChances`, `Stat`, `Power`,
  `Cost`), `Borders` (the tiers: odds, multipliers, cost, colours), `Odds`, `Rarity` (relic / trait tiers only),
  `CardInfo` (readable effect facts), `Elements`, `Foils`, `Awaken`, `RollBoost` (Momentum + Surge), `Deck`, `Bosses`, `Rewards`, `Tower`, `Raid`, `Packs`, `PackBatch` (bulk receipt / sort / limits), `Goals`,
  `Collections`, `ColumnBonds`, `Weather`, `CelestialCards`, `CelestialArt`, `Items` (relics + artifacts), `Traits`, `Meta` (potions, upgrades, Index rewards, daily, gifts, milestones, quests, levels,
  stats, events, wheel, luck / cooldown formulas), `Tutorial`, `Mounts`, `BossModels`, `MonetizationConfig`.
- `src/server` -> ServerScriptService.Server: `Main.server`, `DataService` (ProfileStore saves), `SaveMigration` (old
  saves brought up to date on load; pure, tested), `DevAccess` (who may use test tools), `RollService` (rolls, Auto Roll,
  packs, alchemy, rewards, dev tools), `BattleService` + `BattleEngine`, `DeckService`, `FusionService`, `TraitService`,
  `MetaService` (progression actions, luck / cooldown), `RaidService`, `Momentum`, `MonetizationService`, `AvatarService`,
  `NameTagService`, `LeaderboardService`, `ProfileService`, `TravelService`, `MountService`, `TutorialService`,
  `CollectionService`, `WeatherService`, `CodeService` + `Codes`, `GlobalAnnounce` (Secret pulls to every server), `NpcRange`, `World` (markers / arena spots),
  `WorldSigns` (NPC plates / gate plaques), `TownModels` (four service figures), `TownServices` (stations / pagoda), `RateLimit`, `ProfileStore` (vendored).
- `src/client` -> StarterPlayerScripts.Client: `Main.client`, `State`, `MetaClient`, `LightingSetup`, `ZoneFx`, `HubFx`,
  `Followers`, `Avatars`, `Dash`, `SkyFx`, and `UI/*` (Kit helpers incl. `Kit.glyph` / `Kit.statsText` / `Kit.short`, Theme,
  Components/JuicyButton + IconBadge, Modal (+ `Modal.Tabbed`), Controls, Hud, Reveal, CardView, CardTile, CardTooltip,
  ElementUi, DeckBuilder, Index, OddsPanel, Bag, PackOpen, Fusion, Alchemy, TraitMaster, BossScreen, Battle, Arena,
  RewardReveal, Store, Gifts, Tutorial, Stats, Shop, Wheel, Pets, Travel, Settings, PlayerList, Profile, Title, DevPanel,
  Waypoint, Effects, Sfx, Skin, UIArt (uploaded illustrated kit), BorderFx, ModelView).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- `assets/models/bosses-20261027/BossKit.rbxm` -> ReplicatedStorage.BossKit (four boss templates and service fallbacks).
- Not in Rojo (place file only): `workspace.Map` (Town, EmberVillage, FrostfangPeaks, NeonAbyss, StormspireIsle, Markers),
  Terrain, Lighting, `ServerStorage.MapKit`, `ReplicatedStorage.MountKit`.
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- Card copy follows the user's Anime Card Clash style brief: authored technique names and mechanical prose,
  "the supported card", no system-job boilerplate / auto-action / stagger diagnostics. Every passive / Aura /
  Signature and Support combines a trigger with a status / RNG mechanic, an activation limit or a condition, and
  carries **no self-penalty** (the user's call, 2026-10-30). No elemental damage systems. Percentages are multiples
  of 5 in the actual data / server formula, including border scaling; never round only the tooltip.
  Exact roll odds remain exact. Highlight only key percentages, turn counts and named status effects; activation
  limits / effect caps belong in `CardInfo.Badges` pills, backed by server counters. Use lore-themed ability
  terminology; keep the existing card / boss identities and art unless the user explicitly changes them.

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on
  the server, rate-limit it (`RateLimit`), and check ownership / NPC range where it applies.
- Borders multiply by Base 1x / Gold 4x / Rainbow 16x / Secret 64x; base ATK is authored per card and grows with
  rarity (the 2026-10-30 tiers above, HP = 2 x ATK; among normal cards (and among boss cards) a rarer card never has less ATK, odds_test checks), so a rare
  Gold may outdo a common Rainbow. Duplicates add +0.5% ATK / HP each up to +25% (the user's call, 2026-10-30);
  mastery never multiplies ATK / HP. The same card on one border never reaches itself on the next through mastery
  (odds_test checks). Traits stay small (never ATK / HP). Rolls are pure luck: no pity (luck only tilts odds).
  Fusion is border fusion only: 100 copies at one border -> 1 at the next, for every card.
- Content is data: a new card is one entry in `Cards.luau` (stats, abilities, `Role`, `Weight`, `Element`, `Image`); a
  boss or difficulty one entry in `Bosses.luau`; a relic or artifact in `Items.luau`; a trait in `Traits.luau`; a potion / gift /
  milestone / quest in `Meta.luau`. Support entries use generic `Support.Kind` handlers; Attack passives / Auras / Signatures use generic trigger bundles.
- Save format changes need a step in `SaveMigration` (safe to run twice) and a case in `tests/save_test.luau`.
- Potions, sky items and gifts are earned in game only; the retired Shard shop / bundle sales stay closed.
  Robux sales live only in MonetizationConfig / MonetizationService; any perk that changes odds or gives random rewards
  is gated by PolicyService, with all outcomes and live odds summing to 100% shown.
- Boss HP / ATK per difficulty are tuned so each fixture deck in `tests/fixtures.luau` wins its fight in 60-90 s
  (`tests/battle_test.luau`; the user's newer HP table uses each fixture's Window where authored, including
  World 1 Normal50-90 s / World 3 Nightmare60-100 s / World 4 Nightmare110-140 s); `tests/tower_test.luau` does the same for the tower and the Pagoda (Rainbow /
Secret chase decks). Re-run after changing
  cards, bosses or battle rules, and retune if they fail.
- Original characters only: no real anime characters, names or trademarked terms.
  Prototype exception (the user's call, 2026-10-25, confirmed 2026-10-26): card and boss names are anime-style
  epithets that nod to well-known series (card ids unchanged). Keep them: don't rename them unless the user asks in
  their own words. The user authorized named anime Celestial forms on 2026-10-29, then explicitly requested
  epithet display / technique names for those sixteen on 2026-10-30. Preserve the current names / original ids;
  recognizable portraits and series labels still require the public-release review tracked in the launch checklist.
- Cheap on phones: UI-first, plain Frames + tweens, no textures or 3D particles in reveals, at most one 3D model per
  ViewportFrame; few CanvasGroups; StreamingEnabled, map under ~15k parts, few lights.
- Town services stay at their NPCs (Hoshi, Kenshin, Fortuna): no HUD shortcut, and the server checks `NpcRange.Near`.
- Creator Store models: strip every script (tools/studio/stage.luau); `tools/studio/scan.luau` finds backdoors (a fake
  "Error 501, paste this into the command bar" screen is one: never run it). Sounds: licensed libraries only (Pro Sound Effects,
  APM Music) or Roblox's own; all ids in `UI/Sfx.luau`.
- `✕` and `▾` don't render in game (empty boxes): draw them with `Kit.glyph`. Check new symbols in Studio.
- Test tools: `Config.TestMode = true` during testing, and only `DevAccess` players (Studio, the game owner / group
  admins, `Config.DevUserIds`) can use the DEV panel or mock purchases. `TestMode = false` at launch (see the checklist).

## Commands

The server list opens / closes with Tab or its fold button; Tab passes through while typing and while
the list is hidden. The desktop sky panel moves below the expanded list; compact screens hide that panel
until the list folds. The HUD shows Trait Shards and rolls; retired diamond Shards are absent, while
Celestial Fragments remain in BAG. Neutral dark slate windows keep glossy edges; section titles / active
tabs follow their meaning. Attack / DMG is crimson, Support / HP / luck green, navigation blue, training /
rewards gold. Shared typography preserves authored colors, including small high-contrast pills.
`StatLine` uses uploaded red sword / green heart images on full cards, formation stats, inspectors and
hover sheets; prompts / alpha sources / upload hashes live in `art/ui/stats-20261029/manifest.json`.
Card faces show name, rarity, one headline, trait / foil and combat stats; repeated type / subtitle /
passive tags are removed. The compact inspector shows stats, one technique, rarity / copies and actions;
the skill sheet's collapsed collection section has concise copy / foil / trait / next mastery / bond facts.
Element badges / filters / matchup guides are hidden; internal themes still color art effects. TRAINING
uses the existing illustrated clover, hourglass, prism, Trait Shard and tome assets.

DEV has a searchable card picker with exact border / copies, custom luck / earned-luck reset, Trait
Shard / Fragment and pack grants, local sky / duration previews, level edits, sky supplies and boss
reward-timer reset. Existing tools remain below. Every request retains DevAccess / TestMode gating and
a 3-per-second, burst-8 limiter; new targets / amounts reject unknown ids, NaN, infinity and invalid
ranges (`DevCommands`). Level edits grant no XP / level-up rewards. Sky previews affect this server only;
card / supply grants edit the developer's existing test save. No new save fields are introduced.

- Workflow: open the published place in Studio, `rojo serve`, press Connect in the Rojo plugin (reconnect after new
  folders or remotes). Rojo only touches the folders in `default.project.json`, never the map. Save / publish from Studio.
- Never `rojo build` over the place you open in Studio: a built place has no map. `rojo build default.project.json -o
  AnimeCardRoll-Test.rbxlx` is only for a throwaway script test.
- Rojo and the `luau` CLI come from rokit (`rokit.toml`). luau-lsp isn't in rokit: in a cloud session download the release
  binary (1.70.1 worked) and rojo 7.7.1 into the scratchpad. Keep the type check at 0 errors.
- Type check: `rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json` then
  `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions @roblox=tests/defs/globalTypes.d.luau --ignore "**/ProfileStore.luau" src/`
- UI property names (props set through `Kit.new` aren't type checked): `python tests/check_props.py tests/defs/globalTypes.d.luau src`
- Headless tests (odds, cards, progression, decks, battles, tower, strategy, phase 2, tutorial, save migration):
  `python tests/bundle.py` then `luau tests/bundle_out.luau`
