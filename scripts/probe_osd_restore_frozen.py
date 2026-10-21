from pathlib import Path
import hashlib,json,zipfile
root=Path('D:/FPGA/EG4S20-Probe-OSD-1x')
archive=Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/hdmi_probe/delivery/hdmi_probe_001_source.zip')
assert hashlib.sha256(archive.read_bytes()).hexdigest()=='5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f'
restored=[]
with zipfile.ZipFile(archive) as z:
    manifest=json.loads(z.read('audit/baseline_manifest.json'))
    for row in manifest['selected']:
        name=row['path'];data=z.read('work/design/'+name)
        assert hashlib.sha256(data).hexdigest()==row['sha256']
        relative=('rtl/'+name[len('user_source/hdl_source/'):] if name.startswith('user_source/hdl_source/') else 'project/'+name)
        target=root/relative
        if not target.exists() and not name.endswith('.log'):
            target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('xb') as f:f.write(data)
            restored.append(relative)
out=root/'output/probe_osd_1x';out.mkdir(parents=True,exist_ok=True)
(out/'restoration.json').write_text(json.dumps({'source_zip':str(archive),'source_commit':manifest.get('git_commit'),'restored':restored},indent=2))
print(json.dumps(restored,indent=2))
