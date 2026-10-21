import pathlib,json,hashlib,datetime,os,traceback
from card_api import Handle,bitmap,free,extents,move,flush
root=pathlib.Path(r'D:\FPGA\hx4s20_tf_test_20261013')
plan=json.loads((root/'layout_plan.json').read_text());manifest={x['name']:x for x in json.loads((root/'manifest.json').read_text())}
log=dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=os.getpid(),operation='Windows FSCTL_MOVE_FILE; only three known BMP files; no raw disk writes',files=[],complete=False)
def save():(root/'relocation_result.json').write_text(json.dumps(log,indent=2))
# Verify backed-up originals and targets before any mutation.
for x in plan['files']:
 assert x['name'] in manifest and x['target_last_allocated_lba']<=131071
 for p in [root/x['name'],pathlib.Path('K:/')/x['name']]:assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256']
save()
try:
 with Handle(r'\\.\K:',access=0xc0000000) as vol:
  for x in plan['files']:
   p=pathlib.Path('K:/')/x['name']
   with Handle(str(p),share=1) as fh:
    before=extents(fh)
    expected=[dict(vcn=0,next_vcn=x['cluster_count'],lcn=x['target_lcn'],clusters=x['cluster_count'])]
    rec=dict(name=x['name'],before=before,target=expected,move_returned_success=False);log['files'].append(rec);save()
    if before!=expected:
     assert before==x['source_extents'],'Source changed; refusing move'
     start,total,bits=bitmap(vol)
     assert all(free(bits,start,c) for c in range(x['target_lcn'],x['target_lcn']+x['cluster_count'])),'Target is no longer free'
     move(vol,fh,x['target_lcn'],x['cluster_count']);rec['move_returned_success']=True
    else:rec['already_at_target']=True
    after=extents(fh);rec['after']=after;save();assert after==expected
   h=hashlib.sha256(p.read_bytes()).hexdigest();rec['sha256_after']=h;save();assert h==x['sha256']
  flush(vol);log['volume_flush_success']=True
 log['complete']=True
except BaseException as e:
 log['error']=repr(e);save();raise
save();print(json.dumps(log,indent=2))
