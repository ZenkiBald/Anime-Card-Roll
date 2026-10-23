# Studio map tools

Edit-mode scripts that built the world saved in the place (`workspace.Map`, Terrain, Lighting,
`ServerStorage.MapKit`). They are not synced by Rojo; run them in Studio (command bar, or the Studio MCP
`execute_luau`) with `loadstring` after fetching them, or paste them in.

- `terrain.luau` - generates the terrain (town, Ember Village, Frostfang Peaks, Neon Abyss, lake, edge
  mountains) and the terrain colours. `{ Rows = {0, 11} }` writes everything; `{ Clear = true }` wipes it.
- `map.luau` - places the kit models and the markers World.luau reads. `{ Part = "terrain" | "town" |
  "ember" | "frost" | "abyss" | "markers" | "all" }`. Re-running a part replaces that zone's folder.
- `stage.luau` - loads Creator Store models into `workspace.Staging` side by side for picking, and
  deletes every script inside them (free models can carry backdoors).
- `sync.luau` - stopgap for when Rojo isn't connected: pulls `src/` from `python -m http.server 34875
  --directory src` into the open place (only the Shared / Server / Client script folders).

Markers (in `workspace.Map.Markers`): `Spawn`, `Sage`, `Wheel` (Madame Fortuna's Lucky Wheel booth; she stands
on its left, the wheel behind; facing -Z towards players), `Fusion` (Hoshi the Fusion Master; the altar goes
4.5 studs in front), `Leaderboards` (the three boards stand side by side along it, facing its front),
`Portal_<bossId>` (the portal opening: size and
facing; optional `SignLift` attribute raises the world sign), `Boss_<bossId>` (where the boss stands), `Zone_<Name>` with a `Radius` attribute (music and
lighting zones; names must match `MUSIC` in `src/client/UI/Sfx.luau` and `MOODS` in `src/client/ZoneFx.luau`).
