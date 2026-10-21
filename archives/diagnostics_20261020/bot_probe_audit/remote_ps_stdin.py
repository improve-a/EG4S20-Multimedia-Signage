#!/usr/bin/env python3
"""Pipe a local PowerShell script to `powershell -NoProfile -Command -` on thinkpad.

No files are created on the remote host. Optional VAR=VALUE arguments are
exported as environment variables before the script body.

Usage: python3 remote_ps_stdin.py script.ps1 [VAR=VALUE ...]
"""
import pathlib
import subprocess
import sys

script = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
preamble = "".join(
    "$env:%s='%s'\n" % tuple(a.split("=", 1)) for a in sys.argv[2:]
)
body = "[Console]::OutputEncoding=[Text.UTF8Encoding]::new()\n$ErrorActionPreference='Continue'\n" + preamble + script
r = subprocess.run(
    ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "thinkpad",
     "powershell -NoProfile -Command -"],
    input=body.encode("utf-8"),
)
sys.exit(r.returncode)
