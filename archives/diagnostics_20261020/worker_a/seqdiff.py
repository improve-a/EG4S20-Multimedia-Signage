import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

a, b = sys.argv[1], sys.argv[2]
prefixes = sys.argv[3:]
pa, pb = parse_netlist(a), parse_netlist(b)


def rows(p, pre):
    out = {}
    for name, pins in p["seq"].items():
        if name == pre or name.startswith(pre + "/"):
            out[name] = pins
    return out


for pre in prefixes:
    ra, rb = rows(pa, pre), rows(pb, pre)
    print("=" * 20, pre, "A=", len(ra), "B=", len(rb))
    ka = set(ra)
    kb = set(rb)
    for n in sorted(ka - kb):
        print("  ONLY_A", n, "d=", ra[n].get("d"), "q=", ra[n].get("q"))
    for n in sorted(kb - ka):
        print("  ONLY_B", n, "d=", rb[n].get("d"), "q=", rb[n].get("q"))
    # same cell name, different pins
    for n in sorted(ka & kb):
        if ra[n] != rb[n]:
            diffs = {k: (ra[n].get(k), rb[n].get(k)) for k in set(ra[n]) | set(rb[n])
                     if ra[n].get(k) != rb[n].get(k)}
            print("  PINDIFF", n, diffs)
