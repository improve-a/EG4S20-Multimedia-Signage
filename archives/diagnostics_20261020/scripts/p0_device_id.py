"""Read-only JTAG preflight for P0. No download or device configuration."""
import pathlib
import subprocess
import sys
import tempfile

TD = r'G:\anlu\bin\td_commands_prompt.exe'
TCL = """list_cable
set rc [catch {read_device_id -cable 0} result]
puts "P0_PRE_ID_RC=$rc RESULT=$result"
exit
"""
with tempfile.TemporaryDirectory(prefix='nobot_p0_') as td:
    p = subprocess.run(
        [TD],
        cwd=td,
        input=TCL.encode('utf-8'),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=120,
    )
print('PROCESS_EXIT=' + str(p.returncode))
print('--- STDOUT ---')
print(p.stdout.decode('utf-8', errors='replace'))
print('--- STDERR ---')
print(p.stderr.decode('utf-8', errors='replace'))
text = (p.stdout + b'\n' + p.stderr).decode('utf-8', errors='replace')
sys.exit(0 if 'P0_PRE_ID_RC=0 RESULT=EG4S20BG256' in text else 1)
