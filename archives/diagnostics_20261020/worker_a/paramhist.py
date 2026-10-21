import json
import re
import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

p = parse_netlist(sys.argv[1])
typ = sys.argv[2]
c = Counter()
keys = Counter()
for name, v in p["insts"].items():
    if v["type"] != typ:
        continue
    for k, val in re.findall(r"\.([A-Za-z0-9_]+)\s*\(([^()]*)\)", v["params"]):
        c[(k, val.strip())] += 1
        keys[k] += 1
print("instances", sum(1 for v in p["insts"].values() if v["type"] == typ))
print("keys", dict(keys))
for (k, v), n in c.most_common(40):
    print(n, k, v)
