#!/usr/bin/env python3
"""Fresh serial UI compatibility RTL regression on existing ThinkPad Icarus.

Historical manifests are recipe references only; every input is snapshotted from
current Mac source. No TD, hardware access or RTL/project mutation is performed.
"""
import argparse, datetime, hashlib, json, pathlib, re, struct, subprocess, time, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PYTHON = r'D:\python3.12.3\python.exe'
REMOTE_BASE = 'D:/FPGA/hx4s20_extensions_20261013/sim'
RECIPES = [
    'controls_modes_004', 'controls_storage_002', 'config_002', 'pixel_001',
    'harness_axis_001', 'osd_text_002', 'transition_commit_sdp_001',
    'scale_scan_01', 'scale_sta_reject_01', 'wav_001',
    'audio_fifo_bram_001', 'audio_player_bram_001',
    'audio_media_pipeline_boundary_001', 'audio_output_selection_001',
    'audio_output_pipeline_mux_002', 'audio_visual_bram_001',
    'audio_arbiter_pipeline_001', 'video_audio_integration_004',
    'scale_scan_load_01', 'scale_case3_01', 'existing_tb_storage_spi', 'existing_tb_storage_sd',
]
REMOTE_RUNNER = r'''
import datetime, hashlib, json, os, pathlib, subprocess, sys, time, zipfile
root=pathlib.Path(sys.argv[1]);os.chdir(root)
plan=json.loads((root/'plan.json').read_text())
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
out=root/'results';out.mkdir(exist_ok=False)
identity={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'python':sys.version,'python_executable':sys.executable,'python_sha256':sha(sys.executable),'runner_pid':os.getpid(),'host':os.environ.get('COMPUTERNAME'),'cwd':str(root),'tools':{}}
fs=subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',"Get-Volume -DriveLetter D | Select-Object DriveLetter,FileSystem,FileSystemLabel | ConvertTo-Json -Compress"],capture_output=True,check=True)
identity['volume']=json.loads(fs.stdout.decode('utf-8-sig'))
assert identity['volume']['FileSystem']=='NTFS'
for name in ['iverilog','vvp']:
 exe='C:/iverilog/bin/'+name+'.exe'
 p=subprocess.run([exe,'-V'],capture_output=True,timeout=30)
 identity['tools'][name]={'path':exe,'sha256':sha(exe),'version_exit':p.returncode,'version':(p.stdout+p.stderr).decode(errors='replace')}
(out/'tool_identity.json').write_text(json.dumps(identity,indent=2))
all_results=[];start=time.monotonic()
for case in plan['tests']:
 folder=out/case['id'];folder.mkdir(exist_ok=False)
 record={'id':case['id'],'recipe_reference':case['recipe_reference'],'top':case['top'],'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runner_pid':os.getpid(),'SIM':'FAIL','scope':'explicit existing unencrypted testbench only','source_sha256':{n:sha(root/n) for n in case['inputs']}}
 assert record['source_sha256']=={n:plan['source_sha256'][n] for n in case['inputs']}
 t=time.monotonic();print('START '+case['id'],flush=True)
 cmd=[r'C:\iverilog\bin\iverilog.exe','-g2012','-s',case['top'],'-o',str(folder/'simulation.vvp')]+['-P'+v for v in case['parameters']]+[str(root/n) for n in case['sources']]
 record['compile_command']=cmd
 with (folder/'compile.log').open('wb') as log:
  p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,cwd=root);record['compile_pid']=p.pid
  try:record['compile_exit']=p.wait(timeout=120)
  except subprocess.TimeoutExpired:p.kill();record['compile_exit']=p.wait();record['compile_timeout']=True
 if record['compile_exit']==0:
  cmd=[r'C:\iverilog\bin\vvp.exe',str(folder/'simulation.vvp')];record['simulation_command']=cmd
  with (folder/'simulation.log').open('wb') as log:
   p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,cwd=root);record['simulation_pid']=p.pid
   try:record['simulation_exit']=p.wait(timeout=case['timeout'])
   except subprocess.TimeoutExpired:p.kill();record['simulation_exit']=p.wait();record['simulation_timeout']=True
  output=(folder/'simulation.log').read_text(errors='replace')
  record['completion_lines']=[line for line in output.splitlines() if 'TEST_PASS' in line]
  if record['simulation_exit']==0 and record['completion_lines']:record['SIM']='PASS'
  elif record.get('simulation_timeout'):record['SIM']='TIMEOUT'
 record['elapsed_seconds']=time.monotonic()-t
 record['log_sha256']={p.name:sha(p) for p in folder.glob('*.log')}
 (folder/'result.json').write_text(json.dumps(record,indent=2))
 all_results.append(record)
 print(json.dumps({'id':case['id'],'SIM':record['SIM'],'seconds':record['elapsed_seconds'],'completion':record.get('completion_lines',[])}),flush=True)
 (out/'progress.json').write_text(json.dumps(all_results,indent=2))
summary={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS' if all(r['SIM']=='PASS' for r in all_results) else 'FAIL','fresh_tests':len(all_results),'wall_seconds':time.monotonic()-start,'tests':all_results,'source_sha256':plan['source_sha256'],'source_unchanged_after':{n:sha(root/n) for n in plan['source_sha256']}==plan['source_sha256'],'RTL_MODIFIED_BY_RUNNER':False,'TD_RUN':False,'NEW_BITSTREAM':False,'FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_TESTED'}
(out/'regression_summary.json').write_text(json.dumps(summary,indent=2))
with zipfile.ZipFile(root/'results.zip','x',zipfile.ZIP_DEFLATED) as z:
 for p in out.rglob('*'):
  if p.is_file() and p.suffix not in ['.vvp','.vcd']:z.write(p,p.relative_to(root))
 for p in root.glob('*.ppm'):z.write(p,'rendered/'+p.name)
print('REGRESSION_DONE '+summary['status'],flush=True)
'''

def read_ppm(path):
    data=path.read_bytes();pos=0;tokens=[]
    while len(tokens)<4:
        while data[pos:pos+1].isspace():pos+=1
        if data[pos:pos+1]==b'#':
            pos=data.index(b'\n',pos)+1;continue
        end=pos
        while not data[end:end+1].isspace():end+=1
        tokens.append(data[pos:end]);pos=end
    assert tokens==[b'P6',b'640',b'480',b'255'],tokens
    if data[pos:pos+2]==b'\r\n':pos+=2
    else:pos+=1
    pixels=data[pos:];assert len(pixels)==640*480*3
    return pixels

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--run-id');ap.add_argument('--ui-bmp',type=pathlib.Path);ap.add_argument('--ui-ppm',type=pathlib.Path);ap.add_argument('--only-ui-pixel',action='store_true');ap.add_argument('--select',nargs='+');ap.add_argument('--evidence-root',type=pathlib.Path);a=ap.parse_args()
    assert bool(a.ui_bmp)==bool(a.ui_ppm)
    assert not a.only_ui_pixel or a.ui_bmp
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run_id=a.run_id or 'venue_ui_regression_'+stamp
    assert re.fullmatch(r'[A-Za-z0-9_-]+',run_id)
    evidence=(a.evidence_root or ROOT/'output/venue_emergency_ui/evidence')/('regression_'+stamp)
    evidence.mkdir(parents=True,exist_ok=False)
    cases=[];files=set()
    recipes=json.loads((ROOT/'output/venue_emergency_ui/evidence/regression_recipes.json').read_text())['recipes']
    for reference in (a.select or (['scale_case3_01'] if a.only_ui_pixel else RECIPES)):
        recipe=recipes[reference]
        inputs=recipe['inputs']
        sources=recipe['sources']
        case={'id':recipe['top']+('_full640' if reference=='scale_case3_01' else ''),'recipe_reference':reference,'top':recipe['top'],'sources':sources,'inputs':list(inputs),'parameters':recipe['parameters'],'timeout':recipe['timeout']}
        assert case['id'] not in [c['id'] for c in cases]
        cases.append(case);files.update(inputs)
    local_source_hashes={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in sorted(files)}
    payloads={n:(ROOT/n).read_bytes() for n in sorted(files)}
    ui_provenance=None
    if a.ui_bmp:
        bmp=a.ui_bmp.resolve().read_bytes();pixels=read_ppm(a.ui_ppm.resolve())
        assert bmp[:2]==b'BM' and len(bmp)==921654 and struct.unpack_from('<I',bmp,2)[0]==len(bmp)
        assert struct.unpack_from('<IiiHHI',bmp,14)==(40,640,480,1,24,0)
        assert struct.unpack_from('<I',bmp,10)[0]==54
        expected=b''.join(pixels[y*1920:(y+1)*1920] for y in range(479,-1,-1))
        # Independent PPM RGB reference must exactly match encoded BMP BGR rows.
        assert bytes(v for i in range(0,len(expected),3) for v in (expected[i+2],expected[i+1],expected[i]))==bmp[54:]
        payloads['tests/scale_card_3.hex']=''.join('%02x\n'%v for v in bmp+b'\0'*((-len(bmp))%512)).encode()
        payloads['tests/scale_golden_3.hex']=''.join(expected[i:i+3].hex()+'\n' for i in range(0,len(expected),3)).encode()
        payloads['ui_source/UI05.BMP']=bmp;payloads['ui_source/UI05.ppm']=a.ui_ppm.resolve().read_bytes()
        ui_case=next(c for c in cases if c['top']=='scale_tb')
        ui_case['id']='ui05_real_bmp_full640';ui_case['inputs']+=['ui_source/UI05.BMP','ui_source/UI05.ppm']
        selected_inputs={n for c in cases for n in c['inputs']}
        payloads={n:payloads[n] for n in selected_inputs}
        ui_provenance={'bmp_path':str(a.ui_bmp.resolve()),'bmp_sha256':hashlib.sha256(bmp).hexdigest(),'ppm_path':str(a.ui_ppm.resolve()),'ppm_sha256':hashlib.sha256(a.ui_ppm.resolve().read_bytes()).hexdigest(),'golden':'RGB from independently read top-down P6 source, rows reversed to loader output order; all307200pixels','repository_vectors_modified':False}
    manifest={n:hashlib.sha256(v).hexdigest() for n,v in sorted(payloads.items())}
    plan={'created_utc':stamp,'run_id':run_id,'tests':cases,'source_sha256':manifest,'recipe_policy':'References supply test recipes only. All inputs and results are fresh current-source data.','ui_pixel_provenance':ui_provenance,'remote_runner_sha256':hashlib.sha256(REMOTE_RUNNER.encode()).hexdigest(),'entry_script_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    (evidence/'plan.json').write_text(json.dumps(plan,indent=2))
    (evidence/'remote_runner.py').write_text(REMOTE_RUNNER)
    with zipfile.ZipFile(evidence/'inputs.zip','x',zipfile.ZIP_DEFLATED) as z:
        for n,v in sorted(payloads.items()):z.writestr(n,v)
        z.write(evidence/'plan.json','plan.json');z.write(evidence/'remote_runner.py','remote_runner.py')
    remote_root=REMOTE_BASE+'/'+run_id
    setup=f"import pathlib,zipfile\np=pathlib.Path({remote_root!r});p.mkdir(parents=True,exist_ok=False)\nprint(p)"
    cmd=['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','thinkpad',PYTHON+' -X utf8 -']
    subprocess.run(cmd,input=setup.encode(),check=True,timeout=60)
    subprocess.run(['scp',str(evidence/'inputs.zip'),'thinkpad:'+remote_root+'/inputs.zip'],check=True,timeout=90)
    dispatch=f"import pathlib,zipfile,subprocess,sys\np=pathlib.Path({remote_root!r})\nwith zipfile.ZipFile(p/'inputs.zip') as z:z.extractall(p)\nraise SystemExit(subprocess.call([sys.executable,'-X','utf8',str(p/'remote_runner.py'),str(p)]))"
    start=time.monotonic()
    p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    p.stdin.write(dispatch);p.stdin.close()
    with (evidence/'dispatch.log').open('w') as log:
        for line in p.stdout:print(line,end='',flush=True);log.write(line);log.flush()
    exit_code=p.wait()
    if exit_code:
        (evidence/'dispatch_failure.json').write_text(json.dumps({'ssh_pid':p.pid,'ssh_exit':exit_code,'wall_seconds':time.monotonic()-start,'remote_root':remote_root},indent=2))
        return exit_code
    subprocess.run(['scp','thinkpad:'+remote_root+'/results.zip',str(evidence/'results.zip')],check=True,timeout=90)
    with zipfile.ZipFile(evidence/'results.zip') as z:z.extractall(evidence)
    meta={'utc':stamp,'ssh_pid':p.pid,'ssh_exit':exit_code,'wall_seconds':time.monotonic()-start,'remote_root':remote_root,'input_archive_sha256':hashlib.sha256((evidence/'inputs.zip').read_bytes()).hexdigest(),'local_sources_unchanged_after':local_source_hashes=={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in local_source_hashes}}
    (evidence/'dispatch.json').write_text(json.dumps(meta,indent=2));print('EVIDENCE='+str(evidence),flush=True)
    result=json.loads((evidence/'results/regression_summary.json').read_text())
    return 0 if exit_code==0 and result['status']=='PASS' and meta['local_sources_unchanged_after'] else 1

if __name__=='__main__':raise SystemExit(main())
