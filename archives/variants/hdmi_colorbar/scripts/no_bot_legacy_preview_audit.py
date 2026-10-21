#!/usr/bin/env python3
"""Independently audit complete actual sequential-preview pixels/timestamps/APNG.
Never creates video frames; reads captured PPM, finalmetadata and lossless APNG.
"""
import argparse,datetime,fractions,hashlib,json,re,struct,zlib
from pathlib import Path
from PIL import Image

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ppm(p):
 h,w,m,b=p.read_bytes().split(b'\n',3);assert(h,w,m,len(b))==(b'P6',b'640 480',b'255',921600);return b

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run-root',type=Path,required=True);ap.add_argument('--available',action='store_true');a=ap.parse_args();run=a.run_root;report=json.loads((run/'verification.json').read_text());log=(run/'simulation.log').read_text();complete=report['state']=='LEGACY_DISPLAY_SEGMENT_PASS'
 if not a.available:assert complete
 stamps=[tuple(map(int,m))for m in re.findall(r'^FRAME_PASS (\d+) pixels307200 first(\d+) last(\d+) reads(\d+) responses(\d+)',log,re.M)];assert [s[0]for s in stamps]==list(range(len(stamps)));assert all(stamps[i][1]-stamps[i-1][1]==16800000000 for i in range(1,len(stamps)))
 states={int(m[0])-1:dict(zip(['phase','offset','front','page','cover','coverACK','commit','commitACK','writes','refreshes'],map(int,m[1:])))for m in re.findall(r'^TRANSITION_STATE frame(\d+) phase(\d+) offset(\d+) front(\d+) page(\d+) cover(\d+) coverACK(\d+) commit(\d+) commitACK(\d+) writes(\d+) refreshes(\d+)',log,re.M)}
 assert set(range(len(stamps)))<=states.keys();mem=[int(x,16)>>8 for x in(run/'memory.hex').read_text().split()[:307200]];back=[int(x,16)for x in(run/'second_loader_payload.hex').read_text().split()];sources=[b''.join(x.to_bytes(3,'big')for x in mem),b''.join(back[(479-y)*640+x].to_bytes(3,'big')for y in range(480)for x in range(640))];mask=bytes.fromhex('151615');frames=[];base=0
 for n,first,last,reads,responses in stamps:
  p=run/f'frame_{n:02d}.ppm';rgb=ppm(p);st=states[n];offset=st['offset'];source=sources[st['front']];assert reads==responses==(n+1)*307200;checked=0
  for y in range(480):
   # Include full first row (all final OSD elements begin below row0), plus
   # conservative body region excluding entire HUD/card/shadow boxes.
   spans=[(0,640)]if y==0 else[(0,500)]if y<105 else[(0,24),(510,640)]if 386<=y<466 else[(0,640)]
   for x0,x1 in spans:
    at=(y*640+x0)*3;end=(y*640+x1)*3;cut=max(0,min(x1,offset)-x0);expected=mask*cut+source[at+cut*3:end]
    assert rgb[at:end]==expected,('actual mask/source mismatch',n,y,x0,x1,offset);checked+=x1-x0
  bar_heights=[sum(rgb[((y*640+456+i*5)*3):((y*640+456+i*5)*3)+3]==bytes.fromhex('1a1916')for y in range(399,429))for i in range(9)];bar_pixels=0
  for y in range(399,429):
   for x in range(455,500):
    index,col=divmod(x-455,5);h=bar_heights[index];top=414-h//2;bottom=414+(h+1)//2;expected=col<3 and h>0 and top<=y<bottom and(col==1 or(y>top and y+1<bottom));actual=rgb[(y*640+x)*3:(y*640+x+1)*3]==bytes.fromhex('1a1916');assert actual==expected,('actualaudioROIbarmismatch',n,x,y);bar_pixels+=int(actual)
  base+=checked;frames.append({'audio_actual_bar_heights':bar_heights,'audio_actual_nonzero_ink_pixels':bar_pixels,'audio_ROI_geometry_pixels_checked':1350,'frame':n,'actual_ppm_sha256':sha(p),'first_pixel_time_ps':first,'last_pixel_time_ps':last,'display_state_during_active':st,'mask_and_source_RGB_pixels_checked':checked})
 timeline={'frame_numbering':'zero-based actual frame_NN.ppm. TRANSITION_STATE frameN is logged after increment, mapped to captureN-1.','timestamp_unit':'ps simulator timestamps; first active pixel retained; image frame period16.8ms.','audio_actual_nonzero_frame_indices':[f['frame']for f in frames if f['audio_actual_nonzero_ink_pixels']>0],'audio_picture_scope':'ActualoutRGBbars driven byoffline16.8msWAVpeakROM, notactualPCMplayer; actual64sampleplayer→OSD provenseparately.','nominal_budget_ms':{'12_close_steps':201.6,'18_open_steps':302.4},'unlatched_events':'coverrequest/commitACK/writerfinish not independently timestamped; intervals only, no reconstructed exact event time.'}
 close=[f for f in frames if f['display_state_during_active']['phase']==1 and f['display_state_during_active']['offset']>0];opened=[f for f in frames if f['display_state_during_active']['phase']==3];idle_new=[f for f in frames if f['display_state_during_active']['phase']==0 and f['display_state_during_active']['front']==1]
 if close:
  c=close[0];timeline['first_cover_pixel']={'frame':c['frame'],'xy':[0,0],'time_ps':c['first_pixel_time_ps'],'basis':'Actual row0 maskRGB and full base mask/source comparison'}
  before=frames[c['frame']-1];timeline['cover_request_not_exactly_timestamped']={'after_ps':before['last_pixel_time_ps'],'no_later_than_ps':c['first_pixel_time_ps'],'basis':'Last previous complete visible frame and first actual covered pixel; request separately not logged.'}
  full=[f for f in frames if f['frame']>=c['frame']and f['display_state_during_active']['offset']==640]
  if full:
   f=full[0];timeline['first_all_covered_frame']={'frame':f['frame'],'first_pixel_time_ps':f['first_pixel_time_ps'],'last_pixel_time_ps':f['last_pixel_time_ps'],'first_changed_to_all_covered_firstpixel_ms':(f['first_pixel_time_ps']-c['first_pixel_time_ps'])/1e9,'basis':'Every conservatively unmodified base pixel equals mask; OSD remains drawn above mask.'}
 if opened:
  f=opened[0];x=f['display_state_during_active']['offset'];timeline['first_new_image_reveal_pixel']={'frame':f['frame'],'xy':[x,0],'time_ps':f['first_pixel_time_ps']+x*40000,'basis':'Actual first row source/mask boundary, no OSD at row0'}
 if idle_new:
  f=idle_new[0];timeline['fully_revealed_frame']={'frame':f['frame'],'first_pixel_time_ps':f['first_pixel_time_ps'],'last_pixel_time_ps':f['last_pixel_time_ps']}
  if opened:timeline['first_reveal_to_full_open_firstpixel_ms']=(f['first_pixel_time_ps']-opened[0]['first_pixel_time_ps'])/1e9
 for name,key,target in [('commit_ACK_seen','commitACK',0),('front1_seen','front',1),('fullbackwrites_seen','writes',307200)]:
  hits=[f for f in frames if f['display_state_during_active'][key]==target]
  if hits:
   f=hits[0];prev=frames[f['frame']-1]if f['frame']else None;timeline[name+'_not_exactly_timestamped']={'first_observed_frame':f['frame'],'after_ps':prev['last_pixel_time_ps']if prev else None,'no_later_than_ps':f['last_pixel_time_ps'],'precision':'Between logged complete-frame state samples; no exact event latch.'}
 rw=re.search(r'READ_WRITE_SCOPE writes(\d+) writeFIFOmax(\d+) refreshes(\d+) loadstart(\d+) loadend(\d+) source_period16sysclocks realwriterfinishqualified(\d+)',log)
 if rw:
  writes,maxfifo,refresh,start,end,finished=map(int,rw.groups());assert writes==307200 and finished==1 and end-start==750000000000;timeline['model_load_wait']={'load_start_time_ps':start,'model_wait_end_time_ps':end,'wait_ms':750,'meaning':'loadstart is coverACK observation in source driver, loadend is end of explicit modelwait. Neither is physical TF duration.','actual_write_finish':'NOT_EXACTLY_TIMESTAMPED; source driver waits actualwrite_finish before loadend/candidate.','SPI_transport_only_lower_bound_ms':791.21,'750ms_shorter_than_physical_SPI_minimum':True}
 apngcheck=None
 if complete:
  p=run/'actual_rtl_samples.apng';raw=p.read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n';pos=8;controls=[];sequence=[];declared=None
  while pos<len(raw):
   size=struct.unpack('>I',raw[pos:pos+4])[0];typ=raw[pos+4:pos+8];data=raw[pos+8:pos+8+size];crc=struct.unpack('>I',raw[pos+8+size:pos+12+size])[0];assert zlib.crc32(typ+data)&0xffffffff==crc
   if typ==b'acTL':declared=struct.unpack('>II',data)
   if typ==b'fcTL':
    c=struct.unpack('>IIIIIHHBB',data);assert c[1:5]==(640,480,0,0)and c[7:]==(0,0);assert fractions.Fraction(c[5],c[6])==fractions.Fraction(21,1250);controls.append(c);sequence.append(c[0])
   if typ==b'fdAT':sequence.append(struct.unpack('>I',data[:4])[0])
   pos+=size+12
  assert pos==len(raw)and declared==(len(frames),0)and len(controls)==len(frames)and sequence==list(range(len(sequence)))
  with Image.open(p)as image:
   assert image.n_frames==len(frames)
   for f in frames:
    image.seek(f['frame']);assert image.convert('RGB').tobytes()==ppm(run/f"frame_{f['frame']:02d}.ppm")
  apngcheck={'path':str(p),'sha256':sha(p),'fcTL_count':len(controls),'decoded_frames':len(frames),'no_frame_merge_or_skip':True,'exact_delay_each':'21/1250s = 84/5000s =16.8ms','duration_ms':len(frames)*16.8,'all_chunk_CRC_and_sequences_valid':True,'decoded_RGB_matches_every_actualPPM':True}
 result={'state':'COMPLETE_ACTUAL_PREVIEW_AUDIT_PASS'if complete else'PARTIAL_ACTUAL_FRAMES_AUDIT_ONLY','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'script_sha256':sha(Path(__file__)),'complete_frames':len(frames),'native_frame_period_ms':16.8,'mask_and_source_RGB_pixels_checked':base,'frames':frames,'timeline':timeline,'APNG':apngcheck,'scope_limits':['Source driver and ordered10clk memory+20clk refresh are modeled; actual oldFIFO/video/transition/displaycommit/finaloverlay run. No encrypted SDRAM/HDMI/physical card or fullsystem/hardware claim.','Previewrefresh requests after3100memclocks are not production600/601 qualification; separate8frame600/601pressure eachPASS.','Audio peaks decoded offline over16.8ms windows; productionplayer64sample peaks are separately tested by actualPCMplayer→finalOSD shortcrop.','Finaltail2frames ends before33frame newcaption delay; separate21actualforward/reverse/wrap overlaycrops show naturaltyping, and12static captures showcompletedcards.']};dest=run/('preview_audit.json'if complete else'preview_audit_partial.json');dest.write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps({'state':result['state'],'frames':len(frames),'pixels':base,'path':str(dest)}));return 0
if __name__=='__main__':raise SystemExit(main())
