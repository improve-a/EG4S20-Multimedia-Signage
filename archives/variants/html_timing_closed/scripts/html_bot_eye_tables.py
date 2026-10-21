"""Exact factored ellipse radii: one normalized lookup and two shared DSPs.
For eachry/row, choose aQ12 factor in the intersection of all three rounded
radius intervals. Thus rx6/7/8 outputs are exactly the original analytic table.
"""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 lines=[" function [12:0] eye_unit;input[7:0] code;begin case(code)"];checked=0
 for ry in range(1,8):
  h=(ry-.5)*16
  for row in range(32):
   y=row*4+2
   if y>=h:continue
   unit=math.sqrt(1-(y/h)**2);lo=0;hi=4096
   for rx in [6,7,8]:
    r=(rx-.5)*16;wanted=math.floor(r*unit+.5)
    lo=max(lo,math.ceil((wanted-.5)*4096/r));hi=min(hi,math.ceil((wanted+.5)*4096/r)-1)
   if lo>hi:raise ValueError('noexactcommonQ12factor')
   factor=min(hi,max(lo,math.floor(unit*4096+.5)))
   for rx in [6,7,8]:
    r=(rx-.5)*16
    if (int(r)*factor+2048)//4096!=math.floor(r*unit+.5):raise ValueError('radiuschanged')
    checked+=1
   lines.append(f"   8'd{(ry<<5)|row}:eye_unit=13'd{factor};")
 lines+=["   default:eye_unit=0;endcase end endfunction",
 " function [6:0] eye_edge;input[12:0] code;",
 " reg[12:0] unit;reg[7:0] radius;reg[20:0] product;begin",
 "  unit=eye_unit(code[7:0]);radius={code[12:9],4'b0}-8'd8;",
 "  product=unit*radius+21'd2048;eye_edge=product[18:12];",
 " end endfunction"]
 f=ROOT/'rtl/ext/html_bot_overlay.v';s=f.read_text(encoding='utf8');a=s.index(' // BEGIN GENERATED EYE TABLES');b=s.index(' // END GENERATED EYE TABLES',a)
 s=s[:a]+' // BEGIN GENERATED EYE TABLES\n'+'\n'.join(lines)+'\n'+s[b:];f.write_bytes(s.encode())
 out=ROOT/'output/html_fidelity/bot_osd/eye_radius_factor_proof.json';out.write_bytes(json.dumps({'state':'PASS','factor_words':98,'rounded_nonzero_radii_identical':checked,'zero_default_radii':378,'factor_fraction_bits':12,'max_pixel_geometry_error_from_factor':0},indent=2).encode());print('ExactradiusfactorizationPASS',checked,'nonzero radii plus378zero entries')
if __name__=='__main__':main()
