import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])


def h(n):
    return n.rsplit("/", 1)[0] if "/" in n else "<top>"


sa, sb = pa["seq"], pb["seq"]
same = sum(1 for n in sa if n in sb and sa[n] == sb[n])
pind = sum(1 for n in sa if n in sb and sa[n] != sb[n])
onlya = [n for n in sa if n not in sb]
onlyb = [n for n in sb if n not in sa]
print("AL_MAP_SEQ: identical=%d pindiff=%d onlyA=%d onlyB=%d" % (same, pind, len(onlya), len(onlyb)))
print("onlyA by hier", Counter(h(n) for n in onlya).most_common(8))
print("onlyB by hier", Counter(h(n) for n in onlyb).most_common(8))

hier = sys.argv[3:] if len(sys.argv) > 3 else sorted({h(n) for n in sa} | {h(n) for n in sb})
for x in hier:
    a = {n: v for n, v in sa.items() if h(n) == x}
    b = {n: v for n, v in sb.items() if h(n) == x}
    if not a and not b:
        continue
    i = sum(1 for n in a if n in b and a[n] == b[n])
    pd = sum(1 for n in a if n in b and a[n] != b[n])
    oa = len([n for n in a if n not in b])
    ob = len([n for n in b if n not in a])
    if oa or ob or pd:
        print("%-72s A=%3d B=%3d ident=%3d pind=%3d onlyA=%2d onlyB=%2d" % (x[:72], len(a), len(b), i, pd, oa, ob))
