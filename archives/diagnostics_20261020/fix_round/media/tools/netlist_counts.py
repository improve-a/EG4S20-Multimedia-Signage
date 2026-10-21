#!/usr/bin/env python3
"""Print counts of selected net names in an exported mapped netlist.
Read-only evidence helper; it does not attempt equivalence, only presence.
"""
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
keys = [
    "display_state", "state_code50", "state_code_sd", "state_code",
    "display_valid", "fifo_fault", "frame_commit/active_buf",
    "frame_commit/state_reg", "sd_card_bmp_m0/display_valid",
    "sd_card_bmp_m0/state", "transition/display_fault_sync",
    "frame_commit/fault_sync", "read_addr_index_d0",
]
print("FILE", path)
for k in keys:
    print("%-34s %d" % (k, text.count(k)))
