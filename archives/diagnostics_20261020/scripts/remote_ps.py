#!/usr/bin/env python3
"""Run a UTF-8 PowerShell file over the existing thinkpad SSH alias."""
import base64
import pathlib
import subprocess
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
prefix = "[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding; $ErrorActionPreference = 'Stop';\n"
encoded = base64.b64encode((prefix + text).encode("utf-16-le")).decode("ascii")
result = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "thinkpad", "powershell -NoProfile -EncodedCommand " + encoded])
sys.exit(result.returncode)
