#!/usr/bin/env python3
"""Build a labelled contact sheet only from verified actualRTLoutput PNGs.
No HTML or softwaregold used as picture input. Contact thumbnails are nearest2:1.
"""
import argparse,datetime,hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,__version__
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--static-root',type=Path,required=True);ap.add_argument('--default-root',type=Path);ap.add_argument('--six-pages',action='store_true');ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();d=json.loads((a.static_root/'status.json').read_text());a.output.mkdir(exist_ok=True)
 if not a.six_pages:
  if not a.default_root:ap.error('--default-root required for12case contact')
  e=json.loads((a.default_root/'verification.json').read_text());assert d['state']=='ACTUAL_RTL_STATIC_PASS'and e['state']=='ACTUAL_DEFAULT_HOME2X_SEGMENTS_PASS'
 else:assert len(d['cases'])>=6 and all(c['state']=='PASS' and c['case']=='page'+str(i)for i,c in enumerate(d['cases'][:6]))
 items=[]
 for c in (d['cases'][:6]if a.six_pages else d['cases']):
  assert c['state']=='PASS';p=Path(c['actual_output_png']);assert sha(p)==c['actual_output_sha256'];items.append((c['case'],p,c['actual_output_sha256'],c['child_evidence']))
 if not a.six_pages:
  p=Path(e['actual_output_png']);assert sha(p)==e['actual_output_sha256'];items.append(('HOME default2x focus0',p,e['actual_output_sha256'],e['child_evidence']));assert len(items)==12
 cols,tw,th=(3,640,480)if a.six_pages else(4,320,240);rows=(len(items)+cols-1)//cols;cellh=th+28;width=cols*tw;height=36+rows*cellh+18
 sheet=Image.new('RGB',(width,height),(24,24,24));draw=ImageDraw.Draw(sheet);font=ImageFont.load_default(size=15);small=ImageFont.load_default(size=12)
 draw.text((12,8),('Six actual final RTL frames: HOME / EAGLE / PHOENIX / ELF / DRAGON / ECO'if a.six_pages else'Actual final RTL outRGB: 6pages, 2dual, 3zoom combinations, HOME default2x'),font=font,fill=(238,238,238));records=[]
 for i,(name,p,digest,child)in enumerate(items):
  x=(i%cols)*tw;y=36+(i//cols)*cellh;draw.text((x+6,y+5),name,font=font,fill=(238,238,238))
  with Image.open(p)as im:
   im=im.convert('RGB');assert im.size==(640,480);thumb=im if a.six_pages else im.resize((tw,th),Image.Resampling.NEAREST);sheet.paste(thumb,(x,y+26))
   if a.six_pages:assert sheet.crop((x,y+26,x+tw,y+26+th)).tobytes()==im.tobytes()
  records.append({'case':name,'actual_source_png':str(p),'sha256':digest,'child_evidence':child,'contact_position':[x,y+26],'thumbnail':'full640x480 exactRGBcopy'if a.six_pages else'nearest2:1visualsummary; full640x480PPM/PNGremainWindows'})
 draw.text((12,height-16),'Single actual frames; OSD state only prewarmed. Geometry, loaded pixels, FIFO and final output execute. Not continuous preview.',font=small,fill=(238,238,238));f=a.output/('six_page_actual_contact.png'if a.six_pages else'contact_sheet.png');sheet.save(f)
 report={'scope':__doc__,'state':'ACTUAL_RTL_CONTACT_SHEET_READY','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'path':str(f),'sha256':sha(f),'image_size':[width,height],'pillow_version':__version__,'sources':records,'boundaries':'Singleframe staticOSDprewarm, separateactualloader+scanoutsegments. Fullcontinuous12close/wait/18open hasindependentAPNG. HTMLcomparisontriptychsretainedWindows.'};(a.output/('six_page_actual_contact.json'if a.six_pages else'contact_sheet.json')).write_bytes((json.dumps(report,indent=2)+'\n').encode());print(f);return 0
if __name__=='__main__':raise SystemExit(main())
