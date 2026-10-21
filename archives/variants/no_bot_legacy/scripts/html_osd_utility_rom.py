"""Compile existing RTL5x7 font bits into unused utility-palette ROM words.
Palette bytes0..575 remain exact. No font substitution or image rasterization.
"""
import argparse,hashlib,json,re
from pathlib import Path

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--output-dir',required=True,type=Path);a=ap.parse_args()
 source=a.root/'rtl/ext/html_osd_overlay.v';palette=a.root/'rtl/ext/html_assets/html_osd_swap_palette.hex';output=a.output_dir;output.mkdir(parents=True,exist_ok=True)
 pairs=re.findall(r'  "(.)":digit=35\'b([01]{35});',source.read_text(encoding='utf8'))
 if len(pairs)!=24:raise ValueError('expected original24 live5x7characters')
 values=[int(x,16) for x in palette.read_text().split()]
 if len(values)!=576 or any(v>255 for v in values):raise ValueError('expected numeric576byte framepalette')
 for character,bits in pairs:values.extend(int(bits[row*5:row*5+5],2) for row in range(7))
 values.extend([0]*7)
 if len(values)!=751:raise ValueError('fixed fontaddress contract changed')
 values.extend([0]*(1024-len(values)))
 path=output/'html_osd_swap_font.hex';path.write_bytes(''.join(f'{v:02x}\n' for v in values).encode());binary=path.with_suffix('.hex.bin');binary.write_bytes(''.join(f'{v:08b}\n' for v in values).encode())
 manifest={'source_rtl_sha256':sha(source),'palette_sha256':sha(palette),'font_characters':[c for c,bits in pairs],'layout':{'palette':[0,575],'font_rows':[576,743],'space_rows':[744,750],'zero_padding':[751,1023]},'words':1024,'width':8,'hex_sha256':sha(path),'binary_sha256':sha(binary),'scope':'Original5x7bits only; numericpalettebytes unchanged; singleexisting9K'}
 (output/'html_osd_utility_rom_manifest.json').write_bytes(json.dumps(manifest,indent=2).encode());print(json.dumps(manifest,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
