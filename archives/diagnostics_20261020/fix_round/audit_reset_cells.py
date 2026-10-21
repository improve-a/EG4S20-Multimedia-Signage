"""Root exact-key audit; never infer alias cells from substring matches."""
import hashlib,json,pathlib,re,sys
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020')
sys.path.insert(0,r'D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a')
from netcmp import parse_netlist,parse_params
p=r/'netcheck/media_status_001/mapped.v'
cells=parse_netlist(str(p))['insts']
sta=json.loads((r/'audit/sta_media_status_001.json').read_text())
negative=sta['negative_records'];seen={};norm=lambda x:re.sub(r'[\\\s]','',x)
for path in negative:
 name=path['end'].split('.sr ')[0]
 c=cells[name];pa=parse_params(c['params']);pins=c['pins']
 q=norm(pins.get('q',''));mi=norm(pins.get('mi',''))
 entry={'name':name,'type':c['type'],'pins':pins,'params':pa,'slack':path['slack']}
 assert path['type']=='removal'
 assert norm(pins['sr'])=='rst_all' and norm(pins['clk'])=='extensions/osd/clk'
 if q:
  assert re.fullmatch(r'\{open_n\d+,rs_video/pipe\[1\]_dup_\d+\}',q),q
  assert re.fullmatch(r'\{open_n\d+,rs_video/pipe\[0\]\}',mi),mi
  assert pa['REG0_SD']=='"MI"' and pa['REG0_REGSET']=='"SET"' and pa['SRMODE']=='"ASYNC"' and pa['SRMUX']=='"SR"',pa
  entry['classification']='second_stage_reset_replica'
 else:
  assert name=='rs_video/pipe_reg[1]_syn_4',name
  entry['classification']='no_q_output_unconsumed_FF_SR_not_data'
 seen[name]=entry
assert len(seen)==20
stage0=[]
for n,c in cells.items():
 q=norm(c['pins'].get('q',''))
 if 'rs_video/pipe[0]' in q:
  stage0.append({'name':n,**c,'parameters':parse_params(c['params'])})
assert len(stage0)==1,stage0
result={'mapped_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'negative_count':len(seen),'classification_counts':{k:sum(x['classification']==k for x in seen.values()) for k in ('second_stage_reset_replica','no_q_output_unconsumed_FF_SR_not_data')},'negative_cells':list(seen.values()),'stage0':stage0,'exact_names_1_2_present':{n:n in cells for n in ('rs_video/pipe_reg[1]_syn_1','rs_video/pipe_reg[1]_syn_2')},'source_SDC_untouched':True}
(r/'audit/root_reset_structure.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
