# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses, climb an endless
tower and join server raids. Original design doc (it predates the border tiers, so its rarity sections are out of date):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

This file describes the game as it is now (2026-10-27). How it got here is in `git log` (one commit per pass).
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

**World.** A big Studio-built map (terrain, Creator Store models, AI meshes, StreamingEnabled): spawn town in the middle,
Ember Village (W), Frostfang Peaks (N), Neon Abyss (E), Stormspire Isle (S, over a second bridge), each with a portal and
its boss. Town NPCs: Kenji (guide), Hoshi (fusion + pack alchemy), Kenshin (traits), Madame Fortuna (Lucky Wheel), the
tower gate and leaderboards. The spawn plaza has a thin stone fountain border, short service approaches and two
wooden benches with flower planters. Stalls / services sit around the edge; an explicit Tower marker puts the
jade-and-slate spire northwest of the fountain. `tools/studio/town-polish.luau` applies these place-only edits once
and keeps a reversible backup in ServerStorage. The local saved place is under `studio-local/` (ignored by Git).
Town services only work beside their NPC (server `NpcRange`, 24 studs); every world sign and NPC plate shows
within 140 studs for destinations and 90 for NPC plates; larger plates stay opaque through 80% of their range.
They fade at the edge (HubFx), never draw over the world, and hide with player name tags while a panel,
fight or reveal is up (`Modal.Changed`, `HubFx.SetWorldLabelsHidden`). TRAVEL fast-travels (server-owned). Mounts (5, G to ride), a shoulder pet, dash (Q, two charges) and a
double jump. Lighting: a bright town afternoon (`LightingSetup`); each world has its own theme (`ZoneFx` moods: Ember golden sunset, Frostfang snowy morning, Neon Abyss violet night, Stormspire grey storm with lightning) and zone music.

**Rolling.** The server owns every roll. Each pull picks a card by its `Weight` from the pool (`Cards.Pool`; a boss's
own card joins after that boss's first Normal clear) and rolls its **border**, which is the tier: Base ("Normal" in
saves) 1x / Gold 4x / Rainbow 16x / Secret 64x stats, base odds 1 in 200 / 5,000 / 500,000 (rare on purpose: story
bosses are beaten with Base + Gold, Rainbow and Secret are the tower chase). Luck raises each special border by luck ^
0.6 / 0.8 / 1 (Border Chance and surges multiply them; the specials are capped at 50% together). Total luck = base
(upgrades, stat points, level, Index rewards, Momentum, artifacts) x potion x event / Raid Luck / Totem / VIP, capped at
25x (`Meta.TotalLuck`). Pure luck: no pity. Every card shows its **rarity number** per border (`Cards.Rarity`: 1 / (pull
chance x border chance) at 1x luck, snapped to a round number by `Odds.Round` like "7,500,000", never "1 in"; it is the
big number on card tiles; `Odds.FormatRarity` for the ODDS panel). Every pull also rolls a foil (Aura / Golden Ki /
Demon Seal, battle-only). ROLL (R), QUICK toggle (T: ROLL plays the short reveal, saved), AUTO (E; never stops by
itself: a Rainbow+ pull or Demon Seal holds the next roll `Config.AutoBigRevealHold` s for its full reveal, then it
rolls on). Momentum chain: +1% speed / +0.01x luck per 10 rolls, max 500, breaks after 30 s idle. Overcharge Surge every
25th roll (`TotalRolls % 25`): 5x border odds, or 3 cards at 6x on a perfect tap; HUD meter binds to `SurgeProgress`.
Rainbow+ pulls are announced; a Secret gets "[SERVER] {Player} rolled a SECRET BORDER {Card}!" here and "[GLOBAL] ..."
in every other live server (`GlobalAnnounce`, MessagingService). Weekly **Featured Card** (`Cards.FeaturedAt`): one rare
non-boss card weighs x3 for a week (Monday 00:00 UTC), the same on every server; the event pill, ODDS and Index show it.

**Cards.** 26 character Attack cards (including 4 boss cards) + 11 relic / technique Support cards (anime-style epithet names for the private prototype, see Rules). Attack cards sit on one stat line (ATK ~500 +-10%, HP = 2
x ATK), scaled by rarity (`Cards.Scale`: a Weight 10 card 1x, Weight 1 about 1.41x, boss cards
up to 1.53x), so the border decides power and rarer cards edge out common ones at the same border. Each has an
`Element`, a `Role` (Striker / Hexer / Mender / Warder) and abilities built from the effect library at the top of
`Cards.luau`; All 11 former character Supports now have a damaging Basic / Skill / Ultimate and a triggered Passive, keeping their ids, names and character art. The other Attack kits retain their previous abilities. Support relics have one passive definition
and its subtitle (`Title`) and colour (`Accent`) fit its name and element. Duplicate pulls grant **no combat
bonus**: Stars remain a legacy save field, always zero on normal rolls, and copy-based Awakening is retired.
Copies pile up per border (`BorderCopies`); each owned border has its own tile, and the deck fights at the chosen
border (`Deck.PlayBorder`, save `Play`). **Border fusion** at Hoshi still costs 100 copies of one border for one
copy at the next border, with no extra reward.

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

**Deck and battle.** 4 Attack + 4 Support, 3 presets (+2 VIP), AUTO-BUILD / COUNTER-BUILD. Each Support modifies the
Attack card with the matching slot number. Supports have no damage, HP, action bar, Skill or Ultimate; counters,
reflected statuses and Black Flames belong to the supported Attack card. Original character ownership, ids, names and portraits remain. On first load, `SupportRelicsVersion = 1` grants each owned former Support's replacement relic an independent copy of its saved collection (copies / borders / traits / foil / Mastery / selected border), without overwriting an already-owned relic. All preset Support positions and the older single deck map to the replacement; Attack lineups stay as chosen. Compensation runs once, before deck cleanup; further rolls award only the card rolled.
`Cards.Support` owns the trigger, effect, cost, chance, limits and authored text. `Cards.SupportValue` applies border
strength (Base 1 / Gold 1.25 / Rainbow 1.5 / Secret 1.75x), then rounds the **actual server
value** to the nearest 5 percentage points (positive minimum 5%, maximum 50%). Fixed effects use their authored value;
Eight Trigrams Seal's Crimson Chakra Cloak always returns at 85% HP. Trigger counts, chances, penalties, secondary Burns and healing caps
are fixed. Passive cards add no Attack rating; AUTO-BUILD ranks them separately by border / rarity. Support traits, foils and mastery affect the supported Attack
card; they no longer sit unused on a passive unit.

Support kits (base strengths; inspect the card for its rounded value at another border):

| Card | Passive |
| --- | --- |
| Diamond Mitotic Seal | Below 50% HP, cleanse Burn / Freeze and heal 20% max HP; healing blocked for 2 turns; 1 activation. |
| Binding Blood Vow | After an enemy hit, 25% chance to return 15% of DMG taken as an Attack-card counter; 4 activations. |
| First Form: Thunderclap | On entry, +20% attack speed but -10% DMG for 3 turns; 1 activation. |
| Heavenly Restriction | 10% evade chance; successful evades Weaken the attacker by 10% for 1 turn; 4 activations. |
| Cursed Ocular Seal | Skills / Ultimates roll once per cast: 25% chance to Weaken by 15% for 2 turns and Burn for 10% DMG each turn for 3 turns; 4 activations. |
| Gourd of Living Sand | On entry, 25% max HP shield; -10% attack speed for 2 turns; 1 activation. |
| Wisteria Antidote Vial | On defeating an opponent, heal 20% max HP but deal 10% less DMG for 2 turns; 3 activations. |
| Blink Kunai Seal | On entry, 25% Ultimate charge in exchange for -10% attack speed for 2 turns; 1 activation, requires an Ultimate. |
| Eight Trigrams Seal | Upon a fatal blow, return at 85% HP; permanently -25% DMG and no further healing; 1 activation. |
| Chakra Puppet Threads | Cleanse and reflect Burn / Freeze; reflected Burn is 15% DMG for 3 turns; 2 applications. |
| Stormheart Mantle | Direct hits have a 25% chance to drain 10% of actual DMG as HP; capped at 25% max HP per fight; overkill excluded. |

Attack passives, Auras and Signatures are generic triggered bundles (`Ability.Trigger`, `Chance`, `Limit`, optional
`Every`). `BattleEngine:Trigger` handles OnEntry / OnHit / OnCrit / OnKill / OnAct / BelowHalf, tracks activations and
prevents reentry into the same bundle. On-hit effects roll for every actual hit; Crows explicitly share one roll per
Skill / Ultimate cast. Every passive combines a trigger with a cost or status / RNG mechanic. On-entry Auras also
carry their authored costs. `Bleed` and `Burn` share the timed-damage scheduler but have separate status flags / text.
Healing locks apply to every HP-healing route (`HealingLock` effect, timed Support costs or permanent cloak cost),
with a HEAL BLOCK badge (snapshot N). Reflected Freeze costs the enemy its next action (snapshot Z); Bleed is L.
Posthumous damage cannot consume a healing activation or heal a defeated card.
Elements: Flame > Frost > Storm > Flame, Light <> Void, Cosmic beats all (x1.3 /
x0.85); 2 / 4 of an element switch on a synergy; 8 named bonds fire a Dual Ultimate once. Every fight is the leader +
3 guards (Striker / Hexer / Mender / Warder); tap an enemy to focus it; win when the leader falls. Stagger bar (counter
elements fill it faster) -> 5 s Staggered. Rhythm and threat (`Config.Battle`): bars start part-filled (StartGauge) and one unit acts
per tick, one auto-Ultimate per tick; every enemy hit takes at least MinHit of the card's max HP (guard 1%, leader 2%,
leader's warned move 6% and SkillPierce 40% through shields), so even an overpowered deck takes hits. Attack cards show their next action / Skill in seconds (server snapshot `NextIn`, `K`); blue bars are action progress,
gold bars are Ultimate charge. Support chips show passive status / remaining uses, with no action or energy bar. Results show passive triggers / dodges
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
and Storm Court. Guard ids / roles / effects remain compatible with mixed tower squads. Existing BossKit assets
are retained: their older 3D appearances do not all match the new card art / names (Ember is still Itachi-like;
the other three use fantasy models). Retinues follow those current world / model themes; replacing the leaders
needs a separate art pass. No card or boss names changed.

**Content.** 4 worlds x Normal / Hard / Nightmare (D 1-12; recommended Attack rating 25.4k ... 127.7k; fixtures use Base in
World 1 and Gold later, zero stars and the mastery available from preceding distinct story challenges). Boss wins pay reward rolls (luck / floors by D), Shards,
Roll Packs and Trait Shards (no gear); after a win AUTO-RETRY (opt-in, in the battle controls above SPEED and on
the results screen) restarts the same fight; in the towers the same switch is AUTO CLIMB. With it on, a win shows a 1 s banner (no
results panel unless it's a milestone, relic / artifact or boss-card unlock) and the next fight starts with a 0.3 s
FIGHT! (BattleStart `{ Quick = true }`, `Config.Battle.QuickIntroSeconds`); in a tower it also sweeps: floors the deck
overpowers by `Config.Battle.SweepPower` (3x) are won and paid at once, up to `SweepFloors` (5) per start (BattleService,
same recordResult + towerRewards as a fought win; never the Pagoda's floor 100). Results show a pack progress bar and
the streak's totals when no pack dropped. SCOUT is four unit cards (leader + guards: crests, role, big move, affix). Two towers (BATTLE > TOWER / PAGODA), each floor an echo of a world boss with
affixes, Guardians every 10th, the daily mutator. Infinite Tower: a run (recommended 16.5k x 1.068^(floor-1)); every floor
pays, Roll Packs every 5th floor (Big every 25th); one loss, GIVE UP or leaving mid-fight (`Tower.Live`, ended by
SaveMigration on load) sends the run back to floor 1; the best run is the leaderboard and Guardian bonuses only pay past
it; from floor 50 every win has a 0.1% relic drop (`Items.RelicFloor` / `RelicChance`), the only relic source.
Hundred-Floor Pagoda: 100 kept floors (16.5k x 1.053^(floor-1), floor 100 is a full Secret deck's fight), each paid once,
milestones at 25 / 50 / 75 (packs, Trait Shards) and 100 (the Pagoda's artifact, the Crown of the Hundred Floors, and
the worn "Pagoda Master" title). Server raids every hour at :30 (a shared Colossus pool, Raid Luck x2 when cleared).
Roll Packs (10 / 100 / 1000 rolls) open 1 / 5 / 10 / ALL at your luck, also during Auto Roll; Pack Alchemy condenses or
infuses them.

**Progression and retention.** Levels 1-100 with stat points; Shard Shop upgrades; potions; gear in two sets
(`Items.luau`): **relics** (the 10 wearable items, `Items.Artifacts` / `Gear.Artifacts` in code, wear 3, Infinite Tower
drops only) and **artifacts** (`Items.TowerArtifacts`, one per finite tower's last floor, always on); daily streak,
daily quests, playtime gifts, time-away rewards (`Meta.OfflineReward`: a Roll Pack per 30 min and 2 Shards a minute
offline, after 10 min, up to 8 h; `LastSeen` in the save), roll milestones, Lucky Wheel, server events (LUCKY STORM /
ROLL RUSH / DOUBLE XP), codes, Kenji's 6-step path and titles. Nudges (`Main.client`): a SQUAD badge + hint when AUTO-BUILD would
beat the active deck by 5%, and a hint when a card can fuse at Hoshi. The HUD's Next Goal pill (above Momentum,
`Goals.Next`) shows the reward closest to landing (a fusion, a battle mastery rank, a roll milestone, a Shard upgrade). Social: server list with favourite cards, profiles, name
tags, three town leaderboards.

**Store.** Passes (Fast Roll, Auto Roll+, Triple Roll, VIP), Server Luck Totem, Shard bundles. Every perk that touches
odds or random rewards is gated by PolicyService (`ArePaidRandomItemsRestricted`). Ids are 0 (placeholders) until launch.

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
It has an opaque currency group, a quiet Kenji tracker / claim seal,
XP and Next Goal at bottom-left on desktop, and AUTO / ROLL / QUICK at bottom-centre with Momentum and Surge in one
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

Panels (`Modal`) use navy gradients, glossy purple headers and rounded selected tabs.
On phones, `Modal.FitScale` lays out the panel at desktop size and scales it down (~0.6 sideways); turn
measured sizes back into offsets with `Kit.logicalSize`. The HUD, server list and quick pops hide behind panels.
Search / dropdowns and formation trays are quiet sunken wells. SQUAD has separate ATTACK / SUPPORT tabs above CARD VAULT, without an All-type tab. Clicking a formation slot
selects its matching vault tab. Background rolling updates cached tiles in place; sorting / inserting tiles waits
while a tooltip is open. Selection, filters, scrolling and inspected abilities survive routine rolls; panels mute
automatic reveals. The deck screen retains spirit-blue Slot Links
(gold for bonds), its Cost Challenge meter and synergy / bond tags, with a vermilion AUTO-BUILD. Border-filter chips
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
passive strength instead of generic power. The 26 characters belong to ATTACK; the 11 relics belong to SUPPORT. Only attackers contribute to ATTACK RATING. Tapping a
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
BAG uses 17 individual transparent AI illustrations for the requested packs, potions, relics and Pagoda crown
in both tiles and details, with separate names / counts / status lines. `UI/BagArt` maps item keys to uploaded
images; infused Mega Packs reuse Mega art. Sources, exact built-in imagegen prompts, hashes, uploaded ids
and 512 px RGBA upload copies are in `art/ui/bag-20261027/`. Unmapped items retain the existing marker fallback.
Relic-rarity frames remain (bronze / purple / gold / crimson); packs keep their roll counts. BOSS SCOUT retains its unit trays and
counter / synergy / bond information. Battle intros use smaller straight lacquer / vermilion panels, with matching
controls, enemy target panels and result frames. The current triggered ability kits are described above.

`JuicyButton` still supplies sheen, spring and sounds; `IconBadge` carries element / role / currency crests.
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
  `CardInfo` (readable effect facts), `Elements`, `Foils`, `Awaken`, `RollBoost` (Momentum + Surge), `Deck`, `Bosses`, `Rewards`, `Tower`, `Raid`, `Packs`, `Goals`,
  `Items` (relics + artifacts), `Traits`, `Meta` (potions, upgrades, Index rewards, daily, gifts, milestones, quests, levels,
  stats, events, wheel, luck / cooldown formulas), `Tutorial`, `Mounts`, `BossModels`, `MonetizationConfig`.
- `src/server` -> ServerScriptService.Server: `Main.server`, `DataService` (ProfileStore saves), `SaveMigration` (old
  saves brought up to date on load; pure, tested), `DevAccess` (who may use test tools), `RollService` (rolls, Auto Roll,
  packs, alchemy, rewards, dev tools), `BattleService` + `BattleEngine`, `DeckService`, `FusionService`, `TraitService`,
  `MetaService` (progression actions, luck / cooldown), `RaidService`, `Momentum`, `MonetizationService`, `AvatarService`,
  `NameTagService`, `LeaderboardService`, `ProfileService`, `TravelService`, `MountService`, `TutorialService`,
  `CodeService` + `Codes`, `GlobalAnnounce` (Secret pulls to every server), `NpcRange`, `World` (NPCs, signs, markers, arena spots), `RateLimit`, `ProfileStore` (vendored).
- `src/client` -> StarterPlayerScripts.Client: `Main.client`, `State`, `MetaClient`, `LightingSetup`, `ZoneFx`, `HubFx`,
  `Followers`, `Avatars`, `Dash`, and `UI/*` (Kit helpers incl. `Kit.glyph` / `Kit.statsText` / `Kit.short`, Theme,
  Components/JuicyButton + IconBadge, Modal (+ `Modal.Tabbed`), Controls, Hud, Reveal, CardView, CardTile, CardTooltip,
  ElementUi, DeckBuilder, Index, OddsPanel, Bag, PackOpen, Fusion, Alchemy, TraitMaster, BossScreen, Battle, Arena,
  RewardReveal, Store, Gifts, Tutorial, Stats, Shop, Wheel, Pets, Travel, Settings, PlayerList, Profile, Title, DevPanel,
  Waypoint, Effects, Sfx, Skin, UIArt (uploaded illustrated kit), BorderFx, ModelView).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- Not in Rojo (place file only): `workspace.Map` (Town, EmberVillage, FrostfangPeaks, NeonAbyss, StormspireIsle, Markers),
  Terrain, Lighting, `ServerStorage.MapKit`, `ReplicatedStorage.MountKit`, `ReplicatedStorage.BossKit`.
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- Card copy follows the user's Anime Card Clash style brief: authored technique names and mechanical prose,
  "the supported card", no system-job boilerplate / auto-action / stagger diagnostics. Every passive / Aura /
  Signature and Support combines a trigger with a trade-off or status / RNG mechanic. Percentages are multiples
  of 5 in the actual data / server formula, including border scaling; never round only the tooltip.
  Exact roll odds remain exact. Highlight only key percentages, turn counts and named status effects; activation
  limits / effect caps belong in `CardInfo.Badges` pills, backed by server counters. Use lore-themed ability
  terminology; keep the existing card / boss identities and art unless the user explicitly changes them.

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on
  the server, rate-limit it (`RateLimit`), and check ownership / NPC range where it applies.
- Attack borders always win: Base 1x / Gold 4x / Rainbow 16x / Secret 64x; base stats within +-10% of one line (HP = 2 x ATK),
  then rarer cards scale up (`Cards.Scale`: (10 / Weight) ^ 0.15, boss cards up to about 1.5x, the user's call);
  duplicates grant no stats; mastery never multiplies ATK / HP. A card on one border never reaches the next
  through mastery (odds_test checks). Traits stay
  small (never ATK / HP). Rolls are pure luck: no pity. Fusion is border fusion only: 100 copies at one border -> 1 at the next.
- Content is data: a new card is one entry in `Cards.luau` (stats, abilities, `Role`, `Weight`, `Element`, `Image`); a
  boss or difficulty one entry in `Bosses.luau`; a relic or artifact in `Items.luau`; a trait in `Traits.luau`; a potion / gift /
  milestone / quest in `Meta.luau`. Support entries use generic `Support.Kind` handlers; Attack passives / Auras / Signatures use generic trigger bundles.
- Save format changes need a step in `SaveMigration` (safe to run twice) and a case in `tests/save_test.luau`.
- Potions, upgrades and gifts are earned in game only (Shard bundles are gated like random items because Shards buy luck).
  Robux sales live only in MonetizationConfig / MonetizationService; any perk that changes odds or gives random rewards
  is gated by PolicyService, with all outcomes and live odds summing to 100% shown.
- Boss HP / ATK per difficulty are tuned so each fixture deck in `tests/fixtures.luau` wins its fight in 60-90 s
  (`tests/battle_test.luau`, all 12 fights); `tests/tower_test.luau` does the same for the tower and the Pagoda (Rainbow /
Secret chase decks). Re-run after changing
  cards, bosses or battle rules, and retune if they fail.
- Original characters only: no real anime characters, names or trademarked terms.
  Prototype exception (the user's call, 2026-10-25, confirmed 2026-10-26): card and boss names are anime-style
  epithets that nod to well-known series (card ids unchanged). Keep them: don't rename them unless the user asks in
  their own words. This is for private testing: rename to fully original names before any publish.
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
