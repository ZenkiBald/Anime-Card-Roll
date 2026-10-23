Continue Anime Card Roll, my Roblox anime card RNG game in this folder. Read CLAUDE.md and your memory first.

Roblox Studio is open with the game, and its built-in MCP server is enabled (Roblox_Studio in .mcp.json).
First check you can reach it (list_roblox_studios), then press Play and take screenshots so you see
what I see. Until now everything was built blind and I think it looks like a cheap mini game.

What I want, in this order:

1. UI that looks like top Roblox anime card games (chunky purple panels, glossy buttons, big readable
   numbers). The 29 Figma UI kit images are uploaded and their ids are in src/client/UI/Skin.luau.
   Check in play mode that they all load and look right (no stretching, right sizes, nothing old or ugly
   left), and fix what you see. Show me before/after screenshots.

2. A big real world instead of the small hub made of parts (src/server/World.luau): Roblox terrain
   (mountains, water, grass, snow), real Creator Store models (trees, houses, lanterns, bridges) and
   Studio's AI mesh / procedural model tools where the store has nothing good. A spawn town in the middle
   and three large themed zones to walk to: Ember Village (World 1, Kurogane), Frostfang Peaks
   (World 2, Rimeveil), Neon Abyss (World 3, Vex), each with its portal and boss NPC (BossModels).
   Keep it smooth on phones (StreamingEnabled, sensible part counts).
   Before building, sort out the workflow so the map is never wiped: scripts live in src/ and are built
   with Rojo into AnimeCardRoll-Test.rbxlx, which replaces everything. Propose how the Studio-built map
   and the Rojo scripts live together (e.g. rojo serve + the Rojo plugin into a saved/published place)
   and ask me before changing it.

3. Real sound: find good sounds with the Studio MCP asset search (Roblox / licensed libraries only):
   UI clicks, roll whoosh, card flip, a rising sting per rarity, big hits for Mythic / Secret, battle hits,
   heals, rewards, potion use, plus background music per zone. Wire them into src/client/UI/Sfx.luau and
   check they fire at the right moments in a playtest.

Rules: original characters only (no real anime characters), keep TestMode on, keep the server owning all
results. The check tools (rojo, luau-lsp, luau) aren't installed on my PC: ask me before downloading them.
Keep your messages short and show me screenshots instead of long explanations.
