# Launch checklist

Everything that has to change between "testing in Studio" and "public game", in order. Items marked **code** are edits in
this repo (sync with Rojo, then publish); the rest are Roblox Studio / Creator Dashboard settings.

## 1. Balance decisions

- [x] **Fusion luck removed** (user's call, 2026-10-24). Fusions used to add +0.05x permanent luck each, which had no limit
  of its own and reached the 25x luck cap within a day or two of heavy rolling. Fusion Trait Shards and XP went too:
  a fusion's whole reward is the card at the next border (4x stats).

## 2. Code switches

- [ ] **code** `src/shared/Config.luau`: `Config.TestMode = false`. This one switch:
  - moves saves to the live store `PlayerData_1` (test saves in `PlayerData_Test_1` do NOT carry over: every live
    player starts fresh, testers included);
  - moves leaderboards to the live `LB_*_1` stores;
  - turns the unlock rules on (Quick Roll after 20 rolls + 3 min, Auto Roll after 50 rolls + 10 min, the towers after
    Kurogane Normal, 2x battle speed after its unlock fight);
  - hides the DEV panel and makes the server refuse every dev tool and mock purchase (`DevAccess`).
- [ ] **code** `src/shared/MonetizationConfig.luau`: paste the real ids from the Creator Dashboard over the 0s:
  `FAST_ROLL_PASS_ID`, `AUTO_ROLL_PASS_ID`, `TRIPLE_ROLL_PASS_ID`, `VIP_PASS_ID`, `SERVER_TOTEM_PRODUCT_ID`, and the
  three `ShardBundles` `ProductId`s. Set every `Price` to the dashboard price. Set `MockPurchases = false`.
- [ ] **code** `src/server/Codes.luau`: review the codes (`RELEASE`, `LUCKY`, `TOWER`, `SQUAD`, `TRAITS`, `AWAKEN` are
  the test set). Keep the launch ones, give time-limited ones an `Expires` (unix time).
- [ ] **code** `Config.DevUserIds`: empty it (it only matters while TestMode is on).
- [ ] Run the checks (type check, props check, headless tests: see CLAUDE.md > Commands) and commit.

## 3. Creator Dashboard

- [ ] Create the 4 game passes (Fast Roll, Auto Roll+, Triple Roll, VIP) with icons and prices.
- [ ] Create the developer products: Server Luck Totem and the 3 Shard bundles.
- [ ] **Experience Questionnaire / maturity**: answer the **paid random items** questions truthfully (VIP luck, Auto Roll+
  perfect surges, Triple Roll, the Totem and Shard bundles all change odds). The game already hides those perks where
  `ArePaidRandomItemsRestricted` is true and shows every outcome with live odds in the ODDS panel.
- [ ] Game icon, thumbnails, description (original characters only; no real anime names or trademarked terms).
- [ ] Server size and genre.

## 4. Studio, before publishing

- [ ] `rojo serve` + Connect (reconnect if it was connected before the last pull), so every script and remote is in.
- [ ] Run `tools/studio/lighting.luau` once (`Lighting.Technology = Future` can only be set in Studio), save.
- [ ] Workspace `StreamingEnabled` on; the map stays under ~15k parts.
- [ ] Game Settings > Security: Studio access to API services on (only needed to test saves in Studio).
- [ ] Publish to Roblox from Studio (never `rojo build` over the place: a built place has no map).

## 5. Things still to check in Studio (never seen there yet)

- [x] Card clarity / support borders (2026-10-26): desktop SQUAD shows Attack damage / HP, concrete Support effects,
  type labels and numbered pairs. VIEW SKILLS opens the selected border's scrollable sheet; BACK TO CARDS works.
  Copy bonus replaces unexplained stars; advanced traits / Awakening remain in details. Live battle starts without
  new runtime errors. StoreState / missing currency startup error fixed and absent on fresh Play.
- [ ] User review: AUTO-BUILD, inspect without changing the deck, EQUIP / REMOVE, a Gold Support's actual healing /
  shields / percentage boost, skill-sheet scrolling and the battle skill popup. Real iPhone check remains parked.
- [x] Existing town polish (2026-10-26): real Edit / Play previews, fountain border / service paving / benches,
  moved stalls / NPC markers and jade tower. Pathfinding reaches all five service approaches from spawn without
  jumping; Hoshi / Kenshin / Fortuna range checks accept nearby and reject far-away positions. Map 10,137 parts.
  Local place copy saved in `studio-local/AnimeCardRoll-TownPolish-20261026.rbxl`; nothing published.
- [ ] User view at ground level: fountain / stall sightlines, benches, each NPC's prompt and the Tower / leaderboards.
- [x] Illustrated UI kit (2026-10-26): desktop Studio HUD, SQUAD, BAG, battle controls / intro; uploaded
  navigation / inventory atlases and frames load. Vault / BAG names fit; border-filter labels are visible.
- [ ] User visual review of the implemented kit: menu / roll console, claim seal, selected SQUAD inspector,
  BAG item art / pack counts, store and battle results. Real-device sharpness / memory and all touch actions remain
  to check; phone-specific work is parked at the user's request. No place was published by this pass.
- [x] iPhone readability pass (2026-10-26), Studio iPhone 14 landscape emulator: HUD / SQUAD / BAG and one Normal
  fight; no new runtime errors. All 27 owned vault names and current BAG names fit. Battle feed and DASH hidden.
- [ ] Real iPhone after this pass: smaller HUD / two-line event pill; vault scrolling, selected-card inspector and
  EQUIP; named BAG plaques and status lines; three fixed guard targets, tap to focus, bounded damage numbers,
  single callout at 2x / AUTO CLIMB, Skill text below names, and DASH restored after BACK TO HUB.
- [ ] Arena: camera clipping into terrain (Frostfang), the front guard's panel vs the card dock, the glow behind Tenrai.
- [ ] Battle pods and the Surge meter use CanvasGroups: check sharpness and frame rate on a low-end phone.
- [ ] Fusion (single and FUSE ALL), packs during Auto Roll, OPEN 1 / 5 / 10 / ALL, a tower run ending on a loss (and on leaving mid-fight),
  the PAGODA tab and a milestone, the QUICK toggle.
- [ ] Drawn ✕ / ▾ glyphs, element-lit portraits, NPC plates at distance, name tags above hats.
- [ ] The 2026-10-24 playtest fixes: SUPPORT OPENING! after FIGHT!, the focus hint above the card rows, cast tags
  across the card middle, Vault tiles (DMG / HP on two lines, the ✓ under the stars), the neutral cost pill, the
  ODDS panel's round rarity numbers, the rarity chip on cards and the rarity number on tiles, the
  Trait Master's AUTO ROLL view, the BAG's RELICS / ARTIFACTS tabs and the Pagoda's floor 100 artifact.
- [ ] The art-direction pass: new card tiles (tier frames, star diamonds, element + role badges, name / stat / rarity
  rows), the Surge talisman's three states and shiver, the wax-seal ROLL, recessed AUTO / QUICK, no cyan trims left.
- [ ] Art direction phase 2: panel frames and tabs on every screen, the deck screen (wells, tethers, cost meter,
  synergy tags, AUTO-BUILD / CLEAR), sunken dropdowns, the STORE crests and R$ buttons.
- [ ] Density pass: card tiles without stats (rarity number still on them), BAG plaques and crests and the 2 x 2 OPEN
  seals, BOSS SCOUT trays and chips, the sunken boss well, vermilion tab underlines everywhere.
- [ ] The featured card in the event pill / ODDS / Index; a "While you were away" toast after 10+ min offline; a
  [GLOBAL] Secret banner across two live servers (MessagingService only works in a published game).
- [ ] QoL pass: AUTO REPEAT after a boss win (off by default, counts down, stops on a loss / opening rolls / BACK),
  the "stronger deck is ready" hint and SQUAD badge after a good pull, the "can fuse, see Hoshi" hint, and badge art
  (paste one id into a `Skin.Icons` key such as `Element:Flame` and check every badge picks it up).
- [ ] Lower borders in the SQUAD vault: a card with Gold and Rainbow copies shows two tiles; tapping the Gold tile
  twice puts it in (or switches it) at Gold, the slot, battle card and Deck Cost follow, AUTO-BUILD goes back to Rainbow.
- [ ] Playtest round 3 (2026-10-26): town signs only within 45 studs, 35% smaller, gone while a panel / fight /
  reveal is open; procedural portraits look different card to card (pattern, emblem, weapon, hair); long names wrap
  on vault tiles and splash cards (no "Starfall Wit"), no ★5 chip on splash cards; FUSE! seal and Awakening pips on
  vault tiles, the inspector's EQUIP / FUSE / ROLL TRAITS; the squad dock 12 px higher with no Support row clipping,
  damage numbers above the cards, the third guard clear of the dock, beams / hit flashes / lunges / camera shake in the
  3D arena; AUTO-RETRY above SPEED; the Next Goal pill over Momentum.
- [ ] Pacing pass (2026-10-26): with AUTO CLIMB on, a tower win shows a 1 s banner and the next floor starts with a
  0.3 s FIGHT! (no YOUR DECK vs curtain, no Victory panel); an overpowered deck sweeps up to 5 floors at once with a
  SWEPT FLOORS banner (Shards, packs and quests all count); defeated guards topple and fade; stacked callouts; SCOUT's
  four unit cards; the Victory panel's pack progress bar and run totals when no pack dropped.
- [ ] Combat rhythm (2026-10-26): the opening reads as turns (no burst), cards show SKILL in N / SKILL READY, the boss bar
  shows "⚠ MOVE in N", supports lift on their turn, and a strong deck's HP bars still drop (MinHit) so healers heal.
- [x] Town brightness (2026-10-26): user confirmed "yeah its bright now" after the lighting pass.
- [ ] World themes (2026-10-26): walking into each world tweens to its own look
  (Ember golden sunset, Frostfang snowy morning without blown-out snow, Neon Abyss violet night with neon bloom,
  Stormspire grey storm with lightning) and back to day in town. Re-run `tools/studio/lighting.luau` once and save.
- [ ] Phone layout (2026-10-26): SQUAD shows four deck rows and the vault grid, BATTLE's tabs clear its title, the BAG
  tabs fit, no HUD shows through or over an open panel (no DUPE pops on top), the top bar clears Kenji's tracker and
  the server list, and the Auto Roll feed sits above the DASH / jump buttons.
- [ ] A save from the old rarity era loads correctly (covered by `tests/save_test.luau`, but worth one real look).

## 6. Smoke test on the live game (first hour)

- [ ] Join on PC and on a phone: title screen, HUD, roll, Auto Roll, a reveal, the Index.
- [ ] Leave and rejoin: cards, Shards, deck and settings are still there (live saves).
- [ ] Buy one pass with a real account (or a friend's): the perk works at once and after a rejoin.
- [ ] Beat Kurogane Normal: rewards, the boss card unlock banner, the tower opening.
- [ ] Wait for :30: a raid opens for the server.
- [ ] Check the server output for errors (Developer Console, F9).
