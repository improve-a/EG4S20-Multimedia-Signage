#!/usr/bin/env python3
"""Limited scratch STA: remove only the root-reset removal false path.

Read-only w.r.t. production.  Copies the final routed DB into a fresh
diagnostic directory, copies the production SDC and deletes exactly the one
set_false_path -hold -from rst_all_reg line, imports the DB in a new TD
process, applies the modified user SDC, and reports timing.

No synthesis, PNR, fix_hold, bitgen, hardware, or automatic retry.
TD process is bounded to 120 s.  Production SDC/DB/bit hashes are checked
before and after.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
PROD_ROOT = Path(r"D:\FPGA\EG4S20-NoBot")
BUILD = PROD_ROOT / "output" / "html_fidelity" / "builds" / "no_bot_legacy_004"
PROD_SDC = BUILD / "work" / "design" / "user_source" / "constraints_source" / "timing.sdc"
PROD_DB = BUILD / "work" / "design" / "td_project" / "hx4s20_basic_Runs" / "phy_1" / "hx4s20_basic_pr.db"
PROD_BIT = BUILD / "work" / "design" / "td_project" / "hx4s20_basic_Runs" / "phy_1" / "hx4s20_basic.bit"
PROD_MAPPED = PROD_ROOT / "output" / "html_fidelity" / "no_bot" / "verify" / "routed_init_no_bot_legacy_004" / "mapped.v"
ORIG_FINAL = BUILD / "runs" / "no_bot_legacy_004" / "final_timing.rpt"
OUT = Path(r"D:\FPGA\EG4S20-NoBot-HWFix\output\offline_debug\ds1017_task_b_reset_sta")
TD_EXE = Path(r"G:\anlu\bin\td_commands_prompt.exe")
TIMEOUT_S = 120

RESET_LINE_PREFIX = "set_false_path -hold -from [get_regs {rst_all_reg}]"
TARGET_ENDPOINTS = {
    "rs_sd/pipe_reg[1]",
    "rs_mem/pipe_reg[1]",
    "rs_video/pipe_reg[1]",
    "frame_read_write_m0/mem_reset_sync_reg[1]",
    "frame_read_write_m0/write_reset_sync_reg[1]",
    "frame_read_write_m0/read_reset_sync_reg[0]",
    "frame_read_write_m0/read_reset_sync_reg[1]",
}


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")


def read_text_preserve_newlines(p: Path) -> str:
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        return f.read()


def parse_global(path: Path):
    txt = read_text(path)
    out = {}
    for key, pat in [
        ("SWNS", r"SWNS:\s*([-\d.]+)ns"),
        ("STNS", r"STNS:\s*([-\d.]+)ns"),
        ("HWNS", r"HWNS:\s*([-\d.]+)ns"),
        ("HTNS", r"HTNS:\s*([-\d.]+)ns"),
        ("coverage", r"STA coverage\s*:\s*([\d.]+)%"),
        ("period_wns", r"Period Check WNS:\s*([-\d.]+)ns"),
    ]:
        m = re.search(pat, txt)
        if m:
            out[key] = float(m.group(1))
    return out


def parse_groups(path: Path):
    lines = read_text(path).splitlines()
    groups = {}
    cur = None
    for i, line in enumerate(lines):
        m = re.match(r"\s*Path Group\s*:\s*(.*)", line)
        if m:
            cur = {"name": m.group(1).strip(), "line": i + 1, "max": None, "min": None}
            if cur["name"]:
                groups[cur["name"]] = cur
            continue
        if cur is None:
            continue
        m = re.match(
            r"\s*Max\s*:\s*SWNS\s*([-\d.]+)ns,\s*STNS\s*([-\d.]+)ns,\s*(\d+)\s*Viol Endpoints,\s*(\d+)\s*Total Endpoints,\s*(\d+)\s*Paths",
            line,
        )
        if m and cur["max"] is None:
            cur["max"] = [float(x) if j < 2 else int(x) for j, x in enumerate(m.groups())]
            continue
        m = re.match(
            r"\s*Min\s*:\s*HWNS\s*([-\d.]+)ns,\s*HTNS\s*([-\d.]+)ns,\s*(\d+)\s*Viol Endpoints,\s*(\d+)\s*Total Endpoints,\s*(\d+)\s*Paths",
            line,
        )
        if m and cur["min"] is None:
            cur["min"] = [float(x) if j < 2 else int(x) for j, x in enumerate(m.groups())]
    return groups


def endpoint_key(end: str) -> str:
    e = end.split("(")[0].strip().lstrip("\\")
    e = re.sub(r"\.sr$", "", e)
    e = re.sub(r"_syn_\d+$", "", e)
    return e


def parse_paths(path: Path):
    lines = read_text(path).splitlines()
    out = []
    cur = {}
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("Slack"):
            m = re.search(r"([-\d.]+)\s*ns", line)
            if m:
                cur = {"slack": float(m.group(1)), "slack_line": i + 1}
        elif "Begin Point" in line:
            cur["begin"] = line.split(":", 1)[1].strip()
        elif "End Point" in line:
            cur["end"] = line.split(":", 1)[1].strip()
        elif "Check Type" in line:
            cur["type"] = line.split(":", 1)[1].strip()
        elif "Process" in line:
            cur["process"] = line.split(":", 1)[1].strip()
        elif "Budget" in line:
            cur["budget"] = line.split(":", 1)[1].strip()
        elif "Data Path Delay" in line:
            m = re.search(r":\s*([\d.]+)\s*ns", line)
            if m:
                cur["data_ns"] = float(m.group(1))
        elif "Clock Skew" in line:
            m = re.search(r":\s*([-\d.]+)\s*ns", line)
            if m:
                cur["skew_ns"] = float(m.group(1))
        elif "Logic Level" in line:
            cur["logic_level"] = line.split(":", 1)[1].strip()
        elif "Max Fanout" in line:
            m = re.search(r":\s*(\d+)", line)
            if m:
                cur["max_fanout"] = int(m.group(1))
            if "slack" in cur and "type" in cur:
                out.append(cur.copy())
    return out


def removal_paths(path: Path):
    recs = [
        p
        for p in parse_paths(path)
        if p.get("type") == "removal"
        and p.get("begin", "").startswith("rst_all_reg")
        and ".sr" in p.get("end", "")
    ]
    best = {}
    for p in recs:
        k = endpoint_key(p["end"])
        if k not in best or p["slack"] < best[k]["slack"]:
            best[k] = p
    return [best[k] for k in sorted(best, key=lambda x: best[x]["slack"])], recs


def parse_constraints(ignored: Path, exceptions: Path, check: Path):
    it = read_text(ignored)
    et = read_text(exceptions)
    ct = read_text(check)
    return {
        "ignored_reset_false_path_present": "rst_all_reg" in it,
        "ignored_gray_false_path_count": it.count("primary_addr_gray_reg"),
        "ignored_gray_false_path_lines": [
            l.strip() for l in it.splitlines() if "set_false_path" in l and "primary_addr_gray_reg" in l
        ],
        "exceptions_gray_max_delay_count": et.count("primary_addr_gray_reg"),
        "exceptions_gray_max_delay_lines": [
            l.strip() for l in et.splitlines() if "set_max_delay" in l and "primary_addr_gray_reg" in l
        ],
        "check_summary_lines": ct.splitlines()[2:17],
        "check_shadowed_ignored_zero": "9. checking shadowed/ignored timing exception constraints(0)" in ct,
        "check_no_clock_zero": "1. checking no clock(0)" in ct,
        "check_invalid_zero": "There are 0 invalid constraints" in ct,
    }


def structure_check(mapped: Path):
    lines = read_text(mapped).splitlines()
    starts = [i for i, l in enumerate(lines) if re.match(r"^\s*EG_(PHY|LOGIC)_", l)]
    blocks = []
    for k, a in enumerate(starts):
        b = starts[k + 1] if k + 1 < len(starts) else len(lines)
        blocks.append((a, b))
    wanted = [
        "rs_sd/pipe_reg[1]",
        "rs_mem/pipe_reg[1]",
        "rs_video/pipe_reg[1]",
        "frame_read_write_m0/mem_reset_sync_reg[1]",
        "frame_read_write_m0/write_reset_sync_reg[1]",
        "frame_read_write_m0/read_reset_sync_reg[0]",
        "frame_read_write_m0/read_reset_sync_reg[1]",
    ]
    result = {}
    for name in wanted:
        found = None
        for a, b in blocks:
            txt = "\n".join(lines[a:b])
            if name in txt and ".sr(" in txt:
                found = (a, b, txt)
                break
        if not found:
            result[name] = {"found": False}
            continue
        a, b, txt = found
        result[name] = {
            "found": True,
            "start_line": a + 1,
            "end_line": b,
            "cemux_one": '.CEMUX("1")' in txt,
            "cemux_ce": '.CEMUX("CE")' in txt,
            "dffmode_ff": '.DFFMODE("FF")' in txt,
            "srmode_async": '.SRMODE("ASYNC")' in txt,
            "sr_rst_all": bool(re.search(r"\.sr\(rst_all\)", txt)),
            "reg0_regset_set": '.REG0_REGSET("SET")' in txt,
            "reg1_regset_set": '.REG1_REGSET("SET")' in txt,
            "reg0_sd_mi": '.REG0_SD("MI")' in txt,
            "reg1_sd_mi": '.REG1_SD("MI")' in txt,
            "reg0_sd_f": '.REG0_SD("F")' in txt,
            "reg1_sd_f": '.REG1_SD("F")' in txt,
            "mi_line": next((l.strip() for l in txt.splitlines() if ".mi(" in l), None),
            "q_line": next((l.strip() for l in txt.splitlines() if ".q(" in l), None),
            "sr_line": next((l.strip() for l in txt.splitlines() if ".sr(" in l), None),
            "holdbuf_in_block": "holdbuf" in txt,
        }
    return result


def main():
    if OUT.exists():
        raise SystemExit(f"ABORT: diagnostic directory already exists: {OUT}")
    OUT.mkdir(parents=True, exist_ok=False)
    # Keep a copy of this script with the measurement artifacts.
    shutil.copy2(Path(__file__), OUT / "run_reset_sta.py")

    # Preflight: no existing TD process.  Do not kill anything.
    pre = subprocess.run(
        ["tasklist", "/FO", "CSV", "/NH"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout.lower()
    busy = b"td_commands_prompt.exe" in pre or b"td.exe" in pre
    if busy:
        raise SystemExit("ABORT: a TD process is already running; no overlap allowed")

    before = {
        "sdc": sha256(PROD_SDC),
        "db": sha256(PROD_DB),
        "bit": sha256(PROD_BIT),
        "mapped": sha256(PROD_MAPPED),
    }

    # Copy DB.
    db_copy = OUT / "reset_pr.db"
    shutil.copy2(PROD_DB, db_copy)

    # Remove exactly one reset false-path line.
    sdc_lines = read_text_preserve_newlines(PROD_SDC).splitlines(keepends=True)
    hits = [i for i, l in enumerate(sdc_lines) if l.strip().startswith(RESET_LINE_PREFIX)]
    if len(hits) != 1:
        raise SystemExit(f"ABORT: expected exactly one reset false path, found {len(hits)}")
    removed = sdc_lines.pop(hits[0])
    modified_sdc = OUT / "reset_no_exception.sdc"
    modified_sdc.write_text("".join(sdc_lines), encoding="utf-8", newline="")
    if "set_false_path -hold -from [get_regs {rst_all_reg}]" in modified_sdc.read_text(encoding="utf-8"):
        raise SystemExit("ABORT: reset false path still present")
    if "create_clock" not in modified_sdc.read_text(encoding="utf-8"):
        raise SystemExit("ABORT: modified SDC looks truncated")

    # TCL: known harness workflow; no synthesis/PNR/bitgen.
    tcl = OUT / "reset_sta.tcl"
    q = lambda p: str(p).replace("\\", "/")
    tcl.write_text(
        "\n".join(
            [
                "import_device eagle_s20.db -package EG4S20BG256",
                f"import_db {{{q(db_copy)}}}",
                "clear_sdc -user",
                f"read_sdc {{{q(modified_sdc)}}}",
                "update_timing -mode final",
                f"report_timing_summary -file {{{q(OUT / 'reset_final_timing.rpt')}}} -ep_num 64 -path_num 2",
                f"report_timing_exception -file {{{q(OUT / 'reset_exceptions.rpt')}}} -ep_num 128 -path_num 2",
                f"report_timing_ignored -file {{{q(OUT / 'reset_ignored.rpt')}}} -ep_num 128 -path_num 2",
                f"report_clock_summary -file {{{q(OUT / 'reset_clocks.rpt')}}}",
                f"check_timing -verbose -file {{{q(OUT / 'reset_check.rpt')}}}",
                "exit 0",
                "",
            ]
        ),
        encoding="utf-8",
    )

    stdout_path = OUT / "td_stdout.log"
    stderr_path = OUT / "td_stderr.log"
    env = os.environ.copy()
    t0 = time.monotonic()
    timed_out = False
    exit_code = None
    pid = None
    with stdout_path.open("wb", buffering=0) as out, stderr_path.open("wb", buffering=0) as err:
        p = subprocess.Popen(
            [str(TD_EXE)],
            cwd=str(OUT),
            stdin=subprocess.PIPE,
            stdout=out,
            stderr=err,
            env=env,
        )
        pid = p.pid
        wrapper = (
            "if {[catch {source {%s}} codex_error]} "
            "{puts stderr $codex_error; exit 2}\nexit 2\n" % q(tcl)
        )
        p.stdin.write(wrapper.encode("utf-8"))
        p.stdin.close()
        try:
            exit_code = p.wait(timeout=TIMEOUT_S)
        except subprocess.TimeoutExpired:
            timed_out = True
            subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
            exit_code = p.wait(timeout=15)
    elapsed = round(time.monotonic() - t0, 3)

    after = {
        "sdc": sha256(PROD_SDC),
        "db": sha256(PROD_DB),
        "bit": sha256(PROD_BIT),
        "mapped": sha256(PROD_MAPPED),
    }
    production_unchanged = before == after

    # Reports.
    final = OUT / "reset_final_timing.rpt"
    ignored = OUT / "reset_ignored.rpt"
    exceptions = OUT / "reset_exceptions.rpt"
    check = OUT / "reset_check.rpt"
    clocks = OUT / "reset_clocks.rpt"

    result = {
        "status": "TIMEOUT" if timed_out else ("FINISHED" if exit_code == 0 else "FAILED"),
        "measurement_label": "INPUT_TIMING_EXCEPTION_MEASURED",
        "functional_label": "FUNCTIONAL_ROOT_CAUSE_NOT_CONFIRMED",
        "out_dir": str(OUT),
        "production_unchanged": production_unchanged,
        "before": before,
        "after": after,
        "copied_db_sha256": sha256(db_copy),
        "modified_sdc_sha256": sha256(modified_sdc),
        "modified_sdc_line_count": len(modified_sdc.read_text(encoding="utf-8").splitlines()),
        "removed_line": {"original_line_no": hits[0] + 1, "text": removed.strip()},
        "td": {
            "exe": str(TD_EXE),
            "exe_sha256": sha256(TD_EXE),
            "cwd": str(OUT),
            "pid": pid,
            "exit_code": exit_code,
            "elapsed_seconds": elapsed,
            "timeout_seconds": TIMEOUT_S,
            "timed_out": timed_out,
            "stdout_bytes": stdout_path.stat().st_size,
            "stderr_bytes": stderr_path.stat().st_size,
        },
        "reports": {p.name: sha256(p) for p in [final, ignored, exceptions, check, clocks] if p.exists()},
        "constraints": parse_constraints(ignored, exceptions, check) if all(p.exists() for p in [ignored, exceptions, check]) else None,
        "structure": structure_check(PROD_MAPPED),
    }

    if final.exists():
        result["global"] = parse_global(final)
        result["groups"] = parse_groups(final)
        result["removal_paths"], result["all_reset_removal_rows"] = removal_paths(final)
        result["original_global"] = parse_global(ORIG_FINAL)
        orig_groups = parse_groups(ORIG_FINAL)
        result["original_groups"] = orig_groups

        # Compare group statistics.  Only the three clk->domain Min rows may change.
        changes = {}
        for name, g in orig_groups.items():
            ng = result["groups"].get(name)
            if ng is None:
                changes[name] = {"missing_in_new": True}
            elif g["max"] != ng["max"] or g["min"] != ng["min"]:
                changes[name] = {
                    "before_max": g["max"],
                    "after_max": ng["max"],
                    "before_min": g["min"],
                    "after_min": ng["min"],
                }
        result["group_changes"] = changes
        allowed = {"clk -> sd_card_clk", "clk -> ext_mem_clk", "clk -> video_clk"}
        result["unexpected_group_changes"] = {
            k: v for k, v in changes.items() if k not in allowed
        }
    else:
        result["global"] = None
        result["removal_paths"] = []

    (OUT / "reset_sta_result.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
