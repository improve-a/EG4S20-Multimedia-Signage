#!/usr/bin/env python3
"""Reproducible stdlib media packaging. Writes ordinary files under this deliverable only."""
from __future__ import annotations
import argparse, array, hashlib, importlib.util, json, math, shutil, struct, sys, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
RATE = 48000
SECONDS = 80
FEATURE_SOURCE_SHA='fcf310b665d06def0c9921c4bc87cf21ffec20f4f3e40e2be1df01061d2906db'
FEATURE_HASHES=(
 '37244b5de8bf9d28f3f9f09da9886b5853cf6345ec1d7e27c472fead2a77d455',
 'cb5729efd717c85dc1542dcb656b8696f093bc5a01b6c3d697a2515705c2e57f',
 '781f5ed2ff5f37e53aa7d1dca0f45a7b68f93357e092bb561fbe7a4b80dd12b0',
 '6b59578c5c16232852b90e8207f0fc7efd097464a77cb85a9661023d5711a97b',
 '03b7562335f869c7e63feeced27613e440d657f4c681e298977168d3730b27e2')

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read_ppm(path):
    data = path.read_bytes()
    pos = 0
    tokens = []
    while len(tokens) < 4:
        while pos < len(data) and data[pos] in b' \t\r\n': pos += 1
        if data[pos] == 35:
            pos = data.index(b'\n', pos) + 1
            continue
        end = pos
        while end < len(data) and data[end] not in b' \t\r\n': end += 1
        tokens.append(data[pos:end]); pos = end
    if data[pos:pos+2] == b'\r\n': pos += 2
    else: pos += 1
    assert tokens[0] == b'P6' and tokens[3] == b'255', 'requires P6 RGB8'
    width, height = map(int, tokens[1:3])
    rgb = data[pos:]
    assert 0 < width <= 640 and 0 < height <= 480 and len(rgb) == width*height*3
    return width, height, rgb

def encode_bmp(width, height, rgb):
    stride = (width*3 + 3) & ~3
    pixels = bytearray(stride*height)
    for y in range(height):
        start = (height-1-y)*stride
        row = rgb[y*width*3:(y+1)*width*3]
        pixels[start:start+width*3:3] = row[2::3]
        pixels[start+1:start+width*3:3] = row[1::3]
        pixels[start+2:start+width*3:3] = row[0::3]
    header = struct.pack('<2sIHHI', b'BM', 54+len(pixels), 0, 0, 54)
    dib = struct.pack('<IiiHHIIiiII', 40, width, height, 1, 24, 0, len(pixels), 2835, 2835, 0, 0)
    return header+dib+pixels

def generate_audio(path, cue=False):
    # Original score: slow Cmaj9 / Am7 / Fmaj7 / Gadd9 pads and a sparse bell motif.
    # No external recordings, samples, randomness or time-dependent metadata.
    chords = ((130.8128,164.8138,195.9977,246.9417),
              (110.0,130.8128,164.8138,195.9977),
              (87.3071,130.8128,164.8138,174.6141),
              (97.9989,146.8324,195.9977,220.0))
    melody = (523.2511,659.2551,783.9909,659.2551,587.3295,523.2511,493.8833,587.3295)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        for second in range(SECONDS):
            out = array.array('h')
            for frame in range(RATE):
                t = second + frame/RATE
                section = int(t//8)
                local = t%8
                pad_envelope = min(1., local/1.4, (8-local)/1.8)
                pad = sum(math.sin(math.tau*f*t + 0.018*math.sin(math.tau*0.11*t)) for f in chords[section%4])/4
                note_local = t%4
                # Local phase plus smooth 20 ms attack/release avoids discontinuities
                # at note changes; the natural exponential decay supplies the body.
                bell_attack = math.sin(math.pi/2*min(1.,note_local/0.020))**2
                bell_release = math.sin(math.pi/2*min(1.,(4-note_local)/0.020))**2
                bell = (math.sin(math.tau*melody[int(t//4)%8]*note_local) + 0.16*math.sin(math.tau*2*melody[int(t//4)%8]*note_local))*math.exp(-note_local*2.2)*bell_attack*bell_release
                if cue:
                    # Quiet, soft two-note DEMO chimes every 16 s, never an evacuation alarm.
                    cue_local = t%16
                    value = 0.045*pad*pad_envelope
                    if cue_local < 3:
                        value += 0.13*math.sin(math.tau*(659.2551 if cue_local<1.5 else 783.9909)*t)*math.sin(math.pi*(cue_local%1.5)/1.5)**2
                else:
                    value = 0.16*pad*pad_envelope + 0.05*bell
                # Smooth fade in/out, with exact silent final second for clean EOF.
                fade = max(0., min(1., t/2, (SECONDS-1-t)/3))
                out.append(round(32767*value*fade))
            if sys.byteorder != 'little': out.byteswap()
            w.writeframesraw(out.tobytes())

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--audio-only', action='store_true', help='prepare original audio while UI sources are pending')
    p.add_argument('--audio-update', action='store_true', help='regenerate and refresh only audio and its manifest; leave frozen page files untouched')
    args = p.parse_args()
    audio = ROOT/'assets/audio'; audio.mkdir(parents=True, exist_ok=True)
    for name, cue in [('ambient_80s_mono_48k.wav',False), ('demo_cues_80s_mono_48k.wav',True)]:
        dest = audio/name
        generate_audio(dest,cue)
        print(f'Generated {dest.name}: {dest.stat().st_size} bytes SHA256 {sha(dest.read_bytes())}')
    (audio/'SOURCE_AND_LICENSE.md').write_text('''# Original audio\n\nBoth WAV files are generated solely by `scripts/package_media.py` using standard-library oscillators. Original procedural score: Cmaj9 / Am7 / Fmaj7 / Gadd9 pads with sparse bell notes. No recordings, external samples, copyrighted melodies or third-party audio are used. These original sound assets are dedicated to the public domain under CC0 1.0.\n\n80 seconds, PCM signed 16-bit, 48 kHz, mono. Gentle two-second entrance, three-second fade, exact final second silence. The DEMO cue track is a quiet presentation chime, not a real evacuation alarm. Audio playback is independent of image switching and starts once per boot; no image-triggered cue, synchronization or EOF loop is claimed.\n''',encoding='utf-8')
    if args.audio_only: return
    package = ROOT/'tf_card_package'
    if args.audio_update:
        manifest_path=package/'manifest.json'
        manifest=json.loads(manifest_path.read_text())
        for set_name,file_name,source_name in (
            ('A_daily','03_MUSIC.WAV','ambient_80s_mono_48k.wav'),
            ('B_emergency','05_CUES.WAV','demo_cues_80s_mono_48k.wav')):
            source=audio/source_name;dest=package/set_name/file_name
            records=[r for r in manifest['sets'][set_name]['files'] if r['name']==file_name]
            assert len(records)==1,'audio update requires exact existing manifest entry'
            shutil.copyfile(source,dest)
            records[0].update(bytes=dest.stat().st_size,sha256=sha(dest.read_bytes()))
        manifest['script_sha256']=sha(Path(__file__).read_bytes())
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('Updated audio only; no PPM/BMP file written.')
        return
    master = package/'master_media'; master.mkdir(parents=True,exist_ok=True)
    canonical = []
    for index in range(1,7):
        source = ROOT/f'assets/design/UI{index:02}.ppm'
        width,height,rgb = read_ppm(source)
        assert (width,height)==(640,480),'canonical UI must be native 640x480'
        dest = master/f'UI{index:02}.BMP'
        dest.write_bytes(encode_bmp(width,height,rgb))
        canonical.append(dict(page=f'UI-{index:02}', path=str(dest.relative_to(ROOT)), source=str(source.relative_to(ROOT)),
            width=width,height=height,sha256=sha(dest.read_bytes()),source_sha256=sha(source.read_bytes()),rgb_sha256=sha(rgb)))
    specs = {
        'A_daily':[(master/'UI01.BMP','01_WELCM.BMP'),(master/'UI02.BMP','02_DAILY.BMP'),(audio/'ambient_80s_mono_48k.wav','03_MUSIC.WAV')],
        'B_emergency':[(master/f'UI{i:02}.BMP',f'{i-2:02}_UI{i:02}.BMP') for i in range(3,7)]+[(audio/'demo_cues_80s_mono_48k.wav','05_CUES.WAV')]
    }
    # Bundle the byte-identical original generator; never require untracked repo artifacts.
    fixture_source=ROOT/'scripts/feature_fixture_source.py'
    assert sha(fixture_source.read_bytes())==FEATURE_SOURCE_SHA,'preserved fixture source changed'
    module_spec=importlib.util.spec_from_file_location('feature_fixture_source',fixture_source)
    fixture=importlib.util.module_from_spec(module_spec);module_spec.loader.exec_module(fixture)
    feature_folder=package/'C_features';feature_folder.mkdir(parents=True,exist_ok=True)
    allowed={f'{i+1:02}_BARS.BMP' for i in range(4)}|{'05_TEST.WAV'}
    assert not [p.name for p in feature_folder.iterdir() if p.suffix.lower() in ('.bmp','.wav') and p.name not in allowed], 'preserve unknown feature media'
    feature_entries=[]
    for variant,(width,height) in enumerate(((320,240),(320,180),(640,360),(640,480))):
        path=feature_folder/f'{variant+1:02}_BARS.BMP';path.write_bytes(fixture.make_bmp(width,height,variant))
        assert sha(path.read_bytes())==FEATURE_HASHES[variant],'feature bitmap differs from preserved original'
        feature_entries.append((path,path.name))
    path=feature_folder/'05_TEST.WAV';fixture.make_wav(path,30)
    assert sha(path.read_bytes())==FEATURE_HASHES[4],'feature WAV differs from preserved original'
    feature_entries.append((path,path.name));specs['C_features']=feature_entries
    sets = {}
    for name, entries in specs.items():
        folder=package/name; folder.mkdir(parents=True,exist_ok=True)
        allowed={dest for _,dest in entries}
        unexpected=[p.name for p in folder.iterdir() if p.suffix.lower() in ('.bmp','.wav') and p.name not in allowed]
        assert not unexpected, f'Preserve unexpected media; cannot package directory: {unexpected}'
        records=[]
        for source,name_dest in entries:
            dest=folder/name_dest
            if source!=dest: shutil.copyfile(source,dest)
            records.append(dict(name=name_dest,bytes=dest.stat().st_size,sha256=sha(dest.read_bytes()),source=str(source.relative_to(REPO))))
        sets[name]=dict(files=records,bmp_count=sum(x['name'].endswith('.BMP') for x in records),
            advisory_order='Listed filenames describe intended order only; FPGA scans increasing physical LBA, ignores FAT and names.')
    manifest=dict(status='GENERATED_NOT_HARDWARE_VERIFIED',format='BMP24 BI_RGB 40-byte DIB positive bottom-up; WAV PCM16 48000 mono/stereo',
        scanner=dict(first_lba=0,last_header_lba=131071,max_bmp_per_boot=4,fat_traversal=False,requires_contiguous_sectors=True,order='physical LBA',first_wav_only=True,wav_eof_loop=False),
        canonical=canonical,sets=sets,script_sha256=sha(Path(__file__).read_bytes()),
        preserved_feature_source=dict(path='scripts/feature_fixture_source.py',original_repository_source='scripts/make_demo_media.py',sha256=FEATURE_SOURCE_SHA,original_asset_hashes=list(FEATURE_HASHES)),
        deployment='Ordinary directory artifacts only. Never copy master_media or all sets together. Backup plus explicit later physical-card write authorization and read-only layout audit are required.',
        hardware_status='NOT_VERIFIED',audio_synchronization='NONE; no page-triggered sound')
    (package/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (package/'README.txt').write_text('Choose ONE set: A_daily (2 UI), B_emergency (4 UI), or C_features (independent technical patterns). master_media is an archival collection, NEVER copy-all. These ordinary directories do not prove physical TF allocation or order. Before any card write: verified backup and explicit authorization. No formatting/raw writing is provided. After an authorized ordinary file copy, audit contiguous FAT32 chains, discovery headers within LBA 0..131071, scan order, unexpected residual BMP/WAV and physical byte hashes with inspect_card.py. Physical layout, cold-boot playback and HDMI remain NOT_VERIFIED.\n',encoding='utf-8')
    print(f'Packaged six canonical pages and {len(sets)} independent boot sets.')

if __name__=='__main__': main()
