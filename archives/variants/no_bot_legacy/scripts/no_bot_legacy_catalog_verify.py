#!/usr/bin/env python3
"""Actual production scanner against all10 delivery BMP headers and FAT LBAs."""
import hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('catalog_headers_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 media=ROOT/'output/html_fidelity/no_bot/media';names=[f'UI{i:02d}.BMP' for i in range(1,7)]+[f'PN{i:02d}.BMP' for i in range(1,5)];positions=[2081,3882,5683,7484,9285,11086,12887,13788,14689,15590]
 # These LBAs are separately generated FAT image facts, not scanner formulas.
 (out/'headers.hex').write_bytes(''.join(f'{v:02x}\n' for n in names for v in (media/n).read_bytes()[:512]).encode());(out/'positions.hex').write_bytes(''.join(f'{v:08x}\n' for v in positions).encode())
 files=['tests/legacy_catalog_headers_tb.v','rtl/ext/bmp_scale.v','scripts/no_bot_legacy_catalog_verify.py']
 for n in files:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'scope':__doc__+' Byteport model4clocks/byte, header-only scanner segment; no SPI/physicalcard/whole-system claim.','media_sha256':{n:sha(media/n) for n in names},'sources':{n:sha(out/n) for n in files},'fixtures':{n:sha(out/n) for n in ['headers.hex','positions.hex']},'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for step,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','legacy_catalog_headers_tb','-Plegacy_catalog_headers_tb.FIXTURE_ROOT="'+out.as_posix()+'"','-o','sim.vvp']+files[:2]),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
  tick=time.time();log=out/(step+'.log')
  with log.open('wb')as f:
   p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'step':step,'command':cmd,'pid':p.pid};report['steps'].append(item);save();code=p.wait(timeout=60)
  item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save()
  if code:report.update(state='FAIL');save();print(log.read_text());print(out);return 1
 assert 'TEST_PASS' in log.read_text();report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started']);save();print(log.read_text());print(out);return 0
if __name__=='__main__':raise SystemExit(main())
