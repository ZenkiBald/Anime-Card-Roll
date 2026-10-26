# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses, climb an endless
tower and join server raids. Original design doc (it predates the border tiers, so its rarity sections are out of date):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

This file describes the game as it is now (2026-10-26). How it got here is in `git log` (one commit per pass).
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
within 45 studs only, fades in (HubFx), never draws over the world, and hides with player name tags while a panel,
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

**Cards.** 22 cards + 4 boss cards (anime-style epithet names for the private prototype, see Rules). Attack cards sit on one stat line (ATK ~500 +-10%, HP = 2
x ATK), scaled by rarity (`Cards.Scale`: a Weight 10 card 1x, Weight 1 about 1.41x, boss cards
up to 1.53x), so the border decides power and rarer cards edge out common ones at the same border. Each has an
`Element`, a `Role` (Striker / Hexer / Mender / Warder) and abilities built from the effect library at the top of
`Cards.luau`; Attack cards at Weight 6 and rarer have an Ultimate, boss cards a passive too; Support cards have one passive definition
and its subtitle (`Title`) and colour (`Accent`) fit its name and element. The first five duplicates give a
**Copy bonus** of +5% stats each, up to +25% (still `Stars` internally / in saves). Stars and Awakening pips are
omitted from card faces; progression is explained in the skill sheet. Copies pile up per border (`BorderCopies`); every border with copies is its own
tile in the SQUAD vault (Gold x5 beside Rainbow x1), and the tile put in the deck is the border the card fights at
(`Deck.PlayBorder`, the save's `Play`; DeckService `PlayAs`; AUTO-BUILD resets to the best border); Awakening nodes at 20 / 40 / 60 / 80
copies (+10% stats, +15% Skill DMG, 400% bond, trait slot 2). **Border fusion** at Hoshi: 100 copies at one border -> 1
copy at the next (FUSE or FUSE ALL, which cascades); the card at the next border is the whole reward (no luck, Trait
Shards or XP). Traits are bought at Kenshin with Trait Shards (battle-only: SPD / crit / guard / energy, never ATK /
HP); AUTO rolls a slot until a ticked trait lands (up to `Traits.AutoMax` rolls a tap) and applies it. The Index lists
every card by best border with completion rewards per border. A card can be worn as your avatar (element aura; Rainbow
fire footsteps, Secret celestial motes).

**Deck and battle.** 4 Attack + 4 Support, 3 presets (+2 VIP), AUTO-BUILD / COUNTER-BUILD. Each Support is a passive modifier for the Attack card with the matching slot number. Supports have **no damage,
HP, action bar, Skill or Ultimate**. They are never enemy targets and do not take turns. `Cards.Support` defines the
modifier; `Cards.SupportValue` applies border strength (Base 1 / Gold 1.25 / Rainbow 1.5 / Secret 1.75x), Copy bonus
and Awakening stat multiplier, capped at 50%. Trigger counts and healing caps never scale. Fixed effects (last stand
and cleanse) have the same limits at every border. Passive cards add no Attack rating (`Cards.Power`); AUTO-BUILD
ranks them separately by border / rarity / Copy bonus / Awakening. Existing ownership and all 4+4 presets remain.
The 11 support effects are: Lotus Blossom emergency heal (15% max HP below 40%, once); Fist of Severance damage reduction
(8%); Thunder Flash action speed (+8%); Phantom Blade dodge (6% per enemy hit, excludes burns); Dream Reaper weakening
(Skill / Ultimate hit reduces one target's ATK by 8% for two turns, four casts); Iron Bastion opening shield
(15% max HP, once); Celestial Strategist critical chance (+6%); Time Weaver starting Ultimate energy (25%); Nine-Tails Sovereign
last stand (survive one fatal hit at 1 HP, no invulnerability); Shadow Puppeteer cleanse (two burn / freeze applications);
Storm Oracle lifesteal (4% direct damage, max 20% of the attacker's max HP per battle, no overkill). Names / ids / art
are unchanged. Actual names are authoritative in `Cards.luau`; every effect only helps its paired attacker.
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
(`UI/Arena`, low cinematic camera, guards as tinted smaller copies; beams fly from the card slots to the 3D figures,
hits flash and recoil, guards lunge, boss skills and crits shake the camera; a defeated guard or leader topples
and fades in dark red; callouts show one at a time with at most three queued); no map = the 2D fallback. Damage
numbers have bounded pixel sizes and at most two per target; on the squad's cards they spawn above the frame.
On short phone screens, guard target panels sit in a fixed right rail and the duplicate leader plate hides;
Action countdowns use the line below each Attack card's name. Auto Roll continues with its feed hidden during fights,
and DASH hides until returning to the hub. Supports have no cast tags.

**Content.** 4 worlds x Normal / Hard / Nightmare (D 1-12; recommended Attack rating 25.4k ... 175.6k; the fixtures are Base in
World 1, Gold after, World 4 Gold 5-star with Awakening 1-3). Boss wins pay reward rolls (luck / floors by D), Shards,
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
`Goals.Next`) shows the reward closest to landing (a fusion, an Awakening node, a roll milestone, a Shard upgrade). Social: server list with favourite cards, profiles, name
tags, three town leaderboards.

**Store.** Passes (Fast Roll, Auto Roll+, Triple Roll, VIP), Server Luck Totem, Shard bundles. Every perk that touches
odds or random rewards is gated by PolicyService (`ArePaidRandomItemsRestricted`). Ids are 0 (placeholders) until launch.

**Look.** Illustrated Dark Feudal Occult: Urushi lacquer, antique-gold engraved waves, Washi text and vermilion
cherry-blossom calls to action. `UI/UIArt` supplies four shared uploaded textures (navigation icons, inventory emblems,
panel and summon button); source PNGs, asset ids, crops and prompts are in `art/ui/occult/README.md`. `UI/Skin` routes
the existing panel / button keys into this kit, preserving live text and controls. Panels are 9-sliced; the vermilion
button uses a cropped background. Flat lacquer remains while images load. The archived cartoon kit stays off.
`src/configs/UITheme.luau` feeds `UI/Theme`: Gotham headings / body, Garamond on ROLL, subdued 1 px text shadows,
element colours only where they carry meaning. No thick black letter outlines or multicoloured HUD button trims.

The HUD has one vertical icon-and-label menu, a small framed currency group, a quiet Kenji tracker / claim seal,
XP and Next Goal at bottom-left on desktop, and AUTO / ROLL / QUICK at bottom-centre with Momentum and Surge in one
band. The server list starts folded (tap to expand). RECENT PULLS shows up to three rows, two on short screens.
Surge still charges spirit blue, shivers void purple for the last four rolls, and seals gold (UNLEASH SURGE!).
AUTO / QUICK light their bezel when active. Short screens keep the earlier scaling / compact layout, with Next Goal
over the roll console. Routine Base duplicate pops only show in the feed; away rewards use one compact toast.

Panels (`Modal`) use the engraved lacquer artwork, plain headings with a gold rule and vermilion active-tab
underlines. On phones, `Modal.FitScale` lays out the panel at desktop size and scales it down (~0.6 sideways); turn
measured sizes back into offsets with `Kit.logicalSize`. The HUD, server list and quick pops hide behind panels.
Search / dropdowns and formation trays are quiet sunken wells. The deck screen retains spirit-blue Slot Links
(gold for bonds), its Cost Challenge meter and synergy / bond tags, with a vermilion AUTO-BUILD. Border-filter chips
draw labels above their background gradient so they remain visible.

`UITheme.BorderTiers` still frames cards: bronze 1 px, gold leaf 2 px, prismatic 2.5 px, void 3 px; the border is
the tier. Tiles show art, a plain ATTACK / SUPPORT label, element, name, xN, FUSE! at 100 copies and the
rarity number, with no combat stats. Names wrap / scale 8-14; stats live in the inspector / tooltip. Vault tiles are
larger; the phone inspector collapses until selection; deck thumbnails omit duplicate tiny name / rarity labels.
DECK explains the two card types and numbered pairs. Attack slots show damage / HP; Support slots show their actual
passive strength instead of generic power. Only attackers contribute to ATTACK RATING. Tapping a
vault card only selects it; EQUIP / REMOVE is explicit. The inspector prioritizes the passive effect / limits or Attack Basic and action / Skill timing
and Copy bonus. VIEW SKILLS / BONUSES opens the scrollable Index detail sheet at the selected border, with a visible
BACK TO CARDS button. `Shared/CardInfo` resolves the same effect amounts used by the server into plain language;
tooltips, Index, reveals, battle skill popups and fusion previews use concrete numbers. Advanced traits / Awakening
remain in the details. Battle skill popups scroll within the viewport. HUD refresh waits for initialization so an
early StoreState update cannot access missing currency chips.
BAG uses illustrated relic / potion / pack emblems with named plaques, separate status lines, and relic-rarity
frames (bronze / purple / gold / crimson); packs keep their roll counts. BOSS SCOUT retains its unit trays and
counter / synergy / bond information. Battle intros use smaller straight lacquer / vermilion panels, with matching
controls, enemy target panels and result frames. All timings and battle rules are unchanged.

`JuicyButton` still supplies sheen, spring and sounds; `IconBadge` carries element / role / currency crests.
Card portraits use their 2D `Image` when set, else the existing procedural bust (element pattern, diamond emblem,
role weapon and id-based hair crest). The user is making character illustrations: `art/STORY_CARD_PROMPTS.md` and
`art/cards/<cardId>.png`. This UI kit does not replace those illustrations or rename any cards / bosses.

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

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on
  the server, rate-limit it (`RateLimit`), and check ownership / NPC range where it applies.
- Attack borders always win: Base 1x / Gold 4x / Rainbow 16x / Secret 64x; base stats within +-10% of one line (HP = 2 x ATK),
  then rarer cards scale up (`Cards.Scale`: (10 / Weight) ^ 0.15, boss cards up to about 1.5x, the user's call);
  stars +5% each, max 5; a maxed card on one border never reaches a 0-star card on the next (odds_test checks). Traits stay
  small (never ATK / HP). Rolls are pure luck: no pity. Fusion is border fusion only: 100 copies at one border -> 1 at the next.
- Content is data: a new card is one entry in `Cards.luau` (stats, abilities, `Role`, `Weight`, `Element`, `Image`); a
  boss or difficulty one entry in `Bosses.luau`; a relic or artifact in `Items.luau`; a trait in `Traits.luau`; a potion / gift /
  milestone / quest in `Meta.luau`. Support entries use generic `Support.Kind` handlers; only Secret signatures get card-specific engine exceptions.
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
