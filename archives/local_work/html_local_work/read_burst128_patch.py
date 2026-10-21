from pathlib import Path
import json,hashlib,difflib,pprint,runpy,zipfile,datetime
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');o=r/'output/html_fidelity/verification/read_burst128_v1';o.mkdir(parents=True,exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
mempath=r/'scripts/apply_html_memory_controller.py';old_script=mempath.read_text();api=runpy.run_path(str(mempath));baselines={}
for name,spec in api['FILES'].items():
    before=(r/name).read_text();assert sha(before.encode())==spec['result_text_sha256']
    lines=before.splitlines(True);offset=0;reverse=[]
    for edit in spec['edits']:
        start=edit['start']+offset;reverse.append((start,start+len(edit['new']),edit))
        offset+=len(edit['new'])-len(edit['old'])
    for start,end,edit in reversed(reverse):
        assert lines[start:end]==edit['new'];lines[start:end]=edit['old']
    original=''.join(lines);assert sha(original.encode())==spec['baseline_text_sha256']
    assert api['apply_text'](name,original)[0]==before
    baselines[name]=(original,spec['baseline_sha256'])
changes={}
for name in ['rtl/SD/frame_read_write.v','rtl/top_tf_hdmi_audio.v']:
    p=r/name;before=p.read_text();s=before
    if name.endswith('frame_read_write.v'):
        target='\tparameter BURST_SIZE             = 256,\n';assert s.count(target)==1
        s=s.replace(target,target+'\tparameter READ_BURST_SIZE        = BURST_SIZE, // display reserve independent of write burst\n')
        split=s.index('frame_fifo_read\n');a,b=s[:split],s[split:]
        target='\t.BURST_SIZE                 (BURST_SIZE               )';assert b.count(target)==1
        b=b.replace(target,'\t.BURST_SIZE                 (READ_BURST_SIZE          )');s=a+b
        assert a.count(target)==1 # writer still retains original 256/default
    else:
        target='.WRITE_V_FLIP     (1),.READ_DRAIN_CYCLES(13),.ENABLE_LINEAR_CONFIG(1),.ENABLE_READ_SOURCE(1),'
        assert s.count(target)==1;s=s.replace(target,target.replace('.READ_DRAIN_CYCLES(13)', '.READ_DRAIN_CYCLES(13),.READ_BURST_SIZE(128)'))
    (o/(p.name+'.before')).write_bytes(before.encode());(o/(p.name+'.diff')).write_bytes(''.join(difflib.unified_diff(before.splitlines(True),s.splitlines(True),fromfile=name+'.before',tofile=name)).encode());p.write_bytes(s.encode())
    changes[name]={'before_sha256':sha(before.encode()),'after_sha256':sha(p.read_bytes())}
def rebuild(script, originals, audit_name):
    old=script.read_text();files={}
    for name,(before,rawsha) in originals.items():
        after=(r/name).read_text();a=before.splitlines(True);b=after.splitlines(True)
        edits=[dict(start=i,end=j,old=a[i:j],new=b[k:l]) for tag,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes() if tag!='equal']
        files[name]=dict(baseline_sha256=rawsha,baseline_text_sha256=sha(before.encode()),result_text_sha256=sha(after.encode()),edits=edits)
    new=old[:old.index('FILES=')]+'FILES='+pprint.pformat(files,width=110,sort_dicts=False)+'\n\n'+old[old.index('def digest'):]
    script.write_bytes(new.encode());newapi=runpy.run_path(str(script));checks=[]
    for name,(original,_) in originals.items():
        result,changed=newapi['apply_text'](name,original);assert changed and result==(r/name).read_text()
        again,changed=newapi['apply_text'](name,result);assert not changed and again==result
        try:newapi['apply_text'](name,original+'// foreign edit\n')
        except ValueError:pass
        else:raise AssertionError('foreign edit accepted')
        checks.append(dict(path=name,baseline_rebuild='PASS',idempotence='PASS',foreign_edit_rejection='PASS',sha256=sha(result.encode())))
    (o/audit_name).write_bytes(json.dumps(checks,indent=2).encode())
rebuild(mempath,baselines,'memory_replay_v2.json')
manifest={x['path']:x['sha256'] for x in json.loads((r/'docs/local_dependencies.json').read_text())['dependencies']};originals={}
with zipfile.ZipFile(r/'output/html_fidelity/integration_baseline.zip') as z:
    for name in ['rtl/top_tf_hdmi_audio.v','rtl/SD/frame_fifo_write.v','rtl/SD/bmp_read.v']:
        raw=z.read(name);assert sha(raw)==manifest[name];originals[name]=(raw.decode().replace('\r\n','\n'),sha(raw))
rebuild(r/'scripts/apply_html_integration.py',originals,'integration_replay_v5.json')
record={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'changes':changes,'read_burst':128,'write_burst':256,'legacy_default':'READ_BURST_SIZE=BURST_SIZE','reason':'Measured native eagle y120/x567 underrun under legal continuous SPI+physical write contention at read256. Same source waveform passes read128 with read/write controllers unchanged.'}
(o/'audit.json').write_bytes(json.dumps(record,indent=2).encode());print(json.dumps(record,indent=2))
