"""Snapshot two focused production integration regressions on native Windows.
No encrypted SDRAM/SD PHY or hardware claim. ReaderACK is a bounded model.
Startup test intentionally reproduces unsafe default0 and verifies protected1.
"""
import hashlib,json,os,shutil,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LAYER=['rtl/ext/html_layer_'+n+'.v' for n in ['memory_bridge','viewport','span_frontend','descriptor_rom','palette','pixel_engine','cache','join_ram','blend','line_setup']]
START=LAYER+['rtl/ext/html_scene_motion.v','rtl/ext/html_rom16.v','rtl/ext/html_scene_loader.v','rtl/ext/html_resource_locator.v','rtl/display_commit.v','tests/html_startup_boundary_tb.v']
TIMING=['rtl/display_commit.v','rtl/ext/frame_config_bridge.v','rtl/SD/color_bar.v','rtl/SD/video_timing_data.v','tests/html_integration_timing_tb.v']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/html_fidelity/integration_review'/('run_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 files=sorted(set(START+TIMING+['rtl/top_tf_hdmi_audio.v','rtl/SD/video_define.v','scripts/html_integration_verify.py']+[str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]))
 for name in files:
  dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 top=(out/'rtl/top_tf_hdmi_audio.v').read_text(encoding='utf8')
 assert '.REQUIRE_INITIAL_COMMIT(1)' in top, 'production must enable initialcommit protection'
 assert top.count('.dst_frame(timing_read_req&&!timing_req_prev)')==2, 'both production mailboxes must capture raw request edge'
 header=bytearray(512);header[:2]=b'BM';offset=922112;payload=275200*4
 for at,val in [(2,offset+payload),(10,512),(14,40),(18,640),(22,480),(80,0x4c584648),(88,offset),(92,payload),(104,0x003adc1b)]:struct.pack_into('<I',header,at,val)
 for at,val in [(26,1),(28,24),(84,1),(86,32),(102,6)]:struct.pack_into('<H',header,at,val)
 (out/'startup_header.hex').write_bytes(''.join(f'{v:02x}\n' for v in header).encode())
 tools={'iverilog':Path(r'C:\iverilog\bin\iverilog.exe'),'vvp':Path(r'C:\iverilog\bin\vvp.exe')}
 report={'state':'RUNNING','scope':'Actual loader/locator,layerbridge/renderer,display_commit,640x480 timing and mailboxes; bounded20memcycle readerACK (startup3syncstageACK), ordered10cycle4beat allones unwrittenSDRAM; no fullsystem/PHY/HW claim','pid':os.getpid(),'snapshot':str(out),'started':time.time(),'sources':{n:sha(out/n) for n in files},'tools':{n:{'path':str(p),'sha256':sha(p)} for n,p in tools.items()},'steps':[]}
 def save():(out/'verification.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
 save()
 for test,sources in [('startup_boundary',START),('integration_timing',TIMING)]:
  for require in [0,1]:
   stem=test+'_'+str(require);module='html_'+test+'_tb'
   commands=[('compile',[str(tools['iverilog']),'-g2012','-DHTML_SIM','-Irtl/SD','-s',module,f'-P{module}.REQUIRE={require}','-o',stem+'.vvp']+sources),('simulation',[str(tools['vvp']),stem+'.vvp'])]
   for step,cmd in commands:
    log=out/(stem+'_'+step+'.log');start=time.time()
    with log.open('w') as output:
     child=subprocess.Popen(cmd,cwd=out,stdout=output,stderr=subprocess.STDOUT)
     item={'test':test,'require_initial_commit':require,'step':step,'command':cmd,'pid':child.pid,'started':start};report['steps'].append(item);save()
     try:code=child.wait(timeout=180)
     except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
    item.update(exit_code=code,wall_seconds=time.time()-start,log_sha256=sha(log));save()
    if code:report.update(state='FAIL');save();print(log.read_text());return code
   text=log.read_text();marker='REPRODUCED' if test=='startup_boundary' and require==0 else 'TEST_PASS'
   assert marker in text,stem+' missing expected marker'
   print(text.strip(),flush=True)
 report.update(state='UNIT_SIM_PASS',wall_seconds=time.time()-report['started']);save();print(out);return 0
if __name__=='__main__':raise SystemExit(main())
