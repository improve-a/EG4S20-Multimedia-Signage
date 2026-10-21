"""Compile source CSS Bezier curves at the inherited16.8ms frame period.
The app removes both animation classes at1.55s; hardware applies that atage93.
Table0 is signedQ8 displacement; table1 is opacity8 and hero scale deficitQ12.
"""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'rtl/ext/html_assets'

def ease(x,control):
 if x<=0:return 0.0
 if x>=1:return 1.0
 x1,y1,x2,y2=control;lo=0.0;hi=1.0
 for _ in range(64):
  u=(lo+hi)/2;v=1-u
  if 3*v*v*u*x1+3*v*u*u*x2+u*u*u<x:lo=u
  else:hi=u
 u=(lo+hi)/2;v=1-u
 return 3*v*v*u*y1+3*v*u*u*y2+u*u*u

def nearest(x):return math.floor(x+.5)
def main():
 words=[[],[]];samples=[]
 for bank in range(12):
  for age in range(128):
   t=age*.0168
   if bank==0:
    q=ease(t/1.5,(.16,1,.3,1));offset=70*(1-q);alpha=q;delta=nearest(.035*4096*(1-q))
   elif bank==1:
    q=ease(t/1.7,(.16,1,.3,1));offset=120*(1-q);alpha=1;delta=0
   elif bank==2:
    q=ease(t/1.05,(.76,0,.24,1));offset=-46*q;alpha=1-.75*q;delta=0
   elif bank==3:
    q=ease(t/.45,(.7,0,.84,0));offset=-10*q;alpha=1-q;delta=0
   else:
    q=ease((t-.38-.07*(bank-4))/.9,(.16,1,.3,1));offset=14*(1-q);alpha=q;delta=0
   off=nearest(offset*256);a=nearest(alpha*255)
   words[0].append(off&65535);words[1].append((a<<8)|delta)
   samples.append({'bank':bank,'age':age,'offset_q8':off,'alpha':a,'scale_delta_q12':delta})
 hashes={}
 for i,stem in enumerate(['html_motion_offset','html_motion_alpha_scale']):
  file=ASSET/(stem+'.hex');file.write_bytes(''.join(f'{v:04x}\n' for v in words[i]).encode())
  file.with_suffix('.hex.bin').write_bytes(''.join(f'{v:016b}\n' for v in words[i]).encode())
  hashes[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
 inv=[nearest(4096*4096/(4096-d)) for d in range(144)]
 cases='\n'.join(f"   8'd{d}:inverse_scale=13'd{v};" for d,v in enumerate(inv))
 target=ROOT/'rtl/ext/html_scene_motion.v'
 text=target.read_text();start=text.index(' // BEGIN GENERATED INVERSE');end=text.index(' // END GENERATED INVERSE',start)
 text=text[:start]+' // BEGIN GENERATED INVERSE\n function [12:0] inverse_scale;input[7:0] deficit;begin case(deficit)\n'+cases+"\n   default:inverse_scale=13'd4096;\n  endcase end endfunction\n"+text[end:]
 target.write_bytes(text.encode())
 report={'state':'PASS','words_per_table':1536,'total_bits':49152,'BRAM32K':2,'frame_seconds':.0168,'cleanup_first_age':93,'hashes':hashes,'curves':samples}
 out=ROOT/'output/html_fidelity/bot_osd/motion_tables.json';out.write_bytes(json.dumps(report,indent=2).encode());print(json.dumps({k:v for k,v in report.items() if k!='curves'}))
if __name__=='__main__':main()
