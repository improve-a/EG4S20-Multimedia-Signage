import pathlib, hashlib, json, zipfile, difflib, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8')
root=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020')
cases=[('fail',pathlib.Path(r'D:\FPGA\EG4S20-NoBot'), 'no_bot_legacy_004'),('pass',pathlib.Path(r'D:\FPGA\EG4S20-NoBot-HDMIProbe'),'hdmi_probe_001')]
result={}
for key,repo,id in cases:
 b=root/'baseline_copies'/id
 zpath=repo/'artifacts'/(id+'_source.zip')
 z=zipfile.ZipFile(zpath)
 inputs=json.loads((b/'runs'/id/'inputs.json').read_text())
 mismatches=[]
 for x in inputs:
  h=hashlib.sha256(z.read('work/design/'+x['path'])).hexdigest()
  if h!=x['sha256']:mismatches.append({'path':x['path'],'zip_hash':h,'expected':x['sha256']})
 srcal=z.read('work/design/td_project/hx4s20_basic.al').decode()
 postal=(b/'work/design/td_project/hx4s20_basic.al').read_text()
 manifest=json.loads(z.read('audit/baseline_manifest.json'))
 result[key]={'zip':str(zpath),'sha256':hashlib.sha256(zpath.read_bytes()).hexdigest(),'zip_vs_inputs_mismatches':mismatches,'git_commit':manifest['git_commit'],'git_status':manifest['git_status'],'project_postbuild_diff':''.join(difflib.unified_diff(srcal.splitlines(True),postal.splitlines(True)))}
 target=root/'baseline_copies'/(id+'_source.zip')
 with target.open('xb') as f:f.write(zpath.read_bytes())
 print(key,json.dumps(result[key],ensure_ascii=False,indent=2))
 print('PROJECT_OPTIONS',srcal[srcal.find('<Configurations'):])
for name in ['exported_syn.tcl','exported_phy.tcl']:
 a=(root/'baseline_copies/no_bot_legacy_004/runs/no_bot_legacy_004'/name).read_text()
 b=(root/'baseline_copies/hdmi_probe_001/runs/hdmi_probe_001'/name).read_text()
 print(name,'IDENTICAL',a==b)
 if a!=b: print(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True))))
(root/'source_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('=== gitignore ===')
print((cases[1][1]/'.gitignore').read_text())
print('=== harness files ===')
print('\n'.join(str(x) for x in (cases[1][1]/'harness').iterdir()))
