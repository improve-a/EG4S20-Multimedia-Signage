#!/usr/bin/env python3
"""Experimental HFXLv1 exact BG/index + straightRGBA finite-layer payloads.
No RTL or formalmedia mutation. Source PNGs/layer_measurements are prerequisites.
"""
import argparse,hashlib,json,math,struct,zlib
from pathlib import Path
from html_fidelity_assets import png
from html_fidelity_layers import encode_png
ROLE={'chrome':0,'giant':1,'hero':2,'family':3,'data-in':4,'credit':5}
def align(v,n=4):return (v+n-1)//n*n
def role_meta(page,layer,counts):
 d=layer['dom'];cls=d['cls'];role=cls if cls in ROLE else 'data-in';i=255
 if role=='data-in':
  if cls=='kicker':i=0
  elif cls=='cn':i=1
  elif cls=='model':i=2
  elif cls=='lede':i=2 if page=='home' else 3
  elif cls=='spec':i=4+counts['spec'];counts['spec']+=1
  elif cls=='device':i=7
  elif d['tag']=='LI':i=2+counts['app'];counts['app']+=1
  else:raise AssertionError((page,cls,d))
 x,y,w,h=d['bounds'];pivot=[x+w/2,y+h/2] if role in ('hero','family') else [0,0]
 return dict(role=role,role_code=ROLE[role],i=i,paint_index=d['index'],z=6 if role=='chrome' else 0,pivot_world=pivot)
def bezier(t,p1,p2):
 if t<=0:return 0.
 if t>=1:return 1.
 lo=0.;hi=1.
 for _ in range(35):
  u=(lo+hi)/2;x=3*(1-u)**2*u*p1[0]+3*(1-u)*u*u*p2[0]+u**3
  if x<t:lo=u
  else:hi=u
 u=(lo+hi)/2;return 3*(1-u)**2*u*p1[1]+3*(1-u)*u*u*p2[1]+u**3
OUT=((.16,1),(.3,1));IO=((.76,0),(.24,1));IN=((.7,0),(.84,0))
def sweep(rects):
 if not rects:return dict(max_rgba=0,area=0,max_row_fetches=0,worst_run=0,row=0,x=0)
 ys=sorted({v for r in rects for v in (r[1],r[3])});peak=0;worst=0;maxrow=0;area=sum((r[2]-r[0])*(r[3]-r[1])for r in rects);bestrow=0;bestx=0;maxrowy=0
 for y in ys[:-1]:
  active=[r for r in rects if r[1]<=y<r[3]];rowfetch=sum(r[2]-r[0]for r in active)
  if rowfetch>maxrow:maxrow=rowfetch;maxrowy=y
  ev={}
  for x0,_,x1,_ in active:ev[x0]=ev.get(x0,0)+1;ev[x1]=ev.get(x1,0)-1
  xx=sorted(ev);count=0
  for j in range(len(xx)-1):
   count+=ev[xx[j]];width=xx[j+1]-xx[j]
   if count>peak:peak=count;worst=width;bestrow=y;bestx=xx[j]
   elif count==peak and width>worst:worst=width;bestrow=y;bestx=xx[j]
 return dict(max_rgba=peak,area=area,max_row_fetches=maxrow,max_row_fetches_row=maxrowy,worst_run=worst,row=bestrow,x=bestx)
def rects_at(comps,t,phase,direction):
 q=bezier(min(1,t/1.05),*IO);clip=(640*(1-q),640) if direction==1 else (0,640*q)
 if phase=='leave':clip=(0,clip[0]) if direction==1 else (clip[1],640)
 rects=[]
 for c in comps:
  x,y,w,h=c['bbox'];x1=x+w;y1=y+h;role=c['role'];opacity=1.
  if phase=='entry':
   if role in ('hero','family'):
    e=bezier(t/1.5,*OUT);opacity=e;sc=.965+.035*e;px,py=c['pivot_world'];x=px+(x-px)*sc+direction*70*(1-e);x1=px+(x1-px)*sc+direction*70*(1-e);y=py+(y-py)*sc;y1=py+(y1-py)*sc
   elif role=='giant':e=bezier(t/1.7,*OUT);x+=120*(1-e);x1+=120*(1-e)
   elif role=='data-in':e=bezier((t-(.38+.07*c['i']))/.9,*OUT);opacity=e;y+=14*(1-e);y1+=14*(1-e)
  else:
   if role in ('hero','family','giant'):x-=46*q;x1-=46*q;opacity=1-.75*q
   elif role=='data-in':e=bezier(t/.45,*IN);x-=10*e;x1-=10*e;opacity=1-e
  if opacity<=0:continue
  xx0=max(0,math.floor(max(x,clip[0])));xx1=min(640,math.ceil(min(x1,clip[1])));yy0=max(0,math.floor(y));yy1=min(480,math.ceil(y1))
  if xx1>xx0 and yy1>yy0:rects.append((xx0,yy0,xx1,yy1))
 return rects

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--layers',type=Path,required=True);ap.add_argument('--reference-assets',type=Path,required=True);a=ap.parse_args();out=a.layers;report=json.loads((out/'layer_measurements.json').read_text(encoding='utf8'));setid=0 # Final content ID is stamped after all six payloads exist.
 schema={'name':'HFXL','version':1,'endianness':'little endian32bitwords','set_id':setid,'magic_word':0x4c584648,'header_words':64,'header_fields':{'0':'magic','1':'version1','2':'padded_payload_words','3':'component_count','4':'descriptor_word_offset64','5':'descriptor_stride_words8','6':'bg_word_offset','7':'bg_row_stride214','8':'palette_word_offset','9':'actual_palette_entries<=512','10':'width640','11':'height480','12':'first_component_texture_word_offset','13':'set_id','14':'global_word_base','15':'page_index'},'descriptor_words':8,'descriptor_fields':{'0':'role[7:0],i[15:8],originalDOMpaintindex[23:16],z[31:24]','1':'signedworldx16lo,y16hi','2':'width16lo,height16hi','3':'texturewordoffset relativepagebase','4':'signedpivotworldQ12.4 x16lo,y16hi (originalDOMtransformorigin)','5':'reserved0','6':'texelcount','7':'reserved0'},'role_codes':ROLE,'bg':'3exactindices/word bits9:0,19:10,29:20;top2bits0;214words/row;lastwordlanes1/2zero','palette':'fixed512words RRGGBB00,unusedentrieszero','component':'straightRGBA8888 wordRRGGBBAA,tightrowmajor;regionbase4wordaligned','alignment':'pagebase andregionbase4words;wholepagepadded256words','paint_order':'descriptorsequence alreadyCSSback-to-front;chromez6last','scope':'Experimental runtimepayload only; formalBMP/media untouched; softwarecomposites NEVER DUT'}
 (out/'hfxl_schema.json').write_text(json.dumps(schema,indent=2),encoding='utf8');globalwords=[];pages=[]
 for pidx,page in enumerate(report['pages']):
  counts={'spec':0,'app':0};comps=[]
  for l in page['layers']:
   if l['dom']['cls']=='bg':continue
   c=role_meta(page['page'],l,counts);c.update(name=l['name'],bbox=l['motion_guard_bounds'],source_rgba_png=l['name']+'_crop.png',source_rgba_bounds=l['bounds_rgba_alpha']);comps.append(c)
  comps.sort(key=lambda c:(c['z'],c['paint_index']));assert len(comps)<=16
  desc_off=64;palette_off=align(desc_off+8*len(comps));bg_off=palette_off+512;tex_off=align(bg_off+214*480);words=[0]*tex_off
  bg=page['layers'][0];w,h,r=png(out/(bg['name']+'_crop.png'));rgb=[tuple(r[(yy*w+xx)*4:(yy*w+xx)*4+3])for yy in range(480)for xx in range(640)];colors=sorted(set(rgb));assert len(colors)<=512;lookup={c:i for i,c in enumerate(colors)}
  for i,(rr,gg,bb) in enumerate(colors):words[palette_off+i]=(rr<<24)|(gg<<16)|(bb<<8)
  for yy in range(480):
   for group in range(214):
    val=0
    for lane in range(3):
     xx=group*3+lane
     if xx<640:val|=lookup[rgb[yy*640+xx]]<<(lane*10)
    words[bg_off+yy*214+group]=val
  for ci,c in enumerate(comps):
   words.extend([0]*(align(len(words))-len(words)));start=len(words);w,h,r=png(out/c['source_rgba_png']);x,y,cw,ch=c['bbox'];ox,oy,_,_=c['source_rgba_bounds']
   for yy in range(y,y+ch):
    for xx in range(x,x+cw):
     i=((yy-oy)*w+xx-ox)*4;rr,gg,bb,aa=r[i:i+4];words.append((rr<<24)|(gg<<16)|(bb<<8)|aa)
   c['texture_word_offset']=start;c['texels']=cw*ch;flags=c['role_code']|(c['i']<<8)|(c['paint_index']<<16)|(c['z']<<24);px,py=c['pivot_world'];desc=[flags,(x&65535)|((y&65535)<<16),cw|(ch<<16),start,(round(px*16)&65535)|((round(py*16)&65535)<<16),0,cw*ch,0];words[desc_off+ci*8:desc_off+ci*8+8]=desc;c['descriptor_words']=desc
  words.extend([0]*(align(len(words),256)-len(words)));words[:16]=[0x4c584648,1,len(words),len(comps),64,8,bg_off,214,palette_off,len(colors),640,480,tex_off,setid,len(globalwords),pidx]
  base=len(globalwords);globalwords.extend(words);binary=struct.pack('<'+'I'*len(words),*words);f=out/f'scene_{pidx+1:02d}_{page["page"]}.hfxl.bin';f.write_bytes(binary)
  static=[]
  for c in comps:
   x,y,cw,ch=c['bbox'];static.append((max(0,x),max(0,y),min(640,x+cw),min(480,y+ch)))
  st=sweep(static);profiles=[]
  for yy in range(480):
   ss=sweep([(x0,yy,x1,yy+1)for x0,y0,x1,y1 in static if y0<=yy<y1]);profiles.append({'y':yy,'max_rgba':ss['max_rgba'],'mean_rgba':ss['area']/640,'rgba_fetchtexels':ss['max_row_fetches'],'longest_peak_run':ss['worst_run'],'peak_run_x':ss['x']})
  (out/(page['page']+'_row_overlap.json')).write_text(json.dumps(profiles,indent=2),encoding='utf8');dynamic=[]
  for direction in [-1,1]:
   for phase in ['entry','leave']:
    for frame in range(103):
     rr=[dict(component_index=ci,name=c['name'],bbox=list(rect)) for ci,c in enumerate(comps) for rect in rects_at([c],frame/60,phase,direction)];d=sweep([tuple(z['bbox'])for z in rr]);d.update(frame=frame,seconds=frame/60,phase=phase,direction=direction,rectangles=rr);dynamic.append(d)
  peak=max(dynamic,key=lambda d:(d['max_rgba'],d['worst_run']));rowpeak=max(dynamic,key=lambda d:d['max_row_fetches']);(out/(page['page']+'_dynamic_bbox.json')).write_text(json.dumps(dynamic,indent=2),encoding='utf8')
  # Localerrors compare settled source-layer software reconstruction, neverDUT.
  _,_,recon=png(out/(page['page']+'_source_layers_reconstructed.png'));_,_,ref=png(a.reference_assets/f'A_{pidx+1:02d}_{page["page"]}.png');regions={}
  for c in comps+[dict(name='pure_background_bottom100',bbox=[0,380,640,100])]:
   x,y,cw,ch=c['bbox'];errs=[]
   for yy in range(max(0,y),min(480,y+ch)):
    for xx in range(max(0,x),min(640,x+cw)):
     i=(yy*640+xx)*4;errs.extend(abs(recon[i+k]-ref[i+k])for k in range(3))
   regions[c['name']]={'max_rgb_error':max(errs,default=0),'mean_rgb_error':sum(errs)/max(1,len(errs)),'nonzero_rgb_components':sum(e!=0 for e in errs)}
  pageinfo=dict(page=page['page'],page_index=pidx,path=f.name,sha256=hashlib.sha256(binary).hexdigest(),global_word_base=base,payload_words=len(words),payload_bytes=len(binary),component_count=len(comps),descriptor_word_offset=64,bg_word_offset=bg_off,bg_stride_words=214,palette_word_offset=palette_off,palette_entries=len(colors),components=comps,static_bbox_stats=st,dynamic_peak_overlap=peak,dynamic_peak_row_fetches=rowpeak,source_only_local_error=regions)
  pages.append(pageinfo);print(json.dumps({'page':page['page'],'bytes':len(binary),'component_count':len(comps),'dynamic_max_rgba':peak['max_rgba'],'max_row_fetches':rowpeak['max_row_fetches']}),flush=True)
 binary=struct.pack('<'+'I'*len(globalwords),*globalwords);(out/'hfxl_global_atlas.bin').write_bytes(binary);(out/'hfxl_global_atlas.hex').write_text(''.join(f'{v:08x}\n'for v in globalwords),encoding='ascii')
 manifest=dict(experimental=True,set_id=setid,source_sha256=report['source_sha256'],schema_sha256=hashlib.sha256((out/'hfxl_schema.json').read_bytes()).hexdigest(),pages=pages,total_words=len(globalwords),total_payload_bytes=len(binary),existing_six_page_word_budget=1843200,within_existing_six_page_budget=len(globalwords)<=1843200,compare_panel_base_words=1843200,compare_panel_bytes=999424,total_bytes_plus_existing_panels=len(binary)+999424,sdram_bytes=8388608,spare_bytes=8388608-len(binary)-999424,global_sha256=hashlib.sha256(binary).hexdigest(),dynamic_sampling='frames0..102@60Hz eachentry/leave anddirection±1, originalCSSBezier,apertureclips,alpha0disabled; bboxconservative,notDUT')
 (out/'hfxl_payload_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8');print(json.dumps({k:v for k,v in manifest.items()if k!='pages'},indent=2))
 from html_fidelity_seal_atlas import seal
 seal(out)
if __name__=='__main__':main()
