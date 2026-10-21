"""Finalize private offline delivery, after all builds and reviews have ended."""
import datetime,hashlib,json,pathlib,subprocess,zipfile
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020');d=r/'delivery';repo=r/'repo'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not subprocess.check_output(['git','status','--short'],cwd=repo,text=True).strip()
report=repo/'docs/rca/RCA_REPORT.md'
with (d/'RCA_REPORT.md').open('xb') as f:f.write(report.read_bytes())
with zipfile.ZipFile(d/'rca_verification.zip','a',zipfile.ZIP_DEFLATED) as z:
 for id in ('rca_no_locked_003','rca_locked_only_001'):
  for p in (r/'netcheck'/id).iterdir():
   if p.suffix in ('.rpt','.json','.log','.tcl','.sdc'):
    arc='windows_netcheck/'+id+'/'+p.name
    assert arc not in z.namelist(),arc
    z.write(p,arc)
files=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(d.iterdir()) if p.is_file() and p.name not in ('FINAL_MANIFEST.json','SHA256SUMS.txt')]
manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'conclusion':'ROOT_CAUSE_UNRESOLVED','offline_build':'OFFLINE_BUILD_PASS','hardware':'HARDWARE_NOT_TESTED','classification':'Two diagnostic bitstreams; no production root-cause fix','delivery_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'branch':'codex/nobot-rca-20261020','worker_model':'deepseek/deepseek-flash (DeepSeek V4.1 Flash 1017)','baseline_freeze':str(pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020')),'private_full_build_archive':str(r/'baseline_copies'),'new_builds':str(r/'builds'),'new_netlists_and_init_STA':str(r/'netcheck'),'files':files}
with (d/'FINAL_MANIFEST.json').open('x',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
with (d/'SHA256SUMS.txt').open('x',encoding='utf-8') as f:
 for p in sorted(d.iterdir()):
  if p.is_file() and p.name!='SHA256SUMS.txt':f.write(sha(p)+'  '+p.name+'\n')
print(json.dumps(manifest,indent=2))
