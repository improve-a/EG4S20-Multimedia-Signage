import pathlib,subprocess,zipfile,sys
R=pathlib.Path('D:/FPGA/EG4S20-Bot-HDMIProbe')
D=R/'output/infer_add_inspect';D.mkdir(exist_ok=False)
with zipfile.ZipFile(R/'artifacts/bot_hdmi_probe_001_source.zip') as z:z.extractall(D)
commands='''version -number
help set_param
help report_param
help load_run_param
help set_run
help save_project
import_device eagle_s20.db -package EG4S20BG256
open_project hx4s20_basic.al
load_run_param -run syn_1
report_param
exit 0
'''
p=subprocess.run(['G:/anlu/bin/td_commands_prompt.exe'],input=commands.encode(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,cwd=D/'work/design/td_project',timeout=60)
(D/'query.log').write_bytes(p.stdout)
print(p.stdout.decode(errors='replace'))
sys.exit(p.returncode)
