"""Real RTL query regression against an independent CSS Bezier oracle."""
import csv,hashlib,json,math,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/ext/html_rom16.v','rtl/ext/html_scene_motion.v','tests/html_scene_motion_tb.v']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cubic(u,a,b):return 3*(1-u)**2*u*a+3*(1-u)*u*u*b+u**3
def oracle_ease(x,points):
 if x<=0:return 0.0
 if x>=1:return 1.0
 a,b,c,d=points;u=x
 for _ in range(80):
  error=cubic(u,a,c)-x
  if abs(error)<1e-14:break
  slope=3*(1-u)**2*a+6*(1-u)*u*(c-a)+3*u*u*(1-c)
  candidate=u-error/slope if slope>1e-12 else -1
  if not 0<=candidate<=1:
   lo=0.;hi=1.
   for _ in range(60):
    mid=(lo+hi)/2
    if cubic(mid,a,c)<x:lo=mid
    else:hi=mid
   u=(lo+hi)/2;break
  u=candidate
 return cubic(u,b,d)
def ideal(row):
 age=row['age'];kind=row['kind'];old=row['old'];reverse=row['reverse'];index=row['index'];t=age*21/1250
 if age>=93:return (0.,0.,4096.,4096.,0. if old else 255.)
 if kind==0:return (0.,0.,4096.,4096.,255.)
 if old:
  duration=.45 if kind==3 else 1.05
  q=oracle_ease(t/duration,(.7,0,.84,0) if kind==3 else (.76,0,.24,1))
  return (-256*(10 if kind==3 else 46)*q,0.,4096.,4096.,255*(1-q if kind==3 else 1-.75*q))
 if kind==1:
  q=oracle_ease(t/1.5,(.16,1,.3,1));s=1-.035*(1-q)
  return ((-1 if reverse else 1)*70*256*(1-q),0.,4096*s,4096/s,255*q)
 if kind==2:
  q=oracle_ease(t/1.7,(.16,1,.3,1));return (120*256*(1-q),0.,4096.,4096.,255.)
 q=oracle_ease((t-.38-.07*index)/.9,(.16,1,.3,1));return (0.,14*256*(1-q),4096.,4096.,255*q)
def main():
 out=ROOT/'output/html_fidelity/scene_motion'/('run_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
 files=SOURCES+[str(x.relative_to(ROOT)) for x in (ROOT/'rtl/ext/html_assets').glob('html_motion*.hex')]
 for name in files:
  dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 report={'state':'RUNNING','snapshot':str(out),'started':time.time(),'sources':{n:digest(ROOT/n) for n in files},'steps':[]}
 def save():
  data=json.dumps(report,indent=2);(out/'verification.json').write_bytes(data.encode());(out.parent/'verification.json').write_bytes(data.encode())
 save()
 commands=[('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','html_scene_motion_tb','-o','sim.vvp']+SOURCES),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]
 for name,cmd in commands:
  t=time.time()
  with (out/(name+'.log')).open('w') as log:
   child=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'pid':child.pid,'command':cmd};report['steps'].append(step);save()
   code=child.wait(timeout=60)
  step.update(exit_code=code,wall_seconds=time.time()-t);save()
  if code:raise RuntimeError((out/(name+'.log')).read_text())
 rows=[{k:int(v) for k,v in row.items()} for row in csv.DictReader((out/'motion_actual.csv').open())]
 if len(rows)!=5654:raise ValueError(len(rows))
 maximum=[0.]*5;fields=['x_q8','y_q8','scale_q12','inverse_q12','alpha'];limits=[.501,.501,.501,1.1,.501]
 for row in rows:
  expected=ideal(row)
  for i,key in enumerate(fields):
   error=abs(row[key]-expected[i]);maximum[i]=max(maximum[i],error)
   if error>limits[i]:raise AssertionError((row,key,expected[i],error))
 report.update(state='UNIT_SIM_PASS',queries=len(rows),oracle='Independent Newton/root-solve CSS cubic Bezier;16.8ms frame sampling;JS cleanup atfirstage93',maximum_error_in_fixed_point_LSB=dict(zip(fields,maximum)),limits_in_LSB=dict(zip(fields,limits)),wall_seconds=time.time()-report['started'])
 save();print(json.dumps(report,indent=2));print((out/'simulation.log').read_text())
if __name__=='__main__':main()
