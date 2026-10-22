#!/usr/bin/env python3
"""Run the probe audio regressions on Windows Icarus and check the OSD pixels.

Steps (each logged and hashed into verification.json inside the run directory):
  1. snapshot the owned RTL/tests plus the generated OSD ROM assets
  2. loop testbench  : real 07_MUSIC.WAV bytes, LOOP_PLAY=1 (retained FIFO)
  3. legacy testbench: same WAV, LOOP_PLAY=0 with the top's eof restart,
     for the stall comparison
  4. OSD testbench   : real audio_peak history -> bar pixels, validated against
     an independent pixel model computed here, plus a PPM/ASCII preview

Only the Python standard library is used. Run it on the machine that has
Icarus Verilog; the Mac side has none.
"""
import argparse
import datetime
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LOOP_RTL = ['rtl/ext/audio_media.v', 'rtl/ext/wav_stream_parser.v',
            'rtl/ext/audio_pcm_player.v', 'rtl/ext/audio_async_fifo.v']
OSD_RTL = ['rtl/ext/pixel_adjust.v', 'rtl/ext/html_video_overlay.v',
           'rtl/ext/html_osd_overlay.v', 'rtl/ext/html_osd_swap_rom.v',
           'rtl/ext/html_caption_column_rom.v', 'rtl/ext/html_rom16.v',
           'rtl/ext/html_assets/html_caption_map.v']
OSD_ASSETS = ['rtl/ext/html_assets/html_osd_swap_font.hex',
              'rtl/ext/html_assets/html_caption_columns.hex',
              'rtl/ext/html_assets/html_glyph_coverage.hex']
TESTS = ['tests/probe_audio_loop_tb.v', 'tests/probe_audio_osd_tb.v']

BAR_X0, BAR_X1 = 445, 508          # left inclusive, right exclusive
BAR_PITCH, BAR_WIDTH = 7, 5
BAR_CENTRE, BAR_MAX = 410, 44
BAR_Y0, BAR_Y1 = 388, 432
ROI = (440, 512, 384, 434)         # dumped region x0,x1,y0,y1
BAR_INK = 0x1a1916


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_wav_mono(path):
    data = path.read_bytes()
    if data[:4] != b'RIFF' or data[8:12] != b'WAVE':
        raise SystemExit('%s is not RIFF/WAVE' % path)
    pos, payload = 12, None
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack('<I', data[pos + 4:pos + 8])[0]
        if cid == b'data':
            payload = data[pos + 8:pos + 8 + size]
            break
        pos += 8 + size + (size & 1)
    if payload is None:
        raise SystemExit('%s has no data chunk' % path)
    return payload


def window_peaks(payload):
    pcm = struct.unpack('<%dh' % (len(payload) // 2), payload)
    return [max(abs(pcm[i + k]) for k in range(64))
            for i in range(0, len(pcm) - 63, 64)]


def sheet_frames(peaks, file_peak):
    """Per-frame audio_peak: real music windows, then silence, mute and the
    audio_peak[15:10] range boundaries. The last nine frames are silent so the
    nine-deep history (and therefore the chart) is fully empty at the end."""
    beats = [file_peak, peaks[375], peaks[750], peaks[1125], peaks[1500],
             peaks[1875], peaks[2250], 0, file_peak, 1023, 1024, 32768] + [0] * 9
    mutes = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0] + [0] * 9
    return beats, mutes


def bar_height(history):
    h = (history * 3) >> 1
    return BAR_MAX if h > BAR_MAX else h


def bar_pixel(history, x, y):
    if not (BAR_X0 <= x < BAR_X1 and BAR_Y0 <= y < BAR_Y1):
        return False
    index, col = divmod(x - BAR_X0, BAR_PITCH)
    if index > 8:
        return False
    h = bar_height(history[index])
    if col >= BAR_WIDTH or h == 0:
        return False
    top = BAR_CENTRE - (h >> 1)
    bottom = BAR_CENTRE + ((h + 1) >> 1)
    return top <= y < bottom and (col == 2 or (y > top and y + 1 < bottom))


def model_frame(peaks, mutes, k, height=58, width=72):
    history = [0] * 9
    for i in range(9):
        if k - i >= 0:
            p = peaks[k - i]
            history[i] = 0 if mutes[k - i] else (32 if p >= 32768 else p >> 10)
    rows = []
    for y in range(ROI[2], ROI[3]):
        rows.append(''.join('#' if bar_pixel(history, x, y) else '.'
                            for x in range(ROI[0], ROI[1])))
    return history, rows


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=ROOT,
                    help='source tree providing unmodified files (the synced 61efa10 root)')
    ap.add_argument('--extra', type=Path, action='append', default=[],
                    help='directory searched first for owned files (worker overlay)')
    ap.add_argument('--wav', type=Path, help='07_MUSIC.WAV to play (default: <out>/media/07_MUSIC.WAV)')
    ap.add_argument('--out', type=Path, default=ROOT / 'output/probe_audio_multires/audio_worker')
    ap.add_argument('--run-id')
    ap.add_argument('--iverilog', default=r'C:\iverilog\bin\iverilog.exe')
    ap.add_argument('--skip-loop', action='store_true')
    ap.add_argument('--skip-osd', action='store_true')
    a = ap.parse_args()

    rid = a.run_id or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    run = a.out / 'runs' / rid
    run.mkdir(parents=True, exist_ok=False)
    wav = a.wav or (a.out / 'media/07_MUSIC.WAV')
    if not wav.exists():
        raise SystemExit('missing WAV: %s' % wav)
    run.mkdir(parents=True, exist_ok=True)
    local_wav = run / '07_MUSIC.WAV'
    shutil.copy2(wav, local_wav)

    report = {'state': 'RUNNING', 'run_id': rid, 'root': str(a.root),
              'extra': [str(p) for p in a.extra], 'wav': str(wav), 'wav_sha256': sha(wav),
              'steps': [], 'sources': {},
              'limitations': ('Accelerated 48kHz cadence (4 audio clocks/frame, 130x); '
                              'behavioural sector transport slower relative to playback than the card; '
                              'cropped OSD scan rows; no synthesis, bitstream, card or HDMI hardware.')}
    save = lambda: (run / 'verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    save()

    def resolve(name):
        for base in list(a.extra) + [a.root]:
            p = base / name
            if p.exists():
                return p
        raise SystemExit('missing source: %s' % name)

    def run_cmd(name, cmd, timeout):
        log = run / (name + '.log')
        step = {'name': name, 'cmd': cmd, 'timeout_seconds': timeout}
        report['steps'].append(step)
        save()
        t0 = time.monotonic()
        with log.open('wb') as f:
            try:
                p = subprocess.run(cmd, cwd=run, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
                step['exit_code'] = p.returncode
            except subprocess.TimeoutExpired:
                step['exit_code'] = 124
                f.write(b'\nTIMEOUT\n')
        step['wall_seconds'] = round(time.monotonic() - t0, 3)
        step['log'] = str(log)
        step['log_sha256'] = sha(log)
        save()
        if step['exit_code']:
            raise RuntimeError('%s failed, see %s' % (name, log))
        return log.read_text(encoding='utf8', errors='replace')

    iv = Path(a.iverilog)
    vvp = iv.with_name('vvp.exe' if iv.suffix.lower() == '.exe' else 'vvp')
    report['tools'] = {str(p): sha(p) for p in (iv, vvp, Path(sys.executable))}
    try:
        needed = sorted(set(LOOP_RTL + OSD_RTL + OSD_ASSETS + TESTS))
        for name in needed:
            src = resolve(name)
            dst = run / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            report['sources'][name] = {'sha256': sha(dst), 'from': str(src)}
        save()
        peaks = window_peaks(read_wav_mono(wav))
        report['wav'] = {'path': str(wav), 'sha256': sha(wav),
                         'window_peaks': len(peaks), 'peak': max(peaks)}

        if not a.skip_loop:
            # 2 = no LOOP_PLAY override (production default), 1 = explicit, 0 = legacy.
            for mode, tag in ((2, 'loop_default'), (1, 'loop_explicit'), (0, 'legacy')):
                run_cmd('compile_' + tag, [str(iv), '-g2005-sv', '-s', 'probe_audio_loop_tb',
                                           '-Pprobe_audio_loop_tb.LOOP_MODE=%d' % mode,
                                           '-o', 'loop_%s.vvp' % tag] +
                        LOOP_RTL + ['tests/probe_audio_loop_tb.v'], 120)
                text = run_cmd('sim_' + tag, [str(vvp), 'loop_%s.vvp' % tag,
                                              '+wav=07_MUSIC.WAV'], 1800)
                line = [l for l in text.splitlines() if l.startswith('TEST_PASS')]
                if not line:
                    raise RuntimeError('%s run has no TEST_PASS' % tag)
                report[tag + '_result'] = line[-1]
                report[tag + '_fields'] = dict(p.split('=', 1) for p in line[-1].split() if '=' in p)
            for tag in ('loop_default', 'loop_explicit'):
                if int(report[tag + '_fields']['gaps']) != 0:
                    raise RuntimeError('%s reported starved frames' % tag)
            stall = float(report['legacy_fields']['stall_frames'])
            report['stall'] = {
                'measured_at_lba': 64,
                'frames': stall,
                'milliseconds': round(stall / 48.0, 3),
                'loop_default_gaps': int(report['loop_default_fields']['gaps']),
                'loop_explicit_gaps': int(report['loop_explicit_fields']['gaps']),
                'scaled_to_real_lba_16491_ms': round(stall / 48.0 * 16491 / 64.0, 1),
                'note': 'legacy stall scales with the LBA the scan must cross',
            }

        if not a.skip_osd:
            peaks_used, mutes = sheet_frames(peaks, report['wav']['peak'])
            (run / 'osd_peaks.hex').write_text(
                '\n'.join('%04x' % p for p in peaks_used) + '\n', encoding='ascii')
            (run / 'osd_mute.hex').write_text(
                '\n'.join('%x' % m for m in mutes) + '\n', encoding='ascii')
            run_cmd('compile_osd', [str(iv), '-g2005-sv', '-DHTML_SIM', '-s', 'probe_audio_osd_tb',
                                    '-o', 'osd.vvp'] + OSD_RTL + ['tests/probe_audio_osd_tb.v'], 120)
            run_cmd('sim_osd', [str(vvp), 'osd.vvp', '+dump=osd_dump.txt'], 900)
            dump = {}
            for line in (run / 'osd_dump.txt').read_text().splitlines():
                if not line.strip():
                    continue
                f, x, y, rgb = line.split()
                dump[(int(f), int(x), int(y))] = int(rgb, 16)
            frames = len(peaks_used)
            checks = []
            art = []
            for k in range(frames):
                history, rows = model_frame(peaks_used, mutes, k, width=ROI[1] - ROI[0])
                bad_inside = bad_outside = bars = 0
                for x in range(ROI[0], ROI[1]):
                    for y in range(ROI[2], ROI[3]):
                        got = dump.get((k, x, y))
                        if got is None:
                            raise RuntimeError('missing pixel frame %d x%d y%d' % (k, x, y))
                        want = bar_pixel(history, x, y)
                        is_ink = got == BAR_INK
                        if want and not is_ink:
                            bad_inside += 1
                        if is_ink and not want:
                            bad_outside += 1
                        bars += int(is_ink)
                checks.append({'frame': k, 'audio_peak': peaks_used[k], 'muted': mutes[k],
                               'history': history,
                               'heights': [bar_height(v) for v in history],
                               'bar_pixels': bars,
                               'missing_bar_pixels': bad_inside,
                               'unexpected_ink_pixels': bad_outside})
                if k == 0:
                    art = rows
            report['osd_frames'] = checks
            bad = [c for c in checks if c['missing_bar_pixels'] or c['unexpected_ink_pixels']]
            if bad:
                raise RuntimeError('OSD bar pixel model mismatch on %d frames' % len(bad))
            silent = [c for c in checks if not any(c['history'])]
            if not silent:
                raise RuntimeError('no fully silent frame reached')
            if any(c['bar_pixels'] for c in silent):
                raise RuntimeError('silent frame still drew bars')
            if max(max(c['heights']) for c in checks) != BAR_MAX:
                raise RuntimeError('full-scale peak did not reach the %dpx clamp' % BAR_MAX)
            # PPM preview: every frame's ROI side by side.
            w, h = ROI[1] - ROI[0], ROI[3] - ROI[2]
            ppm = run / 'osd_preview.ppm'
            with ppm.open('wb') as f:
                f.write(b'P6\n%d %d\n255\n' % (w * frames, h))
                for y in range(ROI[2], ROI[3]):
                    row = bytearray()
                    for k in range(frames):
                        for x in range(ROI[0], ROI[1]):
                            rgb = dump[(k, x, y)]
                            row += bytes(((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255))
                    f.write(bytes(row))
            (run / 'osd_frame0_ascii.txt').write_text(
                'frame 0  audio_peak=%d  heights=%s\n' %
                (peaks_used[0], checks[0]['heights']) + '\n'.join(art) + '\n', encoding='utf8')
            report['osd_preview'] = str(ppm)
            report['osd_ascii'] = str(run / 'osd_frame0_ascii.txt')

        report['live_sources_unchanged'] = all(
            sha(resolve(n)) == report['sources'][n]['sha256'] for n in report['sources'])
        if not report['live_sources_unchanged']:
            raise RuntimeError('a source changed during the run')
        report['state'] = 'PROBE_AUDIO_PASS'
    except Exception as e:                      # noqa: BLE001 - report any failure
        report['state'] = 'FAIL'
        report['error'] = str(e)
    save()
    print(run)
    print(report['state'])
    return 0 if report['state'] == 'PROBE_AUDIO_PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
