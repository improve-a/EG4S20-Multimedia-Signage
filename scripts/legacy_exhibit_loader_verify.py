"""Verify actual bounded BMP compositor output against independent coordinate math.
Uses delivered BMP bytes with --media; without it produces declared synthetic BMPs.
"""
import argparse,hashlib,json,os,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def synthetic(width,number):
 data=bytearray(512+width*480*3);data[:2]=b'BM';struct.pack_into('<I',data,2,len(data));struct.pack_into('<I',data,10,512);struct.pack_into('<IiiHHI',data,14,40,width,480,1,24,0)
 for y in range(480):
  for x in range(width):
   pos=512+((479-y)*width+x)*3;data[pos:pos+3]=bytes(((x*3+y*7+number*19)&255,(x+y*5+number*37)&255,(x*7+y+number*53)&255))
 return data
def load(path):
 b=path.read_bytes();w,h=struct.unpack_from('<ii',b,18);off=struct.unpack_from('<I',b,10)[0];assert h==480 and off==512 and len(b)==off+w*h*3
 return b,w
def oracle(left,right,page,dual,zoom,focus):
 d=min(zoom,2)+1;cx,cy=([(435,192) if page==0 else (448,173),(320,240),(160,240),(480,240),(320,120),(320,360)])[focus if focus<6 else 0]
 lb,lw=left;rb,rw=right;result=[]
 for row in range(480):
  sy=479-row if d==1 else (cy*d+(479-row)-240)//d
  for x in range(640):
   sx=x if d==1 else (cx*d+x-320)//d
   b,w=(rb,rw) if dual and sx>=320 else (lb,lw);sx=sx-320 if dual and sx>=320 else sx
   assert 0<=sx<w and 0<=sy<480
   pos=512+((479-sy)*w+sx)*3;blue,green,red=b[pos:pos+3];result.append((red<<16)|(green<<8)|blue)
 return result
def sector_count(page,dual,zoom,focus):
 d=min(zoom,2)+1;cy=([(435,192) if page==0 else (448,173),(320,240),(160,240),(480,240),(320,120),(320,360)])[focus if focus<6 else 0][1]
 ys=set(range(480)) if d==1 else {(cy*d+y-240)//d for y in range(480)};stride=960 if dual else 1920
 return (2 if dual else 1)+sum(((512+(479-y)*stride)%512+stride+511)//512 for y in ys)*(2 if dual else 1)
def main():
 p=argparse.ArgumentParser();p.add_argument('--media',type=Path);p.add_argument('--output',type=Path);p.add_argument('--smoke',action='store_true');p.add_argument('--quick',action='store_true');p.add_argument('--errors-only',action='store_true');p.add_argument('--compare-to',type=Path);a=p.parse_args()
 out=a.output or ROOT/'output/html_fidelity/no_bot/legacy_loader'/('run_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True,exist_ok=False)
 media=a.media or out/'synthetic';media.mkdir(parents=True,exist_ok=True)
 if a.media is None:
  for n in range(1,7):(media/f'UI{n:02}.BMP').write_bytes(synthetic(640,n))
  for n in range(1,5):(media/f'PN{n:02}.BMP').write_bytes(synthetic(320,n+6))
 files={n:media/(n+'.BMP') for n in [*[f'UI{i:02}' for i in range(1,7)],*[f'PN{i:02}' for i in range(1,5)]]}
 parsed={n:load(f) for n,f in files.items()};hexes={}
 for n,(data,w) in parsed.items():
  f=out/(n+'.hex');f.write_bytes(('\n'.join(f'{v:02x}' for v in data)+'\n').encode());hexes[n]=f
 sources=['rtl/ext/legacy_exhibit_loader.v','tests/legacy_exhibit_loader_tb.v'];snap=out/'sources';snap.mkdir()
 for f in sources:(snap/Path(f).name).write_bytes((ROOT/f).read_bytes())
 report={'state':'RUNNING','pid':os.getpid(),'started':time.time(),'scope':'Actual loader RTL output, delivered BMP bytes' if a.media else 'Actual loader RTL output, declared synthetic BMP bytes','sources':{f:sha(ROOT/f) for f in sources},'script_sha256':sha(__file__),'media':{n:{'path':str(f),'sha256':sha(f)} for n,f in files.items()},'steps':[],'compare_to':str(a.compare_to) if a.compare_to else None}
 def save():(out/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
 cases=[(f'page{i}',i,0,0,0,0) for i in range(6)]+[('dual_eagle_phoenix',1,1,0,0,0),('dual_elf_dragon',3,1,0,0,0),('zoom2_focus0',1,0,1,0,0),('zoom3_focus2',2,0,2,2,0),('dual_zoom3_focus1',3,1,2,1,0),('config_latched_focus4',4,0,2,4,9),('zoom2_focus5',5,0,1,5,0),('zoom3_focus3',3,0,2,3,0)]
 if a.smoke:cases=cases[:1]
 elif a.quick:cases=[cases[0],cases[6],cases[8],cases[9],cases[10],cases[11]]
 rejection=[('bad_header_'+str(k),0,0,0,0,1,k) for k in [0,2,10,14,18,22,26,28,30]]+[(n,0,0,0,0,m,28) for n,m in [('short_sector',2),('SD_error',3),('SD_timeout',4),('abort_sector',5),('init_loss_sector',6),('long_sector',7),('ACK_timeout',8),('abort_output',10)]]
 rejection += [('bad_right_header',1,1,0,0,11,28),('abort_with_sector_end',0,0,0,0,12,28),('short_data_sector',0,0,0,0,13,28)]
 if a.errors_only:cases=rejection
 elif not a.smoke:cases+=rejection
 ok=True;iv=Path(r'C:\iverilog\bin\iverilog.exe');vvp=Path(r'C:\iverilog\bin\vvp.exe');report['tools']={str(x):sha(x) for x in [iv,vvp]};save()
 for case in cases:
  name,page,dual,zoom,focus,mode=case[:6];header_byte=case[6] if len(case)>6 else 28
  if dual:ln,rn={1:('PN01','PN02'),2:('PN02','PN01'),3:('PN03','PN04'),4:('PN04','PN03')}.get(page,('PN01','PN02'))
  else:ln,rn=f'UI{page+1:02}','PN01'
  gold=out/(name+'_gold.hex');gold.write_bytes(('\n'.join(f'{v:06x}' for v in oracle(parsed[ln],parsed[rn],page,dual,zoom,focus))+'\n').encode())
  command=[str(iv),'-g2005-sv','-s','legacy_exhibit_loader_tb','-o',str(out/(name+'.vvp'))]
  command += ['-Plegacy_exhibit_loader_tb.'+k+'='+str(v) for k,v in {'PAGE':page,'DUAL':dual,'ZOOM':zoom,'FOCUS':focus,'MODE':mode,'HEADER_BYTE':header_byte}.items()]
  command += [str(snap/'legacy_exhibit_loader.v'),str(snap/'legacy_exhibit_loader_tb.v')]
  started=time.time();c=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=30);(out/(name+'.compile.log')).write_bytes((c.stdout+c.stderr).encode())
  step={'name':name,'compile_exit':c.returncode,'command':command,'gold_sha256':sha(gold)}
  if c.returncode==0:
   args=[str(vvp),str(out/(name+'.vvp')),'+left='+str(hexes[ln]),'+right='+str(hexes[rn]),'+gold='+str(gold),'+left_len='+str(len(parsed[ln][0])),'+right_len='+str(len(parsed[rn][0])),'+expected_sectors='+str(sector_count(page,dual,zoom,focus))]
   if mode in [0,9]:args+=['+dump='+str(out/(name+'_rtl.hex'))]
   v=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=900);log=v.stdout+v.stderr;(out/(name+'.run.log')).write_bytes(log.encode());step.update(exit_code=v.returncode,output=log.strip(),pass_=v.returncode==0 and 'TEST_PASS' in log)
  else:step.update(pass_=False,output=c.stdout+c.stderr)
  if mode in [0,9] and (out/(name+'_rtl.hex')).exists():
   step['payload_sha256']=sha(out/(name+'_rtl.hex'))
   if a.compare_to:
    old=a.compare_to/(name+'_rtl.hex')
    step['baseline_payload_sha256']=sha(old) if old.exists() else None
    step['payload_equal']=step['payload_sha256']==step['baseline_payload_sha256']
    step['pass_']=step['pass_'] and step['payload_equal']
  step['wall_seconds']=time.time()-started;report['steps'].append(step);ok=ok and step['pass_'];save();print(name,'PASS' if step['pass_'] else 'FAIL',step['output'][-400:],flush=True)
  if not step['pass_']:break
 report['state']='PASS' if ok else 'FAIL';report['finished']=time.time();report['wall_seconds']=report['finished']-report['started'];save();print('RESULT',report['state'],out/'verification.json',flush=True);return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())
