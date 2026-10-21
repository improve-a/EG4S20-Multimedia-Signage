#!/usr/bin/env python3
"""Read-only simulation observer; persists actual frame wall intervals/ETA.
Never changes or kills the simulation, source, pixel output, or clock schedule.
"""
import argparse,base64,ctypes,datetime,hashlib,json,os,re,statistics,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def save(p,obj):
 q=p.with_suffix('.tmp');q.write_bytes((json.dumps(obj,indent=2)+'\n').encode());os.replace(q,p)
def alive(pid):
 k=ctypes.WinDLL('kernel32',use_last_error=True);k.OpenProcess.restype=ctypes.c_void_p;k.OpenProcess.argtypes=[ctypes.c_ulong,ctypes.c_bool,ctypes.c_ulong];k.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong)];k.CloseHandle.argtypes=[ctypes.c_void_p]
 h=k.OpenProcess(0x1000,False,pid)
 if not h:return None if ctypes.get_last_error()==5 else False
 c=ctypes.c_ulong();ok=k.GetExitCodeProcess(h,ctypes.byref(c));k.CloseHandle(h);return c.value==259 if ok else None

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run-root',type=Path,required=True);ap.add_argument('--expected-frames',type=int,default=96);ap.add_argument('--deadline-utc',default='2026-10-19T01:46:00+00:00');ap.add_argument('--launch',action='store_true');a=ap.parse_args();out=a.run_root
 if a.launch:
  cmd=[sys.executable,'-X','utf8',str(Path(__file__).resolve())]+[x for x in sys.argv[1:]if x!='--launch'];ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+subprocess.list2cmdline(cmd).replace("'","''")+"';CurrentDirectory='"+str(ROOT)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
  p=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True);(out/'observer_dispatch.log').write_bytes(p.stdout+p.stderr);print(p.stdout.decode(errors='replace'));return p.returncode
 deadline=datetime.datetime.fromisoformat(a.deadline_utc).timestamp();history=[];known=set();last_write=0
 while True:
  try:job=json.loads((out/'verification.json').read_text())
  except (OSError,ValueError):time.sleep(5);continue
  text=(out/'simulation.log').read_text(errors='replace')if(out/'simulation.log').exists()else''
  matched=[tuple(map(int,v))for v in re.findall(r'^FRAME_PASS (\d+) pixels307200 first(\d+) last(\d+) reads(\d+) responses(\d+)',text,re.M)]
  for n,first,last,reads,responses in matched:
   if n in known:continue
   p=out/f'frame_{n:02d}.ppm';end=p.stat().st_mtime
   item={'frame':n,'complete_wall_epoch':end,'complete_wall_utc':datetime.datetime.fromtimestamp(end,datetime.timezone.utc).isoformat(),'first_pixel_time_ps':first,'last_pixel_time_ps':last,'pixels':307200,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'accepted_reads':reads,'returned_reads':responses,'seconds_since_previous_frame':end-history[-1]['complete_wall_epoch']if history else None}
   history.append(item);known.add(n)
  count=len(history);now=time.time();intervals=[v['seconds_since_previous_frame']for v in history[-6:]if v['seconds_since_previous_frame']is not None];period=statistics.median(intervals)if intervals else (history[0]['complete_wall_epoch']-job['started_epoch'])/2 if history else None
  remaining=max(0,a.expected_frames-count);eta=now+remaining*period if period else None;child=job.get('steps',[{}])[-1];running=alive(child['pid'])if child.get('pid')else None
  result={'observer_pid':os.getpid(),'observed_epoch':now,'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'job_state':job['state'],'simulation_pid':child.get('pid'),'simulation_alive':running,'complete_frames':count,'expected_frames_ESTIMATE':a.expected_frames,'frames_estimate_note':'Requested conservative modelphase estimate, exactcompletion depends nativeframealignment; never a PASScriterion.','frame_wall_seconds_median_last5':period,'eta_provisional_until_two_frames':not intervals,'eta_utc_ESTIMATE':datetime.datetime.fromtimestamp(eta,datetime.timezone.utc).isoformat()if eta else None,'deadline_utc':a.deadline_utc,'eta_exceeds_deadline':eta>deadline if eta else None,'native16_8ms_spacing':all(history[i]['first_pixel_time_ps']-history[i-1]['first_pixel_time_ps']==16_800_000_000 for i in range(1,count))if count>=2 else 'INSUFFICIENT_FRAMES','frames':history,'model_load_wait_ms':job.get('model_load_wait_ms'),'scope':'Actual fullframe milestones only; ETAisheuristic. No synthetic/copied frames.','last_transition_state':re.findall(r'^TRANSITION_STATE .*',text,re.M)[-1:]}
  if now-last_write>=60 or count>len(json.loads((out/'runtime_eta.json').read_text()).get('frames',[]))if(out/'runtime_eta.json').exists()else True:save(out/'runtime_eta.json',result);last_write=now
  if job['state']not in ['RUNNING','COMPILE_PASS']or running is False:
   result['observer_finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save(out/'runtime_eta.json',result);return 0
  time.sleep(10)
if __name__=='__main__':raise SystemExit(main())
