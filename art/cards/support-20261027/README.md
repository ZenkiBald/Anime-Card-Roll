# Support card illustrations — 2026-10-27

All 11 relic / technique Supports now have their own AI artwork. The user approved the Diamond Mitotic
Seal, Gourd of Living Sand and Cursed Ocular Seal examples, then authorized the remaining eight in that style.
Those three approved images are preserved exactly. Every source is a distinct 1254 x 1254 full-bleed PNG;
the existing card frames crop it into a portrait. There is no baked-in card text or UI.

The series uses dark shrine backdrops, sharp anime contours, weathered relics and controlled glowing energy.
Supports depict relics, seals, techniques or close-up hands, with no complete characters / faces. Binding
Blood Vow received a cleanup edit to remove stray imagery from other cards; Eight Trigrams Seal received
a cleanup edit to remove a tiny generated signature-like mark. Only the final v2 images are included.

- [manifest.json](manifest.json): names, card ids, filenames, Roblox asset ids, dimensions and SHA-256 hashes.
- [generation-plan.json](generation-plan.json): the exact eight production prompts used with built-in imagegen.
- [approved-preview-prompts.json](approved-preview-prompts.json): the three approved preview prompts.
- [cleanup-edits.json](cleanup-edits.json): cleanup prompts and source paths for the two final v2 images.

`src/shared/Cards.luau`'s ART table connects every image. Uploads belong to the game's owner (4661882681).
Original character artwork, identities, abilities, odds and saves were not changed by this artwork pass.

Validation: all 11 distinct PNGs verified, type check 0 errors, UI props 5,565 / 0 problems, headless ALL
CHECKS PASSED. Studio visibly rendered all 11 actual CardTile and full CardView components; all 11 Art
ImageLabels reported IsLoaded. The normal SQUAD Support tab / saved Support slots displayed the new art.
Studio was returned to Edit; temporary preview UI and upload servers were removed. Nothing was published.
