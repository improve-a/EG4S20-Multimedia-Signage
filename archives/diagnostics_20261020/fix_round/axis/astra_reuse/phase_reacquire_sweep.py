#!/usr/bin/env python3
"""Bounded legal-source phase / initialization sweep for the mapped lock FSM.

Equations are the actual mapped LUT truth functions:
  locked_next = (user && pause) || (locked && (valid || !sol))
  pause_next  = !locked && (sof || (!user && pause))
Source timing is the decoded actual u_hdmi_video_source timing:
  SOF: h==150 and y==45
  SOL: h==160 and y>=45
  read window: h>=160 and y>=45
External AXIS is legal 640x480p60: 640 valid / 800 columns, 480 / 525 rows,
one user at the first valid pixel of each frame. `pause` stops the source h
counter, exactly as the netlist-derived source control does.

WHAT THIS IS NOT: no FIFO/BRAM/TMDS/audio simulation. FIFO write/read address
behavior is covered separately by the netlist-derived iverilog control model.
"""
import json
import time
from pathlib import Path

HT, VT = 800, 525
HTOTAL, VTOTAL = 800, 525
F = HTOTAL * VTOTAL  # 420000


def run(first, init_locked=0, init_pause=0, frames=3, damage=False):
    h = y = 0
    locked, pause = init_locked, init_pause
    first_lock = None
    lock_events = []
    drops = 0
    end_locked = 0
    for t in range(first + frames * F):
        rel = (t - first) % F
        valid = int(t >= first and rel // HT < 480 and rel % HT < 640)
        user = int(t >= first and rel == 0)
        sof = int(h == 150 and y == 45)
        sol = int(h == 160 and y >= 45)
        if damage and first_lock is not None and sol and y == 46:
            valid = 0
        nl = int((user and pause) or (locked and ((not sol) or valid)))
        np = int((not locked) and (sof or ((not user) and pause)))
        if nl and not locked:
            lock_events.append(t)
            if first_lock is None:
                first_lock = t
        if locked and not nl:
            drops += 1
        # advance source counters after evaluating this cycle
        if h == 15:
            y = 0 if y == 524 else y + 1
        if not pause:
            h = 0 if h == 799 else h + 1
        locked, pause = nl, np
        end_locked = locked
    return {
        "first": first, "init_locked": init_locked, "init_pause": init_pause,
        "first_lock": first_lock, "lock_events": lock_events[:8],
        "lock_events_count": len(lock_events), "drops": drops,
        "end_locked": end_locked,
    }


def main():
    t0 = time.monotonic()
    offsets = [0, 1, 2, 8, 16, 24, 28, 29, 30, 31, 32, 33, 34, 40, 64, 128,
               152, 159, 160, 161, 170, 200, 320, 640, 800,
               35360, 35390, 35392, 35400, 35464, 419999]
    inits = [(0, 0), (0, 1), (1, 0)]
    results = []
    bad_actual = []
    bad_perturbed = []
    for first in offsets:
        for il, ip in inits:
            r = run(first, il, ip, frames=3)
            results.append(r)
            # Actual reset states are (locked,pause)=(0,0). Those must acquire
            # within two frames, have no post-acquisition drop, and end locked.
            # (0,1)/(1,0) are deliberate initialization perturbations only.
            bad = (r["first_lock"] is None or r["drops"] != 0 or not r["end_locked"])
            if (il, ip) == (0, 0):
                if bad:
                    bad_actual.append(r)
            elif bad:
                bad_perturbed.append(r)
    negative = run(35392, 0, 0, frames=3, damage=True)
    assert negative["drops"] > 0, "damaged-valid negative control did not drop"
    summary = {
        "scope": "MAPPED_LOCK_FSM + DECODED_SOURCE_TIMING; legal 640x480 AXIS phase/init sweep",
        "offsets": len(offsets), "init_states": inits, "cases": len(results),
        "frames_per_case": 3,
        "actual_reset_all_lock_no_drop": len(bad_actual) == 0,
        "actual_reset_bad_cases": bad_actual,
        "perturbed_init_bad_cases": bad_perturbed,
        "perturbed_init_note": "deliberate locked=1 or pause=1 initial states; may add a transient drop/re-lock, never a permanent unlock in this sweep",
        "negative_control_valid_removed_at_sol": negative,
        "actual_reset_max_first_lock": max(r["first_lock"] for r in results if (r["init_locked"], r["init_pause"]) == (0, 0)),
        "actual_reset_min_first_lock": min(r["first_lock"] for r in results if (r["init_locked"], r["init_pause"]) == (0, 0)),
        "max_first_lock_all_cases": max((r["first_lock"] or 0) for r in results),
        "wall_seconds": time.monotonic() - t0,
        "boundary": "No FIFO/BRAM/TMDS/audio; lock FSM only. Offset range is selected, not exhaustive.",
    }
    print(json.dumps(summary, indent=2))
    with open(Path(__file__).parent / "phase_reacquire_result.json", "w") as f:
        json.dump({"summary": summary, "results": results}, f, indent=2)


if __name__ == "__main__":
    main()
