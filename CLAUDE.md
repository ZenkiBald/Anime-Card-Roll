# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses for bonus rolls.
Full design (rarities, cards, battle, bosses, rewards, production plan):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

## Status

Milestones 1-4 of the design doc are built, plus a first polish pass: rolling (Roll / Quick Roll / Auto Roll),
the rarity reveal ladder, 18 starter cards, duplicates -> stars -> fusion copies, pity, saving, collection, odds panel,
test tools; the deck builder (4 + 4 slots, 3 presets, Auto-build); the server-run battle engine; all 3 worlds
(Kurogane, Rimeveil, Null Emperor Vex; World 4 Tenrai added later) on Normal / Hard / Nightmare with unlocks; boss reward rolls with luck,
floors and first-clear bonuses; 3D boss NPCs in the hub and in battle (built from parts in `BossModels`);
3D chibi card art for all 18 cards (`CardArt`, from each card's `Look`); long-term progression (`Meta`):
potions, Shard Shop upgrades, the Index with completion rewards (replaces the old Collection / ODDS button;
the odds panel opens from the Index and the HUD stats), daily streak, playtime gifts, roll milestones;
SKIP on long reveals and the boss reward fan.
Design changes from the doc: Support cards have no HP (they can't be hit or KO'd and cast their Basic as the
fight opens; Support Deck Power is PWR x 24). Boss wins also pay 15 x D Shards and may drop a potion.
2026-10-22 pass (verified in Studio play mode with screenshots): UI kit skins load and fit (button art scales
to the button's height; top currency bar with big numbers; HUD hides during full reveals); a big world built
in Studio (terrain + Creator Store models + AI meshes, StreamingEnabled): spawn town in the middle, Ember
Village west, Frostfang Peaks north, Neon Abyss east, each with portal + boss; real sound (`UI/Sfx.luau`:
licensed Pro Sound Effects / APM stings, rarity stings, zone + battle music via `ZoneFx`).
Battle result panel and Gifts use the kit look (`Kit.tile` tiles, big numbers, kit icons); TRAVEL panel
(server-owned fast travel to Town / each boss zone); SETTINGS gear top right (Music / Effects volume saved in the
profile, effects quality HIGH/LOW; replaces the old FX menu button).
Fusion (user's design, 2026-10-22): duplicates past 5 stars no longer pay Shards; they pile up as copies.
`Config.FusionCopies` (100) copies of one card fuse it one rarity up at Hoshi the Fusion Master (town NPC at the
map's `Fusion` marker, panel `UI/Fusion`), again and again up to Secret; the copies become one card, stars stay.
A fused card gets its new rarity's power (`Cards.Stat`: stats x new tier multiplier / old), so "rarity always
wins" still holds. Saves keep it as `Cards[id].Fusion`. Frostfang Peaks' lighting mood has exposure -0.6 so snow
and Rimeveil don't blow out.
Daily quests (top of GIFTS): 3 a day from `Meta.Quests`, picked by `Meta.QuestsFor(day, userId)` (same on both
sides, not saved); the server counts progress with `MetaService.Track(player, stat)` from rolls, boss wins,
fusions, gifts and potions. Rebirth was removed (2026-10-23, user's call: a card game doesn't need it; long-term
luck comes from artifacts and accessories). Stat points: every level past 1 gives a point for Luck, Roll Speed,
Border Chance, Shard Gain or XP Gain (`Meta.Stats`, capped per stat; STATS menu button, `UI/Stats`; reset for
Shards). BAG menu button (`UI/Bag`) replaces POTIONS: tabs Potions / Artifacts / Accessories (the last two are
placeholders until they drop). The Lucky Wheel is an NPC, Madame Fortuna, at the map's `Wheel` marker (falls
back near the spawn) with a turning wheel booth; no HUD wheel button.
Card borders (`Borders.luau`, 2026-10-23): every pull also rolls a border on its own, Normal / Gold (1 in 25) /
Rainbow (1 in 250) / Secret (1 in 2,500), raised by the Border Chance stat; a card keeps every border it found
(`Cards[id].Borders`) and wears the best, for a tiny bonus (+1 / +2 / +4%, so a 5-star Secret-border card still
stays under the next rarity; odds_test checks). `UI/BorderFx` draws the frames; the reveal teases the border on the
card back, then slams a "NEW RAINBOW!" ribbon on and calls "RAINBOW LEGENDARY!"; Rainbow / Secret always get the
full reveal, stop Auto Roll when new, and are announced to the server. The odds panel lists border odds, the Index
detail shows found borders. Test tools: border reveal previews and GIVE BORDERS.
Gear (`Items.luau`, 2026-10-23): every boss win rolls for an accessory (20% + 3% x D, max 60%) and an artifact
(3% + 0.7% x D, max 15%), rarer gear on harder fights (Mythic only from D 7); the boss screen shows the odds and
the victory screen calls out drops. Artifacts (10, Rare-Mythic): wear 3, each adds Luck / RollSpeed / Border /
ShardGain / XPGain (`Meta.Bonus` = stat points + worn artifacts); duplicates level them to 5, then melt into
Shards. Accessories (9): one per card, battle-only buffs (SPD, Crit, CritDamage, Guard, StartEnergy) applied as
permanent unit buffs in `BattleEngine` (never ATK / HP, so Deck Power and rarity order don't move). Saved as
`Gear` { Artifacts, Accessories, Worn, Cards }; MetaService actions WearArtifact / RemoveArtifact / WearAccessory
/ RemoveAccessory; BAG tabs in `UI/BagGear`. Test tools: GIVE ITEMS.
Infinite Tower (`Tower.luau`, 2026-10-23, built in a cloud session: headless tests only, not yet seen in Studio):
endless floors, progress saved as `Tower.Floor` (highest cleared; you always fight Floor + 1, each floor pays once).
Each floor's enemy is an "Echo" of a world boss (its moves, model tinted, backdrop) picked by a seeded hash of the
floor (same everywhere, previewable); Vex from floor 24, Tenrai from 30. Recommended power 9k x 1.068^(floor-1)
(floor 48 ~ Tenrai Nightmare, no top); HP / ATK from `Tower.Curve.Points` (simulator-fitted anchors, log-joined).
Boss move set by floor (Hard from 15, Nightmare from 30); affixes from floor 5 (Swift / Armored / Brutal /
Colossal, fair trades). Every 10th floor a Guardian (1.15x power): full boss reward rolls, bonus card, sure potion,
4x gear odds. Rewards use D = floor x 0.25 (`Rewards.For`, `Items.RollDrops(d, rng, boost)`). Server:
`BattleStart("tower")` (BattleService picks the floor; `Engine.new` takes `Stats` to override HP / ATK),
`RollService.TowerRewards`. Client: TOWER tab on the BATTLE screen (`BossScreen.OpenTower`), NEXT FLOOR / TRY AGAIN
on the result panel, a tower gate in town at the map's `Tower` marker (falls back to the spawn's right), a HIGHEST
FLOOR board beside it, Floor in the player list, a daily quest (TowerFloors), dev +10 FLOORS / TOWER TO FLOOR 1.
Opens after `Tower.UnlockAfter` (Kurogane Normal) when unlock rules are on. `tests/tower_test.luau` checks it.
Auto-climb: after a tower win the next floor starts after a 4 s countdown (AUTO CLIMB toggle on the result panel).
Roll Packs (2026-10-23, user's call; replaced the short-lived rarity-ticket roll bank, old tickets convert to
Roll Packs on load): `Packs.luau` (Roll Pack 10 / Big 100 / Mega 1000 rolls, no rarity of their own). Boss wins
drop `Packs.ForBoss(d, firstClear)` Roll Packs; tower floors drop on every 5th (Guardians 2, floor 25s a Big, 100s a
Mega, `Packs.ForFloor`); daily days 3 / 7 and roll milestones 500 / 2500 / 25000 grant packs too (`Bundle.Packs`).
Saved as `Packs[id] = count`; `OpenPack` remote opens one at the player's luck at that moment (batched rolls:
one AddXP, only the best pull announced; returns the rarest `Packs.ShowCards` for the flip reveal + counts per
rarity). BAG > PACKS (`UI/BagPacks`, `UI/PackOpen`), OPEN on the battle result panel. The BAG badge counts them. Fusion panel: `busy` now always clears (pcall + panel close), the
old lock-after-one-fusion bug.
4v4 squads (2026-10-23, user's pick; built in the cloud, headless tests only, not yet seen in Studio): every
fight is the leader (the boss, or the tower's echo; engine id "Boss") + 3 guards (G1-G3) from
`Bosses.GuardTypes` (12, three themed per boss in `boss.Guards`; HP / ATK are shares of the leader's).
Roles: Striker (hits hard), Hexer (burn / freeze / slow), Mender (heals 1.2% of the leader's HP every other
action, Rally +15% ATK every 5th; moves with Target "Ally"), Warder (Taunt + Protect: the leader takes 30% less
while it stands; listed last so it stands in front). Win = the leader falls. Cards hit the focus target
(BattleInput "Target", `Engine:SetFocus`; tap an enemy, tap again to clear), else a taunting guard, else the
enemy with the least HP. Card effects can target "Enemies" (Hayate's Cyclone, Amaya's Stormcall, Orin / Amane
debuffs) or "RandomEnemy" (Kaede, Noa's Comet Rain, Kaito's Ultimate). Tower floors draw 3 guards
(`Tower.GuardsAt`, seeded, at most one Warder / Mender). Boss HP / ATK and `Tower.Curve.Points` were retuned for
squads (about 75 s, about 1 card KO'd). Client: guard tiles left / right / in front of the leader, gold TARGET
marker, guard callouts and KO ("DOWN!"), GUARDS DOWN on the result panel, guard line on the BATTLE screen.
Favourite card + server list (2026-10-23): Index detail "SET AS FAVOURITE" (MetaService "SetFavorite",
`Settings.Favorite`); LeaderboardService sets player attributes Fav / FavFusion / FavBorder (favourite, else rarest),
Power (active Deck Power), Rolls, Level every 2 s; `UI/PlayerList` (top right, left of the gear, "›" folds it) lists
everyone strongest first with their favourite card as picture; Roblox's player list is off. Name tags show the
favourite. New card look (`CardView`, user's reference): full-art, chips (rarity, border, stars, fused), big name,
headline ability bar (Ultimate > Skill > Basic), tag chips (type + passives), DMG / HP (PWR / SPD) footer.
HUD: running potions are tiles bottom right (above the jump button on touch), legendary pity counter over ROLL,
Auto Roll feed lower right. Test tools: GIVE PACKS.
Planned next: traits rolled onto cards; AI card illustrations (user) to replace the chibi figures. Keep it SMALL: rarity still wins.
Leaderboards: Rolls / Level in the player list, and three boards at the map's `Leaderboards` marker
(most rolls, rarest card incl. fusions, fastest Nightmare clear of the last boss) from OrderedDataStores,
refreshed every 60 s.
World 4, Stormspire Isle (south of the lake, over a second bridge; town gate at the south-east): boss Tenrai,
the Storm Sovereign (Chain Lightning hits random cards, Thunderclap stuns the whole deck at 50%), D 10-12,
recommended 140k / 172k / 205k (Nightmare needs a few fusions), 4 new cards (Hayate, Amane, Tsubasa, Amaya),
rain battle backdrop, storm music + local lightning in `ZoneFx`. Terrain: `tools/studio/terrain.luau`
`{ Rows = {9, 11} }`; props + markers: `map.luau` `{ Part = "storm" }`.
Visual pass: a title screen (`UI/Title`: logo, 3D card fan, PLAY unlocks once loaded; the HUD waits behind
it); reveals stand on a tier-coloured backdrop (radial glow + motes), the card flips and sways, Legendary+ get
letterbox bars and Mythic/Secret a light burst; the battle has a glowing boss platform per world, a vignette,
themed hit sparks, crit flash + shake and bigger damage numbers; POTIONS, SHOP rows and the Index detail
use the kit tile look; panels rise and pop in.
Ride pets (`Mounts.luau`, `MountService`, `UI/Pets`): 5 AI-generated mounts (Sakura Pup free; Ember Fox,
Frost Wolf, Void Ray, Storm Kirin unlock on each boss's first Normal clear), speed 26-38, no battle power.
G or the PETS paw (top right, under the gear) rides / gets off; the server welds the model under the rider.
Models live in the place at `ReplicatedStorage.MountKit` (not Rojo); per mount `Seat` is the rider's hip height
and `Forward` slides the model so the saddle is under them. Dash on Q (touch: DASH button, gamepad: X), client
side with a 1.2 s cooldown; Quick Roll moved from Q to T.
On foot, your last mount follows as a small pet (`Followers.luau`, client-drawn from the character's "Pet"
attribute). Name tags over every player (`NameTagService`: name, level, rarest card in its colour).
Sakura petals drift in town and leaves in Ember Village (`ZoneFx`). The 4 bosses, Kenji and Hoshi use AI
models from `ReplicatedStorage.BossKit` (place only; `BossModels.Build` scales them and falls back to the
block figures).
Retention pass (all in `Meta`, all earned, nothing sold): player levels 1-100 (XP from rolls, new cards,
boss wins x D, quests, fusions and every minute played; each level pays Shards, potions every 5th, +0.02x
base luck every 10th; `MetaService.AddXP` + Progress remote; level bar under the top bar, LEVEL UP burst);
server events on the clock (`Meta.EventAt`: the last 5 min of every 15 runs LUCKY STORM 2x luck / ROLL
RUSH 40% faster / DOUBLE XP in turn, same on every server; event pill under the level bar); Lucky Wheel
(`UI/Wheel`, a free spin per 20 min played, banked up to 5, every prize's chance shown); playtime gifts now
run to 3 hours. Test tools can start an event, give spins and add XP.
Readable abilities (`UI/Abilities`): coloured slot badge, when it fires, big name, numbers in gold; shown in the
Index detail, beside the card on full reveals, and in battle (tap a card for its abilities; SKILL casts pop a tag
over the card). Card art: the user is making 2D anime illustrations from `art/CARD_ART_PROMPTS.md`; PNGs go in
`art/cards/<cardId>.png`, Claude uploads them from Studio and sets `Image` in `Cards.luau` (an Image fills the
portrait in cards, tiles and battle; cards without one keep the 3D figure).

## Layout (Rojo project, `default.project.json`)

- `src/shared` -> ReplicatedStorage.Shared: `Config` (tuning + `TestMode`, deck and battle rules), `Rarity` (7 tiers),
  `Cards` (card data; each ability lists its battle effects from the effect library documented at the top),
  `Odds` (luck, floor, pity math, shared by server and client so the odds panel matches the server),
  `Borders` (card border odds, colours and bonus), `Items` (artifacts, accessories, drop odds, gear bonuses),
  `Deck` (deck rules, validation, Deck Power, Auto-build), `Bosses` (boss stats, moves, difficulties, unlocks),
  `Rewards` (boss reward rolls / luck / floor per difficulty score D), `BossModels` (NPC figures from plain parts),
  `Tower` (Infinite Tower floors, enemies, affixes, curve, rewards),
  `Cards` also has the fusion helpers (`FusedRarity`, `MaxFusion`, `Stat`, `Power(card, stars, fusion)`),
  `CardArt` (card chibi figures from `Card.Look`), `Meta` (potions, upgrades, Index rewards, daily, gifts,
  milestones, daily quests, levels and stat points, server events, the Lucky Wheel, and the luck / cooldown formulas
  both sides use), `Mounts` (ride pets).
- `src/server` -> ServerScriptService.Server: `Main.server`, `DataService` (ProfileStore saves),
  `RollService` (all rolls, cooldown, Auto Roll loop, dev tools), `DeckService` (presets), `BattleService`
  (runs fights in real time, streams events), `BattleEngine` (pure battle simulation, no Roblox services, so tests
  run it headless), `RateLimit`, `World` (at start: portal glow, signs, boss + sage NPCs and spawn at the saved
  map's markers, and zone circles in ReplicatedStorage.Zones; falls back to the old parts hub when there's no map),
  `MetaService` (potions + timers, shop, claims, SetMusic / SetEffects volume (must be in `Config.VolumeSteps`);
  owns the dev luck override and the player's total luck / cooldown),
  `TravelService` (Travel remote: validates "Town" or a boss id, rate-limited, refused in battle, streams the
  area in, then pivots beside the zone's Boss_ marker / Spawn), `FusionService` (Fuse remote: checks ownership,
  copies and max rarity, then fuses), `LeaderboardService` (leaderstats + the town boards; test scores go to
  `LB_*_Test_1` stores),
  `ProfileStore` (vendored, Apache-2.0). `RollService.RewardRolls` pays boss rewards (wired into BattleService in `Main.server`).
- `src/client` -> StarterPlayerScripts.Client: `Main.client`, `State`, `MetaClient` (progression calls, badge counts),
  `HubFx` (NPC idle animation, sage tips, portal lock labels), `ZoneFx` (zone music + lighting mood),
  `UI/*` (Kit helpers incl. `Kit.tile` / `Kit.dimTile`, Theme, Skin (UI kit image ids), BorderFx (card border frames), Title, Travel, Settings, Fusion, Modal (blurred-world
  panel with slanted banner), Controls (option pills, tabs, search, headers), CardView (full card), CardTile (square
  grid tile), Reveal, Effects, Hud, Index, OddsPanel, Bag + BagGear, Stats, Shop, Gifts, DevPanel, DeckBuilder, BossScreen,
  Battle, RewardReveal, ModelView (3D figure in a ViewportFrame), Sfx).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- Not in Rojo: the map lives only in the place file (published to Roblox): `workspace.Map` (Town, EmberVillage,
  FrostfangPeaks, NeonAbyss, StormspireIsle, Markers), Terrain, Lighting, `ServerStorage.MapKit` (store models,
  scripts stripped), `ReplicatedStorage.MountKit` (mount models), `ReplicatedStorage.BossKit` (boss / NPC models).
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on the server.
- Rarity always wins: each tier's stats are >= 1.6x the tier below; a card stays within +-10% of its tier base; stars add +5% each, max 5.
  Fusion keeps this: a fused card counts as its new rarity (stats scaled by the tier multipliers), never more.
- Content is data: a new card is one entry in `src/shared/Cards.luau` (stats, abilities, `Look`), a new boss or
  difficulty one entry in `src/shared/Bosses.luau`, a new artifact / accessory one entry in `src/shared/Items.luau`,
  a new potion / gift / milestone / quest one entry in `src/shared/Meta.luau`
  (no other code changes). Only Secret signatures are coded in `BattleEngine`.
- Potions, upgrades and gifts are earned in game only. Selling luck potions for Robux would make them paid random
  items (see the policy rule below).
- Boss HP / ATK per difficulty are tuned so the deck in `tests/fixtures.luau` for each fight (about its
  recommended power, fusions allowed via the fixture's `Fusion`) wins in 60-90 s; `tests/battle_test.luau` checks
  all 12 fights. Re-run it after changing
  cards, bosses or battle rules, and retune if it fails. `tests/tower_test.luau` does the same for the tower: each
  fixture deck must beat every enemy (and affix) at the floor matching its power, 90%+ with a median under 100 s
  (retune `Tower.Curve.Points` or the enemy HP multipliers if it fails).
- Original characters only, no real anime characters or names.
- Keep it cheap on phones: UI-first, plain Frames + tweens for effects, no textures or 3D particles in reveals;
  at most one 3D model per ViewportFrame. The world uses StreamingEnabled; keep the map under ~15k parts and
  few lights (the Abyss has 6), and give multi-part props ModelStreamingMode Atomic.
- Creator Store models: strip every script before use (tools/studio/stage.luau does). Sounds: licensed
  libraries only (Pro Sound Effects, APM Music) or ones shipped with Roblox; all ids live in `UI/Sfx.luau`.
- Leave `Config.TestMode = true` during testing. Setting it false hides the dev panel, enables unlock rules
  (`Config.Unlocks`) and makes the server refuse dev tools.
- If anything is ever sold for Robux that changes odds (luck boosts, pity skips), Roblox's paid random items policy applies:
  show all outcomes and live odds summing to 100%, and check `PolicyService:GetPolicyInfoForPlayerAsync()` (`ArePaidRandomItemsRestricted`).

## Commands

- Workflow: open the published place in Studio, run `rojo serve`, press Connect in the Rojo plugin. Rojo only
  touches the folders in `default.project.json`, never the map. Save/publish the place from Studio.
- Never `rojo build` over the place you open in Studio: a built place has no map (it gets the fallback hub).
  `rojo build default.project.json -o AnimeCardRoll-Test.rbxlx` is only for a throwaway script test.
- Rojo and the `luau` CLI are installed via rokit (`~/.rokit/bin`, pinned in `rokit.toml`); luau-lsp is not installed yet.
- Type check (needs luau-lsp): `rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json` then
  `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions @roblox=tests/defs/globalTypes.d.luau --ignore "**/ProfileStore.luau" src/`
- UI property names check (props set through `Kit.new` aren't type checked): `python tests/check_props.py tests/defs/globalTypes.d.luau src`
- Odds / pity / card stat / progression / deck / battle / tower / pack tests (needs the `luau` CLI): `python tests/bundle.py` then `luau tests/bundle_out.luau`

Tool versions are pinned in `rokit.toml` (`rokit install`).
