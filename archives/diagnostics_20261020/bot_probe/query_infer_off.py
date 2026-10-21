import pathlib,subprocess
D=pathlib.Path('D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect')
commands='''import_device eagle_s20.db -package EG4S20BG256
open_project hx4s20_basic.al
set_param design infer_add off -run syn_1
load_run_param -run syn_1
commit_param -step design
report_param -all -detail -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect/off_params.txt}
export_flow_script -run syn_1 -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/infer_add_inspect/off_syn.tcl}
close_project
exit 0
'''
p=subprocess.run(['G:/anlu/bin/td_commands_prompt.exe'],input=commands.encode(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,cwd=D/'work/design/td_project',timeout=60)
(D/'query_off.log').write_bytes(p.stdout)
print(p.stdout.decode(errors='replace'))
print((D/'work/design/td_project/hx4s20_basic.al').read_text(encoding='utf-8')[-2300:])
