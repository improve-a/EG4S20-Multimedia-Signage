import re
import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])
LUT = {"AL_MAP_LUT1", "AL_MAP_LUT2", "AL_MAP_LUT3", "AL_MAP_LUT4", "AL_MAP_LUT5"}


def own(p, pre):
    """LUTs directly in this hierarchy (not descendants)."""
    c = Counter()
    for n, v in p["insts"].items():
        h = n.rsplit("/", 1)[0] if "/" in n else ""
        if h != pre or v["type"] not in LUT:
            continue
        prm = tuple(sorted(re.findall(r"\.([A-Z0-9_]+)\(([^()]*)\)", v["params"])))
        c[(v["type"], prm)] += 1
    return c


for pre in sys.argv[3:]:
    a, b = own(pa, pre), own(pb, pre)
    common = sum(min(a[k], b[k]) for k in a.keys() & b.keys())
    onlya = sum((a - b).values())
    onlyb = sum((b - a).values())
    print("%-95s A=%3d B=%3d same-shape=%3d onlyA=%3d onlyB=%3d" % (pre[:95], sum(a.values()), sum(b.values()), common, onlya, onlyb))
