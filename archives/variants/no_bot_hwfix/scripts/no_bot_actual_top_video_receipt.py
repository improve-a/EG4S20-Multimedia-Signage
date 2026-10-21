#!/usr/bin/env python3
"""Summarize the existing actual-top first frame; never renders or changes pixels."""
import sys,json,hashlib,datetime
from pathlib import Path
p=Path(sys.argv[1]);log=(p/'runtime.log').read_text(errors='replace')
if 'ACTUAL_HDMI_IMAGE_FRAME_PASS' not in log:raise SystemExit('NOT_READY: complete captured frame not logged')
b=(p/'actual_hdmi_input.ppm').read_bytes();header=b'P6\n640 480\n255\n'
assert b.startswith(header) and len(b)==len(header)+640*480*3
rgb=b[len(header):];gold=bytes.fromhex(''.join((p/'gold_image.hex').read_text().split()));checked=0;mismatch=0
for y in range(480):
 for x in range(640):
  if (x>=500 and y<105) or (24<=x<510 and 386<=y<466):continue
  i=(y*640+x)*3;checked+=1;mismatch+=rgb[i:i+3]!=gold[i:i+3]
assert mismatch==0
s=json.loads((p/'status.json').read_text());events=[line for line in log.splitlines() if line.startswith(('ACTUAL_RESET','ACTUAL_WRITE','ACTUAL_COMMIT','ACTUAL_DISPLAY','ACTUAL_CAPTURE','ACTUAL_HDMI'))]
d={'state':'ACTUAL_TOP_VIDEO_INPUT_PASS','recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'run':str(p),'actual_top_input_hashes':s['input_hashes'],'card_sha256':s['card_sha256'],'pixels':307200,'rgb_nonzero_pixels':sum(rgb[i:i+3]!=bytes(3) for i in range(0,len(rgb),3)),'exact_non_OSD_gold_pixels':checked,'mismatches':mismatch,'ppm_sha256':hashlib.sha256(b).hexdigest(),'events':events,'remaining_case_state':s['state'],'scope':'Original image -> actual scanner/loader -> actual generatedFIFO/frame_read_write -> actual transition/config/OSD/AXIS -> HDMI input monitor. Leaf SDRAM/card/PLL models; protected HDMI receiver/PHY and hardware NOT_VERIFIED. Audio outcome is separately pending until actual-top test finishes.'}
(p/'video_input_receipt.json').write_bytes((json.dumps(d,indent=2)+'\n').encode());print(json.dumps({k:v for k,v in d.items() if k!='actual_top_input_hashes'},indent=2))
