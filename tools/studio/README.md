# Studio map tools

Edit-mode scripts that built the world saved in the place (`workspace.Map`, Terrain, Lighting,
`ServerStorage.MapKit`). They are not synced by Rojo; run them in Studio (command bar, or the Studio MCP
`execute_luau`) with `loadstring` after fetching them, or paste them in.

Exception: `first-session-review.luau` is **Play-only**. Run as a temporary server Script to give services
an independent in-memory test profile with normal unlocks. It never replaces ProfileStore's Data table;
persistent leaderboard readers retain the original profile. `Snapshot` returns the test JSON, `Seed`
can resume an earned checkpoint (or nil starts fresh), and **invoke `Restore` before stopping Play**.
The restore result checks the original profile accessor, owned cards and decks. Do not publish the
temporary Script or use the harness in a live server. It is outside Rojo's synced source folders.

- `terrain.luau` - generates the terrain (town, Ember Village, Frostfang Peaks, Neon Abyss, lake, edge
  mountains) and the terrain colours. `{ Rows = {0, 11} }` writes everything; `{ Clear = true }` wipes it.
- `map.luau` - places the kit models and the markers World.luau reads. `{ Part = "terrain" | "town" |
  "ember" | "frost" | "abyss" | "markers" | "all" }`. Re-running a part replaces that zone's folder.
- `stage.luau` - loads Creator Store models into `workspace.Staging` side by side for picking, and
  deletes every script inside them (free models can carry backdoors).
- `install-boss-models.luau` - one-time Edit-only installer for the four user-selected boss sources.
  Sanitizes before parenting, normalizes facing, archives the old kit / sanitized sources in
  `ServerStorage.BossReplacementBackup_20261027`, and removes the loose originals from Workspace.
  Already applied on 2026-10-27; do not rerun over that backup. The exported sanitized kit now lives in
  `assets/models/bosses-20261027/BossKit.rbxm` and syncs through Rojo automatically. The previous kit
  is archived beside it; see that folder's README / manifest. Full-place backups remain Studio saves.
- `scan.luau` - backdoor scanner, pasted straight into the command bar: lists every script outside our Rojo
  folders, flags the ones that load assets by id / run strings / show the fake "Error 501 ... paste this into the
  command bar" screen, and deletes the flagged ones when `DELETE = true`. Never paste code a game screen asks for.
- `lighting.luau` - sets the place's Lighting to the bright town day and `Technology = Future` (only
  settable in Studio; `src/client/LightingSetup.luau` applies the rest on every client). Save after.
- `town-polish.luau` - optional polish for the existing town, applied after `map.luau`: fountain stone /
  water materials, a thin stone border, service paving, two benches with flower planters, three stall moves
  and explicit NPC / Tower markers around the plaza. Does not rebuild Terrain or the world zones.
  Re-running is a no-op. First run backs up the fountain, stalls and entire Markers folder to
  `ServerStorage.TownPolishBackup_20261026`. `{ Restore = true }` replaces those specific assets with their
  saved copies and removes `Town.PlazaPolish`; later edits to those assets would be replaced too.
  Stop / restart Play after applying or restoring so `World` rebuilds NPCs and registers their service ranges.
  Save the place from Studio; Git / Rojo alone cannot carry these map edits. Local copy from the 2026-10-26
  pass: `studio-local/AnimeCardRoll-TownPolish-20261026.rbxl` (ignored by Git). Not published.
- `sync.luau` - stopgap for when Rojo isn't connected: pulls `src/` from `python -m http.server 34875
  --directory src` into the open place (only the Shared / Server / Client script folders).
- `refine-infinite-tower.luau` - Edit-only, idempotent refinement of the existing 22-floor Assistant tower:
  wide base, named-surface stacking, curved roof sections, timber / windows / gables / steps / embers,
  an outer clearing and smaller night zone. Keeps a per-floor / marker / scenery backup in ServerStorage.
  Already applied on 2026-10-29. Exported current / previous models are in assets/models/infinite-tower-20261029.
- `export-tower.py` + `export-tower.luau` - temporary localhost-only model exporter; see the asset README.

Markers (in `workspace.Map.Markers`): `Spawn`, `Sage`, `Wheel` (Madame Fortuna's Lucky Wheel booth; she stands
on its left, the wheel behind; facing -Z towards players), `Fusion` (Hoshi the Fusion Master; the altar goes
4.5 studs in front), `Leaderboards` (the three boards stand side by side along it, facing its front),
`Portal_<bossId>` (the portal opening: size and
facing; optional `SignLift` attribute raises the world sign), `Boss_<bossId>` (where the boss stands), `Zone_<Name>` with a `Radius` attribute (music and
lighting zones; names must match `MUSIC` in `src/client/UI/Sfx.luau` and `MOODS` in `src/client/ZoneFx.luau`).
