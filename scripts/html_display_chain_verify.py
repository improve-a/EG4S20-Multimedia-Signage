"""Native Windows full display-chain simulation. Standard library; no board access.
DUT writes every exported RGB pixel. PC prepares static storage vectors and
independent pixel/address expectations, never pretends to render DUT output.
"""
import argparse,datetime,fractions,hashlib,importlib.util,json,os,re,shutil,struct,subprocess,sys,time,wave,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/html_fidelity/display_chain'
VECTORS=ROOT/'output/html_fidelity/display_vectors'
MEDIA=ROOT/'output/html_fidelity/media'
ASSETS=ROOT/'output/html_fidelity/assets'
REFERENCE=ROOT/'output/html_fidelity/no_bot/reference'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def atomic_json(p,value):
 p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_name(p.name+'.'+str(os.getpid())+'.tmp');tmp.write_text(json.dumps(value,indent=2),encoding='utf-8');os.replace(tmp,p)
def bmp_rgb(p):
 d=p.read_bytes();off=struct.unpack_from('<I',d,10)[0];w,h=struct.unpack_from('<ii',d,18);bpp=struct.unpack_from('<H',d,28)[0];comp=struct.unpack_from('<I',d,30)[0]
 if d[:2]!=b'BM' or (w,abs(h),bpp,comp)!=(640,480,24,0):raise ValueError(f'unsupported fixture {p}')
 stride=((w*3+3)//4)*4
 rows=[]
 for y in range(abs(h)):
  pos=off+(abs(h)-1-y if h>0 else y)*stride;row=d[pos:pos+w*3]
  rows.append(bytes(v for x in range(w) for v in (row[x*3+2],row[x*3+1],row[x*3])))
 return b''.join(rows),{'offset':off,'width':w,'height':h,'stride':stride,'bytes':len(d)}
def prepare_vectors():
 VECTORS.mkdir(parents=True,exist_ok=True);report={'source_bmp':[],'words':0,'scope':'static storage preparation, not runtime renderer'}
 with (VECTORS/'memory_words.hex').open('w',newline='\n') as out:
  for i in range(1,7):
   p=MEDIA/f'UI{i:02d}.BMP';rgb,meta=bmp_rgb(p)
   for y in range(480):
    row=rgb[y*1920:(y+1)*1920]
    out.write(''.join(f'{row[x*3]:02x}{row[x*3+1]:02x}{row[x*3+2]:02x}00\n' for x in range(640)))
   report['source_bmp'].append({'path':str(p),'sha256':sha(p),**meta});report['words']+=307200
  for i in range(2,6):
   p=MEDIA/f'UI{i:02d}.BMP';d=p.read_bytes();magic,version,tw,th,lw,lh,size,off=struct.unpack_from('<IHHHHHII',d,54)
   if (magic,version,tw,th,lw,lh,size,off)!=(0x43584648,1,320,384,80,24,249856,512):raise ValueError(f'bad packedpanel metadata {p}')
   words=struct.unpack_from('<62464I',d,off);out.write(''.join(f'{v:08x}\n' for v in words));report['words']+=len(words)
 if report['words']!=2093056:raise ValueError('memory layout differs from production mapper')
 wp=MEDIA/'07_MUSIC.WAV'
 with wave.open(str(wp),'rb') as w:
  channels=w.getnchannels();rate=w.getframerate();width=w.getsampwidth();count=w.getnframes();data=w.readframes(count)
 if width!=2:raise ValueError('peak fixture expects PCM16')
 samples=struct.unpack('<'+str(len(data)//2)+'h',data)
 peaks=[]
 for frame in range(256):
  start=(frame*rate*420000)//25000000;end=((frame+1)*rate*420000)//25000000
  peak=max(abs(v) for v in samples[start*channels:end*channels]);peaks.append(min(32768,peak))
 (VECTORS/'real_wav_peaks.hex').write_text(''.join(f'{p:04x}\n' for p in peaks))
 report['audio']={'path':str(wp),'sha256':sha(wp),'channels':channels,'rate':rate,'width':width,'frame_count':count,'method':'actual PCM16 absolute peak per16.8ms video frame; temporal bars, not spectrum'}
 def ease(x):
  lo,hi=0.,1.
  for _ in range(48):
   t=(lo+hi)/2;a=3*(1-t)*(1-t)*t*.76+3*(1-t)*t*t*.24+t*t*t
   if a<x:lo=t
   else:hi=t
  t=(lo+hi)/2;return 3*(1-t)*t*t+t*t*t
 values=[round(640*ease(min(1.,f*0.0168/1.05))) for f in range(64)]
 (VECTORS/'aperture_width.hex').write_text(''.join(f'{v:03x}\n' for v in values))
 report['vectors']={p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in VECTORS.glob('*.hex')};atomic_json(VECTORS/'manifest.json',report)
 return report
def prepare_layered_vectors():
 # Formal trailer bytes are the storage stimulus. Python below is an independent
 # static integer-alpha oracle only; it never writes any DUT exported frame.
 report=prepare_vectors();manifest_path=ROOT/'output/html_fidelity/layers/hfxl_payload_manifest.json'
 manifest=json.loads(manifest_path.read_text(encoding='utf8'));memory=[0]*2093056;golds=[];trailers=[]
 for page in manifest['pages']:
  i=page['page_index'];bmp=MEDIA/f'UI{i+1:02d}.BMP';data=bmp.read_bytes()
  magic,version,length,offset,size,base,pi,count,set_id,reserved=struct.unpack_from('<IHHIIIHHII',data,80)
  if (magic,version,length,base,pi,count,set_id,reserved)!=(0x4c584648,1,32,page['global_word_base'],i,6,manifest['set_id'],0):raise ValueError(f'formal HFXL locator mismatch {bmp}')
  payload=data[offset:offset+size]
  if len(payload)!=page['payload_bytes'] or hashlib.sha256(payload).hexdigest()!=page['sha256']:raise ValueError(f'formal trailer differs from sealedmanifest {bmp}')
  words=struct.unpack('<'+str(len(payload)//4)+'I',payload);memory[base:base+len(words)]=words
  palette=words[page['palette_word_offset']:page['palette_word_offset']+page['palette_entries']];gold=[]
  for y in range(480):
   for x in range(640):
    index=(words[page['bg_word_offset']+y*214+x//3]>>(10*(x%3)))&1023
    if index>=len(palette):raise ValueError('invalid background palette index')
    gold.append(palette[index]>>8)
  for component in page['components']:
   bx,by,w,h=component['bbox'];tex=component['texture_word_offset']
   for ty in range(h):
    y=by+ty
    if y<0 or y>=480:continue
    for tx in range(w):
     x=bx+tx
     if x<0 or x>=640:continue
     fg=words[tex+ty*w+tx];alpha=fg&255;bg=gold[y*640+x];rgb=0
     for shift in [16,8,0]:rgb|=((((fg>>(shift+8))&255)*alpha+((bg>>shift)&255)*(255-alpha)+127)//255)<<shift
     gold[y*640+x]=rgb
  golds.extend(gold);trailers.append({'file':str(bmp),'sha256':sha(bmp),'scene_offset':offset,'payload_sha256':hashlib.sha256(payload).hexdigest(),'word_base':base,'words':len(words)})
 for i in range(2,6):
  p=MEDIA/f'UI{i:02d}.BMP';data=p.read_bytes();offset=struct.unpack_from('<I',data,72)[0]
  # HFXC metadata has payload offset at byte72, fixed512 in this media set.
  if offset!=512:raise ValueError('unexpected HFXC offset')
  words=struct.unpack_from('<62464I',data,offset);base=1843200+(i-2)*62464;memory[base:base+62464]=words
 (VECTORS/'memory_words.hex').write_text(''.join(f'{v:08x}\n' for v in memory),newline='\n')
 (VECTORS/'static_scene_gold.hex').write_text(''.join(f'{v:06x}\n' for v in golds),newline='\n')
 report.update(mode='layered',scope='Formal HFXL+HFXC storage stimulus; independent static palette/straight-alpha oracle, never DUT image generation',trailers=trailers,manifest_sha256=sha(manifest_path),static_oracle='perchannel (src*a+dst*(255-a)+127)//255 in descriptor paintorder; identity age127; runtime action RGB not compared against staticoracle')
 report['vectors']={p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in VECTORS.glob('*.hex')};atomic_json(VECTORS/'manifest.json',report);return report

def png_write(p,w,h,rgb):
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 scan=b''.join(b'\0'+rgb[y*w*3:(y+1)*w*3] for y in range(h))
 p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b''))
def png_read(p):
 data=p.read_bytes();pos=8;packed=b''
 while pos<len(data):
  n=struct.unpack_from('>I',data,pos)[0];tag=data[pos+4:pos+8];d=data[pos+8:pos+8+n];pos+=12+n
  if tag==b'IHDR':w,h,depth,color,comp,filt,interlace=struct.unpack('>IIBBBBB',d)
  elif tag==b'IDAT':packed+=d
 if depth!=8 or color not in (2,6) or interlace:raise ValueError(f'unsupported PNG format {p}')
 channels=3 if color==2 else 4;stride=w*channels;raw=zlib.decompress(packed);prev=bytearray(stride);rgb=bytearray()
 def paeth(a,b,c):
  q=a+b-c;aa=abs(q-a);bb=abs(q-b);cc=abs(q-c)
  return a if aa<=bb and aa<=cc else b if bb<=cc else c
 for y in range(h):
  start=y*(stride+1);mode=raw[start];row=bytearray(raw[start+1:start+1+stride])
  for x in range(stride):
   a=row[x-channels] if x>=channels else 0;b=prev[x];c=prev[x-channels] if x>=channels else 0
   row[x]=(row[x]+(0 if mode==0 else a if mode==1 else b if mode==2 else (a+b)//2 if mode==3 else paeth(a,b,c)))&255
  if channels==3:rgb.extend(row)
  else:
   for x in range(w):rgb.extend(row[x*4:x*4+3])
  prev=row
 return w,h,bytes(rgb)
def ppm_read(p):
 magic,wh,depth,rgb=p.read_bytes().split(b'\n',3)
 if magic!=b'P6' or wh!=b'640 480' or depth!=b'255' or len(rgb)!=921600:raise ValueError(f'incomplete DUT frame {p}')
 return rgb
def compare_frames(run):
 result=[];destination=run/'frames';destination.mkdir(exist_ok=True);names=['home','eagle','phoenix','elf','dragon','eco']
 for ppm in sorted((run/'output/html_fidelity/display_chain').glob('*.ppm')):
  rgb=ppm_read(ppm);target=destination/ppm.name;shutil.copy2(ppm,target);png_write(target.with_suffix('.png'),640,480,rgb)
  item={'frame':ppm.name,'sha256':sha(ppm),'source':'real RTL out_rgb fwrite;640x480307200pixels'}
  reference=None;clean=None
  if ppm.stem.startswith('page'):
   i=int(ppm.stem[4:]);reference=REFERENCE/f'reference_{names[i]}.png';clean=ASSETS/f'A_{i+1:02d}_{names[i]}.png'
  elif ppm.stem=='compare_eagle_phoenix':reference=REFERENCE/'reference_dual.png'
  elif ppm.stem=='zoom2':reference=REFERENCE/'reference_zoom.png'
  if reference and reference.exists():
   w,h,ref=png_read(reference)
   if (w,h)!=(640,480):raise ValueError('reference is not stage640x480')
   diff=bytes(min(255,abs(a-b)*4) for a,b in zip(rgb,ref));triptych=b''.join(ref[y*1920:(y+1)*1920]+rgb[y*1920:(y+1)*1920]+diff[y*1920:(y+1)*1920] for y in range(480))
   png_write(destination/(ppm.stem+'_reference_dut_diff.png'),1920,480,triptych)
   item.update(reference=str(reference),reference_sha256=sha(reference),full_rgb_mae=sum(abs(a-b) for a,b in zip(rgb,ref))/len(rgb),right_bottom_no_bot_rgb_mae=sum(abs(rgb[(y*640+x)*3+c]-ref[(y*640+x)*3+c]) for y in range(380,480) for x in range(510,640) for c in range(3))/(100*130*3),comparison='left sourceHTML;middle actualDUT;right4xabsoluteRGBdifference. Pose/bars differ by disclosed fixture.')
  if clean and clean.exists():
   w,h,base=png_read(clean);err=0;count=0;bad=0
   for y in range(380):
    for x in range(640):
     if x>=500 and y<105:continue
     k=(y*640+x)*3;delta=sum(abs(rgb[k+c]-base[k+c]) for c in range(3));err+=delta;count+=3;bad+=delta!=0
   item.update(clean_A_sha256=sha(clean),clean_A_rgb_mae=err/count,clean_A_nonmatching_pixels=bad,clean_A_mask='y<380 excluding x>=500,y<105; excludes all OSD and zoomindicator')
  result.append(item)
 atomic_json(run/'pixel_comparisons.json',result);return result
def completion_counts(text,smoke,subset="all"):
 frames=re.findall(r'^FRAME_PASS .* pixels(\d+) accepted(\d+) returned(\d+)',text,re.M)
 expected=1 if smoke else {"all":18,"normal012":3,"normal345":3,"compare_zoom":4,"natural":9}[subset]
 if len(frames)!=expected or any(int(p)!=307200 or a!=b for p,a,b in frames):raise ValueError('incomplete/mismatched actual DUT fullframe results')
 result={'mode':'smoke' if smoke else subset,'full_frames':len(frames),'active_pixels':len(frames)*307200,'physical_requests_at_lastframe':int(frames[-1][1]),'physical_returns_at_lastframe':int(frames[-1][2])}
 if not smoke:
  m=re.search(r'DISPLAY_CHAIN_SIM_PASS frames(\d+) sync_checks(\d+) source_pixels(\d+) physicalrequests(\d+) physicalresponses(\d+) refreshes(\d+) minimum(\d+) cycles logicalchecks(\d+) latencies5..10 FIFOunderflow/tagfaultverified',text)
  if not m:raise ValueError('missing final actual timing/FIFO/refresh diagnostic counters')
  values=list(map(int,m.groups()));keys=['frames','sync_checks','source_pixel_checks','physical_requests','physical_responses','refresh_count','minimum_refresh_cycles','logical_pixel_checks'];result.update(dict(zip(keys,values)))
  if values[0]!=expected or values[3]!=values[4] or values[6]<20 or values[7]!=expected*307200:raise ValueError('invalid actualDUT completion totals')
  result.update(latency_cycles_covered=list(range(5,11)),sticky_underflow_verified=True,unsolicited_response_verified=True)
 return result

def write_apng(path,frames,durations_ps,metadata):
 # Full source RGB frames, lossless, no blending/interpolation or palette mapping.
 # Exact rational delay21/1250s preserves the native16.8ms frame period.
 if not frames or len(frames)!=len(durations_ps):raise ValueError('APNG frame/duration count mismatch')
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 blob=bytearray(b'\x89PNG\r\n\x1a\n');blob+=chunk(b'IHDR',struct.pack('>IIBBBBB',640,480,8,2,0,0,0))
 blob+=chunk(b'acTL',struct.pack('>II',len(frames),0))
 blob+=chunk(b'tEXt',b'DUTFrameProvenance\0'+json.dumps(metadata,ensure_ascii=True,separators=(',',':')).encode('ascii'))
 sequence=0
 for i,(rgb,period) in enumerate(zip(frames,durations_ps)):
  if len(rgb)!=640*480*3:raise ValueError('APNG source is not a completeDUTframe')
  delay=fractions.Fraction(period,10**12)
  if delay.numerator>65535 or delay.denominator>65535:raise ValueError('APNG duration exceeds exact16bit rational')
  blob+=chunk(b'fcTL',struct.pack('>IIIIIHHBB',sequence,640,480,0,0,delay.numerator,delay.denominator,0,0));sequence+=1
  scan=b''.join(b'\0'+rgb[y*1920:(y+1)*1920] for y in range(480));packed=zlib.compress(scan)
  if i==0:blob+=chunk(b'IDAT',packed)
  else:blob+=chunk(b'fdAT',struct.pack('>I',sequence)+packed);sequence+=1
 blob+=chunk(b'IEND',b'');path.write_bytes(blob)
 # Existing Pillow is verification only: decode everyAPNGframe and compareRGB.
 from PIL import Image,__version__ as pillow_version
 with Image.open(path) as image:
  if image.n_frames!=len(frames):raise ValueError('APNG lost source frames')
  for i,rgb in enumerate(frames):
   image.seek(i)
   if image.convert('RGB').tobytes()!=rgb:raise ValueError('APNG changed actualDUT RGB')
   if abs(image.info.get('duration',-1)-durations_ps[i]/10**9)>1e-8:raise ValueError('APNG changed actualframe time')
 return {'path':str(path),'sha256':sha(path),'decoded_frames':len(frames),'lossless_rgb_verified':True,'pillow_version':pillow_version}

def make_action_preview(run):
 log=(run/'simulation.log').read_text();stamps={}
 for index,age,first,last in re.findall(r'^FRAME_PASS .*[/\\]action(\d\d)\.ppm .* age(\d+) first_pixel_time(\d+) last_pixel_time(\d+)',log,re.M):
  stamps[int(index)]=(int(age),int(first),int(last))
 if sorted(stamps)!=list(range(8)):raise ValueError('missing8 actualDUT action timestamps')
 frames=[];sources=[];zero=stamps[0][1]
 for i in range(8):
  source=run/'frames'/f'action{i:02d}.ppm';age,first,last=stamps[i]
  if age!=i or first-zero!=i*16_800_000_000:raise ValueError('action capture not consecutive native16.8ms frames')
  frames.append(ppm_read(source));sources.append({'frame':str(source.relative_to(run)),'sha256':sha(source),'caption_swap_age_frames':age,'first_pixel_time_ps':first,'last_pixel_time_ps':last,'relative_first_pixel_time_ms':(first-zero)/10**9})
 metadata={'scope':'Eight actualDUT native640x480 frames0..7 only, sampledtransition window0..117.6ms. Loop resets after134.4ms. No interpolation, redraw, palettequantization or claimtofull1.55s transition.','time_origin':'first active pixel of capturedaction00, absolute simulator timestamps retained','native_frame_period_ps':16_800_000_000,'sources':sources}
 metadata['apng']=write_apng(run/'frames/action_samples.apng',frames,[16_800_000_000]*8,metadata)
 atomic_json(run/'frames/action_samples_provenance.json',metadata);return metadata

def source_files():
 local=['tests/html_display_chain_tb.v','rtl/SD/frame_read_write.v','rtl/SD/frame_fifo_read.v','rtl/SD/frame_fifo_write.v',
        'rtl/SD/video_delay.v','rtl/SD/video_timing_data.v','rtl/SD/color_bar.v','rtl/IP/afifo_32_16_256.v','rtl/IP/afifo_16_32_256.v',
        'rtl/display_commit.v','rtl/ext/pixel_adjust.v','rtl/ext/html_assets/html_caption_map.v']
 local += [str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext').glob('html*.v')]
 local += [str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext').glob('exhibit*.v')]
 return sorted(set(n for n in local if not Path(n).name.startswith(('html_bot_', 'html_eye_'))))
def main():
 global VECTORS
 ap=argparse.ArgumentParser();ap.add_argument('--layered',action='store_true');ap.add_argument('--native-busy-cone',type=Path,help='Private selected native RW busy cone; copied only into ignored simulation output and SHA recorded');ap.add_argument('--data-early',type=int,choices=[0,1],default=1,help='Raw SDRAM payload leads response by one memory clock; production phase adapter selection');ap.add_argument('--subset',choices=['all','normal012','normal345','compare_zoom','natural'],default='all');ap.add_argument('--compile-only',action='store_true');ap.add_argument('--prepare-only',action='store_true');ap.add_argument('--smoke',action='store_true');ap.add_argument('--timeout',type=int,default=6000);a=ap.parse_args()
 if a.smoke and a.subset!='all':ap.error('--smoke requires --subset all')
 expected_exports={'all':18,'normal012':3,'normal345':3,'compare_zoom':4,'natural':8}[a.subset]
 subset_code={'all':0,'normal012':1,'normal345':2,'compare_zoom':3,'natural':4}[a.subset]
 if a.prepare_only:
  if a.layered:VECTORS=ROOT/'output/html_fidelity/display_vectors_layered'
  vectors=prepare_layered_vectors() if a.layered else prepare_vectors()
  print(json.dumps(vectors,indent=2));return 0
 OUT.mkdir(parents=True,exist_ok=True);run=OUT/(('layered_' if a.layered else 'run_')+('' if a.subset=='all' else a.subset+'_')+time.strftime('%Y%m%d_%H%M%S'));run.mkdir()
 # Each process prepares its own fixtures: parallel subsets never share writes.
 VECTORS=run/'output/html_fidelity/display_vectors'
 vectors=prepare_layered_vectors() if a.layered else prepare_vectors()
 sources=source_files()
 dependencies=sources+['scripts/html_display_chain_verify.py','scripts/html_display_chain_postprocess.py','rtl/SD/video_define.v']+[str(p.relative_to(ROOT)) for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
 for name in dependencies:
  dst=run/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
 (run/'output/html_fidelity/display_chain').mkdir(parents=True)
 if a.native_busy_cone:
  local_cone=run/'private/native_rw_busy_selected_cone.v';local_cone.parent.mkdir();shutil.copy2(a.native_busy_cone,local_cone);sources.append('private/native_rw_busy_selected_cone.v')
 evidence={'state':'RUNNING','scope':'Display-chain RTL with real FIFOs/timing; encrypted SDRAM replaced by4-beatgroup model. No SDphysical,PHY,HW orSTAclaim.',
 'fifo_implementation':{'read_module':'rfifo_32_32_512','read_source':'rtl/IP/afifo_32_16_256.v','physical_words':512,'usable_words':511,'full_threshold':'addr_diff>=511','word_bits':32,'implementation':'Actual unencrypted generatedvendorRTL including Graypointer CDC,flags and ram_infer_rfifo_32_32_512 arrayRAM. No simplified occupancyFIFO replacement.','cdc':'SourceGrayregister,two destination synchronizerstages,registeredGray-to-binary;40MHzwrite/25MHzread clocks at testphase. Digitalcycle semantics only; no analogmetastability, siliconBRAMdelay orpostroute claim.','writer_module':'wfifo_32_32_512','writer_source':'rtl/IP/afifo_16_32_256.v','writer_scope':'ActualgeneratedRTLcompiled butwrite_req/write_en tiedzero; simultaneouswriteroccupation covered by separateCunit proofs, notthisdisplaychainsuite.'},
 'read_configuration':{'burst_pixels':128 if a.layered else 256,'drain_cycles':13 if a.layered else 10,'enable_read_source':True,'physical_fairness_enabled':bool(a.layered),'write_reserve_words':384,'writer_traffic':'idle in this suite'},
 'audio_stimulus':{'input':'256entry peakROM from formal07_MUSIC.WAV, prepared by Pythonwave PCM16 decode; maxabsolute channel sample per16.8ms, sourceWAV SHA in vectors.audio','advance':'peak_index increments on eachactualvideo readACK','audio_status':'fixed4d2 teststimulus','scope':'ActualOSD history/bar RTL executes; WAVparser/player,PCMdecoder,I2S,DAC,audioarbiter andSDaudioI/O RTL are not instantiated here. Separateaudio proofs apply; thisisnot integratedA/V verification.'},
 'raw_payload_early_cycles':a.data_early,'native_busy_restart_model':({'path':str(a.native_busy_cone),'sha256':sha(a.native_busy_cone),'scope':'Selected native RW busy/rw_vld/clear cone,internal REF inputs held0. New stream start and oldfall-clear assertions. Response data remains ordered bounded5..10cycle model; no full encrypted controller or physical SDRAM claim.'} if a.native_busy_cone else 'NOT_MODELED: ordered fourbeat renderer model does not emulate native command mux or busy tail. Separate native handshake qualification required.'),'layered':a.layered,'test_mode':'smoke' if a.smoke else a.subset,'subset':a.subset,'exported_frame_count':1 if a.smoke else expected_exports,'natural_subset_warmup':'One checked static640x480 Eagle3x frame, not exported; then8 consecutive native actionframes' if a.subset=='natural' else None,'oracle_scope':{'full_rgb_compared_frames':1 if a.smoke else ({'all':10,'normal012':3,'normal345':3,'compare_zoom':4,'natural':1}[a.subset] if a.layered else {'all':18,'normal012':3,'normal345':3,'compare_zoom':4,'natural':9}[a.subset]),'natural_layered_frames':'8 actualDUT frames checked for sync,knownRGB,fullpixelcounts,commit/caption semantics and stickyfaults; no staticRGBoracle comparison during changing scene transforms' if a.subset in ['all','natural'] else 'No natural action frames in this subset'},'snapshot':str(run),'supervisor_pid':os.getpid(),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'started_epoch':time.time(),
 'sources':{n:sha(run/n) for n in dependencies},'vectors':vectors,'steps':[],
 'fixtures':'Layered static scene age127 pinned before ACK queries, then released for natural action; static scene oracle skipped for natural action. Static captures seed only caption complete and OSD swap registers atverticalblank; noRGBpixel forcing. Natural committedpageaction frames runnormally.'}
 def save():atomic_json(run/'verification.json',evidence);atomic_json(OUT/('verification.json' if a.subset=='all' else 'verification_'+a.subset+'.json'),evidence)
 save()
 commands=[('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM']+(['-DHTML_LAYERED'] if a.layered else [])+(['-DHTML_NATIVE_BUSY'] if a.native_busy_cone else [])+['-Irtl/SD','-s','html_display_chain_tb','-Phtml_display_chain_tb.SDRAM_DATA_EARLY='+str(a.data_early),'-o','sim.vvp']+sources),
           ('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp']+(['+smoke'] if a.smoke else [])+(['+subset='+str(subset_code)] if subset_code else []))]
 for name,cmd in commands:
  if a.compile_only and name=='simulation':break
  t=time.time()
  with (run/(name+'.log')).open('wb') as log:
   child=subprocess.Popen(cmd,cwd=run,stdout=log,stderr=subprocess.STDOUT);step={'name':name,'pid':child.pid,'command':cmd,'state':'RUNNING'};evidence['steps'].append(step);save()
   try:code=child.wait(timeout=120 if name=='compile' else a.timeout)
   except subprocess.TimeoutExpired:child.kill();child.wait();code=-999
  step.update(exit_code=code,wall_seconds=time.time()-t,state='PASS' if code==0 else 'FAIL');save()
  if code:evidence.update(state='FAIL',wall_seconds=time.time()-evidence['started_epoch']);save();print((run/(name+'.log')).read_text(errors='replace'));return code
 if a.compile_only:evidence.update(state='COMPILE_PASS');save();print(run);return 0
 if b'DISPLAY_CHAIN_SIM_PASS' not in (run/'simulation.log').read_bytes():raise ValueError('missing real DUT completionmarker')
 evidence['completion']=completion_counts((run/'simulation.log').read_text(),a.smoke,a.subset);evidence['frames']=compare_frames(run);
 if len(evidence['frames'])!=(1 if a.smoke else expected_exports):raise ValueError('captured DUT files incomplete')
 if not a.smoke and a.subset in ['all','natural']:evidence['action_preview']=make_action_preview(run)
 if a.subset in ['all','normal012','normal345']:
  spec=importlib.util.spec_from_file_location('run_regions',run/'scripts/html_display_chain_postprocess.py')
  region_helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(region_helper)
  regions=region_helper.regional_metrics(sys.modules[__name__],run/'frames',ROOT,run/'source_region_masks')
  atomic_json(run/'regional_metrics.json',regions);evidence['regional_metrics_sha256']=sha(run/'regional_metrics.json')
 evidence.update(state='DISPLAY_CHAIN_SIM_PASS',wall_seconds=time.time()-evidence['started_epoch']);save();print(json.dumps(evidence,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
