#!/usr/bin/env python3
"""Pipe a local python file to the remote interpreter over ssh stdin.
Read-only: nothing is created on the remote host."""
import pathlib
import subprocess
import sys

src = pathlib.Path(sys.argv[1]).read_bytes()
r = subprocess.run(
    ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "thinkpad",
     "set PYTHONIOENCODING=utf-8&& set PYTHONUTF8=1&& D:\\python3.12.3\\python.exe -X utf8 -"],
    input=src,
)
sys.exit(r.returncode)
