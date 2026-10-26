# Notes for any AI coder (ChatGPT / Codex, Claude Code, or another)

Two AIs work on this game, one at a time: Claude Code and ChatGPT (Codex). Whichever one is available
does the work. This file and the two below are shared, so the next one can pick up where the last
one stopped.

1. **`CLAUDE.md`**: how the game works now, the layout, the **rules** and the check commands. It's
   the source of truth for both AIs; the name is historical. Read all of it before changing anything.
2. **`docs/HANDOFF.md`**: what was done last, what's half done, and what's next. Read it first and
   write in it last.
3. `docs/LAUNCH_CHECKLIST.md`: what still needs checking in Studio and before launch.

## Before you start

- Work on the branch named at the top of `docs/HANDOFF.md`. Pull it first
  (`git pull origin <branch>`): the other AI may have pushed since your last session.
- Only one AI works at a time. If `docs/HANDOFF.md` says another session is **IN PROGRESS**, stop
  and ask the user.
- Do only what the user asked, in their own words. Don't rename cards or bosses, and don't undo the
  other AI's work unless the user asks.

## While working

- Follow the Rules in `CLAUDE.md`:
  - The server owns every roll and result.
  - Validate and rate-limit every remote.
  - Content is data.
  - Save changes need a `SaveMigration` step and a test.
  - Cheap on phones.
- Code style: match the surrounding Luau (tabs, `--!strict` / `--!nonstrict` as the file has it, short
  comments that say why).
- Run the checks from `CLAUDE.md` > Commands before every commit:
  - The type check must report 0 errors.
  - `python tests/check_props.py ...` must report 0 problems.
  - `python tests/bundle.py` then `luau tests/bundle_out.luau` must print ALL CHECKS PASSED.

  If you can't run them (no tools), say so in the handoff and in your reply. Never claim they passed.
- Never `rojo build` over the real place: the map lives only in the place file.

## When you finish

1. Update `CLAUDE.md` if how the game works changed (it describes the game *now*, not its history).
2. Add a line to `docs/LAUNCH_CHECKLIST.md` section 5 for anything the user should check in Studio.
3. Add an entry at the top of the log in `docs/HANDOFF.md` and set Status back to **IDLE**.
4. Commit with a clear message (one commit per pass) and push to the branch.
5. Tell the user to `git pull` and reconnect Rojo in Studio.
