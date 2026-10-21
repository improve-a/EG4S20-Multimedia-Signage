#!/usr/bin/env python3
"""Full delivery WAV through actual wav_stream_parser RTL, sample-by-sample and EOF.
Accelerated parser byte interface; no SD PHY/FIFO/player cadence/HDMI/hardware claim.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
import wave
ROOT=Path(__file__).resolve().parents[1]
IVERILOG=Path(r'C:\iverilog\bin\iverilog.exe')
VVP=Path(r'C:\iverilog\bin\vvp.exe')
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as stream:
  for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def samples(path,first=True,count=16):
 with path.open('rb') as stream:
  if not first:stream.seek(max(0,path.stat().st_size-count*4))
  data=stream.read(count*4)
 return [list(pair) for pair in struct.iter_unpack('<hh',data)]
def main():
 stamp=time.strftime('%Y%m%d_%H%M%S');out=ROOT/'output/html_fidelity/no_bot/verify'/('wav_full_'+stamp);out.mkdir(parents=True,exist_ok=False)
 started=time.time();wav=ROOT/'output/html_fidelity/no_bot/media/07_MUSIC.WAV';manifest=json.loads(wav.with_name('manifest.json').read_text(encoding='utf-8'))
 expected_record=next(row for row in manifest['assets'] if row['name']=='07_MUSIC.WAV')
 assert sha(wav)==expected_record['sha256']
 shutil.copy2(wav,out/'delivery.wav')
 with wave.open(str(wav),'rb') as stream:
  params=stream.getparams();assert (params.nchannels,params.sampwidth,params.framerate,params.comptype)==(1,2,48000,'NONE')
  with (out/'expected_pcm.bin').open('wb') as expected:
   for block in iter(lambda:stream.readframes(65536),b''):expected.write(block)
 data=wav.read_bytes();pos=12;data_offset=None;data_length=None
 while pos+8<=len(data):
  kind,size=struct.unpack_from('<4sI',data,pos)
  if kind==b'data':data_offset=pos+8;data_length=size;break
  pos+=8+size+(size&1)
 assert data_offset is not None and data_length==params.nframes*2 and len(data)==data_offset+data_length
 assert (out/'expected_pcm.bin').read_bytes()==data[data_offset:data_offset+data_length]
 sources=['tests/no_bot_wav_full_tb.v','rtl/ext/wav_stream_parser.v']
 for name in sources:
  target=out/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 report=dict(state='RUNNING',pid=os.getpid(),started_epoch=started,scope=__doc__,
             wav=dict(path=str(wav),sha256=sha(wav),bytes=len(data),channels=params.nchannels,sample_bytes=params.sampwidth,
                      sample_rate_hz=params.framerate,samples=params.nframes,duration_seconds=params.nframes/params.framerate,
                      data_offset=data_offset,data_bytes=data_length),
             sources={name:sha(out/name) for name in sources},
             tools={str(tool):dict(sha256=sha(tool)) for tool in [IVERILOG,VVP]},steps=[])
 def save():(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 save()
 for name,tool in [('iverilog',IVERILOG),('vvp',VVP)]:
  version=subprocess.run([str(tool),'-V'],capture_output=True,text=True,timeout=15)
  (out/(name+'_version.log')).write_text(version.stdout+version.stderr,encoding='utf-8')
  report['tools'][str(tool)].update(version_log=name+'_version.log',version_exit=version.returncode)
 for step,cmd in [('compile',[str(IVERILOG),'-g2012','-s','no_bot_wav_full_tb','-o','sim.vvp']+sources),
                  ('simulation',[str(VVP),'sim.vvp',f'+SAMPLES={params.nframes}',f'+FILE_BYTES={len(data)}',f'+DATA_OFFSET={data_offset}',f'+DATA_BYTES={data_length}'])]:
  tick=time.monotonic();log=out/(step+'.log')
  with log.open('wb') as stream:
   process=subprocess.Popen(cmd,cwd=out,stdout=stream,stderr=subprocess.STDOUT)
   record=dict(name=step,pid=process.pid,command=cmd);report['steps'].append(record);save()
   try:code=process.wait(timeout=300)
   except subprocess.TimeoutExpired:process.kill();process.wait();code=124
  record.update(exit_code=code,wall_seconds=round(time.monotonic()-tick,3),log_sha256=sha(log));save()
  if code:
   report.update(state='FAIL',wall_seconds=time.time()-started);save();print(log.read_text(errors='replace'));print(out);return 1
 log_text=(out/'simulation.log').read_text()
 assert 'TEST_PASS full production WAV parser' in log_text
 actual=out/'parser_pcm_lr.bin';assert actual.stat().st_size==params.nframes*4
 expected_hash=hashlib.sha256();actual_hash=hashlib.sha256();left_hash=hashlib.sha256();right_hash=hashlib.sha256();compared=0
 with (out/'expected_pcm.bin').open('rb') as expected,actual.open('rb') as observed:
  while True:
   pcm=expected.read(131072)
   if not pcm:break
   original_words=struct.unpack('<'+'H'*(len(pcm)//2),pcm)
   expected_lr=b''.join(struct.pack('<HH',word,word) for word in original_words)
   seen=observed.read(len(expected_lr));assert seen==expected_lr
   expected_hash.update(expected_lr);actual_hash.update(seen)
   left_hash.update(b''.join(pair[0:2] for pair in [seen[i:i+4] for i in range(0,len(seen),4)]))
   right_hash.update(b''.join(pair[2:4] for pair in [seen[i:i+4] for i in range(0,len(seen),4)]))
   compared+=len(pcm)//2
  assert not observed.read(1)
 assert compared==params.nframes and expected_hash.hexdigest()==actual_hash.hexdigest()
 assert left_hash.hexdigest()==right_hash.hexdigest()==sha(out/'expected_pcm.bin')
 report.update(state='UNIT_SIM_PASS',wall_seconds=round(time.time()-started,3),
               verification=dict(full_samples_compared=compared,rtl_output_path=str(actual),rtl_output_bytes=actual.stat().st_size,
                                 expected_lr_sha256=expected_hash.hexdigest(),actual_lr_sha256=actual_hash.hexdigest(),
                                 mono_pcm_sha256=sha(out/'expected_pcm.bin'),actual_left_sha256=left_hash.hexdigest(),actual_right_sha256=right_hash.hexdigest(),
                                 first16_actual_lr=samples(actual),last16_actual_lr=samples(actual,False),
                                 full_eof=True,post_eof_padding_ignored=64),
               limits=['Actual production parser with unmodified defaults; every original WAV byte including header and complete PCM fed.',
                       'Byte-stream simulation accelerated to one inputbyte per100MHz clock; not80seconds real-time playback.',
                       'Does not cover SD sectorPHY, audio_media/player FIFO/cadence, arbitration during video, HDMI packets or listening.'])
 save();print(log_text);print(json.dumps(dict(state=report['state'],out=str(out),samples=compared,actual_lr_sha256=actual_hash.hexdigest(),wall_seconds=report['wall_seconds'])))
 return 0
if __name__=='__main__':raise SystemExit(main())
