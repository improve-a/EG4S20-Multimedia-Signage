"""Collect one completed run, including final timing path categories; no rebuild."""
import collections,hashlib,json,pathlib,re,sys,zipfile
R=pathlib.Path(__file__).resolve().parents[1];ID='bot_hdmi_probe_infer_add_off_001'
D=R/'output/html_fidelity/builds'/ID;J=D/'runs'/ID
sys.path.insert(0,str(R/'harness'))
from report_parser import parse
result=parse(D,ID)
out=R/'output/bot_probe_infer_add_delivery'
if out.exists():assert not list(out.iterdir()),'No overwrite of collected evidence'
else:out.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8',errors='replace') if p.exists() else ''
result['source_commit']=json.loads((D/'audit/baseline_manifest.json').read_text())['git_commit']
text=read(J/'final_timing.rpt');group='';paths=[];path=None
for line in text.splitlines():
 m=re.match(r'^Path Group\s+:\s+(.+)$',line)
 if m:group=m[1]
 m=re.match(r'^Slack\s+:\s+(-?[\d.]+)ns',line)
 if m:
  if path:paths.append(path)
  path=dict(group=group,slack_ns=float(m[1]))
 if path:
  for label,key in [('Begin Point','begin'),('End Point','end'),('Check Type','check')]:
   m=re.match('^'+label+r'\s+:\s+(.+)$',line)
   if m:path[key]=m[1].strip()
if path:paths.append(path)
checks={}
for kind in ['setup','hold','recovery','removal']:
 rows=[p for p in paths if p.get('check')==kind]
 checks[kind]=dict(displayed_paths=len(rows),negative_displayed_paths=sum(p['slack_ns']<0 for p in rows),worst=min(rows,key=lambda p:p['slack_ns']) if rows else None)
result['final_path_checks']=checks
result['path_scope']='Displayed worst paths only, ep_num=128/path_num=2; group summaries and coverage need review.'
result['stages_text']=read(J/'stages.tsv')
result['option_evidence']=[s for s in read(J/'stdout.log').splitlines() if 'infer_add' in s]
result['packing_evidence']=[s for s in read(D/'work/design/td_project/hx4s20_basic_Runs/phy_1/run.log').splitlines() if 'mslices' in s or 'PHY-9009' in s]
for key,filename in [('coverage_report','check_timing.rpt'),('clock_report','clocks.rpt')]:
 result[key]=read(J/filename)
result['bitstream']=None
if result['BUILD_PASS']:
 bit=D/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
 assert bit.relative_to(D).as_posix() in [p.replace('\\','/') for p in result['fresh_bitstreams']]
 dest=out/(ID+'.bit')
 with dest.open('xb') as f:f.write(bit.read_bytes())
 result['bitstream']=dict(path=str(dest),sha256=sha(dest),bytes=dest.stat().st_size,hardware='NOT_TESTED')
report=out/(ID+'_reports.zip')
with zipfile.ZipFile(report,'x',zipfile.ZIP_DEFLATED) as z:
 for folder in [D/'audit',J,D/'work/design/td_project/hx4s20_basic_Runs',R/'output/infer_add_inspect']:
  for p in folder.rglob('*'):
   if p.is_file() and p.suffix.lower() in ['.txt','.log','.json','.tsv','.rpt','.area','.tcl','.diff','.status']:
    z.write(p,p.relative_to(R).as_posix())
result['archives']={str(p):sha(p) for p in [report,R/'artifacts'/(ID+'_source.zip')]}
(out/'manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(out/'SHA256SUMS.txt').write_text('\n'.join(h+'  '+p for p,h in result['archives'].items())+'\n'+(result['bitstream']['sha256']+'  '+result['bitstream']['path']+'\n' if result['bitstream'] else ''))
print(json.dumps(result,indent=2))
