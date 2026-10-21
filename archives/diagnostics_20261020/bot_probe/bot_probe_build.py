"""Windows-only controlled Bot + proven Probe experiment. No hardware writes."""
import argparse, base64, datetime, difflib, hashlib, json, pathlib, re, subprocess, sys, zipfile
R=pathlib.Path(__file__).resolve().parents[1]
BASE=pathlib.Path('D:/FPGA/EG4S20-Multimedia-Signage/artifacts/timing_fix_20261016_02_source.zip')
PROBE=pathlib.Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/artifacts/hdmi_probe_001_source.zip')
ID='bot_hdmi_probe_001'
D=R/'output/html_fidelity/builds'/ID
def sha(b): return hashlib.sha256(b).hexdigest()
def load(p,h):
 assert sha(p.read_bytes())==h,str(p)
 with zipfile.ZipFile(p) as z: f={n:z.read(n) for n in z.namelist() if not n.endswith('/')}
 m=json.loads(f['audit/baseline_manifest.json'])
 for row in m['selected']: assert sha(f['work/design/'+row['path']])==row['sha256'],row['path']
 return f,m
def main():
 a=argparse.ArgumentParser();a.add_argument('action',choices=['prepare','run']);x=a.parse_args()
 if x.action=='run':
  busy=subprocess.run(['powershell','-NoProfile','-Command','Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'],capture_output=True)
  assert not busy.stdout.strip(),busy.stdout
  command=subprocess.list2cmdline([sys.executable,'-X','utf8',str(D/'harness/windows_job.py'),'--root',str(D),'--run-id',ID,'--timeout','3600'])
  ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+command.replace("'","''")+"';CurrentDirectory='"+str(D)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json; if($r.ReturnValue -ne 0){exit 1}"
  launch=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True,check=True)
  (D/'audit/dispatch.log').write_bytes(launch.stdout+launch.stderr)
  pid=json.loads(launch.stdout.decode('utf-8-sig'))['ProcessId'];print('SUPERVISOR',pid,flush=True)
  subprocess.run(['powershell','-NoProfile','-Command',f'$p=Get-Process -Id {pid} -ErrorAction SilentlyContinue; if($p){{$p | Wait-Process -Timeout 3700 -ErrorAction Stop}}'],check=True)
  state=json.loads((D/'runs'/ID/'status.json').read_text(encoding='utf-8'))
  print(json.dumps(state,indent=2),flush=True)
  if state['state']!='FINISHED':raise SystemExit(1)
  return
 assert not D.exists(),'No overwrites'
 f,m=load(BASE,'2923dfe9667f1cb1472c87ae52e47fae743dda64054cb1978578decc2a4d84c3')
 p,pm=load(PROBE,'5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f')
 original=dict(f)
 top='work/design/user_source/hdl_source/top_tf_hdmi_audio.v'
 text=f[top].decode().replace('\r\n','\n'); pt=p[top].decode().replace('\r\n','\n')
 old_start=text.index('seg_decoder seg_decoder_m0(')
 old_end=text.index('\n);',text.index('seg_scan seg_scan_m0(',old_start))+3
 new_start=pt.index('// Read-only video-clock probes;')
 new_end=pt.index('\n);',pt.index('seg_scan seg_scan_m0(',new_start))+3
 replacements=[(text[old_start:old_end],pt[new_start:new_end]),('wire        axis_s_ready;','wire        axis_s_ready;\nwire        probe_video_locked;'),('.O_video_locked     ()','.O_video_locked     (probe_video_locked)')]
 for old,new in replacements:
  assert text.count(old)==1,old
  text=text.replace(old,new)
 f[top]=text.encode()
 probe='work/design/user_source/hdl_source/ext/hdmi_probe.v';f[probe]=p[probe]
 al='work/design/td_project/hx4s20_basic.al';t=f[al].decode().replace('\r\n','\n')
 order=1+max(map(int,re.findall(r'Name="CompileOrder" Val="(\d+)"',t)))
 entry=re.search(r'            <File Path="../user_source/hdl_source/ext/hdmi_probe.v">.*?</File>',p[al].decode(),re.S).group()
 entry=re.sub(r'Name="CompileOrder" Val="\d+"',f'Name="CompileOrder" Val="{order}"',entry)
 t=t.replace('        </Verilog>',entry+'\n        </Verilog>');f[al]=t.encode()
 oldroot=b'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02'
 changes=[];diff=[]
 for k,v in f.items():
  if not k.startswith('work/design/'):continue
  old=original.get(k,b'')
  if old!=v:
   changes.append(k)
   diff.extend(difflib.unified_diff(old.decode().splitlines(True),v.decode().splitlines(True),fromfile='bot/'+k,tofile='bot_probe/'+k))
 assert set(changes)=={top,probe,al},changes
 for k,v in list(f.items()):
  if k.startswith('work/design/') and k.endswith(('.v','.sv','.al')):f[k]=v.replace(oldroot,D.as_posix().encode())
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
 status=subprocess.check_output(['git','status','--short'],cwd=R,text=True).strip();assert not status,status
 selected=[dict(path=k[len('work/design/'):],sha256=sha(v),bytes=len(v)) for k,v in sorted(f.items()) if k.startswith('work/design/')]
 audit=dict(baseline_commit='20871da98664b2b674fbcfe94a713359ff9614a1',baseline_zip_sha256=sha(BASE.read_bytes()),probe_delivery='42de1dbe4a20ca78f28be54c4bf41bd0dd814481',probe_zip_sha256=sha(PROBE.read_bytes()),git_commit=commit,changes=changes,signal_adaptations=[],probe_sha256=sha(f[probe]),relocation_only=oldroot.decode())
 m.update(task_root=str(R/'output/html_fidelity'),run_id=ID,git_commit=commit,git_branch='codex/bot-hdmi-probe-20261020',git_status=[],selected=selected,snapshot_sha256=sha(json.dumps(selected,sort_keys=True).encode()),experiment=audit)
 f['audit/baseline_manifest.json']=json.dumps(m,indent=2).encode()
 f['audit/bot_probe_audit.json']=json.dumps(audit,indent=2).encode()
 f['audit/probe_only.diff']=''.join(diff).encode()
 out=R/'artifacts'/(ID+'_source.zip');out.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED) as z:
  for k,v in f.items():z.writestr(k,v)
 D.mkdir(parents=True)
 with zipfile.ZipFile(out) as z:z.extractall(D)
 (D/'audit/package_sha256.txt').write_text(sha(out.read_bytes()))
 (D/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)
 (R/'output/html_fidelity/audit').mkdir(parents=True,exist_ok=True)
 print(json.dumps(audit,indent=2));print('PACKAGE',out,sha(out.read_bytes()))
if __name__=='__main__':main()
