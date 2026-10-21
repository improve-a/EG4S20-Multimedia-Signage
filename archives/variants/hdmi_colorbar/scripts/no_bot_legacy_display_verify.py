#!/usr/bin/env python3
"""Capture final RGB from actual legacy sequential video chain after RTL BMP load.
Requires actual loader pixel_valid dump and verifies it independently first.
The loader and loaded-memory scanout are separate simulations, joined by hashed
RTL payload. Ordered10cycle SDRAM stimulus excludes encryptedSDRAM/PHY/HW proof.
"""
import argparse,datetime,hashlib,importlib.util,json,os,shutil,struct,subprocess,sys,time,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj):
 t=p.with_suffix('.tmp');t.write_bytes((json.dumps(obj,indent=2)+'\n').encode());os.replace(t,p)
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
SOURCES=['tests/no_bot_legacy_scanout_tb.v','rtl/SD/frame_read_write.v','rtl/SD/frame_fifo_read.v','rtl/SD/frame_fifo_write.v','rtl/IP/afifo_32_16_256.v','rtl/IP/afifo_16_32_256.v','rtl/SD/video_delay.v','rtl/SD/video_timing_data.v','rtl/SD/color_bar.v','rtl/display_commit.v','rtl/ext/video_transition.v','rtl/ext/html_video_overlay.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/pixel_adjust.v','rtl/ext/html_assets/html_caption_map.v']
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--loader-dump',type=Path,required=True);ap.add_argument('--animate',action='store_true');ap.add_argument('--second-loader-dump',type=Path);ap.add_argument('--next-page',type=int,choices=range(6),default=1);ap.add_argument('--next-dual',action='store_true');ap.add_argument('--next-zoom',type=int,choices=range(3),default=0);ap.add_argument('--next-focus',type=int,choices=range(6),default=0);ap.add_argument('--static-caption',action='store_true');ap.add_argument('--page',type=int,choices=range(6),required=True);ap.add_argument('--dual',action='store_true');ap.add_argument('--zoom',type=int,choices=range(3),default=0);ap.add_argument('--focus',type=int,choices=range(6),default=0);ap.add_argument('--frames',type=int,default=8);ap.add_argument('--timeout',type=int,default=3600);ap.add_argument('--compile-only',action='store_true');a=ap.parse_args()
 if not 1<=a.frames<=100:ap.error('frames1..100')
 if a.animate and (not a.second_loader_dump or a.static_caption):ap.error('animation requires second actual loader dump and natural caption state')
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/no_bot/verify'/('legacy_display_'+stamp);out.mkdir(parents=True,exist_ok=False)
 oracle=module('legacy_oracle',ROOT/'scripts/no_bot_legacy_oracle.py');rgb,metadata=oracle.expected_rgb(a.page,a.dual,a.zoom,a.focus);checked=oracle.verify_loader_dump(a.loader_dump,rgb)
 # Actual loader output mapped by oldwriter WRITE_V_FLIP, not software-renderedRGB.
 words=[int(v,16) for v in a.loader_dump.read_text().split()];topdown=[words[(479-y)*640+x] for y in range(480) for x in range(640)]
 (out/'memory.hex').write_bytes(''.join(f'{v:08x}\n' for v in [v<<8 for v in topdown]+([0xdeadbeef]*307200 if a.animate else [v<<8 for v in topdown])).encode())
 second=None
 if a.animate:
  expected2,meta2=oracle.expected_rgb(a.next_page,a.next_dual,a.next_zoom,a.next_focus);second=oracle.verify_loader_dump(a.second_loader_dump,expected2);second['independent_expected']=meta2
  (out/'second_loader_payload.hex').write_bytes(a.second_loader_dump.read_bytes())
 wav=ROOT/'output/html_fidelity/no_bot/media/07_MUSIC.WAV'
 with wave.open(str(wav),'rb')as w:
  channels=w.getnchannels();rate=w.getframerate();assert w.getsampwidth()==2;raw=w.readframes((257*rate*21)//1250)
 samples=struct.unpack('<'+str(len(raw)//2)+'h',raw);peaks=[]
 for frame in range(256):
  lo=(frame*rate*21)//1250;hi=((frame+1)*rate*21)//1250;peaks.append(min(32768,max(abs(v)for v in samples[lo*channels:hi*channels])))
 (out/'real_wav_peaks.hex').write_bytes(''.join(f'{v:04x}\n'for v in peaks).encode())
 files=SOURCES+['rtl/SD/video_define.v','scripts/no_bot_legacy_display_verify.py','scripts/no_bot_legacy_oracle.py']+[p.relative_to(ROOT).as_posix() for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for n in files:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','scope':__doc__,'pid':os.getpid(),'started_epoch':time.time(),'snapshot':str(out),'loader_payload':checked,'second_loader_payload':second,'static_caption_fixture':a.static_caption,'source_state_driver':'Actualproduction video_transition/display_commit; source cover/load/commit event driver modeled. Actual legacy_exhibit_media controller protocol tested separately.','full_transition':a.animate,'model_load_wait_ms':750 if a.animate else None,'actual_SPI_lower_bound_ms':'at least791.21ms transportfor2161sectors+loaderwork+arbitration+realTFwait; 750msclipwaitisexplicitacceleratedmodel,notmeasurement','producer_pressure':'realRTLloaderpayload at1word/16sysclocks(~49ms), then explicitidlecoveredwaituntil750ms; sourcecontrollerdriver modeled','independent_expected':metadata,'input_memory_sha256':sha(out/'memory.hex'),'audio_stimulus':{'wav':str(wav),'sha256':sha(wav),'peak_fixture_sha256':sha(out/'real_wav_peaks.hex'),'scope':'Actual WAV decoded offline to256native16.8ms absolute PCM peaks; actual OSD history/bar RTL executes. Audio parser/player/SD arbiter/HDMI PCM path tested separately, not instantiated here.'},'source_sha256':{n:sha(out/n) for n in files},'tools':{},'steps':[],'FULL_SYSTEM_SIM':'NOT_RUN','HARDWARE':'HARDWARE_NOT_TESTED','read_fifo':'Actualgenerated rfifo_32_32_512 RAM+GrayCDC,511usablewords','memory_model':('Ordered10memorycycle response; actualwriter source actualRTLloaderdump at worstlegal1word/16sysclocks, actualgeneratedwriteFIFO+oldflipwriter, synthetic20cycle refreshes betweenbursts; no physicalSDRAMqualification' if a.animate else 'Ordered10memorycycle response on eachactuallyacceptedsequentialread; writeridle; no physicalSDRAMqualification'),'production_clocks':'memory40MHz,video25MHz,800x525,640x480active,16.8ms/frame'}
 for tool in ['iverilog','vvp']:
  p=Path(r'C:\iverilog\bin')/(tool+'.exe');q=subprocess.run([str(p),'-V'],capture_output=True);report['tools'][tool]={'path':str(p),'sha256':sha(p),'identity':(q.stdout+q.stderr).decode(errors='replace')}
 def state():save(out/'verification.json',report)
 state()
 params={'FRAMES':a.frames,'PAGE':a.page,'ZOOM':a.zoom,'DUAL':int(a.dual),'FOCUS':a.focus,'ANIMATE':int(a.animate),'NEXT_PAGE':a.next_page,'NEXT_ZOOM':a.next_zoom,'NEXT_DUAL':int(a.next_dual),'NEXT_FOCUS':a.next_focus,'STATIC_CAPTION':int(a.static_caption),'FIXTURE_ROOT':'"'+out.as_posix()+'"'}
 cmd=[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-Irtl/SD','-s','no_bot_legacy_scanout_tb','-o','sim.vvp']+[f'-Pno_bot_legacy_scanout_tb.{k}={v}' for k,v in params.items()]+SOURCES
 for step,cmd in [('compile',cmd),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  if a.compile_only and step=='simulation':break
  log=out/(step+'.log');tick=time.time()
  with log.open('wb') as f:
   p=subprocess.Popen(cmd,cwd=out,stdin=subprocess.DEVNULL,stdout=f,stderr=subprocess.STDOUT);item={'step':step,'pid':p.pid,'command':cmd,'state':'RUNNING'};report['steps'].append(item);state()
   try:code=p.wait(timeout=120 if step=='compile' else a.timeout)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  item.update(exit_code=code,wall_seconds=time.time()-tick,state='PASS' if code==0 else 'FAIL',log_sha256=sha(log));state()
  if code:report.update(state='FAIL',wall_seconds=time.time()-report['started_epoch']);state();print(log.read_text(errors='replace'));print(out);return 1
 if a.compile_only:report.update(state='COMPILE_PASS');state();print(out);return 0
 log=(out/'simulation.log').read_text();assert 'TEST_PASS LEGACY_SEQUENTIAL' in log
 import re
 stamps=[tuple(map(int,m)) for m in re.findall(r'^FRAME_PASS (\d+) pixels307200 first(\d+) last(\d+) reads(\d+) responses(\d+)',log,re.M)]
 assert (len(stamps)==a.frames if not a.animate else len(stamps)>=46) and [x[0] for x in stamps]==list(range(len(stamps)))
 assert all(stamps[i][1]-stamps[i-1][1]==16_800_000_000 for i in range(1,len(stamps)))
 pixels=module('display_pixels',ROOT/'scripts/html_display_chain_verify.py');frames=[];evidence=[]
 for i,first,last,reads,responses in stamps:
  p=out/f'frame_{i:02d}.ppm';b=pixels.ppm_read(p);pixels.png_write(p.with_suffix('.png'),640,480,b);frames.append(b);evidence.append({'frame':p.name,'sha256':sha(p),'source':'Actual final wrapper outRGB fwrite,307200pixels','first_pixel_time_ps':first,'last_pixel_time_ps':last,'accepted_reads':reads,'returned_reads':responses})
 if len(frames)>1:report['apng']=pixels.write_apng(out/'actual_rtl_samples.apng',frames,[16_800_000_000]*len(frames),{'scope':__doc__,'frames':evidence})
 report.update(state='LEGACY_DISPLAY_SEGMENT_PASS',frames=evidence,transition_state_trace=re.findall(r'^TRANSITION_STATE .*',log,re.M),wall_seconds=time.time()-report['started_epoch']);state();print(log);print(out);return 0
if __name__=='__main__':raise SystemExit(main())
