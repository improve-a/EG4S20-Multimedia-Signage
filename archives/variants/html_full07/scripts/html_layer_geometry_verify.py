from pathlib import Path
import argparse,datetime,hashlib,json,os,subprocess,sys,time
ap=argparse.ArgumentParser(description='Finite layer geometry: source-derived fixed-point address/alpha oracle and CSS-verified motion tables; not whole-system simulation')
ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--run-id',default=datetime.datetime.now(datetime.timezone.utc).strftime('geometry_%Y%m%dT%H%M%S%fZ'));ap.add_argument('--frontend',type=Path);a=ap.parse_args()
if not a.run_id or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in a.run_id):ap.error('Invalid run-id')
r=a.root.resolve();d=r/'rtl/ext/html_assets';out=r/'output/html_fidelity/page_control'/a.run_id;out.mkdir(parents=True,exist_ok=False);started=time.monotonic();rom=[int(x,16) for x in (d/'html_layer_descriptors.hex').read_text().split()];offset=[int(x,16) for x in (d/'html_motion_offset.hex').read_text().split()];scales=[int(x,16) for x in (d/'html_motion_alpha_scale.hex').read_text().split()];bases=[0,275200,586240,890880,1202688,1514240]
def signed(v,n):return v-(1<<n) if v>>(n-1) else v
def spans(page,age,rev,old,y):
 result=[]
 for c in range(16):
  w=rom[(page*16+c)*8:(page*16+c+1)*8];role=w[0]&255
  if role==255:continue
  kind=1 if role in(2,3) else 2 if role==1 else 3 if role==4 else 0;i=(w[0]>>8)&255
  tx=ty=0;inv=4096;alpha=0 if old and age>=93 else 255
  if age<93 and kind:
   bank=(3 if kind==3 else 2) if old else (0 if kind==1 else 1 if kind==2 else 4+i);v=offset[bank*128+age];a=scales[bank*128+age];alpha=a>>8
   if kind==3 and not old:ty=signed(v&8191,13)
   else:tx=signed(v,16)*(-1 if kind==1 and not old and rev else 1)
   if kind==1 and not old:inv=((1<<24)+(4096-(a&255))//2)//(4096-(a&255))
  cx=signed(w[1]&65535,16);cy=signed(w[1]>>16,16);ww=w[2]&65535;hh=w[2]>>16;px=signed(w[4]&65535,16);py=signed(w[4]>>16,16)
  if kind==1 and inv!=4096:
   sy=((py<<15)+((y<<7)-(py<<3)-(ty>>1))*inv)>>19;origin=(px<<12)+((-(px<<3)-(tx>>1))*inv>>3);step=inv<<4
  else:sy=(y*256-ty)>>8;origin=-tx*256;step=65536
  if alpha and ww and hh and 0<=sy-cy<hh:result.append((cx,ww,bases[page]+w[3]+(sy-cy)*ww,origin,step,alpha))
 if len(result)>4:raise ValueError(('morethan4',page,age,rev,old,y,len(result)))
 return result
cases=[]
rows=[88,195,294,334,350,459]
for cur in range(6):
 for old in range(6):
  if old==cur:continue
  for rev in (0,1):
   for row in rows:cases.append((cur,old,25,rev,row))
for cur in range(6):
 for rev in (0,1):
  old=(cur+(1 if rev else 5))%6
  for age in(0,16,66,92,93):
   for row in rows:cases.append((cur,old,age,rev,row))
headers=[];gold=[]
for cur,old,age,rev,y in cases:
 headers.append((cur<<20)|(old<<17)|(age<<10)|(rev<<9)|y)
 for isold,page in[(0,cur),(1,old)]:
  ss=spans(page,age,rev,isold,y)
  for x in range(640):
   aa=[];alph=[]
   for cx,ww,base,origin,step,alpha in ss:
    sx=(origin+x*step)>>16
    if cx<=sx<cx+ww:aa.append(base+sx-cx);alph.append(alpha)
   if len(aa)>2:raise ValueError(('morethan2',cur,old,age,rev,y,x))
   n=len(aa);aa+=[0]*(2-n);alph+=[255]*(2-n);gold.append((n<<58)|(aa[0]<<37)|(aa[1]<<16)|(alph[0]<<8)|alph[1])
(out/'cases.hex').write_text(''.join(f'{v:06x}\n' for v in headers));(out/'gold.hex').write_text(''.join(f'{v:015x}\n' for v in gold));(out/'fixture_manifest.json').write_text(json.dumps({'scope':'All30orderedpagepairs age25 plus6adjacentpairs ages0,16,66,92,93 bothdirections sixcriticalrows; independentlycomputed64bitinversegeometry using CSS-verifiedmotiontables','cases':len(cases),'pixels':len(gold)},indent=2))

frontend=a.frontend.resolve() if a.frontend else r/'rtl/ext/html_layer_span_frontend.v'
sources=[r/'tests/html_layer_geometry_tb.v',frontend]+[r/f for f in ['rtl/ext/html_layer_descriptor_rom.v','rtl/ext/html_layer_line_setup.v','rtl/ext/html_scene_motion.v','rtl/ext/html_rom16.v']]
inputs=[d/f for f in ['html_layer_descriptors.hex','html_layer_descriptors16.hex','html_motion_offset.hex','html_motion_alpha_scale.hex']]+[Path(__file__).resolve(),r/'harness/test_runner.py']
report={'UNIT_SIM':'RUNNING','FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_VERIFIED','pid':os.getpid(),'python':sys.version,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in sources+inputs},'fixture_scope':json.loads((out/'fixture_manifest.json').read_text())}
cmd=[sys.executable,str(r/'harness/test_runner.py'),'--top','html_layer_geometry_tb','--output',str(out/'simulation'),'--cwd',str(r),'--sim-timeout','600','--parameter',f'html_layer_geometry_tb.CASE_COUNT={len(cases)}','--parameter','html_layer_geometry_tb.FIXTURE_ROOT="'+out.as_posix()+'"']+[str(f) for f in sources]
report['command']=cmd
with (out/'runner.log').open('wb') as log:
 p=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT);report['simulation_pid']=p.pid;report['exit']=p.wait()
q=out/'simulation/result.json';report['result']=json.loads(q.read_text()) if q.exists() else {'SIM':'MISSING'};report['UNIT_SIM']='PASS' if report['exit']==0 and report['result'].get('SIM')=='PASS' else 'FAIL';report['wall_seconds']=time.monotonic()-started;(out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps({'UNIT_SIM':report['UNIT_SIM'],'cases':len(cases),'pixels':len(gold),'exit':report['exit'],'evidence':str(out)}));raise SystemExit(0 if report['UNIT_SIM']=='PASS' else 1)
