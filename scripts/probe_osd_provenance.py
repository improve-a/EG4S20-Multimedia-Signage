"""Read-only comparison to the accepted Probe source archive and frozen bit."""
from pathlib import Path
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[1]
FROZEN=Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/hdmi_probe/delivery')
def sha(b):return hashlib.sha256(b).hexdigest()
expected={
 'user_source/hdl_source/media_controls.v',
 'user_source/hdl_source/ext/html_osd_overlay.v',
 'user_source/hdl_source/ext/html_video_overlay.v',
 'user_source/hdl_source/ext/html_assets/html_osd_swap_font.hex',
 'user_source/hdl_source/ext/html_assets/html_osd_swap_font.hex.bin',
}
def normalized(b):
 b=b.replace(b'\r\n',b'\n')
 b=re.sub(rb'D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001/work/design/user_source/hdl_source/ext/html_assets/',b'rtl/ext/html_assets/',b)
 b=re.sub(rb'(<Project Version="3" Minor="2" Path=")[^"]*',rb'\1PROJECT_ROOT',b)
 return b
archive=FROZEN/'hdmi_probe_001_source.zip'
assert sha(archive.read_bytes())=='5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f'
assert sha((FROZEN/'hdmi_probe_001.bit').read_bytes())=='bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618'
changed=[];unchanged=[];missing=[]
with zipfile.ZipFile(archive) as z:
 m=json.loads(z.read('audit/baseline_manifest.json'))
 for row in m['selected']:
  n=row['path'];old=z.read('work/design/'+n)
  assert sha(old)==row['sha256']
  if n.endswith('.log'):continue
  rel='rtl/'+n[len('user_source/hdl_source/'):] if n.startswith('user_source/hdl_source/') else 'project/'+n
  p=ROOT/rel
  if not p.exists():missing.append(rel);continue
  (unchanged if normalized(old)==normalized(p.read_bytes()) else changed).append(n)
 old=[int(v,16) for v in z.read('work/design/user_source/hdl_source/ext/html_assets/html_osd_swap_font.hex').split()]
 new=[int(v,16) for v in (ROOT/'rtl/ext/html_assets/html_osd_swap_font.hex').read_bytes().split()]
 assert len(old)==len(new)==1024 and old[:751]==new[:751]
out=ROOT/'output/probe_osd_1x';out.mkdir(parents=True,exist_ok=True)
r={'frozen_bit_sha256':sha((FROZEN/'hdmi_probe_001.bit').read_bytes()),'frozen_source_sha256':sha(archive.read_bytes()),'build_source_commit':m['git_commit'],'unchanged_inputs':unchanged,'changed_inputs':changed,'missing':missing,'palette_and_original_font_unchanged':True,'unexpected':sorted(set(changed)-expected),'expected_but_unchanged':sorted(expected-set(changed))}
(out/'provenance.json').write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))
assert not missing and set(changed)==expected
