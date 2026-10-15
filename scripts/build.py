"""Dispatch/status/collect one explicit isolated TD run; no automatic retries."""
import argparse,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'harness'))
from windows_runner import remote_python
REMOTE=r'D:\FPGA\hx4s20_extensions_20261013'
a=argparse.ArgumentParser();a.add_argument('action',choices=['launch','status','collect']);a.add_argument('run_id');a.add_argument('--timeout',type=int,default=1800);a.add_argument('--synth-top');x=a.parse_args()
dest=REMOTE+'\\builds\\'+x.run_id
if x.action=='launch':
    # Check process names before preparing; the supervisor also owns a lock.
    text=remote_python("import subprocess,json\np=subprocess.run(['powershell','-NoProfile','-Command',\"Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json\"],capture_output=True)\nprint(p.stdout.decode(errors='replace'))")
    if text.strip():raise RuntimeError('A potentially heavy TD process is present: '+text)
    subprocess.run([sys.executable,str(ROOT/'scripts/prepare_snapshot.py'),x.run_id]+(['--synth-top',x.synth_top] if x.synth_top else []),check=True)
    print(remote_python(f"from pathlib import Path\np=Path({REMOTE!r});(p/'artifacts').mkdir(exist_ok=True);(p/'audit').mkdir(exist_ok=True)\n"))
    archive=ROOT/'artifacts'/(x.run_id+'_source.zip')
    subprocess.run(['scp',str(archive),'thinkpad:'+REMOTE.replace('\\','/')+'/artifacts/'],check=True)
    print(remote_python(f"import pathlib,zipfile,hashlib\np=pathlib.Path({dest!r});p.mkdir(parents=True,exist_ok=False)\nwith zipfile.ZipFile(pathlib.Path({REMOTE!r})/'artifacts'/{archive.name!r}) as z:z.extractall(p)\n(p/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)\n(p/'audit/package_sha256.txt').write_text(hashlib.sha256((pathlib.Path({REMOTE!r})/'artifacts'/{archive.name!r}).read_bytes()).hexdigest())\nprint(p)"))
cmd=[sys.executable,str(ROOT/'harness/windows_runner.py'),x.action,x.run_id,'--root',dest,'--timeout',str(x.timeout),'--output',str(ROOT/'evidence/builds')]
p=subprocess.run(cmd,capture_output=True,text=True)
out=ROOT/'evidence/build_dispatch';out.mkdir(parents=True,exist_ok=True)
import datetime
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
(out/(x.run_id+'_'+x.action+'_'+stamp+'.txt')).write_text(p.stdout+p.stderr)
print(p.stdout);print(p.stderr);raise SystemExit(p.returncode)
