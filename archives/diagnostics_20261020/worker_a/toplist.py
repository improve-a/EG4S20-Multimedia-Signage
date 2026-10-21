import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

for path in sys.argv[1:]:
    p = parse_netlist(path)
    rows = [(n, v) for n, v in p["seq"].items() if "/" not in n]
    print("#####", path, len(rows))
    for n, v in sorted(rows):
        print("%-28s q=%-34s d=%-34s ce=%s sr=%s" % (n, v.get("q"), v.get("d"), v.get("ce"), v.get("sr")))
