#!/usr/bin/env python3
"""Regenerate and activate the unified six-scene HFXC/HFXL/WAV media pack."""
import argparse
import hashlib
import json
import os
import shutil
import struct
import tempfile
from pathlib import Path

from html_fidelity_hfxl_containers import package


ROOT = Path(__file__).resolve().parents[1]
NAMES = [f'UI{i:02d}.BMP' for i in range(1, 7)]
AUDIO = '07_MUSIC.WAV'


def sha_file(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def json_file(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def assets_by_name(manifest):
    records = {item['name'].upper(): item for item in manifest.get('assets', []) if 'name' in item}
    audio = manifest.get('audio')
    if audio and 'name' in audio:
        records[audio['name'].upper()] = audio
    return records


def bgr_region(path):
    data = Path(path).read_bytes()
    pixel_offset = struct.unpack_from('<I', data, 10)[0]
    bgr = data[pixel_offset:pixel_offset + 921600]
    if len(bgr) != 921600:
        raise ValueError(f'{path}: invalid 640x480 BGR region')
    return bgr


def validate_generated(pack, manifest, layers, expected_bgr, expected_hfxc, wav_sha):
    hfxl_manifest = json_file(layers / 'hfxl_payload_manifest.json')
    if manifest['set_id'] != hfxl_manifest['set_id']:
        raise ValueError('generated pack set ID differs from sealed payload manifest')
    records = {x['name'].upper(): x for x in manifest['assets']}
    if set(records) != set(NAMES):
        raise ValueError('unified pack must contain exactly the six ordered BMP records')
    for page_index, name in enumerate(NAMES):
        path = pack / name
        data = path.read_bytes()
        record = records[name]
        pixel_offset = struct.unpack_from('<I', data, 10)[0]
        scene_offset, payload_bytes, base = struct.unpack_from('<III', data, 88)
        locator_magic, version, locator_bytes = struct.unpack_from('<4sHH', data, 80)
        page, page_count = struct.unpack_from('<HH', data, 100)
        set_id = struct.unpack_from('<I', data, 104)[0]
        reserved = struct.unpack_from('<I', data, 108)[0]
        page_meta = hfxl_manifest['pages'][page_index]
        if (locator_magic, version, locator_bytes, page, page_count, set_id, reserved) != (
            b'HFXL', 1, 32, page_index, 6, hfxl_manifest['set_id'], 0
        ):
            raise ValueError(f'{name}: invalid locator identity')
        if scene_offset != ((pixel_offset + 921600 + 511) // 512) * 512:
            raise ValueError(f'{name}: HFXL trailer offset is not sector aligned after native pixels')
        if (payload_bytes, base) != (page_meta['payload_bytes'], page_meta['global_word_base']):
            raise ValueError(f'{name}: HFXL payload extent/base differs from sealed manifest')
        if scene_offset + payload_bytes != len(data) or struct.unpack_from('<I', data, 2)[0] != len(data):
            raise ValueError(f'{name}: BMP scene trailer extent does not match file size')
        payload = data[scene_offset:scene_offset + payload_bytes]
        if hashlib.sha256(payload).hexdigest() != record['hfxl']['payload_sha256']:
            raise ValueError(f'{name}: HFXL trailer hash mismatch')
        if record['hfxl']['set_id'] != set_id or record['hfxl']['global_word_base'] != base:
            raise ValueError(f'{name}: manifest locator metadata mismatch')
        bgr = data[pixel_offset:pixel_offset + 921600]
        if hashlib.sha256(bgr).hexdigest() != expected_bgr[name]:
            raise ValueError(f'{name}: static native BGR pixels changed')
        if record['main_bgr_sha256'] != expected_bgr[name]:
            raise ValueError(f'{name}: manifest native BGR hash mismatch')
        hfxc = record.get('hfxc')
        if expected_hfxc.get(name):
            if not hfxc or hfxc['resource_sha256'] != expected_hfxc[name]:
                raise ValueError(f'{name}: missing or changed HFXC oracle resource')
            off, size = hfxc['resource_offset'], hfxc['resource_bytes']
            if hashlib.sha256(data[off:off + size]).hexdigest() != expected_hfxc[name]:
                raise ValueError(f'{name}: HFXC payload bytes changed')
        elif hfxc is not None:
            raise ValueError(f'{name}: unexpected HFXC payload')
    audio_record = manifest.get('audio')
    if not audio_record or audio_record['name'].upper() != AUDIO or audio_record['sha256'] != wav_sha:
        raise ValueError('WAV manifest hash or name mismatch')
    if sha_file(pack / AUDIO) != wav_sha:
        raise ValueError('WAV file hash changed')


def run(pack, layers, snapshot_image, snapshot_manifest):
    pack = Path(pack).resolve(); layers = Path(layers).resolve()
    snapshot_image = Path(snapshot_image).resolve(); snapshot_manifest = Path(snapshot_manifest).resolve()
    if not pack.is_dir() or not layers.is_dir():
        raise ValueError('formal media pack and sealed layer inputs must already exist')
    if not snapshot_image.is_file() or not snapshot_manifest.is_file():
        raise ValueError('preserved first_static image and snapshot manifest are required')

    snapshot_sha = sha_file(snapshot_image)
    snapshot_manifest_sha = sha_file(snapshot_manifest)
    static_snapshot = json_file(snapshot_manifest)
    snapshot_files = {item['name'].upper(): item['sha256'] for item in static_snapshot['files']}
    prior_manifest_path = pack / 'manifest.json'
    prior_manifest = json_file(prior_manifest_path)
    prior_manifest_sha = sha_file(prior_manifest_path)
    prior_assets = assets_by_name(prior_manifest)

    if set(prior_assets) != set(NAMES + [AUDIO]):
        raise ValueError('existing formal pack manifest must list six BMPs and 07_MUSIC.WAV')
    baseline = prior_manifest.get('baseline_static_snapshot')
    if baseline:
        if baseline['image_sha256'] != snapshot_sha or baseline['manifest_sha256'] != snapshot_manifest_sha:
            raise ValueError('first_static image/manifest changed since unified pack activation')
        expected_bgr = {n: prior_assets[n]['main_bgr_sha256'] for n in NAMES}
        expected_hfxc = {
            n: prior_assets[n]['hfxc']['resource_sha256']
            for n in NAMES if prior_assets[n].get('hfxc')
        }
        baseline_file_hashes = baseline['file_sha256']
    else:
        baseline_file_hashes = snapshot_files
        expected_bgr = {}
        expected_hfxc = {}
        for name in NAMES:
            if sha_file(pack / name) != snapshot_files[name]:
                raise ValueError(f'{name}: existing pack differs from preserved first_static snapshot')
            expected_bgr[name] = hashlib.sha256(bgr_region(pack / name)).hexdigest()
            old = prior_assets[name]
            hfxc = old.get('hfxc')
            if hfxc:
                expected_hfxc[name] = hfxc['resource_sha256']
            elif old.get('resource_sha256'):
                expected_hfxc[name] = old['resource_sha256']
    wav_sha = sha_file(pack / AUDIO)
    audio_record = prior_assets[AUDIO]
    known_wav_sha = audio_record.get('sha256') or audio_record.get('source_sha256')
    if known_wav_sha != wav_sha:
        raise ValueError('existing WAV differs from its authoritative pack manifest')

    temp_parent = pack.parent
    with tempfile.TemporaryDirectory(prefix='.unified-hfxl-', dir=temp_parent) as temp_dir:
        stage = Path(temp_dir)
        generated = package(layers, pack, stage, pack / AUDIO)
        validate_generated(stage, generated, layers, expected_bgr, expected_hfxc, wav_sha)
        generated['baseline_static_snapshot'] = dict(
            image=str(snapshot_image), image_sha256=snapshot_sha,
            manifest=str(snapshot_manifest), manifest_sha256=snapshot_manifest_sha,
            file_sha256=baseline_file_hashes,
        )
        generated['formal_pack'] = dict(
            path=str(pack), authoritative_manifest=str(pack / 'manifest.json'),
            previous_manifest_sha256=prior_manifest_sha,
            generator='scripts/html_fidelity_unified_pack.py',
            command='python scripts/html_fidelity_unified_pack.py',
        )
        generated['hardware'] = 'NOT_VERIFIED'
        generated['scope'] = 'Offline unified six-HFXL-BMP plus existing WAV deployment pack; no hardware/card/device access'
        manifest_stage = stage / 'manifest.json'
        manifest_stage.write_text(json.dumps(generated, indent=2) + '\n', encoding='utf8')

        # All staged assets have passed before activation. Replace only six BMPs and the manifest.
        for name in NAMES:
            os.replace(stage / name, pack / name)
        os.replace(manifest_stage, prior_manifest_path)

    active_manifest = json_file(prior_manifest_path)
    validate_generated(pack, active_manifest, layers, expected_bgr, expected_hfxc, wav_sha)
    if sha_file(snapshot_image) != snapshot_sha or sha_file(snapshot_manifest) != snapshot_manifest_sha:
        raise ValueError('first_static image or snapshot manifest changed during pack activation')
    return active_manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack', type=Path, default=ROOT / 'output/html_fidelity/media')
    parser.add_argument('--layers', type=Path, default=ROOT / 'output/html_fidelity/layers')
    parser.add_argument('--snapshot-image', type=Path, default=ROOT / 'output/html_fidelity/card_images/first_static.img')
    parser.add_argument('--snapshot-manifest', type=Path, default=ROOT / 'output/html_fidelity/card_images/first_static.json')
    args = parser.parse_args()
    result = run(args.pack, args.layers, args.snapshot_image, args.snapshot_manifest)
    print(json.dumps({'status': 'PASS', 'formal_pack': result['formal_pack']['path'],
                      'set_id': result['set_id'], 'bmp_count': len(result['assets']),
                      'wav': result['audio'], 'manifest': result['formal_pack']['authoritative_manifest']}))


if __name__ == '__main__':
    main()
