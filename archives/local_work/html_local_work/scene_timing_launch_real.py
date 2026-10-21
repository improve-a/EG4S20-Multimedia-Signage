from pathlib import Path
import json,subprocess,base64,os,datetime
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');os.chdir(r);d=r/'output/html_fidelity/verification/header_timing_v1'
wrapper=d/'run_real.py'
wrapper.write_bytes(("from pathlib import Path\nimport subprocess,json,datetime\nr=Path("+repr(str(r))+")\nd=Path("+repr(str(d))+")\nwith (d/'real_dispatch.log').open('wb') as f:\n p=subprocess.run(["+repr(r'D:\python3.12.3\python.exe')+",'-X','utf8',str(r/'scripts/html_fidelity_verify_scenes.py')],cwd=r,stdout=f,stderr=subprocess.STDOUT)\n(d/'real_dispatch_result.json').write_text(json.dumps({'exit':p.returncode,'finished_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}))\n").encode())
cmd=subprocess.list2cmdline([r'D:\python3.12.3\python.exe','-X','utf8',str(wrapper)])
ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+cmd+"';CurrentDirectory='"+str(r)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
p=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True)
(d/'real_dispatch.json').write_bytes(p.stdout);print(p.stdout.decode(errors='replace'));print(p.stderr.decode(errors='replace'))
t=(d/'scene_cycle_equivalence_tb.v').read_text().replace('gap=byte_i%3;','gap=0;')
(d/'scene_continuous_equivalence_tb.v').write_bytes(t.encode())
c=[r'C:\iverilog\bin\iverilog.exe','-g2012','-s','html_scene_loader_tb','-o',str(d/'continuous.vvp'),str(d/'scene_continuous_equivalence_tb.v'),str(d/'html_scene_loader_candidate.v'),str(d/'html_scene_loader_original.v'),str(r/'rtl/ext/html_resource_locator.v')]
p=subprocess.run(c,capture_output=True);(d/'continuous_compile.log').write_bytes(p.stdout+p.stderr);print('compile',p.returncode);assert p.returncode==0
p=subprocess.run([r'C:\iverilog\bin\vvp.exe',str(d/'continuous.vvp')],capture_output=True,timeout=90);(d/'continuous_run.log').write_bytes(p.stdout+p.stderr);print('run',p.returncode,p.stdout.decode(errors='replace'));assert p.returncode==0
