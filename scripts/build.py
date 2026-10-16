"""Dispatch/status/collect one explicit isolated TD run; no automatic retries."""
import argparse,json,pathlib,subprocess,sys,os,zipfile,datetime
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'harness'))
from windows_runner import remote_python
REMOTE=r'D:\FPGA\hx4s20_extensions_20261013'
a=argparse.ArgumentParser();a.add_argument('action',choices=['launch','status','collect']);a.add_argument('run_id');a.add_argument('--timeout',type=int,default=1800);a.add_argument('--synth-top');a.add_argument('--probe-source',action='append',default=[]);a.add_argument('--build-root',type=pathlib.Path);x=a.parse_args()
if os.name=='nt':
    base=x.build_root or ROOT/'output/html_fidelity/builds'
    dest=base/x.run_id
    if x.action=='launch':
        (ROOT/'output/html_fidelity/audit').mkdir(parents=True,exist_ok=True)
        check=subprocess.run(['powershell','-NoProfile','-Command','Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'],capture_output=True,text=True)
        if check.stdout.strip():raise RuntimeError('Heavy TD already present: '+check.stdout)
        subprocess.run([sys.executable,str(ROOT/'scripts/prepare_snapshot.py'),x.run_id,'--build-root',str(base)]+(['--synth-top',x.synth_top] if x.synth_top else [])+sum((['--probe-source',v] for v in x.probe_source),[]),check=True,cwd=ROOT)
        dest.mkdir(parents=True,exist_ok=False)
        archive=ROOT/'artifacts'/(x.run_id+'_source.zip')
        with zipfile.ZipFile(archive) as z:z.extractall(dest)
        (dest/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)
        import hashlib
        (dest/'audit/package_sha256.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest())
        cmd=[sys.executable,str(dest/'harness/windows_job.py'),'--root',str(dest),'--run-id',x.run_id,'--timeout',str(x.timeout)]
        # Reuse the existing WMI detach mechanism; SSH's process lifetime must
        # not own the TD supervisor. The supervisor retains its own kill-job.
        import base64
        command=subprocess.list2cmdline(cmd)
        script="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+command.replace("'","''")+"';CurrentDirectory='"+str(dest).replace("'","''")+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json; if($r.ReturnValue -ne 0){exit 1}"
        launch=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(script.encode('utf-16le')).decode()],capture_output=True,check=True)
        # PowerShell may emit localized CLIXML in the host codepage. Preserve
        # the exact bytes; decoding must not turn a successful spawn into failure.
        (dest/'audit/dispatch.log').write_bytes(launch.stdout+launch.stderr)
        print(launch.stdout.decode('utf-8',errors='replace'))
    else:
        status=dest/'runs'/x.run_id/'status.json'
        print(status.read_text() if status.exists() else 'STATUS_NOT_CREATED')
        stages=status.parent/'stages.tsv'
        print(stages.read_text() if stages.exists() else '')
    raise SystemExit(0)

dest=REMOTE+'\\builds\\'+x.run_id
if x.action=='launch':
    # Check process names before preparing; the supervisor also owns a lock.
    text=remote_python("import subprocess,json\np=subprocess.run(['powershell','-NoProfile','-Command',\"Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json\"],capture_output=True)\nprint(p.stdout.decode(errors='replace'))")
    if text.strip():raise RuntimeError('A potentially heavy TD process is present: '+text)
    subprocess.run([sys.executable,str(ROOT/'scripts/prepare_snapshot.py'),x.run_id]+(['--synth-top',x.synth_top] if x.synth_top else [])+sum((['--probe-source',v] for v in x.probe_source),[]),check=True)
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
