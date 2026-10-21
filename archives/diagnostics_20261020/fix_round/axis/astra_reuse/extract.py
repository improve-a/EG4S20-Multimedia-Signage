from pathlib import Path
import re,json
p=Path(r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\routed_init_no_bot_legacy_004\mapped.v')
s=re.sub(r'//[^\n]*','',p.read_text())
cells=[]
for m in re.finditer(r'(EG_PHY_\w+)\s*#\((.*?)\)\s*([^\s(]+)\s*\((.*?)\);',s,re.S):
 typ,par,name,port=m.groups()
 pars=dict(re.findall(r'\.(\w+)\((.*?)\)',par))
 ports=dict(re.findall(r'\.(\w+)\((.*?)\)',port))
 cells.append(dict(type=typ,name=name,params=pars,ports=ports))
def bits(e):
 e=e.strip()
 if e.startswith('{'):return sum((bits(x) for x in e[1:-1].split(',')),[])
 m=re.fullmatch(r'(\\\S+)\s+\[(\d+):(\d+)\]',e)
 if m:return [m[1]+' ['+str(x)+']' for x in range(int(m[2]),int(m[3])-1,-1)]
 m=re.fullmatch(r"(\d+)'b([01]+)",e)
 if m:return list(m[2])
 return [e]
dr={}
for c in cells:
 for port in ['f','q','fco']:
  if port in c['ports']:
   bb=bits(c['ports'][port])
   for i,b in enumerate(reversed(bb)):dr[b]=(c,port,i)
stem='\\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/'
seen=set(); selected=[]
def walk(n):
 if n in seen:return
 seen.add(n)
 if n not in dr:return
 c,port,ix=dr[n]
 if port=='q':return
 selected.append(c)
 for pp in ['a','b','c','d','e','mi','fci']:
  for nn in bits(c['ports'].get(pp,"2'b00")):walk(nn)
for tail in ['u_hdmi_video_source/O_video_sof_n2_syn_4','u_hdmi_video_source/O_video_sof_n2_syn_6','u_hdmi_video_source/O_video_sof_n2_syn_8','u_hdmi_video_source/S_line_cnt_b3[2]_syn_6','u_hdmi_video_source/O_video_sol_n2_syn_2','u_hdmi_video_source/S_line_cnt_b1_n','u_hdmi_video_source/S_col_cnt_b3_n']:
 walk(stem+tail)
print(json.dumps(cells,indent=2))
