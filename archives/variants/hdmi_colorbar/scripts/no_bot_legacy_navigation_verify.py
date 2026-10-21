#!/usr/bin/env python3
"""Actual final production-wrapper RGB crops for forward/reverse/wrap captions.
Overlay segment only: source plainBMP pixels, short synthetic VS frames, fixed
25MHz pixelclock. Not fullscanout, SDRAM, or a continuous production-time clip.
"""
import hashlib,importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(name,p):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('navigation_overlay_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 oracle=load('oracle',ROOT/'scripts/no_bot_legacy_oracle.py');pixels=load('pixels',ROOT/'scripts/html_display_chain_verify.py');media=ROOT/'output/html_fidelity/no_bot/media';background=[]
 for page in range(6):
  w,h,b=oracle.read_bmp(media/f'UI{page+1:02d}.BMP');background.extend((b[i]<<16)|(b[i+1]<<8)|b[i+2]for i in range(386*1920,469*1920,3))
 (out/'navigation_background.hex').write_bytes(''.join(f'{v:06x}\n'for v in background).encode());peak=ROOT/'output/html_fidelity/no_bot/verify/legacy_display_20261018T165610241836Z/real_wav_peaks.hex';shutil.copy2(peak,out/'real_wav_peaks.hex')
 files=['tests/legacy_navigation_overlay_tb.v','rtl/ext/html_video_overlay.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/pixel_adjust.v','rtl/ext/html_assets/html_caption_map.v']+[p.relative_to(ROOT).as_posix()for p in(ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for n in files:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'snapshot':str(out),'scope':__doc__,'sources':{n:sha(out/n)for n in files},'fixtures':{n:sha(out/n)for n in['navigation_background.hex','real_wav_peaks.hex']},'state_fixtures':'Oldcaption typed_count127 prewarm only before each navigation; newcaption swap/typewriter runs naturally with actual RTL after page_event. y386 croporigin set for bounded region, no RGB forcing. Frame ages are syntheticVS state indices, not video clip timestamps.','steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for step,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','legacy_navigation_overlay_tb','-o','sim.vvp']+files[:8]),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  log=out/(step+'.log');tick=time.time()
  with log.open('wb')as f:
   p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'step':step,'pid':p.pid,'command':cmd};report['steps'].append(item);save()
   try:code=p.wait(timeout=600)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save()
  if code:report.update(state='FAIL');save();print(log.read_text());print(out);return 1
 assert'TEST_PASS'in log.read_text();frames=[]
 for p in sorted(out.glob('*.ppm')):
  a,b,c,rgb=p.read_bytes().split(b'\n',3);assert(a,b,c,len(rgb))==(b'P6',b'640 83',b'255',159360);png=p.with_suffix('.png');pixels.png_write(png,640,83,rgb);frames.append({'actual_rgb_crop':p.name,'sha256':sha(p),'png':png.name,'origin':[0,386],'size':[640,83]})
 assert len(frames)==21;report.update(state='OVERLAY_SEGMENT_PASS',frames=frames,wall_seconds=time.time()-report['started']);save();print(log.read_text());print(out);return 0
if __name__=='__main__':raise SystemExit(main())
