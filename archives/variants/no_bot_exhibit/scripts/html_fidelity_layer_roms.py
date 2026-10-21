#!/usr/bin/env python3
"""Export small fixed palette/descriptor/header ROMs from frozen HFXL payloads."""
import argparse,hashlib,json,struct
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--layers',type=Path,required=True);a=p.parse_args();r=a.layers;m=json.loads((r/'hfxl_payload_manifest.json').read_text(encoding='utf8'));palette=[];desc=[];headers=[]
 for q in m['pages']:
  with (r/q['path']).open('rb') as f:
   h=struct.unpack('<16I',f.read(64));assert h[13]==m['set_id'] and h[14]==q['global_word_base'];headers.extend(h);f.seek(q['palette_word_offset']*4);pal=struct.unpack('<512I',f.read(2048));assert all(v&255==0 for v in pal);palette.extend(v>>8 for v in pal)
   f.seek(64*4);actual=struct.unpack('<'+'I'*(q['component_count']*8),f.read(q['component_count']*32));desc.extend(actual)
   for _ in range(16-q['component_count']):desc.extend([255,0,0,0,0,0,0,0])
 for name,data,width in [('html_layer_palette.hex',palette,6),('html_layer_descriptors.hex',desc,8),('html_layer_headers.hex',headers,8)]:
  f=r/name;f.write_text(''.join(f'{v:0{width}x}\n'for v in data),encoding='ascii');(r/(name+'.bin')).write_text(''.join(f'{v:0{width*4}b}\n'for v in data),encoding='ascii')
 planes={'r':[(v>>16)&255 for v in palette],'g':[(v>>8)&255 for v in palette],'b':[v&255 for v in palette]}
 for channel,values in planes.items():
  f=r/f'html_layer_palette_{channel}.hex';f.write_text(''.join(f'{v:02x}\n' for v in values),encoding='ascii')
  (r/f'html_layer_palette_{channel}.hex.bin').write_text(''.join(f'{v:08b}\n' for v in values),encoding='ascii')
 assert all(((planes['r'][i]<<16)|(planes['g'][i]<<8)|planes['b'][i])==palette[i] for i in range(len(palette)))
 desc16=[half for word in desc for half in (word&0xffff,(word>>16)&0xffff)]
 d16=r/'html_layer_descriptors16.hex';d16.write_text(''.join(f'{v:04x}\n'for v in desc16),encoding='ascii')
 (r/'html_layer_descriptors16.hex.bin').write_text(''.join(f'{v:016b}\n'for v in desc16),encoding='ascii')
 assert all((desc16[i*2]|(desc16[i*2+1]<<16))==desc[i] for i in range(len(desc)))
 report={'set_id':m['set_id'],'palette':{'file':'html_layer_palette.hex','items':len(palette),'bits_per_item':24,'format':'page_index*512+color_index, RRGGBB','planes':{ch:{'file':f'html_layer_palette_{ch}.hex','items':len(values),'bits_per_item':8,'format':{'r':'R','g':'G','b':'B'}[ch]}for ch,values in planes.items()},'planes_byte_exact':True},'descriptors':{'file':'html_layer_descriptors.hex','items':len(desc),'bits_per_item':32,'format':'(page_index*16+component_index)*8+word;inactivew0role255','dual_port_16bit':{'file':'html_layer_descriptors16.hex','items':len(desc16),'bits_per_item':16,'ordering':'word0_low16,word0_high16,word1_low16,word1_high16,...','round_trip_exact':True}},'headers':{'file':'html_layer_headers.hex','items':len(headers),'bits_per_item':32,'format':'page_index*16+headerword'},'rom_bits_total':len(palette)*24+len(desc)*32+len(headers)*32,'sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest()for f in [r/(n+suf)for n in ['html_layer_palette.hex','html_layer_descriptors.hex','html_layer_headers.hex','html_layer_descriptors16.hex']for suf in ['', '.bin']if (r/(n+suf)).exists()]+[r/f'html_layer_palette_{ch}.hex{suffix}'for ch in planes for suffix in ['', '.bin']]},'scope':'Exact smallROM exports; synthesis memory allocation and runtimeDUT not verified'};(r/'layer_roms_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps({'ROM_bits':report['rom_bits_total'],'set_id':m['set_id'],'palette_planes':{ch:len(values) for ch,values in planes.items()},'descriptor16_items':len(desc16)}))
if __name__=='__main__':main()
