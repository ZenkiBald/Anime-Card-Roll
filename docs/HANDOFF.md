# Handoff between AI sessions

Shared by Claude Code and ChatGPT (Codex); see `AGENTS.md`. Read this first and update it last.

**Branch:** `claude/brave-franklin-kkqlyz` (all work goes here until the user says otherwise)

**Status:** IDLE
<!-- While working, set it to: IN PROGRESS: <who>, <date>, <what> -->

## Next up (the user's open asks, newest first)

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
