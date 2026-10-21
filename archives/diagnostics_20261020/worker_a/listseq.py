import sys
from collections import Counter, defaultdict

sys.path.insert(0, ".")
from netcmp import parse_netlist, strip_comments  # noqa: E402

path, pre = sys.argv[1], sys.argv[2]
p = parse_netlist(path)
seqs = {n: v for n, v in p["seq"].items() if n == pre or n.startswith(pre + "/")}
print("count", len(seqs))
for n in sorted(seqs):
    q = seqs[n].get("q")
    print("%-60s q=%-45s d=%s" % (n[len(pre) + 1:] if n.startswith(pre + "/") else n, q, seqs[n].get("d")))
