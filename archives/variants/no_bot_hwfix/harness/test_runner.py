"""Explicit Windows Icarus test runner. Supply only unencrypted, simulation-ready sources."""
import argparse,json,pathlib,subprocess,time,hashlib,datetime,os

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--top',required=True);ap.add_argument('--output',required=True);ap.add_argument('--cwd');ap.add_argument('--sim-timeout',type=int,default=120);ap.add_argument('--language',choices=['2005','2012'],default='2012');ap.add_argument('--parameter',action='append',default=[]);ap.add_argument('sources',nargs='+');a=ap.parse_args()
 out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=False)
 src=[str(pathlib.Path(x).resolve(strict=True)) for x in a.sources]
 result={'schema_version':1,'SIM':'FAIL','scope':'explicit_testbench_only','top':a.top,'sources':src,'source_sha256':{s:hashlib.sha256(pathlib.Path(s).read_bytes()).hexdigest() for s in src},'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':os.getpid()};t=time.monotonic()
 try:
  compile_cmd=[r'C:\iverilog\bin\iverilog.exe','-g'+a.language,'-DHTML_SIM','-s',a.top,'-o',str(out/'sim.vvp')]+['-P'+x for x in a.parameter]+src
  result['compile_command']=compile_cmd;result['parameter_overrides']=a.parameter
  c=subprocess.run(compile_cmd,capture_output=True,timeout=120,cwd=a.cwd);(out/'compile.log').write_bytes(c.stdout+c.stderr);result['compile_exit']=c.returncode
  if c.returncode==0:
   with (out/'simulation.log').open('wb') as log:
    p=subprocess.run([r'C:\iverilog\bin\vvp.exe',str(out/'sim.vvp')],stdout=log,stderr=subprocess.STDOUT,timeout=a.sim_timeout,cwd=a.cwd)
   result['simulation_exit']=p.returncode
   # Explicit completion token prevents a silently incomplete simulation from passing.
   result['SIM']='PASS' if p.returncode==0 and b'TEST_PASS' in (out/'simulation.log').read_bytes() else 'FAIL'
 except subprocess.TimeoutExpired:result['SIM']='TIMEOUT'
 result['elapsed_seconds']=time.monotonic()-t
 (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result));return 0 if result['SIM']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
