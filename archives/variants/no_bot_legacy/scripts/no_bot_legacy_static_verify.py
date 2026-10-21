#!/usr/bin/env python3
"""Serial actual-output single-frame captures from independently checked RTL loads.
Static OSD register prewarm is explicit; geometry/source/FIFO/finalRGB all execute.
Never replaces final RGB with BMPs, HTML or software expected images.
"""
import argparse,base64,datetime,hashlib,importlib.util,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj):
 q=p.with_suffix('.tmp');q.write_bytes((json.dumps(obj,indent=2)+'\n').encode());os.replace(q,p)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--loader-root',type=Path,required=True);ap.add_argument('--launch',action='store_true');ap.add_argument('--run-id');a=ap.parse_args();rid=a.run_id or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/no_bot/verify'/('legacy_static_'+rid);out.mkdir(parents=True,exist_ok=True)
 if a.launch:
  args=[x for x in sys.argv[1:]if x!='--launch'];cmd=[sys.executable,'-X','utf8',str(Path(__file__).resolve())]+args+['--run-id',rid]
  ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+subprocess.list2cmdline(cmd).replace("'","''")+"';CurrentDirectory='"+str(ROOT)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
  p=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True);(out/'dispatch.log').write_bytes(p.stdout+p.stderr);save(out/'dispatch.json',{'command':cmd,'return_code':p.returncode,'WMI':p.stdout.decode(errors='replace')});print(out);print(p.stdout.decode(errors='replace'));return p.returncode
 cases=[(f'page{i}',i,0,0,0)for i in range(6)]+[('dual_eagle_phoenix',1,1,0,0),('dual_elf_dragon',3,1,0,0),('zoom2_focus0',1,0,1,0),('zoom3_focus2',2,0,2,2),('dual_zoom3_focus1',3,1,2,1)]
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'scope':__doc__,'static_fixture':'Only OSD swap/typewriter/cursor state prewarmed in blanking to show completed card. No source/geometry/RGB forcing. Continuous animation proof uses natural OSD separately.','loader_root':str(a.loader_root),'entry_sha256':sha(Path(__file__)),'cases':[]};save(out/'status.json',report)
 spec=importlib.util.spec_from_file_location('pixels',ROOT/'scripts/html_display_chain_verify.py');pixels=importlib.util.module_from_spec(spec);spec.loader.exec_module(pixels)
 refs=['home','eagle','phoenix','elf','dragon','eco'];frameout=out/'frames';frameout.mkdir(exist_ok=True)
 for name,page,dual,zoom,focus in cases:
  item={'case':name,'page':page,'dual':bool(dual),'zoom':zoom+1,'focus':focus,'state':'WAITING_LOADER'};report['cases'].append(item);save(out/'status.json',report);start=time.time()
  while True:
   try:
    state=json.loads((a.loader_root/'verification.json').read_text());done=any(c.get('name')==name and c.get('pass_')for c in state['steps'])
   except (OSError,ValueError):done=False
   if done:break
   if time.time()-start>7200:raise RuntimeError('actual loader completion unavailable '+name)
   time.sleep(10)
  dump=a.loader_root/(name+'_rtl.hex');cmd=[sys.executable,'-X','utf8','scripts/no_bot_legacy_display_verify.py','--loader-dump',str(dump),'--page',str(page),'--zoom',str(zoom),'--focus',str(focus),'--frames','1','--static-caption','--timeout','3000']+(['--dual']if dual else [])
  log=out/(name+'.log');tick=time.time()
  with log.open('wb')as f:
   p=subprocess.Popen(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT);item.update(state='RUNNING',command=cmd,pid=p.pid);save(out/'status.json',report);code=p.wait(timeout=3300)
  item.update(exit_code=code,wall_seconds=time.time()-tick,log_sha256=sha(log));save(out/'status.json',report)
  if code:report.update(state='FAIL');save(out/'status.json',report);return 1
  path=Path(log.read_text().strip().splitlines()[-1]);child=json.loads((path/'verification.json').read_text());assert child['state']=='LEGACY_DISPLAY_SEGMENT_PASS'
  pp=path/'frame_00.ppm';rgb=pixels.ppm_read(pp);dest=frameout/(name+'.png');shutil.copy2(pp.with_suffix('.png'),dest);item.update(state='PASS',actual_output_png=str(dest),actual_output_sha256=sha(dest),child_evidence=str(path),source_payload_sha256=sha(dump))
  reference=ROOT/'output/html_fidelity/no_bot/reference'/('reference_'+(refs[page]if not dual and zoom==0 else'dual'if name=='dual_eagle_phoenix'else'zoom'if name=='zoom2_focus0'else'UNAVAILABLE')+'.png')
  if reference.exists():
   w,h,ref=pixels.png_read(reference);assert(w,h)==(640,480);item.update(reference=str(reference),reference_sha256=sha(reference),full_rgb_mae=sum(abs(a-b)for a,b in zip(rgb,ref))/len(rgb),comparison_scope='Actual final RGB vs noBotHTMLstage; actualPCMpeakfixture differs HTMLrandomviz and quantizedglyphs/1pxbaseline are disclosed.')
   diff=bytes(min(255,abs(a-b)*4)for a,b in zip(rgb,ref));tri=b''.join(ref[y*1920:(y+1)*1920]+rgb[y*1920:(y+1)*1920]+diff[y*1920:(y+1)*1920]for y in range(480));pixels.png_write(frameout/(name+'_reference_actual_diff.png'),1920,480,tri)
  save(out/'status.json',report)
 report.update(state='ACTUAL_RTL_STATIC_PASS',wall_seconds=time.time()-report['started']);save(out/'status.json',report);print(out);return 0
if __name__=='__main__':raise SystemExit(main())
