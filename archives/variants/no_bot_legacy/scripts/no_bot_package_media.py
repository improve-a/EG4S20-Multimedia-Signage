#!/usr/bin/env python3
"""Package six static BMP24 pages and four independent dual panels for the legacy stream.
No render, card access, HFXC/HFXL payload, compressed layers or source-media edits.
Uses only Python standard library and preserves every BMP pixel/WAV byte.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import wave

ROOT = Path(__file__).resolve().parents[1]
PAGES = ['home', 'eagle', 'phoenix', 'elf', 'dragon', 'eco']
PANELS = ['eagle', 'phoenix', 'elf', 'dragon']

def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()

def read_bmp(path):
    data = path.read_bytes()
    if len(data) < 54:
        raise ValueError(f'{path}: missing BMP header')
    signature, declared_size, reserved0, reserved1, offset = struct.unpack_from('<2sIHHI', data)
    dib, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', data, 14)
    if (signature, declared_size, reserved0, reserved1, dib, height, planes, bits, compression) != (b'BM', len(data), 0, 0, 40, 480, 1, 24, 0):
        raise ValueError(f'{path}: expected uncompressed positive-height BMP24 with40byteDIB')
    if width not in (320, 640) or offset < 54:
        raise ValueError(f'{path}: unexpected width/offset')
    stride = (width * 3 + 3) & ~3
    if len(data) != offset + stride * height:
        raise ValueError(f'{path}: unexpected trailer or truncated image')
    return data, dict(width=width, height=height, source_pixel_offset=offset,
                      stride_bytes=stride, pixel_bytes=stride * height,
                      image_bytes=struct.unpack_from('<I', data, 34)[0])

def package_bmp(source, destination, kind, order, expected_width):
    original, meta = read_bmp(source)
    if meta['width'] != expected_width:
        raise ValueError(f'{source}: unexpected source dimensions')
    header = bytearray(original[:54])
    pixel_data = original[meta['source_pixel_offset']:]
    struct.pack_into('<I', header, 2, 512 + len(pixel_data))
    struct.pack_into('<I', header, 10, 512)
    payload = bytes(header) + bytes(512 - 54) + pixel_data
    destination.write_bytes(payload)
    generated, verify = read_bmp(destination)
    if generated[512:] != pixel_data or any(generated[54:512]):
        raise ValueError(f'{destination}: pixel-equivalence/header-gap failed')
    # Height, width, planes, encoding and all unaffected header bytes remain exact.
    for offset in list(range(2)) + list(range(6, 10)) + list(range(14, 54)):
        if generated[offset] != original[offset]:
            raise ValueError(f'{destination}: unrelated BMP header byte changed')
    if verify['stride_bytes'] != meta['stride_bytes']:
        raise ValueError(f'{destination}: row orientation/stride changed')
    return dict(name=destination.name, path=str(destination), kind=kind, loading_order=order,
                source=str(source), source_sha256=sha_bytes(original), sha256=sha_bytes(generated),
                bytes=len(generated), sectors=(len(generated)+511)//512,
                dimensions=[meta['width'], meta['height']], format='BMP24 BI_RGB, BGR bytes, positive-height bottom-up',
                dib_bytes=40, planes=1, bits_per_pixel=24, compression=0,
                pixel_offset=512, header_gap_bytes=458, header_gap_all_zero=True,
                row_stride_bytes=meta['stride_bytes'], row_padding_bytes=0,
                pixel_bytes=len(pixel_data), pixel_sha256=sha_bytes(pixel_data),
                source_pixel_offset=meta['source_pixel_offset'], decoded_pixels_checked=meta['width']*meta['height'],
                decoded_pixel_equivalence='PASS: complete BGR payload, dimensions, row stride and orientation unchanged')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', type=Path, default=ROOT/'output/html_fidelity/assets')
    parser.add_argument('--wav', type=Path, default=ROOT/'output/html_fidelity/media/07_MUSIC.WAV')
    parser.add_argument('--out', type=Path, default=ROOT/'output/html_fidelity/no_bot/media')
    args = parser.parse_args()
    if args.out.resolve() in (args.assets.resolve(), args.wav.parent.resolve()):
        parser.error('output must be separate from preserved source assets/media')
    started = time.monotonic()
    args.out.mkdir(parents=True, exist_ok=True)
    assets = []
    for index, name in enumerate(PAGES):
        assets.append(package_bmp(args.assets/f'A_{index+1:02d}_{name}.bmp', args.out/f'UI{index+1:02d}.BMP',
                                  'full_scene', index, 640))
        assets[-1].update(page_index=index, page_name=name)
    for index, name in enumerate(PANELS):
        assets.append(package_bmp(args.assets/f'panel_{name}.bmp', args.out/f'PN{index+1:02d}.BMP',
                                  'independent_product_panel', index+6, 320))
        assets[-1].update(panel_index=index, product=name)
    wav_data = args.wav.read_bytes()
    with wave.open(str(args.wav), 'rb') as stream:
        audio_format = dict(channels=stream.getnchannels(), sample_bytes=stream.getsampwidth(),
                            sample_rate_hz=stream.getframerate(), frames=stream.getnframes(),
                            compression=stream.getcomptype())
    if audio_format['channels'] not in (1,2) or (audio_format['sample_bytes'],audio_format['sample_rate_hz'],audio_format['compression']) != (2,48000,'NONE'):
        raise ValueError('expected existing mono/stereoPCM16 48kHz WAV')
    target = args.out/'07_MUSIC.WAV'
    target.write_bytes(wav_data)
    if target.read_bytes() != wav_data:
        raise ValueError('WAV preservation failed')
    assets.append(dict(name=target.name,path=str(target),kind='audio',loading_order=10,
                       source=str(args.wav),source_sha256=sha_bytes(wav_data),sha256=sha_bytes(wav_data),
                       bytes=len(wav_data),sectors=(len(wav_data)+511)//512,
                       format='WAV RIFF PCM16 '+str(audio_format['channels'])+'channel48000Hz',audio_format=audio_format,
                       byte_equivalence='PASS: entire source WAV unchanged'))
    manifest = dict(state='MEDIA_PACKAGE_PASS',created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    generator=dict(path=str(Path(__file__).resolve()),sha256=sha_bytes(Path(__file__).read_bytes()),
                                   python=sys.version,pid=os.getpid(),exit_code=0,wall_seconds=round(time.monotonic()-started,3)),
                    command=r'D:\python3.12.3\python.exe -X utf8 scripts\no_bot_package_media.py',
                    format='10 ordinary BMP24 files with512byte pixel offsets, plus unchanged existing WAV; no HFXC/HFXL',
                    loading_order=[a['name'] for a in assets],assets=assets,
                    framebuffer_layout=dict(address_unit='32bit word, RRGGBB00',frame_width=640,frame_height=480,
                                            words_per_frame=307200,buffer_bases=[0,307200],buffer_bytes=1228800,
                                            total_buffer_bytes=2457600,policy='Load requested source page or runtime-composed independent panel pair into inactive buffer; commit at frame boundary. Six pages remain accessible from TF; not all resident.'),
                    pair_map=dict(eagle=['PN01.BMP','PN02.BMP'],phoenix=['PN02.BMP','PN01.BMP'],
                                  elf=['PN03.BMP','PN04.BMP'],dragon=['PN04.BMP','PN03.BMP'],
                                  home=['PN01.BMP','PN02.BMP'],eco=['PN01.BMP','PN02.BMP']),
                    dual_contract='PN01..PN04 each stores one independent320x480 source. Runtime loader selects left/right files and emits640x480 sequential framebuffer pixels; no joined dual screenshot supplied.',
                    zoom_contract='Runtime source-coordinate sampling remains a hardware loader function; package preserves original scene/panel source pixels.',
                    osd='Excluded from every static BMP; dynamic caption, page index/progress and audio visualizer remain RTL layers.',
                    checks=dict(bmp_count=10,pixel_decode_equivalence='PASS',pixels_checked=sum(a.get('decoded_pixels_checked',0) for a in assets),
                                all_bmp_offsets_512=True,all_bmp_gap_bytes_zero=True,wav_unchanged=True,
                                no_hfxc_hfxl_metadata=True,no_hardware_or_card_access=True),
                    deployment='Ordinary files only. Loading order is logical catalog order, not an existing-cardLBA. No FAT image/card sectors generated; deployed file extents/startsectors must be discovered from the actual newly prepared card.',
                    hardware='HARDWARE_NOT_TESTED')
    (args.out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(state=manifest['state'],out=str(args.out),loading_order=manifest['loading_order'],
                         pixels_checked=manifest['checks']['pixels_checked'],wall_seconds=manifest['generator']['wall_seconds']),ensure_ascii=False))

if __name__ == '__main__':
    main()
