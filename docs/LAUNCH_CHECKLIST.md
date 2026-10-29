# Launch checklist

Everything that has to change between "testing in Studio" and "public game", in order. Items marked **code** are edits in
this repo (sync with Rojo, then publish); the rest are Roblox Studio / Creator Dashboard settings.

## 1. Balance decisions

- [x] **Fusion luck removed** (user's call, 2026-10-24). Fusions used to add +0.05x permanent luck each, which had no limit
  of its own and reached the 25x luck cap within a day or two of heavy rolling. Fusion Trait Shards and XP went too:
  a fusion's whole reward is the card at the next border (4x stats).

- [ ] **IP before publishing (blocking).** The private prototype now uses real anime characters well beyond the
  card names: card art drawn from named characters (`docs/CARD_CONVERSION.md`, `art/cards/*/manifest.json`), the
  boss models in `assets/models/bosses-20261027/` (Kurama, Golden Frieza, Madara's Susanoo, Muzan), and series
  terms in ability / Support names (Chakra, Tailed Beast, Breathing forms, Eight Trigrams, Heavenly Restriction...).
  Before any public release, replace all three: original names, original art and original boss models. Roblox
  removes infringing games and assets, and repeat strikes can cost the account.

- [ ] **World 4 Nightmare is unwinnable (decide).** At 250,000,000 HP (2026-10-30) the strongest deck in the game,
  four Secret Blood Moon cards, deals about 169M in the 180 s limit (~203M with the Blood Moon +20%). Pick one: lower
  its HP to ~120M (that deck wins in ~2 min), raise `Config.Battle.TimeLimit` for it, or keep it as an aspiration.
- [ ] **New players can't clear World 1 Normal (decide).** The all-Base starter deck (31.5k) loses Kurogane Normal
  (250,000 HP) on time; the first clear needs about four Gold cards (115.7k). Kenji's path and the first boss-card
  unlock wait behind that. Consider ~60k HP for World 1 Normal or a starter Gold card.

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
  active product prices. Retired `ShardBundles` stay unavailable; preserve old receipt ids for compensation.
  Set every active `Price` to the dashboard price. Set `MockPurchases = false`.
- [ ] **code** `src/server/Codes.luau`: review the codes (`RELEASE`, `LUCKY`, `TOWER`, `SQUAD`, `TRAITS`, `AWAKEN` are
  the test set). Keep the launch ones, give time-limited ones an `Expires` (unix time).
- [ ] **code** `Config.DevUserIds`: empty it (it only matters while TestMode is on).
- [ ] Run the checks (type check, props check, headless tests: see CLAUDE.md > Commands) and commit.

## 3. Creator Dashboard

- [ ] Create the 4 game passes (Fast Roll, Auto Roll+, Triple Roll, VIP) with icons and prices.
- [ ] Create the active developer product: Server Luck Totem. Do not reopen retired Shard bundle sales.
- [ ] **Experience Questionnaire / maturity**: answer the **paid random items** questions truthfully (VIP luck, Auto Roll+
  perfect surges, Triple Roll and the Totem change odds). The game already hides those perks where
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

- [ ] Real-time battle pass (2026-10-30, headless only): play a World 1 Normal fight at 1x and 2x. Check:
  - Fast / Balanced / Heavy Basic, Skill and Ultimate animations; full cards hovering; hit flash / shake.
  - The CLASH ring appears when a big move lands, a tap and Space both work, and Space doesn't make the
    character jump. A HIDE BATTLE mid-window leaves Space free.
  - Muted 🛡 numbers while the Shield stands, big gold ones after the shatter; SHIELD BROKEN banner.
  - HOLD · BREAK on full cards above 60% Shield, then the 0.5 s Ultimate chain; AUTO ULT / HOLD toggles save.
  - Guard link beams in the Arena (and that they fade when a guard falls); five left-hand buttons on phone.
  - Feel: fights now open with every card attacking; Recommended ratings dropped (World 1 Normal 70.1k).

- [x] Sky tiers / bulk packs / reveal settings / claim-all (2026-10-30): live Base Yhwach1595 > Gojo1449,
  with Blood Moon1600-1760; all same-rarity normal / boss comparisons and story / tower fixtures pass.
  Actual Secret showcase label matches Borders.Secret gradient. SETTINGS minimum / Pack Flip vs Cinematic /
  duplicate options inspected; controlled Secret+ / new-only pack preview played one eligible full manual
  reveal, skipped the duplicate Secret / new Rainbow and reached grouped summary. Saved-pref migration /
  malformed preference repair tested. BAG has USE ALL on owned pack tiles and details; claim-all visible
  on DAILY & GIFTS. Real server copied-profile opening:1001 ten-card packs ->1000+1 bounded chunks /
  10010 cards /54 unique receipt groups, original restored. Real client USE ALL loop with mock receipts
  crosses10000 and Stop preserves remaining packs. Copied-profile ClaimAll pays all9 milestones once;
  controlled Kenji readiness pays6 consecutive steps then zero. Sigil Eclipse->Rain->Eclipse succeeds
  immediately, consumes the right items, cooldown0. Temporary profiles / functions restored; no test grants
  saved. Required checks passed. Existing203785492 asset-type warning remains unrelated.
- [ ] Ordinary-play review: USE ALL with a larger real pile, progress / Stop / leaving BAG / reconnect
  during a chunk; real Secret+ and New Only / Include Copies choices across rejoin, manual / Auto / packs;
  Pack Flip / Cinematic on phone; repeated sigil use / Hourglass; claim-all with real playtime gifts,
  quest completion caused by those gifts and Index rewards. Final Secret violet / white appearance and
  all four sky stat tiers need user preference review. No place was published.

- [x] Semantic UI / sky rarity pass (2026-10-29): desktop SQUAD / TRAINING / CARD PACKS and Demon
  Progenitor's full sheet inspected. Dark slate windows, blue navigation, red Attack / DMG, green
  Support / HP / luck; red sword / green heart images visibly loaded, small pills / trait tags readable.
  Compact inspector / card faces / collection section have fewer repeated labels and no card emojis.
  All four Limitbreak HUD slots show dark ? / ??? / base rarity without ownership; client-only Broly
  discovery immediately loads only his portrait / name. Original client state restored. Server reports
  Limitbreak 600 / 750 / 800 / 1000 and 1250 / 1287 / 1298 / 1336 Base ATK. Controlled, non-yielding
  profile-copy pack check: 100 ten-card packs -> 1000 normal + one forced sky find; immediate second
  opening -> zero sky finds / no second search. Original profile and picker restored. Natural sky
  eligibility, all-card rarity / relative stats, 500k sampled searches per sky, battle / tower fixtures
  and all required checks pass. Existing asset-type warning 203785492 remains unrelated.
- [ ] User review: semantic colors across BAG / fights / results, hover / collection sheet scrolling,
  narrow-screen stat icon / number fit, unknown -> real sky discovery after an ordinary roll / rejoin,
  and ordinary luck / border / sky-find pacing. A bulk opening still gives all normal pulls but shares
  one sky search per second with ROLL / AUTO. Review scarcity over multiple natural / summoned skies.

- [x] Tower / UI / DEV pass (2026-10-29): existing 22-floor Studio Assistant tower refined and exported,
  original backed up; 52.7-stud base / curved roofs / timber / windows / gables / embers inspected in Studio.
  All parts anchored; named foundation-to-roof gaps <0.00002 studs. Entrance approach pathfinding succeeds
  with jumping allowed; actual F prompt opens the tower panel. Lobby ClockTime 14 -> entrance 0 -> lobby 14;
  radius 46, six nearby lantern lights, embers active. No old runtime duplicate tower. Exported Rojo template
  round-trip preserves sizes / colors / lanterns / prompt / particles. Real Tab expands and folds SERVER;
  expanded list moves the sky panel below it. TRAINING illustrations and expanded DEV controls inspected.
  Isolated-profile server checks: exact Gold copies, resources / packs, level / XP, timer reset, invalid ids /
  NaN, burst limit and TestMode-disabled rejection; original profile restored. Required checks all pass.
- [ ] User review: tower from ground level / long distance, steps / nearby trees, night boundary, streamed
  floors and mobile performance; restart / rejoin with the exported template in an older place. Review
  card labels, absence of element filters / diamond HUD, Tab while typing, DEV searching / scrolling /
  sky preview and ordinary grants. Save the open place for its scenery / original-model backups.

- [x] Celestial / collection redesign (2026-10-29): all 16 clothed event portraits loaded visibly through
  actual ImageLabels; desktop sky panel shows the anime, luck, four eligible portraits and countdown.
  iPhone 17 Pro landscape emulator (750 x 323 usable): read-only sky panel and bottom-right relic row
  clear the event / progress controls; BAG and CARD PACKS fit. SKY ITEMS shows six loaded illustrations,
  Orb odds and sigil crafting cost. Desktop worn-relic hover shows the actual bonus. Modal pop animation
  now refits after a device resize, fixing a full-size panel clipping outside the phone screen.
  Isolated-profile runtime checks: 1,000 ten-card packs consumed once -> 10,000 normal + 8 eligible sky
  cards, complete grouped receipt / five highlights; crafting spends 10 fragments, summon / one extension
  succeed, a second extension is rejected. Collection unlock / malformed / distance checks and both new
  remote rate limits reject invalid calls. Real profile restored; no fake rewards saved or announced.
  Preserved Studio Assistant's InfiniteTower night mood in source; its tower / zone marker remain in the place.
  SkyFx active LOW rate 3 -> 0 with BAG open -> 3 after close, checked on the actual client.
- [ ] Ordinary-play review after reconnecting Rojo: Card Packs keeper prompt / selecting and rejoining;
  roll / AUTO / packs use that pool, unlocked bosses stay eligible; all four natural sky transitions and
  forecasts across live servers; clothed art availability / crops; BAG summon / craft / Hourglass cooldown
  / banner; real-phone tapping status icons and long tooltips; LOW / crowded-server performance.
- [ ] Battle / progression review: familiar-column BONDED bonuses; ~8 s skills / 22 s minimum Ultimates
  at 1x; five-minute boss reward cooldown / PRACTICE with no XP, mastery or rewards; new-player starter pack,
  First Light title, neutral elements, 1-shard traits, old purchased bonuses / balance compensation on rejoin.
  Headless story fixtures win in ~74-76 s; player-deck / Corrupted boss feel still needs ordinary play.
- [ ] Studio Assistant tower integration: the place has `Workspace.InfiniteTower` with 22 floor models
  at a different position from the old Tower marker, without a ProximityPrompt. Existing runtime tower
  / entrance remain intact. Save the place, then decide which entrance should serve the new model before
  replacing / removing either tower. This pass preserved both and copied the new night mood into Git.

- [x] Quest / input follow-up (2026-10-29): verified Claude's Modal blocker with real desktop clicks:
  blank space in BAG, SQUAD and QUESTS stays open; QUESTS outside click closes it. Daily reward art,
  scrolled milestones (potions / hourglass / packs), GOALS page portraits / crown / live counts and
  a mixed HUD notification rendered in Studio. GOALS opens from the sidebar; its story button opens
  BATTLE and closes QUESTS. No real reward granted for the notification preview. Source synced by Rojo;
  temporary click probe / notification preview disappeared on Stop. Studio left Edit, no publish.
  Type 0 errors (four existing warnings), props 5,513 / 0 problems; full headless ALL CHECKS PASSED,
  including journey progression / legal challenge / completed milestone regressions.
- [ ] Ordinary-play touch review: blank-space taps, scroll / controls / close / outside taps, Kenji
  reward rows, long mixed notifications, all GOALS destinations and live progression updates. Desktop
  checks do not count as a real-phone pass. New content / guaranteed grind rewards are only proposed
  in docs/PROGRESSION_PLAN.md; this pass changes guidance and reward presentation, not payouts.

- [x] User-selected boss models (2026-10-27): all four actual ModelView portraits and Arena previews
  checked with existing guards: Kurama / Frieza / Susanoo / Muzan. Susanoo shell shading corrected;
  Muzan ground ray ignores the hidden world NPC, feet match terrain within idle bob. One real Kurama
  Normal fight won in 26.8 s with the owner's strong deck; result / rewards appeared. New and archived
  BossKit assets contain zero scripts / GUI / remotes. Fresh runtime scans found no fake recovery GUI.
  Type check 0 errors, props 5,465 / 0 problems, full headless ALL CHECKS PASSED. Kit is now in Git / Rojo;
  Studio left Edit, nothing published. No combat tuning / names / saves changed.
- [ ] Review all four bosses in ordinary play, later difficulties / tower, phone and crowded streaming.
  Neon arena's existing foreground boulder can obscure the third guard; map adjustment remains separate.
  Cosmetic rigs use the existing arena motions; imported animation scripts were removed. Save the open
  place to retain sanitized source backups / removal of loose imports; a new full-place backup was not saved.

- [x] Endless tower / elements / bulk packs (2026-10-27): 80-story ~1,600-stud skyline with local cloud
  bank / mist, Torii / cyan runes / doorway vortex; five-story streaming sections, lower skyline Persistent.
  Combined saved map + runtime parts about 12.2k. Four real R15 service rigs build and all four have one
  looping idle track. Restored floating Neon Abyss title visibly readable across town, 600-stud destinations;
  26 px crimson sidebar badges show crisp 9+. Six actual ElementUi icons visibly loaded / IsLoaded=true.
  Isolated real server OpenPacks call: 100 ten-card packs → 1,000 pulls, 40 stacks summing to 1,000,
  five sorted highlights, all test packs consumed; original profile untouched. Same receipt checked in
  normal BAG cover: readable scrollable stacks / DONE visible / rendered quantities sum to 1,000.
  Checks: type 0 errors, props 5,465 / 0, headless ALL CHECKS PASSED including new pack regressions.
- [ ] User review: tower from normal walking / zoomed-out views and other worlds; real-phone / crowded
  streaming cost, service outfits / idles, all doorway titles at distance, real owned-pack OPEN 1 / ALL /
  DONE / another batch, Rainbow / Secret first reveals and capped Mega-pack leftovers. Visual BAG preview
  used an isolated receipt without spending real packs. Temporary previews / upload server removed, Studio
  left Edit, final sources synced via Rojo, nothing published. Cards / bosses / combat / save format unchanged.

- [x] Town services / HUD art (2026-10-27): desktop Play checked Kenji / Hoshi / Kenshin / Fortuna,
  workbenches / lectern, wheel canopy, pagoda / steps / doorway and physical town / Ember portal plaques.
  Titles clear roofs; compact nameplates use nearby detail and collision suppression. All tagged signs
  disabled during the panel-hide smoke check. F prompts retain service ids / 16-stud range; actual
  server NpcRange accepts nearby and rejects far positions for fusion / traits / fortune. Ten new HUD
  images load; opaque currency chips hide world text behind them. A live Normal win displays BAG pack
  artwork / short hint / new currency icons; existing buttons remain. Type 0 errors, props 5,397 / 0,
  headless ALL CHECKS PASSED. Runtime changes synced via Rojo; Studio left Edit; nothing published.
- [ ] User review at normal walking distance: service plates, all four gate approaches / portal backs,
  tower entry, wheel prompt, first-clear three-line card unlock and multi-pack / no-pack result variants.
  Real-phone and crowded streaming checks remain parked. Town additions rebuild at Play from source;
  the underlying saved town / terrain / original plaza polish still live in the place file.

- [x] Showcase / roll polish (2026-10-27): enlarged tilted card clears the back better; both faces glow,
  three emitters run at 18 / 35 / 25 with a brightness-3 light, tier / name / odds billboard displays,
  animated gradient rotates. LOW total rate is 19.5/s with no showcase light; unequip removes the part.
  Copy / New / first-border badge flags checked; clean quick / full Gold roll and 12-card reward preview
  render with no role line / rarity pill / DUPE, two discovery badges and a first-clear footer.
- [ ] Review showcase aura on a real phone / crowded server, night lighting, large accessories, turning
  and respawn. Nearest-three light / rate budget is implemented but not multiplayer stress-tested.
  Reconnect Rojo: its socket disconnected during the pass; final changed reveal sources were synced
  directly to the open Studio place for verification. Studio left Edit; nothing published.

- [x] UI polish (2026-10-27): 17 BAG illustrations loaded visibly in the normal grid / detail;
  colored HUD menu checked. SQUAD text rows separated; MY PROFILE's 14 mini tiles have no name / rarity
  rectangle overlap. Quick rolls appear on the right; flex card is at root-local (2.2, 1.6, 3.0), with
  a real particle emitter; unequip cleanup verified. No new runtime errors.
- [ ] Check this polish on a real phone: mini names / rarity, colored navigation, BAG tile / detail icons,
  and running / turning / respawning while the showcase is equipped. No new artwork for Speed Potion;
  it retains its previous marker (the requested list contained the other 17 items).

- [x] Glossy vector UI (2026-10-27): Studio startup, HUD, SQUAD / card vault and BAG checked visually;
  tab labels remain readable above glossy fills. Visible rare borders rotate and hidden ones pause.
- [ ] Review the glossy windows / buttons / card borders on phone, STORE, reveals and live battles;
  confirm selected / disabled buttons remain clear and tooltips stay readable. No gameplay tuning changed.

- [x] Approved Support art (2026-10-27): all 11 actual CardTile illustrations visibly rendered and reported
  IsLoaded; all 11 full CardView portrait crops checked. Normal SQUAD Support tab and saved Support slots show
  the relic art. Sources / prompts / hashes / asset ids are in `art/cards/support-20261027/`. Code checks pass.
- [ ] User review: new Support art in ordinary reveals / battle pods and on a real phone. Studio left in
  Edit, temporary art galleries / upload servers removed, source synced via Rojo; nothing published.

- [ ] Character / relic conversion (2026-10-27): restart Play so the save migration runs. Confirm all 11
  former Support characters are in ATTACK with HP / speed / Basic / Skill / Passive / Ultimate and original
  portraits; their relic replacements are in SUPPORT with no HP / action bar. Existing borders, copies,
  traits, Mastery and Support positions in every preset should survive. Try character bonds, AUTO-BUILD,
  reading skills during Auto Roll, and a real battle. Studio reported no place open, so these visual / live
  checks could not run during the conversion pass. The approved art pass subsequently checked SQUAD's
  separate Support tab / saved slots and all artwork; exhaustive real-profile and live combat checks remain.
  All 11 Support illustrations are now uploaded / wired. See `docs/CARD_CONVERSION.md`.

- [x] Mastery / exploration / UI pass (2026-10-26): separate ATTACK and SUPPORT vault tabs; Support-only
  contents checked. Hover tooltip remained open through multiple Auto Rolls and closed with SQUAD. Clean
  panels / text navigation replace the ornate atlases; original art files and all card / boss names remain.
- [x] Live baseline 25.4k starter fight: hidden at 73% leader HP, normal camera and character streaming focus
  restored; character moved while the server fight continued. Returning restored the cinematic camera and
  the current fight state. Win awarded one mastery mark with the card still at one copy.
- [x] Auto Trait checked beside Kenshin using an isolated test deck / wallet: repeated capped batches continued
  until funds ran out; a selected trait applied on success; Stop finished one batch without starting another.
  Original cards / decks / traits / shards / settings restored afterward. No new runtime errors in those checks.
- [x] World labels: destination range 140 studs, NPC range 90, larger NPC plates, fade only over final 20%.
  Final Studio instance reported both ranges. All 12 guard models / classic Roblox faces built successfully.
- [x] Required checks: type check 0 errors (existing warnings); UI properties 5,555 / 0 problems; headless ALL
  CHECKS PASSED. All 12 story fixtures win 100%, median 61.4–79.2 s; tower / Pagoda / raids also pass.
- [ ] User review: Mastery sheet at 1 / 3 / 6 / 10 different story challenges, separate card tabs, Auto Trait
  run totals / Stop, hidden auto-climb / retry, signs at distance and faction guards in normal play. Phone work
  stays parked. Source is synced through Rojo; not published. Existing BossKit leader models still predate
  the current card names / artwork; they were preserved, not silently replaced.

- [x] Cohesive card art (2026-10-26): all 26 illustrations visibly rendered in a temporary actual-CardTile
  gallery; SQUAD and full Limitless Sage portrait crop checked in Studio, no new client runtime errors.
  All sources are distinct 1254 x 1254 PNGs. Asset ids / old ids / hashes are in the art manifest.
- [ ] User artwork review: SQUAD / INDEX, reveals and battle pods. Check faces through the existing portrait
  crops. Sources are in `art/cards/cohesive-20261026/`; art is synced through Rojo, not published.

- [x] Authored card kits / tooltip pass (2026-10-26): desktop Crimson Chakra Cloak sheet shows 85% return / 25%
  DMG cost and a drawn-check Activation Limit pill. Collection data collapses / expands. Attack hover card shows
  authored Basic / Skill / Passive / Ultimate with only percentages and turn counts highlighted. Five-technique
  tooltip preview was constrained to 300 px and scrolled to Y=100 (canvas 622 px). One live Hard fight starts and
  runs with new technique names / passive status and no new runtime errors. Headless verifies trigger costs,
  reflected Freeze / Burn, Bleed, healing locks, chance bundles / limits and every border / Copy bonus's copy.
- [ ] User review: Nine-Tails Sovereign's Crimson Chakra Cloak, Dream Reaper's Illusion of Crows, Titan Warder's
  Armored Advance cost, hover / battle inspection and COLLECTION & BONUSES. Check the new HEAL BLOCK badge during
  a longer fight. Source is synced through Rojo; not published. Real-device review remains parked.

- [x] Passive Support pass (2026-10-26): desktop Gold Support sheet shows the paired effect, actual percentage,
  Copy bonus and per-battle limit. Live Normal fight shows Attack / Skill seconds and passive use counts;
  Support pods have no action / energy / HP bars. Results show passive triggers / applied bonuses instead of
  fake healing scores. No new runtime errors. Headless: all 12 boss fixtures 99-100% wins, 71.5-76.5 s medians;
  tower / Pagoda / raid tests and passive-limit regressions pass. No names, art, ownership or save format changed.
- [ ] User review: pair a Support with the same numbered attacker, inspect its effect / border strength, and try
  a fight near the new ATTACK RATING recommendation. Review the limited healing / survival feel. Fixed last-stand
  and cleanse effects have the same trigger limit at every border. Source synced through Rojo; not published.

- [x] Card clarity / support borders (2026-10-26): desktop SQUAD shows Attack damage / HP, concrete Support effects,
  type labels and numbered pairs. VIEW SKILLS opens the selected border's scrollable sheet; BACK TO CARDS works.
  Copy bonus replaces unexplained stars; advanced traits / Awakening remain in details. Live battle starts without
  new runtime errors. StoreState / missing currency startup error fixed and absent on fresh Play.
- [ ] User review: AUTO-BUILD, inspect without changing the deck, EQUIP / REMOVE, a Gold Support's passive strength /
  trigger limits, skill-sheet scrolling and the battle skill popup. Real iPhone check remains parked.
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

- [ ] Rarity / bulk-pack / boss pass (2026-10-30): USE ALL on 100 Mega Packs finishes in about a second with one
  summary; during a sky, opening packs gives sky cards in proportion; chat shows a line for a 1-in-10M+ pull and the
  BILLION PULL line for 1-in-1B+; the new card stats, Eight Trigrams 55-100%, and each boss at its recommended deck.

## 6. Smoke test on the live game (first hour)

- [ ] Join on PC and on a phone: title screen, HUD, roll, Auto Roll, a reveal, the Index.
- [ ] Leave and rejoin: cards, Shards, deck and settings are still there (live saves).
- [ ] Buy one pass with a real account (or a friend's): the perk works at once and after a rejoin.
- [ ] Beat Kurogane Normal: rewards, the boss card unlock banner, the tower opening.
- [ ] Wait for :30: a raid opens for the server.
- [ ] Check the server output for errors (Developer Console, F9).
