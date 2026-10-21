"""Collect one candidate build without modifying any frozen artifact."""
from pathlib import Path
import collections,hashlib,importlib.util,json,re,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]
RID='probe_osd_1x_001'
BASE=ROOT/'output/html_fidelity/builds'/RID
OLD=Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def loadparser():
 s=importlib.util.spec_from_file_location('parser',ROOT/'harness/report_parser.py')
 m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
parser=loadparser();result=parser.parse(BASE,RID);baseline=parser.parse(OLD,'hdmi_probe_001')
job=BASE/'runs'/RID;oldjob=OLD/'runs/hdmi_probe_001'
timing=(job/'final_timing.rpt').read_text()
detail=collections.defaultdict(list)
for value,kind in re.findall(r'Slack\s*:\s*(-?[\d.]+)ns(?:(?!Slack).)*?Check Type\s*:\s*(\w+)',timing,re.S):
 detail[kind.lower()].append(float(value))
viol=[int(x) for x in re.findall(r'(\d+) Viol Endpoints',timing)]
result['reported_path_min_ns']={k:min(v) for k,v in detail.items()}
result['reported_path_count']={k:len(v) for k,v in detail.items()}
result['group_violation_counts']=viol
result['STA_CONSTRAINED_PATHS_PASS']=bool(viol) and not any(viol) and all(k in detail and min(detail[k])>=0 for k in ['setup','hold','recovery','removal']) and all(result['timing'].get(k,{}).get('tns_ns',-1)==0 for k in ['setup','hold']) and 'Check Corner        : Both (Slow and Fast)' in timing
result['FULL_INTERFACE_SIGNOFF']='NOT_VERIFIED; inherited external-I/O/CDC coverage limitations; no new exceptions'
def resources(path):
 return {k:int(v) for k,v in re.findall(r'^\s*#(lut|reg|bram9k|bram32k|dsp|pll)\s+(\d+)',path.read_text(),re.M)}
before=resources(oldjob/'final_area.rpt');after=resources(job/'final_area.rpt')
result['resource_comparison']={k:{'baseline':before[k],'candidate':after[k],'delta':after[k]-before[k]} for k in before}
result['baseline_warning_counts']=baseline['warning_counts']
result['timing_checks_unchanged']=result['timing_coverage']['checks']==baseline['timing_coverage']['checks']
result['baseline_coverage']=baseline['timing_coverage']
manifest=json.loads((BASE/'audit/baseline_manifest.json').read_text())
verified=[]
for rel in ['media_controls.v','ext/html_video_overlay.v','ext/html_osd_overlay.v','ext/html_assets/html_osd_swap_font.hex','ext/html_assets/html_osd_swap_font.hex.bin','top_tf_hdmi_audio.v']:
 live=(ROOT/'rtl'/rel).read_bytes()
 if rel.endswith('.v'):live=live.replace(b'rtl/ext/html_assets/',(BASE.as_posix()+'/work/design/user_source/hdl_source/ext/html_assets/').encode())
 snap=BASE/'work/design/user_source/hdl_source'/rel
 assert hashlib.sha256(live).hexdigest()==sha(snap),rel
 verified.append({'path':rel,'snapshot_sha256':sha(snap)})
result['verified_snapshot_inputs']=verified
result['build_source_commit']=manifest['git_commit']
result['candidate_classification']='NEW_CANDIDATE / HARDWARE_NOT_TESTED'
dest=ROOT/'output/probe_osd_1x/delivery';dest.mkdir(parents=True,exist_ok=False)
bit=BASE/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
assert result['BUILD_PASS'],result['states']
target=dest/'probe_osd_1x_001_NEW_CANDIDATE_HARDWARE_NOT_TESTED.bit'
shutil.copy2(bit,target)
result['candidate_bit']={'path':str(target),'bytes':target.stat().st_size,'sha256':sha(target)}
source=ROOT/'artifacts'/f'{RID}_source.zip'
result['candidate_source_zip']={'path':str(source),'sha256':sha(source)}
# All original logs remain in the isolated build. The delivery ZIP also retains
# routed reports and fresh run logs, but does not duplicate large databases.
archive=dest/f'{RID}_reports.zip'
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED) as z:
 for p in job.iterdir():
  if p.is_file() and p.suffix in ('.rpt','.log','.tsv','.json','.tcl'):z.write(p,'build/'+p.name)
 for run in ('syn_1','phy_1'):
  p=BASE/'work/design/td_project/hx4s20_basic_Runs'/run/'run.log'
  z.write(p,f'build/{run}_run.log')
 for p in (ROOT/'output/probe_osd_1x').glob('*.json'):z.write(p,'audit/'+p.name)
 for p in (ROOT/'output/probe_osd_1x').glob('*.log'):z.write(p,'audit/'+p.name)
 for folder in [ROOT/'output/probe_osd_default_1x',ROOT/'output/html_fidelity/no_bot/verify',ROOT/'output/html_fidelity/osd_swap']:
  for p in folder.rglob('*'):
   if p.is_file() and p.suffix in ('.log','.json'):z.write(p,'regression/'+p.relative_to(ROOT/'output').as_posix())
 z.write(BASE/'audit/baseline_manifest.json','audit/build_source_manifest.json')
result['reports_zip']={'path':str(archive),'sha256':sha(archive)}
(dest/'RESULT.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
