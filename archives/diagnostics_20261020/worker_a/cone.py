"""Dump a shallow combinational cone for a net, for A/B structural comparison.

Usage: cone.py file.v net [depth]
Output is a canonical s-expression: primitives with their params and pins,
recursing through *input* pins (output pins excluded).  Net names that are
purely tool-generated (end with _syn_<n> or open_n<d>) are printed as @, so two
mappings of the same function often produce identical trees.
"""
import re
import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

path, top = sys.argv[1], sys.argv[2]
depth = int(sys.argv[3]) if len(sys.argv) > 3 else 3
p = parse_netlist(path)

# driver: net -> (cell, pin)
drv = {}
for name, v in p["insts"].items():
    t = v["type"]
    if t in ("EG_PHY_PAD", "EG_PHY_CONFIG", "EG_PHY_GCLK", "buf"):
        continue
    for pin, net in v["pins"].items():
        nets = re.findall(r"\\[^\s,{}]+|'b[01]+|[01]+'b[01]+|[A-Za-z_][\w$\[\]]*", net)
        if pin in ("q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"):
            for n in nets:
                drv.setdefault(n.lstrip("\\"), (name, pin))


def norm(n):
    n = n.strip().lstrip("\\")
    if re.search(r"_syn_\d+$", n) or re.match(r"open_n\d+$", n) or not n:
        return "@"
    return n


def expr(net, d):
    if d < 0:
        return "."
    hit = drv.get(net.lstrip("\\"))
    if not hit:
        return norm(net)
    name, opin = hit
    v = p["insts"][name]
    parts = []
    for pin, val in sorted(v["pins"].items()):
        if pin in ("q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"):
            continue
        for n in re.findall(r"\\[^\s,{}]+|'b[01]+|[01]+'b[01]+|[A-Za-z_][\w$\[\]]*", val):
            parts.append(pin + "=" + expr(n, d - 1))
    params = v["params"].replace(" ", "")
    return "(%s%s %s)" % (v["type"], "[" + params + "]" if params else "", " ".join(parts))


print(expr(top, depth))
