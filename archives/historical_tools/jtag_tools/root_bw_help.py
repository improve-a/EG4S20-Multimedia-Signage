import datetime, hashlib, json, pathlib, subprocess, time
root=pathlib.Path(r'D:\FPGA\hx4s20_usb_jtag_harness_20261013')
exe=pathlib.Path(r'G:\anlu\bin\bw_commands_prompt.exe')
script='puts HARNESS_HELP_ONLY\nputs [info commands]\nhelp\nexit\n'
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
prefix=root/(stamp+'_root_bw_help')
pathlib.Path(str(prefix)+'.stdin.tcl').write_text(script,encoding='utf-8')
started=time.monotonic()
p=subprocess.Popen([str(exe)],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
timeout=False
try: out,err=p.communicate(script.encode(),timeout=40)
except subprocess.TimeoutExpired:
    timeout=True; p.kill(); out,err=p.communicate()
pathlib.Path(str(prefix)+'.stdout.txt').write_bytes(out)
pathlib.Path(str(prefix)+'.stderr.txt').write_bytes(err)
meta=dict(utc=stamp,exe=str(exe),exe_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),pid=p.pid,exit_code=p.returncode,wall_seconds=time.monotonic()-started,timeout=timeout,operation='Tcl help/introspection only')
pathlib.Path(str(prefix)+'.meta.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(meta)); print(out.decode('utf-8',errors='replace'));print(err.decode('utf-8',errors='replace'))
