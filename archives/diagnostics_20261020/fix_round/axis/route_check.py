#!/usr/bin/env python3
"""Targeted post-route spot check for the AXIS ready/write path.

Text-level, not a formal extraction: TD packed the ready FF into a shared
EG_PHY_LSLICE, so the pre-route LUT names no longer exist. We check that the
same D/inputs are still present and that no BRAM write-enable uses ready.
"""
import re
import sys

path = sys.argv[1]
t = open(path, encoding="utf-8", errors="replace").read()
lines = t.splitlines()
print("file", path, "lines", len(lines))

# 1) the register whose Q contains S_video_in_ready
q_hits = [i for i, l in enumerate(lines) if ".q(" in l and "S_video_in_ready" in l]
print("ready Q assignments:", len(q_hits))
for i in q_hits:
    start = i
    while start > 0 and not lines[start].lstrip().startswith(("EG_PHY_", "AL_MAP_")):
        start -= 1
    print("  cell start line", start + 1)
    print("  " + "\n  ".join(x.strip() for x in lines[start:i + 1] if x.strip()))

# 2) WEA pins
weas = sorted(set(re.findall(r"\.wea\(([^)]*)\)", t)))
print("distinct .wea nets:", weas)
bad = [w for w in weas if "ready" in w.lower()]
print("wea using ready:", bad)

# 3) empty/last/ready all appear in the same packed ready cell
for i in q_hits:
    start = i
    while start > 0 and not lines[start].lstrip().startswith(("EG_PHY_", "AL_MAP_")):
        start -= 1
    blob = "\n".join(lines[start:i + 1])
    print("  ready cell has S_fifo_empty:", "S_fifo_empty" in blob)
    print("  ready cell has probe/al:", "probe/al" in blob)
    print("  ready cell has S_video_in_ready:", "S_video_in_ready" in blob)
