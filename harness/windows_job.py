"""Detached Windows TD supervisor. Standard library only; never programs hardware."""
import argparse,ctypes,datetime,hashlib,json,os,pathlib,subprocess,time,traceback
from ctypes import wintypes

def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def atomic(p,data):
 t=p.with_suffix('.tmp');t.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');os.replace(t,p)
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def attach_kill_job():
 # Supervisor and every descendant belong to a kill-on-close Job Object.
 # Closing SSH does not close this WMI-launched process or its job handle.
 k=ctypes.WinDLL('kernel32',use_last_error=True)
 class BASIC(ctypes.Structure):
  _fields_=[('per_process',ctypes.c_int64),('per_job',ctypes.c_int64),('flags',wintypes.DWORD),('min_work',ctypes.c_size_t),('max_work',ctypes.c_size_t),('active',wintypes.DWORD),('affinity',ctypes.c_size_t),('priority',wintypes.DWORD),('scheduling',wintypes.DWORD)]
 class IO(ctypes.Structure):_fields_=[(x,ctypes.c_ulonglong) for x in ['read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes']]
 class EXT(ctypes.Structure):_fields_=[('basic',BASIC),('io',IO),('process_mem',ctypes.c_size_t),('job_mem',ctypes.c_size_t),('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]
 k.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR];k.CreateJobObjectW.restype=wintypes.HANDLE
 k.SetInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
 k.GetCurrentProcess.restype=wintypes.HANDLE
 k.AssignProcessToJobObject.argtypes=[wintypes.HANDLE,wintypes.HANDLE]
 handle=k.CreateJobObjectW(None,None)
 if not handle:raise ctypes.WinError(ctypes.get_last_error())
 info=EXT();info.basic.flags=0x2000 # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
 if not k.SetInformationJobObject(handle,9,ctypes.byref(info),ctypes.sizeof(info)):raise ctypes.WinError(ctypes.get_last_error())
 if not k.AssignProcessToJobObject(handle,k.GetCurrentProcess()):raise ctypes.WinError(ctypes.get_last_error())
 # Keep the handle alive for process lifetime; process teardown closes it.
 return handle

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',required=True);ap.add_argument('--run-id',required=True);ap.add_argument('--timeout',type=int,default=3600);a=ap.parse_args()
 root=pathlib.Path(a.root).resolve();job=root/'runs'/a.run_id;job.mkdir(parents=True,exist_ok=False)
 state={'schema_version':1,'run_id':a.run_id,'state':'STARTING','started_utc':now(),'supervisor_pid':os.getpid(),'td_pid':None,'timeout_seconds':min(a.timeout,3600),'exit_code':None,'root':str(root)}
 atomic(job/'status.json',state);p=None;t=time.monotonic();budget_lock=None
 try:
  job_handle=attach_kill_job();state['job_object']='KILL_ON_JOB_CLOSE'
  manifest=json.loads((root/'audit/baseline_manifest.json').read_text(encoding='utf-8'))
  if manifest.get('task_root'):
   task_root=pathlib.Path(manifest['task_root']);lock=task_root/'audit/build.lock'
   fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY);os.close(fd);budget_lock=lock
   ledger_path=task_root/'audit/build_budget.json'
   ledger=json.loads(ledger_path.read_text()) if ledger_path.exists() else {'attempts':[]}
   used=0
   for prior in ledger['attempts']:
     previous=json.loads(pathlib.Path(prior['status']).read_text(encoding='utf-8'))
    if previous['state'] in ['STARTING','RUNNING']:raise RuntimeError('Another build is active or unresolved')
    used+=previous.get('elapsed_seconds',0)
   state['prior_build_seconds']=used;state['attempt_number']=len(ledger['attempts'])+1
   ledger['attempts'].append({'run_id':a.run_id,'status':str(job/'status.json'),'snapshot_sha256':manifest['snapshot_sha256']});atomic(ledger_path,ledger)
  snapshots=[]
  for entry in manifest['selected']:
   f=root/'work/design'/entry['path']
   if manifest.get('schema_version')==2 and sha(f)!=entry['sha256']:raise RuntimeError('Prepared input changed: '+entry['path'])
   snapshots.append({'path':entry['path'],'sha256':sha(f),'bytes':f.stat().st_size})
  atomic(job/'inputs.json',snapshots)
  state['td_executable']=r'G:\anlu\bin\td_commands_prompt.exe';state['td_sha256']=sha(pathlib.Path(state['td_executable']))
  state['tcl_sha256']=sha(root/'harness/build.tcl');state['baseline_import_sha256']=manifest['zip_sha256'];state['source_zip_sha256']=(root/'audit/package_sha256.txt').read_text().strip();state['snapshot_sha256']=manifest['snapshot_sha256']
  script=job/'build.tcl';script.write_text((root/'harness/build.tcl').read_text().replace('@RUN_DIR@',str(job).replace('\\','/')).replace('@ROOT@',str(root).replace('\\','/')),encoding='utf-8')
  env=os.environ.copy();env['ANLOGIC_RUN_DIR']=str(job).replace('\\','/')
  with (job/'stdout.log').open('wb',buffering=0) as out,(job/'stderr.log').open('wb',buffering=0) as err:
   p=subprocess.Popen([state['td_executable']],cwd=root/'work/design/td_project',stdin=subprocess.PIPE,stdout=out,stderr=err,env=env)
   p.stdin.write(('if {[catch {source {'+str(script).replace('\\','/')+'}} codex_error]} {puts stderr $codex_error; exit 2}\nexit 2\n').encode());p.stdin.close()
   state.update(state='RUNNING',td_pid=p.pid);atomic(job/'status.json',state)
   while p.poll() is None:
    state['elapsed_seconds']=round(time.monotonic()-t,3);state['heartbeat_utc']=now();atomic(job/'status.json',state)
    if state['elapsed_seconds']>=state['timeout_seconds']:
     state['state']='TIMEOUT';subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True);p.wait(timeout=15);break
    time.sleep(2)
   state['exit_code']=p.returncode
   state['flow_complete']='HARNESS_FLOW_COMPLETE' in (job/'stdout.log').read_text(errors='replace')
   if state['state']!='TIMEOUT':state['state']='FINISHED' if p.returncode==0 and state['flow_complete'] else 'FAILED'
 except Exception:
  state['state']='SUPERVISOR_ERROR';state['exception']=traceback.format_exc()
  if p and p.poll() is None:subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True)
 finally:
  state['elapsed_seconds']=round(time.monotonic()-t,3);state['finished_utc']=now();state['heartbeat_utc']=now();atomic(job/'status.json',state)
  artifacts=[]
  for base in [job,root/'work/design/td_project']:
   for f in base.rglob('*'):
    if f.is_file() and f.name!='artifacts.json':artifacts.append({'path':str(f.relative_to(root)),'bytes':f.stat().st_size,'mtime_utc':datetime.datetime.fromtimestamp(f.stat().st_mtime,datetime.timezone.utc).isoformat(),'sha256':sha(f)})
  atomic(job/'artifacts.json',artifacts)
  if budget_lock:budget_lock.unlink()
if __name__=='__main__':main()
