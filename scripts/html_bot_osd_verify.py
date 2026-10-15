"""Run native Windows DUT test, retain source/tool hashes and real pixel frames."""
import hashlib,json,os,shutil,struct,subprocess,sys,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/html_fidelity/bot_osd'
SOURCES=['rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/html_bot_overlay.v','rtl/ext/html_osd_overlay.v',
 'rtl/ext/html_assets/html_caption_map.v','tests/html_bot_osd_tb.v']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def png_from_ppm(p):
 data=p.read_bytes();magic,wh,depth,raw=data.split(b'\n',3)
 if magic!=b'P6' or wh!=b'640 480' or depth!=b'255' or len(raw)!=640*480*3:
  raise ValueError(f'invalid real DUT frame {p}: {len(raw)} bytes')
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 scan=b''.join(b'\0'+raw[y*1920:(y+1)*1920] for y in range(480))
 blob=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,480,8,2,0,0,0))
 p.with_suffix('.png').write_bytes(blob+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b''))
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 snapshot=OUT/('verify_'+time.strftime('%Y%m%d_%H%M%S'))
 snapshot.mkdir()
 for name in SOURCES+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]:
  target=snapshot/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 (snapshot/'output/html_fidelity/bot_osd').mkdir(parents=True)
 evidence={'scope':'UNIT_SIM real RTL DUT 640x480; no full-system or hardware claim',
  'root':str(ROOT),'snapshot':str(snapshot),'pid':os.getpid(),'started':time.time(),'state':'RUNNING','sources':{p:sha(ROOT/p) for p in SOURCES},
  'assets':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')},'steps':[]}
 def save():
  blob=json.dumps(evidence,indent=2);(OUT/'verification.json').write_text(blob);(snapshot/'verification.json').write_text(blob)
 save()
 cmds=[('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-Wall','-s','html_bot_osd_tb','-o',str(OUT/'sim.vvp')]+SOURCES),
       ('simulation',[r'C:\iverilog\bin\vvp.exe',str(OUT/'sim.vvp')]+(['+quick'] if '--quick' in sys.argv else []))]
 for name,cmd in cmds:
  start=time.time()
  with (OUT/(name+'.log')).open('w') as log:
   child=subprocess.Popen(cmd,cwd=snapshot,stdout=log,stderr=subprocess.STDOUT)
   step={'name':name,'command':cmd,'pid':child.pid,'start':start,'state':'RUNNING'};evidence['steps'].append(step);save()
   try:code=child.wait(timeout=1800)
   except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
  shutil.copy2(OUT/(name+'.log'),snapshot/(name+'.log'))
  step.update(exit_code=code,wall_seconds=time.time()-start,state='PASS' if code==0 else 'FAIL');save()
  if code:
   evidence.update(state='FAIL',wall_seconds=time.time()-evidence['started']);save();return code
 if 'UNIT_SIM_PASS' not in (OUT/'simulation.log').read_text():raise ValueError('no DUT pass marker')
 evidence['frames']=[]
 for frame in (snapshot/'output/html_fidelity/bot_osd').glob('*.ppm'):shutil.copy2(frame,OUT/frame.name)
 for frame in sorted((snapshot/'output/html_fidelity/bot_osd').glob('*.ppm')):
  p=OUT/frame.name
  png_from_ppm(p);evidence['frames'].append({'file':str(p.relative_to(ROOT)),'sha256':sha(p),'size':p.stat().st_size})
 evidence.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-evidence['started']);save()
 print(json.dumps(evidence,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
