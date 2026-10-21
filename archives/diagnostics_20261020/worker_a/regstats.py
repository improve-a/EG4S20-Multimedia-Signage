import re
import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

path = sys.argv[1]
p = parse_netlist(path)
regs = Counter()
seqcells = Counter()
slicec = Counter()
for name, v in p["insts"].items():
    h = name.rsplit("/", 1)[0] if "/" in name else ""
    if v["type"] == "AL_MAP_SEQ":
        regs[h] += 1
        seqcells[h] += 1
    elif v["type"] in ("EG_PHY_MSLICE", "EG_PHY_LSLICE"):
        n = len(re.findall(r"\.REG[01]_SD\s*\(", v["params"]))
        if n:
            regs[h] += n
            slicec[h] += n
total = sum(regs.values())
print("TOTAL_REGS", total, "seqcells", sum(seqcells.values()), "slice_regs", sum(slicec.values()))
for h in sys.argv[2:]:
    print(h, "regs", regs.get(h, 0), "seq", seqcells.get(h, 0), "slice", slicec.get(h, 0))
