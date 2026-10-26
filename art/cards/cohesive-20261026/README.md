# Cohesive card illustrations — 2026-10-26

All 26 current cards have an illustration generated with the built-in image tool. The three approved previews
(mirai, akane, tomo) established the shared rendering style; the remaining portraits follow that direction.

Every PNG is 1254 x 1254, full bleed and without baked-in card UI. Existing CardTile / CardView frames crop the
square art to fit. Faces are composed centrally for those crops. Do not resize the card UI to match the sources.

- `manifest.json`: card ids, displayed names, inspiration mapping, image ids, previous ids, dimensions and SHA-256.
- `generation-plan.json`: shared production style and the 23 batch prompts.
- `approved-preview-prompts.json`: the exact three approved preview prompts.

`src/shared/Cards.luau`'s ART table uses the uploaded image ids. The five older root PNGs and their former ids
are preserved; this folder does not overwrite them. No names, kits, stats, ownership or save data changed.

Validation: 26 distinct valid PNGs, square dimensions checked; type check 0 errors; UI props 0 problems;
headless ALL CHECKS PASSED. Studio visibly rendered all 26 actual CardTile components, SQUAD and the full
Limitless Sage portrait. Asset preload flags were unreliable even for visibly rendered images, so visual
inspection was used. Review reveals and battle pods in normal play. The place has not been published.
