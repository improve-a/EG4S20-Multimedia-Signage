#!/usr/bin/env python3
"""Fresh legacy controller protocol units; explicit scanner/loader/SD stubs.
Real media_controls/arbiter and production controller; not full system/pixels.
"""
import hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('legacy_control_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 files=['tests/legacy_exhibit_media_tb.v','rtl/ext/legacy_exhibit_media.v','rtl/media_controls.v','rtl/ext/media_sector_arbiter.v','scripts/no_bot_legacy_control_verify.py']
 for n in files:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','pid':os.getpid(),'started_epoch':time.time(),'scope':__doc__,'snapshot':str(out),'sources':{n:sha(out/n) for n in files},'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for mode in range(12):
  for stage,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-s','legacy_exhibit_media_tb',f'-Plegacy_exhibit_media_tb.MODE={mode}','-o',f'mode{mode}.vvp']+files[:4]),('simulation',[r'C:\iverilog\bin\vvp.exe',f'mode{mode}.vvp'])]:
   tick=time.time();log=out/f'mode{mode}_{stage}.log'
   with log.open('wb') as f:
    p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'mode':mode,'stage':stage,'command':cmd,'pid':p.pid};report['steps'].append(item);save()
    try:code=p.wait(timeout=60)
    except subprocess.TimeoutExpired:p.kill();p.wait();code=124
   item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save()
   if code:report.update(state='FAIL');save();print(log.read_text());print(out);return 1
  if 'TEST_PASS' not in log.read_text():raise AssertionError('missing completion')
  print(log.read_text(),flush=True)
 report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started_epoch'],live_test_sources_unchanged=all((ROOT/n).exists() and sha(ROOT/n)==h for n,h in report['sources'].items()));save();print(out);return 0
if __name__=='__main__':raise SystemExit(main())
