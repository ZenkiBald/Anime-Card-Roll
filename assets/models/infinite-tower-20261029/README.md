# Refined Infinite Tower

`InfiniteTower.rbxmx` is the user's existing 22-floor Studio Assistant model, refined in place from
the supplied pagoda reference on 2026-10-29. `PreviousInfiniteTower.rbxmx` preserves its untouched
geometry. Both are sanitized anchored models with zero scripts / remotes; hashes and class counts
are recorded in `manifest.json`.

The first hall is 1.7x the old width (52.7 studs); the second is 0.6x that width, then floors taper
0.94x. Named Foundation / TopRoof surfaces stack within 0.00002 studs, without GetBoundingBox.
Four sloped Slate sections per side curve toward upturned eaves; corner ridges, broad base gables,
recessed amber windows, timber framing, steps, embers and an upper cloud bank complete the model.

The model is at (-135, 7.4, -95), outside the lobby. Its night zone has radius 46; no global Lighting
properties were changed. The entrance prompt uses the existing tower UI / combat system.

Rojo loads the refined asset into ServerStorage.InfiniteTowerTemplate (unknown ServerStorage
instances are preserved). World keeps an existing refined workspace.InfiniteTower; if absent, it
restores the template in floor-sized chunks. It reconnects the prompt, zone, board, particle / light
culling and moves only trees intersecting the restored hall. TownServices skips the older generated
tower whenever this authored model is active. Saves / tower progression are unchanged.

The Edit-mode tool `tools/studio/refine-infinite-tower.luau` was applied once. It keeps original floors,
markers and moved trees in ServerStorage.TowerReferenceBackup_20261029 and is idempotent. Do not rerun
an old tool over later manual edits. The place still needs saving to preserve those backups / scenery moves.

To reproduce an export, run `python tools/studio/export-tower.py`, then use the companion
`export-tower.luau` through Studio MCP in Edit mode. It posts whitelisted model data in bounded chunks
to localhost only. Enable HTTP temporarily if needed and restore the previous setting afterwards.
Stop the helper after export; it does not publish or upload anything to Roblox.
