#!/usr/bin/env python3
"""Package six HFXL scene trailers while preserving existing BMP and HFXC data."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inspect_hfxc(original, pixel_offset):
    if original[54:58] != b'HFXC':
        return None
    magic, version, width, top_height, bottom_width, bottom_height, size, offset = struct.unpack_from(
        '<4sHHHHHII', original, 54
    )
    if (magic, version, width, top_height, bottom_width, bottom_height, size, offset) != (
        b'HFXC', 1, 320, 384, 80, 24, 249856, 512
    ):
        raise ValueError('unexpected existing HFXC header')
    if offset + size != pixel_offset:
        raise ValueError('HFXC resource must fill the pre-pixel gap exactly')
    resource = original[offset:offset + size]
    if len(resource) != size:
        raise ValueError('short HFXC resource')
    return dict(
        resource_offset=offset,
        resource_bytes=size,
        resource_sha256=sha(resource),
        header=dict(version=version, width=width, native_top_height=top_height,
                    background_width=bottom_width, background_height=bottom_height),
    )


def write_layout(include, manifest):
    lines = [
        '// Generated exact HFXLv1 scene layout; source hfxl_schema.json.',
        '`ifndef HTML_LAYER_LAYOUT_VH', '`define HTML_LAYER_LAYOUT_VH',
        f"`define HTML_LAYER_SET_ID 32'h{manifest['set_id']:08x}",
        '`define HTML_LAYER_PAGE_COUNT 6', '`define HTML_LAYER_MAX_COMPONENTS 16',
        "`define HTML_LAYER_POOL_WORDS 21'd1843200",
        f"`define HTML_LAYER_TOTAL_WORDS 21'd{manifest['total_words']}",
        '`define HTML_LAYER_BG_STRIDE_WORDS 214', '`define HTML_LAYER_PALETTE_WORDS 512',
        '`define HTML_LAYER_DESCRIPTOR_OFFSET_WORDS 64', '`define HTML_LAYER_DESCRIPTOR_WORDS 8',
    ]
    for page in manifest['pages']:
        index = page['page_index']
        for label, key in [('BASE', 'global_word_base'), ('WORDS', 'payload_words'),
                           ('BG_OFFSET', 'bg_word_offset'), ('PALETTE_OFFSET', 'palette_word_offset'),
                           ('COMPONENTS', 'component_count')]:
            lines.append(f"`define HTML_LAYER_PAGE{index}_{label} 21'd{page[key]}")
    lines.extend(['`endif', ''])
    include.parent.mkdir(parents=True, exist_ok=True)
    include.write_text('\n'.join(lines), encoding='ascii')


def package(layers, base_media, out, wav=None, rtl_include=None):
    layers = Path(layers); base_media = Path(base_media); out = Path(out)
    if out.resolve() == base_media.resolve():
        raise ValueError('staging output must differ from base media directory')
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((layers / 'hfxl_payload_manifest.json').read_text(encoding='utf8'))
    schema = json.loads((layers / 'hfxl_schema.json').read_text(encoding='utf8'))
    set_id = manifest['set_id']
    schema['locator'] = {
        'byte_offset': 80, 'bytes': 32, 'struct_format': '<4sHHIIIHHII',
        'fields': {'80': 'ASCIIHFXL', '84': 'u16version1', '86': 'u16locator_bytes32',
                   '88': 'u32scene_byte_offset', '92': 'u32scene_payload_bytes',
                   '96': 'u32global_word_base', '100': 'u16page_index0..5',
                   '102': 'u16page_count6', '104': 'u32set_id', '108': 'u32reserved0'},
        'constraints': ['width640,height480,DIB40,pixeloffset>=512;ordinaryoffset<=1048576 unchanged',
                        'scene_byte_offset=align512(pixeloffset+921600)',
                        'scene_payload_bytes>0,<=2097152,multiple1024',
                        'bfSize=scene_byte_offset+scene_payload_bytes usingwidearithmetic',
                        'globalbase%256=0,base+payloadwords<=1843200',
                        'loader additionally matches pageindex,setid and exact6base/words table',
                        'ENABLE_HFXL default0 retains ordinaryBMP maxpixelend+65536 bound'],
    }
    schema['set_id'] = set_id
    schema['expected_page_regions'] = [
        {'page_index': q['page_index'], 'global_word_base': q['global_word_base'],
         'payload_words': q['payload_words']} for q in manifest['pages']
    ]
    schema_path = layers / 'hfxl_schema.json'
    schema_path.write_text(json.dumps(schema, indent=2), encoding='utf8')
    schema_sha256 = sha(schema_path.read_bytes())

    files = []
    for page in manifest['pages']:
        index = page['page_index']
        source = base_media / f'UI{index + 1:02d}.BMP'
        original = source.read_bytes()
        pixel_offset = struct.unpack_from('<I', original, 10)[0]
        bgr = original[pixel_offset:pixel_offset + 921600]
        if len(bgr) != 921600:
            raise ValueError(f'{source.name}: expected 640x480 BGR pixels')
        hfxc = inspect_hfxc(original, pixel_offset)

        # Keep the existing offset gap and its HFXC bytes for the four comparison pages.
        new_pixel_offset = pixel_offset if hfxc else 512
        header = bytearray(new_pixel_offset)
        header[:min(new_pixel_offset, len(original))] = original[:min(new_pixel_offset, len(original))]
        if hfxc:
            if header[512:new_pixel_offset] != original[512:pixel_offset]:
                raise ValueError(f'{source.name}: HFXC gap was not preserved')
        scene_offset = (new_pixel_offset + len(bgr) + 511) // 512 * 512
        payload = (layers / page['path']).read_bytes()
        if len(payload) != page['payload_bytes'] or len(payload) % 1024 or len(payload) > 2097152:
            raise ValueError(f'{source.name}: invalid HFXL payload extent')
        hfxl_header = struct.unpack_from('<16I', payload)
        if hfxl_header[13] != set_id or hfxl_header[14] != page['global_word_base']:
            raise ValueError(f'{source.name}: payload header ID or base mismatch')
        struct.pack_into('<I', header, 2, scene_offset + len(payload))
        struct.pack_into('<I', header, 10, new_pixel_offset)
        struct.pack_into('<4sHHIIIHHII', header, 80, b'HFXL', 1, 32, scene_offset, len(payload),
                         page['global_word_base'], index, 6, set_id, 0)
        output = bytes(header) + bgr + bytes(scene_offset - new_pixel_offset - len(bgr)) + payload
        if output[new_pixel_offset:new_pixel_offset + 921600] != bgr:
            raise ValueError(f'{source.name}: main BGR pixels changed')
        if hfxc and output[hfxc['resource_offset']:hfxc['resource_offset'] + hfxc['resource_bytes']] != \
                original[hfxc['resource_offset']:hfxc['resource_offset'] + hfxc['resource_bytes']]:
            raise ValueError(f'{source.name}: HFXC resource changed')
        dest = out / source.name
        dest.write_bytes(output)
        record = dict(
            name=dest.name, page_index=index, width=640, height=480,
            pixel_offset=new_pixel_offset, main_bgr_bytes=len(bgr), main_bgr_sha256=sha(bgr),
            hfxc=hfxc,
            hfxl=dict(version=1, set_id=set_id, scene_byte_offset=scene_offset,
                      scene_sector_offset=scene_offset // 512, payload_bytes=len(payload),
                      payload_words=len(payload) // 4, global_word_base=page['global_word_base'],
                      payload_sha256=sha(payload)),
            bytes=len(output), sha256=sha(output), source_sha256=sha(original),
        )
        files.append(record)

    audio_record = None
    if wav:
        wav = Path(wav)
        if wav.name.upper() != '07_MUSIC.WAV':
            raise ValueError('unified pack audio must be named 07_MUSIC.WAV')
        audio_dest = out / '07_MUSIC.WAV'
        shutil.copyfile(wav, audio_dest)
        audio_record = dict(name=audio_dest.name, bytes=audio_dest.stat().st_size,
                            sha256=sha(audio_dest.read_bytes()), source_sha256=sha(wav.read_bytes()))
    if rtl_include:
        write_layout(Path(rtl_include), manifest)
    manifest['schema_sha256'] = schema_sha256
    (layers / 'hfxl_payload_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
    report = dict(
        format='Unified HFXC v1 comparison resources + HFXL v1 scene trailers',
        set_id=set_id, schema_sha256=schema_sha256, assets=files,
        audio=audio_record, hardware='NOT_VERIFIED',
        scope='Offline unified media pack; six native BMP images, preserved HFXC/HFXL resources, WAV hash recorded; no card/device access',
    )
    (out / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layers', type=Path, required=True)
    parser.add_argument('--base-media', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--wav', type=Path)
    parser.add_argument('--rtl-include', type=Path)
    args = parser.parse_args()
    report = package(args.layers, args.base_media, args.out, args.wav, args.rtl_include)
    print(json.dumps({'containers': len(report['assets']), 'set_id': report['set_id'],
                      'audio': report['audio'], 'out': str(args.out)}))


if __name__ == '__main__':
    main()
