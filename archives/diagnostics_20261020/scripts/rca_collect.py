"""Collect fresh final PHY bits and concise TD evidence; never select best_result."""
import argparse,hashlib,json,pathlib,shutil,sys,zipfile
repo=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(repo/'harness'))
from report_parser import parse
p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('ids',nargs='+');a=p.parse_args()
results=[]
for id in a.ids:
 b=a.root/'builds'/id;job=b/'runs'/id
 result=parse(b,id)
 assert result['BUILD_PASS'],result
 bit=b/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
 dest=a.root/'delivery'/(id+'.bit')
 with dest.open('xb') as f:f.write(bit.read_bytes())
 manifest=json.loads((b/'audit/baseline_manifest.json').read_text())
 result['source_commit']=manifest['git_commit'];result['experiment']=manifest['experiment']
 result['rtl_checks']=json.loads((b/'rca_checks/receipt.json').read_text())
 result['bit']={'path':str(dest),'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
 source=a.root/'delivery'/(id+'_source.zip')
 result['source_zip']={'path':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
 reports=a.root/'delivery'/(id+'_reports.zip')
 with zipfile.ZipFile(reports,'x',zipfile.ZIP_DEFLATED) as z:
  for directory in (job,b/'rca_checks',b/'audit'):
   for f in directory.rglob('*'):
    if f.is_file() and f.suffix not in ('.vvp',):z.write(f,f.relative_to(b).as_posix())
 result['report_zip']={'path':str(reports),'sha256':hashlib.sha256(reports.read_bytes()).hexdigest()}
 (a.root/'delivery'/(id+'_manifest.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
 results.append(result)
 print(json.dumps({k:result[k] for k in ('run_id','BUILD_PASS','states','source_commit','timing','resources','bit','source_zip','timing_coverage')},indent=2))
(a.root/'delivery/BUILD_RESULTS.json').write_text(json.dumps(results,indent=2))
