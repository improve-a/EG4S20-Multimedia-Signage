import pathlib, zipfile, hashlib, json, subprocess
r=pathlib.Path('D:/FPGA/EG4S20-Multimedia-Signage')
zpath=r/'artifacts/timing_fix_20261016_02_source.zip'
assert hashlib.sha256(zpath.read_bytes()).hexdigest()=='2923dfe9667f1cb1472c87ae52e47fae743dda64054cb1978578decc2a4d84c3'
with zipfile.ZipFile(zpath) as z:
 m=json.loads(z.read('audit/baseline_manifest.json'))
 for row in m['selected']:
  assert hashlib.sha256(z.read('work/design/'+row['path'])).hexdigest()==row['sha256'],row['path']
 print('VERIFIED',len(m['selected']),m['git_commit'])
 print('TOP',z.read('work/design/user_source/hdl_source/top_tf_hdmi_audio.v').decode()[-8500:])
 print('HARNESS',z.read('harness/build.tcl').decode())
 print('FILES',z.namelist())
