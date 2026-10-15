"""Compare actual RTL Bot crop to the source HTML at identical known state."""
import argparse,hashlib,importlib.util,json,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/ext/html_rom16.v','rtl/ext/html_bot_overlay.v','tests/html_bot_reference_tb.v']
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--label',default='current');a=ap.parse_args()
 out=ROOT/'output/html_fidelity/bot_reference'/(a.label+'_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 spec=importlib.util.spec_from_file_location('images',ROOT/'scripts/html_display_chain_verify.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 for name in SOURCES+['rtl/ext/html_assets/bot_body_argb4444.hex']:
  dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
 base,_=m.bmp_rgb(ROOT/'output/html_fidelity/media/UI01.BMP')
 (out/'page0_rgb.hex').write_bytes(''.join(f'{base[i]:02x}{base[i+1]:02x}{base[i+2]:02x}\n' for i in range(0,len(base),3)).encode())
 report={'state':'RUNNING','snapshot':str(out),'started':time.time(),'label':a.label,'scope':'RealDUT104x100crop withrealpage0background; sameknownstaticstate assix-pagechain; notfullsystem','sources':{n:m.sha(out/n) for n in SOURCES},'steps':[]}
 def save():
  data=json.dumps(report,indent=2).encode();(out/'verification.json').write_bytes(data);(out.parent/'verification.json').write_bytes(data)
 save()
 for name,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','html_bot_reference_tb','-o','sim.vvp']+SOURCES),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  start=time.time()
  with (out/(name+'.log')).open('w') as log:
   child=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'command':cmd,'pid':child.pid};report['steps'].append(step);save();code=child.wait(timeout=120)
  step.update(exit_code=code,wall_seconds=time.time()-start);save()
  if code:report.update(state='FAIL');save();raise RuntimeError((out/(name+'.log')).read_text())
 source=ROOT/'output/html_fidelity/assets/reference_home.png';_,_,ref=m.png_read(source)
 wanted=b''.join(ref[(y*640+520)*3:(y*640+624)*3] for y in range(368,468));actual=(out/'bot_actual.ppm').read_bytes().split(b'\n',3)[3]
 if len(actual)!=31200:raise ValueError('DUTcropcount')
 diff=bytes(min(255,abs(x-y)*4) for x,y in zip(actual,wanted));triptych=b''.join(wanted[y*312:(y+1)*312]+actual[y*312:(y+1)*312]+diff[y*312:(y+1)*312] for y in range(100))
 m.png_write(out/'reference_dut_diff.png',312,100,triptych);m.png_write(out/'bot_actual.png',104,100,actual)
 def metric(predicate):
  errors=[abs(actual[(y*104+x)*3+c]-wanted[(y*104+x)*3+c]) for y in range(100) for x in range(104) if predicate(x,y) for c in range(3)]
  return {'rgb_mae':sum(errors)/len(errors),'channel_checks':len(errors),'max_error':max(errors)}
 report.update(state='UNIT_SIM_PASS',reference=str(source),reference_sha256=m.sha(source),actual_sha256=m.sha(out/'bot_actual.ppm'),metrics={'all':metric(lambda x,y:True),'eyes':metric(lambda x,y:30<=x<75 and 40<=y<65),'body_without_eyes':metric(lambda x,y:y<90 and not(30<=x<75 and 40<=y<65)),'shadow':metric(lambda x,y:y>=90)},wall_seconds=time.time()-report['started']);save();print(json.dumps(report,indent=2));print((out/'simulation.log').read_text())
if __name__=='__main__':main()
