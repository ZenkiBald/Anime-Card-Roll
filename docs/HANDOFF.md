# Handoff between AI sessions

Shared by Claude Code and ChatGPT (Codex); see `AGENTS.md`. Read this first and update it last.

**Branch:** `claude/brave-franklin-kkqlyz` (all work goes here until the user says otherwise)

**Status:** IDLE
<!-- While working, set it to: IN PROGRESS: <who>, <date>, <what> -->

## Next up (the user's open asks, newest first)

- NEW (2026-10-27): converted all 11 character Supports to Attack cards, keeping original names / ids /
  portraits. Added 11 separate relic / technique Supports with the previous passive math. The pool is 37 cards
  (33 before boss unlocks). Idempotent migration preserves characters and grants replacement Supports with
  independent copies of their old collection / traits / Mastery; every preset Support position maps to the relic.
  See `docs/CARD_CONVERSION.md`. Rejoin / restart Play after syncing so the migration runs.
- SUPPORT ART COMPLETE (2026-10-27): user approved the three examples; all 11 are now uploaded / wired.
  Sources, asset ids, hashes and exact production / preview prompts are in `art/cards/support-20261027/`.
  All 11 actual tiles / full cards loaded visibly in Studio; normal SQUAD Support art and saved slots checked.
  Review reveals / battle pods in ordinary play. Studio left Edit, source synced via Rojo, nothing published.
- The previous conversion pass had no Studio place open. This art pass checked the separate vault and saved
  Support presentation, but did not repeat live combat or exhaustively audit real-profile migration fields.
  Headless migration / combat checks pass; remaining ordinary-play checks are in checklist section 5.

- User review of the completed mastery / exploration pass: SQUAD has separate ATTACK / SUPPORT tabs above
  CARD VAULT. Copy stat bonuses and copy Awakening are gone; duplicates are for border fusion. Win different
  story boss difficulties with each card to earn Mastery at 1 / 3 / 6 / 10 challenges. SEE VIEW SKILLS / MASTERY.
  Existing collections and second trait slots are preserved. Review the progression pace and enemy team choices.
- Auto Roll no longer rebuilds the whole open vault or interrupts it with reveals. Tiles are cached; grid
  insertion / sorting waits while reading a hover tooltip. Check selection, scroll, filters and new-border pulls.
- HIDE BATTLE lets you explore while the server fights. RETURN TO BATTLE shows HP / time, then VIEW RESULT.
  Hidden auto-climb / retry remains hidden. Review long runs / milestone results; no second concurrent fight.
- Auto Trait now runs successive bounded batches until a selected target, Stop, closing, insufficient shards
  or leaving Kenshin. Stop finishes the current batch; cumulative roll / cost totals are shown. Supports' traits,
  foil and mastery now affect their supported attacker. Recheck the new behavior during ordinary play.
- UI image atlases are disabled (archived, not deleted): clean panels, text menu and restrained markers let
  the 26 illustrations lead. Labels reach 140 studs for destinations / 90 for NPCs, fading only at the edge.
- Enemy guards now have distinct faction / role models, names and themed moves. Ember follows its current
  Itachi-like 3D leader with a Crimson-Eye clan retinue; the other existing fantasy leaders have Frost / Void /
  Storm Courts. IMPORTANT: BossKit leader models still predate the new card names / art. That mismatch needs
  a separate leader-art decision; no card / boss names or leader models were silently replaced in this pass.
- All 26 card illustrations remain in `art/cards/cohesive-20261026/` with prompts, hashes, ids and old ids.
  Review reveals and battle pods. The old five portrait PNGs remain untouched.
- Town polish is still place-only, not published: `studio-local/AnimeCardRoll-TownPolish-20261026.rbxl`, or
  `tools/studio/town-polish.luau` applied to the original map. Map changes do not travel through Git / Rojo.
  Reconnect Rojo when opening that local copy, since its stored scripts predate these source changes.
- Parked: real iPhone review. Town brightness was confirmed; per-world lighting remains worth checking.

## Log (newest first)

Each entry: date · who · commit · what changed · what's left or unsure.

- 2026-10-27 · Codex · this commit · Completed the production prompt archive after the artwork push:
  generation-plan.json now includes all eight exact prompts, source paths and card ids. No image or code
  changes. Required checks rerun successfully: type 0 errors, props 5,565 / 0, headless ALL CHECKS PASSED.

- 2026-10-27 · Codex · bb15483 · Finished the approved Support artwork batch. Kept the exact three
  approved previews and generated eight matching illustrations with built-in imagegen; no extra character
  series. Relics / seals / techniques / close-up hands, no complete characters or faces. Cleaned stray borrowed
  symbols from Binding Blood Vow and a tiny signature-like mark from Eight Trigrams Seal via imagegen edits.
  Saved 11 distinct 1254 x 1254 PNGs, hashes, uploaded ids, approved preview / production / cleanup prompts under
  art/cards/support-20261027. All uploaded to the game's owner and connected only through Cards.ART; character
  art / names, combat, odds and saves unchanged. Checks: type 0 errors (existing warnings), props 5,565 / 0,
  headless ALL CHECKS PASSED. Studio: all 11 actual CardTile images visibly loaded and reported IsLoaded;
  all 11 full CardView portrait crops checked in two galleries, then normal SQUAD Support tab / saved Support
  slots displayed the new art. No new product runtime errors; existing sound asset warning persists, and a
  temporary self-destroying preview helper produced a parent-cleanup warning. Gallery / helper removed with
  Play stop; Studio left Edit. Both temporary localhost upload servers stopped. Source synced through Rojo,
  not published. User review of normal reveals / battle pods remains; unrelated .codex / five root PNGs untouched.

- 2026-10-27 · Codex · this commit · Converted the 11 former character Supports into independent Attack cards
  with real stats, Basic / Skill / triggered Passive / Ultimate. Preserved every existing card / boss name,
  character id / portrait / leaderboard list position; followed the approved 26-art inspirations where Gemini's
  reference table conflicted (Toji, Minato, Sasori, Fourth Raikage). Appended 11 relic / technique Supports,
  retaining old Support math / weights / elements; roll chances recalculate across 37 cards, border odds unchanged.
  One-time SupportRelicsVersion migration deep-copies each owned former Support to its replacement, keeping the
  character too; remaps all preset and legacy Support positions without changing Attack lineups / active preset.
  Existing replacement entries are never overwritten. Deck.Clean now clears wrong-type stale slots. Supports
  without approved art show monograms instead of character busts. New kits use existing server effect handlers,
  clean 5-point percentages, bounded passives and truthful status descriptions. Character bonds require the
  characters, not their new relics. Updated fixture Support ids and bond coverage; fixed chase fixture helper
  ignoring its explicitly requested Mastery (story fixtures still use previous challenge clears). No boss tuning.
  Added save independence / preserved collection / presets / repeat-load cases and live engine checks for all
  11 Basic / Skill / Ultimate kits, 26 Attack / 11 Support pool, Attack-only viability, entry charge, cloak healing
  lock and follow-up limits. Required checks: type 0 errors (existing warnings), props 5,565 / 0 problems,
  headless ALL CHECKS PASSED; 12 story fixtures 100% wins, 61.4–81.4 s medians; towers / Pagoda / raids pass.
  Studio MCP lists an instance but reports no place open: NO Studio visual / live verification ran; no place
  modified or published. Generated three reviewed local Support art examples with built-in imagegen, matching
  relic / seal composition without character faces; all 1254 x 1254. Images / exact prompts remain ignored in
  studio-local pending USER APPROVAL, no upload / asset ids / art wiring / image commit. Remaining eight not
  generated. Updated CLAUDE / conversion map / launch checks. Unrelated .codex and five root PNGs untouched.

- 2026-10-26 · Codex · this commit · Completed the approved progression / team / UI / exploration plan plus
  separate ATTACK / SUPPORT vault tabs and Auto Trait investigation. Retired duplicate stat bonuses and copy
  Awakening; fusion remains 100:1. Server-owned per-card Mastery marks use distinct story fight keys: 1 / 3 / 6 /
  10 challenges give 5% speed / 10% Skill+Ultimate / 350% bond / trait slot 2. Repeats, losses, unpaired Supports,
  towers and raids grant none. Idempotent save migration clears legacy copy strength, preserves existing second
  trait access (including old fusion unlocks), collections and presets. Mastery never multiplies base stats.
  Retuned story HP / ATK / recommendations and one raid pool factor; fixtures use no star bonus and earned
  mastery. Supports now pass traits / foil / mastery effects to the supported card, fixing previously inert
  Support traits. Auto Trait continues capped server batches, with Stop / close / funds / range handling and
  cumulative costs; all Trait actions rate-limit, target lists are bounded, old trait stays on a miss.
  Cached vault tiles preserve reading during Auto Roll; topology waits while a tooltip is open; panels mute
  auto reveals. Formation slot selects its matching vault tab. Removed ornate UI atlases in favor of clean
  panels / text navigation; kept all original image files, card / boss names, ids and kits. Added hide / return
  battle view with HP / time / result widget, normal movement / dash / zone effects and character streaming
  focus; server combat and hidden chaining continue. Distinct clan / court guard models replace boss clones,
  with their model portraits in battle; guard ids / combat roles kept. Signs now 140 / 90 studs with larger NPC
  plates and edge-only fading. Existing BossKit leader / card-art mismatch documented rather than overwritten.
  Checks: type 0 errors (existing warnings), props 5,555 / 0, headless ALL CHECKS PASSED; all 12 story fixtures
  100% wins / 61.4–79.2 s medians, towers / Pagoda / raids pass. Added migration, no-copy-stats, unique mastery
  and Support trait routing regressions. Studio: both tabs / Support-only contents; stable hover across rolls;
  normal camera / streaming / movement while hidden and cinematic restore; baseline live win awarded 1 mark at
  1 copy; Auto Trait no-hit continuation / success / Stop tested with a temporary wallet; original profile fields
  restored before stopping Play. Final guard models / classic faces built, 140 / 90 label ranges checked, no new
  product runtime errors. Studio left in Edit, synced through Rojo, not published. User review remains above.
  Unrelated untracked .codex and five original root PNGs left alone. Pull and reconnect Rojo before next session.

- 2026-10-26 · Codex · this commit · Completed the approved cohesive AI artwork batch: 26 distinct square
  1254 x 1254 PNGs, including the three approved previews and new matching versions of the previous five portraits.
  Uploaded every image to the game's owner through Studio; changed only Cards.ART in gameplay sources. Old five
  root PNGs remain untouched and previous ids are recorded in the manifest. Full production prompts, file hashes,
  dimensions and new asset ids are saved beside the images. User said choose fitting inspirations without adding
  many anime: retained Naruto / JJK / Demon Slayer / Dragon Ball / Bleach only. No identity / stat / save changes.
  Type check 0 errors (existing warnings); props 5,530 / 0 problems; headless ALL CHECKS PASSED. Studio: all 26
  illustrations visibly rendered in a temporary actual-CardTile gallery; SQUAD and full Limitless Sage portrait
  crop checked, no new client runtime errors. PreloadAsync / IsLoaded queries reported failures even for visibly
  rendered old and new images, so visual capture was used as evidence, not those API flags. Temporary UI removed
  by stopping Play; Studio left in Edit. Source synced through Rojo, not published. User review of reveals /
  battle pods remains. Phone work stays parked. Git pull and reconnect Rojo before the next session.

- 2026-10-26 · Codex · this commit · Rewrote all 26 cards' technique names / descriptions in the user's requested
  style. Authored templates resolve effect values directly; no debug-job / auto-action / paired-only / stagger
  text, ordinary-number highlighting or limit prose. Shared ability rows provide Activation Limit / Effect Cap
  pills with a drawn check. Tooltip is dark, bounded and scrollable; full skill sheet collapses collection data.
  Every passive / Aura / Signature / Support now combines a trigger with a cost or status / RNG. Generic Attack
  bundles handle entry / hit / crit / kill / action / below-half triggers, chances and caps. Supports include
  counterstrikes, entry bargains, Crows / Black Flames, reflected statuses, kill-heal costs, 85% HP Chakra revival
  for -25% DMG / no further healing, and capped chance-based draining. Server percentage scaling rounds to 5-point
  steps; text uses that same value. Added distinct Bleed / reflected enemy Freeze and HEAL BLOCK status. Healing
  locks cover every HP-heal route; posthumous damage cannot heal a dead card. Reactive cleansing cancels other
  simultaneous Burn ticks. Card / boss identities, art, stats / weights, ownership / presets and save schema kept.
  Type check: 0 errors (existing warnings); props: 5,530 / 0 problems; headless: ALL CHECKS PASSED, all 12 bosses
  100% wins / 73.8-88.7 s medians, tower / Pagoda / raids pass. New regressions cover all copy / border text,
  two-mechanic passives, live chances / costs / caps, multi-hit triggers, Bleed, Freeze and simultaneous cleansing.
  Desktop Studio: cloak sheet / limit badge, collection toggle, Attack tooltip, bounded five-technique preview /
  scrolling, and a live Hard fight; no new runtime errors. Studio left in Edit; not published. User review of
  ability feel and the HEAL BLOCK badge in a longer fight remains; real-device work stays parked. Town local
  place still predates current scripts: reconnect Rojo when opening it. User untracked art / .codex left alone.

- 2026-10-26 · Codex · 41ac30b · Made all 11 Supports paired passive modifiers, following the user's
  correction: no damage, HP, action bar, active Skill / Ultimate or repeated team healing. Kept 4 Attack + 4 Support,
  names / ids / art, ownership and presets. Added bounded emergency heal, opening shield, dodge, speed, crit,
  guard, starting energy, weakening, two cleanses, one fatal-hit survival and capped lifesteal. Percentages use
  the selected border / Copy bonus / Awakening; triggers and healing caps stay fixed. ATTACK RATING counts only
  attackers; AUTO-BUILD ranks passive cards separately. Retuned all bosses and tower curves; raids remain viable.
  Attack / Skill countdowns now show seconds; Support chips show passive status / uses; results report triggers,
  dodges or applied bonuses. Shared descriptions / tooltips / fusion / Kenji explain the new rules. No save format
  change. Type check 0 errors (existing warnings), props 5,498 / 0 problems, headless ALL CHECKS PASSED: all 12
  bosses 99-100% wins, median 71.5-76.5 s; tower / Pagoda / raids and passive bounds / Attack-only viability pass.
  Desktop Studio: Gold Lotus Blossom sheet, real Normal fight, attacker countdowns, no Support action bars,
  passive results and no new runtime errors. Owned deck / presets were not edited. Studio left in Edit; not published.
  User feedback on the passive effects / balance and real-device play remain unverified. Town local copy still
  predates these scripts: reconnect Rojo when opening it.

- 2026-10-26 · Codex · 039ef31 · Simplified cards / deck play using the user's references for clarity:
  Attack damage / HP, concrete Support effects, plain type labels, numbered pairs, TEAM RATING estimate, explicit
  EQUIP / REMOVE (vault taps only inspect), and a VIEW SKILLS / BONUSES sheet with a real Back button. Shared
  CardInfo resolves readable values from the effects / border formulas; used in tooltips, full cards, Index,
  reveals, fusion and battle skill info. Removed unexplained stars / Awakening pips from card faces; Copy bonus
  explains the existing first-five-dupes stat bonus, traits / Awakening still in details. No names / art ids / save
  fields changed. Server now scales Support buffs / debuffs / Slot Links gently by border (1 / 1.25 / 1.5 / 1.75x),
  leaving durations / energy grants / shared synergies / Attack percentages alone. Vex Normal HP 756k -> 790k to
  keep its fixture in range (63.1 s median). Fixed early StoreState / HUD refresh race. Type check 0 errors (existing
  warnings), props 5,491 checked / 0 problems, headless ALL CHECKS PASSED including battle / tower tuning and new
  support tests for all border heals / shields / boosts / links, debuff scaling and player-facing text.
  Desktop Studio: card selection, skill sheet / Back, repeated inspection leaves saved deck unchanged, no star /
  Awakening pips on vault cards, no new runtime errors, fresh startup no currency error; one live battle started
  without errors. Test-clicked Lotus Blossom slot restored to its original state. Studio left in Edit; not published.
  User comprehension, all touch actions, fusion interaction and the resized battle skill popup still need review.
- 2026-10-26 · Codex · 331d0a4 · Polished the existing spawn town in Studio: restrained fountain materials,
  thin stone border / service approaches, two wood benches with flower planters, moved the three existing stalls,
  explicit Sage / Fusion / TraitMaster / Wheel / Tower markers and a clearer leaderboard position. Tower palette
  is jade / slate with non-neon bands (door / crystal keep their glow). Reproducible edit script has one-run guard
  and original fountain / stalls / markers backup in `ServerStorage.TownPolishBackup_20261026`; prior World source
  is also stored there. Real Edit / Play previews checked; five no-jump paths from spawn succeed; actual game-script
  NpcRange checks accept near / reject far for Hoshi, Kenshin and Fortuna. Map has 10,137 parts. Local place saved
  and its contents verified; Studio left in Edit. No publishing, UI changes, renames, save or gameplay changes.
  Type check 0 errors (existing warnings); 5,505 props checked, 0 problems; headless ALL CHECKS PASSED.
  Re-running map polish does nothing, as expected. User ground-level view / actual prompt actions remain to check;
  existing HUD startup error recorded above. Leave the user's untracked card PNGs and `.codex/` alone.
- 2026-10-26 · Claude Code · this commit · Card art wiring: the game only draws `Card.Image` (a Roblox asset id), so PNGs in
  `art/cards/` never showed. Added an `ART` id table at the bottom of `src/shared/Cards.luau` (all 0 until the user pastes ids);
  steps in `art/cards/README.md`. Also earlier this day (bosses hit back in Worlds 1-3, common cards got Skills) is in git log.
  Tests pass; not seen in Studio.
- 2026-10-26 · Claude Code · this commit · HUD polish on Codex's lacquer kit, from the user's desktop screenshot:
  ROLL is the one big button (AUTO / QUICK smaller toggles), the RECENT PULLS label only shows over pulls, MOUNT
  label no longer clipped, ODDS line bigger, Next Goal pill larger on desktop and pulses every 3 s while it can be
  done. Type check 0 errors, props 0 problems; not seen in Studio.
- 2026-10-26 · Codex · this commit · Implemented the approved visual concept in the real UI. Generated and uploaded
  four textures (navigation atlas, inventory atlas, lacquer panel, vermilion blossom button); source PNGs / prompts /
  ids in `art/ui/occult/README.md`, active wiring in `UI/UIArt` + `Skin`. Vertical gold-icon menu, small currency group,
  bottom-left XP / Next Goal on desktop, one-band Momentum / Surge, quiet Kenji tracker, matching shared panels,
  buttons, BAG emblems, battle controls / enemy tiles / smaller straight intro panels. Gotham type and subdued text
  shadows replace the thick cartoon lettering; ROLL uses Garamond. Fixed invisible filter chips (their background
  gradient was tinting button Text black); labels now draw above it. Server / saves / odds / battle tuning / names /
  character illustrations unchanged. Type check 0 errors (existing warnings); props 0 problems; headless ALL CHECKS
  PASSED. Desktop Studio: HUD, SQUAD, BAG and Hard / Nightmare battle UI checked, textures load, names / filter labels
  fit, no new runtime errors. Corrected atlas / slice coordinates for Roblox's 1024 px served images. Temporary upload
  server stopped; Studio returned to Edit. Nothing published. User visual review, remaining screens / interactions,
  actual-device sharpness / memory and live asset loading still need checking; phone work parked by user.
- 2026-10-26 · Codex · 3caef39 · iPhone screenshot polish: compact HUD and away reward toast, fewer routine
  duplicate pops, larger vault / BAG tiles with complete names, a phone inspector that collapses until selection,
  clearer deck thumbnails / names, fixed phone guard target rail, bounded damage floats, queued single callouts,
  Skill countdowns below names, no battle roll feed / DASH. Fixed raid banner TextButton.Text / label collision.
  Names, balance and server / save code unchanged. Type check: 0 errors (existing lint warnings); props: 0 problems;
  bundled headless tests: ALL CHECKS PASSED. Live Rojo sync confirmed. Studio iPhone 14 landscape: HUD, SQUAD, BAG
  and one Normal fight checked; 27 owned vault names and all current BAG names fit; no new runtime errors.
  Studio restored to Edit, device simulation off; nothing published. Real iPhone, focus taps, selected inspector,
  AUTO CLIMB transitions and DASH restoration still need checking. Known asset-id warnings predate this pass.
- 2026-10-26 · Codex · 89c297c · User confirmed "yeah its bright now"; recorded town
  brightness as checked in the launch checklist and current Studio status. Per-world transitions and phone layout
  still await feedback. No game code changed. Props: 0 problems; headless tests: ALL CHECKS PASSED.
  Type check not run: luau-lsp is not installed / available on PATH in this local session.
- 2026-10-26 · Claude Code · 7a46df3 · Phone layout. On short screens panels lay out at desktop size and
  scale down (`Modal.FitScale`); grids measure with `Kit.logicalSize`. The HUD, server list and quick
  roll pops hide while a panel is open. The top bar fits between Kenji's tracker and the server list,
  and the feed sits above DASH. Not seen on a phone yet.
- 2026-10-26 · Claude Code · cbb9bac · The town is a bright afternoon again. Each world has its own
  lighting (`ZoneFx` MOODS): Ember sunset, Frostfang snowy morning, Neon Abyss night, Stormspire storm.
  Not seen in Studio yet.
- 2026-10-26 · Claude Code · 2b9d9ee · Combat rhythm and threat:
  - Gauges start staggered, one action per tick.
  - A MinHit floor so bosses always hurt.
  - SKILL in N on cards, and the boss's next move shown.
- 2026-10-26 · Claude Code · 835c934 · Pacing:
  - AUTO-RETRY / AUTO CLIMB quick chain, and tower sweep of easy floors.
  - Falling enemies and the SCOUT unit cards.
- Before that: see `git log` (one commit per pass).
