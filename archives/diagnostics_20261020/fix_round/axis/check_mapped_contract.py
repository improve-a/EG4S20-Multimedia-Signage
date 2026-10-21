#!/usr/bin/env python3
"""Static checks on the extracted mapped-netlist snippets (read-only evidence).

The snippets were produced by contract_snippets.py from:
  * netcheck/rca_no_locked_003/gate.v   (experiment A, full probe)
  * worker_a/b_gate.v                  (successful Probe baseline)
  * netcheck/rca_locked_only_001/gate.v (experiment B, locked-only display)

This is not a full-netlist proof. It only checks the cells that implement the
RX handshake/status path.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EVID = os.path.join(HERE, "evidence")


def blocks(path):
    out = {}
    cur = None
    for line in open(path, encoding="utf-8"):
        if line.startswith("---- "):
            cur = line[5:].strip()
            out[cur] = []
        elif cur:
            out[cur].append(line.rstrip("\n"))
    return out


def joined(blocks_, name):
    return "\n".join(blocks_.get(name, []))


def find_block(blocks_, needle):
    for name, lines in blocks_.items():
        txt = "\n".join(lines)
        if needle in txt:
            return name, txt
    return None, ""


def check(label, path, wea_net, ready_expected):
    b = blocks(path)
    rows = []
    ok = True

    def need(cond, msg):
        nonlocal ok
        rows.append((bool(cond), msg))
        if not cond:
            ok = False

    ready_lut = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/S_video_in_ready_reg_syn_4")
    ready_reg = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/S_video_in_ready_reg")
    if ready_expected:
        need("AL_MAP_LUT3" in ready_lut, "ready next-state is LUT3")
        need("~C*~(~B*~A)" in ready_lut, "ready equation is !last && (empty || ready)")
        need("S_fifo_empty" in ready_lut, "ready uses S_fifo_empty")
        need("S_video_in_ready" in ready_lut, "ready uses its own state")
        need("probe/al" in ready_lut, "ready uses I_axis_s_last")
        need('REGSET("SET")' in ready_reg, "ready FF is reset/preset to 1 (SET)")
    else:
        need("MISSING" in ready_lut, "fixed-name ready next-state node absent (name-level only; not whole-branch proof)")
        need("MISSING" in ready_reg, "fixed-name ready FF absent (name-level only; not whole-branch proof)")

    for n in ("u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_380",
              "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_390",
              "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_400"):
        txt = joined(b, n)
        need((".wea=\\" + wea_net) in txt, "BRAM %s.wea = valid (%s)" % (n.rsplit("_", 1)[-1], wea_net))
        need("ready" not in txt.split(".wea=")[1].splitlines()[0], "BRAM wea does not use ready")

    if ready_expected:
        _, rd = find_block(b, "I_fifo_rd_en_syn_8")
        need("AL_MAP_LUT2" in rd, "rd_en final gate is LUT2")
        need("(B*~A)" in rd, "rd_en = period && !empty")
        need("S_fifo_empty" in rd, "rd_en uses S_fifo_empty")
        need("I_fifo_rd_en" in rd, "rd_en second input is the video-source period")

    ptr = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo[0]")
    need('SRMODE("ASYNC")' in ptr, "FIFO pointer FF physical SRMODE is ASYNC")
    need("I_rst" in ptr, "FIFO pointer FF sr is I_rst")
    bram = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_380")
    need('RESETMODE("SYNC")' in bram, "video BRAM reset mode is SYNC")

    frst = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/I_rst_syn_7")
    need("AL_MAP_LUT2" in frst, "FIFO reset is LUT2")
    need("~(B*~A)" in frst, "FIFO reset = core_rst | !locked")
    need("O_video_locked" in frst or "probe/locked" in frst, "FIFO reset consumes real locked")

    locked = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_4")
    user_ok = ("I_axis_s_user" in locked) or ("probe/au" in locked)
    valid_ok = ("I_axis_s_valid" in locked) or ("probe/av" in locked)
    need("I_video_source_sol" in locked and "O_video_source_pause" in locked
         and user_ok and valid_ok,
         "locked D = f(sol, locked, pause, user, valid)")
    need("ready" not in locked, "locked D does not use ready")

    pause = joined(b, "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_source_pause_reg_syn_4")
    user_ok = ("I_axis_s_user" in pause) or ("probe/au" in pause)
    need("I_video_source_sof" in pause and "O_video_source_pause" in pause
         and user_ok, "pause D = f(sof, locked, pause, user)")
    need("ready" not in pause, "pause D does not use ready")

    return {"label": label, "file": path, "ok": ok,
            "checks": [{"ok": c, "what": w} for c, w in rows]}


def check_expB_rd_en():
    path = os.path.join(EVID, "expB_rd_en_cone.txt")
    t = open(path, encoding="utf-8").read()
    checks = [
        ("I_fifo_rd_en_syn_8" in t, "experimentB: rd_en cone root is I_fifo_rd_en_syn_8"),
        ("AL_MAP_LUT4" in t, "experimentB: rd_en final gate is a LUT4"),
        ("(D*~(C*B*A))" in t, "experimentB: rd_en = period && !empty"),
        ("O_video_period_reg" in t, "experimentB: rd_en uses the decoded video period"),
        ("(~(D@B)*~(C@A))" in t, "experimentB: 11-bit pointer equality (empty) logic is present"),
        ("u_logic_ramfifo" in t, "experimentB: rd_en cone reaches the FIFO pointer FFs"),
    ]
    return {"label": "experimentB_rd_en", "file": path,
            "ok": all(c for c, _ in checks),
            "checks": [{"ok": c, "what": w} for c, w in checks]}


def check_route():
    path = os.path.join(EVID, "route_check_expA.txt")
    t = open(path, encoding="utf-8").read()
    checks = [
        ("wea using ready: []" in t, "post-route: no BRAM wea uses ready"),
        ("ready cell has S_fifo_empty: True" in t, "post-route: ready cell sees S_fifo_empty"),
        ("ready cell has probe/al: True" in t, "post-route: ready cell sees last"),
        ('LUTF0("(~C*~(~B*~D))")' in t, "post-route: ready function !last&&(ready||empty)"),
        ("\\probe/av_syn_36" in t, "post-route: video FIFO wea is valid alias"),
    ]
    return {"label": "experimentA_route", "file": path,
            "ok": all(c for c, _ in checks),
            "checks": [{"ok": c, "what": w} for c, w in checks]}


def main():
    out = []
    out.append(check("experimentA", os.path.join(EVID, "snippets_expA.txt"), "probe/av_syn_36", True))
    out.append(check("probe", os.path.join(EVID, "snippets_probe.txt"), "probe/av_syn_36", True))
    out.append(check("experimentB", os.path.join(EVID, "snippets_expB.txt"), "probe/av_syn_4", False))
    out.append(check_expB_rd_en())
    out.append(check_route())
    for r in out:
        print(("PASS " if r["ok"] else "FAIL ") + r["label"])
        for c in r["checks"]:
            print("  [%s] %s" % ("ok" if c["ok"] else "FAIL", c["what"]))
    print(json.dumps(out, indent=1))
    return 0 if all(r["ok"] for r in out) else 1


if __name__ == "__main__":
    sys.exit(main())
