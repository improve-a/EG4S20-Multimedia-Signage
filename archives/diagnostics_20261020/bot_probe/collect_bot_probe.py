import pathlib,json,hashlib,zipfile,sys
R=pathlib.Path(__file__).resolve().parents[1];ID='bot_hdmi_probe_001';D=R/'output/html_fidelity/builds'/ID
sys.path.insert(0,str(R/'harness'))
from report_parser import parse
result=parse(D,ID)
out=R/'output/bot_probe_delivery';out.mkdir(exist_ok=False)
result['source_commit']=json.loads((D/'audit/baseline_manifest.json').read_text())['git_commit']
result['failure_stage']='PNR / Global Placement / Place Packing'
result['direct_error']='PHY-9009: MSLICE 4925 exceeds 4900'
result['final_routed_setup_hold']='NOT_RUN'
result['hardware']='NOT_RUN: no bitstream generated; no hardware or card writes'
result['bitstream']=None
assert not list(D.rglob('*.bit'))
report=out/(ID+'_reports.zip')
with zipfile.ZipFile(report,'x',zipfile.ZIP_DEFLATED) as z:
 for folder in [D/'audit',D/'runs'/ID,D/'work/design/td_project/hx4s20_basic_Runs',R/'output/bot_probe_verification']:
  for p in folder.rglob('*'):
   if p.is_file() and p.suffix.lower() in ['.txt','.log','.json','.tsv','.rpt','.area','.tcl','.diff','.status']:
    z.write(p,p.relative_to(R).as_posix())
hashes={}
for p in [report,R/'artifacts'/(ID+'_source.zip')]:hashes[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
result['archives']=hashes
(out/'manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(out/'SHA256SUMS.txt').write_text('\n'.join(h+'  '+p for p,h in hashes.items())+'\n')
print(json.dumps(result,indent=2))
