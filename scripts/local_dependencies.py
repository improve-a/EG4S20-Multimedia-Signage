#!/usr/bin/env python3
"""Restore exact locally licensed dependencies; never download or overwrite files."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Preserved hx4s20_extensions source root')
    parser.add_argument('--check', action='store_true', help='Check local dependencies without copying')
    args = parser.parse_args()
    rows = json.loads((ROOT / 'docs/local_dependencies.json').read_text())['dependencies']
    pending = []
    issues = []
    for row in rows:
        relative = Path(row['path'])
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Invalid manifest path')
        target = ROOT / relative
        if target.exists():
            if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != row['sha256']:
                issues.append(row['path'] + ': existing file differs; preserved without overwrite')
        elif args.check or args.source is None:
            issues.append(row['path'] + ': missing')
        else:
            source = args.source / relative
            if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != row['sha256']:
                issues.append(row['path'] + ': source missing or differs')
            else:
                pending.append((source, target))
    if issues:
        print('\n'.join(issues))
        return 1
    for source, target in pending:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    print(json.dumps({'status': 'PASS', 'checked': len(rows), 'restored': len(pending),
                      'scope': 'local file identity only; no build or hardware test'}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
