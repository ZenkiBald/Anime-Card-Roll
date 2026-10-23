# Checks every property name passed through Kit.new / Kit.label / Kit.button / part()
# against the Roblox API definitions, since those go through a dynamic setter.
import re, sys, pathlib
defs = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
classes = {}
for m in re.finditer(r"^declare (?:extern type|class) (\w+)(?: extends (\w+))? with(?: end$|(.*?)^end$)", defs, re.S | re.M):
    name, parent, body = m.group(1), m.group(2), m.group(3) or ""
    props = set(re.findall(r"^[ \t]+(\w+)[ \t]*:", body, re.M))
    classes[name] = (parent, props)
def has(cls, prop):
    while cls:
        parent, props = classes.get(cls, (None, set()))
        if prop in props:
            return True
        cls = parent
    return False
def table_at(src, i):
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{": depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0: return src[i:j+1]
    return ""
def keys(tbl):
    out, depth, line = [], 0, ""
    for ch in tbl[1:-1]:
        if ch in "{(": depth += 1
        elif ch in "})": depth -= 1
        if depth == 0 and ch in ",\n":
            m = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", line)
            if m: out.append(m.group(1))
            line = ""
        else:
            line += ch
    m = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)", line)
    if m: out.append(m.group(1))
    return out
bad = 0; checked = 0
for path in pathlib.Path(sys.argv[2]).rglob("*.luau"):
    if path.name == "ProfileStore.luau": continue
    src = path.read_text(encoding="utf-8")
    patterns = [(r'Kit\.new\("(\w+)",\s*\{', None), (r"Kit\.label\(\{", "TextLabel"),
                (r"(?<![\w.])part\(\{", "Part")]
    for pat, fixed in patterns:
        for m in re.finditer(pat, src):
            cls = fixed or m.group(1)
            tbl = table_at(src, m.end() - 1)
            for k in keys(tbl):
                checked += 1
                if k == "Parent": continue
                if not has(cls, k):
                    bad += 1
                    line = src[:m.start()].count("\n") + 1
                    print(f"{path.name}:{line}: {cls} has no property '{k}'")
    for m in re.finditer(r"Kit\.button\([^{]*?(\{)", src):
        tbl = table_at(src, m.start(1))
        for k in keys(tbl):
            checked += 1
            if k != "Parent" and not has("TextButton", k):
                bad += 1; print(f"{path.name}: TextButton has no property '{k}'")
print(f"checked {checked} property names, {bad} problems")
sys.exit(1 if bad else 0)
