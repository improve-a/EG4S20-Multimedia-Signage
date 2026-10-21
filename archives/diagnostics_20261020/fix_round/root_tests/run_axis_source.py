import hashlib,json,pathlib,subprocess,time
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020\root_tests')
src=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\hdmi_probe_001\work\design\user_source\hdl_source\video_rgb_to_axis_640x480.v')
tb=r/'axis_source_hold_tb.v';steps=[]
for cmd in ([r'C:\iverilog\bin\iverilog.exe','-g2012','-s','tb','-o',str(r/'axis_source_hold.vvp'),str(tb),str(src)], [r'C:\iverilog\bin\vvp.exe',str(r/'axis_source_hold.vvp')]):
 start=time.monotonic();p=subprocess.run(cmd,cwd=r,capture_output=True,timeout=30)
 steps.append({'command':cmd,'exit':p.returncode,'seconds':time.monotonic()-start,'stdout':p.stdout.decode(errors='replace'),'stderr':p.stderr.decode(errors='replace')})
 assert p.returncode==0,steps
result={'scope':'Actual frozen source only, synthetic ready checker, no receiver model','steps':steps,'hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (tb,src)}}
(r/'axis_source_receipt.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
