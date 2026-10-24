# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses, climb an endless
tower and join server raids. Original design doc (it predates the border tiers, so its rarity sections are out of date):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

This file describes the game as it is now (2026-10-24). How it got here is in `git log` (one commit per pass).
Launch steps: `docs/LAUNCH_CHECKLIST.md`.

## How the game works

**Studio status.** The 2026-10-22 world / UI / sound pass was verified in Studio. Everything after it was built in cloud
sessions with headless tests + luau-lsp only; the user has since play-tested the HUD, deck screen, Index, quests and a
tower fight (screenshots 2026-10-24) and the fixes from that are in (the second round's list is in the checklist,
section 5). Treat anything not named here as unseen.

**World.** A big Studio-built map (terrain, Creator Store models, AI meshes, StreamingEnabled): spawn town in the middle,
Ember Village (W), Frostfang Peaks (N), Neon Abyss (E), Stormspire Isle (S, over a second bridge), each with a portal and
its boss. Town NPCs: Kenji (guide), Hoshi (fusion + pack alchemy), Kenshin (traits), Madame Fortuna (Lucky Wheel), the
tower gate and leaderboards. Town services only work beside their NPC (server `NpcRange`, 24 studs); NPC name plates show
from 160 studs. TRAVEL fast-travels (server-owned). Mounts (5, G to ride), a shoulder pet, dash (Q, two charges) and a
double jump. Twilight lighting (`LightingSetup`), zone music and moods (`ZoneFx`).

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

**Cards.** 22 cards + 4 boss cards (original characters only). Every card sits on one stat line (ATK ~500 +-10%, HP = 2
x ATK; Support PWR ~300, no HP), scaled by rarity (`Cards.Scale`: a Weight 10 card 1x, Weight 1 about 1.41x, boss cards
up to 1.53x), so the border decides power and rarer cards edge out common ones at the same border. Each has an
`Element`, a `Role` (Striker / Hexer / Mender / Warder) and abilities built from the effect library at the top of
`Cards.luau`. Stars +5% each (max 5). Copies pile up per border (`BorderCopies`); Awakening nodes at 20 / 40 / 60 / 80
copies (+10% stats, +15% Skill DMG, 400% bond, trait slot 2). **Border fusion** at Hoshi: 100 copies at one border -> 1
copy at the next (FUSE or FUSE ALL, which cascades); the card at the next border is the whole reward (no luck, Trait
Shards or XP). Traits are bought at Kenshin with Trait Shards (battle-only: SPD / crit / guard / energy, never ATK /
HP); AUTO rolls a slot until a ticked trait lands (up to `Traits.AutoMax` rolls a tap) and applies it. The Index lists
every card by best border with completion rewards per border. A card can be worn as your avatar (element aura; Rainbow
fire footsteps, Secret celestial motes).

**Deck and battle.** 4 Attack + 4 Support, 3 presets (+2 VIP), AUTO-BUILD / COUNTER-BUILD. Each Support's Slot Link
buffs the Attack card in its column. Elements: Flame > Frost > Storm > Flame, Light <> Void, Cosmic beats all (x1.3 /
x0.85); 2 / 4 of an element switch on a synergy; 8 named bonds fire a Dual Ultimate once. Every fight is the leader +
3 guards (Striker / Hexer / Mender / Warder); tap an enemy to focus it; win when the leader falls. Stagger bar (counter
elements fill it faster) -> 5 s Staggered. Cost Challenge (Deck Cost by border 2/4/6/8, cap 30) for x2 Trait Shards.
The engine (`BattleEngine`) is pure and runs headless in tests. Fights are staged in 3D at the boss's spot in its world
(`UI/Arena`, low cinematic camera, guards as tinted smaller copies); no map = the 2D fallback.

**Content.** 4 worlds x Normal / Hard / Nightmare (D 1-12; recommended power 45k ... 388k; the fixtures are Base in
World 1, Gold after, World 4 Gold 5-star with Awakening 1-3). Boss wins pay reward rolls (luck / floors by D), Shards,
Roll Packs and Trait Shards (no gear). Two towers (BATTLE > TOWER / PAGODA), each floor an echo of a world boss with
affixes, Guardians every 10th, the daily mutator. Infinite Tower: a run (recommended 33k x 1.068^(floor-1)); every floor
pays, Roll Packs every 5th floor (Big every 25th); one loss, GIVE UP or leaving mid-fight (`Tower.Live`, ended by
SaveMigration on load) sends the run back to floor 1; the best run is the leaderboard and Guardian bonuses only pay past
it; from floor 50 every win has a 0.1% relic drop (`Items.RelicFloor` / `RelicChance`), the only relic source.
Hundred-Floor Pagoda: 100 kept floors (33k x 1.053^(floor-1), floor 100 is a full Secret deck's fight), each paid once,
milestones at 25 / 50 / 75 (packs, Trait Shards) and 100 (the Pagoda's artifact, the Crown of the Hundred Floors, and
the worn "Pagoda Master" title). Server raids every hour at :30 (a shared Colossus pool, Raid Luck x2 when cleared).
Roll Packs (10 / 100 / 1000 rolls) open 1 / 5 / 10 / ALL at your luck, also during Auto Roll; Pack Alchemy condenses or
infuses them.

**Progression and retention.** Levels 1-100 with stat points; Shard Shop upgrades; potions; gear in two sets
(`Items.luau`): **relics** (the 10 wearable items, `Items.Artifacts` / `Gear.Artifacts` in code, wear 3, Infinite Tower
drops only) and **artifacts** (`Items.TowerArtifacts`, one per finite tower's last floor, always on); daily streak,
daily quests, playtime gifts, time-away rewards (`Meta.OfflineReward`: a Roll Pack per 30 min and 2 Shards a minute
offline, after 10 min, up to 8 h; `LastSeen` in the save), roll milestones, Lucky Wheel, server events (LUCKY STORM /
ROLL RUSH / DOUBLE XP), codes, Kenji's 6-step path and titles. Social: server list with favourite cards, profiles, name
tags, three town leaderboards.

**Store.** Passes (Fast Roll, Auto Roll+, Triple Roll, VIP), Server Luck Totem, Shard bundles. Every perk that touches
odds or random rewards is gated by PolicyService (`ArePaidRandomItemsRestricted`). Ids are 0 (placeholders) until launch.

**Look.** Dark Feudal Occult: `src/configs/UITheme.luau` tokens (Urushi base / raised / inset lacquer, Tamahagane slate
/ edge / rust steel, Washi parchment and ghost text, Vermilion wax seal, element glows, FredokaOne headers; no electric
cyan) feed `UI/Theme`. `UITheme.BorderTiers` frames card tiles (bronze 1 px, gold leaf 2 px, prismatic 2.5 px, void 3
px: the border is the tier); stars are small parchment diamonds (they're stats, not the tier). The HUD's Surge talisman
charges spirit blue, shivers void purple for the last 4 rolls, and seals gold when the next roll is the surge (ROLL then
reads UNLEASH SURGE!); AUTO / QUICK are recessed and light their bezel when on. Panels (`Modal`) are Urushi with a 2 px
steel edge, a vermilion banner slash and underline, tabs with a vermilion underline when active; `Controls` dropdowns
and search are sunken wells. The deck screen has sunken empty slots, spirit-blue Slot Link tethers (gold for a bond), a
sunken Cost Challenge meter and synergy / bond tags; AUTO-BUILD is the vermilion seal. Card tiles carry no combat stats
(frame, art, star diamonds, element / role crests, name, xN and the rarity number); stats live in the deck inspector and
the tooltip. BAG plaques are framed by relic rarity (bronze / purple / gold / cosmic crimson) with diamond crests (packs
show their roll count). BOSS SCOUT is trays: leader and counter crests with +30% DMG, guard unit chips, synergy / bond
tags; the boss well is sunken with a vignette; every tab strip uses the vermilion underline. The STORE uses diamond
crests (monograms, no emoji) and solid vermilion R$ buttons. Components: `JuicyButton` (sheen, spring, sounds,
CanvasGroup content; roll console + battle pods) and `IconBadge` (diamond badges for element / role / currency). Card
portraits use the 2D `Image` when set, else an element-lit bust (the user is making the illustrations:
`art/CARD_ART_PROMPTS.md`, PNGs in `art/cards/<cardId>.png`).

## Layout (Rojo project, `default.project.json`)

- `src/configs` -> ReplicatedStorage.Configs: `UITheme` (design tokens, client UI only).
- `src/shared` -> ReplicatedStorage.Shared (both sides; pure data + formulas, tested headless): `Config` (tuning,
  `TestMode`, dev access lists, deck and battle rules), `Cards` (card data + `Pool`, `PullChances`, `Stat`, `Power`,
  `Cost`), `Borders` (the tiers: odds, multipliers, cost, colours), `Odds`, `Rarity` (relic / trait tiers only),
  `Elements`, `Foils`, `Awaken`, `RollBoost` (Momentum + Surge), `Deck`, `Bosses`, `Rewards`, `Tower`, `Raid`, `Packs`,
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
  Waypoint, Effects, Sfx, Skin, BorderFx, ModelView).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- Not in Rojo (place file only): `workspace.Map` (Town, EmberVillage, FrostfangPeaks, NeonAbyss, StormspireIsle, Markers),
  Terrain, Lighting, `ServerStorage.MapKit`, `ReplicatedStorage.MountKit`, `ReplicatedStorage.BossKit`.
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on
  the server, rate-limit it (`RateLimit`), and check ownership / NPC range where it applies.
- The border always wins: Base 1x / Gold 4x / Rainbow 16x / Secret 64x; base stats within +-10% of one line (HP = 2 x ATK),
  then rarer cards scale up (`Cards.Scale`: (10 / Weight) ^ 0.15, boss cards up to about 1.5x, the user's call);
  stars +5% each, max 5; a maxed card on one border never reaches a 0-star card on the next (odds_test checks). Traits stay
  small (never ATK / HP). Rolls are pure luck: no pity. Fusion is border fusion only: 100 copies at one border -> 1 at the next.
- Content is data: a new card is one entry in `Cards.luau` (stats, abilities, `Role`, `Weight`, `Element`, `Image`); a
  boss or difficulty one entry in `Bosses.luau`; a relic or artifact in `Items.luau`; a trait in `Traits.luau`; a potion / gift /
  milestone / quest in `Meta.luau`. Only Secret signatures are coded in `BattleEngine`.
- Save format changes need a step in `SaveMigration` (safe to run twice) and a case in `tests/save_test.luau`.
- Potions, upgrades and gifts are earned in game only (Shard bundles are gated like random items because Shards buy luck).
  Robux sales live only in MonetizationConfig / MonetizationService; any perk that changes odds or gives random rewards
  is gated by PolicyService, with all outcomes and live odds summing to 100% shown.
- Boss HP / ATK per difficulty are tuned so each fixture deck in `tests/fixtures.luau` wins its fight in 60-90 s
  (`tests/battle_test.luau`, all 12 fights); `tests/tower_test.luau` does the same for the tower and the Pagoda (Rainbow /
Secret chase decks). Re-run after changing
  cards, bosses or battle rules, and retune if they fail.
- Original characters only: no real anime characters, names or trademarked terms.
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
