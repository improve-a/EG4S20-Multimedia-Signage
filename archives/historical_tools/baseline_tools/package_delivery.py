"""Package the qualified m5_004 evidence; no SSH, EDA or hardware side effects."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parent.parent
sha = lambda data: hashlib.sha256(data).hexdigest()
gate = json.loads((root / 'reports/m5_004_acceptance.json').read_text())
source = json.loads((root / 'audit/m5_004_manifest.json').read_text())
assert gate['M5_GATE'] == 'PASS'
assert source['snapshot_sha256'] == gate['snapshot_sha256']
archive = root / 'artifacts/m5_004_source.zip'
bit = root / 'artifacts/hx4s20_basic_m5_004.bit'
assert sha(archive.read_bytes()) == gate['source_archive_sha256']
assert sha(bit.read_bytes()) == gate['bit_sha256']

# The project Path is the sole snapshot rewrite performed by prepare_snapshot.py.
prefixes = {'user_source/hdl_source/': 'rtl/',
            'user_source/constraints_source/': 'constraints/',
            'td_project/': 'project/'}
checked = []
with zipfile.ZipFile(archive) as frozen:
    for item in source['selected']:
        path = item['path']
        data = frozen.read('work/design/' + path)
        assert sha(data) == item['sha256'], path
        prefix = next(p for p in prefixes if path.startswith(p))
        current = root / (prefixes[prefix] + path[len(prefix):])
        live = current.read_bytes()
        if path == 'td_project/hx4s20_basic.al':
            target = 'D:/FPGA/hx4s20_contest1_20261013/builds/m5_004/work/design/td_project'
            live = re.sub(r'(<Project Version="3" Minor="2" Path=")[^"]*',
                          lambda m: m[1] + target, live.decode()).encode()
        assert sha(live) == item['sha256'], 'Working source differs: ' + path
        checked.append({'path': path, 'sha256': item['sha256']})

timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
(root / 'audit/delivery_source_check.json').write_text(json.dumps({
    'verified_utc': timestamp, 'run_id': 'm5_004',
    'snapshot_sha256': gate['snapshot_sha256'], 'bit_sha256': gate['bit_sha256'],
    'status': 'PASS', 'files': checked}, indent=2) + '\n')

files = {}
excluded_audit = {'delivery_manifest.json', 'delivery_archive.json', 'delivery_remote_verification.json'}
for dirname in ['rtl', 'constraints', 'project', 'scripts', 'tb', 'docs', 'audit', 'reports', 'reference']:
    for p in (root / dirname).rglob('*'):
        if not p.is_file() or '__pycache__' in p.parts:
            continue
        if p.suffix.lower() in {'.pyc', '.vvp', '.db', '.zip', '.bit'}:
            continue
        if dirname == 'audit' and p.name in excluded_audit:
            continue
        if 'hardware_pdf' in p.parts:
            continue
        files[p.relative_to(root).as_posix()] = p
for name in ['README.md', 'AGENTS.md', 'STATUS.md', 'acceptance_report.md', 'next_actions.md']:
    files[name] = root / name
for p in [archive, bit]:
    files[p.relative_to(root).as_posix()] = p

rows = [{'path': name, 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
        for name, p in sorted(files.items())]
manifest = dict(created_utc=timestamp, run_id='m5_004', hardware_attempt='m6_sram_006',
                hardware_scope='User-observed basic functions and approximately 5 minutes; 30 minutes unverified',
                bit_sha256=gate['bit_sha256'], snapshot_sha256=gate['snapshot_sha256'], files=rows)
mp = root / 'audit/delivery_manifest.json'
mp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
files['audit/delivery_manifest.json'] = mp
out = root / 'artifacts/hx4s20_basic_m5_004_delivery.zip'
with zipfile.ZipFile(out, 'x', zipfile.ZIP_DEFLATED) as z:
    for name, p in sorted(files.items()):
        z.write(p, 'hx4s20_basic_m5_004/' + name)
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    for entry in rows:
        data = z.read('hx4s20_basic_m5_004/' + entry['path'])
        assert len(data) == entry['bytes'] and sha(data) == entry['sha256'], entry['path']
    assert z.read('hx4s20_basic_m5_004/audit/delivery_manifest.json') == mp.read_bytes()
result = dict(path=str(out), bytes=out.stat().st_size, sha256=sha(out.read_bytes()),
              content_files=len(files), frozen_source_files=len(checked),
              archive_crc_and_all_sha256='PASS', created_utc=timestamp)
out.with_suffix('.zip.sha256').write_text(result['sha256'] + '  ' + out.name + '\n')
(root / 'audit/delivery_archive.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
