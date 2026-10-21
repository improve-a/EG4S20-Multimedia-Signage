#!/usr/bin/env python3
"""Read a Tang Dynasty final_timing.rpt and print path blocks whose text
contains any requested substring. Read-only; run with the report path as argv[1].
"""
import re
import sys

path = sys.argv[1]
keys = sys.argv[2:]
text = open(path, encoding="utf-8", errors="replace").read().splitlines()

# Track current path group and check type.
group = ""
blocks = []
cur = None
for line in text:
    if line.startswith("Path Group"):
        group = line.split(":", 1)[-1].strip()
    if line.startswith("Slack               :"):
        if cur:
            blocks.append(cur)
        cur = {"group": group, "lines": [line]}
    elif cur is not None:
        if line.startswith("Slack               :"):
            pass
        cur["lines"].append(line)
        if line.startswith("Path Group"):
            group = line.split(":", 1)[-1].strip()
if cur:
    blocks.append(cur)

for b in blocks:
    body = "\n".join(b["lines"])
    if keys and not any(k in body for k in keys):
        continue
    slack = b["lines"][0].split(":", 1)[-1].strip()
    begin = end = ctype = ""
    for l in b["lines"][:10]:
        if l.startswith("Begin Point"):
            begin = l.split(":", 1)[-1].strip()
        elif l.startswith("End Point"):
            end = l.split(":", 1)[-1].strip()
        elif l.startswith("Check Type"):
            ctype = l.split(":", 1)[-1].strip()
    print("GROUP:", b["group"], "| SLACK:", slack, "|", ctype)
    print("  FROM:", begin)
    print("  TO  :", end)
