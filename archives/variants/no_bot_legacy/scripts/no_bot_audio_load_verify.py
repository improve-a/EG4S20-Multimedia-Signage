#!/usr/bin/env python3
"""First 4096 original delivery WAV samples with continuous modeled BMP traffic.
Production audio_media, arbiter, FIFO, parser and player at 100/25 MHz. No EOF,
full 80-second track, SD PHY/card, encrypted HDMI or listening claim. The fixture
relocates the original first 33 WAV sectors byte-for-byte to LBA 2 for a bounded scan.
"""
import argparse,hashlib,json,os,shutil,struct,subprocess,time,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FINAL='6ee7c70bbf36c33f90a687f010c876de48f03ba6'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--source-commit',default=FINAL,help='frozen production commit to match source bytes');args=ap.parse_args()
 expected_commit=args.source_commit
 out=ROOT/'output/html_fidelity/no_bot/verify'/('audio_load_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 wav=ROOT/'output/html_fidelity/no_bot/media/07_MUSIC.WAV'
 with wave.open(str(wav),'rb') as w:
  params=w.getparams();assert(params.nchannels,params.sampwidth,params.framerate)==(1,2,48000);pcm=w.readframes(4096)
 assert len(pcm)==8192
 raw=wav.read_bytes();prefix=raw[:33*512];assert len(prefix)==33*512
 # The real 80-second header/data sizes remain unchanged, so excerpt termination
 # is the testbench's4096th accepted sample, never a fabricated EOF.
 card=bytes(1024)+prefix;assert card[1024:]==prefix
 (out/'delivery_card.hex').write_bytes(''.join(f'{x:02x}\n' for x in card).encode())
 values=struct.unpack('<4096h',pcm)
 (out/'delivery_pcm.hex').write_bytes(''.join(f'{x&65535:04x}{x&65535:04x}\n' for x in values).encode())
 sources=['tests/no_bot_audio_load_tb.v','rtl/ext/audio_media.v','rtl/ext/audio_pcm_player.v','rtl/ext/audio_async_fifo.v','rtl/ext/wav_stream_parser.v','rtl/ext/media_sector_arbiter.v']
 for n in sources:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 (out/'scripts').mkdir(parents=True,exist_ok=True)
 shutil.copy2(Path(__file__),out/'scripts/no_bot_audio_load_verify.py')
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 for n in sources[1:]:
  original=subprocess.check_output(['git','show',expected_commit+':'+n],cwd=ROOT)
  assert hashlib.sha256(original).hexdigest()==sha(out/n),('production differs from final',n)
 iv=Path(r'C:\iverilog\bin\iverilog.exe');vv=Path(r'C:\iverilog\bin\vvp.exe')
 report={'state':'RUNNING','pid':os.getpid(),'started_epoch':time.time(),'scope':__doc__,'source_commit':expected_commit,'checkout_head':head,
 'clocks_hz':{'sys':100000000,'audio':25000000},'transport_model':{'byte_clocks':70,'command_token_clocks':634,'crc_clocks':140,'sector_clocks':36614,'measured_existing_ideal_sector_clocks':36613,'real_card_waits':'NOT_MODELED'},
 'delivery_wav':{'path':str(wav),'sha256':sha(wav),'params':list(params),'tested_first_frames':4096,'original_header_preserved':True,'prefix_sectors':33,'prefix_sha256':hashlib.sha256(prefix).hexdigest(),'fixture_lba':2,'leading_zero_samples':next(i for i,v in enumerate(values) if v),'nonzero_samples':sum(v!=0 for v in values),'sample_min':min(values),'sample_max':max(values)},
 'sources':{n:sha(out/n) for n in sources},'runner_sha256':sha(out/'scripts/no_bot_audio_load_verify.py'),'fixtures':{n:sha(out/n) for n in ['delivery_card.hex','delivery_pcm.hex']},'tools':{str(p):sha(p) for p in [iv,vv]},'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save();print('OUTPUT',out,flush=True)
 for step,cmd in [('compile',[str(iv),'-g2012','-s','no_bot_audio_load_tb','-o','sim.vvp']+sources),('simulation',[str(vv),'sim.vvp'])]:
  tick=time.time();log=out/(step+'.log')
  with log.open('wb') as f:
   p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'name':step,'pid':p.pid,'command':cmd};report['steps'].append(item);save()
   try:code=p.wait(timeout=420)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save()
  if code:report.update(state='FAIL',wall_seconds=time.time()-report['started_epoch']);save();print(log.read_text(errors='replace'));return 1
 logtext=log.read_text();assert 'TEST_PASS' in logtext
 report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started_epoch'],result=logtext.strip());save();print(logtext);print(out);return 0
if __name__=='__main__':raise SystemExit(main())
