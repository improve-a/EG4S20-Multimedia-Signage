import sys, re
sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist
p = parse_netlist(sys.argv[1])
need = sys.argv[2:]
print("cells", len(p["insts"]))
for name, v in sorted(p["insts"].items()):
    if any(n in name for n in need):
        print("----", name, v["type"])
        print(" params", " ".join(v["params"].split())[:300])
        for k, val in v["pins"].items():
            print("   .%s=%s" % (k, val))
