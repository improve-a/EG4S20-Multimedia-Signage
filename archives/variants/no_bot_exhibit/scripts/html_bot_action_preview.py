"""Actual overlay-RTL time-sampled action preview; never a softwareDUT renderer."""
import argparse,datetime,hashlib,importlib.util,json,os,re,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/ext/html_eye_radius_rom.v','rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/html_bot_overlay.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_assets/html_caption_map.v','tests/html_bot_action_samples_tb.v']
AGES=[0,5,25,65,92,100]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--production-commit',required=True);a=ap.parse_args()
 run=ROOT/'output/html_fidelity/bot_action_samples'/('run_'+time.strftime('%Y%m%d_%H%M%S'));run.mkdir(parents=True)
 dependencies=SOURCES+['scripts/html_bot_action_preview.py','scripts/html_display_chain_verify.py']+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for name in dependencies:
  target=run/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 (run/'output/html_fidelity/bot_osd').mkdir(parents=True)
 report={'state':'RUNNING','production_rtl_commit':a.production_commit,'harness':'Newownedtestharness beyondproductioncommit; exactsourceSHAs retained','snapshot':str(run),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':os.getpid(),'sources':{n:sha(run/n) for n in dependencies},'scope':'Six actualRTL full640x480 RGB captures on syntheticdarktestbackdrop. VS controller frames accelerated between samples. Nominal59.5238Hz frameindices, notcontinuousvideo and notwholememory/displaychain. No redraw/interpolation/palettequantization.','audio':'Fixedpeak24576/status2 teststimulus; nointegratedaudio claim','pipeline_cycles':10,'steps':[]}
 def save():(run/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
 save();print('SNAPSHOT '+str(run),flush=True)
 for name,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','html_bot_action_samples_tb','-o','sim.vvp']+SOURCES),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  started=time.time()
  with (run/(name+'.log')).open('wb') as log:
   child=subprocess.Popen(cmd,cwd=run,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'pid':child.pid,'command':cmd};report['steps'].append(step);save()
   try:code=child.wait(timeout=1800)
   except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
  step.update(exit_code=code,wall_seconds=time.time()-started);save()
  if code:report['state']='FAIL';save();print((run/(name+'.log')).read_text());return code
 text=(run/'simulation.log').read_text();found=[int(v) for v in re.findall(r'ACTION_SAMPLE_PASS age(\d+)',text)]
 if found!=AGES or 'ACTION_SAMPLES_SIM_PASS6' not in text:raise ValueError('missing exactactualDUT age samples')
 spec=importlib.util.spec_from_file_location('pixels',run/'scripts/html_display_chain_verify.py');pixels=importlib.util.module_from_spec(spec);spec.loader.exec_module(pixels)
 frames=run/'frames';frames.mkdir();rgb=[];sources=[]
 for age in AGES:
  source=run/'output/html_fidelity/bot_osd'/f'action_age{age:03d}.ppm';target=frames/source.name;shutil.copy2(source,target);data=pixels.ppm_read(target);rgb.append(data);pixels.png_write(target.with_suffix('.png'),640,480,data);sources.append({'frame':str(target.relative_to(run)),'sha256':sha(target),'controller_age_frames':age,'nominal_time_ms':age*16.8})
 durations=[(b-a)*16_800_000_000 for a,b in zip(AGES,AGES[1:])]+[16_800_000_000]
 metadata={'scope':report['scope'],'sample_times_ms':[age*16.8 for age in AGES],'display_semantics':'Hold eachactualsample untilnextsampletime; loopresets after1696.8ms. Sparse6keyframes, notcontinuousmotion.','sources':sources,'production_rtl_commit':a.production_commit}
 report['frames']=sources;report['apng']=pixels.write_apng(frames/'late_action_samples.apng',rgb,durations,metadata);report['preview_metadata']=metadata;report['state']='OVERLAY_ACTION_SAMPLES_SIM_PASS';save();print(json.dumps(report,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
