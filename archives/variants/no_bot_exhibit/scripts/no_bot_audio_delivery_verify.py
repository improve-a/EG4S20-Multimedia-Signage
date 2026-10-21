#!/usr/bin/env python3
"""Actual delivery WAV PCM excerpt through production audio RTL, twice via restart.
Retains source format and first300 samples; 80-second full continuity is NOT_RUN.
Sector byte transport is modeled; no SD PHY, HDMI encapsulation or listening claim.
"""
import hashlib,io,json,os,shutil,struct,subprocess,sys,time,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('delivery_audio_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 wav=ROOT/'output/html_fidelity/media/07_MUSIC.WAV'
 with wave.open(str(wav),'rb') as w:
  params=w.getparams();assert(params.nchannels,params.sampwidth,params.framerate)==(1,2,48000);pcm=w.readframes(300)
 b=io.BytesIO()
 with wave.open(b,'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000);w.writeframes(pcm)
 card=bytearray(3072);card[1024:1024+len(b.getvalue())]=b.getvalue()
 (out/'delivery_card.hex').write_bytes(''.join(f'{x:02x}\n' for x in card).encode())
 (out/'delivery_pcm.hex').write_bytes(''.join(f'{x:04x}{x:04x}\n' for x in struct.unpack('<300H',pcm)).encode())
 sources=['tests/no_bot_audio_delivery_tb.v','rtl/ext/audio_media.v','rtl/ext/audio_pcm_player.v','rtl/ext/audio_async_fifo.v','rtl/ext/wav_stream_parser.v']
 for n in sources:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','pid':os.getpid(),'started_epoch':time.time(),'scope':__doc__,'delivery_wav':{'path':str(wav),'sha256':sha(wav),'params':list(params),'tested_first_frames':300,'restart_loops':2},'sources':{n:sha(out/n) for n in sources},'fixtures':{n:sha(out/n) for n in ['delivery_card.hex','delivery_pcm.hex']},'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for step,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-s','no_bot_audio_delivery_tb','-o','sim.vvp']+sources),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  tick=time.time();log=out/(step+'.log')
  with log.open('wb') as f:
   p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'name':step,'pid':p.pid,'command':cmd};report['steps'].append(item);save()
   try:code=p.wait(timeout=300)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save()
  if code:report.update(state='FAIL');save();print(log.read_text(errors='replace'));return 1
 assert 'TEST_PASS' in log.read_text()
 report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started_epoch']);save();print(log.read_text());print(out);return 0
if __name__=='__main__':raise SystemExit(main())
