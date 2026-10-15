#!/usr/bin/env python3
"""Reproducible offline package/validation; never enumerates or accesses disks."""
import argparse, hashlib, json, shutil, struct, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/venue_unified_offline/media'
SOURCE = ROOT / 'output/venue_emergency_ui/tf_card_package'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def inspect(p):
    b=p.read_bytes()
    if p.suffix=='.BMP':
        assert b[:2]==b'BM'
        size,offset=struct.unpack_from('<I',b,2)[0],struct.unpack_from('<I',b,10)[0]
        dib,w,h,planes,bpp,compression=struct.unpack_from('<IiiHHI',b,14)
        assert (size,offset,dib,w,h,planes,bpp,compression)==(len(b),54,40,640,480,1,24,0)
        assert len(b)==921654
        return dict(format='BMP BI_RGB24 bottom-up',width=w,height=h,pixels=307200)
    with wave.open(str(p),'rb') as f:
        assert (f.getnchannels(),f.getsampwidth(),f.getframerate(),f.getnframes())==(1,2,48000,3840000)
        assert f.getcomptype()=='NONE'
        f.setpos(f.getnframes()-48000);assert not any(f.readframes(48000))
    return dict(format='PCM16 mono',rate=48000,seconds=80)
def validate():
    m=json.loads((OUT/'manifest.json').read_text())
    assert m['physical_layout']=='NOT_TESTED'
    names=[f'UI{i:02}.BMP' for i in range(1,7)]+['07_MUSIC.WAV']
    assert [a['name'] for a in m['assets']]==names
    assert m['intended_image_order']==names[:6]
    assert sorted(q.name for q in OUT.iterdir() if q.suffix.upper() in ('.BMP','.WAV'))==sorted(names)
    assert (OUT/'SHA256SUMS').read_text()==''.join(f"{a['sha256']}  {a['name']}\n" for a in m['assets'])
    for a in m['assets']:
        p=OUT/a['name'];assert digest(p)==a['sha256'];assert p.stat().st_size==a['bytes'];assert inspect(p)==a['format']
        source=ROOT/a['source'];assert digest(source)==a['sha256']
    assert [a['physical_index_intended'] for a in m['assets'][:6]]==list(range(6))
    assert len({a['sha256'] for a in m['assets'][:6]})==6
    print('OFFLINE_MEDIA_PASS six distinct canonical BMPs + original daily WAV; physical_layout=NOT_TESTED')
def main():
    p=argparse.ArgumentParser();p.add_argument('--validate-only',action='store_true');args=p.parse_args()
    if args.validate_only:validate();return
    OUT.mkdir(parents=True,exist_ok=True);assets=[]
    for i in range(6):
        name=f'UI{i+1:02}.BMP';src=SOURCE/'master_media'/name;dest=OUT/name;shutil.copyfile(src,dest)
        assets.append(dict(name=name,source=str(src.relative_to(ROOT)),bytes=dest.stat().st_size,sha256=digest(dest),format=inspect(dest),physical_index_intended=i,content_mode='daily' if i<2 else 'emergency'))
    src=SOURCE/'A_daily/03_MUSIC.WAV';dest=OUT/'07_MUSIC.WAV';shutil.copyfile(src,dest)
    assets.append(dict(name=dest.name,source=str(src.relative_to(ROOT)),bytes=dest.stat().st_size,sha256=digest(dest),format=inspect(dest),audio_policy='global continuous; independent of content mode; no mode/audio synchronization'))
    (OUT/'manifest.json').write_text(json.dumps(dict(schema=1,physical_layout='NOT_TESTED',intended_image_order=['UI01.BMP','UI02.BMP','UI03.BMP','UI04.BMP','UI05.BMP','UI06.BMP'],assets=assets),indent=2)+'\n')
    (OUT/'SHA256SUMS').write_text(''.join(f"{a['sha256']}  {a['name']}\n" for a in assets))
    (OUT/'README.md').write_text('''# Unified offline media\n\nSix original canonical 640×480 uncompressed BMPs are preserved byte for byte. Intended physical discovery indices: daily 0=UI01, 1=UI02; emergency 2=UI03, 3=UI04, 4=UI05, 5=UI06. Filenames and copy order alone do not prove physical LBA order. Physical layout: **NOT_TESTED**.\n\n07_MUSIC.WAV is the original daily 80-second PCM16 mono 48 kHz track. Playback is global/continuous and independent of image mode; emergency visuals do not select, restart or synchronize audio. The 80-second file ends in silence; there is no automatic loop or mode-triggered restart.\n\nReproduce from repository root: `python3 scripts/package_unified_offline.py`. Validate: `python3 scripts/package_unified_offline.py --validate-only`. Manifest records source provenance, hashes, formats and intended ordering. This script reads and writes repository files only; no card discovery, mounting, writing, JTAG or hardware actions. Offline format/hash validation does not establish physical acceptance.\n''')
    validate()
if __name__=='__main__':main()
