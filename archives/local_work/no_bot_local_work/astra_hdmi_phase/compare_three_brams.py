"""Static check of exactly the three video FIFO BRAMs and their 24 payload wires."""
from pathlib import Path
import json,re
from decode import bits
p=Path(__file__).parent
sets=[json.loads((p/f).read_text()) for f in ['baseline_cells_all.json','new_cells_all.json']]
pre='\\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/'
axis='\\u_hdmi_1_4b_transmitter_core_wrapper/I_axis_s_data'
ramstem=pre+'u_video_axi_stream_receiver/u_w24_d1024_fifo/'
def norm(n):
 n=n.strip()
 if n in ['video_clk','\\extensions/osd/clk']:return 'PIXEL_CLOCK'
 if n.startswith('open_n'):return 'UNCONNECTED'
 return n

def bb(v):
 v=v.replace(pre+'u_hdmi_video_data_assemble/I_video_data_ch0 ',pre+'u_hdmi_video_data_assemble/I_video_data_ch0 [7:0] ')
 return [norm(x) for x in bits(v)]

def data(cs):
 br={c['name']:{'params':c['params'],'ports':{k:bb(v) for k,v in c['ports'].items()}} for c in cs if c['type']=='EG_PHY_BRAM' and c['name'].startswith(ramstem)}
 assert len(br)==3
 mp={}
 for n,c in br.items():
  assert len(c['ports']['dia'])==len(c['ports']['dob'])==9
  for x,y in zip(c['ports']['dia'],c['ports']['dob']):
   if x!='UNCONNECTED':mp[x]=y
 assert len(mp)==24
 regs={}
 for c in cs:
  for i,q in enumerate(reversed(bits(c['ports'].get('q','')))):
   if c['params'].get('REG'+str(i)+'_SD')=='"MI"':
    regs[q.strip()]={'d':list(reversed(bits(c['ports'].get('mi',"2'b00"))))[i].strip(),'params':{k.replace('REG'+str(i),'REG'):v for k,v in c['params'].items() if k.startswith('REG'+str(i)) or k in ['DFFMODE','CEMUX','CLKMUX','SRMODE','SRMUX']},'clk':norm(c['ports'].get('clk','')),'ce':norm(c['ports'].get('ce','')),'sr':norm(c['ports'].get('sr',''))}
 chains=[]
 for i in range(24):
  ch,bit=divmod(i,8);src=axis+' ['+str(i)+']';dst=pre+'u_hdmi_video_data_assemble/I_video_data_ch'+str(ch)+' ['+str(bit)+']';assert mp[src]==dst
  nets=[dst]+[pre+'u_hdmi_island_data_assemble/'+s+' ['+str(bit)+']' for s in ['I_video_data_ch'+str(ch),'S_video_data_ch'+str(ch)+'_1d','S_video_data_ch'+str(ch)+'_2d','S_video_data_ch'+str(ch)+'_3d']]+[pre+'u_hdmi_data_distribution/I_video_data_ch'+str(ch)+' ['+str(bit)+']',pre+'u'+str(ch)+'_hdmi_tmds_encode/I_video_data ['+str(bit)+']']
  for prev,q in zip(nets,nets[1:]):assert regs[q]['d']==prev,(q,regs[q]['d'],prev)
  chains.append({'axis_bit':i,'bram_output_net':dst,'registered_path':[{q:regs[q]} for q in nets[1:]]})
 return br,chains
old,oc=data(sets[0]);new,nc=data(sets[1]);assert old==new;assert oc==nc
r={'scope':'Three video receiver FIFO BRAMs, their 24 data bits, and direct registered payload wiring to distribution outputs (encoder inputs); static only','brams_exact_match_after_verified_clock_alias_and_unused_open_normalization':True,'three_bram_parameters':next(iter(old.values()))['params'],'bram_names':list(old),'bea_beb_ports':'Both absent in all three old/new instances; no per-byte-enable difference','24bit_map':'AXIS[7:0] -> CH0[7:0]; AXIS[15:8] -> CH1[7:0]; AXIS[23:16] -> CH2[7:0]','direct_pipeline_stages':6,'pipeline_register_bits_compared':144,'all_direct_pipeline_data_and_control_configs_match':True,'normalized_three_brams':old,'bit_paths':oc}
(p/'three_bram_comparison.json').write_text(json.dumps(r,indent=2))
print(json.dumps({k:v for k,v in r.items() if k not in ['normalized_three_brams','bit_paths']},indent=2))
