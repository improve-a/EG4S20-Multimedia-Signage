"""Native Windows full display-chain simulation. Standard library; no board access.
DUT writes every exported RGB pixel. PC prepares static storage vectors and
independent pixel/address expectations, never pretends to render DUT output.
"""
import argparse,datetime,hashlib,json,os,shutil,struct,subprocess,time,wave,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/html_fidelity/display_chain'
VECTORS=ROOT/'output/html_fidelity/display_vectors'
MEDIA=ROOT/'output/html_fidelity/media'
ASSETS=ROOT/'output/html_fidelity/assets'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def atomic_json(p,value):
 p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(value,indent=2),encoding='utf-8');os.replace(tmp,p)
def bmp_rgb(p):
 d=p.read_bytes();off=struct.unpack_from('<I',d,10)[0];w,h=struct.unpack_from('<ii',d,18);bpp=struct.unpack_from('<H',d,28)[0];comp=struct.unpack_from('<I',d,30)[0]
 if d[:2]!=b'BM' or (w,abs(h),bpp,comp)!=(640,480,24,0):raise ValueError(f'unsupported fixture {p}')
 stride=((w*3+3)//4)*4
 rows=[]
 for y in range(abs(h)):
  pos=off+(abs(h)-1-y if h>0 else y)*stride;row=d[pos:pos+w*3]
  rows.append(bytes(v for x in range(w) for v in (row[x*3+2],row[x*3+1],row[x*3])))
 return b''.join(rows),{'offset':off,'width':w,'height':h,'stride':stride,'bytes':len(d)}
def prepare_vectors():
 VECTORS.mkdir(parents=True,exist_ok=True);report={'source_bmp':[],'words':0,'scope':'static storage preparation, not runtime renderer'}
 with (VECTORS/'memory_words.hex').open('w',newline='\n') as out:
  for i in range(1,7):
   p=MEDIA/f'UI{i:02d}.BMP';rgb,meta=bmp_rgb(p)
   for y in range(480):
    row=rgb[y*1920:(y+1)*1920]
    out.write(''.join(f'{row[x*3]:02x}{row[x*3+1]:02x}{row[x*3+2]:02x}00\n' for x in range(640)))
   report['source_bmp'].append({'path':str(p),'sha256':sha(p),**meta});report['words']+=307200
  for i in range(2,6):
   p=MEDIA/f'UI{i:02d}.BMP';d=p.read_bytes();magic,version,tw,th,lw,lh,size,off=struct.unpack_from('<IHHHHHII',d,54)
   if (magic,version,tw,th,lw,lh,size,off)!=(0x43584648,1,320,384,80,24,249856,512):raise ValueError(f'bad packedpanel metadata {p}')
   words=struct.unpack_from('<62464I',d,off);out.write(''.join(f'{v:08x}\n' for v in words));report['words']+=len(words)
 if report['words']!=2093056:raise ValueError('memory layout differs from production mapper')
 wp=MEDIA/'07_MUSIC.WAV'
 with wave.open(str(wp),'rb') as w:
  channels=w.getnchannels();rate=w.getframerate();width=w.getsampwidth();count=w.getnframes();data=w.readframes(count)
 if width!=2:raise ValueError('peak fixture expects PCM16')
 samples=struct.unpack('<'+str(len(data)//2)+'h',data)
 peaks=[]
 for frame in range(256):
  start=(frame*rate*420000)//25000000;end=((frame+1)*rate*420000)//25000000
  peak=max(abs(v) for v in samples[start*channels:end*channels]);peaks.append(min(32768,peak))
 (VECTORS/'real_wav_peaks.hex').write_text(''.join(f'{p:04x}\n' for p in peaks))
 report['audio']={'path':str(wp),'sha256':sha(wp),'channels':channels,'rate':rate,'width':width,'frame_count':count,'method':'actual PCM16 absolute peak per16.8ms video frame; temporal bars, not spectrum'}
 def ease(x):
  lo,hi=0.,1.
  for _ in range(48):
   t=(lo+hi)/2;a=3*(1-t)*(1-t)*t*.76+3*(1-t)*t*t*.24+t*t*t
   if a<x:lo=t
   else:hi=t
  t=(lo+hi)/2;return 3*(1-t)*t*t+t*t*t
 values=[round(640*ease(min(1.,f*0.0168/1.05))) for f in range(64)]
 (VECTORS/'aperture_width.hex').write_text(''.join(f'{v:03x}\n' for v in values))
 report['vectors']={p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in VECTORS.glob('*.hex')};atomic_json(VECTORS/'manifest.json',report)
 return report
def png_write(p,w,h,rgb):
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 scan=b''.join(b'\0'+rgb[y*w*3:(y+1)*w*3] for y in range(h))
 p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b''))
def png_read(p):
 data=p.read_bytes();pos=8;packed=b''
 while pos<len(data):
  n=struct.unpack_from('>I',data,pos)[0];tag=data[pos+4:pos+8];d=data[pos+8:pos+8+n];pos+=12+n
  if tag==b'IHDR':w,h,depth,color,comp,filt,interlace=struct.unpack('>IIBBBBB',d)
  elif tag==b'IDAT':packed+=d
 if depth!=8 or color not in (2,6) or interlace:raise ValueError(f'unsupported PNG format {p}')
 channels=3 if color==2 else 4;stride=w*channels;raw=zlib.decompress(packed);prev=bytearray(stride);rgb=bytearray()
 def paeth(a,b,c):
  q=a+b-c;aa=abs(q-a);bb=abs(q-b);cc=abs(q-c)
  return a if aa<=bb and aa<=cc else b if bb<=cc else c
 for y in range(h):
  start=y*(stride+1);mode=raw[start];row=bytearray(raw[start+1:start+1+stride])
  for x in range(stride):
   a=row[x-channels] if x>=channels else 0;b=prev[x];c=prev[x-channels] if x>=channels else 0
   row[x]=(row[x]+(0 if mode==0 else a if mode==1 else b if mode==2 else (a+b)//2 if mode==3 else paeth(a,b,c)))&255
  if channels==3:rgb.extend(row)
  else:
   for x in range(w):rgb.extend(row[x*4:x*4+3])
  prev=row
 return w,h,bytes(rgb)
def ppm_read(p):
 magic,wh,depth,rgb=p.read_bytes().split(b'\n',3)
 if magic!=b'P6' or wh!=b'640 480' or depth!=b'255' or len(rgb)!=921600:raise ValueError(f'incomplete DUT frame {p}')
 return rgb
def compare_frames(run):
 result=[];names=['home','eagle','phoenix','elf','dragon','eco']
 for ppm in sorted((run/'output/html_fidelity/display_chain').glob('*.ppm')):
  rgb=ppm_read(ppm);target=OUT/ppm.name;shutil.copy2(ppm,target);png_write(target.with_suffix('.png'),640,480,rgb)
  item={'frame':ppm.name,'sha256':sha(ppm),'source':'real RTL out_rgb fwrite;640x480307200pixels'}
  reference=None;clean=None
  if ppm.stem.startswith('page'):
   i=int(ppm.stem[4:]);reference=ASSETS/f'reference_{names[i]}.png';clean=ASSETS/f'A_{i+1:02d}_{names[i]}.png'
  elif ppm.stem=='compare_eagle_phoenix':reference=ASSETS/'reference_dual.png'
  elif ppm.stem=='zoom2':reference=ASSETS/'reference_zoom.png'
  if reference and reference.exists():
   w,h,ref=png_read(reference)
   if (w,h)!=(640,480):raise ValueError('reference is not stage640x480')
   diff=bytes(min(255,abs(a-b)*4) for a,b in zip(rgb,ref));triptych=b''.join(ref[y*1920:(y+1)*1920]+rgb[y*1920:(y+1)*1920]+diff[y*1920:(y+1)*1920] for y in range(480))
   png_write(OUT/(ppm.stem+'_reference_dut_diff.png'),1920,480,triptych)
   item.update(reference=str(reference),reference_sha256=sha(reference),full_rgb_mae=sum(abs(a-b) for a,b in zip(rgb,ref))/len(rgb),comparison='left sourceHTML;middle actualDUT;right4xabsoluteRGBdifference. Pose/bars differ by disclosed fixture.')
  if clean and clean.exists():
   w,h,base=png_read(clean);err=0;count=0;bad=0
   for y in range(380):
    for x in range(640):
     if x>=500 and y<105:continue
     k=(y*640+x)*3;delta=sum(abs(rgb[k+c]-base[k+c]) for c in range(3));err+=delta;count+=3;bad+=delta!=0
   item.update(clean_A_sha256=sha(clean),clean_A_rgb_mae=err/count,clean_A_nonmatching_pixels=bad,clean_A_mask='y<380 excluding x>=500,y<105; excludes all OSD,Bot and zoomindicator')
  result.append(item)
 atomic_json(OUT/'pixel_comparisons.json',result);return result
def source_files():
 local=['tests/html_display_chain_tb.v','rtl/SD/frame_read_write.v','rtl/SD/frame_fifo_read.v','rtl/SD/frame_fifo_write.v',
        'rtl/SD/video_delay.v','rtl/SD/video_timing_data.v','rtl/SD/color_bar.v','rtl/IP/afifo_32_16_256.v','rtl/IP/afifo_16_32_256.v',
        'rtl/ext/pixel_adjust.v','rtl/ext/html_assets/html_caption_map.v']
 local += [str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext').glob('html*.v')]
 local += [str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext').glob('exhibit*.v')]
 return sorted(set(local))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--prepare-only',action='store_true');ap.add_argument('--smoke',action='store_true');ap.add_argument('--timeout',type=int,default=6000);a=ap.parse_args()
 vectors=prepare_vectors()
 if a.prepare_only:print(json.dumps(vectors,indent=2));return 0
 OUT.mkdir(parents=True,exist_ok=True);run=OUT/('run_'+time.strftime('%Y%m%d_%H%M%S'));run.mkdir()
 sources=source_files()
 dependencies=sources+['rtl/SD/video_define.v']+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for name in dependencies:
  dst=run/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 for folder in ['display_vectors']:
  shutil.copytree(ROOT/'output/html_fidelity'/folder,run/'output/html_fidelity'/folder)
 (run/'output/html_fidelity/display_chain').mkdir(parents=True)
 evidence={'state':'RUNNING','scope':'Display-chain RTL with real FIFOs/timing; encrypted SDRAM replaced by4-beatgroup model. No SDphysical,PHY,HW orSTAclaim.',
 'snapshot':str(run),'supervisor_pid':os.getpid(),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'started_epoch':time.time(),
 'sources':{n:sha(run/n) for n in dependencies},'vectors':vectors,'steps':[],
 'fixtures':'Static captures seed only caption complete and known Botmotion registers atverticalblank; noRGBpixel forcing. Natural committedpageaction frames runnormally.'}
 def save():atomic_json(run/'verification.json',evidence);atomic_json(OUT/'verification.json',evidence)
 save()
 commands=[('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-Irtl/SD','-s','html_display_chain_tb','-o','sim.vvp']+sources),
           ('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp']+(['+smoke'] if a.smoke else []))]
 for name,cmd in commands:
  t=time.time()
  with (run/(name+'.log')).open('wb') as log:
   child=subprocess.Popen(cmd,cwd=run,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'pid':child.pid,'command':cmd,'state':'RUNNING'};evidence['steps'].append(step);save()
   try:code=child.wait(timeout=120 if name=='compile' else a.timeout)
   except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
  step.update(exit_code=code,wall_seconds=time.time()-t,state='PASS' if code==0 else 'FAIL');save()
  if code:evidence.update(state='FAIL',wall_seconds=time.time()-evidence['started_epoch']);save();print((run/(name+'.log')).read_text(errors='replace'));return code
 if b'DISPLAY_CHAIN_SIM_PASS' not in (run/'simulation.log').read_bytes():raise ValueError('missing real DUT completionmarker')
 evidence['frames']=compare_frames(run);evidence.update(state='DISPLAY_CHAIN_SIM_PASS',wall_seconds=time.time()-evidence['started_epoch']);save();print(json.dumps(evidence,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
