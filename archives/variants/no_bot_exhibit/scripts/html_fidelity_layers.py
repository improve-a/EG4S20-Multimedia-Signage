#!/usr/bin/env python3
"""Experimental finite component atlas measurement, never deployment media.
Installed Chrome renders original layers with128px transparent gutter; alpha
bounds include soft shadows and offstage pixels. Original A/BMPs stay untouched.
"""
import argparse,collections,hashlib,html,json,math,re,struct,subprocess,time,zlib
from pathlib import Path
from html_fidelity_assets import png

def encode_png(path,w,h,rgba):
 def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v)&0xffffffff)
 raw=b''.join(b'\0'+rgba[y*w*4:(y+1)*w*4] for y in range(h));path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--prototype',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--finalize-only',action='store_true');ap.add_argument('--reference-assets',type=Path);ap.add_argument('--chrome',default='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');a=ap.parse_args();out=a.out;out.mkdir(parents=True,exist_ok=True)
 if a.finalize_only:
  finalize(out,a.reference_assets);return
 original=(a.prototype/'anlogic-exhibit.html').read_text(encoding='utf8');source=original.replace('<script>','<script>window.requestAnimationFrame=()=>0;Math.random=()=>.5;</script><script>',1)
 css='''<style>html,body{margin:0!important;width:896px!important;height:736px!important;background:transparent!important;display:block!important;overflow:hidden!important}.viewport{position:absolute;left:0;top:0;padding:0!important;display:block!important;width:896px;height:736px;min-height:0!important}.frame{position:absolute;left:0;top:0;width:896px!important;height:736px!important;background:transparent!important;box-shadow:none!important}#stage{left:128px!important;top:128px!important;transform:none!important;overflow:visible!important;background:transparent!important}#osd,#bot,.panel,.viewport-meta{display:none!important}*,*::before,*::after{animation:none!important;transition:none!important}</style>'''
 src=source.replace('</head>',css+'</head>');profile=out/'chrome_profile';rows=[]
 # Each selector is a disjoint hierarchy leaf/group, so no parent/child double counting.
 common=['.bg','.chrome','.giant','.hero','.family'];records=[]
 for page,name in enumerate(['home','eagle','phoenix','elf','dragon','eco']):
  sels=common+['[data-in]','.credit'];layers=[]
  # One DOM export provides all actual element bounds and styles.
  js=f'''S.playing=false;scenes.forEach(s=>s.style.display='none');let sc=scenes[{page}];sc.style.display='block';sc.className='scene '+PAGES[{page}].cls+' on';let list=[...sc.querySelectorAll('.bg,.chrome,.giant,.hero,.family,[data-in],.credit')];list.forEach((e,i)=>e.dataset.layerIndex=i);let rr=list.map((e,i)=>{{let r=e.getBoundingClientRect(),c=getComputedStyle(e);return{{index:i,tag:e.tagName,cls:e.className,text:e.textContent.trim(),bounds:[r.x-128,r.y-128,r.width,r.height],display:c.display,color:c.color,filter:c.filter,transform:c.transform}}}});document.body.insertAdjacentHTML('beforeend','<pre id="export">'+JSON.stringify(rr)+'</pre>');'''
  f=out/'measure.html';f.write_text(src.replace('</body>','<script>'+js+'</script></body>'),encoding='utf8');cmd=[a.chrome,'--headless','--disable-gpu','--no-first-run',f'--user-data-dir={profile}','--dump-dom',f.as_uri()];r=subprocess.run(cmd,capture_output=True,text=True,check=True);m=re.findall('<pre id="export">(.*?)</pre>',r.stdout,re.S);dom=json.loads(html.unescape(m[-1]));(out/f'{name}_dom.json').write_text(json.dumps(dom,ensure_ascii=True,indent=2),encoding='utf8')
  overlap=bytearray(640*480);component_texels=0;component_nonzero=0;background=None
  for d in dom:
   if d['display']=='none':continue
   index=d['index'];layername=f'{page+1:02d}_{name}_{index:02d}';target=out/(layername+'.png');t=time.monotonic()
   show=f'''S.playing=false;scenes.forEach(s=>s.style.display='none');let sc=scenes[{page}];sc.style.display='block';sc.className='scene '+PAGES[{page}].cls+' on';let list=[...sc.querySelectorAll('.bg,.chrome,.giant,.hero,.family,[data-in],.credit')];let keep=list[{index}];sc.querySelectorAll('*').forEach(e=>{{if(e!==keep&&!e.contains(keep)&&!keep.contains(e))e.style.visibility='hidden';}});'''
   f=out/'render_layer.html';f.write_text(src.replace('</body>','<script>'+show+'</script></body>'),encoding='utf8');cmd=[a.chrome,'--headless','--disable-gpu','--no-first-run','--hide-scrollbars','--force-device-scale-factor=1','--default-background-color=00000000',f'--user-data-dir={profile}','--window-size=896,736','--virtual-time-budget=250',f'--screenshot={target}',f.as_uri()];pr=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE);pid=pr.pid;stdout,stderr=pr.communicate(timeout=40);(out/(layername+'.log')).write_bytes(stdout+stderr);assert pr.returncode==0
   w,h,rgba=png(target);assert(w,h)==(896,736);xs=[];ys=[];rgb=set();rgb565=set();alphacount=0;minx=w;maxx=-1;miny=h;maxy=-1
   for y in range(h):
    for x in range(w):
     q=(y*w+x)*4;al=rgba[q+3]
     if not al:continue
     alphacount+=1;minx=min(minx,x);maxx=max(maxx,x);miny=min(miny,y);maxy=max(maxy,y);rr,gg,bb=rgba[q:q+3];rgb.add((rr,gg,bb));rgb565.add(((rr>>3)<<11)|((gg>>2)<<5)|(bb>>3))
     xx=x-128;yy=y-128
     if 0<=xx<640 and 0<=yy<480:overlap[yy*640+xx]+=1
   if maxx<0:continue
   bounds=[minx-128,miny-128,maxx-minx+1,maxy-miny+1];texels=bounds[2]*bounds[3];rec=dict(name=layername,dom=d,bounds_rgba_alpha=bounds,cropped_texels=texels,nonzero_alpha_texels=alphacount,rgb_colors=len(rgb),rgb565_colors=len(rgb565),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),renderer_pid=pid,renderer_exit=pr.returncode,wall_seconds=time.monotonic()-t)
   # Tight alpha crop is the actual proposed texture, retained independently.
   crop=b''.join(rgba[(y*w+minx)*4:(y*w+maxx+1)*4] for y in range(miny,maxy+1));encode_png(out/(layername+'_crop.png'),bounds[2],bounds[3],crop)
   if d['cls']=='bg':background=rec;rec['lossless_rgb_index_bits']=max(1,math.ceil(math.log2(len(rgb))));rec['lossless_index_bytes']=math.ceil(texels*rec['lossless_rgb_index_bits']/8)+len(rgb)*3
   else:component_texels+=texels;component_nonzero+=alphacount
   layers.append(rec);print(json.dumps({'page':name,'layer':index,'crop':bounds,'texels':texels}),flush=True)
  assert background
  bgtex=background['cropped_texels'];budget=307200*4
  records.append(dict(page=name,layers=layers,component_cropped_texels=component_texels,component_nonzero_texels=component_nonzero,background_cropped_texels=bgtex,max_overlap_including_background=max(overlap),budget_bytes=budget,budget_options={'RGBA32_components_plus_RGB888_background':component_texels*4+bgtex*3,'RGBA32_components_plus_lossless_indexed_background':component_texels*4+background['lossless_index_bytes'],'RGB565_A8_components_plus_RGB565_background':component_texels*3+bgtex*2,'ARGB4444_components_plus_RGB565_background':component_texels*2+bgtex*2},motion={'hero_family_source_guard_px':70,'giant_source_guard_px':46,'copy_spec_apps_device_rise_px':14,'page_wipe_seconds':1.05,'hero_entry_seconds':1.5,'giant_entry_seconds':1.7,'data_in_entry_seconds':.9,'data_in_delay_seconds':'.38+i*.07'}))
  (out/'layer_measurements.json').write_text(json.dumps(dict(experimental=True,source_sha256=hashlib.sha256(original.encode()).hexdigest(),renderer=subprocess.check_output([a.chrome,'--version'],text=True).strip(),stage=[640,480],gutter=128,pages=records,notes=['No deployment A/media/RTL changes. Layer bounds include rendered shadows beyond viewport.','Raw full opacity background counted separately. Lossless indexed option measures actual RGB color count, no invented gradient simplification.','RGB565/A8 and ARGB4444 options have explicit color/alpha quantization; no pixel-identical claim.','Atlas packing/layout and memory transactions are design decisions pending resource probe.']),indent=2),encoding='utf8')
 print('LAYER_MEASUREMENTS_DONE '+str(out),flush=True)
def finalize(out,reference_assets=None):
 report=json.loads((out/'layer_measurements.json').read_text(encoding='utf8'));summaries=[]
 for page in report['pages']:
  coverage=[0]*(640*480);rgba_canvas=bytearray(640*480*4);total_guard=0;total_strip=0;pieces_count=0;nonzero=0
  for layer in sorted(page['layers'],key=lambda l:6 if l['dom']['cls']=='chrome' else 0):
   w,h,pixels=png(out/(layer['name']+'_crop.png'));x,y,bw,bh=layer['bounds_rgba_alpha'];x0=x;x1=x+bw;y0=y;y1=y+bh;bg=layer['dom']['cls']=='bg'
   if 'giant' in layer['dom']['cls']:x0=max(x0,-48);x1=min(x1,688)
   if layer['dom']['cls'] in ('hero','family'):x0=max(x0,-72);x1=min(x1,712)
   layer['motion_guard_bounds']=[x0,y0,x1-x0,y1-y0]
   if not bg:total_guard+=(x1-x0)*(y1-y0)
   # Preserve all nonzero pixels exactly while discarding fully transparent rows.
   bands=[];start=None
   for yy in range(y0,y1+1):
    present=yy<y1 and any(pixels[((yy-y)*w+xx-x)*4+3] for xx in range(x0,x1))
    if present and start is None:start=yy
    if not present and start is not None:
     end=yy;lo=x1;hi=x0
     for ry in range(start,end):
      for xx in range(x0,x1):
       if pixels[((ry-y)*w+xx-x)*4+3]:lo=min(lo,xx);hi=max(hi,xx+1)
     bands.append([lo,start,hi-lo,end-start]);start=None
   layer['lossless_zero_row_pieces']=bands
   if not bg:total_strip+=sum(b[2]*b[3]for b in bands);pieces_count+=len(bands)
   for yy in range(max(y0,0),min(y1,480)):
    for xx in range(max(x0,0),min(x1,640)):
     if not bg:coverage[yy*640+xx]+=1
     off=((yy-y)*w+xx-x)*4;rr,gg,bb,al=pixels[off:off+4]
     if not al:continue
     q=(yy*640+xx)*4
     for c,val in enumerate((rr,gg,bb)):rgba_canvas[q+c]=(val*al+rgba_canvas[q+c]*(255-al)+127)//255
     rgba_canvas[q+3]=255
  bg=page['layers'][0];colors=bg['rgb_colors'];three_index_row_words=(640+2)//3;bg3=three_index_row_words*480*4+colors*4
  descbytes=pieces_count*32 # Conservative8word descriptor/piece, parent animation shared.
  packed=((total_strip*4+15)//16*16)+bg3+descbytes
  result=dict(page=page['page'],component_guard_texels=total_guard,component_zero_row_piece_texels=total_strip,pieces=pieces_count,background_colors=colors,background_index_bits=bg['lossless_rgb_index_bits'],bg_three_indices_per_word_bytes=bg3,component_rgba32_bytes=total_strip*4,descriptors_bytes_conservative=descbytes,total_bytes_three_index_rgba32=packed,budget_bytes=1228800,spare_bytes=1228800-packed,bbox_max_overlap_including_bg=max(coverage)+1,mean_component_bbox_fetches=sum(coverage)/307200,alpha_max_overlap_including_bg=page['max_overlap_including_background'])
  if reference_assets:
   clean=reference_assets/('A_'+str(len(summaries)+1).zfill(2)+'_'+page['page']+'.png');rw,rh,ref=png(clean);assert(rw,rh)==(640,480);err=[abs(rgba_canvas[i]-ref[i])for i in range(len(ref))if i%4!=3];result['source_only_reconstruction']={'max_rgb_error':max(err),'mean_rgb_error':sum(err)/len(err),'nonzero_rgb_components':sum(e!=0 for e in err),'scope':'Software recomposition of exportedsource layers, NEVER DUT output'}
   encode_png(out/(page['page']+'_source_layers_reconstructed.png'),640,480,rgba_canvas)
  summaries.append(result)
 report['packing_plan']=summaries;report['packing_notes']=['Lossless9bit(or10bit)indices:3indices/32bitword,214words/row; palette stores one originalRGB24 per32bitword. Eco8bit still uses common3index layout.','Independent component RGBA8888 retains color+8bitalpha, no photos/glyph quantization. Fullytransparent row gaps split into pieces sharing originalparent animation; no semantic layer removed.','Giant retains sourcex<=688 (46pxleave plus2pxfilterguard); hero/family retainx<=712 (70pxreverse entry plus2). Furtheroffstage pixels never enter viewport under originalCSS transforms.','Descriptors conservatively8words32bytes/piece. Final hardware/addressing/alpha blending/bandwidth NOT implemented by this experiment.','BBoxfetchcounts are currentstaticplacement; entrance/leave/wipe can change overlap, and metadata/cachetraffic is additional.']
 (out/'layer_measurements.json').write_text(json.dumps(report,indent=2),encoding='utf8');(out/'packing_summary.json').write_text(json.dumps(summaries,indent=2),encoding='utf8')
 print(json.dumps(summaries,indent=2))

if __name__=='__main__':main()
