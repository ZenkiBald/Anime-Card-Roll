# Bundles the shared modules (and the pure server modules) with Roblox stubs into one Luau
# file the plain Luau CLI can run, followed by every test file.
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
tests = root / "tests"
modules = [
    ("Config", root / "src" / "shared"),
    ("Rarity", root / "src" / "shared"),
    ("Borders", root / "src" / "shared"),
    ("Elements", root / "src" / "shared"),
    ("Awaken", root / "src" / "shared"),
    ("Foils", root / "src" / "shared"),
    ("RollBoost", root / "src" / "shared"),
    ("Odds", root / "src" / "shared"),
    ("Cards", root / "src" / "shared"),
    ("Deck", root / "src" / "shared"),
    ("Bosses", root / "src" / "shared"),
    ("Rewards", root / "src" / "shared"),
    ("Packs", root / "src" / "shared"),
    ("Items", root / "src" / "shared"),
    ("Traits", root / "src" / "shared"),
    ("Meta", root / "src" / "shared"),
    ("Tower", root / "src" / "shared"),
    ("Raid", root / "src" / "shared"),
    ("Tutorial", root / "src" / "shared"),
    ("Goals", root / "src" / "shared"),
    ("MonetizationConfig", root / "src" / "shared"),
    ("BattleEngine", root / "src" / "server"),
    ("SaveMigration", root / "src" / "server"),
]
test_files = ["odds_test.luau", "meta_test.luau", "battle_test.luau", "tower_test.luau", "strategy_test.luau", "phase2_test.luau", "ftue_test.luau", "save_test.luau"]

out = [(tests / "stubs.luau").read_text(encoding="utf-8"), (tests / "harness.luau").read_text(encoding="utf-8"), "MODULES = {}"]
for name, folder in modules:
    src = (folder / f"{name}.luau").read_text(encoding="utf-8")
    src = re.sub(r"^--!(strict|nonstrict)\n", "", src, flags=re.M)
    src = re.sub(r"require\((?:script\.Parent|Shared)\.(\w+)\)", r"MODULES.\1", src)
    # server modules reach the shared ones through ReplicatedStorage
    src = re.sub(r"^local (ReplicatedStorage|Shared) = .*\n", "", src, flags=re.M)
    # type exports aren't allowed inside functions
    src = re.sub(r"^export type", "type", src, flags=re.M)
    out.append(f"MODULES.{name} = (function()\n{src}\nend)()")
out.append("do -- fixtures.luau\n" + (tests / "fixtures.luau").read_text(encoding="utf-8") + "\nend")
for name in test_files:
    body = (tests / name).read_text(encoding="utf-8")
    out.append(f"do -- {name}\n{body}\nend")
out.append('print(if failures == 0 then "\\nALL CHECKS PASSED" else `\\n{failures} CHECK(S) FAILED`)')
(tests / "bundle_out.luau").write_text("\n".join(out), encoding="utf-8")
