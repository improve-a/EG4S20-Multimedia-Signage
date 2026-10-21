import re
import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

path, top = sys.argv[1], sys.argv[2]
depth = int(sys.argv[3]) if len(sys.argv) > 3 else 8
p = parse_netlist(path)
drv = {}
for name, v in p["insts"].items():
    if v["type"] in ("EG_PHY_PAD", "EG_PHY_CONFIG", "EG_PHY_GCLK"):
        continue
    for pin, net in v["pins"].items():
        nets = re.findall(r"\\[^\s,{}]+|'b[01]+|[01]+'b[01]+|[A-Za-z_][\w$\[\]]*", net)
        if pin in ("q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"):
            for n in nets:
                drv.setdefault(n.lstrip("\\"), (name, pin))

leaves = Counter()
seen = set()


def walk(net, d):
    key = (net, d)
    if key in seen:
        return
    seen.add(key)
    hit = drv.get(net.lstrip("\\"))
    if not hit or d < 0:
        leaves[net.lstrip("\\")] += 1
        return
    v = p["insts"][hit[0]]
    for pin, val in v["pins"].items():
        if pin in ("q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"):
            continue
        for n in re.findall(r"\\[^\s,{}]+|'b[01]+|[01]+'b[01]+|[A-Za-z_][\w$\[\]]*", val):
            walk(n, d - 1)


walk(top, depth)
for k, n in sorted(leaves.items()):
    print(n, k)
