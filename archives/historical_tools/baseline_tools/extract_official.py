import pathlib,zipfile,json,hashlib,datetime
root=pathlib.Path(r'D:\FPGA\hx4s20_contest1_20261013')
root.mkdir(exist_ok=False)
for d in ['reference/official','audit','harness','builds','runs','reports','work']:(root/d).mkdir(parents=True,exist_ok=True)
archive=next(pathlib.Path('G:/macshare/嵌赛/HX4S20_Contest_202606/7_lab_ex_2026_nosoft').glob('*.zip'))
sha=lambda b:hashlib.sha256(b).hexdigest()
rows=[];skipped=[]
with zipfile.ZipFile(archive) as z:
 for i in z.infolist():
  n=i.filename
  if i.is_dir() or not n.startswith(('lab_ex4_tf/','lab_ex5_i2s/')):continue
  p=pathlib.PurePosixPath(n)
  assert '..' not in p.parts and not p.is_absolute()
  # Keep actual source/project/IP references, never cached EDA databases or bitstreams.
  if any(x in ('runs','impl','work') or x.endswith('_Runs') for x in p.parts) or p.suffix.lower() in ('.bit','.db','.bmp'):
   skipped.append(dict(name=n,bytes=i.file_size));continue
  data=z.read(i);dest=root/'reference/official'/n;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  rows.append(dict(name=n,bytes=len(data),sha256=sha(data)))
r=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),archive=str(archive),zip_sha256=sha(archive.read_bytes()),selected=rows,skipped=skipped)
(root/'audit/official_manifest.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
out=root/'audit/official_sources.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for x in rows:z.write(root/'reference/official'/x['name'],x['name'])
print(json.dumps(dict(root=str(root),archive=str(out),members=len(rows),bytes=out.stat().st_size,skipped=skipped),ensure_ascii=False))
