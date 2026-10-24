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
- `scan.luau` - backdoor scanner, pasted straight into the command bar: lists every script outside our Rojo
  folders, flags the ones that load assets by id / run strings / show the fake "Error 501 ... paste this into the
  command bar" screen, and deletes the flagged ones when `DELETE = true`. Never paste code a game screen asks for.
- `lighting.luau` - sets the place's Lighting to the twilight look and `Technology = Future` (only
  settable in Studio; `src/client/LightingSetup.luau` applies the rest on every client). Save after.
- `sync.luau` - stopgap for when Rojo isn't connected: pulls `src/` from `python -m http.server 34875
  --directory src` into the open place (only the Shared / Server / Client script folders).

Markers (in `workspace.Map.Markers`): `Spawn`, `Sage`, `Wheel` (Madame Fortuna's Lucky Wheel booth; she stands
on its left, the wheel behind; facing -Z towards players), `Fusion` (Hoshi the Fusion Master; the altar goes
4.5 studs in front), `Leaderboards` (the three boards stand side by side along it, facing its front),
`Portal_<bossId>` (the portal opening: size and
facing; optional `SignLift` attribute raises the world sign), `Boss_<bossId>` (where the boss stands), `Zone_<Name>` with a `Radius` attribute (music and
lighting zones; names must match `MUSIC` in `src/client/UI/Sfx.luau` and `MOODS` in `src/client/ZoneFx.luau`).
