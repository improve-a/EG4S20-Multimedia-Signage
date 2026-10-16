#!/usr/bin/env python3
"""Windows-only focused RTL checks; exact top block extraction and existing runner.
No TD/hardware actions. FIFO boundary stubs do not verify storage payloads.
"""
import datetime,hashlib,importlib.util,json,os,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
 out=ROOT/'output/html_fidelity/timing_fix'/('reset_fault_'+stamp);out.mkdir(parents=True,exist_ok=False)
 top=(ROOT/'rtl/top_tf_hdmi_audio.v').read_text(encoding='utf-8')
 declaration=re.search(r'^.*reg \[5:0\] fault50_meta,fault50_sync;\s*$',top,re.M)
 block=re.search(r'always @\(posedge clk or posedge rst_all\)\s*\n if\(rst_all\)begin fault50_meta<=0;fault50_sync<=0;end\s*\n else begin\s*\n  fault50_meta<=\{scene_error,panel_error,tag_fault,frame_fault_sources\};\s*\n  fault50_sync<=fault50_meta;\s*\n end',top)
 display=re.search(r'^assign display_state = \(\|fault50_sync\) \? 4\x27ha : state_code50;\s*$',top,re.M)
 assert declaration and block and display,'Current top shape differs: review extraction before proceeding'
 wrapper='module fault50_extract(input clk,rst_all,scene_error,panel_error,tag_fault,input[2:0]frame_fault_sources,input[3:0]state_code50,output[3:0]display_state,output[5:0]observed_meta,observed_sync);\n'+declaration.group(0)+'\n'+block.group(0)+'\n'+display.group(0)+'\nassign observed_meta=fault50_meta;assign observed_sync=fault50_sync;\nendmodule\n'
 spec=importlib.util.spec_from_file_location('existing_runner',ROOT/'scripts/run_regression.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 names=['tests/timing_reset_fault_tb.v','rtl/reset_sync.v','rtl/SD/frame_read_write.v','rtl/SD/frame_fifo_write.v','rtl/SD/frame_fifo_read.v']
 payloads={n:(ROOT/n).read_bytes() for n in names};payloads['generated/fault50_extract.v']=wrapper.encode()
 cases=[dict(id='timing_reset_fault',recipe_reference='Actual reset/frame RTL; exact current-top fault50 block; FIFO boundary stubs only',top='timing_reset_fault_tb',sources=names+['generated/fault50_extract.v'],inputs=names+['generated/fault50_extract.v'],parameters=[],timeout=30)]
 mailbox=['tests/timing_mailbox_hold_tb.v','rtl/ext/frame_config_bridge.v']
 for n in mailbox:payloads[n]=(ROOT/n).read_bytes()
 cases.append(dict(id='timing_mailbox_hold',recipe_reference='ActualWIDTH51/3 mailbox:5phase trials, beforecapture/ackroundtrip bounds, rapidupdates/frame stalls/resetaborts',top='timing_mailbox_hold_tb',sources=mailbox,inputs=mailbox,parameters=[],timeout=30))
 recipes=json.loads((ROOT/'output/venue_emergency_ui/evidence/regression_recipes.json').read_text(encoding='utf-8'))['recipes']
 for key in ['config_002','audio_fifo_bram_001']:
  q=recipes[key]
  for n in q['inputs']:payloads[n]=(ROOT/n).read_bytes()
  cases.append(dict(id='replay_'+q['top'],recipe_reference=key,top=q['top'],sources=q['sources'],inputs=list(q['inputs']),parameters=q['parameters'],timeout=q['timeout']))
 for n,b in payloads.items():
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 plan=dict(tests=cases,source_sha256={n:sha(b)for n,b in payloads.items()},top_source_sha256=sha((ROOT/'rtl/top_tf_hdmi_audio.v').read_bytes()),entry_script_sha256=sha(Path(__file__).read_bytes()),existing_runner_sha256=sha((ROOT/'scripts/run_regression.py').read_bytes()),extraction=[dict(start_line=top[:x.start()].count('\n')+1,end_line=top[:x.end()].count('\n')+1,sha256=sha(x.group(0).encode()))for x in [declaration,block,display]],scope='UNIT_SIM only; actual reset_sync/frame_read_write and exact top fault50 block. Fulltop/encryptedIP/storagepayload/metastability/physicaltiming not simulated.')
 (out/'plan.json').write_text(json.dumps(plan,indent=2),encoding='utf-8');(out/'existing_runner.py').write_text(m.REMOTE_RUNNER,encoding='utf-8')
 start=time.monotonic();cmd=[sys.executable,'-X','utf8',str(out/'existing_runner.py'),str(out)]
 with (out/'dispatch.log').open('w',encoding='utf-8')as log:
  p=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);code=p.wait(timeout=300)
 summary=json.loads((out/'results/regression_summary.json').read_text()) if(out/'results/regression_summary.json').exists()else{}
 summary.update(dispatch_pid=p.pid,dispatch_exit=code,dispatch_wall_seconds=time.monotonic()-start,dispatch_command=cmd,driver_pid=os.getpid(),scope=plan['scope'],top_source_unchanged=sha((ROOT/'rtl/top_tf_hdmi_audio.v').read_bytes())==plan['top_source_sha256'],extraction=plan['extraction'])
 contract_log=out/'results/timing_mailbox_hold/simulation.log'
 if contract_log.exists():
  records=[]
  for line in contract_log.read_text().splitlines():
   if line.startswith('MAILBOX_CONTRACT '):
    values=dict(re.findall(r'(\w+)=([0-9.]+)',line));records.append({k:float(v) if '.' in v else int(v) for k,v in values.items()})
  summary['mailbox_contract_trials']=records
  summary['mailbox_scope']='IdealRTLclock simulation of actualframe_config_bridge WIDTH51/3; coordinatedresetaborts excluded fromtimingminima; notmetastability/physicaldelay proof.'
 (out/'verification.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
 print((out/'dispatch.log').read_text(encoding='utf-8'));print('TIMING_RESET_FAULT_EVIDENCE='+str(out));print('RESULT='+summary.get('status','FAIL'))
 return 0 if code==0 and summary.get('status')=='PASS' and summary['top_source_unchanged'] else 1
if __name__=='__main__':raise SystemExit(main())
