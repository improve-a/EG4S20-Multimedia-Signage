#!/usr/bin/env python3
"""Isolated real HFXL/PCM shared transport simulation; no formal media mutation."""
import argparse,datetime,hashlib,json,os,shutil,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def hexbytes(p,b):p.write_text(''.join('%02x\n'%v for v in b),encoding='ascii')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--focused-page0',action='store_true',help='verify only page 0 through real SD/arbiter/loader transport');args=ap.parse_args()
 out=ROOT/'output/html_fidelity/scene_verification'/datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out.mkdir(parents=True)
 names=['rtl/ext/html_scene_loader.v','rtl/ext/html_resource_locator.v','rtl/ext/media_sector_arbiter.v','rtl/ext/audio_media.v','rtl/ext/audio_async_fifo.v','rtl/ext/audio_pcm_player.v','rtl/ext/wav_stream_parser.v','tests/html_scene_real_tb.v','scripts/html_fidelity_verify_scenes.py']
 manifest=json.loads((ROOT/'output/html_fidelity/layers/hfxl_payload_manifest.json').read_text(encoding='utf8'));expected_id=manifest['set_id']
 result={'pid':os.getpid(),'scope':'UNIT_SIM_ONLY focused real page-0 transport' if args.focused_page0 else 'UNIT_SIM_ONLY all-six real scene transport and actual PCM client','source_sha256':{},'fixtures':[],'expected_set_id':expected_id,'payload_manifest_sha256':sha(ROOT/'output/html_fidelity/layers/hfxl_payload_manifest.json')}
 for n in names:
  d=out/n;d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/n,d);result['source_sha256'][n]=sha(d)
 headers=bytearray();payload=bytearray();bases=[];lens=[];offsets=[]
 for i in range(6):
  f=ROOT/f'output/html_fidelity/layers/experimental_media/UI{i+1:02d}.BMP';b=f.read_bytes();loc=struct.unpack_from('<4sHHIIIHHII',b,80);assert loc[:3]==(b'HFXL',1,32)
  off,size,base,page,count,setid=loc[3:9];assert page==i and count==6 and setid==expected_id and base*4==len(payload)
  headers.extend(b[:512]);payload.extend(b[off:off+size]);bases.append(base);lens.append(size//4);offsets.append(off//512);result['fixtures'].append({'path':str(f),'sha256':sha(f),'payload_bytes':size,'base':base,'scene_offset':off})
 assert len(payload)==7215104
 hexbytes(out/'headers.hex',headers);hexbytes(out/'payload_bytes.hex',payload)
 (out/'payload_words.hex').write_text(''.join('%08x\n'%w[0] for w in struct.iter_unpack('<I',payload)),encoding='ascii')
 for name,values in [('bases',bases),('lengths',lens),('offsets',offsets)]: (out/(name+'.hex')).write_text(''.join('%08x\n'%v for v in values),encoding='ascii')
 card=ROOT/'tests/audio_card.hex';shutil.copyfile(card,out/'audio_card.hex');raw=bytes(int(v,16) for v in card.read_text().split());start=raw.index(b'data')+8;size=struct.unpack_from('<I',raw,start-4)[0];samples=raw[start:start+size];assert len(samples)==1200
 (out/'pcm.hex').write_text(''.join('%04x%04x\n'%(l&65535,r&65535) for l,r in struct.iter_unpack('<hh',samples)),encoding='ascii');result['audio_card_sha256']=sha(card)
 result['tools']={}
 for t in ['iverilog','vvp']:
  p=Path('C:/iverilog/bin')/(t+'.exe');r=subprocess.run([str(p),'-V'],capture_output=True);result['tools'][t]={'path':str(p),'sha256':sha(p),'version':(r.stdout+r.stderr).decode(errors='replace')}
 start=time.monotonic();cmd=['C:/iverilog/bin/iverilog.exe','-g2012','-s','html_scene_real_tb','-Phtml_scene_real_tb.SET_ID=32\'d'+str(expected_id),'-Phtml_scene_real_tb.FOCUSED_PAGE0='+('1' if args.focused_page0 else '0'),'-o',str(out/'test.vvp')]+[str(out/n) for n in names[:-1]];result['compile_command']=cmd
 p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,cwd=out);result['compile_pid']=p.pid;log=p.communicate(timeout=60)[0];result['compile_exit']=p.returncode;(out/'compile.log').write_bytes(log)
 if p.returncode==0:
  cmd=['C:/iverilog/bin/vvp.exe',str(out/'test.vvp')];result['simulation_command']=cmd
  with (out/'simulation.log').open('wb') as f:
   p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,cwd=out);result['simulation_pid']=p.pid
   try:p.wait(timeout=3600);result['simulation_exit']=p.returncode
   except subprocess.TimeoutExpired:p.kill();p.wait();result['simulation_exit']=124
  log=(out/'simulation.log').read_bytes()
 marker=b'FOCUSED_PASS' if args.focused_page0 else b'TEST_PASS'
 result['wall_seconds']=time.monotonic()-start;result['state']='UNIT_SIM_PASS' if p.returncode==0 and marker in log else 'UNIT_SIM_FAIL';result['log_sha256']={f.name:sha(f) for f in out.glob('*.log')};(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(log.decode(errors='replace'));print(json.dumps({'output':str(out),'state':result['state']}));return int(result['state']!='UNIT_SIM_PASS')
if __name__=='__main__':raise SystemExit(main())
