"""Check whether a probe build actually removed an observation cone.

Usage: obs_check.py gate.v

Facts printed (exact net names from `wire` declarations, not substrings):
 1. number of probe_display/status_meta_reg and status_sync_reg FFs
    (baseline probe build: 31 and 31; flags_async={23'd0,flags[4:0]}: 5 and 5)
 2. which bits of `probe/flags` are still referenced and by which hierarchy
 3. exact loads of `probe/locked` and `O_video_locked`
 4. whether exact nets probe/locked, probe_video_locked exist

Exit code 0 only prints facts; it does not judge pass/fail.
"""
import re
import sys
from collections import Counter

sys.path.insert(0, ".")
from netcmp import parse_netlist, strip_comments  # noqa: E402

OUT_PINS = {"q", "o", "Q", "O", "f", "fx", "fco", "dob", "co"}


def hier(n):
    return n.rsplit("/", 1)[0] if "/" in n else "<top>"


def bits(val):
    val = val.strip()
    if val.startswith("{") and val.endswith("}"):
        return [x.strip() for x in val[1:-1].split(",")]
    return [val]


def main():
    path = sys.argv[1]
    p = parse_netlist(path)
    text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    declared = set()
    for m in re.finditer(r"\bwire\b\s*(?:\[[^\]]*\])?\s*(\\[^\s;]+)", text):
        declared.add(m.group(1).lstrip("\\"))

    print("== status FFs")
    for stem in ("status_meta_reg", "status_sync_reg"):
        names = [n for n in p["seq"] if stem in n]
        print("  %-16s %d" % (stem, len(names)))
        idx = sorted(int(m.group(1)) for n in names
                     for m in [re.search(r"\[(\d+)\]$", n)] if m)
        if idx:
            print("    bit range %d..%d" % (idx[0], idx[-1]))

    print("== probe/flags bits referenced")
    used = Counter()
    byh = Counter()
    for cell, v in p["insts"].items():
        for pin, val in v["pins"].items():
            if pin in OUT_PINS:
                continue
            for m in re.finditer(r"(?:\\?)probe/flags\s*\[(\d+)\]", val):
                used[int(m.group(1))] += 1
                byh[hier(cell)] += 1
    if used:
        print("  bits:", ",".join(str(i) for i in sorted(used)))
        for h, c in byh.most_common():
            print("   %-60s %d" % (h, c))
    else:
        print("  none")

    print("== exact locked observation loads")
    for target in ("probe/locked", "O_video_locked"):
        resolved = {d for d in declared if d == target or d.endswith("/" + target)}
        print("  target %-18s declared=%s %s" %
              (target, bool(resolved), sorted(resolved)[:2]))
        n = 0
        for cell, v in p["insts"].items():
            for pin, val in v["pins"].items():
                if pin in OUT_PINS:
                    continue
                if any(b.strip().lstrip("\\") in resolved for b in bits(val)):
                    print("     %-68s .%s" % (cell, pin))
                    n += 1
        print("    loads=%d" % n)

    for n in ("probe/locked", "probe_video_locked", "probe/ready"):
        print("  exact net %-22s declared=%s" % (n, n in declared))


if __name__ == "__main__":
    main()
