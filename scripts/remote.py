#!/usr/bin/env python3
"""Execute saved PS over existing SSH, retaining command/output provenance."""
import argparse, base64, datetime, hashlib, json, pathlib, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
def run(script, name='probe', timeout=90):
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    outdir=ROOT/'evidence'/f'{stamp}_{name}'
    outdir.mkdir(parents=True)
    script='[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)\n'+script
    (outdir/'command.ps1').write_text(script)
    encoded=base64.b64encode(script.encode('utf-16le')).decode()
    start=time.monotonic()
    p=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','thinkpad','powershell -NoProfile -NonInteractive -EncodedCommand '+encoded],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    timed_out=False
    try: out,err=p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out=True;p.kill();out,err=p.communicate()
    (outdir/'stdout.txt').write_bytes(out);(outdir/'stderr.txt').write_bytes(err)
    meta=dict(utc=stamp,ssh_pid=p.pid,exit_code=p.returncode,wall_seconds=time.monotonic()-start,timed_out=timed_out,script_sha256=hashlib.sha256(script.encode()).hexdigest())
    (outdir/'meta.json').write_text(json.dumps(meta,indent=2))
    print(str(outdir));print(out.decode('utf-8-sig',errors='replace'));print(err.decode('utf-8-sig',errors='replace'))
    return p.returncode or (124 if timed_out else 0)
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('script');ap.add_argument('--timeout',type=int,default=90);a=ap.parse_args()
    raise SystemExit(run(pathlib.Path(a.script).read_text(),pathlib.Path(a.script).stem,a.timeout))
