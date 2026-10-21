import sys
sys.path.insert(0,'harness')
from windows_runner import remote_python
print(remote_python(r"""
from pathlib import Path
import zipfile,difflib,hashlib,json,pprint,runpy,datetime
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');p=r/'scripts/apply_html_integration.py';s=p.read_text(encoding='utf-8')
manifest={v['path']:v['sha256'] for v in json.loads((r/'docs/local_dependencies.json').read_text())['dependencies']}
files={};checks=[]
with zipfile.ZipFile(r/'output/html_fidelity/integration_baseline.zip') as z:
 for name in ['rtl/top_tf_hdmi_audio.v','rtl/SD/frame_fifo_write.v','rtl/SD/bmp_read.v']:
  baseline=z.read(name);sha=hashlib.sha256(baseline).hexdigest();assert sha==manifest[name],(name,sha,manifest[name])
  before=baseline.decode('utf-8').replace('\r\n','\n');after=(r/name).read_text(encoding='utf-8');a=before.splitlines(keepends=True);b=after.splitlines(keepends=True)
  edits=[dict(start=i,end=j,old=a[i:j],new=b[k:l]) for tag,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes() if tag!='equal']
  files[name]=dict(baseline_sha256=sha,baseline_text_sha256=hashlib.sha256(before.encode()).hexdigest(),result_text_sha256=hashlib.sha256(after.encode()).hexdigest(),edits=edits)
 s=s[:s.index('FILES=')]+'FILES='+pprint.pformat(files,width=110,sort_dicts=False)+'\n\n'+s[s.index('def digest'):]
 s=s.replace('top-level and linear-write integration','top-level, linear-write and tagged BMP integration');p.write_bytes(s.encode('utf-8'))
 api=runpy.run_path(str(p))
 for name in files:
  orig=z.read(name).decode('utf-8');new,changed=api['apply_text'](name,orig);assert changed and new==(r/name).read_text(encoding='utf-8')
  again,changed=api['apply_text'](name,new);assert not changed and again==new
  try:api['apply_text'](name,orig+'// external change\n')
  except ValueError:pass
  else:raise AssertionError('accepted outside edits')
  checks.append(dict(path=name,baseline_rebuild='PASS',idempotence='PASS',foreign_edit_rejection='PASS',sha256=files[name]['result_text_sha256']))
output=r/'output/html_fidelity/verification/integration_replay_v4.json';assert not output.exists();output.write_text(json.dumps(checks,indent=2),encoding='utf-8');print(json.dumps(checks))
""",timeout=60))
