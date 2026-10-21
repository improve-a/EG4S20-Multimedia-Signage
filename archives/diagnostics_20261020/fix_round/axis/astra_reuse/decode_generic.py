from pathlib import Path
import json,re
root=Path(__file__).parent
import os
cells=json.loads(Path(os.environ.get('CONE','cone.json')).read_text())
stem='\\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/'
src=stem+'u_hdmi_video_source/'
rx=stem+'u_video_axi_stream_receiver/'
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
 for port in ['f','q','fco','fx','o']:
  if port in c['ports']:
   for i,b in enumerate(reversed(bits(c['ports'][port]))):dr[b]=(c,port,i)
def lut(v,index):
 m=re.fullmatch(r"\d+'([bh])([0-9a-fA-F]+)",v)
 return int(m[2],2 if m[1]=='b' else 16)>>index&1
def evaluate(target,h,y,pause=0,d_input=False,overrides=None):
 cache={src+'S_col_cnt ['+str(i)+']':h>>i&1 for i in range(14)}
 cache.update({src+'S_line_cnt ['+str(i)+']':y>>i&1 for i in range(14)})
 # lt6 comparator has encoded constant 45 <= S_line_cnt (mapped lines116240..346).
 cache[src+'S_v_en']=int(y>=45)
 cache[rx+'O_video_source_pause']=pause
 cache.update(overrides or {})
 def val(n):
  n=n.strip()
  if n in ('0','1'):return int(n)
  if n in cache:return cache[n]
  if n.startswith('open_n'):return 0
  c,port,i=dr[n]
  if port=='q':raise ValueError('Unexpected sequential input '+n)
  if port not in ['f','fx']:raise ValueError('Unexpected arithmetic '+n)
  z=cell(c,i,port);cache[n]=z;return z
 def inp(c,p,i):
  bb=list(reversed(bits(c['ports'].get(p,"2'b00"))))
  return val(bb[i] if i<len(bb) else '0')
 def cell(c,i,port='f'):
  pp=c['params'];idx=sum(inp(c,p,i)<<j for j,p in enumerate('abcd'))
  if c['type']=='EG_PHY_LSLICE':
   assert pp.get('LSFMUX'+str(i),'"FUNC5"')=='"FUNC5"',c['name']
   key=('INIT_LUTG' if inp(c,'e',i) else 'INIT_LUTF')+str(i)
  else:
   assert pp.get('MODE','"LOGIC"')=='"LOGIC"',c['name']
   key='INIT_LUT'+str(i)
  return lut(pp.get(key,"16'b0"),idx)
 if d_input:
  c,port,i=dr[target];assert port=='q'
  mode=c['params']['REG'+str(i)+'_SD'].strip('"')
  if mode=='F':return cell(c,i)
  if mode=='FX':return cell(c,inp(c,'mi',0))
  if mode=='MI':return inp(c,'mi',i)
  raise ValueError(mode)
 return val(target)
if __name__=='__main__':
 checks={}
 for name in ['O_video_sof_n2_syn_4','O_video_sof_n2_syn_6','O_video_sof_n2_syn_8','S_line_cnt_b3[2]_syn_6','S_line_cnt_b1_n','S_col_cnt_b3_n']:
  if name in ['O_video_sof_n2_syn_8','S_line_cnt_b3[2]_syn_6']:
   matches=[y for y in range(525) if evaluate(src+name,150,y)]
  else:matches=[h for h in range(800) if evaluate(src+name,h,45)]
  checks[name]=matches
 checks['source_sof_col']=[h for h in range(800) if evaluate(rx+'I_video_source_sof',h,45,d_input=True)]
 checks['source_sof_row']=[y for y in range(525) if evaluate(rx+'I_video_source_sof',150,y,d_input=True)]
 checks['source_sol_col']=[h for h in range(800) if evaluate(rx+'I_video_source_sol',h,45,d_input=True)]
 checks['row_terminal']=[y for y in range(525) if evaluate(src+'S_line_cnt_b3_n',15,y)]
 print(json.dumps(checks,indent=2))
 Path(os.environ.get('TIMING_OUT',str(root/'decoded_timing.json'))).write_text(json.dumps(checks,indent=2))
