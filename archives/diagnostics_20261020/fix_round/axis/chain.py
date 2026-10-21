import sys
sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist
p = parse_netlist(sys.argv[1])
pref = sys.argv[2]
for n, v in sorted(p["insts"].items()):
    if n.startswith(pref) and ("lt11" in n or "lt1_" in n or "lt0_" in n):
        print("----", n, v["type"])
        print(" ", " ".join(v["params"].split())[:300])
        for k, val in v["pins"].items():
            print("   .%s=%s" % (k, val))
