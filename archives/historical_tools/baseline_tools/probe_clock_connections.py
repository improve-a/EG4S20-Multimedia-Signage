from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).parent/'harness'))
from windows_runner import remote_python
s=remote_python(r'''import pathlib,subprocess,time,json,hashlib,datetime
r=pathlib.Path(r'D:\FPGA\hx4s20_contest1_20261013');assert not(r/'audit/build.lock').exists()
b=r/'builds/m2_003/work/design/td_project';out=r/'reports/clock_probe_m2_003_03';out.mkdir(exist_ok=False)
script='''+repr('''import_device eagle_s20.db -package EG4S20BG256
open_project hx4s20_basic.al
open_run phy_1
update_timing -mode final
write_verilog {D:/FPGA/hx4s20_contest1_20261013/reports/clock_probe_m2_003_03/routed.v}
report_cells {sys_pll_m0/pll_inst video_pll_m0/pll_inst} -connection
report_cells {sys_pll_m0/bufg_feedback video_pll_m0/bufg_feedback} -connection
close_project
exit 0
''')+r'''
f=out/'probe.tcl';f.write_text(script);exe=pathlib.Path(r'G:\anlu\bin\td_commands_prompt.exe');t=time.monotonic()
p=subprocess.Popen([str(exe),str(f).replace('\\','/')],cwd=b,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
a,z=p.communicate(timeout=90);(out/'stdout.log').write_bytes(a);(out/'stderr.log').write_bytes(z)
meta={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':p.pid,'exit_code':p.returncode,'wall_seconds':time.monotonic()-t,'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'tcl_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'scope':'read existing routed DB and export diagnostic netlist only'};(out/'metadata.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta));print(a.decode(errors='replace')[-10000:]);print(z.decode(errors='replace'))
''',timeout=105)
(Path(__file__).resolve().parent.parent/'reports/clock_probe_m2_003_03_console.txt').write_text(s);print(s)
