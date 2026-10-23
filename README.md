# Anime Card Roll

A Roblox card-rolling game. This folder is a Rojo project.

## Play it now

Open `AnimeCardRoll-Test.rbxlx` in Roblox Studio and press Play.

## Work on it with live sync

1. Install the tools: `rokit install` (or install Rojo 7.7.1 any way you like).
2. Install the Rojo plugin in Studio: `rojo plugin install`.
3. In this folder run `rojo serve`, then in Studio open the Rojo plugin and click Connect.
   Edits to files in `src` now appear in Studio straight away.

## Saving in Studio

Progress resets each time you stop testing until you publish the place and turn on
File > Experience Settings > Security > Enable Studio Access to API Services.
Use a separate test copy of the game for that, not the live one.

## Before launch

Set `TestMode = false` in `src/shared/Config.luau`.

See `CLAUDE.md` for the project layout, rules and check commands.
