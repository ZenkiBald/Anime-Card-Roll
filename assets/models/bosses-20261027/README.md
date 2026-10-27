# User-selected boss replacements

`BossKit.rbxm` is the sanitized, canonical-facing Roblox model asset managed by Rojo at
`ReplicatedStorage.BossKit`. It travels with Git; these four models no longer depend on a particular
local place copy. Existing service fallback meshes are retained in the same kit.

| Boss id / existing name | User-selected appearance | Inserted source name | Parts |
| --- | --- | --- | --- |
| kurogane / Tailed Beast Calamity | Naruto Kurama Avatar | Nine-Tails Fox (Kurama) | 65 |
| rimeveil / Galactic Emperor | R6 Golden Frieza Rig | Golden Frieza | 33 |
| vex / Mirror Flower Overlord | Madara Susanoo | Susanoo (Madara) | 51 |
| tenrai / Demon Progenitor | Muzan [R6] | Muzan Kibutsuji | 10 |

All inserted scripts, GUI, remotes, sounds, package links and emitters are removed. Kurama's original
movement / sound scripts and Susanoo's 28 emitters do not ship. Runtime `BossModels` also strips
executable / interactive content from every clone. Humanoid evaluation is disabled so imported rigs
keep their clothing without restoring torso collision. All visual parts are anchored and noninteractive.
Susanoo's 33 dark-blue Neon shell parts use shaded blue SmoothPlastic so its armor remains readable.

The installer is `tools/studio/install-boss-models.luau`. It backs up the former kit and moves sanitized
workspace sources out of the map into `ServerStorage.BossReplacementBackup_20261027`; do not run it again
over an existing backup. Source models retain their meshes / textures / clothing; no remote code is loaded.

`PreviousBossKit.rbxm` archives the previous kit and is not mapped into the running game. To restore it,
point the BossKit entry in `default.project.json` at that file. Never restore a downloaded asset's scripts.
`manifest.json` records the exported file hashes and mapping. Actual Creator Store listing ids were not
available from the inserted objects; names record user selections rather than invented listing metadata.

No card / boss names, ids, stats, drops, progression, saves or combat rules change in this pass.
