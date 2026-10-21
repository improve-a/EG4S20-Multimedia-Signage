#!/usr/bin/env python3
"""Allpixel exact encoding checks for experimental HFXLv1, not DUT rendering."""
import argparse,hashlib,json,struct
from pathlib import Path
from html_fidelity_assets import png

def main():
 p=argparse.ArgumentParser();p.add_argument('--layers',type=Path,required=True);a=p.parse_args();r=a.layers;m=json.loads((r/'hfxl_payload_manifest.json').read_text(encoding='utf8'));layers=json.loads((r/'layer_measurements.json').read_text(encoding='utf8'));glob=(r/'hfxl_global_atlas.bin').read_bytes();assert len(glob)==m['total_words']*4;tests=[];rompal=[int(v,16)for v in (r/'html_layer_palette.hex').read_text(encoding='ascii').split()];romdesc=[int(v,16)for v in (r/'html_layer_descriptors.hex').read_text(encoding='ascii').split()];romhead=[int(v,16)for v in (r/'html_layer_headers.hex').read_text(encoding='ascii').split()];assert(len(rompal),len(romdesc),len(romhead))==(3072,768,96)
 for name,width in [('html_layer_palette.hex',24),('html_layer_descriptors.hex',32),('html_layer_headers.hex',32)]:
  hs=(r/name).read_text().split();bs=(r/(name+'.bin')).read_text().split();assert len(hs)==len(bs) and all(len(b)==width and int(b,2)==int(h,16)for h,b in zip(hs,bs))
 normalized=bytearray(glob)
 for q in m['pages']:struct.pack_into('<I',normalized,q['global_word_base']*4+52,0)
 content_digest=hashlib.sha256(normalized).hexdigest();assert int(content_digest[:8],16)==m['set_id'] and content_digest==m['set_id_derivation']['zeroed_payload_sha256']
 normalized[-1]^=1;assert hashlib.sha256(normalized).hexdigest()!=content_digest
 for q,lp in zip(m['pages'],layers['pages']):
  b=(r/q['path']).read_bytes();words=struct.unpack('<'+'I'*(len(b)//4),b);assert words[0:6]==(0x4c584648,1,len(words),q['component_count'],64,8);assert len(words)%256==0 and q['global_word_base']%256==0 and q['global_word_base']+len(words)<=1843200
  pi=q['page_index'];assert tuple(romhead[pi*16:pi*16+16])==words[:16];assert rompal[pi*512:pi*512+512]==[v>>8 for v in words[q['palette_word_offset']:q['palette_word_offset']+512]]
  assert words[13]==m['set_id'] and words[14]==q['global_word_base'] and words[15]==q['page_index'];assert glob[q['global_word_base']*4:(q['global_word_base']+len(words))*4]==b
  bg=lp['layers'][0];w,h,pix=png(r/(bg['name']+'_crop.png'));assert(w,h)==(640,480)
  for y in range(480):
   for x in range(640):
    word=words[q['bg_word_offset']+y*214+x//3];idx=(word>>(x%3*10))&1023;assert idx<q['palette_entries'];col=words[q['palette_word_offset']+idx];i=(y*640+x)*4;assert ((col>>24)&255,(col>>16)&255,(col>>8)&255)==tuple(pix[i:i+3])
   assert words[q['bg_word_offset']+y*214+213]>>10==0
  for ci,c in enumerate(q['components']):
   assert c['texture_word_offset']%4==0;desc=words[64+ci*8:64+ci*8+8];assert tuple(romdesc[(pi*16+ci)*8:(pi*16+ci+1)*8])==desc;assert tuple(c['descriptor_words'])==desc and desc[5]==desc[7]==0
   original=next(l for l in lp['layers']if l['name']==c['name']);ow,oh,rgba=png(r/(c['name']+'_crop.png'));ox,oy,_,_=original['bounds_rgba_alpha'];x,y,cw,ch=c['bbox'];expected=bytearray()
   for yy in range(y,y+ch):
    for xx in range(x,x+cw):
     i=((yy-oy)*ow+xx-ox)*4;rr,gg,bb,aa=rgba[i:i+4];expected.extend((aa,bb,gg,rr))
   off=c['texture_word_offset']*4;assert b[off:off+len(expected)]==expected
  for ci in range(q['component_count'],16):assert romdesc[(pi*16+ci)*8:(pi*16+ci+1)*8]==[255,0,0,0,0,0,0,0]
  container=(r/'experimental_media'/f'UI{q["page_index"]+1:02d}.BMP').read_bytes();loc=struct.unpack_from('<4sHHIIIHHII',container,80);magic,version,lens,scene,pbytes,base,idx,count,setid,reserved=loc;assert(magic,version,lens,base,idx,count,setid,reserved)==(b'HFXL',1,32,q['global_word_base'],q['page_index'],6,m['set_id'],0)
  poff=struct.unpack_from('<I',container,10)[0];assert scene==(poff+921600+511)//512*512 and pbytes==len(b) and pbytes<=2097152 and pbytes%1024==0 and scene+pbytes==len(container);assert container[scene:]==b and struct.unpack_from('<I',container,2)[0]==len(container)
  tests.append({'page':q['page'],'state':'EXPERIMENTAL_ENCODING_PASS','bg_pixels_checked':307200,'rgba_pixels_checked':sum(c['texels']for c in q['components']),'payload_sha256':hashlib.sha256(b).hexdigest()})
 result={'state':'EXPERIMENTAL_ENCODING_PASS','pages':tests,'global_words':m['total_words'],'word_extent_within_original_six_pages':m['total_words']<=1843200,'global_sha256':hashlib.sha256(glob).hexdigest(),'scope':'All exact BG palette/index pixels, all RGBA bytes, descriptors, alignment, global extents, locator/trailer encodings. Does NOT establish parser/loader/DUT/timing/hardware correctness.'};(r/'atlas_encoding_tests.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps({'state':result['state'],'pages':len(tests),'words':m['total_words']}))
if __name__=='__main__':main()
