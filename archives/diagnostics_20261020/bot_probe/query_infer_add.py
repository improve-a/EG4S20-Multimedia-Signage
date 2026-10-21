import pathlib,subprocess
D=pathlib.Path('D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect')
commands='''set_param -help
report_param -help
save_project -help
import_device eagle_s20.db -package EG4S20BG256
open_project hx4s20_basic.al
load_run_param -run syn_1
report_param -all -detail -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect/default_params.txt}
set_param design infer_add false -run syn_1
load_run_param -run syn_1
report_param -all -detail -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect/toggled_params.txt}
save_project
export_flow_script -run syn_1 -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect/toggled_syn.tcl}
exit 0
'''
p=subprocess.run(['G:/anlu/bin/td_commands_prompt.exe'],input=commands.encode(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,cwd=D/'work/design/td_project',timeout=60)
(D/'query_toggle.log').write_bytes(p.stdout)
print(p.stdout.decode(errors='replace'))
