"""Snapshot and run focused production-overlay regressions on native Windows.
Use --columns for the longer original parallel-decoder equivalence comparison.
"""
import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=['rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_assets/html_caption_map.v']
TESTS={
 'no_bot_overlay':BASE+['rtl/ext/pixel_adjust.v','rtl/ext/html_video_overlay.v','tests/no_bot_overlay_tb.v'],
 'zoom_indicator':BASE+['rtl/ext/exhibit_viewport.v','tests/html_zoom_indicator_tb.v'],
 'interval_fraction':BASE+['tests/html_interval_fraction_tb.v'],
 'commit_overlay':BASE+['rtl/SD/color_bar.v','rtl/SD/video_timing_data.v','rtl/display_commit.v','rtl/ext/pixel_adjust.v','rtl/ext/html_video_overlay.v','tests/html_commit_overlay_tb.v'],
}
if '--columns' in sys.argv:TESTS['osd_columns']=BASE+['tests/models/html_osd_reference.v','tests/html_osd_columns_tb.v']

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/overlay_target'/('run_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 files=sorted(set(sum(TESTS.values(),[])+['rtl/SD/video_define.v']+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]))
 for name in files:
  dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 tools={'iverilog':Path(r'C:\iverilog\bin\iverilog.exe'),'vvp':Path(r'C:\iverilog\bin\vvp.exe')}
 report={'state':'RUNNING','scope':'Focused real RTL unit regressions; boundedACKmodel only for commit test; no HW/fullsystem claim','snapshot':str(out),'started':time.time(),'pid':__import__('os').getpid(),'sources':{n:sha(ROOT/n) for n in files},'tools':{n:{'path':str(p),'sha256':sha(p)} for n,p in tools.items()},'steps':[]}
 def save():
  data=json.dumps(report,indent=2).encode();(out/'verification.json').write_bytes(data);(out.parent/'verification.json').write_bytes(data)
 save()
 for test,sources in TESTS.items():
  commands=[('compile',[str(tools['iverilog']),'-g2012','-DHTML_SIM','-Irtl/SD','-s',('no_bot_overlay_tb' if test=='no_bot_overlay' else 'html_'+test+'_tb'),'-o',test+'.vvp']+sources),('simulation',[str(tools['vvp']),test+'.vvp'])]
  for name,cmd in commands:
   log=out/(test+'_'+name+'.log');start=time.time()
   with log.open('w') as output:
    child=subprocess.Popen(cmd,cwd=out,stdout=output,stderr=subprocess.STDOUT)
    step={'test':test,'name':name,'command':cmd,'pid':child.pid,'started':start};report['steps'].append(step);save()
    try:code=child.wait(timeout=600)
    except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
   step.update(exit_code=code,wall_seconds=time.time()-start,log_sha256=sha(log));save()
   if code:
    report.update(state='FAIL',wall_seconds=time.time()-report['started']);save();print(log.read_text());return code
  text=log.read_text()
  if 'TEST_PASS' not in text:raise ValueError('missing pass marker '+test)
  print(text.strip(),flush=True)
 report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started']);save();print(json.dumps({k:v for k,v in report.items() if k not in ['sources','steps','tools']},indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
