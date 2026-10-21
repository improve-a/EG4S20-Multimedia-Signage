#!/usr/bin/env python3
"""Reproduce the finite HFXL renderer and ordered four-word memory contract.

Default cases supply independently generated settled geometry. --whole-bridge
includes the actual viewport, row frontend, motion and palette with a disclosed
settled motion-age127 hook. --writer-stress adds actual read/write control RTL,
behavioral512word FIFO occupancy and the legal102.4memclock/sourceword bound.
--cache-unit covers hit/miss/refcounts and positive/negative reset/drain cases.
--real-fifo uses actual generated FIFO RAM/Gray CDC with511 usable words,
read128/write256 and a latched writer reserve (default384). --transition-age25/65
uses independent dynamic RGB gold and explicit frame-state force hooks.
These are scoped unit/cadence proofs, not a full display-chain or hardware proof.
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

def transition_fixture(out,pages,words,name,age,reverse,root,initial=False):
 item=fixture(out,pages,words,name);page=item['page'];old=(page+(1 if reverse else 5))%6
 assets=root/'rtl/ext/html_assets'
 rom=[int(x,16) for x in (assets/'html_layer_descriptors.hex').read_text().split()]
 offsets=[int(x,16) for x in (assets/'html_motion_offset.hex').read_text().split()]
 scales=[int(x,16) for x in (assets/'html_motion_alpha_scale.hex').read_text().split()]
 bases=[p['global_word_base'] for p in pages]
 def signed(v,n):return v-(1<<n) if v>>(n-1) else v
 def spans(p,isold,y):
  result=[]
  for c in range(16):
   w=rom[(p*16+c)*8:(p*16+c+1)*8];role=w[0]&255
   if role==255:continue
   kind=1 if role in (2,3) else 2 if role==1 else 3 if role==4 else 0;idx=(w[0]>>8)&255
   tx=ty=0;inv=4096;alpha=0 if isold and age>=93 else 255
   if age<93 and kind:
    bank=(3 if kind==3 else 2) if isold else (0 if kind==1 else 1 if kind==2 else 4+idx)
    v=offsets[bank*128+age];a=scales[bank*128+age];alpha=a>>8
    if kind==3 and not isold:ty=signed(v&8191,13)
    else:tx=signed(v,16)*(-1 if kind==1 and not isold and reverse else 1)
    if kind==1 and not isold:
     scale=4096-(a&255);inv=((1<<24)+scale//2)//scale
   cx=signed(w[1]&65535,16);cy=signed(w[1]>>16,16);ww=w[2]&65535;hh=w[2]>>16;px=signed(w[4]&65535,16);py=signed(w[4]>>16,16)
   if kind==1 and inv!=4096:
    sy=((py<<15)+((y<<7)-(py<<3)-(ty>>1))*inv)>>19;origin=(px<<12)+((-(px<<3)-(tx>>1))*inv>>3);step=inv<<4
   else:sy=(y*256-ty)>>8;origin=-tx*256;step=65536
   if alpha and ww and hh and 0<=sy-cy<hh:result.append((cx,ww,bases[p]+w[3]+(sy-cy)*ww,origin,step,alpha))
  assert len(result)<=4,(p,age,y,len(result))
  return result
 # Independent bisection of the CSS cubic-bezier(.76,0,.24,1).
 t=min(1.0,age*0.0168/1.05);lo=0.0;hi=1.0
 for _ in range(64):
  q=(lo+hi)/2;x=3*(1-q)**2*q*.76+3*(1-q)*q*q*.24+q**3
  if x<t:lo=q
  else:hi=q
 q=(lo+hi)/2;aperture=round(640*(3*(1-q)*q*q+q**3));active=age<63 and not initial
 golden=[];max_rgba=0
 for y in range(480):
  row_spans={False:spans(page,False,y),True:spans(old,True,y)}
  for x in range(640):
   isold=active and (x>=aperture if reverse else x<640-aperture);p=old if isold else page
   bg=bases[p]+pages[p]['bg_word_offset']+y*214+x//3;lane=x%3;idx=(words[bg]>>(10*lane))&1023
   rgb=words[bases[p]+pages[p]['palette_word_offset']+idx]>>8;n=0
   for cx,ww,b,origin,step,alpha in row_spans[bool(isold)]:
    sx=(origin+x*step)>>16
    if cx<=sx<cx+ww:
     fg=words[b+sx-cx];a=((fg&255)*alpha+127)//255
     rgb=sum((((((fg>>(8+sh))&255)*a+((rgb>>sh)&255)*(255-a)+127)//255)<<sh) for sh in (0,8,16));n+=1
   assert n<=2,(page,old,age,y,x,n);max_rgba=max(max_rgba,n);golden.append(f'{rgb<<8:08x}\n')
 (out/(name+'_gold.hex')).write_text(''.join(golden))
 item.update(transition_age=age,old_page=old,reverse=reverse,aperture_width=aperture,aperture_active=active,max_rgba=max_rgba,golden_scope='Independent fixedpoint geometry from validated CSS motion ROMs, independent Bezier aperture, actual source texels/palette/source-over rounding; explicit forced frame-state hook, not natural frame advancement')
 item['fixture_sha256'][name+'_gold.hex']=sha(out/(name+'_gold.hex'))
 return item

def cache_unit(a):
 r=a.root.resolve();out=r/'output/html_fidelity/page_control'/a.run_id;out.mkdir(parents=True,exist_ok=False)
 cache=a.cache_source.resolve() if a.cache_source else r/'rtl/ext/html_layer_cache.v'
 sourcefiles=[cache,r/'tests/html_layer_cache_tb.v',r/'tests/html_layer_cache_boundary_tb.v',r/'scripts/html_layer_render_verify.py',r/'harness/test_runner.py']
 report={'schema':1,'scope':'Cache ordered4word groups,8192task hit/miss/refcount/eviction plus actual boundary positive/negative checks. Explicit unit only.','UNIT_SIM':'RUNNING','FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_VERIFIED','source_sha256':{str(f):sha(f) for f in sourcefiles},'cases':[],'pid':os.getpid()}
 report['tools']={}
 for exe in [r'C:\iverilog\bin\iverilog.exe',r'C:\iverilog\bin\vvp.exe']:
  t=subprocess.run([exe,'-V'],capture_output=True,timeout=30);report['tools'][exe]={'exit':t.returncode,'identity':(t.stdout+t.stderr).decode(errors='replace')}
 start=time.monotonic()
 for name,top,params in [('cache8','html_layer_cache_tb',{'CACHE_SLOT_BITS':3}),('cache32','html_layer_cache_tb',{'CACHE_SLOT_BITS':5}),('cache_boundary','html_layer_cache_boundary_tb',{})]:
  cmd=[sys.executable,str(r/'harness/test_runner.py'),'--top',top,'--output',str(out/name),'--cwd',str(r),'--sim-timeout','60']
  for key,value in params.items():cmd+=['--parameter',f'{top}.{key}={value}']
  cmd += [str(r/'tests'/f'{top}.v'),str(cache)]
  tick=time.monotonic()
  with (out/(name+'_runner.log')).open('wb') as log:
   proc=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT);code=proc.wait()
  q=out/name/'result.json';item={'case':name,'command':cmd,'pid':proc.pid,'exit':code,'wall_seconds':time.monotonic()-tick,'result':json.loads(q.read_text()) if q.exists() else {'SIM':'MISSING'}}
  report['cases'].append(item);print(json.dumps({'case':name,'SIM':item['result'].get('SIM'),'exit':code}),flush=True)
  (out/'result.json').write_text(json.dumps(report,indent=2))
 report['UNIT_SIM']='PASS' if all(x['exit']==0 and x['result'].get('SIM')=='PASS' for x in report['cases']) else 'FAIL'
 report['wall_seconds']=time.monotonic()-start;(out/'result.json').write_text(json.dumps(report,indent=2));return int(report['UNIT_SIM']!='PASS')

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1]);ap.add_argument('--run-id',default=datetime.datetime.now(datetime.timezone.utc).strftime('layer_render_%Y%m%dT%H%M%S%fZ'));ap.add_argument('--case',action='append',choices=NAMES);ap.add_argument('--slots',type=int,choices=[4,8,16],default=8);ap.add_argument('--contexts',type=int,choices=[4,8],default=8);ap.add_argument('--bg-slots',type=int,choices=[8,16],default=16);ap.add_argument('--engine-source',type=pathlib.Path,help='Explicit isolated pixel-engine candidate');ap.add_argument('--real-fifo',action='store_true');ap.add_argument('--transition-age',type=int,choices=[25,65,127],default=127);ap.add_argument('--reverse',action='store_true');ap.add_argument('--initial-scene',action='store_true');ap.add_argument('--write-reserve',type=int,choices=[256,320,384,400],default=384);ap.add_argument('--read-burst',type=int,choices=[128,256],default=256,help='Actual writer stress reader burst length; producer remains256words');ap.add_argument('--writer-stress',action='store_true',help='Actual read/write controllers with512wordinitialbacklog and102.4memoryclocks/sourceword');ap.add_argument('--write-cycles',type=int,default=0,help='Enable actual writer/controller admission stress (nonzero legacy argument);102.4memcycles/sourceword plus initial512wordbacklog');ap.add_argument('--cache-source',type=pathlib.Path,help='Explicit isolated cache candidate; omitted uses production RTL');ap.add_argument('--whole-bridge',action='store_true',help='Include real viewport, descriptors, motion (settled age127 hook), row frontend and palette');ap.add_argument('--cache-unit',action='store_true',help='8192task cache8/cache32 and flush/reset/drain/unsolicited-response boundaries');ap.add_argument('--mixed-unit',action='store_true',help='Generate and run mixed6-page scalar-opacity/zoom/packed/plain pixel-engine unit');ap.add_argument('--fixtures-only',action='store_true');a=ap.parse_args()
 if a.writer_stress and not a.write_cycles:a.write_cycles=1
 if a.real_fifo and (not a.whole_bridge or not a.write_cycles or a.read_burst!=128 or not a.case or any(n not in NAMES[:6] for n in a.case) or (a.slots,a.contexts,a.bg_slots)!=(8,8,16)):ap.error('real-fifo requires whole-bridge writer-stress read-burst128, explicit normal1x case and cache8/compute8/BG16')
 if (a.transition_age!=127 or a.reverse or a.initial_scene) and not a.real_fifo:ap.error('dynamic frame-state hooks require real-fifo')
 if not a.run_id or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in a.run_id):ap.error('Invalid run-id')
 if a.cache_unit:
  if a.mixed_unit or a.whole_bridge or a.case or a.write_cycles or a.engine_source:ap.error('cache-unit is exclusive with renderer options')
  return cache_unit(a)
 if a.mixed_unit and (a.whole_bridge or a.case):ap.error('mixed-unit is exclusive with whole-bridge/case')
 if a.write_cycles<0 or a.write_cycles>4096 or (a.write_cycles and not a.whole_bridge):ap.error('write-cycles requires whole-bridge, range0..4096')
 sources=list(SOURCES);top='html_layer_engine_full_tb'
 if a.mixed_unit:top='html_layer_pixel_engine_tb';sources[0]='tests/html_layer_pixel_engine_tb.v'
 if a.whole_bridge:
  top='html_layer_bridge_full_tb';sources[0]='tests/'+top+'.v';sources+=['rtl/ext/html_layer_memory_bridge.v','rtl/ext/html_layer_viewport.v','rtl/ext/html_layer_span_frontend.v','rtl/ext/html_layer_descriptor_rom.v','rtl/ext/html_layer_line_setup.v','rtl/ext/html_layer_palette.v','rtl/ext/html_scene_motion.v','rtl/ext/html_rom16.v']
 if a.write_cycles:
  top='html_layer_bridge_write_tb';sources[0]='tests/'+top+'.v';sources+=['rtl/SD/frame_fifo_read.v','rtl/SD/frame_fifo_write.v']
 if a.real_fifo:
  top='html_layer_physical_fifo_tb';sources[0]='tests/'+top+'.v';sources+=['rtl/SD/frame_read_write.v','rtl/IP/afifo_32_16_256.v','rtl/IP/afifo_16_32_256.v']
 if a.engine_source:sources=[str(a.engine_source.resolve()) if f=='rtl/ext/html_layer_pixel_engine.v' else f for f in sources]
 if a.cache_source:sources=[str(a.cache_source.resolve()) if f=='rtl/ext/html_layer_cache.v' else f for f in sources]
 r=a.root.resolve();d=r/'output/html_fidelity/layers';out=r/'output/html_fidelity/page_control'/a.run_id;out.mkdir(parents=True,exist_ok=False);started=time.monotonic();now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
 m=json.loads((d/'hfxl_payload_manifest.json').read_text());blob=(d/'hfxl_global_atlas.bin').read_bytes();words=list(struct.unpack('<%dI'%(len(blob)//4),blob));words.extend([0]*(2097152-len(words)))
 inputs=['output/html_fidelity/layers/hfxl_payload_manifest.json','output/html_fidelity/layers/hfxl_global_atlas.bin','rtl/ext/html_assets/html_layer_palette.hex']
 if a.whole_bridge:
  inputs += ['rtl/ext/html_assets/'+f for f in ['html_layer_palette_r.hex','html_layer_palette_g.hex','html_layer_palette_b.hex','html_layer_palette_r.hex.bin','html_layer_palette_g.hex.bin','html_layer_palette_b.hex.bin','html_layer_descriptors.hex','html_layer_descriptors16.hex','html_layer_descriptors16.hex.bin','html_motion_offset.hex','html_motion_alpha_scale.hex','html_motion_offset.hex.bin','html_motion_alpha_scale.hex.bin','html_layer_layout.vh']]
 for p in range(1,5):
  f=f'output/html_fidelity/layers/experimental_media/UI{p+1:02}.BMP';b=(r/f).read_bytes();words[1843200+(p-1)*62464:1843200+p*62464]=struct.unpack('<62464I',b[512:250368]);inputs.append(f)
 (out/'memory.hex').write_text(''.join(f'{w:08x}\n' for w in words))
 report={'schema':1,'scope':__doc__,'UNIT_SIM':'RUNNING' if not a.fixtures_only else 'NOT_RUN','FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_VERIFIED','pid':os.getpid(),'started_utc':now(),'python':sys.version,'slots':a.slots,'compute_contexts':a.contexts,'bg_slots':a.bg_slots,'whole_bridge':a.whole_bridge,'actual_reader_burst':a.read_burst if a.write_cycles else None,'writer_stress_enabled':bool(a.write_cycles),'writer_source_memory_clocks_per_word':102.4 if a.write_cycles else None,'writer_initial_backlog_words':(511 if a.real_fifo else 512) if a.write_cycles else None,'actual_fifo_gray_cdc':a.real_fifo,'usable_fifo_capacity':511 if a.real_fifo else 512,'latched_write_reserve':a.write_reserve if a.real_fifo else None,'explicit_frame_state_hook':a.transition_age!=127,'motion_hook_age':a.transition_age,'natural_frame_advancement_proven':False,'writer_admission':'actual frame_fifo_read/write RTL' if a.write_cycles else None,'static_motion_hook_age':127 if a.whole_bridge and a.transition_age==127 else None,'source_sha256':{f:sha(r/f) for f in sources+inputs+['scripts/html_layer_render_verify.py','harness/test_runner.py']},'cases':[],'tools':{}}
 for exe in [r'C:\iverilog\bin\iverilog.exe',r'C:\iverilog\bin\vvp.exe']:
  t=subprocess.run([exe,'-V'],capture_output=True,timeout=30);report['tools'][exe]={'exit':t.returncode,'identity':(t.stdout+t.stderr).decode(errors='replace')}
 for name in (['mixed_unit'] if a.mixed_unit else a.case or NAMES):
  item=mixed_fixture(out,m['pages'],words) if a.mixed_unit else transition_fixture(out,m['pages'],words,name,a.transition_age,a.reverse,r,a.initial_scene) if a.real_fifo and a.transition_age!=127 else fixture(out,m['pages'],words,name)
  if not a.fixtures_only:
   cmd=[sys.executable,str(r/'harness/test_runner.py'),'--top',top,'--output',str(out/name),'--cwd',str(r),'--sim-timeout','600']
   parameters={'PAGE':(1 if name=='compare12' else 3) if name.startswith('compare') else item.get('page',0),'CONTEXT_BITS':2 if a.contexts==4 else 3,'CACHE_SLOT_BITS':a.slots.bit_length()-1,'BG_SLOT_BITS':3 if a.bg_slots==8 else 4,'DESC_COUNT':item['contexts'],'CASE_NAME':'"'+name+'"','FIXTURE_ROOT':'"'+out.as_posix()+'"'}
   if a.whole_bridge:parameters.update(DIVISOR=item['divisor'],COMPARE=int(name.startswith('compare')))
   if a.mixed_unit:parameters={'CONTEXT_BITS':2 if a.contexts==4 else 3,'CACHE_SLOT_BITS':a.slots.bit_length()-1,'BG_SLOT_BITS':3 if a.bg_slots==8 else 4,'DESC_COUNT':item['contexts'],'PIXEL_COUNT':item['logical_pixels'],'FIXTURE_ROOT':'"'+out.as_posix()+'"'}
   if a.write_cycles:parameters.update(WRITE_CYCLES=a.write_cycles,READ_BURST=a.read_burst)
   if a.real_fifo:parameters={'PAGE':item['page'],'MOTION_AGE':a.transition_age,'OLD_PAGE':item.get('old_page',0),'REVERSE':int(a.reverse),'APERTURE_WIDTH':item.get('aperture_width',640),'APERTURE_ENABLE':int(not a.initial_scene),'WRITE_RESERVE':a.write_reserve,'CASE_NAME':chr(34)+name+chr(34),'FIXTURE_ROOT':chr(34)+out.as_posix()+chr(34)}
   for k,v in parameters.items():cmd+=['--parameter',f'{top}.{k}={v}']
   cmd += [str(r/f) for f in sources];item.update(command=cmd,started_utc=now());tick=time.monotonic()
   with (out/(name+'_runner.log')).open('wb') as log:
    t=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT);item.update(pid=t.pid,exit=t.wait())
   item['wall_seconds']=time.monotonic()-tick;q=out/name/'result.json';item['result']=json.loads(q.read_text()) if q.exists() else {'SIM':'MISSING'}
  report['cases'].append(item);report['wall_seconds']=time.monotonic()-started;(out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps({'case':name,'contexts':item['contexts'],'SIM':item.get('result',{}).get('SIM','NOT_RUN'),'exit':item.get('exit'),'seconds':item.get('wall_seconds'),'fixtures':str(out)}),flush=True)
 if not a.fixtures_only:report['UNIT_SIM']='PASS' if all(c['exit']==0 and c['result'].get('SIM')=='PASS' for c in report['cases']) else 'FAIL'
 report['finished_utc']=now();report['wall_seconds']=time.monotonic()-started;(out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps({'UNIT_SIM':report['UNIT_SIM'],'evidence':str(out)}));return 0 if a.fixtures_only or report['UNIT_SIM']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
