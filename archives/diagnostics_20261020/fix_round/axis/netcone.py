import sys
sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist

OUT = {"q", "o", "Q", "O", "f", "fx", "fco", "dob", "co", "dout"}
LUTS = {"AL_MAP_LUT1": "a", "AL_MAP_LUT2": "ab", "AL_MAP_LUT3": "abc",
        "AL_MAP_LUT4": "abcd", "AL_MAP_LUT5": "abcde"}

p = parse_netlist(sys.argv[1])
drv = {}
for name, v in p["insts"].items():
    for pin, val in v["pins"].items():
        if pin.lower() in OUT:
            drv.setdefault(val.strip().lstrip("\\"), (name, pin))


def show(net, depth=6, ind=""):
    net = net.strip().lstrip("\\")
    hit = drv.get(net)
    print(ind + net + ("  <- " + hit[0] + "." + hit[1] if hit else "  [LEAF]"))
    if not hit or depth <= 0:
        return
    name, pin = hit
    v = p["insts"][name]
    typ = v["type"]
    if typ in LUTS:
        print(ind + "  " + typ + " " + v["params"].replace("\n", " ")[:260])
        for pn in LUTS[typ]:
            val = v["pins"].get(pn)
            if val:
                for b in ([x.strip() for x in val.strip("{}").split(",")]):
                    show(b, depth - 1, ind + "    " + pn + ":")
    elif typ.startswith("EG_PHY_MSLICE"):
        print(ind + "  " + typ + " " + v["params"].replace("\n", " ")[:260])
        for pn, val in v["pins"].items():
            if pn.lower() in OUT:
                continue
            print(ind + "    .%s=%s" % (pn, val))
    elif typ == "AL_MAP_SEQ":
        print(ind + "  SEQ d=" + str(v["pins"].get("d")) + " q=" + str(v["pins"].get("q")))
    else:
        print(ind + "  " + typ + " " + str(v["pins"])[:200])


for n in sys.argv[2:]:
    print("=" * 100)
    show(n)
