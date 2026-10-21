#!/usr/bin/env python3
"""Legacy sequential8frame datapath under native600/601clock refreshrequests.
Actual511FIFO/reader/writer/timing/delay+RTLloaderpayload, ordered10clk responses.
Pending request blocks newbursts, acceptedburst+responses drain then20clk blocking;
this bounded scheduling model does not execute encrypted SDRAM/PHY controller.
"""
import argparse,base64,datetime,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 t=p.with_suffix('.tmp');t.write_bytes((json.dumps(d,indent=2)+'\n').encode());os.replace(t,p)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--launch',action='store_true');ap.add_argument('--run-id');a=ap.parse_args();rid=a.run_id or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/no_bot/verify'/('legacy_pressure_'+rid);out.mkdir(exist_ok=True)
 if a.launch:
  cmd=[sys.executable,'-X','utf8',str(Path(__file__).resolve()),'--run-id',rid];ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+subprocess.list2cmdline(cmd).replace("'","''")+"';CurrentDirectory='"+str(ROOT)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json";q=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True);(out/'dispatch.log').write_bytes(q.stdout+q.stderr);print(out);print(q.stdout.decode(errors='replace'));return q.returncode
 sys.stdout=open(out/'driver.log','a',buffering=1,encoding='utf-8');sys.stderr=sys.stdout
 files=['tests/legacy_sequential_pressure_tb.v','rtl/SD/frame_read_write.v','rtl/SD/frame_fifo_read.v','rtl/SD/frame_fifo_write.v','rtl/IP/afifo_32_16_256.v','rtl/IP/afifo_16_32_256.v','rtl/SD/video_delay.v','rtl/SD/video_timing_data.v','rtl/SD/color_bar.v','rtl/display_commit.v']
 for n in files+['rtl/SD/video_define.v','scripts/no_bot_legacy_pressure_verify.py']:
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 source=ROOT/'output/html_fidelity/no_bot/verify/legacy_display_20261018T171156698167Z';shutil.copy2(source/'memory.hex',out/'memory.hex');shutil.copy2(source/'second_loader_payload.hex',out/'payload.hex')
 iv=Path(r'C:\iverilog\bin\iverilog.exe');vvp=iv.with_name('vvp.exe');report={'state':'RUNNING','scope':__doc__,'pid':os.getpid(),'started':time.time(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sources':{n:sha(out/n)for n in files+['rtl/SD/video_define.v','scripts/no_bot_legacy_pressure_verify.py']},'fixtures':{n:sha(out/n)for n in ['memory.hex','payload.hex']},'fixture_association':str(source/'verification.json'),'tools':{str(p):sha(p)for p in [iv,vvp]},'steps':[],'FULL_SYSTEM_SIM':'NOT_RUN','HARDWARE':'NOT_TESTED','clocks':'mem40MHz/video25MHz/source100MHz,800x525640x48016.8msnative','actual_write_source':'Full307200pixel_validactualRTLloaderdump,bottomup,1word/16sysclocks,oldWRITE_V_FLIPacceptaddress/dataexact; backbuffercommitafteractualwritefinish'}
 def state():save(out/'verification.json',report)
 state()
 for period in [600,601]:
  command=[str(iv),'-g2012','-DHTML_SIM','-Irtl/SD','-s','legacy_sequential_pressure_tb',f'-Plegacy_sequential_pressure_tb.REFRESH_PERIOD={period}','-Plegacy_sequential_pressure_tb.FIXTURE_ROOT="'+out.as_posix()+'"','-o',f'pressure_{period}.vvp']+files
  for name,cmd in [('compile',command),('simulation',[str(vvp),f'pressure_{period}.vvp'])]:
   log=out/f'{period}_{name}.log';tick=time.time()
   with log.open('wb')as f:
    p=subprocess.Popen(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT);item={'refresh_request_period':period,'name':name,'command':cmd,'pid':p.pid,'state':'RUNNING'};report['steps'].append(item);state()
    try:code=p.wait(timeout=120 if name=='compile' else 1800)
    except subprocess.TimeoutExpired:p.kill();p.wait();code=124
   item.update(exit_code=code,state='PASS'if code==0 else'FAIL',wall_seconds=time.time()-tick,log_sha256=sha(log));state()
   if code:report.update(state='FAIL',wall_seconds=time.time()-report['started']);state();return 1
  assert'TEST_PASS LEGACY_PRESSURE8frames'in log.read_text();report['steps'][-1]['output']=log.read_text();state()
 report.update(state='LEGACY_PRESSURE600_601_PASS',wall_seconds=time.time()-report['started']);state();print(out);return 0
if __name__=='__main__':raise SystemExit(main())
