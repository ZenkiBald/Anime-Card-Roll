# Handoff between AI sessions

Shared by Claude Code and ChatGPT (Codex); see `AGENTS.md`. Read this first and update it last.

**Branch:** `claude/brave-franklin-kkqlyz` (all work goes here until the user says otherwise)

**Status:** IDLE
<!-- While working, set it to: IN PROGRESS: <who>, <date>, <what> -->

## Next up (the user's open asks, newest first)

- Phone check of the 2026-10-26 layout pass (`docs/LAUNCH_CHECKLIST.md` section 5): if panel text is too
  small, the scale is `Modal.FitScale` in `src/client/UI/Modal.luau`.
- Check the per-world lighting in Studio. Each world's values are the `MOODS` table in
  `src/client/ZoneFx.luau`, and the town's are in `src/client/LightingSetup.luau`. Run
  `tools/studio/lighting.luau` once in Studio and save.

## Log (newest first)

Each entry: date · who · commit · what changed · what's left or unsure.

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
