#!/usr/bin/env python3
"""Generate audit evidence files from the independently parsed TD reports (read-only)."""
import json, re, hashlib, os, collections

BASE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(BASE, "evidence")
os.makedirs(EV, exist_ok=True)

parsed = json.load(open(os.path.join(BASE, "reports/parsed_timing.json")))
hdr = parsed["header"]
groups = parsed["groups"]
wbc = parsed["worst_by_check"]

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

# ---------------- groups.csv
with open(os.path.join(EV, "groups.csv"), "w") as f:
    f.write("type,path_group,max_SWNS,max_STNS,max_viol_ep,max_total_ep,max_paths,min_HWNS,min_HTNS,min_viol_ep,min_total_ep,min_paths\n")
    for g in groups:
        f.write(",".join(str(x) for x in [
            g.get("type"), '"%s"' % g["path_group"].replace('"', "'"),
            g.get("max_SWNS"), g.get("max_STNS"), g.get("max_viol_ep"), g.get("max_total_ep"), g.get("max_paths"),
            g.get("min_HWNS"), g.get("min_HTNS"), g.get("min_viol_ep"), g.get("min_total_ep"), g.get("min_paths"),
        ]) + "\n")

# ---------------- checks
populated = [g for g in groups if (g.get("min_total_ep") or 0) > 0]
empty_min = [g for g in groups if (g.get("min_total_ep") or 0) == 0]
sum_stns = round(sum(g.get("max_STNS", 0.0) for g in groups), 3)
sum_viol = sum(g.get("max_viol_ep", 0) for g in groups)
worst_sw = min(g.get("max_SWNS", 0.0) for g in groups)
worst_hw = min(g.get("min_HWNS", 0.0) for g in populated)
sum_min_viol = sum(g.get("min_viol_ep", 0) for g in groups)
total_ep = sum(g.get("max_total_ep", 0) for g in groups)

checks = {
    "source": "final_timing.rpt (independently re-parsed)",
    "global": hdr,
    "global_SWNS_equals_min_group_SWNS": {"value": worst_sw, "header": hdr["SWNS"], "pass": abs(worst_sw - hdr["SWNS"]) < 1e-6},
    "global_STNS_equals_sum_group_STNS": {"sum": sum_stns, "header": hdr["STNS"], "pass": abs(sum_stns - hdr["STNS"]) < 1e-6},
    "global_S_failing_endpoints_equals_sum_group": {"sum": sum_viol, "route_qor": 304, "pass": sum_viol == 304},
    "global_HWNS_equals_min_group_HWNS_over_nonempty_min_groups": {"value": worst_hw, "header": hdr["HWNS"], "pass": abs(worst_hw - hdr["HWNS"]) < 1e-6},
    "empty_min_groups_placeholders": [{"path_group": g["path_group"], "type": g.get("type"), "min_HWNS": g.get("min_HWNS"), "min_total_ep": g.get("min_total_ep")} for g in empty_min],
    "sum_min_violated_endpoints": sum_min_viol,
    "total_endpoints_all_groups": total_ep,
    "failing_setup_fraction": round(sum_viol / total_ep, 5),
    "worst_by_check": {k: {"slack": v["worst"]["slack"], "group": v["worst"].get("group"), "process": v["worst"].get("process"),
                           "logic_level": v["worst"].get("logic_level"), "data_delay": v["worst"].get("data_delay"),
                           "begin": v["worst"].get("begin"), "end": v["worst"].get("end")} for k, v in wbc.items()},
    "negative_displayed_entries": {k: v["negative_count"] for k, v in wbc.items()},
    "displayed_entries": {k: v["count_in_detail"] for k, v in wbc.items()},
    "group_count": len(groups),
}
json.dump(checks, open(os.path.join(EV, "checks.json"), "w"), indent=1)

# ---------------- hashes (local copies + artifacts.json cross-check)
_art_all = json.load(open(os.path.join(BASE, "reports/artifacts.json")))
# prefer the run-directory copy when several artifacts share a basename (e.g. phy_1/final_timing.rpt)
art = {}
for a in _art_all:
    name = a["path"].replace("\\", "/").split("/")[-1]
    if name not in art or "\\runs\\" in a["path"]:
        art[name] = a["sha256"]
lines = []
for name in ["final_timing.rpt", "final_area.rpt", "check_timing.rpt", "ignored_timing.rpt", "exceptions.rpt",
             "before_hold_fix.rpt", "after_hold_fix.rpt", "clocks.rpt", "status.json", "artifacts.json", "build.tcl",
             "timing.sdc", "stdout.log", "route.qor", "place.qor", "hx4s20_basic_phy.area"]:
    p = os.path.join(BASE, "reports", name)
    if not os.path.exists(p):
        lines.append("%-26s MISSING" % name)
        continue
    s = sha(p)
    ref = art.get(name)
    tag = "" if ref is None else (" MATCH artifacts.json" if ref == s else " MISMATCH artifacts.json(%s)" % ref)
    lines.append("%s  %s%s" % (s, name, tag))
bitp = os.path.join(BASE, "bit/bot_hdmi_probe_infer_add_off_001.bit")
lines.append("%s  bit/bot_hdmi_probe_infer_add_off_001.bit (delivered; claim 49c9eeab...6151)" % sha(bitp))
prep = os.path.join(BASE, "bit/best_result_hx4s20_basic.bit")
if os.path.exists(prep):
    lines.append("%s  bit/best_result_hx4s20_basic.bit (pre-fix route-stage copy, artifacts.json  f94654e6...c886f)" % sha(prep))
lines.append("%s  reports/phy1_final_timing.rpt (TD route-stage report, HWNS -0.044)"
             % sha(os.path.join(BASE, "reports/phy1_final_timing.rpt")))
open(os.path.join(EV, "hashes.txt"), "w").write("\n".join(lines) + "\n")

# ---------------- area / slices
area = open(os.path.join(BASE, "reports/final_area.rpt")).read()
def grab(k):
    m = re.search(r"^%s\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%%" % re.escape(k), area, re.M)
    return (int(m.group(1)), int(m.group(2)), float(m.group(3))) if m else None
slices = {
    "final_area_has_MSLICE_token": bool(re.search(r"MSLICE|LSLICE", area, re.I)),
    "final_area_counts": {k: grab(k) for k in ["#lut", "#reg", "#bram", "#dsp", "#pll", "#gclk"]},
    "final_area_le": int(re.search(r"^#le\s+(\d+)", area, re.M).group(1)),
    "route_qor_slices": 9084,
    "route_qor_slices_pct": 92.69,
    "route_log_last_mslices": 4542,
    "route_log_last_lslices": 4542,
    "route_log_earlier_mslices_after_place": 4527,
    "area_identical_to_route_stage_phy_area": sha(os.path.join(BASE, "reports/final_area.rpt")) == sha(os.path.join(BASE, "reports/hx4s20_basic_phy.area")),
    "device_slice_capacity_implied": 9084 / 0.9269,
    "mslice_pct_of_4900": round(4542 / 4900 * 100, 2),
    "le_per_used_slice": round(17822 / 9084, 3),
}
json.dump(slices, open(os.path.join(EV, "slices.json"), "w"), indent=1)

# ---------------- hold-fix timeline
log = open(os.path.join(BASE, "reports/stdout.log"), errors="replace").read().splitlines()
keep = [l for l in log if re.search(r"Hold Fix|hold fix|hold fixing|HWNS|violation on|EP fixed|Bridge count|update_timing -mode final", l)]
open(os.path.join(EV, "holdfix_timeline.txt"), "w").write("\n".join(keep) + "\n")

print(json.dumps(checks["global"], indent=1))
print("STNS sum", sum_stns, "viol", sum_viol, "HWNS", worst_hw, "minViolSum", sum_min_viol, "totalEP", total_ep)
print(json.dumps(slices, indent=1))
print(open(os.path.join(EV, "hashes.txt")).read())
