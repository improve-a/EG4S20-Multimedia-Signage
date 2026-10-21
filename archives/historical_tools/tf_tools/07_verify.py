import pathlib,struct,json,hashlib,datetime,os
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013')
geo=json.loads((root/'fat_before.json').read_text());items=json.loads((root/'manifest.json').read_text())
spc=geo['sectors_per_cluster'];datalba=geo['data_start_lba'];bps=512
results=[]
with open(r'\\.\PhysicalDrive3','rb',buffering=0) as disk:
 disk.seek((geo['partition_start_lba']+geo['reserved_sectors'])*512)
 fat=disk.read(geo['fat_sectors']*512)
 def chain(first):
  out=[];seen=set();c=first
  while c<0xffffff8:
   assert 2<=c<len(fat)//4 and c not in seen,(first,c)
   seen.add(c);out.append(c);c=struct.unpack_from('<I',fat,c*4)[0]&0xfffffff
  return out
 entries={}
 for c in chain(geo['root_cluster']):
  disk.seek((datalba+(c-2)*spc)*512);data=disk.read(spc*512)
  for off in range(0,len(data),32):
   e=data[off:off+32]
   if e[0]==0:break
   if e[0]==0xe5 or e[11]==0x0f or e[11]&0x18:continue
   name=e[:8].decode('ascii',errors='replace').rstrip()+'.'+e[8:11].decode('ascii',errors='replace').rstrip()
   entries[name]=(struct.unpack_from('<H',e,20)[0]<<16|struct.unpack_from('<H',e,26)[0],struct.unpack_from('<I',e,28)[0])
 for x in items:
  first,size=entries[x['name']];clusters=chain(first)
  contiguous=all(b==a+1 for a,b in zip(clusters,clusters[1:]))
  assert size==x['size'] and contiguous,(x['name'],size,clusters)
  lba=datalba+(first-2)*spc;count=(size+511)//512
  disk.seek(lba*512);raw=disk.read(count*512)[:size]
  rawhash=hashlib.sha256(raw).hexdigest();filedata=(pathlib.Path('K:/')/x['name']).read_bytes()
  assert rawhash==x['sha256']==hashlib.sha256(filedata).hexdigest()
  assert raw[:2]==b'BM' and struct.unpack_from('<I',raw,2)[0]==len(raw)
  assert struct.unpack_from('<I',raw,10)[0]==54
  assert struct.unpack_from('<IiiHHII',raw,14)==(40,640,480,1,24,0,921600)
  results.append(dict(name=x['name'],bytes=size,sha256=rawhash,first_cluster=first,clusters=clusters,contiguous=contiguous,first_lba=lba,last_file_lba=lba+count-1,last_allocated_lba=lba+len(clusters)*spc-1,default_scan_can_find=lba<=131071,raw_sequential_read_sha256_pass=True,bmp_header_pass=True))
 max_lba=max(x['last_file_lba'] for x in results)
 # Reproduce official header scan through new image end, reading only; skip full file after each match.
 matches=[];sector=0;chunk_start=-1;chunk=b'';chunk_sectors=8192
 while sector<=max_lba:
  if not chunk_start<=sector<chunk_start+len(chunk)//512:
   chunk_start=sector;disk.seek(sector*512);chunk=disk.read(min(chunk_sectors,max_lba-sector+1)*512)
  off=(sector-chunk_start)*512;b=chunk[off:off+54]
  if len(b)==54 and b[:2]==b'BM' and struct.unpack_from('<H',b,18)[0]==640 and struct.unpack_from('<H',b,22)[0]==480 and struct.unpack_from('<H',b,28)[0]==24 and struct.unpack_from('<I',b,30)[0]==0:
   length=struct.unpack_from('<I',b,2)[0];matches.append(dict(lba=sector,file_bytes=length));sector+=max(1,(length+511)//512)
  else:sector+=1
original=json.loads((root/'card_before_hashes.json').read_text(encoding='utf-8-sig'))
checks=[]
for x in original:
 p=pathlib.Path(x['path']);h=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
 checks.append(dict(path=x['path'],size=p.stat().st_size if p.exists() else None,sha256=h,unchanged=h==x['sha256'].lower() and p.stat().st_size==x['size']))
known={x['path'].lower() for x in original};now={str(p).lower() for p in pathlib.Path('K:/').rglob('*') if p.is_file()}
new=sorted(now-known)
report=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=os.getpid(),physical_access='read only',files=results,scan_end_lba=max_lba,scan_matches=matches,original_file_count=len(checks),original_files_unchanged=all(x['unchanged'] for x in checks),original_files_changed=[x for x in checks if not x['unchanged']],new_files=new,original_checks=checks)
(root/'verification.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
summary={k:v for k,v in report.items() if k!='original_checks'}
print(json.dumps(summary,indent=2,ensure_ascii=False))
assert report['original_files_unchanged']
assert new==sorted(str(pathlib.Path('K:/')/x['name']).lower() for x in items),new
assert {x['lba'] for x in matches}.issuperset(x['first_lba'] for x in results)
