"""Bounded static comparison, not combinational/sequential equivalence checking."""
from pathlib import Path
import json, collections
from decode import bits
p=Path(__file__).parent
old=json.loads((p/'baseline_cells_all.json').read_text())
new=json.loads((p/'new_cells_all.json').read_text())
first='\\u_hdmi_1_4b_transmitter_core_wrapper/u0_reset_sync/S_sync_reset_1d'
reset_prefix='\\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_receiver_controller/I_rst'
def norm(n):
 n=(n or '').strip()
 if n in ['video_clk','\\extensions/osd/clk']:return 'PIXEL_CLOCK'
 return n

def regs(cs):
 out={};drivers={}
 for c in cs:
  for i,q in enumerate(reversed(bits(c['ports'].get('q','')))):
   drivers[q.strip()]=(c,i)
   if any(x in q for x in ['u_hdmi_data_distribution/','hdmi_tmds_encode/','u_hdmi2phy_wrapper/']):
    pp={k.replace('REG'+str(i),'REG'):v for k,v in c['params'].items() if k.startswith('REG'+str(i)) or k in ['DFFMODE','SRMODE','CLKMUX','CEMUX','SRMUX']}
    out[q]={'params':pp,'clk':norm(c['ports'].get('clk')),'sr':norm(c['ports'].get('sr')),'ce':norm(c['ports'].get('ce')),'mi':list(reversed(bits(c['ports'].get('mi',"2'b00"))))[i].strip()}
 clone_checks=[]
 for n in {r['sr'] for r in out.values() if r['sr'].startswith(reset_prefix)}:
  c,i=drivers[n]; pp=c['params']; mi=list(reversed(bits(c['ports']['mi'])))[i].strip()
  assert mi==first
  assert norm(c['ports']['clk'])=='PIXEL_CLOCK'
  assert norm(c['ports']['sr'])=='\\rs_video/pipe [1]'
  for k,v in {'CEMUX':'"1"','CLKMUX':'"CLK"','SRMODE':'"ASYNC"','SRMUX':'"SR"','REG'+str(i)+'_REGSET':'"SET"','REG'+str(i)+'_SD':'"MI"'}.items():assert pp[k]==v
  clone_checks.append(n)
 c,i=drivers[first];assert list(reversed(bits(c['ports']['mi'])))[i]=='0'
 assert norm(c['ports']['clk'])=='PIXEL_CLOCK' and norm(c['ports']['sr'])=='\\rs_video/pipe [1]'
 assert c['params']['REG'+str(i)+'_REGSET']=='"SET"' and c['params']['REG'+str(i)+'_SD']=='"MI"'
 for r in out.values():
  if r['sr'].startswith(reset_prefix):r['sr']='CORE_RESET_SYNC_CLONE'
 return out,sorted(clone_checks)
a,ac=regs(old);b,bc=regs(new);assert set(a)==set(b)
changes=[];mis=[]
for q in a:
 x,y=a[q].copy(),b[q].copy();px=x.pop('params').copy();py=y.pop('params').copy();sx=px.pop('REG_SD');sy=py.pop('REG_SD');assert px==py
 assert all(x[k]==y[k] for k in ['clk','sr','ce'])
 if sx!=sy:changes.append({'q':q,'old':sx,'new':sy})
 if sx==sy=='"MI"':
  assert x['mi']==y['mi'];mis.append(q)
om={c['name']:c for c in old};nm={c['name']:c for c in new}
pads=['HDMI_CLK_P_syn_2','HDMI_D0_P_syn_2','HDMI_D1_P_syn_2','HDMI_D2_P_syn_2']
for n in pads:assert om[n]==nm[n]
pll='\\video_pll_m0/pll_inst';assert om[pll]['params']==nm[pll]['params']
for k,v in om[pll]['ports'].items():
 assert len(bits(v))==len(bits(nm[pll]['ports'][k]))
 for x,y in zip(bits(v),bits(nm[pll]['ports'][k])):
  if not x.startswith('open_n'):assert x==y
r={'scope':'Static output-chain configuration/connectivity; not full netlist equivalence or physical timing verification','register_count':len(a),'register_names_exact_match':True,'normalized_control_configs_exact_match':True,'clock_counts':dict(collections.Counter(x['clk'] for x in a.values())),'direct_MI_input_exact_matches':len(mis),'register_input_selection_changes':changes,'old_verified_core_reset_clones':ac,'new_verified_core_reset_clones':bc,'four_tmds_pad_cells_exact_match':True,'video_pll_params_and_used_ports_exact_match':True,'pixel_clock_alias_evidence':'Both EG_PHY_GCLK video_pll_m0/bufg_feedback: clki(video_pll_m0/clk0_buf), clko old video_clk / new extensions/osd/clk. Read directly from mapped files.'}
(p/'output_chain_comparison.json').write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))
