"""One bounded actual-HOME loader test at production SPI byte cadence; no hardware."""
import hashlib,json,subprocess,time,os
from pathlib import Path
from legacy_exhibit_loader_verify import load,oracle
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/no_bot/verify'/('loader_spi_gap_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 old=Path(r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\default_home2x_final592_r2_20261019')
 media=Path(r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media')
 inputs=[ROOT/'rtl/ext/legacy_exhibit_loader.v',ROOT/'tests/legacy_exhibit_loader_tb.v',ROOT/'rtl/SD/sd_card_top.v',ROOT/'rtl/SD/spi_master.v',ROOT/'rtl/SD/sd_card_cmd.v',ROOT/'rtl/SD/sd_card_sec_read_write.v']
 snap=out/'sources';snap.mkdir()
 for f in inputs:(snap/f.name).write_bytes(f.read_bytes())
 left,right=load(media/'UI01.BMP'),load(media/'PN01.BMP')
 for name,data in [('UI01',left[0]),('PN01',right[0])]: (out/(name+'.hex')).write_bytes(('\n'.join(f'{v:02x}' for v in data)+'\n').encode())
 gold=oracle(left,right,0,0,1,0);gp=out/'gold.hex';gp.write_bytes(('\n'.join(f'{v:06x}' for v in gold)+'\n').encode())
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'source_commit':'6ee7c70bbf36c33f90a687f010c876de48f03ba6','working_head':'17ac5f2','scope':'Actual loader, page0 single 2x focus0; source-byte cadence only. Not fullSD protocol, SDRAM, HDMI or hardware.','sources':{str(f.relative_to(ROOT)):sha(f) for f in inputs},'script_sha256':sha(__file__),'media':{str(media/n):sha(media/n) for n in ['UI01.BMP','PN01.BMP']},'spi_byte_period':70,'spi_derivation':'sd_card_top HIGH_SPEED_DIV2. spi_master 16*(2+2) edge clocks +3 last-half +1 ACK +1 ACK_WAIT +1 IDLE =70 sysclks/byte. sd_card_cmd S_READ holds request; block_read_valid registers wr_ack; sec wrapper only gates it.','model_limits':'No command/token latency added: this falsifies spacing dependency, not card protocol/latency. Production TIMEOUT200000000 retained.','steps':[],'historical_fast_receipt':str(old/'verification.json')}
 def save():(out/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
 save();iv=r'C:\iverilog\bin\iverilog.exe';vvp=r'C:\iverilog\bin\vvp.exe';report['tools']={f:sha(f) for f in [iv,vvp]}
 for mode,name in [(13,'short_data_sector'),(0,'home_default2x')]:
  params={'PAGE':0,'DUAL':0,'ZOOM':1,'FOCUS':0,'MODE':mode,'BYTE_PERIOD':70,'TIMEOUT':200000000,'WATCHDOG_NS':1500000000}
  cmd=[iv,'-g2005-sv','-s','legacy_exhibit_loader_tb','-o',str(out/(name+'.vvp'))]+['-Plegacy_exhibit_loader_tb.'+k+'='+str(v) for k,v in params.items()]+[str(snap/'legacy_exhibit_loader.v'),str(snap/'legacy_exhibit_loader_tb.v')]
  t=time.time();c=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=30);(out/(name+'.compile.log')).write_bytes((c.stdout+c.stderr).encode());step={'name':name,'parameters':params,'compile_command':cmd,'compile_exit':c.returncode}
  if c.returncode!=0:report['state']='FAIL';report['steps'].append(step);save();return 1
  args=[vvp,str(out/(name+'.vvp')),'+left='+str(out/'UI01.hex'),'+right='+str(out/'PN01.hex'),'+gold='+str(gp),'+left_len=922112','+right_len=461312','+expected_sectors=1081']
  if mode==0:args+=['+dump='+str(out/'home_default2x_rtl.hex')]
  v=subprocess.Popen(args,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);report['active_case']={'name':name,'pid':v.pid,'started':time.time()};step['simulation_command']=args;step['pid']=v.pid;save()
  stdout,stderr=v.communicate(timeout=1500);log=stdout+stderr;(out/(name+'.run.log')).write_bytes(log.encode());step.update(exit_code=v.returncode,output=log.strip(),wall_seconds=time.time()-t,pass_=v.returncode==0 and 'TEST_PASS' in log)
  if mode==0 and step['pass_']:
   actual=out/'home_default2x_rtl.hex';words=[int(x,16) for x in actual.read_text().split()];step.update(pixels=len(words),payload_sha256=sha(actual),independent_coordinate_gold_equal=words==gold,historical_fast_payload_sha256=sha(old/'home_default2x_rtl.hex'),historical_fast_payload_equal=actual.read_bytes()==(old/'home_default2x_rtl.hex').read_bytes());step['pass_']=step['pass_'] and words==gold and step['historical_fast_payload_equal']
  report.pop('active_case',None);report['steps'].append(step);save();print(name,step['pass_'],log.strip(),flush=True)
  if not step['pass_']:report['state']='FAIL';save();return 1
 report['state']='UNIT_SIM_PASS';report['finished']=time.time();report['wall_seconds']=report['finished']-report['started'];report['conclusion']='REFUTED for tested loader config: 70-clock byte spacing retains every pixel; short data sector still rejected as error2.';save();print('RESULT',out,flush=True);return 0
if __name__=='__main__':raise SystemExit(main())
