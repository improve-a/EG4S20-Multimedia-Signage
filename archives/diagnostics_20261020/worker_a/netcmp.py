#!/usr/bin/env python3
"""Read-only structural comparison of two TD mapped Verilog netlists.

Usage:
  netcmp.py summary A.v B.v
  netcmp.py seq A.v B.v <hier-prefix> [<hier-prefix> ...]
  netcmp.py const A.v B.v
  netcmp.py net A.v B.v <substring> [<substring> ...]

All analysis happens locally on files that were dumped from the copied .db
inside the worker scratch directory.  No source/build tree is written.
"""
import json
import re
import sys
from collections import Counter, defaultdict

SEQ_TYPES = {"AL_MAP_SEQ"}


def strip_comments(text):
    # remove /* ... */ (may span lines) then // to end of line
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    out = []
    for line in text.splitlines():
        i = line.find("//")
        if i >= 0:
            line = line[:i]
        out.append(line)
    return "\n".join(out)


def split_statements(body):
    stmts, cur, depth = [], [], 0
    instr = False
    for ch in body:
        if ch == '"':
            instr = not instr
        if not instr:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == ";" and depth == 0:
                stmts.append("".join(cur).strip())
                cur = []
                continue
        cur.append(ch)
    if "".join(cur).strip():
        stmts.append("".join(cur).strip())
    return stmts


def parse_params(s):
    """s = ".A(1), .B(2)" -> {A:'1',B:'2'} (raw, whitespace normalised)."""
    d = {}
    for m in re.finditer(r"\.([A-Za-z0-9_]+)\s*\(([^()]*)\)", s):
        d[m.group(1)] = m.group(2).strip()
    return d


def parse_netlist(path):
    text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    # module top ... endmodule (single flattened module)
    m = re.search(r"\bmodule\s+top\b(.*?)\bendmodule\b", text, re.S)
    if not m:
        raise SystemExit("no module top in " + path)
    body = m.group(1)
    # drop the port declaration list after module name
    i = body.find(");")
    if i > 0:
        body = body[i + 2:]
    stmts = split_statements(body)
    insts = {}
    seq = {}
    for st in stmts:
        if not st or st.startswith(("wire", "input", "output", "inout",
                                    "parameter", "assign", "reg")):
            continue
        # TYPE [#(params)] NAME ( pins )
        mm = re.match(
            r"([A-Za-z_][A-Za-z0-9_]*)\s*(?:#\s*\((.*?)\)\s*)?"
            r"(\\\S+|[A-Za-z_][A-Za-z0-9_$\[\]]*)\s*\((.*)\)\s*$",
            st, re.S)
        if not mm:
            continue
        typ, params, name, pins = mm.groups()
        if typ in ("module", "endmodule"):
            continue
        if name.startswith("\\"):
            name = name[1:].strip()
        pins = parse_params(pins or "")
        insts[name] = {"type": typ, "params": params or "", "pins": pins}
        if typ in SEQ_TYPES:
            seq[name] = pins
    return {"insts": insts, "seq": seq}


def hier(name):
    return name.rsplit("/", 1)[0] if "/" in name else ""


def cmd_summary(a, b):
    pa, pb = parse_netlist(a), parse_netlist(b)
    out = {}
    for tag, p in (("A", pa), ("B", pb)):
        out[tag] = {
            "cells": len(p["insts"]),
            "by_type": dict(Counter(v["type"] for v in p["insts"].values())),
            "seq_by_hier": dict(Counter(hier(k) for k in p["seq"])),
        }
    print(json.dumps(out, indent=1, sort_keys=True))


def cmd_seq(a, b, prefixes):
    pa, pb = parse_netlist(a), parse_netlist(b)
    out = {}
    for tag, p in (("A", pa), ("B", pb)):
        res = {}
        for pre in prefixes:
            rows = []
            for name, pins in sorted(p["seq"].items()):
                if name == pre or name.startswith(pre + "/"):
                    rows.append({"cell": name,
                                 "q": pins.get("Q") or pins.get("QN"),
                                 "d": pins.get("D"),
                                 "ce": pins.get("CE"),
                                 "clk": pins.get("CLK"),
                                 "sr": pins.get("SR") or pins.get("R") or pins.get("S"),
                                 "params": p["insts"][name]["params"]})
            res[pre] = rows
        out[tag] = res
    print(json.dumps(out, indent=1, sort_keys=True))


def cmd_net(a, b, needles):
    out = {}
    for tag, path in (("A", a), ("B", b)):
        text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        res = {}
        for nd in needles:
            hits = []
            for i, line in enumerate(text.splitlines(), 1):
                if nd in line:
                    hits.append({"line": i, "text": " ".join(line.split())})
            res[nd] = hits
        out[tag] = res
    print(json.dumps(out, indent=1, sort_keys=True))


def cmd_const(a, b):
    out = {}
    for tag, path in (("A", a), ("B", b)):
        p = parse_netlist(path)
        c = Counter()
        where = defaultdict(list)
        for name, v in p["insts"].items():
            for pin, net in v["pins"].items():
                nn = net.strip()
                if nn in ("1'b0", "1'b1", "0", "1"):
                    c[nn] += 1
                    where[nn].append(name + "." + pin)
        out[tag] = {"counts": dict(c),
                    "gnd_targets": where.get("1'b0", [])[:200],
                    "vcc_targets": where.get("1'b1", [])[:200]}
    print(json.dumps(out, indent=1, sort_keys=True))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "summary":
        cmd_summary(sys.argv[2], sys.argv[3])
    elif cmd == "seq":
        cmd_seq(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif cmd == "net":
        cmd_net(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif cmd == "const":
        cmd_const(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit(__doc__)
