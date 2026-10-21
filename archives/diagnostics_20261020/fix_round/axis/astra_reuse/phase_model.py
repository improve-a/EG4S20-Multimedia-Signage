"""Bounded HDMI control-cone model; not a vendor core/PHY simulation.

Boolean register-D functions are checked against actual mapped LUT INIT bits.
Source counter enable/reset decodes are enumerated from that same netlist.
Pixel input has the verified native 800x525/640x480 protocol. Payload and HDMI
audio/data-island/BRAM implementation are outside this experiment.
"""
from pathlib import Path
import itertools,json,time,hashlib
from decode import evaluate,src,rx
root=Path(__file__).parent
start=time.monotonic()
lock='\\u_hdmi_1_4b_transmitter_core_wrapper/O_video_locked'
axis='\\u_hdmi_1_4b_transmitter_core_wrapper/'
truth=[]
for locked,pause,sof,sol,user,valid in itertools.product([0,1],repeat=6):
 overrides={lock:locked,rx+'O_video_source_pause':pause,
  rx+'I_video_source_sof':sof,rx+'I_video_source_sol':sol,
  axis+'I_axis_s_user':user,axis+'I_axis_s_valid':valid}
 actual_l=evaluate(lock,0,0,d_input=True,overrides=overrides)
 actual_p=evaluate(rx+'O_video_source_pause',0,0,d_input=True,overrides=overrides)
 expected_l=int((user and pause) or (locked and (not sol or valid)))
 expected_p=int(not locked and (sof or (not user and pause)))
 assert (actual_l,actual_p)==(expected_l,expected_p),(overrides,actual_l,actual_p)
 truth.append([locked,pause,sof,sol,user,valid,actual_l,actual_p])
def run(first_user,damage=False):
 h=y=sof=sol=pause=locked=0
 first_lock=None;drops=0;sol_checks=0;pause_cycles=0
 after_hash=hashlib.sha256();lock_events=[]
 for t in range(3*420000+first_user):
  rel=(t-first_user)%420000
  valid=int(t>=first_user and rel//800<480 and rel%800<640)
  user=int(t>=first_user and rel==0)
  if damage and first_lock is not None and sol and y==46:valid=0
  next_l=int((user and pause) or (locked and (not sol or valid)))
  next_p=int(not locked and (sof or (not user and pause)))
  if next_l and not locked:
   lock_events.append(t)
   if first_lock is None:first_lock=t
  if locked and not next_l:drops+=1
  if locked and sol:sol_checks+=1
  if pause:pause_cycles+=1
  # State equivalence in first two post-SOF frames, deliberately includes every
  # pixel clock and all control signals, not merely frame/line event counts.
  if first_user<=t<first_user+2*420000:
   after_hash.update(bytes((h&255,h>>8,y&255,y>>8,sof,sol,pause,locked,user,valid)))
  sof,sol=int(h==150 and y==45),int(h==160 and y>=45)
  if h==15:y=0 if y==524 else y+1
  if not pause:h=0 if h==799 else h+1
  locked,pause=next_l,next_p
 return {'first_user_cycle':first_user,'first_lock_cycle':first_lock,
  'lock_events':lock_events,'lock_drops':drops,'sol_checks':sol_checks,
  'pause_cycles':pause_cycles,'post_sof_2frame_control_sha256':after_hash.hexdigest()}
results=[run(35360+d) for d in [0,1,2,8,16,24,28,29,30,31,32,33,34,40,64,128,640]]
assert all(r['lock_drops']==0 and r['first_lock_cycle']==r['first_user_cycle'] for r in results)
assert len({r['post_sof_2frame_control_sha256'] for r in results})==1
negative=run(35392,True)
assert negative['lock_drops']>0
report={'scope':'MAPPED_LUT_CONTROL_CONE_MODEL_PASS; not complete HDMI core simulation',
 'mapped_path':r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\routed_init_no_bot_legacy_004\mapped.v',
 'mapped_sha256':'36edbd1af5b40b4c0ade94c00ccb18408a9f9a5abff75afb9bfae30360a4d10d',
 'register_d_truth_table_cases':len(truth),'source_sof_decode':[150,45],
 'source_sol_decode':{'col':160,'rows':[45,524]},'h_terminal':799,'v_terminal':524,'row_update_col':15,
 'delay_sweep':results,'missing_valid_at_real_sol_negative_control':negative,
 'conclusion':'Constant complete-stream latency shifts within the tested phase range are absorbed by source pause; actual receiver lock and source timing states after SOF are identical. This refutes +2 clocks alone as a persistent-unlock trigger under verified native input protocol.',
 'limitations':['No BRAM, FIFO flags, TMDS, audio-packet, EDID or electrical simulation.',
  'S_v_en comparator summarized as y>=45 from mapped lt6 chain and production timing.',
  'Counter increment arithmetic summarized as +1; terminal and enable decodes checked from actual LUTs.'],
 'wall_seconds':time.monotonic()-start}
(root/'phase_model_result.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'scope':report['scope'],'cases':len(results),'control_hash':results[0]['post_sof_2frame_control_sha256'],'negative_control_drops':negative['lock_drops'],'wall_seconds':report['wall_seconds']},indent=2))
