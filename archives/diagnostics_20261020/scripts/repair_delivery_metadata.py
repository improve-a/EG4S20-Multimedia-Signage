"""Correct the archive digest after ZIP central-directory close; no build changes."""
import hashlib,json,pathlib,zipfile
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020');d=r/'delivery'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=d/'FINAL_MANIFEST.json';old=p.read_bytes();m=json.loads(old)
bad=[f['name'] for f in m['files'] if sha(d/f['name'])!=f['sha256']]
assert bad==['rca_verification.zip'],bad
with (r/'audit/FINAL_MANIFEST_before_zip_close_fix.json').open('xb') as f:f.write(old)
zpath=d/'rca_verification.zip';temp=r/'audit/rca_verification_repacked.zip'
with zipfile.ZipFile(zpath) as src, zipfile.ZipFile(temp,'x',zipfile.ZIP_DEFLATED) as dst:
 for item in src.infolist():
  data=(r/'scripts/finalize_delivery.py').read_bytes() if item.filename=='scripts/finalize_delivery.py' else src.read(item)
  dst.writestr(item,data)
temp.replace(zpath)
for entry in m['files']:
 f=d/entry['name'];entry.update(bytes=f.stat().st_size,sha256=sha(f))
p.write_text(json.dumps(m,indent=2),encoding='utf-8')
with (d/'SHA256SUMS.txt').open('w',encoding='utf-8') as f:
 for x in sorted(d.iterdir()):
  if x.is_file() and x.name!='SHA256SUMS.txt':f.write(sha(x)+'  '+x.name+'\n')
assert all(sha(d/f['name'])==f['sha256'] for f in m['files'])
print('FINAL_MANIFEST_ALL_ENTRIES_VERIFIED',len(m['files']))
