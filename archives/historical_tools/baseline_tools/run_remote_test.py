import argparse,pathlib,sys,json,time
sys.path.insert(0,str(pathlib.Path(__file__).parent/'harness'))
from windows_runner import remote_python
p=argparse.ArgumentParser();p.add_argument('run_id');p.add_argument('top');p.add_argument('sources',nargs='+');p.add_argument('--timeout',type=int,default=120);p.add_argument('--language',choices=['2005','2012'],default='2012');p.add_argument('--parameter',action='append',default=[]);a=p.parse_args()
root=r'D:\FPGA\hx4s20_contest1_20261013';local=pathlib.Path(__file__).resolve().parent.parent
code=f'''import pathlib,subprocess,json,sys
r=pathlib.Path({root!r});out=r/'reports/sim'/{a.run_id!r}
cmd=[sys.executable,str(r/'harness/test_runner.py'),'--top',{a.top!r},'--output',str(out),'--cwd',str(r),'--sim-timeout',{str(a.timeout)!r},'--language',{a.language!r}]+[y for x in {a.parameter!r} for y in ['--parameter',x]]+[str(r/x) for x in {a.sources!r}]
p=subprocess.run(cmd,capture_output=True,timeout={a.timeout+130})
print(p.stdout.decode('utf-8',errors='replace'));print(p.stderr.decode('utf-8',errors='replace'))
for name in ['compile.log','simulation.log']:
 f=out/name
 if f.exists():print(name+':\\n'+f.read_text(errors='replace')[-6000:])
print('REMOTE_TEST_EXIT='+str(p.returncode))
'''
t=time.monotonic();text=remote_python(code,timeout=a.timeout+145);print(text)
out=local/'reports/sim';out.mkdir(exist_ok=True);(out/(a.run_id+'.txt')).write_text(text);(out/(a.run_id+'_dispatch.json')).write_text(json.dumps(dict(top=a.top,run_id=a.run_id,wall_seconds=time.monotonic()-t,sources=a.sources,parameters=a.parameter),indent=2))

import re
m=re.search(r'REMOTE_TEST_EXIT=(\d+)',text)
sys.exit(int(m[1]) if m else 2)
