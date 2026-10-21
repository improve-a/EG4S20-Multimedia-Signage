import pathlib,struct,json,datetime
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013')
raw=(root/'inventory.json').read_bytes()
inv=json.loads(raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig'))
assert inv['disk']['Number']==3 and inv['disk']['SerialNumber']=='000000001532' and inv['volume']['FileSystem']=='FAT32'
part=inv['partition']['Offset']//512
with open(r'\\.\PhysicalDrive3','rb',buffering=0) as f:
 f.seek(part*512);b=f.read(512)
 assert b[510:512]==b'\x55\xaa'
 bps=struct.unpack_from('<H',b,11)[0];spc=b[13];reserved=struct.unpack_from('<H',b,14)[0];nf=b[16];fatsz=struct.unpack_from('<I',b,36)[0];total=struct.unpack_from('<I',b,32)[0];rootc=struct.unpack_from('<I',b,44)[0]
 assert bps==512 and fatsz>0 and b[82:90]==b'FAT32   '
 datalba=part+reserved+nf*fatsz
 maxcluster=(131071-datalba+1)//spc+1
 fatbytes=((max(0,maxcluster)+1)*4+511)//512*512
 f.seek((part+reserved)*512);fat=f.read(fatbytes)
 free=[];run=None
 for c in range(2,maxcluster+1):
  v=struct.unpack_from('<I',fat,c*4)[0]&0xfffffff
  if v==0:
   if run is None:run=c
  elif run is not None:free.append((run,c-run));run=None
 if run is not None:free.append((run,maxcluster+1-run))
 runs=[{'first_cluster':c,'clusters':n,'first_lba':datalba+(c-2)*spc,'last_lba':datalba+(c+n-2)*spc-1,'bytes':n*spc*512} for c,n in free]
 r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'device':r'\\.\PhysicalDrive3','access':'read-only','partition_start_lba':part,'bytes_per_sector':bps,'sectors_per_cluster':spc,'reserved_sectors':reserved,'fat_count':nf,'fat_sectors':fatsz,'total_sectors':total,'root_cluster':rootc,'data_start_lba':datalba,'official_scan_last_lba':131071,'free_runs_within_scan':runs,'free_bytes_within_scan':sum(x['bytes'] for x in runs)}
(root/'fat_before.json').write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))
