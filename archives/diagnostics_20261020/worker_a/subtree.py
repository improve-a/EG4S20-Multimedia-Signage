import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])
for pre in sys.argv[3:]:
    a = {n: v for n, v in pa["seq"].items() if n.startswith(pre)}
    b = {n: v for n, v in pb["seq"].items() if n.startswith(pre)}
    i = sum(1 for n in a if n in b and a[n] == b[n])
    pd = sum(1 for n in a if n in b and a[n] != b[n])
    oa = [n for n in a if n not in b]
    ob = [n for n in b if n not in a]
    print("%s  A=%d B=%d identical=%d pindiff=%d onlyA=%d onlyB=%d" % (pre, len(a), len(b), i, pd, len(oa), len(ob)))
    for n in sorted(oa):
        print("   ONLY_A", n)
    for n in sorted(ob)[:30]:
        print("   ONLY_B", n)
