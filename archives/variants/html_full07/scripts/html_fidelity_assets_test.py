#!/usr/bin/env python3
"""Structural/encoding tests for exported static layers and realtime texture inputs."""
import argparse,hashlib,json,struct
from pathlib import Path
from html_fidelity_assets import png

def main():
 a=argparse.ArgumentParser();a.add_argument('assets',type=Path);p=a.parse_args().assets;checks=[]
 for f in sorted(p.glob('*.bmp')):
  d=f.read_bytes();sig,size,_,_,off=struct.unpack_from('<2sIHHI',d);dib,w,h,planes,bits,compression=struct.unpack_from('<IiiHHI',d,14)
  assert(sig,size,off,dib,h,planes,bits,compression)==(b'BM',len(d),54,40,480,1,24,0)
  assert w==(320 if f.name.startswith('panel_') else 640)
  ww,hh,r=png(f.with_suffix('.png'));assert (w,h)==(ww,hh)
  stride=(w*3+3)&~3
  for y in range(h):
   row=d[off+(h-1-y)*stride:off+(h-1-y)*stride+w*3]
   for x in range(w):
    i=(y*w+x)*4; assert tuple(row[x*3:x*3+3])==tuple(reversed(r[i:i+3]))
  checks.append(f.name+': full pixel roundtrip BMP24 bottom-up PASS')
 w,h,r=png(p/'bot_body_nominal.png');body=[int(z,16) for z in (p/'bot_body_argb4444.hex').read_text(encoding='utf-8').split()];assert len(body)==10400
 assert r[3]==0 and body[0]>>12==0,'body must have transparent canvas corner'
 assert any(0<(v>>12)<15 for v in body),'antialias/shadow coverage preserved'
 levels=[0,2,4,7,11,16,22,29,37,46,58,74,96,128,176,255];q=lambda v:min(range(16),key=lambda i:abs(levels[i]-v))
 for i,v in enumerate(body):
  rr,gg,bb,aa=r[i*4:i*4+4];assert v==((aa+8)//17<<12)|(q(rr)<<8)|(q(gg)<<4)|q(bb)
 checks.append('body:10400 ARGB4444 words; transparent exterior; full pixel quantization PASS')
 data=json.loads((p/'caption_layout.json').read_text(encoding='utf-8'));glyph=[int(z,16) for z in (p/'html_glyph_coverage.hex').read_text(encoding='utf-8').split()];assert len(glyph)==len(data['glyphs'])*40
 for i,g in enumerate(data['glyphs']):
  unpack=[]
  for v in glyph[i*40:(i+1)*40]:unpack.extend((v>>n)&3 for n in range(14,-1,-2))
  assert unpack==g['alpha']
 assert len(data['all'])==12 and len(data['glyphs'])<=256
 for layout in data['all']:
  caption=[z for z in layout['runs'] if z['caption']];assert len(caption)==len(layout['text']);assert [z['i'] for z in caption]==list(range(len(layout['text'])))
  assert all(0<=z['id']<len(data['glyphs']) and z['x']>=42 and z['y'] in (416,435) for z in caption)
 checks.append('glyph:all coverage words unpack exactly;12 normal/dual proportional captions; <=256 glyphs PASS')
 total=len(body)*16+len(glyph)*16;assert total<350000;checks.append(f'texture budget:{total} bits <350000 PASS (synthesis allocation separate)')
 report=dict(state='ASSET_ENCODING_PASS',checks=checks,texture_bits=total,limits='Does not establish DUT rendering, synthesis BRAM allocation, full-system simulation or hardware correctness.',hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(p.iterdir()) if f.is_file() and f.suffix in ('.png','.bmp','.hex','.json') and f.name!='asset_tests.json'})
 (p/'asset_tests.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'state':report['state'],'checks':len(checks),'texture_bits':total}))
if __name__=='__main__':main()
