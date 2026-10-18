#!/usr/bin/env python3
"""Actual delivered HOME BMP -> final loader2x -> final sequential scanout1frame.
Separate RTL segments joined by full hashed pixel_valid payload, not whole-system.
"""
import argparse,base64,datetime,hashlib,importlib.util,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 q=p.with_suffix('.tmp');q.write_bytes((json.dumps(d,indent=2)+'\n').encode());os.replace(q,p)
def module(name,path):
 q=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(q);q.loader.exec_module(m);return m
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--launch',action='store_true');ap.add_argument('--run-id');a=ap.parse_args();rid=a.run_id or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/no_bot/verify'/('default_home2x_'+rid);out.mkdir(exist_ok=True)
 if a.launch:
  cmd=[sys.executable,'-X','utf8',str(Path(__file__).resolve()),'--run-id',rid];ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+subprocess.list2cmdline(cmd).replace("'","''")+"';CurrentDirectory='"+str(ROOT)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
  q=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True);(out/'dispatch.log').write_bytes(q.stdout+q.stderr);print(out);print(q.stdout.decode(errors='replace'));return q.returncode
 sys.stdout=open(out/'driver.log','a',buffering=1,encoding='utf-8');sys.stderr=sys.stdout
 production=['rtl/ext/legacy_exhibit_loader.v'];files=production+['tests/legacy_exhibit_loader_tb.v','scripts/legacy_exhibit_loader_verify.py','scripts/no_bot_legacy_oracle.py','scripts/no_bot_legacy_default_verify.py']
 for n in files:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 media=ROOT/'output/html_fidelity/no_bot/media';inputs=[media/'UI01.BMP',media/'PN01.BMP'];fixtures=[]
 for p in inputs:
  data=p.read_bytes();f=out/(p.stem+'.hex');f.write_bytes(''.join(f'{v:02x}\n'for v in data).encode());fixtures.append(f)
 oracle=module('default_independent_oracle',out/'scripts/no_bot_legacy_oracle.py');expected,metadata=oracle.expected_rgb(0,False,1,0,media=media);words=[(expected[(y*640+x)*3]<<16)|(expected[(y*640+x)*3+1]<<8)|expected[(y*640+x)*3+2] for y in reversed(range(480))for x in range(640)];gold=out/'home_default2x_gold.hex';gold.write_bytes(''.join(f'{v:06x}\n'for v in words).encode())
 loaderhelper=module('loader_contract',out/'scripts/legacy_exhibit_loader_verify.py');iv=Path(r'C:\iverilog\bin\iverilog.exe');vvp=iv.with_name('vvp.exe');dump=out/'home_default2x_rtl.hex'
 report={'state':'RUNNING','scope':__doc__,'pid':os.getpid(),'started':time.time(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sources':{n:sha(out/n)for n in files},'media':{str(p):sha(p)for p in inputs},'fixtures':{str(p.name):sha(p)for p in fixtures},'independent_oracle':metadata,'gold_sha256':sha(gold),'tools':{str(p):sha(p)for p in [iv,vvp]},'steps':[],'FULL_SYSTEM_SIM':'NOT_RUN','HARDWARE':'NOT_TESTED','configuration':'HOME page0,default multiplier2x(zoomcode1),focus0; loader/scanout event drivers modeled; actualreset default is independently checked in controller/keys tests','model_boundaries':'Loader6/7byte/clock accelerated source, not realTF; subsequent ordered10cycle memorymodel, actual511wordFIFO, production40/25MHz finalRGB; staticOSD prewarm explicit.'}
 def state():save(out/'verification.json',report)
 def run(name,cmd,cwd,timeout):
  tick=time.time();log=out/(name+'.log')
  with log.open('wb')as f:
   p=subprocess.Popen(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT);item={'name':name,'command':cmd,'pid':p.pid,'state':'RUNNING'};report['steps'].append(item);state()
   try:code=p.wait(timeout=timeout)
   except subprocess.TimeoutExpired:p.kill();p.wait();code=124
  item.update(state='PASS'if code==0 else'FAIL',exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));state();return code,log
 state();cmd=[str(iv),'-g2005-sv','-s','legacy_exhibit_loader_tb','-o',str(out/'loader.vvp'),'-Plegacy_exhibit_loader_tb.PAGE=0','-Plegacy_exhibit_loader_tb.ZOOM=1',str(out/'rtl/ext/legacy_exhibit_loader.v'),str(out/'tests/legacy_exhibit_loader_tb.v')]
 code,log=run('compile',cmd,out,120)
 if code:report.update(state='FAIL');state();return 1
 cmd=[str(vvp),str(out/'loader.vvp'),'+left='+str(fixtures[0]),'+right='+str(fixtures[1]),'+gold='+str(gold),'+left_len='+str(inputs[0].stat().st_size),'+right_len='+str(inputs[1].stat().st_size),'+expected_sectors='+str(loaderhelper.sector_count(0,False,1,0)),'+dump='+str(dump)]
 code,log=run('actual_home_default2x_loader',cmd,out,900)
 if code or'TEST_PASS'not in log.read_text():report.update(state='FAIL');state();return 1
 report['actual_loader_payload']=oracle.verify_loader_dump(dump,expected);state()
 cmd=[sys.executable,'-X','utf8','scripts/no_bot_legacy_display_verify.py','--loader-dump',str(dump),'--page','0','--zoom','1','--focus','0','--frames','1','--static-caption','--timeout','3000'];code,log=run('actual_home_default2x_scanout',cmd,ROOT,3300)
 if code:report.update(state='FAIL');state();return 1
 child=Path(log.read_text().strip().splitlines()[-1]);evidence=json.loads((child/'verification.json').read_text());assert evidence['state']=='LEGACY_DISPLAY_SEGMENT_PASS';png=child/'frame_00.png';shutil.copy2(png,out/'home_default2x_actual.png');report.update(state='ACTUAL_DEFAULT_HOME2X_SEGMENTS_PASS',child_evidence=str(child),actual_output_png=str(out/'home_default2x_actual.png'),actual_output_sha256=sha(png),wall_seconds=time.time()-report['started']);state();print(out);return 0
if __name__=='__main__':raise SystemExit(main())
