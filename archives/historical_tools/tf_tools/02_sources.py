import pathlib,zipfile,json,datetime
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013')
base=pathlib.Path('G:/macshare/嵌赛/HX4S20_Contest_202606')
archives=list((base/'7_lab_ex_2026_nosoft').glob('*.zip'))+list((base/'2_Example').glob('*.zip'))
rows=[]
for p in archives:
 with zipfile.ZipFile(p) as z:
  names=[{'name':i.filename,'bytes':i.file_size} for i in z.infolist() if not i.is_dir()]
  rows.append({'archive':str(p),'files':names})
r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archives':rows}
(root/'source_zip_inventory.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
for item in rows:
 print('ARCHIVE',item['archive'],'FILES',len(item['files']))
 for f in item['files']:
  n=f['name'].lower()
  if any(x in n for x in ['.pdf','.doc','.zip','bmp','sd_','sdcard','sd_card','fat','赛题','题一']):print(json.dumps(f,ensure_ascii=False))
