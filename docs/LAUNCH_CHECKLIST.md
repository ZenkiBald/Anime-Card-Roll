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
  - turns the unlock rules on (Quick Roll after 20 rolls + 3 min, Auto Roll after 50 rolls + 10 min, the tower after
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

- [ ] Arena: camera clipping into terrain (Frostfang), the front guard's panel vs the card dock, the glow behind Tenrai.
- [ ] Battle pods and the Surge meter use CanvasGroups: check sharpness and frame rate on a low-end phone.
- [ ] Fusion (single and FUSE ALL), packs during Auto Roll, OPEN 1 / 5 / 10 / ALL, tower replays, the QUICK toggle.
- [ ] Drawn ✕ / ▾ glyphs, element-lit portraits, NPC plates at distance, name tags above hats.
- [ ] A save from the old rarity era loads correctly (covered by `tests/save_test.luau`, but worth one real look).

## 6. Smoke test on the live game (first hour)

- [ ] Join on PC and on a phone: title screen, HUD, roll, Auto Roll, a reveal, the Index.
- [ ] Leave and rejoin: cards, Shards, deck and settings are still there (live saves).
- [ ] Buy one pass with a real account (or a friend's): the perk works at once and after a rejoin.
- [ ] Beat Kurogane Normal: rewards, the boss card unlock banner, the tower opening.
- [ ] Wait for :30: a raid opens for the server.
- [ ] Check the server output for errors (Developer Console, F9).
