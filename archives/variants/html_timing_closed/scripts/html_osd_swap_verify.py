"""Snapshot real swap RTL pixels and compare curve parameters to CSS oracle."""
import csv,hashlib,importlib.util,json,math,shutil,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/ext/html_osd_swap_rom.v','rtl/ext/html_caption_column_rom.v','rtl/ext/html_rom16.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_assets/html_caption_map.v','tests/html_osd_swap_tb.v']
def main():
 out=ROOT/'output/html_fidelity/osd_swap'/('run_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 files=SOURCES+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for name in files:
  dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 report={'state':'RUNNING','snapshot':str(out),'started':time.time(),'sources':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in files},'steps':[]}
 def save():
  b=json.dumps(report,indent=2).encode();(out/'verification.json').write_bytes(b);(out.parent/'verification.json').write_bytes(b)
 save()
 for name,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','html_osd_swap_tb','-o','sim.vvp']+SOURCES),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  start=time.time()
  with (out/(name+'.log')).open('w') as log:
   child=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'command':cmd,'pid':child.pid};report['steps'].append(step);save();code=child.wait(timeout=120)
  step.update(exit_code=code,wall_seconds=time.time()-start);save()
  if code:
   report.update(state='FAIL',wall_seconds=time.time()-report['started']);save();raise RuntimeError((out/(name+'.log')).read_text())
 spec=importlib.util.spec_from_file_location('oracle',ROOT/'scripts/html_scene_motion_verify.py');oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
 for row in csv.DictReader((out/'swap_actual.csv').open()):
  age=int(row['age']);actual=int(row['values'],16);q=oracle.oracle_ease(age*.0168/.5,(.16,1,.3,1));dy=math.floor(6*(1-q)+.5);a=math.floor(q*255+.5);wanted=dy
  for fg in [(26,25,22),(119,115,107)]:
   for coverage in [1,2,3]:
    rgb=[math.floor((f*a*coverage+b*(765-a*coverage))/765+.5) for f,b in zip(fg,(237,233,226))];wanted=(wanted<<24)|(rgb[0]<<16)|(rgb[1]<<8)|rgb[2]
  if actual!=wanted:raise AssertionError((age,actual,wanted))
 frames=[]
 for ppm in out.glob('swap_*.ppm'):
  header=ppm.read_bytes().split(b'\n',3);rgb=header[3]
  if len(rgb)!=640*83*3:raise ValueError('incomplete DUT crop')
  def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
  scan=b''.join(b'\0'+rgb[y*1920:(y+1)*1920] for y in range(83));png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,83,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b'');ppm.with_suffix('.png').write_bytes(png)
  frames.append({'file':str(ppm),'sha256':hashlib.sha256(ppm.read_bytes()).hexdigest(),'scope':'actualDUT lower83rows,notfullframe'})
 report.update(state='UNIT_SIM_PASS',oracle='Independent Newton CSS curve;32frames,nearest-pixel translate,8bit opacity',frames=frames,wall_seconds=time.time()-report['started']);save();print(json.dumps(report,indent=2));print((out/'simulation.log').read_text())
if __name__=='__main__':main()
