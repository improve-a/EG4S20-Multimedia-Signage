#!/usr/bin/env python3
"""Focused real-key/native1x/status regression; no synthesis, media or hardware."""
import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--run-id')
    ap.add_argument('--iverilog', default=r'C:\iverilog\bin\iverilog.exe')
    a = ap.parse_args()
    rid = a.run_id or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = ROOT / 'output/probe_osd_default_1x' / rid
    out.mkdir(parents=True, exist_ok=False)
    report = {'state': 'RUNNING', 'scope': __doc__, 'root': str(ROOT), 'steps': [], 'sources': {},
              'limitations': 'Accelerated key timing and cropped scan coordinates; not full scanout, synthesis or hardware.',
              'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    def save():
        (out / 'verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf8')
    def run(name, cmd, timeout=60):
        log = out / (name+'.log')
        step = {'name': name, 'command': cmd, 'cwd': str(out), 'timeout_seconds': timeout}
        report['steps'].append(step)
        save()
        start = time.monotonic()
        with log.open('wb') as f:
            try:
                p = subprocess.run(cmd, cwd=out, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
                step['exit_code'] = p.returncode
            except subprocess.TimeoutExpired:
                step['exit_code'] = 124
                f.write(b'\nTIMEOUT\n')
        step.update(wall_seconds=time.monotonic()-start, log_sha256=sha(log))
        save()
        if step['exit_code']:
            raise RuntimeError(name+' failed: '+str(log))
        return log.read_text(encoding='utf8', errors='replace')
    save()
    try:
        production = ['pixel_adjust.v', 'html_video_overlay.v', 'html_osd_overlay.v',
                      'html_osd_swap_rom.v', 'html_caption_column_rom.v', 'html_rom16.v']
        rtl = ['rtl/media_controls.v', 'rtl/ext/html_assets/html_caption_map.v'] + ['rtl/ext/'+n for n in production]
        files = rtl + [
            'rtl/ext/html_assets/html_osd_swap_palette.hex',
            'rtl/ext/html_assets/html_caption_columns.hex', 'rtl/ext/html_assets/html_glyph_coverage.hex',
            'scripts/html_osd_utility_rom.py', 'scripts/probe_osd_default_1x_verify.py',
            'tests/probe_osd_default_1x_tb.v']
        for name in files:
            src, dst = ROOT/name, out/name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            report['sources'][name] = sha(dst)
        report['source_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        iv = Path(a.iverilog)
        vvp = iv.with_name('vvp.exe' if iv.suffix.lower()=='.exe' else 'vvp')
        report['tools'] = {str(p): sha(p) for p in (iv, vvp, Path(sys.executable))}
        save()
        run('font_generate', [sys.executable, '-X', 'utf8', 'scripts/html_osd_utility_rom.py',
                              '--root', str(out), '--output-dir', str(out/'rtl/ext/html_assets')])
        font = out/'rtl/ext/html_assets/html_osd_swap_font.hex'
        report['generated_font_sha256'] = sha(font)
        assert sha(font) == sha(ROOT/'rtl/ext/html_assets/html_osd_swap_font.hex'), 'live HEX differs from tested font'
        assert sha(font.with_suffix('.hex.bin')) == sha(ROOT/'rtl/ext/html_assets/html_osd_swap_font.hex.bin'), 'synthesis BIN differs from tested font'
        run('compile', [str(iv), '-g2005-sv', '-DHTML_SIM', '-s', 'probe_osd_default_1x_tb',
                        '-o', 'test.vvp'] + rtl + ['tests/probe_osd_default_1x_tb.v'])
        text = run('simulate', [str(vvp), 'test.vvp'], timeout=90)
        if 'TEST_PASS probe_osd_default_1x ' not in text or any(s in text for s in ('ERROR:', 'FATAL:', 'WARNING:')):
            raise RuntimeError('Missing PASS or simulator diagnostics; inspect simulate.log')
        report['live_sources_unchanged'] = all(sha(ROOT/n)==h for n,h in report['sources'].items())
        assert report['live_sources_unchanged'], 'source changed during regression'
        report.update(state='PROBE_OSD_DEFAULT_1X_PASS', result=text.strip())
    except Exception as e:
        report.update(state='FAIL', error=str(e))
    save()
    print(out)
    print(report['state'])
    return 0 if report['state']=='PROBE_OSD_DEFAULT_1X_PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())
