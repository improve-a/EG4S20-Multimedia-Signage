#!/usr/bin/env python3
"""No-Bot verification supervisor. Offline only; WMI detached jobs survive SSH.
Each child keeps its original fresh snapshot/evidence. This index records process,
source/tool identity, exit and timing, without upgrading unit results to HW proof.
"""
import argparse,base64,datetime,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/html_fidelity/no_bot/verify'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj):
 t=p.with_suffix('.tmp');t.write_bytes((json.dumps(obj,indent=2)+'\n').encode());os.replace(t,p)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('suite',choices=['quick','overlay','audio','media','capture','delivery-audio']);ap.add_argument('--launch',action='store_true');ap.add_argument('--run-id');ap.add_argument('--native-busy-cone',type=Path);ap.add_argument('--subset',choices=['all','normal012','normal345','compare_zoom','natural'],default='all');ap.add_argument('--data-early',type=int,choices=[0,1],default=1);ap.add_argument('--timeout',type=int,default=8000);a=ap.parse_args()
 rid=a.run_id or (a.suite+'_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
 if not rid or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in rid):ap.error('invalid run-id')
 OUT.mkdir(parents=True,exist_ok=True);out=OUT/rid
 if a.launch:
  out.mkdir(exist_ok=False)
  cmd=[sys.executable,'-X','utf8',str(Path(__file__).resolve()),a.suite,'--run-id',rid,'--subset',a.subset,'--data-early',str(a.data_early),'--timeout',str(a.timeout)]
  if a.native_busy_cone:cmd+=['--native-busy-cone',str(a.native_busy_cone)]
  ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+subprocess.list2cmdline(cmd).replace("'","''")+"';CurrentDirectory='"+str(ROOT).replace("'","''")+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json; if($r.ReturnValue -ne 0){exit 1}"
  p=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True)
  (out/'dispatch.log').write_bytes(p.stdout+p.stderr)
  save(out/'dispatch.json',{'command':cmd,'exit_code':p.returncode,'launched_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'result':p.stdout.decode(errors='replace')});print(out);print(p.stdout.decode(errors='replace'));return p.returncode
 out.mkdir(exist_ok=True)
 quick=['scripts/html_control_verify.py','--run-id',rid,'--sim-timeout','600']
 for n in ['control_modes_tb','content_modes_tb','exhibit_interval_tb','exhibit_keys_tb','exhibit_resource_mode_tb','exhibit_layer_control_tb','exhibit_control_tb','exhibit_panel_mux_tb']:quick+=['--only',n]
 plans={'delivery-audio':[['scripts/no_bot_audio_delivery_verify.py']], 'quick':[quick,['scripts/html_integration_verify.py']], 'overlay':[['scripts/html_overlay_target_verify.py'],['scripts/html_osd_swap_verify.py']], 'audio':[['scripts/timing_audio_verify.py'],['scripts/no_bot_audio_delivery_verify.py']], 'media':[['scripts/html_fidelity_verify_io.py'],['scripts/html_fidelity_regression.py','--only','real_hfxl_hfxc_native_bmp','--only','real_hfxl_rejected_without_optin','--only','real_wav_dynamic_volume_mute_eof']], 'capture':[['scripts/html_display_chain_verify.py','--layered','--subset',a.subset,'--data-early',str(a.data_early),'--timeout',str(a.timeout)]+(['--native-busy-cone',str(a.native_busy_cone)] if a.native_busy_cone else [])]}
 files=[]
 for d in ['rtl','tests','scripts','harness']:
  files.extend(p for p in (ROOT/d).rglob('*') if p.is_file() and p.suffix in ['.v','.vh','.hex','.bin','.py','.json'])
 start=time.time();report={'state':'RUNNING','suite':a.suite,'pid':os.getpid(),'root':str(ROOT),'started_epoch':start,'python':sys.version,'source_sha256':{p.relative_to(ROOT).as_posix():sha(p) for p in files},'tools':{},'steps':[],'FULL_SYSTEM_SIM':'NOT_RUN','HARDWARE':'HARDWARE_NOT_TESTED','model_boundaries':'Fresh child evidence scopes apply; ideal fourbeat render model is not native SDRAM qualification. Audio uses byte transport; capture visualizer uses real-WAV peak ROM, not integrated PCM.'}
 report['git_head']=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True).stdout.strip()
 for tool in ['iverilog','vvp']:
  p=Path(r'C:\iverilog\bin')/(tool+'.exe');q=subprocess.run([str(p),'-V'],capture_output=True);report['tools'][tool]={'path':str(p),'sha256':sha(p),'exit_code':q.returncode,'identity':(q.stdout+q.stderr).decode(errors='replace')}
 save(out/'status.json',report)
 for index,args in enumerate(plans[a.suite]):
  cmd=[sys.executable,'-X','utf8']+args;log=out/(str(index)+'_'+Path(args[0]).stem+'.log');tick=time.time()
  with log.open('wb') as f:
   child=subprocess.Popen(cmd,cwd=ROOT,stdin=subprocess.DEVNULL,stdout=f,stderr=subprocess.STDOUT)
   item={'command':cmd,'pid':child.pid,'state':'RUNNING','started_epoch':tick,'log':str(log)};report['steps'].append(item);save(out/'status.json',report)
   try:code=child.wait(timeout=a.timeout)
   except subprocess.TimeoutExpired:
    subprocess.run(['taskkill','/PID',str(child.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);child.wait();code=124
  item.update(state='PASS' if code==0 else 'FAIL',exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save(out/'status.json',report)
 report['changed_during_run']=[n for n,h in report['source_sha256'].items() if not (ROOT/n).exists() or sha(ROOT/n)!=h]
 report.update(state='PASS' if all(x['exit_code']==0 for x in report['steps']) else 'FAIL',wall_seconds=time.time()-start,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 save(out/'status.json',report);return int(report['state']!='PASS')
if __name__=='__main__':raise SystemExit(main())
