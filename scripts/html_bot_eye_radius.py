"""Exact analytic Q4 ellipse radii; numeric ROM, not animation/image frames."""
import argparse,hashlib,json,math
from pathlib import Path

def words():
 values=[0]*1024
 for rx in [6,7,8]:
  for ry in range(1,8):
   height=(ry-.5)*16;radius=(rx-.5)*16
   for row in range(32):
    y=row*4+2
    if y<height:values[((rx-6)<<8)|(ry<<5)|row]=math.floor(radius*math.sqrt(1-(y/height)**2)+.5)
 return values

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output-dir',type=Path,required=True);a=ap.parse_args();a.output_dir.mkdir(parents=True,exist_ok=True)
 values=words();outputs={'html_eye_radius.hex':''.join(f'{x:03x}\n' for x in values).encode(),'html_eye_radius.hex.bin':''.join(f'{x:09b}\n' for x in values).encode()}
 for name,data in outputs.items():(a.output_dir/name).write_bytes(data)
 print(json.dumps({'words':1024,'physical_bits':9216,'reachable':672,'outputs':{n:hashlib.sha256(d).hexdigest() for n,d in outputs.items()}},indent=2))
if __name__=='__main__':main()
