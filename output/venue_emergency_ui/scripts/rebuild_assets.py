#!/usr/bin/env python3
"""Recreate the complete deliverable with existing macOS Swift and Python stdlib.

No physical devices, network requests, font installation or TD invocation.
Run from any working directory; existing generated outputs are refreshed.
"""
from pathlib import Path
import datetime
import hashlib
import json
import os
import platform
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def hashes():
    paths = [p for folder in ('previews', 'tf_card_package', 'assets/design', 'assets/audio')
             for p in (ROOT / folder).rglob('*') if p.is_file()
             and p.suffix.lower() in ('.png', '.ppm', '.bmp', '.wav', '.svg')]
    paths += list((ROOT / 'assets').glob('UI*.svg'))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def main():
    before = hashes()
    commands = [
        [sys.executable, str(ROOT / 'scripts/generate_ui.py')],
        ['/usr/bin/swift', str(ROOT / 'scripts/render_ui.swift')],
        [sys.executable, str(ROOT / 'scripts/package_media.py')],
        [sys.executable, str(ROOT / 'scripts/validate_media.py')],
    ]
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    start = time.monotonic()
    runs = []
    log = []
    for cmd in commands:
        t = time.monotonic()
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, cwd=ROOT)
        output, _ = process.communicate()
        log.append('$ ' + ' '.join(cmd) + '\n' + output)
        runs.append({'command': cmd, 'pid': process.pid, 'exit_code': process.returncode,
                     'wall_seconds': round(time.monotonic() - t, 3)})
        print(output, end='', flush=True)
        if process.returncode:
            break
    after = hashes()
    changes = sorted(k for k in before.keys() | after.keys()
                     if before.get(k) != after.get(k))
    result = {'started_utc': started, 'python': sys.version, 'platform': platform.platform(),
              'supervisor_pid': os.getpid(), 'wall_seconds': round(time.monotonic()-start, 3),
              'commands': runs, 'status': 'PASS' if len(runs)==4 and all(
                  r['exit_code']==0 for r in runs) else 'FAIL',
              'generated_media_files': len(after), 'before_sha256': before, 'after_sha256': after,
              'reproduced_identically': bool(before) and not changes, 'changed_files': changes,
              'scope': 'local asset regeneration; no RTL/TD or physical device operation'}
    out = ROOT / 'evidence'
    out.mkdir(exist_ok=True)
    (out / 'reproduction.json').write_text(json.dumps(result, indent=2)+'\n')
    (out / 'reproduction.log').write_text('\n'.join(log))
    print(json.dumps({k:result[k] for k in ('status','generated_media_files',
                     'reproduced_identically','changed_files','wall_seconds')}, indent=2))
    return 0 if result['status']=='PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
