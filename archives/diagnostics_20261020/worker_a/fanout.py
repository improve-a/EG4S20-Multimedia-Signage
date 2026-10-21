"""Print driver and all loads of a net in a TD `write_verilog` gate netlist.

Usage:
  fanout.py gate.v NET_SUBSTRING [--outside HIER]

Matches any net expression containing NET_SUBSTRING (e.g. `probe/locked`,
`O_video_locked`, `status_meta`).  Prints the driver cell (if any) and each
consumer cell/pin with its hierarchy.  With --outside, loads whose hierarchy
does not start with HIER are marked LOAD_OUTSIDE.

Only pin connections are inspected; a net that exists as `wire` but has no
consumer prints "no loads".
"""
import re
import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist, strip_comments  # noqa: E402

OUT_PINS = {"q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"}


def hier(name):
    return name.rsplit("/", 1)[0] if "/" in name else "<top>"


def main():
    path, needle = sys.argv[1], sys.argv[2]
    outside = None
    if "--outside" in sys.argv:
        outside = sys.argv[sys.argv.index("--outside") + 1]
    p = parse_netlist(path)
    text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    nets = set()
    for line in text.splitlines():
        if "wire" in line or needle in line:
            for m in re.finditer(r"\\[^\s,{};]+", line):
                n = m.group(0).lstrip("\\")
                if needle in n:
                    nets.add(n)
    print("matched nets:", len(nets))
    for n in sorted(nets)[:40]:
        print("  NET", n)
    loads = []
    drivers = []
    for cell, v in p["insts"].items():
        for pin, val in v["pins"].items():
            if needle not in val:
                continue
            if pin in OUT_PINS:
                drivers.append((cell, pin, val.strip()))
            else:
                loads.append((cell, pin, val.strip()))
    print("drivers:", len(drivers))
    for d in drivers[:20]:
        print("  DRV %-70s .%s(%s)" % (d[0], d[1], d[2]))
    print("loads:", len(loads))
    for cell, pin, val in loads[:80]:
        flag = ""
        if outside and not hier(cell).startswith(outside):
            flag = "  <== LOAD_OUTSIDE"
        print("  %-70s .%-4s %s%s" % (cell, pin, val, flag))
    for n in sorted(nets):
        cnt = sum(1 for c, pi, v in loads if n in v)
        if cnt == 0:
            print("  NET %s : no loads" % n)


if __name__ == "__main__":
    main()
