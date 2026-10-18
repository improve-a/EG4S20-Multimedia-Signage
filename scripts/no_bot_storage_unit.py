"""Authored cache stream contract tests; no vendor/netlist cone is published.
Run with --cache PATH for an immutable candidate before source promotion.
Abstract busy and ordered memory returns are independent models. This is unit
protocol evidence, not SDRAM electrical timing or full-system/HW verification.
"""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--cache',type=Path,default=ROOT/'rtl/ext/html_layer_cache.v');p.add_argument('--output',type=Path)
 a=p.parse_args();out=a.output or ROOT/'output/html_fidelity/no_bot/storage'/('unit_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 cache=out/'cache.v';cache.write_bytes(a.cache.read_bytes());bench=out/'no_bot_storage_tb.v';bench.write_bytes((ROOT/'tests/no_bot_storage_tb.v').read_bytes())
 iv=Path(r'C:\iverilog\bin\iverilog.exe');vvp=Path(r'C:\iverilog\bin\vvp.exe')
 report={'state':'RUNNING','scope':'Authored unit busy/ordered-return contract; mem_ready stays high after init. No native cone, full-system, or hardware claim.','started':time.time(),'pid':os.getpid(),'input':str(a.cache),'source_sha256':sha(cache),'bench_sha256':sha(bench),'tools':{str(x):sha(x) for x in [iv,vvp]},'steps':[]}
 def save():(out/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
 def run_case(name,source,top,params=None,defines=None,negative=False):
  cmd=[str(iv),'-g2005-sv','-DHTML_SIM','-s',top,'-o',str(out/(name+'.vvp'))]
  cmd += ['-D'+v for v in (defines or [])]
  cmd += ['-P'+top+'.'+k+'='+str(v) for k,v in (params or {}).items()]
  cmd += [str(source),str(bench if top=='no_bot_storage_tb' else out/'compat_tb.v')]
  t=time.time();c=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30)
  (out/(name+'.compile.log')).write_bytes((c.stdout+c.stderr).encode())
  result={'name':name,'command':cmd,'compile_exit':c.returncode,'expected':'UNSAFE_RESTART' if negative else 'TEST_PASS'}
  if c.returncode==0:
   v=subprocess.run([str(vvp),str(out/(name+'.vvp'))],cwd=ROOT,capture_output=True,text=True,timeout=60)
   log=v.stdout+v.stderr;(out/(name+'.run.log')).write_bytes(log.encode());result.update(exit_code=v.returncode,output=log.strip())
   result['pass']=v.returncode!=0 and 'UNSAFE_RESTART' in log if negative else v.returncode==0 and 'TEST_PASS' in log
  else:result['pass']=False
  result['wall_seconds']=time.time()-t;report['steps'].append(result);save();print(name,'PASS' if result['pass'] else 'FAIL',result.get('output','')[-600:],flush=True)
  return result['pass']
 save()
 cases=[('latency6',{'LATENCY':6}),('latency10',{'LATENCY':10}),('latency11',{'LATENCY':11}),('latency32_ring_stalls',{'LATENCY':32,'SATURATION':1,'STALLS':1}),('variable6_10_11_32',{'VARIABLE':1,'STALLS':1}),('busy_first_beat',{'BUSY_RACE':1}),('phase3_refresh',{'REFRESH_RACE':1}),('reset_midquad',{'RESET_MID':1})]
 ok=True
 for name,params in cases:ok=run_case(name,cache,'no_bot_storage_tb',params) and ok
 # Negative: actual accepted HEAD baseline algorithm, with ignored compatibility
 # parameter/input only, allows the same checker to observe its unsafe restart.
 raw=subprocess.check_output(['git','show','HEAD:rtl/ext/html_layer_cache.v'],cwd=ROOT);baseline=raw.decode();baseline=baseline.replace('ENABLE_PHYSICAL_FAIRNESS=0','ENABLE_PHYSICAL_FAIRNESS=0,ENABLE_STREAM_HANDSHAKE=0',1).replace('output physical_busy\n','output physical_busy,input mem_busy\n',1)
 baseline_path=out/'baseline_adapter.v';baseline_path.write_bytes(baseline.encode());report['baseline_original_sha256']=hashlib.sha256(raw).hexdigest();report['baseline_adapter_sha256']=sha(baseline_path)
 ok=run_case('negative_original_baseline',baseline_path,'no_bot_storage_tb',{'HANDSHAKE':0},['NO_BOT_ORIGINAL_POLICY'],True) and ok
 # Existing 8192-task production-mode test, adding only the candidate's unused
 # final mem_busy input to its positional instantiation. Its test logic is intact.
 compat=(ROOT/'tests/html_layer_cache_tb.v').read_text();compat=compat.replace("busy,fault,1'b0,);","busy,fault,1'b0,,1'b0);")
 (out/'compat_tb.v').write_bytes(compat.encode());report['compat_original_sha256']=sha(ROOT/'tests/html_layer_cache_tb.v');report['compat_adapter_sha256']=sha(out/'compat_tb.v')
 for bits in [3,5]:ok=run_case('compat_slots'+str(1<<bits),cache,'html_layer_cache_tb',{'CACHE_SLOT_BITS':bits}) and ok
 report['state']='PASS' if ok else 'FAIL';report['finished']=time.time();report['wall_seconds']=report['finished']-report['started'];save();print('RESULT',report['state'],str(out/'verification.json'),flush=True)
 return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())
