import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

for path in sys.argv[1:]:
    p = parse_netlist(path)
    print("#####", path)
    for name, v in p["insts"].items():
        if "u_w24_d1024_fifo" in name and v["type"].startswith("EG_PHY_BRAM"):
            print(name, v["type"])
            for k, val in sorted(v["pins"].items()):
                print("   .%s(%s)" % (k, val))
