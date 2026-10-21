#!/usr/bin/env python3
"""Run a local python file on the thinkpad via stdin (read-only; nothing written remotely)."""
import base64
import pathlib
import subprocess
import sys

src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
b64 = base64.b64encode(src.encode("utf-8")).decode("ascii")
ps = (
    "[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding\n"
    "$ErrorActionPreference = 'Continue'\n"
    "$env:PYTHONIOENCODING='utf-8'\n"
    "$env:PYTHONUTF8='1'\n"
    f"$src = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{b64}'))\n"
    "$src | D:\\python3.12.3\\python.exe -\n"
    "Write-Output ('REMOTE_EXIT=' + $LASTEXITCODE)\n"
)
tmp = pathlib.Path(__file__).parent / "_remote_py_tmp.ps1"
tmp.write_text(ps, encoding="utf-8")
r = subprocess.run(
    [sys.executable, "../scripts/remote_ps.py", str(tmp)],
    cwd=str(pathlib.Path(__file__).resolve().parent),
)
sys.exit(r.returncode)
