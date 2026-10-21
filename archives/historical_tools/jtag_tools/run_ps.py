#!/usr/bin/env python3
"""Run a saved PowerShell probe over existing SSH; preserve output and provenance."""
import argparse, base64, datetime, hashlib, json, pathlib, subprocess, time
p = argparse.ArgumentParser()
p.add_argument('script'); p.add_argument('--timeout', type=int, default=180)
a = p.parse_args()
script = pathlib.Path(a.script).resolve()
root = script.parent.parent
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
name = stamp + '_' + script.stem
content = script.read_text(encoding='utf-8-sig')
encoded = base64.b64encode(content.encode('utf-16le')).decode()
cmd = ['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','thinkpad',
       'powershell -NoProfile -NonInteractive -EncodedCommand ' + encoded]
started = time.monotonic()
proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
timed_out = False
try: out, err = proc.communicate(timeout=a.timeout)
except subprocess.TimeoutExpired:
    timed_out = True; proc.kill(); out, err = proc.communicate()
evidence = root / 'evidence'; evidence.mkdir(exist_ok=True)
(evidence / (name+'.stdout.txt')).write_bytes(out)
(evidence / (name+'.stderr.txt')).write_bytes(err)
meta = dict(start_utc=stamp, script=str(script), script_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),
            ssh_pid=proc.pid, exit_code=proc.returncode, wall_seconds=round(time.monotonic()-started,3),
            timed_out=timed_out, host='thinkpad', remote_root=r'D:\FPGA\hx4s20_usb_jtag_harness_20261013')
(evidence / (name+'.meta.json')).write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(json.dumps(meta,ensure_ascii=False)); print(out[:30000].decode('utf-8-sig',errors='replace'))
if len(out)>30000: print('Output preview capped; full stdout preserved in evidence.')
if err: print('STDERR:',err[:5000].decode('utf-8-sig',errors='replace'))
raise SystemExit(proc.returncode or (124 if timed_out else 0))
