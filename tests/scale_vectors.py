#!/usr/bin/env python3
"""Independent BMP encoder and top-down nearest-neighbour canvas oracle.
Expected stream is reversed vertically for the inherited SDRAM WRITE_V_FLIP.
"""
import pathlib,struct,json
ROOT=pathlib.Path(__file__).resolve().parent
CASES=[(320,240,0,54),(320,180,0,511),(640,360,0,1027),(640,480,0,54),
       (320,240,1,124),(319,179,0,513),(319,179,1,108),(1,1,0,54)]
def rgb(x,y):return ((x*7+y*13+1)&255,(x*11+y*3+29)&255,(x*5+y*17+71)&255)
def encode(w,h,offset):
 stride=(w*3+3)&~3
 raw=bytearray(offset+stride*h)
 raw[:2]=b'BM';struct.pack_into('<I',raw,2,len(raw));struct.pack_into('<I',raw,10,offset)
 struct.pack_into('<IiiHHI',raw,14,40,w,h,1,24,0)
 for sy in range(h):
  for x in range(w):
   r,g,b=rgb(x,h-1-sy);raw[offset+sy*stride+x*3:offset+sy*stride+x*3+3]=bytes((b,g,r))
  raw[offset+sy*stride+w*3:offset+(sy+1)*stride]=b'\xda'*(stride-w*3)
 return raw
(ROOT/'scale_header.hex').write_text(''.join(f'{b:02x}\n' for b in encode(640,480,54)[:512]))
meta=[]
for n,(w,h,mode,offset) in enumerate(CASES):
 data=encode(w,h,offset);data+=bytes((-len(data))%512)
 (ROOT/f'scale_card_{n}.hex').write_text(''.join(f'{b:02x}\n' for b in data))
 factor=2 if mode==0 and w<=320 and h<=240 else 1
 left=(640-w*factor)//2;top=(480-h*factor)//2
 # Top-down geometry, reversed emission order.
 expected=[]
 for y in range(479,-1,-1):
  for x in range(640):
   c=rgb((x-left)//factor,(y-top)//factor) if left<=x<left+w*factor and top<=y<top+h*factor else (0,0,0)
   expected.append('%02x%02x%02x\n'%c)
 (ROOT/f'scale_golden_{n}.hex').write_text(''.join(expected))
 meta.append(dict(case=n,width=w,height=h,mode=mode,offset=offset,bytes=len(data),scale=factor))
(ROOT/'scale_vectors.json').write_text(json.dumps(meta,indent=2)+'\n')
# Invalid dimensions, signed/top-down height, offset/DIB overlap, length and
# compression, signature, planes, bpp, address wrap all remain rejected.
base=encode(320,180,54)
bad=[]
for field,at,fmt,val in [('width0',18,'I',0),('width641',18,'I',641),('height481',22,'I',481),
 ('heightnegative',22,'i',-180),('offsetshort',10,'I',53),('offsethuge',10,'I',1048577),
 ('lengthshort',2,'I',len(base)-1),('lengthhuge',2,'I',len(base)+65537),
 ('compression',30,'I',1),('dib',14,'I',12),('planes',26,'H',2),('bpp',28,'H',32)]:
 b=bytearray(base[:512]);struct.pack_into('<'+fmt,b,at,val);bad.extend(b)
(ROOT/'scale_scan.hex').write_text(''.join(f'{b:02x}\n' for b in bytes(bad[:512])+encode(320,180,511)[:512]+encode(640,480,54)[:512]))
(ROOT/'scale_invalid.hex').write_text(''.join(f'{b:02x}\n' for b in bad))
