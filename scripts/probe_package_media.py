#!/usr/bin/env python3
"""Copy preserved media into a new pack, replacing only UI06 and the WAV."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import wave

ORDER = [f'UI{i:02d}.BMP' for i in range(1, 7)] + [f'PN{i:02d}.BMP' for i in range(1, 5)] + ['07_MUSIC.WAV']

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--baseline', type=Path, required=True)
    ap.add_argument('--replacements', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    records = []
    for name in ORDER:
        changed = name in ('UI06.BMP', '07_MUSIC.WAV')
        # Keep the raw 54-byte-header 800x600 source separately; the frozen
        # loader contract requires the byte-identical payload at offset512.
        source_name = 'UI06_512.BMP' if name == 'UI06.BMP' else name
        src = (a.replacements if changed else a.baseline) / source_name
        data = src.read_bytes()
        meta = {'name': name, 'source': str(src), 'bytes': len(data), 'sha256': sha(data),
                'sectors': (len(data) + 511) // 512, 'replaced': changed}
        if name.endswith('.BMP'):
            size, off = struct.unpack_from('<I', data, 2)[0], struct.unpack_from('<I', data, 10)[0]
            dib, w, h, planes, bits, compression = struct.unpack_from('<IiiHHI', data, 14)
            stride = (w * 3 + 3) & ~3
            expected = (800, 600) if name == 'UI06.BMP' else (320, 480) if name.startswith('PN') else (640, 480)
            assert data[:2] == b'BM' and (w, h) == expected
            assert (size, off, dib, planes, bits, compression) == (len(data), 512, 40, 1, 24, 0)
            assert len(data) == off + stride * h
            meta.update(dimensions=[w, h], row_stride_bytes=stride, row_padding_bytes=stride-w*3,
                        pixel_offset=off, pixel_sha256=sha(data[off:]), format='BMP24 BI_RGB bottom-up')
        else:
            with wave.open(str(src), 'rb') as wav:
                assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (1, 2, 48000, 'NONE')
                meta.update(format='WAV PCM16 mono 48000Hz', frames=wav.getnframes(), duration_seconds=wav.getnframes()/48000)
        shutil.copyfile(src, a.out / name)
        records.append(meta)
    manifest = {'state': 'MEDIA_PACKAGE_PASS', 'loading_order': ORDER, 'assets': records,
                'framebuffer': {'word_bytes': 4, 'bases_words': [0, 307200], 'words_per_buffer': 307200,
                                'total_bytes': 2457600, 'highest_word': 614399, 'addressable_words': 2097152},
                'hardware': 'NEW_CANDIDATE_HARDWARE_NOT_TESTED',
                'adaptation': 'UI06 is a true800x600 BMP; FPGA reads central640x480 at source x80,y60; 64% source area visible, no host resampling.'}
    (a.out / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')
    print(json.dumps({'state': manifest['state'], 'bytes': sum(r['bytes'] for r in records),
                      'sectors': sum(r['sectors'] for r in records)}, indent=2))

if __name__ == '__main__':
    main()
