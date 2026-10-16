"""Recover only derived display artifacts after a proven runner postprocess error.
OriginalDUT PPMs, simulation/source snapshots and failedrunner records stay intact.
"""
import argparse,datetime,hashlib,importlib.util,json,shutil,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
NAMES=['home','eagle','phoenix','elf','dragon','eco']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load_pixels(path):
 spec=importlib.util.spec_from_file_location('fixed_pixels',path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def rectangle(x,y,w,h):return {yy*640+xx for yy in range(max(0,y),min(480,y+h)) for xx in range(max(0,x),min(640,x+w))}
def stats(actual,reference,mask):
 if not mask:return {'pixels':0,'available':False}
 histogram=[0]*256;total=exact=above8=above32=0
 for index in mask:
  offset=index*3;errors=[abs(actual[offset+c]-reference[offset+c]) for c in range(3)];total+=sum(errors);maximum=max(errors);exact+=maximum==0;above8+=maximum>8;above32+=maximum>32
  for error in errors:histogram[error]+=1
 target=(len(mask)*3*95+99)//100;count=0;p95=0
 for error,n in enumerate(histogram):
  count+=n
  if count>=target:p95=error;break
 return {'pixels':len(mask),'rgb_mae':total/(len(mask)*3),'exact_pixels':exact,'pixels_with_channel_error_above8':above8,'pixels_with_channel_error_above32':above32,'p95_channel_absolute_error':p95,'scope':'Rawregional RGBdifference indicators, no perceptualquality score/pass threshold'}

def regional_metrics(pixels,frames,project=ROOT,preserve=None):
 from PIL import Image
 layer_root=project/'output/html_fidelity/layers';asset_root=project/'output/html_fidelity/assets';manifest_path=layer_root/'hfxl_payload_manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf8'));result={'scope':'Sixstaticnormalpages only. Bot/caption use sourcecompositePNG withdisclosedfixedDUTpose/fulltext; scene/product use cleanA sourcePNG. Regionmasks mayoverlap. FullscreenMAE isnotan overallfidelityscore.','layout_manifest_sha256':sha(manifest_path),'pages':[]}
 def retain(path):
  if preserve:
   target=preserve/path.name;target.parent.mkdir(parents=True,exist_ok=True)
   if not target.exists():shutil.copy2(path,target)
  return sha(path)
 retain(manifest_path)
 for index,name in enumerate(NAMES):
  frame=frames/f'page{index}.ppm'
  if not frame.exists():continue
  if frame.stat().st_size<921615:
   result.setdefault('unfinished_frames',[]).append(str(frame));continue
  actual=pixels.ppm_read(frame)
  if len(actual)!=640*480*3:
   result.setdefault('unfinished_frames',[]).append(str(frame));continue
  composite_path=asset_root/f'reference_{name}.png';clean_path=asset_root/f'A_{index+1:02d}_{name}.png';w,h,composite=pixels.png_read(composite_path);cw,ch,clean=pixels.png_read(clean_path)
  if (w,h,cw,ch)!=(640,480,640,480):raise ValueError('regionalreference dimensionschanged')
  sources={str(composite_path):retain(composite_path),str(clean_path):retain(clean_path)};product=set();text=set()
  page=manifest['pages'][index]
  for component in page['components']:
   role=component['role']
   if role not in ['hero','family','giant','data-in','chrome','credit']:continue
   path=layer_root/component['source_rgba_png'];sources[str(path)]=retain(path);x,y,bw,bh=component.get('source_rgba_bounds',component['bbox'])
   with Image.open(path) as image:
    rgba=image.convert('RGBA');iw,ih=rgba.size;alpha=rgba.getchannel('A').tobytes()
   if (iw,ih)!=(bw,bh):raise ValueError('sourcecomponent mask/bbox mismatch '+str(path))
   mask={((y+dy)*640+x+dx) for dy in range(ih) for dx in range(iw) if 0<=x+dx<640 and 0<=y+dy<480 and alpha[dy*iw+dx]>0}
   (product if role in ['hero','family'] else text).update(mask)
  caption=rectangle(42,397,392,58);ink={i for i in caption if max(abs(composite[i*3+c]-[237,233,226][c]) for c in range(3))>4}
  regions={'bot_104x100':stats(actual,composite,rectangle(520,368,104,100)),'bot_eye_area':stats(actual,composite,rectangle(552,411,42,25)),'caption_rectangle':stats(actual,composite,caption),'caption_source_ink':stats(actual,composite,ink),'scene_text_and_data_source_alpha':stats(actual,clean,text),'product_source_alpha':stats(actual,clean,product)}
  result['pages'].append({'page':name,'dut_ppm_sha256':sha(frame),'references_and_masks':sources,'regions':regions,'mask_definition':'Captionink differsfromopaquepaper>4; scene/product support fromunchangedsourceRGBA alpha>0 indeclaredsource_rgba_bounds clippedtoviewport; formaltexturebboxmaytrimoffscreenpixels. Neither masknorDUTRGB isredrawn.'})
 return result

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--run',required=True,type=Path);ap.add_argument('--failure-log',required=True,type=Path);ap.add_argument('--original-exit-code',required=True,type=int);ap.add_argument('--fixed-runner',type=Path,default=ROOT/'scripts/html_display_chain_verify.py');a=ap.parse_args();run=a.run;original=json.loads((run/'verification.json').read_text(encoding='utf8'));log=(run/'simulation.log').read_text();failure=a.failure_log.read_text(errors='replace')
 if a.original_exit_code==0 or 'NameError' not in failure or 'frames' not in failure:raise ValueError('requires actualpreservedoriginalrunner NameError/exit evidence')
 if 'DISPLAY_CHAIN_SIM_PASS' not in log:raise ValueError('RTLsimulation notcompleted/passed')
 simulation=[step for step in original['steps'] if step['name']=='simulation'][-1]
 if simulation.get('exit_code')!=0:raise ValueError('actualVVP exitnotPASS')
 resume=run/('postprocess_resume_'+time.strftime('%Y%m%d_%H%M%S'));resume.mkdir();origin=resume/'original_run_records';origin.mkdir()
 for name in ['verification.json','root_commit_provenance.json','compile.log']:
  if (run/name).exists():shutil.copy2(run/name,origin/name)
 (resume/'scripts').mkdir();shutil.copy2(a.fixed_runner,resume/'scripts/html_display_chain_verify.py');shutil.copy2(Path(__file__),resume/'scripts/html_display_chain_postprocess.py');shutil.copy2(a.failure_log,resume/'original_runner_failure.log');shutil.copy2(run/'simulation.log',resume/'simulation.log')
 asset_target=resume/'output/html_fidelity/assets';asset_target.mkdir(parents=True)
 for pattern in ['reference_*.png','A_*.png']:
  for source in (ROOT/'output/html_fidelity/assets').glob(pattern):shutil.copy2(source,asset_target/source.name)
 destination=resume/'output/html_fidelity/display_chain';destination.mkdir(parents=True);source_hashes={}
 for source in sorted((run/'output/html_fidelity/display_chain').glob('*.ppm')):
  source_hashes[source.name]=sha(source);shutil.copy2(source,destination/source.name)
 if len(source_hashes)!=18:raise ValueError('requires all18actualDUTPPMs')
 pixels=load_pixels(resume/'scripts/html_display_chain_verify.py');completion=pixels.completion_counts(log,False);frames=pixels.compare_frames(resume)
 if len(frames)!=18:raise ValueError('not18derivedframe records')
 preview=pixels.make_action_preview(resume);regions=regional_metrics(pixels,resume/'frames',ROOT,resume/'source_region_masks');(resume/'regional_metrics.json').write_bytes(json.dumps(regions,indent=2).encode())
 for source in (run/'output/html_fidelity/display_chain').glob('*.ppm'):
  if sha(source)!=source_hashes[source.name]:raise ValueError('originalDUT PPMchanged')
 current_source_differences={}
 for name,old_sha in original['sources'].items():
  current=ROOT/name
  if current.exists() and sha(current)!=old_sha:current_source_differences[name]={'run_sha256':old_sha,'current_sha256':sha(current)}
 report={'original_source_sha256':original['sources'],'current_source_differences_at_postprocess':current_source_differences,'source_identity_scope':'Simulation proves only the frozen run sources. Later source changes require explicit independent equivalence evidence; current hashes are recorded without extending this run claim.','original_run_record_sha256':{str(p.relative_to(resume)):sha(p) for p in origin.iterdir()},'state':'DISPLAY_CHAIN_SIM_PASS_POSTPROCESS_RECOVERED','source_run':str(run),'resume':str(resume),'original_runner_sha256':original['sources']['scripts/html_display_chain_verify.py'],'fixed_runner_sha256':sha(resume/'scripts/html_display_chain_verify.py'),'resume_script_sha256':sha(resume/'scripts/html_display_chain_postprocess.py'),'original_runner_exit_code':a.original_exit_code,'original_runner_verification_preserved_sha256':sha(run/'verification.json'),'failure_log_sha256':sha(a.failure_log),'simulation_log_sha256':sha(run/'simulation.log'),'scope':'Original18RTLsimulation passed; originalrunner failed onlyPNGpostprocessing. Resumedfixedfunctions transformonlyexportedactualRGB tolosslessartifacts. Noresimulation/redraw/source/log/failedrecordoverwrite.','fifo_capacity':{'physical_words':512,'usable_words':511,'full_threshold':'addr_diff>=511','source':'actualgeneratedvendorFIFO/GrayCDC RTL; internalarrayRAM model; noanalog/HWclaim'},'audio_scope':original.get('audio_stimulus',{}),'completion':completion,'original_dut_ppm_sha256':source_hashes,'frames':frames,'action_preview':preview,'regional_metrics_sha256':sha(resume/'regional_metrics.json'),'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 (resume/'verification.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2));return 0
if __name__=='__main__':raise SystemExit(main())
