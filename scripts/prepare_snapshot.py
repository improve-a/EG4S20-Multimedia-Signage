"""Create a clean, source-only TD snapshot. Never reuse an existing run."""
import argparse,datetime,hashlib,json,pathlib,re,subprocess,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
REMOTE=r'D:\FPGA\hx4s20_extensions_20261013'
a=argparse.ArgumentParser();a.add_argument('run_id');a.add_argument('--synth-top');x=a.parse_args()
assert re.fullmatch('[A-Za-z0-9_-]+',x.run_id)
if x.synth_top:assert re.fullmatch('[A-Za-z_][A-Za-z0-9_]*',x.synth_top)
dest=REMOTE+'\\builds\\'+x.run_id
files={}
for folder,prefix in [('rtl','user_source/hdl_source'),('project/user_source/constraints_source','user_source/constraints_source'),('project/td_project','td_project')]:
    for p in (ROOT/folder).rglob('*'):
        if p.is_file() and not p.name.startswith('.'):
            files[prefix+'/'+p.relative_to(ROOT/folder).as_posix()]=p.read_bytes()
project='td_project/hx4s20_basic.al'
txt=files[project].decode('utf-8')
txt=re.sub(r'(<Project Version="3" Minor="2" Path=")[^"]*',lambda m:m[1]+dest.replace('\\','/')+'/work/design/td_project',txt)
files[project]=txt.encode()
lookup={k.lower() for k in files}
for name in re.findall(r'<File Path="([^"]+)"',txt):
    parts=[]
    for s in ('td_project/'+name).split('/'):
        if s=='..':parts.pop()
        elif s!='.':parts.append(s)
    assert '/'.join(parts).lower() in lookup,name
rows=[dict(path=k,sha256=hashlib.sha256(v).hexdigest(),bytes=len(v)) for k,v in sorted(files.items())]
manifest=dict(schema_version=2,task_root=REMOTE,run_id=x.run_id,source='HX4S20 extension working source',selected=rows,snapshot_sha256=hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest(),zip_sha256='5da6d4e9202fa401bc5bd89d8362f4ecd666c97777449cda6832049d3ba0fff6',created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
# zip_sha256 above is the frozen baseline import, not this run's package hash.
# The package hash is stored outside the ZIP by build.py to avoid self-reference.
manifest['git_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
manifest['git_branch']=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()
manifest['git_status']=subprocess.check_output(['git','status','--short'],cwd=ROOT,text=True).splitlines()
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'evidence/manifests').mkdir(parents=True,exist_ok=True)
out=ROOT/'artifacts'/(x.run_id+'_source.zip')
with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED) as z:
    for k,v in files.items():z.writestr('work/design/'+k,v)
    for p in (ROOT/'harness').glob('*'):
        if p.is_file():
            if p.name=='build.tcl' and x.synth_top:
                z.writestr('harness/build.tcl',(ROOT/'harness/synth_probe.tcl').read_text().replace('@SYN_TOP@',x.synth_top))
            else:z.write(p,'harness/'+p.name)
    z.writestr('audit/scope.json',json.dumps({'scope':'SYNTHESIS_ONLY' if x.synth_top else 'FULL_FLOW','probe_top':x.synth_top}))
    z.writestr('audit/baseline_manifest.json',json.dumps(manifest,indent=2))
(ROOT/'evidence/manifests'/(x.run_id+'.json')).write_text(json.dumps(manifest,indent=2))
print(json.dumps(dict(archive=str(out),remote_root=dest,source_files=len(rows),snapshot_sha256=manifest['snapshot_sha256'],archive_sha256=hashlib.sha256(out.read_bytes()).hexdigest())))
