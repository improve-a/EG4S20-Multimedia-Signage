"""Compile the source.card .txt.swap opacity/translateY curve, not image frames."""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def ease(x):
 if x>=1:return 1.0
 lo=0.;hi=1.
 for _ in range(64):
  t=(lo+hi)/2
  if 3*(1-t)**2*t*.16+3*(1-t)*t*t*.3+t**3<x:lo=t
  else:hi=t
 t=(lo+hi)/2;return 1-(1-t)**3

def main():
 rows=[];cases=[];rom=[]
 for age in range(32):
  q=ease(age*.0168/.5);dy=math.floor(6*(1-q)+.5);alpha=math.floor(255*q+.5);packed=dy
  colors=[]
  for fg in [(26,25,22),(119,115,107)]:
   for cov in [1,2,3]:
    color=tuple(math.floor((f*alpha*cov+b*(765-alpha*cov))/765+.5) for f,b in zip(fg,(237,233,226)))
    colors.append(color);rom.extend(color);packed=(packed<<24)|(color[0]<<16)|(color[1]<<8)|color[2]
  cases.append(f"   6'd{age}:swap_offset=3'd{dy};")
  rows.append({'age':age,'translate_y':dy,'opacity':q,'alpha8':alpha,'colors':colors})
 f=ROOT/'rtl/ext/html_osd_overlay.v';s=f.read_text(encoding='utf8');a=s.index(' // BEGIN GENERATED SWAP');b=s.index(' // END GENERATED SWAP',a)
 s=s[:a]+" // BEGIN GENERATED SWAP\n localparam [146:0] SWAP_STEADY=147'h"+f"{packed:037x}"+";\n function [2:0] swap_offset;input[5:0] a;begin case(a)\n"+'\n'.join(cases)+"\n   default:swap_offset=0;\n  endcase end endfunction\n"+s[b:];f.write_bytes(s.encode())
 file=ROOT/'rtl/ext/html_assets/html_osd_swap_palette.hex';file.write_bytes(''.join(f'{v:02x}\n' for v in rom).encode());file.with_suffix('.hex.bin').write_bytes(''.join(f'{v:08b}\n' for v in rom).encode())
 out=ROOT/'output/html_fidelity/bot_osd/swap_curve.json';out.write_bytes(json.dumps({'source':'03.css.card.txt.swap .5s e-out(.16,1,.3,1); onlywho+say+caret','frame_seconds':.0168,'rows':rows},indent=2).encode());print('swapcurve32rows,576byte serialpalette,oneBRAM9K,noimageframes')
if __name__=='__main__':main()
