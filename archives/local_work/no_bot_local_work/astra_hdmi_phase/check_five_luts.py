"""Reuse decoded mapped LUT evaluator on five changed F/FX selections."""
import json,itertools,hashlib
from pathlib import Path
import decode
from decode import bits
p=Path(__file__).parent
cs=[json.loads((p/f).read_text()) for f in ['baseline_cells_all.json','new_cells_all.json']]
dr=[]
for cells in cs:
 d={}
 for c in cells:
  for port in ['f','q','fco','fx']:
   for i,b in enumerate(reversed(bits(c['ports'].get(port,'')))):d[b.strip()]=(c,port,i)
 dr.append(d)
changes=json.loads((p/'output_chain_comparison.json').read_text())['register_input_selection_changes']
pre='\\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/'
results=[]
for ch in changes:
 q=ch['q'];c,port,i=dr[0][q.strip()]
 if '/S_cnt_t_1 [1]' in q:
  ep=pre+'u2_hdmi_tmds_encode/'
  inputs=[ep+x for x in ['S_cnt_t_1_b2_n1','add14_syn_3 [3]','add15_syn_3 [3]','S_cnt_t_1 [4]','S_N_0_q_m_0_7 [3]','S_N_1_q_m_0_7 [3]','S_N_0_q_m_0_7 [1]','S_N_0_q_m_0_7 [2]','S_N_1_q_m_0_7 [1]','S_N_1_q_m_0_7 [2]','S_cnt_t_1_b6 [1]','S_cnt_t_1_b7 [1]']]+[pre+'u0_hdmi_tmds_encode/S_video_valid_2d']
 else:inputs=[list(reversed(bits(c['ports'][pn])))[i].strip() for pn in 'abcde']
 inputs=sorted(set(inputs)); tables=[]
 for side in range(2):
  # Existing decoder strips names in val(); driver dictionary normalized accordingly.
  decode.dr=dr[side]
  table=[]
  for n in range(1<<len(inputs)):
   overrides={x:(n>>i)&1 for i,x in enumerate(inputs)}
   table.append(decode.evaluate(q.strip(),0,0,d_input=True,overrides=overrides))
  tables.append(bytes(table))
 mismatches=sum(x!=y for x,y in zip(*tables))
 results.append({'q':q,'inputs_sorted':inputs,'assignments':len(tables[0]),'mismatches':mismatches,'old_sha256':hashlib.sha256(tables[0]).hexdigest(),'new_sha256':hashlib.sha256(tables[1]).hexdigest()})
 assert mismatches==0,results[-1]
(p/'five_lut_truth_tables.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
