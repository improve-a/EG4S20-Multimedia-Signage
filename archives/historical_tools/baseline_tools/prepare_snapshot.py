"""Package a clean Windows per-run source snapshot, reusing existing TD supervisor."""
import argparse,pathlib,hashlib,json,zipfile,datetime,re
p=argparse.ArgumentParser();p.add_argument('run_id');p.add_argument('--official-baseline',action='store_true');a=p.parse_args();assert re.fullmatch('[A-Za-z0-9_-]+',a.run_id)
r=pathlib.Path(__file__).resolve().parent.parent
remote=r'D:\FPGA\hx4s20_contest1_20261013';dest=remote+'\\builds\\'+a.run_id
files={}
src=r/'reference/official/lab_ex4_tf/src/user_source/hdl_source' if a.official_baseline else r/'rtl'
official=r/'reference/official/lab_ex4_tf/src'
con=official/'user_source/constraints_source' if a.official_baseline else r/'constraints'
proj=official/'td_project' if a.official_baseline else r/'project'
for base,prefix in [(src,'user_source/hdl_source'),(con,'user_source/constraints_source'),(proj,'td_project')]:
 for f in base.rglob('*'):
  if f.is_file():files[prefix+'/'+f.relative_to(base).as_posix()]=f.read_bytes()
project='td_project/hx4s20_basic.al'
if a.official_baseline:
 files[project]=files.pop('td_project/lab_ex5_i2s_v1.0.al')
 txt=files[project].decode('utf-8').replace('<Name>lab_ex5_i2s_v1.0</Name>','<Name>hx4s20_basic</Name>')
 txt=re.sub(r'\s*<CWC_FILE>.*?</CWC_FILE>','',txt,flags=re.S)
 files[project]=txt.encode('utf-8')
 key='user_source/constraints_source/timing.sdc'
 files[key]=re.sub(rb'^set_clock_groups -exclusive[^\r\n]*',b'# Removed invalid exclusive relationship between concurrently active clocks.',files[key],flags=re.M)
txt=files[project].decode('utf-8');txt=re.sub(r'(<Project Version="3" Minor="2" Path=")[^"]*',lambda m:m[1]+dest.replace('\\','/')+'/work/design/td_project',txt);files[project]=txt.encode('utf-8')
# Validate all source entries resolve, accounting for Windows case-insensitivity.
lookup={x.lower() for x in files}
for path in re.findall(r'<File Path="([^"]+)"',txt):
 parts=[]
 for v in ('td_project/'+path).split('/'):
  if v=='..':parts.pop()
  elif v!='.':parts.append(v)
 assert '/'.join(parts).lower() in lookup,path
rows=[dict(path=k,sha256=hashlib.sha256(v).hexdigest(),bytes=len(v)) for k,v in sorted(files.items())]
manifest=dict(schema_version=2,task_root=remote,run_id=a.run_id,source='official ex4 frozen baseline' if a.official_baseline else 'integrated working source',selected=rows,snapshot_sha256=hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest(),zip_sha256=json.loads((r/'audit/official_manifest.json').read_text())['zip_sha256'],created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
out=r/'artifacts'/(a.run_id+'_source.zip')
with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED) as z:
 for k,v in files.items():z.writestr('work/design/'+k,v)
 for f in (r/'scripts/harness').glob('*'):
  if f.is_file():z.write(f,'harness/'+f.name)
 z.writestr('audit/baseline_manifest.json',json.dumps(manifest,indent=2))
(r/'audit'/(a.run_id+'_manifest.json')).write_text(json.dumps(manifest,indent=2))
print(json.dumps(dict(archive=str(out),remote_root=dest,source_files=len(rows),snapshot_sha256=manifest['snapshot_sha256'])))
