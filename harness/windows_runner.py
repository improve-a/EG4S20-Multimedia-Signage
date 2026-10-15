"""Mac-side SSH runner: explicit launch/status/collect; no automatic build retries."""
import argparse,base64,json,pathlib,re,subprocess,sys
ROOT=r'D:\FPGA\hx4s20_extensions_20261013'
PYTHON=r'D:\python3.12.3\python.exe'
def remote_python(code,timeout=45):
 p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','thinkpad',PYTHON+' -X utf8 -'],input=('import sys;sys.stdout.reconfigure(encoding="utf-8")\n'+code).encode(),capture_output=True,timeout=timeout)
 if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace'))
 return p.stdout.decode('utf-8')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('action',choices=['status','collect','launch','prepare']);ap.add_argument('run_id');ap.add_argument('--root',default=ROOT);ap.add_argument('--output',default='reports/builds');ap.add_argument('--timeout',type=int,default=3600);a=ap.parse_args()
 if not re.fullmatch(r'[A-Za-z0-9_-]+',a.run_id):ap.error('Invalid run id')
 if a.action=='prepare':
  code=f'import sys;sys.path.insert(0,{str(pathlib.PureWindowsPath(a.root)/"harness")!r})\nfrom prepare import prepare\nimport json;print(json.dumps(prepare({a.root!r},{a.run_id!r})))'
  print(remote_python(code));return
 if a.action=='launch':
  # Refuse reusing a populated TD run tree: a new run id alone does not remove stale design products.
  script=f'''$ErrorActionPreference='Stop'
$root='{a.root.replace(chr(39),chr(39)*2)}'
if(Test-Path -LiteralPath ($root+'\\runs\\{a.run_id}')){{throw 'Run id already exists'}}
$old=Get-ChildItem -LiteralPath ($root+'\\work\\design\\td_project\\hx4s20_basic_Runs') -Recurse -Force -File | Where-Object {{$_.Name -match '^\\..*\\.(begin|end|error)\\.f$|\\.(db|bit)$'}}
if($old){{throw 'Existing build products: prepare a fresh workspace; do not overwrite baseline'}}
$cmd='"{PYTHON}" "'+$root+'\\harness\\windows_job.py" --root "'+$root+'" --run-id {a.run_id} --timeout {min(max(a.timeout,1),3600)}'
$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{{CommandLine=$cmd;CurrentDirectory=$root}}
$r | Select-Object ReturnValue,ProcessId | ConvertTo-Json
if($r.ReturnValue -ne 0){{throw 'Detached launch failed'}}
'''
  b=base64.b64encode(script.encode('utf-16le')).decode()
  p=subprocess.run(['ssh','-o','BatchMode=yes','thinkpad','powershell.exe -NoProfile -NonInteractive -EncodedCommand '+b],capture_output=True,timeout=30)
  print(p.stdout.decode(errors='replace'))
  if p.stderr:print(p.stderr.decode(errors='replace'),file=sys.stderr)
  sys.exit(p.returncode)
 code=f'import pathlib,json,zipfile\nr=pathlib.Path({a.root!r});j=r/"runs"/{a.run_id!r}\n'
 if a.action=='status':
  code+='print((j/"status.json").read_text());print((j/"stages.tsv").read_text() if (j/"stages.tsv").exists() else "NO_STAGE_EVENTS")\n'
  print(remote_python(code));return
 code+='''s=json.loads((j/'status.json').read_text())
if s['state'] in ['RUNNING','STARTING']:raise RuntimeError('Wait for build completion before final collection')
z=r/'audit'/(j.name+'_evidence.zip')
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as out:
 for base in [j,r/'work/design/td_project']:
  for f in base.rglob('*'):
   if not f.is_file():continue
   # Large vendor databases stay on Windows; their hashes remain in artifacts.json.
   if f.suffix.lower() in ['.db','.v','.sv','.vo']:continue
   if f.stat().st_size>30*1024*1024:continue
   out.write(f,str(f.relative_to(r)))
print(json.dumps({'archive':str(z),'bytes':z.stat().st_size}))
'''
 info=json.loads(remote_python(code));out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
 archive=out/(a.run_id+'_evidence.zip')
 subprocess.run(['scp','thinkpad:'+info['archive'].replace('\\','/'),str(archive)],check=True)
 import zipfile
 with zipfile.ZipFile(archive) as z:z.extractall(out/a.run_id)
 print(out/a.run_id)
if __name__=='__main__':main()
