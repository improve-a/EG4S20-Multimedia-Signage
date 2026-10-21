#!/usr/bin/env python3
"""Pack native BMPs with independent dual-panel HFXC resources in BMP offset gaps.
No card access. BMP ordinary BGR main image stays unchanged. Bottom background
uses4x4 average samples; native top384 rows retain all comparison text/images.
"""
import argparse,hashlib,json,shutil,struct
from pathlib import Path
from html_fidelity_assets import png

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--assets',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--wav',type=Path);a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 records=[]
 names=['home','eagle','phoenix','elf','dragon','eco']
 for i,n in enumerate(names,1):
  src=a.assets/f'A_{i:02d}_{n}.bmp';original=src.read_bytes();dest=a.out/f'UI{i:02d}.BMP';rec=dict(name=dest.name,page=i-1,source=src.name,source_sha256=sha(src),width=640,height=480)
  if n not in ('home','eco'):
   panel=a.assets/f'panel_{n}.png';w,h,r=png(panel);assert(w,h)==(320,480)
   resource=bytearray()
   def emit(red,green,blue):resource.extend(struct.pack('<H',((red>>3)<<11)|((green>>2)<<5)|(blue>>3)))
   for y in range(384):
    for x in range(320):
     p=(y*320+x)*4;emit(*r[p:p+3])
   for yy in range(24):
    for xx in range(80):
     sums=[0,0,0]
     for dy in range(4):
      for dx in range(4):
       p=((384+yy*4+dy)*320+xx*4+dx)*4
       for c in range(3):sums[c]+=r[p+c]
     emit(*[(v+8)//16 for v in sums])
   assert len(resource)==249600;resource.extend(bytes(256));assert len(resource)==249856
   header=bytearray(512);header[:54]=original[:54];struct.pack_into('<I',header,2,250368+len(original)-54);struct.pack_into('<I',header,10,250368)
   struct.pack_into('<4sHHHHHII',header,54,b'HFXC',1,320,384,80,24,249856,512)
   payload=bytes(header)+resource+original[54:];assert len(payload)==250368+640*480*3
   assert payload[250368:]==original[54:]
   dest.write_bytes(payload);rec.update(pixel_offset=250368,resource_offset=512,resource_bytes=249856,resource_sha256=hashlib.sha256(resource).hexdigest(),panel_source=panel.name,panel_sha256=sha(panel),native_top=[320,384],background_bottom=[80,24],background_reconstruction='Nearest4x upsample of4x4 average, y384..479; gradient approximation and noise reduction; no semantic text omitted')
  else:dest.write_bytes(original);rec.update(pixel_offset=54)
  rec.update(bytes=dest.stat().st_size,sha256=sha(dest));records.append(rec)
 if a.wav:
  d=a.out/'07_MUSIC.WAV';shutil.copyfile(a.wav,d);records.append(dict(name=d.name,bytes=d.stat().st_size,sha256=sha(d),source_sha256=sha(a.wav)))
 manifest=dict(format='HFXC v1 BMP offset-gap independent comparison resources',header={'signature':[54,'4bytes HFXC'],'version':[58,'LEu16=1'],'width':[60,'LEu16=320'],'top_height':[62,'LEu16=384'],'bottom_width':[64,'LEu16=80'],'bottom_height':[66,'LEu16=24'],'resource_bytes':[68,'LEu32=249856'],'resource_offset':[72,'LEu32=512']},resource='LE RGB565,122880 native top pixels +1920 bottom samples +256 zero bytes. Four independent product regions. No joined screenshot/movie.',assets=records,hardware='NOT_VERIFIED')
 (a.out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=True,indent=2)+'\n',encoding='utf-8');print(json.dumps({'media_files':len(records),'out':str(a.out)}))
if __name__=='__main__':main()
