#!/usr/bin/env python3
"""Compare an externally produced DUT PNG to a disclosed source-side reference.
This script never renders a DUT; it only reads the --dut file provided by a simulator.
"""
import argparse,hashlib,json,struct,zlib
from pathlib import Path
from html_fidelity_assets import png

def write_png(path,w,h,rgba):
 def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
 raw=b''.join(b'\0'+rgba[y*w*4:(y+1)*w*4]for y in range(h))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference',type=Path,required=True);p.add_argument('--dut',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--layers',type=Path);p.add_argument('--page-index',type=int,default=0);p.add_argument('--exclude',action='append',default=[],help='rectangle x,y,width,height excluded only from masked statistics');a=p.parse_args();w,h,r=png(a.reference);dw,dh,d=png(a.dut);assert(w,h)==(dw,dh)==(640,480);a.out.mkdir(parents=True,exist_ok=True)
 excludes=[tuple(map(int,s.split(',')))for s in a.exclude];regions=[('whole_frame',(0,0,w,h)),('whole_frame_excluding_declared_rectangles',(0,0,w,h))]
 if a.layers:
  m=json.loads((a.layers/'hfxl_payload_manifest.json').read_text(encoding='utf8'));q=m['pages'][a.page_index];regions.extend((c['name'],c['bbox'])for c in q['components'])
 results={}
 for name,(x,y,cw,ch)in regions:
  count=total=changed=maximum=0
  for yy in range(max(0,y),min(h,y+ch)):
   for xx in range(max(0,x),min(w,x+cw)):
    if name.endswith('declared_rectangles')and any(ex<=xx<ex+ew and ey<=yy<ey+eh for ex,ey,ew,eh in excludes):continue
    i=(yy*w+xx)*4;delta=[abs(d[i+k]-r[i+k])for k in range(3)];count+=1;total+=sum(delta);changed+=any(delta);maximum=max(maximum,*delta)
  results[name]={'pixels':count,'changed_pixels':changed,'max_rgb_error':maximum,'mean_abs_rgb_error':total/(3*count)if count else 0}
 diff=bytearray(w*h*4);trip=bytearray(w*3*h*4)
 for yy in range(h):
  for xx in range(w):
   i=(yy*w+xx)*4;diff[i:i+4]=bytes([min(255,8*abs(d[i+k]-r[i+k]))for k in range(3)]+[255])
  for j,im in enumerate([r,d,diff]):trip[(yy*w*3+j*w)*4:(yy*w*3+(j+1)*w)*4]=im[yy*w*4:(yy+1)*w*4]
 write_png(a.out/'reference_dut_diff8x.png',w*3,h,trip);write_png(a.out/'diff8x.png',w,h,diff)
 result={'scope':'Left source reference / center externally supplied DUT / right absolute RGB difference multiplied by 8. This tool does not generate DUT pixels.','reference':{'path':str(a.reference.resolve()),'sha256':hashlib.sha256(a.reference.read_bytes()).hexdigest()},'dut':{'path':str(a.dut.resolve()),'sha256':hashlib.sha256(a.dut.read_bytes()).hexdigest()},'excluded_rectangles_xywh':excludes,'regions':results};(a.out/'regiondiff.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(results))
if __name__=='__main__':main()
