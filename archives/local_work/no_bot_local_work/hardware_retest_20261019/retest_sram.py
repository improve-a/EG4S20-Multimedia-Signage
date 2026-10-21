"""Windows: repeat the explicitly requested final no-Bot volatile SRAM test."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import time

root = Path(r'D:\FPGA\EG4S20-NoBot')
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
out = root / 'output/hardware' / ('no_bot_retest_' + stamp)
out.mkdir(parents=True, exist_ok=False)
bit = root / 'output/html_fidelity/builds/no_bot_legacy_004/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
tool = Path(r'G:\anlu\bin\bw_commands_prompt.exe')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert bit.stat().st_size == 677348
assert sha(bit) == '61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7'
assert sha(tool) == '513b024c8c1853825441939c9c51feb0156c2c6c2043f854a39e805c38064401'
tcl = '''puts NO_BOT_RETEST_BEGIN
list_cable
set rc [catch {read_device_id -cable 0} result]
puts "PRE_ID_RC=$rc RESULT=$result"
if {$rc || $result ne "EG4S20BG256"} {exit 3}
set rc [catch {download -bit {%s} -mode jtag -cable 0 -spd 6} result]
puts "DOWNLOAD_RC=$rc RESULT=$result"
if {$rc} {exit 4}
set rc [catch {read_device_id -cable 0} result]
puts "POST_ID_RC=$rc RESULT=$result"
if {$rc || $result ne "EG4S20BG256"} {exit 5}
puts NO_BOT_RETEST_SRAM_PASS
exit
''' % bit.as_posix()
script = out / 'sram.tcl'
script.write_text(tcl, encoding='utf-8')
record = dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              state='STARTING', authorization='现在再重新测试一下那个无bot的bitstream.',
              SOURCE_SHA='6ee7c70bbf36c33f90a687f010c876de48f03ba6',
              DELIVERY_SHA='17ac5f26acb120b4ed0055010d913bf4bcd9b50e',
              bit=str(bit), bit_sha256=sha(bit), bit_bytes=bit.stat().st_size,
              tool=str(tool), tool_sha256=sha(tool), tcl_sha256=sha(script),
              scope='Final existing no_bot_legacy_004; volatile JTAG SRAM only',
              persistent_flash_write=False, physical_card_write=False,
              FULL_SYSTEM_SIM='NOT_VERIFIED', HARDWARE_FUNCTIONAL='PENDING_OBSERVATION',
              prior_evidence=str(root / 'output/hardware/no_bot_20261019T140608Z'),
              evidence_root=str(out))
def save():
    (out / 'metadata.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
save()
start = time.monotonic()
with (out / 'stdout.log').open('wb') as stdout, (out / 'stderr.log').open('wb') as stderr:
    p = subprocess.Popen([str(tool)], cwd=out, stdin=subprocess.PIPE, stdout=stdout, stderr=stderr)
    record['pid'] = p.pid
    save()
    try:
        p.communicate(('source {' + script.as_posix() + '}\nexit\n').encode(), timeout=45)
    except subprocess.TimeoutExpired:
        p.kill()
        p.communicate()
        record['timeout'] = True
output = (out / 'stdout.log').read_bytes().decode(errors='replace')
passed = p.returncode == 0 and not record.get('timeout') and all(s in output for s in
    ('PRE_ID_RC=0 RESULT=EG4S20BG256', 'DOWNLOAD_RC=0', 'POST_ID_RC=0 RESULT=EG4S20BG256', 'NO_BOT_RETEST_SRAM_PASS'))
record.update(exit_code=p.returncode, wall_seconds=round(time.monotonic() - start, 3),
              finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              state='SRAM_DOWNLOAD_PASS' if passed else 'SRAM_DOWNLOAD_FAILED_NO_AUTOMATIC_RETRY')
save()
print(json.dumps(record, ensure_ascii=False, indent=2))
print(output)
print((out / 'stderr.log').read_bytes().decode(errors='replace'))
raise SystemExit(0 if passed else 1)
