#!/usr/bin/env python3
"""Snapshot selected inputs, execute existing Windows Icarus, preserve evidence."""
import argparse,datetime,hashlib,json,pathlib,re,subprocess,time,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
REMOTE='D:/FPGA/hx4s20_extensions_20261013'
PYTHON=r'D:\python3.12.3\python.exe'
def remote(code,timeout=60):
    p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','thinkpad',PYTHON+' -X utf8 -'],input=code.encode(),capture_output=True,timeout=timeout)
    if p.returncode: raise RuntimeError(p.stderr.decode(errors='replace')+p.stdout.decode(errors='replace'))
    return p.stdout.decode('utf-8')
def main():
    a=argparse.ArgumentParser();a.add_argument('run_id');a.add_argument('top');a.add_argument('sources',nargs='+');a.add_argument('--data',action='append',default=[]);a.add_argument('--timeout',type=int,default=120);a.add_argument('--language',default='2012');a.add_argument('--parameter',action='append',default=[]);x=a.parse_args()
    assert re.fullmatch('[A-Za-z0-9_-]+',x.run_id)
    out=ROOT/'evidence/sim'/x.run_id;out.mkdir(parents=True,exist_ok=False)
    files=x.sources+x.data+['harness/test_runner.py'];manifest={}
    with zipfile.ZipFile(out/'inputs.zip','x',zipfile.ZIP_DEFLATED) as z:
        for name in files:
            p=(ROOT/name).resolve();p.relative_to(ROOT)
            content=p.read_bytes();z.writestr(name,content);manifest[name]=hashlib.sha256(content).hexdigest()
    (out/'inputs.json').write_text(json.dumps(manifest,indent=2))
    target=REMOTE+'/sim/'+x.run_id
    start=time.monotonic()
    print(remote(f'from pathlib import Path\np=Path({target!r});p.mkdir(parents=True,exist_ok=False)\nprint(p)'))
    subprocess.run(['scp',str(out/'inputs.zip'),'thinkpad:'+target+'/inputs.zip'],check=True)
    code=f'''import pathlib,zipfile,subprocess,json,sys
p=pathlib.Path({target!r})
with zipfile.ZipFile(p/'inputs.zip') as z:z.extractall(p)
cmd=[sys.executable,str(p/'harness/test_runner.py'),'--top',{x.top!r},'--output',str(p/'result'),'--cwd',str(p),'--sim-timeout',{str(x.timeout)!r},'--language',{x.language!r}]+[y for v in {x.parameter!r} for y in ['--parameter',v]]+[str(p/n) for n in {x.sources!r}]
r=subprocess.run(cmd,capture_output=True,cwd=p,timeout={x.timeout+130})
print(r.stdout.decode(errors='replace'));print(r.stderr.decode(errors='replace'))
with zipfile.ZipFile(p/'results.zip','w',zipfile.ZIP_DEFLATED) as z:
 for f in (p/'result').glob('*'):
  if f.is_file() and f.suffix not in ['.vvp','.vcd']:z.write(f,'result/'+f.name)
 for f in p.glob('*.out'):
  z.write(f,f.name)
print('REMOTE_TEST_EXIT='+str(r.returncode))
'''
    text=remote(code,x.timeout+160);(out/'dispatch.txt').write_text(text);print(text)
    subprocess.run(['scp','thinkpad:'+target+'/results.zip',str(out/'results.zip')],check=True)
    with zipfile.ZipFile(out/'results.zip') as z:z.extractall(out)
    (out/'dispatch.json').write_text(json.dumps(dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),wall_seconds=time.monotonic()-start,top=x.top,sources=manifest,remote=target),indent=2))
    for f in (out/'result').glob('*.log'):print(f.name+':\n'+f.read_text(errors='replace')[-6000:])
    match=re.search('REMOTE_TEST_EXIT=(\\d+)',text)
    return int(match[1]) if match else 2
if __name__=='__main__':raise SystemExit(main())
