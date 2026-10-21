import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])
sa, sb = pa["seq"], pb["seq"]
c = Counter()
for name, v in sa.items():
    w = sb.get(name)
    if w is None or w == v:
        continue
    for k in set(v) | set(w):
        if v.get(k) != w.get(k):
            c[(k, v.get(k), w.get(k))] += 1
for (k, x, y), n in c.most_common(30):
    print("%3d  %-4s A=%s | B=%s" % (n, k, x, y))
