import pathlib,zipfile,json,hashlib,xml.etree.ElementTree as ET,datetime
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013');out=root/'official_source';out.mkdir(exist_ok=True)
base=pathlib.Path('G:/macshare/嵌赛/HX4S20_Contest_202606/7_lab_ex_2026_nosoft')
archive=next(base.glob('*.zip'));rows=[]
with zipfile.ZipFile(archive) as z:
 for i in z.infolist():
  n=i.filename
  pick=(n.startswith(('lab_ex4_tf/','lab_ex5_i2s/')) and (('/hdl_source/' in n and n.endswith('.v')) or n.endswith('convert_images_to_bmp.py') or n.endswith('设计参考例程文档.docx'))) or ('/' not in n and n.endswith('.docx'))
  if not pick:continue
  data=z.read(i);p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
  rows.append({'name':n,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
  if n.endswith('.docx'):
   with zipfile.ZipFile(p) as dz:
    x=ET.fromstring(dz.read('word/document.xml'));ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    text='\n'.join(''.join(t.itertext()) for t in x.findall('.//w:p',ns))
    p.with_suffix('.txt').write_text(text,encoding='utf-8')
(root/'official_source_manifest.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archive':str(archive),'members':rows},ensure_ascii=False,indent=2),encoding='utf-8')
print('Extracted',len(rows),'read-only reference members to independent evidence root')
