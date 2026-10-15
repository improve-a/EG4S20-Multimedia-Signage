#!/usr/bin/env python3
"""Push main through a Windows bare relay using existing Git authentication."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/improve-a/EG4S20-Multimedia-Signage.git'
RELAY = 'D:/FPGA/EG4S20-Multimedia-Signage-relay.git'
PYTHON = r'D:\python3.12.3\python.exe'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    if git('branch', '--show-current') != 'main':
        raise RuntimeError('Switch to main before publishing')
    if git('status', '--porcelain'):
        raise RuntimeError('Commit or preserve working changes before publishing')
    if git('remote', 'get-url', 'origin') != URL:
        raise RuntimeError('Unexpected origin')
    excluded = {r['path'] for r in json.loads((ROOT / 'docs/local_dependencies.json').read_text())['dependencies']}
    names = set(git('ls-files').splitlines())
    if names & excluded or any(Path(n).suffix.lower() in ('.bit', '.zip', '.bundle', '.vvp', '.vcd') for n in names):
        raise RuntimeError('Local dependency or generated archive present in Git index')
    # Inspect every reachable object, including history, without printing contents.
    vendor_hashes = {r['sha256'] for r in json.loads((ROOT / 'docs/local_dependencies.json').read_text())['dependencies'] if r['bytes'] > 0}
    for line in git('rev-list', '--objects', 'main').splitlines():
        oid = line.split(' ', 1)[0]
        if git('cat-file', '-t', oid) == 'blob':
            data = subprocess.check_output(['git', 'cat-file', 'blob', oid], cwd=ROOT)
            if hashlib.sha256(data).hexdigest() in vendor_hashes:
                raise RuntimeError('Excluded dependency found in reachable history')
    head = git('rev-parse', 'main')
    folder = ROOT / 'evidence/github_publish'
    folder.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    bundle = folder / (head + '.bundle')
    if not bundle.exists():
        subprocess.run(['git', 'bundle', 'create', str(bundle), 'main'], cwd=ROOT, check=True)
    incoming = RELAY.removesuffix('.git') + '-incoming.bundle'
    subprocess.run(['scp', str(bundle), 'thinkpad:' + incoming], check=True)
    code = f'''
import hashlib,json,os,pathlib,subprocess
relay=pathlib.Path({RELAY!r});incoming=pathlib.Path({incoming!r})
assert hashlib.sha256(incoming.read_bytes()).hexdigest()=={hashlib.sha256(bundle.read_bytes()).hexdigest()!r}
os.environ['GIT_TERMINAL_PROMPT']='0'
os.environ['GCM_INTERACTIVE']='Never'
def git(*a):
    p=subprocess.run(['git','--git-dir='+str(relay),*a],capture_output=True,text=True)
    if p.returncode:raise RuntimeError(p.stdout+p.stderr)
    return p.stdout.strip()
if not relay.exists():subprocess.run(['git','init','--bare','--initial-branch=main',str(relay)],check=True,capture_output=True)
assert git('rev-parse','--is-bare-repository')=='true'
remotes=git('remote').splitlines()
if 'origin' not in remotes:git('remote','add','origin',{URL!r})
assert git('remote','get-url','origin')=={URL!r}
git('fetch',str(incoming),'refs/heads/main:refs/remotes/mac/main')
assert git('rev-parse','refs/remotes/mac/main')=={head!r}
print(git('push','origin','refs/remotes/mac/main:refs/heads/main'))
remote=git('ls-remote','origin','refs/heads/main').split()[0]
assert remote=={head!r}
print(json.dumps({{'remote_main':remote,'relay_bare':True,'url':{URL!r}}}))
'''
    started = time.monotonic()
    process = subprocess.Popen(['ssh', '-o', 'BatchMode=yes', 'thinkpad', PYTHON + ' -X utf8 -'],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate(code.encode(), timeout=240)
    record = {'utc': stamp, 'local_main': head, 'bundle_sha256': hashlib.sha256(bundle.read_bytes()).hexdigest(),
              'ssh_pid': process.pid, 'exit_code': process.returncode,
              'wall_seconds': time.monotonic() - started, 'relay': RELAY,
              'stdout': stdout.decode(errors='replace'), 'stderr': stderr.decode(errors='replace')}
    (folder / (stamp + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(record['stdout'], end='')
    if record['stderr']:
        print(record['stderr'], end='')
    if process.returncode:
        return process.returncode
    remote = git('ls-remote', 'origin', 'refs/heads/main').split()[0]
    if remote != head:
        raise RuntimeError('Mac remote verification differs from local main')
    subprocess.run(['git', 'fetch', 'origin', 'main'], cwd=ROOT, check=True)
    subprocess.run(['git', 'branch', '--set-upstream-to=origin/main', 'main'], cwd=ROOT, check=True)
    print('VERIFIED main=' + head)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
