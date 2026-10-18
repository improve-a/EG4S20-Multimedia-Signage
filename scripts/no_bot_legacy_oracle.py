#!/usr/bin/env python3
"""Independent geometric oracle for legacy sequential-loader verification.
This produces EXPECTED source pixels only. It never labels software gold as RTL.
Crop centers are explicit UI geometry, not copies of packed RTL origin constants.
"""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MEDIA=ROOT/'output/html_fidelity/no_bot/media'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read_bmp(path):
 b=path.read_bytes();off=struct.unpack_from('<I',b,10)[0];w,h=struct.unpack_from('<ii',b,18);planes,bpp,compression=struct.unpack_from('<HHI',b,26);stride=(w*3+3)//4*4
 if b[:2]!=b'BM' or planes!=1 or bpp!=24 or compression or h<=0 or off!=512 or w not in [320,640] or h!=480:raise ValueError('plain BMP contract '+str(path))
 rows=[]
 for y in range(h):
  row=b[off+(h-1-y)*stride:off+(h-1-y)*stride+w*3]
  if len(row)!=w*3:raise ValueError('truncated '+str(path))
  rows.append(bytes(v for x in range(w) for v in [row[x*3+2],row[x*3+1],row[x*3]]))
 return w,h,b''.join(rows)
def source_xy(x,y,page,zoom,focus):
 d=min(3,max(1,int(zoom)+1))
 if d==1:return x,y
 centers=[(435,192) if page==0 else (448,173),(320,240),(160,240),(480,240),(320,120),(320,360)]
 cx,cy=centers[focus if 0<=focus<6 else 0]
 return cx+(x-320)//d,cy+(y-240)//d

def pair(page):return {1:(1,2),2:(2,1),3:(3,4),4:(4,3)}.get(page,(1,2))
def expected_rgb(page,dual=False,zoom=0,focus=0,media=MEDIA):
 left,right=pair(page);names=[f'PN{left:02d}.BMP',f'PN{right:02d}.BMP'] if dual else [f'UI{page+1:02d}.BMP']
 images=[read_bmp(media/name) for name in names];rgb=bytearray(640*480*3)
 for y in range(480):
  for x in range(640):
   sx,sy=source_xy(x,y,page,zoom,focus);which=int(dual and sx>=320)
   if dual:sx%=320
   w,h,pixels=images[which]
   if not(0<=sx<w and 0<=sy<h):raise AssertionError((page,dual,zoom,focus,x,y,sx,sy))
   at=(y*640+x)*3;source=(sy*w+sx)*3;rgb[at:at+3]=pixels[source:source+3]
 return bytes(rgb),{'oracle':'software expected only; independent rational centered crop; staticBMPsource, no DUToutput','page':page,'dual':bool(dual),'zoom':min(3,zoom+1),'focus':focus,'sources':{name:sha(media/name) for name in names},'rgb_sha256':hashlib.sha256(rgb).hexdigest()}
def verify_loader_dump(path,expected):
 words=[int(n,16) for n in path.read_text().split()]
 if len(words)!=307200:raise AssertionError('loader output pixel count '+str(len(words)))
 topdown=bytearray(921600)
 for n,word in enumerate(words):
  x=n%640;y=479-n//640;at=(y*640+x)*3;topdown[at:at+3]=bytes([(word>>16)&255,(word>>8)&255,word&255])
 if topdown!=expected:
  k=next(i for i,(a,b) in enumerate(zip(topdown,expected)) if a!=b);raise AssertionError(f'actual loader pixel mismatch x{(k//3)%640} y{(k//3)//640} channel{k%3} got{topdown[k]} expected{expected[k]}')
 return {'actual_loader_dump':str(path),'sha256':sha(path),'pixels':307200,'exact_rgb':'PASS','writer_mapping':'bottom-up emittedrows→topdown old WRITE_V_FLIP address order'}
