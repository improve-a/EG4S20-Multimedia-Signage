import sys, re
p = sys.argv[1]
keys = sys.argv[2:]
t = open(p, encoding="utf-8", errors="replace").read().splitlines()
blocks = []
cur = None
for i, l in enumerate(t):
    if l.startswith("Slack               :"):
        if cur:
            blocks.append(cur)
        cur = {"line": i+1, "lines": [l]}
    elif cur is not None:
        cur["lines"].append(l)
        if len(cur["lines"]) > 400:  # keep bounded, path detail is <200 lines
            blocks.append(cur); cur = None
if cur:
    blocks.append(cur)

def field(b, name):
    for l in b["lines"]:
        if l.startswith(name):
            return l.split(":", 1)[1].strip()
    return ""

rows = []
for b in blocks:
    txt = "\n".join(b["lines"])
    typ = field(b, "Check Type")
    if typ not in ("recovery", "removal"):
        continue
    if keys and not any(k in txt for k in keys):
        continue
    rows.append((b["line"], field(b, "Slack"), typ, field(b, "Process"),
                 field(b, "Begin Point"), field(b, "End Point")))
print("file", p, "recovery/removal matched", len(rows))
for r in rows:
    print("---- line %d Slack=%s Type=%s Process=%s" % (r[0], r[1], r[2], r[3]))
    print("  Begin:", r[4])
    print("  End  :", r[5])
