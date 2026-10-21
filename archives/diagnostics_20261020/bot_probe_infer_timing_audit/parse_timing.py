#!/usr/bin/env python3
"""Read-only parser for Tang Dynasty final_timing.rpt (independent audit)."""
import json, re, sys, collections

path = sys.argv[1]
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()

# ---- header / timing status
hdr = {}
for i, l in enumerate(lines[:40]):
    m = re.match(r"\s*SWNS:\s*(-?[\d.]+)ns,\s*STNS:\s*(-?[\d.]+)ns", l)
    if m: hdr["SWNS"], hdr["STNS"] = float(m.group(1)), float(m.group(2))
    m = re.match(r"\s*HWNS:\s*(-?[\d.]+)ns,\s*HTNS:\s*(-?[\d.]+)ns", l)
    if m: hdr["HWNS"], hdr["HTNS"] = float(m.group(1)), float(m.group(2))
    m = re.match(r"\s*Period Check WNS:\s*(-?[\d.]+)ns", l)
    if m: hdr["PeriodCheckWNS"] = float(m.group(1))
    if l.startswith("STA coverage"):
        hdr["coverage"] = l.split(":", 1)[1].strip()
    if l.startswith("Report Scheme"):
        hdr["scheme"] = l.split(":", 1)[1].strip()
    if l.startswith("Check Corner"):
        hdr["corner"] = l.split(":", 1)[1].strip()

# ---- groups
groups = []
i = 0
while i < len(lines):
    if lines[i].startswith("Path Group"):
        g = {"path_group": lines[i].split(":", 1)[1].strip(), "line": i + 1}
        j = i + 1
        # constraint text line may follow (SMD)
        while j < len(lines) and not lines[j].strip().startswith("Type"):
            if lines[j].strip() and not lines[j].startswith("Path Group"):
                g["constraint_text"] = lines[j].strip()
            j += 1
        while j < len(lines) and j < i + 20:
            s = lines[j].strip()
            if s.startswith("Type"): g["type"] = s.split(":", 1)[1].strip()
            if s.startswith("From Clock"): g["from_clock"] = s.split(":", 1)[1].strip()
            if s.startswith("To Clock"): g["to_clock"] = s.split(":", 1)[1].strip()
            if s.startswith("Min Period"): g["min_period"] = s.split(":", 1)[1].strip()
            if s.startswith("Fmax"): g["fmax"] = s.split(":", 1)[1].strip()
            if s.startswith("Max ") and "SWNS" in s:
                g["max_stats"] = s
                mm = re.search(r"SWNS\s+(-?[\d.]+)ns,\s+STNS\s+(-?[\d.]+)ns,\s+(\d+)\s+Viol Endpoints,\s+(\d+)\s+Total Endpoints,\s+(\d+)\s+Paths", s)
                if mm:
                    g["max_SWNS"], g["max_STNS"] = float(mm.group(1)), float(mm.group(2))
                    g["max_viol_ep"], g["max_total_ep"], g["max_paths"] = map(int, mm.group(3, 4, 5))
            if s.startswith("Min ") and "HWNS" in s:
                g["min_stats"] = s
                mm = re.search(r"HWNS\s+(-?[\d.]+)ns,\s+HTNS\s+(-?[\d.]+)ns,\s+(\d+)\s+Viol Endpoints,\s+(\d+)\s+Total Endpoints,\s+(\d+)\s+Paths", s)
                if mm:
                    g["min_HWNS"], g["min_HTNS"] = float(mm.group(1)), float(mm.group(2))
                    g["min_viol_ep"], g["min_total_ep"], g["min_paths"] = map(int, mm.group(3, 4, 5))
            if s.startswith("Max Paths"): g["detail_start"] = j
            if s.startswith("Min Paths"): g["min_detail_start"] = j
            if s.startswith("Path Group") or s.startswith("Intra clock") or s.startswith("Inter clock"):
                break
            j += 1
        g["end"] = j
        groups.append(g)
        i = j
    else:
        i += 1

# ---- detailed path metadata blocks
details = []
for k, l in enumerate(lines):
    m = re.match(r"Slack\s+:\s+(-?[\d.]+)ns", l)
    if m:
        d = {"slack": float(m.group(1)), "line": k + 1, "section": None}
        for o in range(k + 1, min(k + 14, len(lines))):
            s = lines[o].strip()
            if s.startswith("Begin Point"): d["begin"] = s.split(":", 1)[1].strip()
            elif s.startswith("End Point"): d["end"] = s.split(":", 1)[1].strip()
            elif s.startswith("Check Type"): d["check"] = s.split(":", 1)[1].strip()
            elif s.startswith("Process"): d["process"] = s.split(":", 1)[1].strip()
            elif s.startswith("Logic Level"): d["logic_level"] = s.split(":", 1)[1].strip()
            elif s.startswith("Data Path Delay"): d["data_delay"] = s.split(":", 1)[1].strip()
            elif s.startswith("Clock Uncertainty"): d["uncertainty"] = s.split(":", 1)[1].strip()
            elif s.startswith("Slack") and o > k: break
        # attach group
        g = None
        for gg in groups:
            if gg["line"] < k + 1:
                g = gg
        d["group"] = g["path_group"] if g else None
        d["group_type"] = g.get("type") if g else None
        d["min_section"] = bool(g and g.get("min_detail_start") and k + 1 > g["min_detail_start"])
        details.append(d)

out = {"header": hdr, "groups": groups, "detail_count": len(details)}

# ---- aggregate: worst per check type
bytype = collections.defaultdict(list)
for d in details:
    bytype[d.get("check", "?")].append(d)
out["worst_by_check"] = {}
for t, ds in bytype.items():
    ds2 = sorted(ds, key=lambda x: x["slack"])
    out["worst_by_check"][t] = {
        "count_in_detail": len(ds),
        "worst": ds2[0],
        "top5": ds2[:5],
        "negative_count": sum(1 for x in ds if x["slack"] < 0),
    }

# ---- aggregate endpoints per group detail (setup) to see domain pairs
dom = {}
for d in details:
    if d.get("check") != "setup": continue
    key = (d.get("group_type"), d.get("group"))
    dom.setdefault(key, []).append(d["slack"])

json.dump(out, open(sys.argv[2], "w"), indent=1)
print("groups:", len(groups), "details:", len(details))
print("header:", hdr)
for g in groups:
    print(f"{g.get('type'):4} {g['path_group'][:55]:57} maxSWNS={g.get('max_SWNS')} violEP={g.get('max_viol_ep')}/{g.get('max_total_ep')} minHWNS={g.get('min_HWNS')} minViolEP={g.get('min_viol_ep')}")
print("\nworst by check:", {k: (v["worst"]["slack"], v["worst"].get("group"), v["negative_count"], v["count_in_detail"]) for k, v in out["worst_by_check"].items()})
