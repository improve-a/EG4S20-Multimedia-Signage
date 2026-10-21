import sys
from collections import Counter, defaultdict

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

pa, pb = parse_netlist(sys.argv[1]), parse_netlist(sys.argv[2])
ia, ib = pa["insts"], pb["insts"]
same = 0
onlya, onlyb, chg = [], [], []
for n, v in ia.items():
    w = ib.get(n)
    if w is None:
        onlya.append(n)
    elif v == w:
        same += 1
    else:
        chg.append((n, v["type"], w["type"]))
for n in ib:
    if n not in ia:
        onlyb.append(n)


def h(n):
    return n.rsplit("/", 1)[0] if "/" in n else "<top>"


print("identical_cells", same)
print("only_A", len(onlya), "only_B", len(onlyb), "changed", len(chg))
for tag, lst in (("ONLY_A", onlya), ("ONLY_B", onlyb)):
    c = Counter(h(n) for n in lst)
    print(tag, "by hier:")
    for k, v in c.most_common(20):
        print("   %-70s %d" % (k, v))
c = Counter(h(n) for n, _, _ in chg)
print("CHANGED by hier:")
for k, v in c.most_common(20):
    print("   %-70s %d" % (k, v))
print("CHANGED type pairs:", Counter((t, u) for _, t, u in chg).most_common(10))
