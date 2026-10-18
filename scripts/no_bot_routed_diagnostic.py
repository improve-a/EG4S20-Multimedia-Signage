"""Read-only final-route SPI initialization STA and mapped-netlist export.
Copies the completed route DB into a unique directory; does not run PNR or bitgen.
"""
import argparse,datetime,hashlib,json,os,pathlib,subprocess,time,traceback
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def save(p,value):
 q=p.with_suffix('.tmp');q.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8');os.replace(q,p)
def main():
 a=argparse.ArgumentParser();a.add_argument('run_id');a.add_argument('--timeout',type=int,default=600);x=a.parse_args()
 build=ROOT/'output/html_fidelity/builds'/x.run_id
 status=json.loads((build/'runs'/x.run_id/'status.json').read_text())
 if status['state']!='FINISHED' or status['exit_code']!=0: raise RuntimeError('Requires a completed fresh build')
 project=build/'work/design/td_project';phy=project/'hx4s20_basic_Runs/phy_1'
 db=phy/'hx4s20_basic_pr.db'
 sdc=build/'work/design/user_source/constraints_source/timing.sdc'
 if not db.exists() or not sdc.exists(): raise RuntimeError('Missing final DB/SDC')
 out=ROOT/'output/html_fidelity/no_bot/verify'/('routed_init_'+x.run_id)
 out.mkdir(parents=True,exist_ok=False)
 script=ROOT/'harness/spi_init_timing.tcl'
 local_script=out/'spi_init_timing.tcl';local_script.write_bytes(script.read_bytes())
 td=pathlib.Path(r'G:\anlu\bin\td_commands_prompt.exe')
 inputs={str(p):{'sha256':sha(p),'bytes':p.stat().st_size} for p in [db,sdc,script,td]}
 data={'state':'RUNNING','scope':'Final routed DB copied; init-mode user SDC only; mapped netlist export; no implementation or bitgen',
       'run_id':x.run_id,'source_sha':json.loads((build/'audit/baseline_manifest.json').read_text())['git_commit'],
       'inputs':inputs,'supervisor_pid':os.getpid(),'started_utc':now(),'timeout_seconds':x.timeout}
 start=time.monotonic();proc=None;save(out/'status.json',data)
 try:
  env=os.environ.copy();env['ANLOGIC_DB_SOURCE']=str(db);env['ANLOGIC_PROD_SDC']=str(sdc)
  with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
   proc=subprocess.Popen([str(td)],cwd=out,env=env,stdin=subprocess.PIPE,stdout=stdout,stderr=stderr)
   data['td_pid']=proc.pid;save(out/'status.json',data)
   command='if {[catch {source {'+local_script.as_posix()+'}} diagnostic_error]} {puts stderr $diagnostic_error; exit 2}\nexit 2\n'
   proc.communicate(command.encode(),timeout=x.timeout)
  data['exit_code']=proc.returncode
  required=['mapped.v','init_timing.rpt','init_exceptions.rpt','init_ignored.rpt','init_clocks.rpt','init_check.rpt']
  data['reports_present']=all((out/f).is_file() for f in required)
  data['inputs_unchanged']=all(sha(pathlib.Path(p))==v['sha256'] for p,v in inputs.items())
  data['state']='PASS' if proc.returncode==0 and data['reports_present'] and data['inputs_unchanged'] else 'FAIL'
 except Exception:
  data['state']='ERROR';data['exception']=traceback.format_exc()
  if proc and proc.poll() is None:
   subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True);proc.wait()
 finally:
  data['wall_seconds']=round(time.monotonic()-start,3);data['finished_utc']=now()
  save(out/'status.json',data)
  save(out/'artifacts.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(out.iterdir()) if p.is_file() and p.name!='artifacts.json'])
 print(json.dumps(data,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
