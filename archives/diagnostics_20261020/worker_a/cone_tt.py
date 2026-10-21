"""Bounded truth-table check for a small combinational cone in a TD gate netlist.

Usage:
  cone_tt.py A.v B.v TOP_NET_A TOP_NET_B [max_vars]

Only LUT1..LUT5 (INIT), AL_BUFKEEP (o=i), AL_MAP_SEQ (Q = free variable) are
modelled.  Any other primitive output met in the cone becomes a free variable
and is reported.  Refuses to run above max_vars (default 16).

Prints variable sets and whether the two truth tables are identical over the
same variables (after alias normalisation of probe/* names).
Boundary: this proves equality only for the extracted combinational cone under
the assumption that every leaf (FF Q, BRAM output, other primitive output) is a
free input; it says nothing about sequential behaviour.
"""
import re
import sys

sys.path.insert(0, ".")
from netcmp import parse_netlist  # noqa: E402

OUT_PINS = {"q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"}
LUTS = {"AL_MAP_LUT1": 1, "AL_MAP_LUT2": 2, "AL_MAP_LUT3": 3,
        "AL_MAP_LUT4": 4, "AL_MAP_LUT5": 5}

ALIAS = {
    "probe/au": "u_hdmi_1_4b_transmitter_core_wrapper/I_axis_s_user",
    "probe/av": "u_hdmi_1_4b_transmitter_core_wrapper/I_axis_s_valid",
    "probe/locked": "u_hdmi_1_4b_transmitter_core_wrapper/O_video_locked",
    "probe/al": "u_video_rgb_to_axis_640x480/O_video_last",
    "probe/vs": "u_video_rgb_to_axis_640x480/I_vs",
    "audio_valid": "acr/I_audio_valid",
}


def norm_net(n):
    n = n.strip().lstrip("\\")
    return ALIAS.get(n, n)


def pin_bits(val):
    val = val.strip()
    if val.startswith("{") and val.endswith("}"):
        return [x.strip() for x in val[1:-1].split(",")]
    return [val]


def build(path):
    p = parse_netlist(path)
    drv = {}
    for name, v in p["insts"].items():
        for pin, val in v["pins"].items():
            if pin in OUT_PINS:
                for i, b in enumerate(pin_bits(val)):
                    drv.setdefault(norm_net(b), (name, pin, i))
    return p, drv


def init_of(params):
    m = re.search(r"\.INIT\(([^()]*)\)", params)
    if not m:
        return None
    s = m.group(1).strip()
    if "'" in s:
        _, rest = s.split("'", 1)
        base = rest[0].lower()
        digits = rest[1:].replace("_", "")
        return int(digits, 16 if base == "h" else 2)
    return int(s, 10)


def cone(path, top, max_vars):
    p, drv = build(path)
    order = []
    seen = {}
    stats = {"luts": 0, "depth": 0, "unsupported": set()}

    def var(net):
        if net not in seen:
            seen[net] = len(order)
            order.append(net)
            if len(order) > max_vars:
                raise SystemExit("too many variables (>%d)" % max_vars)
        return ("var", seen[net])

    def walk(net, d):
        net = norm_net(net)
        stats["depth"] = max(stats["depth"], d)
        hit = drv.get(net)
        if hit is None:
            return var(net)
        name, pin, idx = hit
        v = p["insts"][name]
        typ = v["type"]
        if typ in LUTS:
            stats["luts"] += 1
            args = []
            for pn in "abcde"[:LUTS[typ]]:
                val = v["pins"].get(pn)
                if val is None:
                    args.append(("const", 0))
                    continue
                bits = pin_bits(val)
                b = bits[idx] if idx < len(bits) else bits[0]
                args.append(walk(b, d + 1))
            return ("lut", init_of(v["params"]), args)
        if typ == "AL_BUFKEEP":
            bits = pin_bits(v["pins"].get("i", ""))
            b = bits[idx] if idx < len(bits) else bits[0]
            return walk(b, d)
        if typ == "AL_MAP_SEQ":
            return var(net)
        stats["unsupported"].add(typ)
        return var(net)

    tree = walk(top, 0)
    return order, tree, stats


def eval_tree(node, bits, own_to_shared):
    kind = node[0]
    if kind == "var":
        return (bits >> own_to_shared[node[1]]) & 1
    if kind == "const":
        return node[1]
    _, init, args = node
    idx = 0
    for i, a in enumerate(args):
        idx |= eval_tree(a, bits, own_to_shared) << i
    return (init >> idx) & 1 if init is not None else 0


def run(a_path, b_path, top_a, top_b, max_vars):
    oa, ta, sa = cone(a_path, top_a, max_vars)
    ob, tb, sb = cone(b_path, top_b, max_vars)
    for tag, o, s in (("A", oa, sa), ("B", ob, sb)):
        print("%s vars=%d luts=%d depth=%d unsupported=%s" %
              (tag, len(o), s["luts"], s["depth"], sorted(s["unsupported"]) or "none"))
        for n in o:
            print("   var", n)
    names_a, names_b = set(oa), set(ob)
    if names_a != names_b:
        print("VAR SET DIFF")
        for n in sorted(names_a - names_b):
            print("  ONLY_A", n)
        for n in sorted(names_b - names_a):
            print("  ONLY_B", n)
        return 2
    order = sorted(names_a)
    pos = {n: i for i, n in enumerate(order)}
    map_a = {i: pos[n] for i, n in enumerate(oa)}
    map_b = {i: pos[n] for i, n in enumerate(ob)}
    n = len(order)
    print("enumerating 2^%d = %d" % (n, 1 << n))
    for bits in range(1 << n):
        va = eval_tree(ta, bits, map_a)
        vb = eval_tree(tb, bits, map_b)
        if va != vb:
            print("MISMATCH", {order[i]: (bits >> pos[order[i]]) & 1 for i in range(n)},
                  "A=", va, "B=", vb)
            return 1
    print("TRUTH_TABLES_IDENTICAL over %d variables" % n)
    return 0


if __name__ == "__main__":
    a, b, ta, tb = sys.argv[1:5]
    mv = int(sys.argv[5]) if len(sys.argv) > 5 else 16
    sys.exit(run(a, b, ta, tb, mv))
