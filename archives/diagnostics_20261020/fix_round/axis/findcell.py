import sys
sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist
p = parse_netlist(sys.argv[1])
need = sys.argv[2:]
for name, v in p["insts"].items():
    blob = " ".join(v["pins"].values())
    if all(n in blob for n in need):
        print("----", name, v["type"])
        print(v["params"])
        for k, val in v["pins"].items():
            print("  .%s=%s" % (k, val))
