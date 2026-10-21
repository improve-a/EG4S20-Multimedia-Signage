#!/usr/bin/env python3
"""Extract the AXIS receiver contract cone from a TD write_verilog netlist.

Read-only. Reuses worker_a/netcmp.py (parse_netlist). This does NOT compare the
whole design and does not re-synthesise anything. It walks only the cones that
matter to the question:

  O_axis_s_ready / S_video_in_ready      - registered ready output
  S_fifo_pro_full                        - programmable-full status
  I_fifo_rd_en                           - FIFO read enable
  O_video_source_pause / O_video_locked  - SOF/SOL/lock feedback
  BRAM .wea                              - what actually writes the FIFO

Usage:
  python axis_extract.py <gate.v> <label> <out.txt>
"""
import sys
import re
from collections import Counter

sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist  # noqa: E402

OUT_PINS = {"q", "o", "Q", "O", "f", "fx", "fco", "dob", "co", "dout"}
LUTS = {"AL_MAP_LUT1": 1, "AL_MAP_LUT2": 2, "AL_MAP_LUT3": 3,
        "AL_MAP_LUT4": 4, "AL_MAP_LUT5": 5}
RX = "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver"
FIFO = RX + "/u_w24_d1024_fifo"


def bits(val):
    val = val.strip()
    if val.startswith("{") and val.endswith("}"):
        return [x.strip() for x in val[1:-1].split(",")]
    return [val]


def clean(n):
    return n.strip().lstrip("\\")


def build(p):
    drv = {}
    for name, v in p["insts"].items():
        for pin, val in v["pins"].items():
            if pin.lower() in OUT_PINS:
                for i, b in enumerate(bits(val)):
                    drv.setdefault(clean(b), (name, pin, i))
    return drv


def leaves_expr(p, drv, net, depth, seen=None, max_depth=20):
    """Return (expr, leaves) for a net. LUTs/BUFKEEP expanded; SEQ/BRAM/ports stop."""
    if seen is None:
        seen = set()
    net = clean(net)
    hit = drv.get(net)
    if hit is None:
        return ("LEAF:" + net, {(net, "undriven/port")})
    name, pin, idx = hit
    v = p["insts"][name]
    typ = v["type"]
    if typ in LUTS:
        if depth <= 0:
            return ("CUT:" + name, {(name, typ + ".o")})
        args = []
        lv = set()
        for pn in "abcde"[:LUTS[typ]]:
            val = v["pins"].get(pn)
            if val is None:
                args.append("0")
                continue
            bs = bits(val)
            b = bs[idx] if idx < len(bs) else bs[0]
            e, l = leaves_expr(p, drv, b, depth - 1, seen, max_depth)
            args.append(e)
            lv |= l
        eq = re.search(r'\.EQN\("([^"]*)"\)', v["params"])
        init = re.search(r"\.INIT\(([^()]*)\)", v["params"])
        tag = typ.replace("AL_MAP_", "")
        return ("%s[%s](%s)" % (tag, (eq.group(1) if eq else (init.group(1) if init else "")),
                                ",".join(args)), lv)
    if typ in ("AL_BUFKEEP", "AL_MAP_BUF"):
        val = v["pins"].get("i") or v["pins"].get("I")
        if val is None:
            return ("BUF?", {(name, typ)})
        bs = bits(val)
        b = bs[idx] if idx < len(bs) else bs[0]
        return leaves_expr(p, drv, b, depth, seen, max_depth)
    if typ == "AL_MAP_SEQ":
        return ("SEQQ:" + name, {(name, "SEQ.Q")})
    if typ.startswith("EG_PHY_BRAM"):
        return ("BRAMOUT:" + name, {(name, typ)})
    # unsupported cell: stop
    return ("CELL:" + name + ":" + typ, {(name, typ)})


def report_net(p, drv, label, net):
    lines = []
    hit = drv.get(clean(net))
    lines.append("### %s  net=%s" % (label, net))
    if not hit:
        lines.append("  NO DRIVER (top-level port or constant)")
        return lines
    name, pin, idx = hit
    lines.append("  driver: %s .%s[%d] type=%s" % (name, pin, idx, p["insts"][name]["type"]))
    expr, lv = leaves_expr(p, drv, net, 10)
    lines.append("  expr: " + expr[:6000])
    lines.append("  leaves (%d):" % len(lv))
    for n, t in sorted(lv):
        lines.append("    %-90s %s" % (n, t))
    return lines


def main():
    path, label, out = sys.argv[1:4]
    p = parse_netlist(path)
    drv = build(p)
    L = []
    L.append("===== %s  %s" % (label, path))
    rx_cells = [n for n in p["insts"] if n == RX or n.startswith(RX + "/")]
    L.append("receiver subtree cells: %d" % len(rx_cells))
    tc = Counter(p["insts"][n]["type"] for n in rx_cells)
    L.append("  types: " + ", ".join("%s=%d" % kv for kv in sorted(tc.items())))
    # list all SEQ in receiver with D/Q/CE/SR
    L.append("")
    L.append("-- receiver sequentials --")
    for n in sorted(rx_cells):
        v = p["insts"][n]
        if v["type"] == "AL_MAP_SEQ":
            pp = v["pins"]
            L.append("  %-100s clk=%-28s d=%-80s q=%-80s ce=%s sr=%s" % (
                n, pp.get("clk", "?"), pp.get("d", "?"), pp.get("q", "?"),
                pp.get("ce", "?"), pp.get("sr", "?")))
    # FIFO BRAM pins
    L.append("")
    L.append("-- FIFO BRAM write/read controls --")
    for n, v in sorted(p["insts"].items()):
        if n.startswith(FIFO + "/") and v["type"].startswith("EG_PHY_BRAM"):
            pp = v["pins"]
            L.append("  %s" % n)
            for k in ("wea", "ceb", "rsta", "rstb", "clka", "clkb"):
                L.append("    .%s(%s)" % (k, pp.get(k, "?")))
    L.append("")
    for label2, net in [
        ("O_axis_s_ready (wrapper port net)", RX.replace("/u_video_axi_stream_receiver", "") + "/O_axis_s_ready"),
        ("S_video_in_ready", RX + "/S_video_in_ready"),
        ("S_video_in_ready D", RX + "/S_video_in_ready_reg_syn_3"),
        ("S_fifo_pro_full", RX + "/S_fifo_pro_full"),
        ("I_fifo_rd_en", FIFO + "/I_fifo_rd_en"),
        ("I_fifo_rd_en_syn_8", FIFO + "/I_fifo_rd_en_syn_8"),
        ("O_video_source_pause", RX + "/O_video_source_pause"),
        ("O_video_source_pause D", RX + "/O_video_source_pause_reg_syn_3"),
        ("O_video_locked", RX + "/O_video_locked"),
        ("O_video_locked D", RX + "/O_video_locked_reg_syn_3"),
        ("I_video_source_sol", RX + "/I_video_source_sol"),
    ]:
        try:
            L += report_net(p, drv, label2, net)
        except Exception as e:  # noqa: BLE001
            L.append("### %s ERROR %r" % (label2, e))
        L.append("")
    text = "\n".join(L)
    open(out, "w", encoding="utf-8").write(text)
    print(text[:12000])


if __name__ == "__main__":
    main()
