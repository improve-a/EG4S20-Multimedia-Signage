#!/usr/bin/env python3
"""Persist a read-only final pixel/APNG audit after the existing capture finishes.
Never starts or restarts an RTL simulation and never changes captured pixels.
"""
import datetime,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'output/html_fidelity/no_bot/verify/legacy_display_20261018T171156698167Z'
OUT=RUN/'final_audit_observer.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(d):
 p=OUT.with_suffix('.tmp');p.write_bytes((json.dumps(d,indent=2)+'\n').encode());os.replace(p,OUT)
def main():
 helper=ROOT/'scripts/no_bot_legacy_preview_audit.py';snapshot=RUN/'preview_audit_helper.py';snapshot.write_bytes(helper.read_bytes());d={'state':'WAITING_EXISTING_CAPTURE','pid':os.getpid(),'started_epoch':time.time(),'scope':__doc__,'helper_sha256':sha(snapshot),'helper_snapshot':str(snapshot),'capture_restarted':False};save(d)
 while time.time()-d['started_epoch']<30000:
  e=json.loads((RUN/'verification.json').read_text());d['observed_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();d['observed_capture_state']=e['state'];save(d)
  if e['state']=='LEGACY_DISPLAY_SEGMENT_PASS':
   t=time.time();cmd=[sys.executable,str(snapshot),'--run-root',str(RUN)]
   with(RUN/'final_audit_observer.log').open('wb')as f:
    p=subprocess.Popen(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT);d.update(state='AUDITING_COMPLETED_CAPTURE',audit_pid=p.pid,command=cmd);save(d)
    try:code=p.wait(timeout=1800)
    except subprocess.TimeoutExpired:p.kill();p.wait();code=124
   d.update(state='FINAL_ACTUAL_PREVIEW_AUDIT_PASS'if code==0 else'FINAL_AUDIT_FAILED',exit_code=code,audit_wall_seconds=time.time()-t,log_sha256=sha(RUN/'final_audit_observer.log'),finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat());save(d);return code
  if e['state']!='RUNNING':d.update(state='CAPTURE_DID_NOT_PASS_NO_AUDIT',finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat());save(d);return 2
  time.sleep(60)
 d.update(state='OBSERVER_TIMEOUT_CAPTURE_UNCHANGED');save(d);return 124
if __name__=='__main__':raise SystemExit(main())
