#!/usr/bin/env python3
"""Separate source-pixel correctness from browser/OSD appearance diagnostics.
Only actual RTL PPM is measured. Software expected pixels never become previews.
"""
import argparse,datetime,hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def module(name,p):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def difference(a,b,indices):
 count=0;different=0;channels=0;total=0;maximum=0;examples=[]
 for n in indices:
  at=n*3;v=[abs(a[at+i]-b[at+i])for i in range(3)];count+=1;different+=int(any(v));channels+=sum(x!=0 for x in v);total+=sum(v);maximum=max(maximum,*v)
  if any(v)and len(examples)<4:examples.append({'x':n%640,'y':n//640,'actual':list(a[at:at+3]),'target':list(b[at:at+3])})
 return {'pixels':count,'different_pixels':different,'different_channels':channels,'exact_pixel_fraction':(count-different)/count,'mean_abs_error_per_RGB_channel':total/(count*3),'max_abs_channel_difference':maximum,'first_differences':examples}
def rectangle(x0,y0,x1,y1):return[y*640+x for y in range(y0,y1)for x in range(x0,x1)]
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--static-root',type=Path,required=True);ap.add_argument('--default-root',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--available',action='store_true');a=ap.parse_args();a.output.mkdir(exist_ok=True)
 status=json.loads((a.static_root/'status.json').read_text());default=json.loads((a.default_root/'verification.json').read_text());selected=[c for c in status['cases']if c['state']=='PASS'];final=len(selected)==11 and default['state']=='ACTUAL_DEFAULT_HOME2X_SEGMENTS_PASS'
 if not a.available:assert final
 if default['state']=='ACTUAL_DEFAULT_HOME2X_SEGMENTS_PASS':selected.append({'case':'HOME_default2x','page':0,'dual':False,'zoom':2,'focus':0,'child_evidence':default['child_evidence']})
 pix=module('pixel_decode',ROOT/'scripts/html_display_chain_verify.py');oracle=module('independent_geometry',ROOT/'scripts/no_bot_legacy_oracle.py');base_indices=[y*640+x for y in range(480)for x in range(640)if not(x>=500 and y<105)and not(24<=x<510 and 386<=y<466)];right=rectangle(510,105,640,480);tail=rectangle(510,416,516,429)
 rois={'card_signature_products_guide':(42,397,94,417),'card_subheading':(94,397,202,417),'caption_body':(42,416,434,455),'inner_card_without_audio':(27,388,443,458),'flat_paper_plate':(30,389,434,397)};names=['home','eagle','phoenix','elf','dragon','eco'];rows=[]
 for c in selected:
  child=Path(c['child_evidence']);e=json.loads((child/'verification.json').read_text());assert e['state']=='LEGACY_DISPLAY_SEGMENT_PASS';actual=pix.ppm_read(child/'frame_00.ppm');w,h,png=pix.png_read(child/'frame_00.png');assert(w,h)==(640,480)and png==actual
  expected,meta=oracle.expected_rgb(c['page'],c['dual'],c['zoom']-1,c['focus']);load=e['loader_payload'];assert sha(Path(load['actual_loader_dump']))==load['sha256'];oracle.verify_loader_dump(Path(load['actual_loader_dump']),expected)
  base=difference(actual,expected,base_indices);nobot=difference(actual,expected,right);removedtail=difference(actual,expected,tail)
  reference=ROOT/'output/html_fidelity/no_bot/reference'/('reference_'+('dual'if c['dual']else names[c['page']])+'.png');w,h,ref=pix.png_read(reference);assert(w,h)==(640,480)
  osd={name:{'ROI_xy_exclusive':[x0,y0,x1,y1],'diagnostic_vs_noBot_browser':difference(actual,ref,rectangle(x0,y0,x1,y1))}for name,(x0,y0,x1,y1)in rois.items()}
  if not c['dual']and c['zoom']==1:osd['page_index_no_progress']={'ROI_xy_exclusive':[528,22,608,42],'diagnostic_vs_noBot_browser':difference(actual,ref,rectangle(528,22,608,42))}
  row={'case':c['case'],'child_snapshot':str(child),'actual_PPM_sha256':sha(child/'frame_00.ppm'),'actual_PNG_sha256':sha(child/'frame_00.png'),'PNG_decoded_equals_actual_PPM':True,'source_oracle':meta,'actual_loader_dump':load,'static_base_vs_exact_loaded_source':base,'right_background_noBot_vs_exact_loaded_source':nobot,'removed_tail_vs_exact_loaded_source':removedtail,'noBot_browser_reference':str(reference),'noBot_browser_reference_sha256':sha(reference),'OSD_target_diagnostics':osd,'audio_stimulus':e['audio_stimulus'],'audio_playback_proven_by_picture':False,'static_OSD_state_prewarmed':e['static_caption_fixture']};rows.append(row)
 failures=[x['case']for x in rows if any(x[k]['different_pixels']for k in ['static_base_vs_exact_loaded_source','right_background_noBot_vs_exact_loaded_source','removed_tail_vs_exact_loaded_source'])]
 report={'state':'SOURCE_PIXEL_FAILURE'if failures else'COMPLETE_SOURCE_PIXEL_PASS_WITH_BROWSER_DIAGNOSTICS'if final else'PARTIAL_AVAILABLE_SOURCE_PIXEL_PASS_WITH_BROWSER_DIAGNOSTICS','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':__doc__,'measured_cases':len(rows),'expected_cases':12,'all12_ready':final,'source_pixel_failure_cases':failures,'script_sha256':sha(Path(__file__)),'dependencies_sha256':{n:sha(ROOT/n)for n in ['scripts/html_display_chain_verify.py','scripts/no_bot_legacy_oracle.py']},'definitions':{'static_base':'Outside x>=500,y<105 HUDwindow and x24..509,y386..465card+shadow. Everyremainingpixel compared to independently verifiedactual loaderdump mapping; zeroerror is transport/source correctness.','OSD_diagnostic':'Actualcard/signature/body/pageindex RGB compared to noBotHTMLreference only. No thresholds or hiddenfontnormalization. Browserfont/coverage/baseline differences belonghere, never to source-loading error.','dynamic_exclusions':'Waveform/audio-status label, progress ticks and zoom badge are excluded from browserdiagnostic ROIs. Innercard opaqueRGB permits same caption reference acrosszoom; dualcard uses genericdualreference. Pageindex compared only6matched1xpages.','home_baseline':'NoBotbrowserhomeChrome154baseline415 versus normalizedROM416; retainactual1pxdifference inOSDmetric.','audio':'FinalWAVdecodedofflineinto native16.8msPCMpeakROM. Pictureprovesonlyfixture-drivenvisualizerRTL, never playback; parser/player/loadcontention/HDMI tests are separate.','fullframe_MAE':'OldfullframeRGBMAE is holisticdiagnosticonly; do notlabelitstaticbottomloaderror.'},'cases':rows};(a.output/'visual_metrics.json').write_bytes((json.dumps(report,indent=2)+'\n').encode());print(json.dumps({'state':report['state'],'cases':len(rows),'failures':failures,'base_pixels_each':len(base_indices),'path':str(a.output/'visual_metrics.json')}));return 1 if failures else 0
if __name__=='__main__':raise SystemExit(main())
