import pathlib,json,hashlib,os,datetime,struct
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013')
items=json.loads((root/'manifest.json').read_text())
for x in items:
 p=pathlib.Path('K:/')/x['name']
 assert not p.exists(),f'Refusing to overwrite {p}'
 data=(root/x['name']).read_bytes()
 assert len(data)==921654 and hashlib.sha256(data).hexdigest()==x['sha256']
 assert struct.unpack_from('<IiiHHI',data,14)==(40,640,480,1,24,0)
result=[]
for x in items:
 p=pathlib.Path('K:/')/x['name']; data=(root/x['name']).read_bytes()
 with p.open('xb') as f:
  f.write(data);f.flush();os.fsync(f.fileno())
 h=hashlib.sha256(p.read_bytes()).hexdigest()
 assert h==x['sha256']
 result.append(dict(name=x['name'],path=str(p),size=p.stat().st_size,sha256=h,verified=True))
 report=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=os.getpid(),operation='exclusive create, flush, close, readback SHA256',files=result)
 (root/'copy_result.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
