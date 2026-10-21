"""Export exact new gate DB and run inherited init-mode STA on a route copy."""
import argparse,hashlib,json,os,pathlib,re,subprocess,sys,time
repo=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(repo/'harness'))
from report_parser import timing
p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('ids',nargs='+');a=p.parse_args()
TD=r'G:\anlu\bin\td_commands_prompt.exe'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for id in a.ids:
 b=a.root/'builds'/id
 out=a.root/'netcheck'/id;out.mkdir(parents=True,exist_ok=False)
 gate=b/'work/design/td_project/hx4s20_basic_Runs/syn_1/hx4s20_basic_gate.db'
 route=b/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic_pr.db'
 sdc=b/'work/design/user_source/constraints_source/timing.sdc'
 state=json.loads((b/'runs'/id/'status.json').read_text(encoding='utf-8'))
 assert state['state']=='FINISHED',state
 hashes={str(x):sha(x) for x in (gate,route,sdc)}
 gatecopy=out/'gate.db';gatecopy.write_bytes(gate.read_bytes())
 tcl=out/'export_gate.tcl'
 tcl.write_text(f'import_device eagle_s20.db -package EG4S20BG256\nimport_db {{{gatecopy.as_posix()}}}\nwrite_verilog {{{(out/"gate.v").as_posix()}}} -nobuf\nexit 0\n')
 steps=[]
 for name,script,env in [('gate',tcl,os.environ.copy()),('init',b/'harness/spi_init_timing.tcl',{**os.environ,'ANLOGIC_DB_SOURCE':str(route),'ANLOGIC_PROD_SDC':str(sdc)})]:
  command=f'if {{[catch {{source {{{script.as_posix()}}}}} err]}} {{puts stderr $err; exit 2}}\nexit 2\n'
  start=time.monotonic()
  with (out/(name+'.stdout.log')).open('wb') as stdout,(out/(name+'.stderr.log')).open('wb') as stderr:
   pr=subprocess.run([TD],cwd=out,env=env,input=command.encode(),stdout=stdout,stderr=stderr,timeout=120)
  steps.append({'name':name,'exit_code':pr.returncode,'seconds':time.monotonic()-start})
  assert pr.returncode==0,steps
 text=(out/'gate.v').read_text(errors='replace')
 seq=re.findall(r'\bAL_MAP_SEQ\s*#\s*\((.*?)\)\s*(\\\S+|\w+)\s*\((.*?)\);',text,re.S)
 assert len(seq)==len(re.findall(r'\bAL_MAP_SEQ\s*#',text))
 names=[x[1].lstrip('\\') for x in seq]
 patterns={
  'core_locked':r'/O_video_locked_reg$',
  'core_ready':r'/S_video_in_ready_reg$',
  'axis_last':r'^u_video_rgb_to_axis_640x480/O_video_last_reg$',
  'axis_x_count':r'^u_video_rgb_to_axis_640x480/S_x_cnt_reg\[',
  'probe_frame_count':r'^probe/frame_pixels_reg\[',
  'probe_line_count':r'^probe/line_pixels_reg\[',
  'probe_lock_ever':r'^probe/lock_ever_reg$',
 }
 selected={k:[n for n in names if re.search(v,n)] for k,v in patterns.items()}
 counts={k:len(v) for k,v in selected.items()}
 assert counts['core_locked']==1,counts
 if id.startswith('rca_no_locked'):
  assert counts['core_ready']==1 and counts['axis_last']==1 and counts['axis_x_count']==11,counts
  assert counts['probe_lock_ever']==0 and counts['probe_frame_count']>0,counts
 elif id.startswith('rca_locked_only'):
  assert counts['core_ready']==counts['axis_last']==counts['axis_x_count']==counts['probe_frame_count']==counts['probe_line_count']==0,counts
  assert counts['probe_lock_ever']==1,counts
 init=timing((out/'init_timing.rpt').read_text(errors='replace'))
 assert len(init)==2 and all(v['wns_ns']>=0 and v['tns_ns']==0 for v in init.values()),init
 assert all(sha(pathlib.Path(k))==v for k,v in hashes.items())
 result={'run_id':id,'state':'SCOPED_PASS','steps':steps,'source_hashes':hashes,'gate_v_sha256':sha(out/'gate.v'),'mapped_route_sha256':sha(out/'mapped.v'),'total_al_map_seq':len(seq),'observer_counts':counts,'observer_nodes':selected,'init_timing':init,'input_DB_and_SDC_unchanged':True,'scope':'Observer retention/removal assertions and inherited SPI-init STA only. Not full netlist formal equivalence or board-level timing signoff.'}
 (out/'receipt.json').write_text(json.dumps(result,indent=2))
 print(json.dumps(result,indent=2))
