#!/usr/bin/env python3
"""Actual audio_pcm_player 64sample wave_peak to final noBot overlay crop.
Real25MHz/48kHz cadence; synthetic short VS at each peak window, not full VGA.
Formal delivery mono PCM excerpt; no gain changes, software bars or RGB forcing.
"""
import array,datetime,hashlib,importlib.util,json,os,re,shutil,subprocess,time,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('player_osd_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 wav=ROOT/'output/html_fidelity/no_bot/media/07_MUSIC.WAV'
 with wave.open(str(wav),'rb')as w:
  assert(w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,48000);a=array.array('h',w.readframes(w.getnframes()))
 peakindex=max(range(len(a)),key=lambda i:abs(a[i]));start=max(0,min(peakindex-256,len(a)-4096));samples=a[start:start+4096];(out/'formal_pcm.hex').write_bytes(''.join(f'{x&65535:04x}\n'for x in samples).encode())
 spec=importlib.util.spec_from_file_location('oracle',ROOT/'scripts/no_bot_legacy_oracle.py');oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle);w,h,b=oracle.read_bmp(ROOT/'output/html_fidelity/no_bot/media/UI01.BMP');(out/'home_crop.hex').write_bytes(''.join(b[i:i+3].hex()+'\n'for i in range(386*1920,469*1920,3)).encode())
 files=['tests/no_bot_player_osd_tb.v','rtl/ext/audio_pcm_player.v','rtl/ext/html_video_overlay.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/pixel_adjust.v','rtl/ext/html_assets/html_caption_map.v']+[p.relative_to(ROOT).as_posix()for p in(ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for n in files:p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'snapshot':str(out),'scope':__doc__,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sources':{n:sha(out/n)for n in files},'WAV':{'path':str(wav),'sha256':sha(wav),'sample_offset':start,'seconds_offset':start/48000,'sample_count':4096,'selection':'4096sample excerpt placing formal track absolute maximum at index256','global_abs_max':abs(a[peakindex]),'first9_independent_64sample_max':[max(abs(x)for x in samples[i:i+64])for i in range(0,576,64)]},'fixtures':{n:sha(out/n)for n in ['formal_pcm.hex','home_crop.hex']},'boundaries':['Targeted player to OSD wire segment; FIFO synchronous data model, WAV parser/media/arbiter/HDMI PHY not instantiated','Actual gain8 and actual25MHz/48kHz fractional cadence. Accelerated VS every64sample peak window, not59.52Hz capture','OSD y386 croporigin set; source pixels and output RGB never forced. No whole system playback claim'],'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for name,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','no_bot_player_osd_tb','-o','sim.vvp']+files[:9]),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  log=out/(name+'.log');t=time.time()
  with log.open('wb')as f:
   p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);row={'name':name,'pid':p.pid,'command':cmd};report['steps'].append(row);save()
   try:code=p.wait(timeout=1800)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  row.update(exit_code=code,wall_seconds=time.time()-t,log_sha256=sha(log));save()
  if code:report.update(state='FAIL');save();print(log.read_text());print(out);return 1
 logtext=log.read_text();assert'TEST_PASS'in logtext;history=list(map(int,re.search(r'ACTUAL_HISTORY((?: \d+){9})',logtext)[1].split()));assert history==[min(29,p>>10)for p in reversed(report['WAV']['first9_independent_64sample_max'])]
 data=(out/'actual_player_osd.ppm').read_bytes().split(b'\n',3)[3];assert len(data)==640*83*3;count=0
 for y in range(399,429):
  for x in range(455,500):
   index,col=divmod(x-455,5);height=min(29,history[index]);top=414-height//2;bottom=414+(height+1)//2;expected=col<3 and height>0 and top<=y<bottom and(col==1 or(y>top and y+1<bottom));actual=data[((y-386)*640+x)*3:((y-386)*640+x+1)*3]==bytes.fromhex('1a1916');assert actual==expected,(x,y,height,actual,expected);count+=int(actual)
 assert count>0
 spec=importlib.util.spec_from_file_location('pixels',ROOT/'scripts/html_display_chain_verify.py');pixels=importlib.util.module_from_spec(spec);spec.loader.exec_module(pixels);png=out/'actual_player_osd.png';pixels.png_write(png,640,83,data)
 report.update(state='ACTUAL_PLAYER64_PEAK_TO_FINAL_OSD_SEGMENT_PASS',history=history,bar_ROI_exact_geometry_checked_pixels=1350,nonzero_bar_pixels=count,actual_output_png=str(png),actual_output_png_sha256=sha(png),actual_output_ppm_sha256=sha(out/'actual_player_osd.ppm'),wall_seconds=time.time()-report['started'],live_sources_unchanged=all(sha(ROOT/n)==v for n,v in report['sources'].items()));save();print(logtext);print(out);return 0
if __name__=='__main__':raise SystemExit(main())
