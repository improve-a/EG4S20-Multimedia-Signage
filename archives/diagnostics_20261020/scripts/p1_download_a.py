"""P1: verify experiment A and program only its SRAM image over JTAG."""
import hashlib
import pathlib
import subprocess
import sys
import tempfile

BIT = pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_no_locked_003.bit')
EXPECTED = 'cce449034505c4d5c61a856b94b48c4c3d7e20a3eb86627972763a1981ca46a5'
TD = r'G:\anlu\bin\td_commands_prompt.exe'

data = BIT.read_bytes()
actual = hashlib.sha256(data).hexdigest()
print(f'BIT={BIT}')
print(f'BYTES={len(data)}')
print(f'SHA256={actual}')
if actual != EXPECTED or len(data) != 677348:
    raise SystemExit('Refusing to program: bitstream identity mismatch')

tcl = (
    'read_device_id -cable 0\n'
    'set rc [catch {download -bit {' + BIT.as_posix() + '} -mode jtag -cable 0 -spd 6} result]\n'
    'puts "P1_DOWNLOAD_RC=$rc RESULT=$result"\n'
    'set idrc [catch {read_device_id -cable 0} idresult]\n'
    'puts "P1_POST_ID_RC=$idrc RESULT=$idresult"\n'
    'exit\n'
)
with tempfile.TemporaryDirectory(prefix='nobot_p1_a_') as td:
    p = subprocess.run(
        [TD],
        cwd=td,
        input=tcl.encode('utf-8'),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=240,
    )
print('PROCESS_EXIT=' + str(p.returncode))
print('--- STDOUT ---')
print(p.stdout.decode('utf-8', errors='replace'))
print('--- STDERR ---')
print(p.stderr.decode('utf-8', errors='replace'))
text = (p.stdout + b'\n' + p.stderr).decode('utf-8', errors='replace')
ok = 'P1_DOWNLOAD_RC=0' in text and 'P1_POST_ID_RC=0 RESULT=EG4S20BG256' in text
print('P1_PROGRAM_A_PASS' if ok else 'P1_PROGRAM_A_NOT_CONFIRMED')
sys.exit(0 if ok else 1)
