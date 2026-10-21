import pathlib,zipfile,json,hashlib,difflib,subprocess
R=pathlib.Path('D:/FPGA/EG4S20-Bot-HDMIProbe');D=R/'output/html_fidelity/builds/bot_hdmi_probe_001'
O=R/'output/bot_probe_verification';O.mkdir(exist_ok=False)
oldroot=b'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02'
sha=lambda b:hashlib.sha256(b).hexdigest()
with zipfile.ZipFile('D:/FPGA/EG4S20-Multimedia-Signage/artifacts/timing_fix_20261016_02_source.zip') as z:
 with zipfile.ZipFile(R/'artifacts/bot_hdmi_probe_001_source.zip') as n:
  changes=[];same=[];diff=[]
  for k in sorted(set(z.namelist())|set(n.namelist())):
   if not k.startswith('work/design/'):continue
   a=z.read(k) if k in z.namelist() else b'';b=n.read(k)
   b=b.replace(D.as_posix().encode(),oldroot)
   if k.endswith(('.v','.al')):a=a.replace(b'\r\n',b'\n');b=b.replace(b'\r\n',b'\n')
   if a==b:same.append(k)
   else:
    changes.append(k);diff.extend(difflib.unified_diff(a.decode().splitlines(True),b.decode().splitlines(True),fromfile='old/'+k,tofile='new/'+k))
  assert len(changes)==3,changes
  assert all('constraints_source' not in k for k in changes)
  # Non-design harness files used to run TD are exactly inherited.
  for k in z.namelist():
   if k.startswith('harness/'):assert z.read(k)==n.read(k),k
  (O/'normalized_probe_only.diff').write_text(''.join(diff),encoding='utf-8')
steps=[]
for top in ['tb','display_tb']:
 cmds=[['C:/iverilog/bin/iverilog.exe','-g2012','-s',top,'-o',str(O/(top+'.vvp')),'D:/FPGA/EG4S20-NoBot-HDMIProbe/tests/hdmi_probe_tb.v',str(D/'work/design/user_source/hdl_source/ext/hdmi_probe.v'),str(D/'work/design/user_source/hdl_source/video_rgb_to_axis_640x480.v')],['C:/iverilog/bin/vvp.exe',str(O/(top+'.vvp'))]]
 for cmd in cmds:
  p=subprocess.run(cmd,capture_output=True,timeout=90);steps.append(dict(command=cmd,exit=p.returncode,stdout=p.stdout.decode(errors='replace'),stderr=p.stderr.decode(errors='replace')))
  (O/'verification.json').write_text(json.dumps(dict(unchanged=same,changes=changes,tests=steps),indent=2))
  assert p.returncode==0,steps[-1]
print(json.dumps(dict(unchanged_count=len(same),changes=changes,tests=steps),indent=2))
