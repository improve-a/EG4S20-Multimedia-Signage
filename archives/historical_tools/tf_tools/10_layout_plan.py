import pathlib,json,struct,hashlib,datetime,os
from card_api import Handle,bitmap,free,extents
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013');geo=json.loads((root/'fat_before.json').read_text());items=json.loads((root/'manifest.json').read_text());old=json.loads((root/'verification.json').read_text())
spc=geo['sectors_per_cluster'];base=geo['data_start_lba'];need=sum((x['size']+spc*512-1)//(spc*512) for x in items)
with Handle(r'\\.\K:') as vol:
 start,total,bits=bitmap(vol)
 maxlcn=(131071-base+1)//spc-1
 run=0;target=None
 for lcn in range(max(1,start),maxlcn+1):
  run=run+1 if free(bits,start,lcn) else 0
  if run>=need:target=lcn-need+1;break
 assert target is not None,'No contiguous free region inside official scan range'
 plans=[];dest=target
 for x in items:
  p=pathlib.Path('K:/')/x['name'];assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256']
  with Handle(str(p),share=1) as h:e=extents(h)
  previous=next(z for z in old['files'] if z['name']==x['name'])
  assert len(e)==1 and e[0]['lcn']==previous['first_cluster']-2,'LCN/FAT mapping or source layout changed; re-audit before move'
  count=(x['size']+spc*512-1)//(spc*512)
  assert e[0]['vcn']==0 and e[0]['clusters']==count
  plans.append(dict(name=x['name'],sha256=x['sha256'],source_extents=e,target_lcn=dest,target_fat_cluster=dest+2,cluster_count=count,target_first_lba=base+dest*spc,target_last_allocated_lba=base+(dest+count)*spc-1))
  dest+=count
with open(r'\\.\PhysicalDrive3','rb',buffering=0) as disk:
 disk.seek((geo['partition_start_lba']+geo['reserved_sectors'])*512);fat=disk.read(geo['fat_sectors']*512)
 for plan in plans:
  assert plan['target_last_allocated_lba']<=131071
  for c in range(plan['target_fat_cluster'],plan['target_fat_cluster']+plan['cluster_count']):assert struct.unpack_from('<I',fat,c*4)[0]&0xfffffff==0
r=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=os.getpid(),operation='read-only targeted relocation plan',bitmap_start_lcn=start,bitmap_clusters=total,official_max_lba=131071,files=plans)
(root/'layout_plan.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
