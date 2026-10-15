#!/usr/bin/env python3
"""Actual layer pixel-engine 25/40MHz proof with source-side exact RGBA oracle.

Geometry inputs are generated from settled source descriptors, so this suite
verifies the physical4-beat cache, input joins, blending and video FIFO cadence;
it does not claim frontend, natural animation or complete system coverage.
"""
import argparse,datetime,hashlib,json,os,pathlib,struct,subprocess,sys,time
NAMES=['home','eagle','phoenix','elf','dragon','eco','home_zoom3','eagle_zoom2','eagle_zoom3','compare12','compare34']
SOURCES=['tests/html_layer_engine_full_tb.v','rtl/ext/html_layer_pixel_engine.v','rtl/ext/html_layer_cache.v','rtl/ext/html_layer_join_ram.v','rtl/ext/html_layer_blend.v']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def blend(bg,fg):
 a=fg&255
 return sum((((((fg>>(8+sh))&255)*a+((bg>>sh)&255)*(255-a)+127)//255)<<sh) for sh in(0,8,16))
def fixture(out,pages,words,name):
 packed=name.startswith('compare');page=pages[0] if packed else next(p for p in pages if p['page']==name.split('_')[0]);div=3 if name.endswith('zoom3') else 2 if name.endswith('zoom2') else 1
 lines=[];gold=[];base=page['global_word_base'];ox=640*(div-1)//2;oy=480*(div-1)//2
 for y in range(480):
  sy=(y+oy)//div;active=[c for c in page['components'] if c['bbox'][1]<=sy<c['bbox'][1]+c['bbox'][3]];x=0
  while x<640:
   sx=(x+ox)//div;run=min(div-(x+ox)%div,640-x);aa=[];bg=lane=da=half=0;pindex=page['page_index']
   if packed:
    pindex=(1 if name=='compare12' else 3)+(sx>=320);xh=sx%320;pb=1843200+(pindex-1)*62464
    da=pb+(sy*160+xh//2 if sy<384 else 61440+(sy-384)//4*40+xh//8);half=xh%2 if sy<384 else (xh//4)%2
    v=(words[da]>>(16*half))&65535;rr=v>>11;gg=(v>>5)&63;bb=v&31;rgb=((rr<<3|rr>>2)<<16)|((gg<<2|gg>>4)<<8)|(bb<<3|bb>>2)
   else:
    bg=base+page['bg_word_offset']+sy*214+sx//3;lane=sx%3;idx=(words[bg]>>(10*lane))&1023;rgb=words[base+page['palette_word_offset']+idx]>>8
    for c in active:
     xx,yy,w,h=c['bbox']
     if xx<=sx<xx+w:
      a=base+c['texture_word_offset']+(sy-yy)*w+sx-xx;aa.append(a);rgb=blend(rgb,words[a])
   n=len(aa)
   if n>2:raise ValueError('source violates finite two-RGBA contract')
   aa+=[0]*(2-n);fields=[(pindex,3),(bg,21),(lane,2),(run,2),(n,2),(aa[0],21),(aa[1],21),(255,8),(255,8),(0,1),(int(packed),1),(half,1),(0,1),(da,21)];v=0
   for value,width in fields:v=(v<<width)|value
   lines.append(f'{v:029x}\n');gold.extend([f'{rgb<<8:08x}\n']*run);x+=run
 (out/(name+'_descriptors.hex')).write_text(''.join(lines));(out/(name+'_gold.hex')).write_text(''.join(gold))
 return {'case':name,'page':page['page_index'],'divisor':div,'contexts':len(lines),'logical_pixels':len(gold),'fixture_sha256':{f:sha(out/f) for f in [name+'_descriptors.hex',name+'_gold.hex']}}
def mixed_fixture(out,pages,words):
 def blend(bg,fg,op):
  a=((fg&255)*op+127)//255
  return sum(((((fg>>(8+shift))&255)*a+((bg>>shift)&255)*(255-a)+127)//255)<<shift for shift in (0,8,16))
 records=[];expected=[]
 def record(fields,rgb,repeat):
  v=0
  for value,width in fields:v=(v<<width)|(value&((1<<width)-1))
  records.append(v);expected.extend([(rgb<<8)]*repeat)
 for div in (1,2,3):
  for p in pages:
   base=p['global_word_base'];ox=640*(div-1)//2
   for y in ([26,88,120,195,280,294,334,350,360,459] if div==1 else [280,350]):
    x=0
    while x<640:
     sx=(x+ox)//div;run=min(div-((x+ox)%div),640-x);sy=y
     bg=base+p['bg_word_offset']+sy*214+sx//3;lane=sx%3;idx=(words[bg]>>(lane*10))&1023
     rgb=words[base+p['palette_word_offset']+idx]>>8;rgba=[];opacity=[]
     for c in p['components']:
      xx,yy,w,h=c['bbox']
      if xx<=sx<xx+w and yy<=sy<yy+h:
       a=base+c['texture_word_offset']+(sy-yy)*w+sx-xx;op=127 if len(records)%3==0 else 201 if len(records)%7==0 else 255
       rgba.append(a);opacity.append(op);rgb=blend(rgb,words[a],op)
     assert len(rgba)<=2;rc=len(rgba);rgba+=[0]*(2-rc);opacity+=[255]*(2-rc)
     fields=[(p['page_index'],3),(bg,21),(lane,2),(run,2),(rc,2),(rgba[0],21),(rgba[1],21),(opacity[0],8),(opacity[1],8),(0,1),(0,1),(0,1),(0,1),(0,21)]
     record(fields,rgb,run);x+=run
 # Direct RGB shares the same path/cache, no duplicate old bridge.
 for a in [0,648,103368,275200+672,1514240+640,1843199]:
  if a>=len(words):continue
  record([(0,3),(0,21),(0,2),(2,2),(0,2),(0,21),(0,21),(255,8),(255,8),(1,1),(0,1),(0,1),(0,1),(a,21)],words[a]>>8,2)
 for p in range(1,5):
  for y in [0,383,384,479]:
   for x in [0,1,2,7,319]:
    a=1843200+(p-1)*62464+(y*160+x//2 if y<384 else 61440+(y-384)//4*40+x//8);half=x%2 if y<384 else(x//4)%2
    v=(words[a]>>(half*16))&65535;rgb=((v>>11)*255//31)<<16|(((v>>5)&63)*255//63)<<8|(v&31)*255//31
    # Match standard bit replication, not a separate scaling convention.
    rr=v>>11;gg=(v>>5)&63;bb=v&31;rgb=((rr<<3|rr>>2)<<16)|((gg<<2|gg>>4)<<8)|(bb<<3|bb>>2)
    record([(p,3),(0,21),(0,2),(3,2),(0,2),(0,21),(0,21),(255,8),(255,8),(0,1),(1,1),(half,1),(0,1),(a,21)],rgb,3)
 (out/'descriptors.hex').write_text(''.join(f'{v:029x}\n' for v in records));(out/'expected.hex').write_text(''.join(f'{v:08x}\n' for v in expected));(out/'fixtures.json').write_text(json.dumps({'records':len(records),'logicalpixels':len(expected),'scope':'actual HFXL settled texels plus scalar opacity/zoom repetitions, packed top/footer and directRGB. Geometry frontend supplied as fixtures, not DUT.'},indent=2))
 return {'case':'mixed_unit','contexts':len(records),'logical_pixels':len(expected),'fixture_sha256':{f:sha(out/f) for f in ['descriptors.hex','expected.hex']}}

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1]);ap.add_argument('--run-id',default=datetime.datetime.now(datetime.timezone.utc).strftime('layer_render_%Y%m%dT%H%M%S%fZ'));ap.add_argument('--case',action='append',choices=NAMES);ap.add_argument('--slots',type=int,choices=[8,16],default=8);ap.add_argument('--write-cycles',type=int,default=0,help='Whole bridge physical writer holds bus this many cycles whenever idle');ap.add_argument('--cache-source',type=pathlib.Path,help='Explicit isolated cache candidate; omitted uses production RTL');ap.add_argument('--whole-bridge',action='store_true',help='Include real viewport, descriptors, motion (settled age127 hook), row frontend and palette');ap.add_argument('--mixed-unit',action='store_true',help='Generate and run mixed6-page scalar-opacity/zoom/packed/plain pixel-engine unit');ap.add_argument('--fixtures-only',action='store_true');a=ap.parse_args()
 if not a.run_id or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in a.run_id):ap.error('Invalid run-id')
 if a.mixed_unit and (a.whole_bridge or a.case):ap.error('mixed-unit is exclusive with whole-bridge/case')
 if a.write_cycles<0 or a.write_cycles>4096 or (a.write_cycles and not a.whole_bridge):ap.error('write-cycles requires whole-bridge, range0..4096')
 sources=list(SOURCES);top='html_layer_engine_full_tb'
 if a.mixed_unit:top='html_layer_pixel_engine_tb';sources[0]='tests/html_layer_pixel_engine_tb.v'
 if a.whole_bridge:
  top='html_layer_bridge_full_tb';sources[0]='tests/'+top+'.v';sources+=['rtl/ext/html_layer_memory_bridge.v','rtl/ext/html_layer_viewport.v','rtl/ext/html_layer_span_frontend.v','rtl/ext/html_layer_descriptor_rom.v','rtl/ext/html_layer_line_setup.v','rtl/ext/html_layer_palette.v','rtl/ext/html_scene_motion.v','rtl/ext/html_rom16.v']
 if a.write_cycles:top='html_layer_bridge_write_tb';sources[0]='tests/'+top+'.v'
 if a.cache_source:sources=[str(a.cache_source.resolve()) if f=='rtl/ext/html_layer_cache.v' else f for f in sources]
 r=a.root.resolve();d=r/'output/html_fidelity/layers';out=r/'output/html_fidelity/page_control'/a.run_id;out.mkdir(parents=True,exist_ok=False);started=time.monotonic();now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
 m=json.loads((d/'hfxl_payload_manifest.json').read_text());blob=(d/'hfxl_global_atlas.bin').read_bytes();words=list(struct.unpack('<%dI'%(len(blob)//4),blob));words.extend([0]*(2097152-len(words)))
 inputs=['output/html_fidelity/layers/hfxl_payload_manifest.json','output/html_fidelity/layers/hfxl_global_atlas.bin','rtl/ext/html_assets/html_layer_palette.hex']
 if a.whole_bridge:
  inputs += ['rtl/ext/html_assets/'+f for f in ['html_layer_palette_r.hex','html_layer_palette_g.hex','html_layer_palette_b.hex','html_layer_palette_r.hex.bin','html_layer_palette_g.hex.bin','html_layer_palette_b.hex.bin','html_layer_descriptors.hex','html_layer_descriptors16.hex','html_layer_descriptors16.hex.bin','html_motion_offset.hex','html_motion_alpha_scale.hex','html_motion_offset.hex.bin','html_motion_alpha_scale.hex.bin','html_layer_layout.vh']]
 for p in range(1,5):
  f=f'output/html_fidelity/layers/experimental_media/UI{p+1:02}.BMP';b=(r/f).read_bytes();words[1843200+(p-1)*62464:1843200+p*62464]=struct.unpack('<62464I',b[512:250368]);inputs.append(f)
 (out/'memory.hex').write_text(''.join(f'{w:08x}\n' for w in words))
 report={'schema':1,'scope':__doc__,'UNIT_SIM':'RUNNING' if not a.fixtures_only else 'NOT_RUN','FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_VERIFIED','pid':os.getpid(),'started_utc':now(),'python':sys.version,'slots':a.slots,'whole_bridge':a.whole_bridge,'write_busy_cycles':a.write_cycles,'static_motion_hook_age':127 if a.whole_bridge else None,'source_sha256':{f:sha(r/f) for f in sources+inputs+['scripts/html_layer_render_verify.py','harness/test_runner.py']},'cases':[],'tools':{}}
 for exe in [r'C:\iverilog\bin\iverilog.exe',r'C:\iverilog\bin\vvp.exe']:
  t=subprocess.run([exe,'-V'],capture_output=True,timeout=30);report['tools'][exe]={'exit':t.returncode,'identity':(t.stdout+t.stderr).decode(errors='replace')}
 for name in (['mixed_unit'] if a.mixed_unit else a.case or NAMES):
  item=mixed_fixture(out,m['pages'],words) if a.mixed_unit else fixture(out,m['pages'],words,name)
  if not a.fixtures_only:
   cmd=[sys.executable,str(r/'harness/test_runner.py'),'--top',top,'--output',str(out/name),'--cwd',str(r),'--sim-timeout','600']
   parameters={'PAGE':(1 if name=='compare12' else 3) if name.startswith('compare') else item.get('page',0),'CONTEXT_BITS':3,'CACHE_SLOT_BITS':3 if a.slots==8 else 4,'BG_SLOT_BITS':4,'DESC_COUNT':item['contexts'],'CASE_NAME':'"'+name+'"','FIXTURE_ROOT':'"'+out.as_posix()+'"'}
   if a.whole_bridge:parameters.update(DIVISOR=item['divisor'],COMPARE=int(name.startswith('compare')))
   if a.mixed_unit:parameters={'CONTEXT_BITS':3,'CACHE_SLOT_BITS':3 if a.slots==8 else 4,'BG_SLOT_BITS':4,'DESC_COUNT':item['contexts'],'PIXEL_COUNT':item['logical_pixels'],'FIXTURE_ROOT':'"'+out.as_posix()+'"'}
   if a.write_cycles:parameters['WRITE_CYCLES']=a.write_cycles
   for k,v in parameters.items():cmd+=['--parameter',f'{top}.{k}={v}']
   cmd += [str(r/f) for f in sources];item.update(command=cmd,started_utc=now());tick=time.monotonic()
   with (out/(name+'_runner.log')).open('wb') as log:
    t=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT);item.update(pid=t.pid,exit=t.wait())
   item['wall_seconds']=time.monotonic()-tick;q=out/name/'result.json';item['result']=json.loads(q.read_text()) if q.exists() else {'SIM':'MISSING'}
  report['cases'].append(item);report['wall_seconds']=time.monotonic()-started;(out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps({'case':name,'contexts':item['contexts'],'SIM':item.get('result',{}).get('SIM','NOT_RUN'),'exit':item.get('exit'),'seconds':item.get('wall_seconds'),'fixtures':str(out)}),flush=True)
 if not a.fixtures_only:report['UNIT_SIM']='PASS' if all(c['exit']==0 and c['result'].get('SIM')=='PASS' for c in report['cases']) else 'FAIL'
 report['finished_utc']=now();report['wall_seconds']=time.monotonic()-started;(out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps({'UNIT_SIM':report['UNIT_SIM'],'evidence':str(out)}));return 0 if a.fixtures_only or report['UNIT_SIM']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
