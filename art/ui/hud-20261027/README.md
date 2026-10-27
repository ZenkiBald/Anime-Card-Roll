# Town / HUD icon pass (2026-10-27)

Ten individual transparent illustrations generated with the built-in ImageGen tool.
The full-size 1254 x 1254 originals are here; `upload/` contains the 384 x 384 alpha-preserving upload copies.
`manifest.json` records each exact prompt, source, SHA-256, consuming key and uploaded Roblox asset id.
`generation-plan.json` preserves the prompt set; `asset-ids.json` is the upload receipt.

`src/client/UI/HudArt.luau` maps these images to the three currency chips and seven navigation buttons.
Battle reward chips reuse Shards / Trait Shards; reward packs use the existing BAG illustrations.
