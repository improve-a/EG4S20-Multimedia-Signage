#!/usr/bin/env python3
"""Restore only missing local dependencies from the hardware-passed Probe archive."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SHA = '5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f'

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('archive', type=Path)
    args = ap.parse_args()
    assert hashlib.sha256(args.archive.read_bytes()).hexdigest() == SHA
    restored = []
    with zipfile.ZipFile(args.archive) as archive:
        manifest = json.loads(archive.read('audit/baseline_manifest.json'))
        for item in manifest['selected']:
            name = item['path']
            if name.endswith('.log'):
                continue
            relative = ('rtl/' + name[len('user_source/hdl_source/'):] if name.startswith('user_source/hdl_source/') else 'project/' + name)
            target = ROOT / relative
            if target.exists():
                continue
            data = archive.read('work/design/' + name)
            assert hashlib.sha256(data).hexdigest() == item['sha256'], name
            if target.suffix in ('.v', '.sv') and b'/work/design/user_source/hdl_source/ext/html_assets/' in data:
                # Undo the frozen build's absolute ROM path, so prepare_snapshot
                # relocates it to this candidate rather than the historical build.
                import re
                data = re.sub(rb'[^"\s]*?/work/design/user_source/hdl_source/ext/html_assets/', b'rtl/ext/html_assets/', data)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            restored.append(relative)
    print(json.dumps({'archive_sha256': SHA, 'source_commit': manifest.get('git_commit'), 'restored': restored}, indent=2))

if __name__ == '__main__':
    main()
