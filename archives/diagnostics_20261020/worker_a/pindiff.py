import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])
pre = sys.argv[3]
n = int(sys.argv[4]) if len(sys.argv) > 4 else 15
sa, sb = pa["seq"], pb["seq"]
shown = 0
for name, v in sorted(sa.items()):
    if not name.startswith(pre):
        continue
    w = sb.get(name)
    if w is None or w == v:
        continue
    diffs = {k: (v.get(k), w.get(k)) for k in set(v) | set(w) if v.get(k) != w.get(k)}
    print(name)
    for k, (x, y) in diffs.items():
        print("   %-4s A=%s\n        B=%s" % (k, x, y))
    shown += 1
    if shown >= n:
        break
