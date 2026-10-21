#!/usr/bin/env python3
"""Windows-native isolated real-media loader/tag unit verification; no TD/card access."""
import datetime,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/verification'/stamp;out.mkdir(parents=True,exist_ok=False)
 files=['rtl/ext/html_panel_loader.v','rtl/ext/html_read_tags.v','rtl/ext/media_sector_arbiter.v','tests/html_panel_loader_tb.v','scripts/html_fidelity_verify_io.py'];inputs={}
 for n in files:
  f=ROOT/n;d=out/n;d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,d);inputs[n]=sha(f)
 fixtures=[];raw=bytearray()
 for i in range(2,6):
  f=ROOT/f'output/html_fidelity/media/UI{i:02d}.BMP';b=f.read_bytes();assert b[54:58]==b'HFXC';raw.extend(b[:250368]);fixtures.append({'path':str(f),'sha256':sha(f),'prefix_bytes':250368})
 (out/'media_prefix.hex').write_text(''.join(f'{v:02x}\n' for v in raw),encoding='ascii')
 result=dict(utc=stamp,pid=os.getpid(),source_sha256=inputs,fixtures=fixtures,fixture_sha256=sha(out/'media_prefix.hex'),scope='UNIT_SIM_ONLY loader resource transport and tag metadata; no full-system/hardware/build claim',tests=[])
 result['tool_identity']={}
 for tool in ['iverilog','vvp']:
  p=Path('C:/iverilog/bin')/(tool+'.exe');r=subprocess.run([str(p),'-V'],capture_output=True);result['tool_identity'][tool]={'path':str(p),'sha256':sha(p),'version':(r.stdout+r.stderr).decode(errors='replace')}
 for top in ['html_panel_loader_tb','html_read_tags_tb']:
  test={'top':top};start=time.monotonic();compile_cmd=['C:/iverilog/bin/iverilog.exe','-g2012','-s',top,'-o',str(out/(top+'.vvp'))]+[str(out/n) for n in files[:4]]
  test['compile_command']=compile_cmd;p=subprocess.Popen(compile_cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,cwd=out);test['compile_pid']=p.pid;data=p.communicate(timeout=60)[0];test['compile_exit']=p.returncode;(out/(top+'.compile.log')).write_bytes(data)
  if p.returncode==0:
   cmd=['C:/iverilog/bin/vvp.exe',str(out/(top+'.vvp'))];test['simulation_command']=cmd
   with (out/(top+'.simulation.log')).open('wb') as log:
    p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,cwd=out);test['simulation_pid']=p.pid
    try:p.wait(timeout=120);test['simulation_exit']=p.returncode
    except subprocess.TimeoutExpired:p.kill();p.wait();test['simulation_exit']=124
   data=(out/(top+'.simulation.log')).read_bytes();test['state']='UNIT_SIM_PASS' if p.returncode==0 and b'TEST_PASS' in data else 'UNIT_SIM_FAIL';print(data.decode(errors='replace'))
  else:test['state']='COMPILE_FAIL';print(data.decode(errors='replace'))
  test['wall_seconds']=time.monotonic()-start;test['log_sha256']={f.name:sha(f) for f in out.glob(top+'.*.log')};result['tests'].append(test)
 result['state']='UNIT_SIM_PASS' if all(t['state']=='UNIT_SIM_PASS' for t in result['tests']) else 'UNIT_SIM_FAIL';(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps({'out':str(out),'state':result['state']}));return 0 if result['state']=='UNIT_SIM_PASS' else 1
if __name__=='__main__':raise SystemExit(main())
