# Handoff between AI sessions

Shared by Claude Code and ChatGPT (Codex); see `AGENTS.md`. Read this first and update it last.

**Branch:** `claude/brave-franklin-kkqlyz` (all work goes here until the user says otherwise)

**Status:** IDLE
<!-- While working, set it to: IN PROGRESS: <who>, <date>, <what> -->

## Next up (the user's open asks, newest first)

- User review of the completed 26-card AI artwork set: all cards now have matching illustrations, uploaded and
  connected in `Cards.ART`. Sources / prompts / hashes / asset ids / previous five ids are in
  `art/cards/cohesive-20261026/`. All PNGs are 1254 x 1254; card frames crop them. Desktop Studio showed all 26
  actual CardTile components and the full Limitless Sage portrait. Review reveals and battle pods next.
  Same five represented anime inspirations; no new franchises added. Names, kits and saves kept. Not published.

- User review of the authored card-kit overhaul: SQUAD > select a card > VIEW SKILLS / BONUSES. All 26 cards
  have authored ability names / mechanical copy; no job boilerplate, paired-only preface, auto-action reminder or
  stagger diagnostics. Each passive mixes a trigger with a cost or status / RNG mechanic. Actual percentage
  strengths round to multiples of 5, including scaled Support values. Activation Limit / Effect Cap pills replace
  limit paragraphs. The skill sheet collapses collection data under COLLECTION & BONUSES; hover cards scroll.
  Try Nine-Tails Sovereign's Crimson Chakra Cloak, Dream Reaper's Illusion of Crows and Titan Warder's entry cost.
  All 4+4 slots, card / boss names, ids, art and save format remain. Studio source is synced through Rojo, not
  published. Review the costs / effects during a longer fight, including HEAL BLOCK; real-device play is parked.
- User review of the existing-town polish, applied in the actual place (not a concept): fountain border,
  service paving, benches / planters, roomier NPC / stall positions and a jade-and-slate tower set northwest.
  Local saved place: `studio-local/AnimeCardRoll-TownPolish-20261026.rbxl` (ignored by Git; verified it contains
  the geometry / markers / backup). The currently open cloud place also has the edits, but they are NOT published.
  Map changes do not travel through Rojo / git pull: use that local copy or apply `tools/studio/town-polish.luau`
  to the original map and save from Studio. Do not use `rojo build`. Cloudspire / a replacement world were NOT
  approved; the user rejected the concepts and chose to improve the current town. Replacement UI themes are parked;
  the later card / support clarity request is implemented above.
- User review of the implemented illustrated UI kit: gold icon menu, lacquer panels, vermilion buttons,
  Gotham typography, BAG emblems and matching battle intro / controls. The user asked to put phone work aside
  and implement the visual concept. Source art / prompts / asset ids: `art/ui/occult/README.md`.
- Parked: real iPhone check after the screenshot readability pass (`docs/LAUNCH_CHECKLIST.md` section 5): HUD, larger
  vault / BAG tiles, selected-card inspector, fixed guard targets / focus, 2x AUTO CLIMB, and DASH restored in town.
  Studio's iPhone 14 landscape emulator was checked; the user has not seen these latest changes on their phone.
- Town brightness confirmed by the user on 2026-10-26. Check the per-world lighting in Studio.
  Each world's values are the `MOODS` table in
  `src/client/ZoneFx.luau`, and the town's are in `src/client/LightingSetup.luau`. Run
  `tools/studio/lighting.luau` once in Studio and save.

## Log (newest first)

Each entry: date · who · commit · what changed · what's left or unsure.

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
