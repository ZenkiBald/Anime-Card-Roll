# Trait artwork · 2026-11-13

Sixteen original transparent illustrations generated with the built-in `image_gen` tool, one image
per call. Subjects follow `docs/TRAIT_ICON_PROMPTS.md`; no trait identities, odds or bonuses changed.

- `contact-sheet.jpg`: labeled preview of the complete set.
- `generation-plan.json`: exact production prompts and tool settings.
- `manifest.json`: prompts, original dimensions, upload dimensions, SHA-256 hashes and Roblox asset IDs.
- `asset-ids.json`: compact trait ID → uploaded image ID mapping used by `UI/TraitArt.luau`.
- Root PNGs: untouched generated originals, with their original aspect ratios / alpha preserved.
- `upload/*.png`: transparent 512 × 512 copies; contained within 448 × 448 and centered with padding,
  without stretching or cropping. Pillow was used only for export sizing / contact-sheet assembly.
- `source-paths.json`: provenance paths of the original generation outputs; committed copies above
  are the portable source assets.

All sixteen Roblox images returned AssetFetchStatus.Success in desktop Studio. The set is integrated
into Trait Master choices / animations, card trait chips, collection facts and ODDS. Phone sizing,
real reroll animation pacing and the user's aesthetic review remain in LAUNCH_CHECKLIST section 5.
