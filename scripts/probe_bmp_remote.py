#!/usr/bin/env python3
"""Windows-side runner for the 800x600 virtual-window probe.

Runs inside the isolated worker directory: builds the fixtures, the oracle
gold files and the hex images, then compiles and runs the benches with the
local iverilog/vvp. Writes result.json; it never touches the repository RTL,
never builds in TD and never opens a card.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

IVERILOG = r'C:\iverilog\bin\iverilog.exe'
VVP = r'C:\iverilog\bin\vvp.exe'
CASE_FILTER = ''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(cmd, cwd, timeout=1800):
    started = time.time()
    p = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout)
    return dict(returncode=p.returncode, seconds=round(time.time() - started, 1),
                output=(p.stdout + p.stderr)[-4000:])


def build_media(work):
    """Generate the 800x600 page here, so no binary crosses machines."""
    import probe_bmp_media as M
    media = work / 'media'
    media.mkdir(parents=True, exist_ok=True)
    payload = M.bmp_payload(M.render())
    for name, header in (('UI06.BMP', 54), ('UI06_512.BMP', 512)):
        (media / name).write_bytes(M.build(payload, header))
    return media


def build_fixtures(work, C):
    fix = work / 'fixtures'
    fix.mkdir(parents=True, exist_ok=True)
    media = work / 'media'
    info = {}
    for name in C.FIXTURES:
        data = C.fixture_bytes(name, media)
        bmp = fix / (name + '.BMP')
        bmp.write_bytes(data)
        hexf = fix / (name + '.hex')
        hexf.write_bytes(''.join(f'{b:02x}\n' for b in data).encode())
        info[name] = dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                          hex_bytes=hexf.stat().st_size)
    return fix, info


def write_hex(path, words):
    path.write_bytes(''.join(f'{w:06x}\n' for w in words).encode())


def loader_cases(fix, C, O, info):
    """Gold, sector model and hex names for every loader case."""
    out = []
    for case in C.LOADER_CASES:
        name = case['name']
        fixtures = [case['fixture']] + list(case.get('reload', []))
        rec = dict(name=name, parameters=dict(case),
                   fixture_hex=[f + '.hex' for f in fixtures],
                   fixture_len=[info[f]['bytes'] for f in fixtures],
                   right_hex=(case['right'] + '.hex') if case.get('right') else None,
                   right_len=info[case['right']]['bytes'] if case.get('right') else 0,
                   gold_files=[], expected_sectors=[], gold_sha256=[])
        if case['mode'] not in (0, 20):
            dummy = fix / 'dummy_gold.hex'
            if not dummy.exists():
                dummy.write_bytes(b'000000\n')
            rec['gold_files'] = ['dummy_gold.hex'] * len(fixtures)
            rec['expected_sectors'] = [0] * len(fixtures)
            out.append((case, rec))
            continue
        right = O.Bmp(fix / (case['right'] + '.BMP')) if case.get('right') else None
        for idx, fx in enumerate(fixtures):
            img_l = O.Bmp(fix / (fx + '.BMP'))
            if case['mode'] == 20:
                # the bench reloads on the same instance: 800 -> 640 -> 800,
                # page3 then page0, all at 1x (identity mapping)
                pg = case['page'] if idx == 0 else (3 if idx == 1 else 0)
                words = O.expected_words(img_l, img_l, pg, 0, 0, 0)
                sectors = len(O.sector_sequence(img_l, img_l, 0, 0, 0))
            else:
                img_r = right if (idx == 0 and right is not None) else img_l
                words = O.expected_words(img_l, img_r, case['page'], case['dual'],
                                         case['zoom'], case['focus'])
                sectors = len(O.sector_sequence(img_l, img_r, case['dual'],
                                                case['zoom'], case['focus']))
            gp = fix / f'{name}_gold{idx}.hex'
            write_hex(gp, words)
            rec['gold_files'].append(gp.name)
            rec['expected_sectors'].append(sectors)
            rec['gold_sha256'].append(hashlib.sha256(O.dump_text(words).encode()).hexdigest())
        out.append((case, rec))
    return out


def run_loader(work, fix, cases, run_dir):
    """Compile and run every loader case; pixel dumps are kept as evidence."""
    tb = work / 'tests/probe_bmp_loader_tb.v'
    rtl = work / 'rtl/ext/legacy_exhibit_loader.v'
    results = []
    for case, rec in cases:
        name = case['name']
        if CASE_FILTER and name != CASE_FILTER:
            continue
        vvp = run_dir / f'{name}.vvp'
        cmd = [IVERILOG, '-g2005-sv', '-s', 'probe_bmp_loader_tb', '-o', str(vvp),
               f"-Pprobe_bmp_loader_tb.PAGE={case['page']}",
               f"-Pprobe_bmp_loader_tb.DUAL={case['dual']}",
               f"-Pprobe_bmp_loader_tb.ZOOM={case['zoom']}",
               f"-Pprobe_bmp_loader_tb.FOCUS={case['focus']}",
               f"-Pprobe_bmp_loader_tb.MODE={case['mode']}",
               f"-Pprobe_bmp_loader_tb.PERIOD={case['period']}",
               f"-Pprobe_bmp_loader_tb.BAD_BYTE={case.get('bad_byte', 28)}",
               f"-Pprobe_bmp_loader_tb.BAD_MASK={case.get('bad_mask', 1)}",
               f"-Pprobe_bmp_loader_tb.RIGHT_BAD={case.get('right_bad', 0)}",
               str(tb), str(rtl)]
        step = dict(name=name, compile_cmd=' '.join(cmd))
        c = run(cmd, fix, timeout=300)
        step['compile'] = c
        if c['returncode'] != 0:
            step['pass'] = False
            results.append(step)
            continue
        dump = run_dir / f'{name}_dump.hex'
        args = [VVP, str(vvp),
                '+left=' + rec['fixture_hex'][0],
                '+gold=' + rec['gold_files'][0],
                f"+left_len={rec['fixture_len'][0]}",
                f"+expected_sectors={rec['expected_sectors'][0]}",
                '+dump=' + str(dump)]
        if rec['right_hex']:
            args += ['+right=' + rec['right_hex'], f"+right_len={rec['right_len']}"]
        if case['mode'] == 20:
            args += ['+left2=' + rec['fixture_hex'][1], '+left3=' + rec['fixture_hex'][2],
                     f"+left2_len={rec['fixture_len'][1]}", f"+left3_len={rec['fixture_len'][2]}",
                     '+gold2=' + rec['gold_files'][1], '+gold3=' + rec['gold_files'][2],
                     f"+expected_sectors2={rec['expected_sectors'][1]}",
                     f"+expected_sectors3={rec['expected_sectors'][2]}"]
        s = run(args, fix, timeout=1700)
        step['sim_cmd'] = ' '.join(args)
        step['sim'] = s
        step['pass'] = s['returncode'] == 0 and 'TEST_PASS' in s['output']
        if dump.exists():
            step['dump_sha256'] = sha(dump)
            step['dump_bytes'] = dump.stat().st_size
        results.append(step)
    return results


def run_scan(work, fix, C, run_dir):
    heads = bytearray()
    for fx in C.SCAN_FIXTURES:
        heads += (fix / (fx + '.BMP')).read_bytes()[:512]
    (fix / 'headers.hex').write_bytes(''.join(f'{b:02x}\n' for b in heads).encode())
    (fix / 'positions.hex').write_bytes(''.join(f'{p:08x}\n' for p in C.SCAN_POSITIONS).encode())
    tb = work / 'tests/probe_bmp_scan_tb.v'
    scan_rtl = work / 'rtl/ext/bmp_scale.v'
    results = []
    for case in C.SCAN_CASES:
        vvp = run_dir / (case['name'] + '.vvp')
        cmd = [IVERILOG, '-g2005-sv', '-DHTML_SIM', '-s', 'probe_bmp_scan_tb', '-o', str(vvp),
               f"-Pprobe_bmp_scan_tb.MODE={case['mode']}",
               '-Pprobe_bmp_scan_tb.BAD_INDEX=5', str(tb), str(scan_rtl)]
        step = dict(name=case['name'], compile_cmd=' '.join(cmd))
        c = run(cmd, fix, timeout=300)
        step['compile'] = c
        if c['returncode'] != 0:
            step['pass'] = False
            results.append(step)
            continue
        s = run([VVP, str(vvp)], fix, timeout=900)
        step['sim'] = s
        step['pass'] = s['returncode'] == 0 and 'TEST_PASS' in s['output']
        results.append(step)
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--work', required=True, help='tree containing rtl/, tests/, scripts/')
    ap.add_argument('--out', default='', help='output root (default <work>/output/probe_audio_multires/bmp_worker)')
    ap.add_argument('--only', default='all')
    ap.add_argument('--case', default='')
    a = ap.parse_args()
    global CASE_FILTER
    CASE_FILTER = a.case
    work = Path(a.work)
    base = Path(a.out) if a.out else work / 'output/probe_audio_multires/bmp_worker'
    base.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(work / 'scripts'))
    import probe_bmp_oracle as O
    C = O
    stamp = time.strftime('%Y%m%d_%H%M%S')
    run_dir = base / 'runs' / f'{a.only}_{stamp}'
    run_dir.mkdir(parents=True, exist_ok=True)
    build_media(base)
    fix, info = build_fixtures(base, C)
    result = dict(work=str(work), out=str(base), started=time.time(),
                  run_dir=str(run_dir), tools={}, fixtures=info, loader=[], scan=[])
    for tool in (IVERILOG, VVP):
        result['tools'][tool] = sha(tool)
    if a.only in ('all', 'loader'):
        cases = loader_cases(fix, C, O, info)
        result['expected'] = {rec['name']: {k: rec[k] for k in
                                            ('expected_sectors', 'gold_sha256',
                                             'fixture_len', 'gold_files')} for _, rec in cases}
        result['loader'] = run_loader(work, fix, cases, run_dir)
    if a.only in ('all', 'scan'):
        result['scan'] = run_scan(work, fix, C, run_dir)
    result['finished'] = time.time()
    (base / f'result_{a.only}.json').write_bytes(json.dumps(result, indent=2).encode())
    print(json.dumps({'loader': [(s['name'], s.get('pass')) for s in result['loader']],
                      'scan': [(s['name'], s.get('pass')) for s in result['scan']],
                      },
                     indent=2))


if __name__ == '__main__':
    main()
