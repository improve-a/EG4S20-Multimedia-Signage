#!/usr/bin/env python3
"""Read-only scan of a TD mapped netlist for reset synchronizer cells.
Usage: python scan_reset.py mapped.v
"""
import re, sys
p = sys.argv[1]
L = open(p, encoding="utf-8", errors="replace").read().splitlines()

def cell(name):
    i = next((k for k, l in enumerate(L) if ("\\"+name) in l or name in l), -1)
    if i < 0:
        return None
    j = next((k for k in range(i, len(L)) if ');' in L[k]), i)
    s = next((k for k in range(i, 0, -1) if L[k].lstrip().startswith("EG_PHY_")), max(0, i-25))
    return s, j

def val(blk, key):
    m = re.search(r'\.'+key+r'\(([^)]*)\)', blk)
    return m.group(1) if m else ""

print("FILE", p)
for n in list(range(0, 24)):
    nm = "rs_video/pipe_reg[1]_syn_%d" % n
    c = cell(nm)
    if not c:
        continue
    s, j = c
    blk = "\n".join(L[s:j+1])
    print("%-30s q=%-22s d=%-22s sr=%-8s clk=%-18s REGSET=%s SRMODE=%s SRMUX=%s SD=%s" % (
        nm, val(blk,"q"), val(blk,"mi"), val(blk,"sr"), val(blk,"clk"),
        val(blk,"REG0_REGSET"), val(blk,"SRMODE"), val(blk,"SRMUX"), val(blk,"REG0_SD")))

for nm in ["rst_all_reg_reg_syn_10"]:
    c = cell(nm)
    if c:
        s, j = c
        blk = "\n".join(L[s:j+1])
        print("\n%-30s q=%-22s d=%-22s sr=%-8s clk=%-18s REGSET=%s SRMODE=%s SRMUX=%s SD=%s" % (
            nm, val(blk,"q"), val(blk,"d"), val(blk,"sr"), val(blk,"clk"),
            val(blk,"REG0_REGSET"), val(blk,"SRMODE"), val(blk,"SRMUX"), val(blk,"REG0_SD")))
