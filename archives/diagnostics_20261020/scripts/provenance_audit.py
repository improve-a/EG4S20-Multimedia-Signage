"""Windows-only audit/copy of exact build evidence; originals are never written."""
import hashlib, json, pathlib, shutil, subprocess, zipfile, difflib, sys

sys.stdout.reconfigure(encoding='utf-8')

ROOT = pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020')
BASES = {
    'fail': pathlib.Path(r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'),
    'pass': pathlib.Path(r'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'),
}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
result = {}
for key, b in BASES.items():
    run = b / 'runs' / b.name
    inputs = json.loads((run / 'inputs.json').read_text())
    actual = []
    for x in inputs:
        p = b / 'work/design' / x['path']
        actual.append(dict(path=x['path'], expected=x['sha256'], actual=sha(p) if p.exists() else None))
    result[key] = {'build': str(b), 'input_count': len(inputs), 'input_mismatches': [x for x in actual if x['expected'] != x['actual']]}
    result[key]['inputs'] = actual
    # Archive whole exact build under a new, exclusive destination, not in the success freeze.
    target = ROOT / 'baseline_copies' / b.name
    if target.exists(): raise SystemExit(f'Refusing to overwrite {target}')
    shutil.copytree(b, target)
    files=[]
    for p in sorted(b.rglob('*')):
        if p.is_file():
            rel=p.relative_to(b)
            h=sha(p)
            assert sha(target/rel)==h, str(rel)
            files.append({'path':rel.as_posix(),'bytes':p.stat().st_size,'sha256':h})
    result[key]['archive'] = str(target)
    result[key]['archive_files'] = files
    result[key]['status'] = json.loads((run/'status.json').read_text())

a={x['path']:x['actual'] for x in result['fail']['inputs']}
b={x['path']:x['actual'] for x in result['pass']['inputs']}
changes=[]
diffs=[]
for name in sorted(a.keys()|b.keys()):
    if a.get(name)!=b.get(name):
        changes.append({'path':name,'fail':a.get(name),'pass':b.get(name)})
        if name in a and name in b:
            p1=BASES['fail']/'work/design'/name
            p2=BASES['pass']/'work/design'/name
            diffs.extend(difflib.unified_diff(p1.read_text(errors='replace').splitlines(True),p2.read_text(errors='replace').splitlines(True),fromfile='fail/'+name,tofile='pass/'+name))
result['input_changes']=changes
(ROOT/'provenance_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(ROOT/'snapshot.diff').write_text(''.join(diffs),encoding='utf-8')
print(json.dumps({k:{x:y for x,y in v.items() if x not in ('inputs','archive_files')} for k,v in result.items() if k!='input_changes'},indent=2))
print(json.dumps(changes,indent=2))
print('SNAPSHOT_DIFF\n'+''.join(diffs))
