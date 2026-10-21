#!/usr/bin/env python3
"""Print the Statistics block of every path group in a TD final_timing.rpt."""
import sys
p = sys.argv[1]
L = open(p, encoding="utf-8", errors="replace").read().splitlines()
i = 0
while i < len(L):
    if L[i].startswith("Path Group"):
        print("\n".join(L[i:i + 28]))
        print("=" * 40)
        i += 28
    else:
        i += 1
