from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).parent/'harness'))
from windows_runner import remote_python
s=remote_python(r'''import pathlib,subprocess,time,json,hashlib,datetime
r=pathlib.Path(r'D:\FPGA\hx4s20_contest1_20261013');assert not(r/'audit/build.lock').exists()
b=r/'builds/m5_001/work/design/td_project';out=r/'reports/io_probe_m5_001_03';out.mkdir(exist_ok=False)
script='''+repr('''import_device eagle_s20.db -package EG4S20BG256
open_project hx4s20_basic.al
open_run phy_1
clear_sdc
read_sdc {D:/FPGA/hx4s20_contest1_20261013/reports/io_candidate.sdc}
read_sdc -ip rfifo_32_32_512 ../user_source/hdl_source/ip/afifo_32_16_256.tcl
read_sdc -ip wfifo_32_32_512 ../user_source/hdl_source/ip/afifo_16_32_256.tcl
update_timing -mode final
report_timing_path -file {D:/FPGA/hx4s20_contest1_20261013/reports/io_probe_m5_001_03/miso.rpt} -from [get_ports {sd_miso}]
report_timing_path -file {D:/FPGA/hx4s20_contest1_20261013/reports/io_probe_m5_001_03/mosi.rpt} -to [get_ports {sd_mosi sd_ncs}]
report_timing_exception -file {D:/FPGA/hx4s20_contest1_20261013/reports/io_probe_m5_001_03/exceptions.rpt}
report_nets {sd_card_bmp_m0/bmp_read_m0/clk video_clk} -connection -pin_output_limit 4
close_project
exit 0
''')+r'''
f=out/'probe.tcl';f.write_text(script);exe=pathlib.Path(r'G:\anlu\bin\td_commands_prompt.exe');t=time.monotonic()
p=subprocess.Popen([str(exe),str(f).replace('\\','/')],cwd=b,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
a,z=p.communicate(timeout=90);(out/'stdout.log').write_bytes(a);(out/'stderr.log').write_bytes(z)
meta={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':p.pid,'exit_code':p.returncode,'wall_seconds':time.monotonic()-t,'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'tcl_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'scope':'existing m5_001 route with candidate port MCP constraints, no save/rebuild/hardware'};(out/'metadata.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta));print(a.decode(errors='replace')[-10000:]);print(z.decode(errors='replace'))
''',timeout=105)
(Path(__file__).resolve().parent.parent/'reports/io_probe_m5_001_03_console.txt').write_text(s);print(s)
