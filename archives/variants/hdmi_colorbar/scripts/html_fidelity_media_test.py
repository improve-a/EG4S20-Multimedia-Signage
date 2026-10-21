#!/usr/bin/env python3
"""Validate HFXC resources pixel-for-pixel against clean independent panels."""
import argparse,hashlib,json,struct
from pathlib import Path
from html_fidelity_assets import png

def main():
 p=argparse.ArgumentParser();p.add_argument('--assets',type=Path,required=True);p.add_argument('--media',type=Path,required=True);a=p.parse_args();checks=[]
 for i,n in enumerate(['home','eagle','phoenix','elf','dragon','eco'],1):
  source=(a.assets/f'A_{i:02d}_{n}.bmp').read_bytes();d=(a.media/f'UI{i:02d}.BMP').read_bytes();off=struct.unpack_from('<I',d,10)[0];assert struct.unpack_from('<I',d,2)[0]==len(d)
  assert d[off:]==source[54:],'main BMP visual bytes changed'
  if n not in ('home','eco'):
   assert off==250368;assert struct.unpack_from('<4sHHHHHII',d,54)==(b'HFXC',1,320,384,80,24,249856,512)
   w,h,r=png(a.assets/f'panel_{n}.png');rs=d[512:250368];assert rs[-256:]==bytes(256)
   pos=0
   def check(rr,gg,bb):
    nonlocal pos
    expect=((rr>>3)<<11)|((gg>>2)<<5)|(bb>>3);actual=struct.unpack_from('<H',rs,pos)[0];assert actual==expect;pos+=2
   for y in range(384):
    for x in range(320):
     p=(y*320+x)*4;check(*r[p:p+3])
   for yy in range(24):
    for xx in range(80):
     sums=[0,0,0]
     for dy in range(4):
      for dx in range(4):
       p=((384+yy*4+dy)*320+xx*4+dx)*4
       for c in range(3):sums[c]+=r[p+c]
     check(*[(v+8)//16 for v in sums])
   assert pos==249600
  else:assert d==source and off==54
  checks.append(f'UI{i:02d}.BMP:main image identical;HFXC full resource validation PASS')
 report={'state':'MEDIA_ENCODING_PASS','checks':checks,'four_resource_regions_total_bytes':999424,'spare_sdram_bytes':1015808,'remaining_bytes':16384,'limitations':'Bottom96 background rows use4x4 average/downsample, not exact noise. DUT load/dual/zoom and card/hardware not established.'}
 (a.media/'media_tests.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps({'state':report['state'],'checks':len(checks),'remaining_sdram_bytes':16384}))
if __name__=='__main__':main()
