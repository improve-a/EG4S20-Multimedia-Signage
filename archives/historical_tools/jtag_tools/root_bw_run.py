"""Root-only execution of a reviewed Tcl file, in isolated evidence directory."""
import datetime, hashlib, json, pathlib, subprocess, sys, time
root=pathlib.Path(r'D:\FPGA\hx4s20_usb_jtag_harness_20261013')
exe=pathlib.Path(r'G:\anlu\bin\bw_commands_prompt.exe')
script=root/pathlib.Path(sys.argv[1]).name
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
prefix=root/(stamp+'_'+script.stem)
payload=('source {'+script.as_posix()+'}\nexit\n').encode()
pathlib.Path(str(prefix)+'.stdin.tcl').write_bytes(script.read_bytes())
started=time.monotonic()
p=subprocess.Popen([str(exe)],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
timeout=False
try: out,err=p.communicate(payload,timeout=40)
except subprocess.TimeoutExpired:
    timeout=True; p.kill(); out,err=p.communicate()
pathlib.Path(str(prefix)+'.stdout.txt').write_bytes(out)
pathlib.Path(str(prefix)+'.stderr.txt').write_bytes(err)
meta=dict(utc=stamp,exe=str(exe),exe_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),script=str(script),script_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),pid=p.pid,exit_code=p.returncode,wall_seconds=time.monotonic()-started,timeout=timeout)
pathlib.Path(str(prefix)+'.meta.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(meta)); print(out.decode('utf-8',errors='replace')); print(err.decode('utf-8',errors='replace'))
sys.exit(p.returncode or (124 if timeout else 0))
