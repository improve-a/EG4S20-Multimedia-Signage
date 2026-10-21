"""Lossless column descriptors for fixed-layout prototype glyph runs."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'rtl/ext/html_assets'
PAT=re.compile(r"if\(x>=10'd(\d+) && x<10'd(\d+) && y>=10'd(\d+) && y<10'd(\d+)\) begin is_text=1;is_caption=1'b([01]);glyph_id=8'd(\d+);glyph_x=x-10'd(\d+);glyph_y=y-10'd(\d+);char_index=7'd(\d+);end")
def main():
 source=(ASSET/'html_caption_map.v').read_text();layouts={};current=None
 for line in source.splitlines():
  m=re.match(r"4'd(\d+): begin total_chars",line)
  if m:current=int(m.group(1));layouts[current]=[]
  m=PAT.fullmatch(line)
  if m:layouts[current].append(tuple(map(int,m.groups())))
 if set(layouts)!=set(range(6))|set(range(8,14)):raise ValueError(f'unexpected layout keys {layouts.keys()}')
 words=[];blank=255<<10
 def band(runs,y,x0,width):
  out=[blank]*width
  for lo,hi,top,bottom,caption,glyph,gx,gy,ordinal in runs:
   if top!=y:continue
   if lo<x0 or hi>x0+width:raise ValueError(f'run outside band {lo,hi,y}')
   if ordinal>63 or gx!=lo or gy!=top:raise ValueError('descriptor cannot encode run')
   for x in range(lo,hi):out[x-x0]=(glyph<<10)|((gx&15)<<6)|ordinal
  return out
 ordered=[layouts[i] for i in range(6)]+[layouts[i] for i in range(8,14)]
 for runs in ordered:words+=band(runs,416,42,392)+band(runs,435,42,168)
 for runs in ordered[:6]:words+=band(runs,397,42,128)
 header=band(ordered[6],397,42,128)
 if any(band(x,397,42,128)!=header for x in ordered[6:]):raise ValueError('dual headers not shared')
 words+=header
 for page,runs in enumerate(ordered[:6]):
  a=band(runs,22,528,80);b=band(runs,23,528,80)
  merged=[y if y!=blank else x for x,y in zip(a,b)]
  a2=band(ordered[page+6],22,528,80);b2=band(ordered[page+6],23,528,80)
  if merged!=[y if y!=blank else x for x,y in zip(a2,b2)]:raise ValueError('index differs in dual mode')
  words+=merged
 audio=band(ordered[0],433,468,18)
 if any(band(x,433,468,18)!=audio for x in ordered):raise ValueError('audio labels differ')
 words+=audio
 if len(words)!=8114:raise ValueError(len(words))
 atlas=[int(x,16) for x in (ASSET/'html_glyph_coverage.hex').read_text().split()]
 if any(atlas[g*40+y*2+k] for g in range(len(atlas)//40) for y in [0,19] for k in [0,1]):raise ValueError('overlap row is not transparent')
 p=ASSET/'html_caption_columns.hex';p.write_bytes(''.join(f'{v:05x}\n' for v in words).encode('ascii'))
 p.with_suffix('.hex.bin').write_bytes(''.join(f'{v:018b}\n' for v in words).encode('ascii'))
 def ink(g,x,y):
  if g==255 or not(0<=x<16 and 0<=y<20):return 0
  return (atlas[g*40+y*2+x//8]>>(14-2*(x%8)))&3
 checked=0
 for layout,runs in enumerate(ordered):
  page=layout%6;dual=layout>=6
  for y in list(range(22,43))+list(range(397,455)):
   for x in range(42,608):
    old=None
    for lo,hi,top,bottom,c,g,gx,gy,n in runs:
     if lo<=x<hi and top<=y<bottom:old=(g,x-gx,y-gy,n,c)
    addr=None;row=0;cap=0
    if 42<=x<170 and 397<=y<417:addr=6720+(6 if dual else page)*128+x-42;row=y-397
    elif 42<=x<434 and 416<=y<435:addr=layout*560+x-42;row=y-416;cap=1
    elif 42<=x<210 and 435<=y<455:addr=layout*560+392+x-42;row=y-435;cap=1
    elif 528<=x<608 and 22<=y<43:addr=7616+page*80+x-528;row=y-(23 if x>=584 else 22)
    elif 468<=x<486 and 433<=y<453:addr=8096+x-468;row=y-433
    new=None
    if addr is not None:
     v=words[addr];g=v>>10;new=(g,(x-((v>>6)&15))&15,row,v&63,cap)
    oldink=0 if old is None else ink(*old[:3]);newink=0 if new is None else ink(*new[:3])
    if oldink!=newink:raise ValueError(f'coverage mismatch layout{layout} at{x},{y}: {old} {new}')
    if oldink and old[4] and (new[3]!=old[3] or not new[4]):raise ValueError('typewriter ordinal mismatch')
    checked+=1
 report={'state':'PASS','words':len(words),'width':18,'bits':len(words)*18,'bram9k_estimate':16,'coverage_pixel_checks':checked,
 'map_sha256':hashlib.sha256(source.encode()).hexdigest(),'column_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
 'format':'glyphID[17:10],glyphstartXlow4[9:6],characterordinal[5:0];ID255 blank; body12x560,header7x128,index6x80,audio18'}
 out=ROOT/'output/html_fidelity/bot_osd/caption_columns_generation.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2));print(json.dumps(report))
if __name__=='__main__':main()
