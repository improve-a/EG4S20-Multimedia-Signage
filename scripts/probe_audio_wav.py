#!/usr/bin/env python3
"""Compose and analyse the probe audio loop (48 kHz PCM16 mono RIFF/WAVE).

The composition is synthesised from scratch with the Python standard library
only. Every note is mixed into a circular buffer, so the file is an exact
periodic signal: the last sample is followed by the first sample without any
discontinuity, which is what the FPGA loop path needs.

Outputs (all under the git-ignored output/probe_audio_multires/):
  07_MUSIC.WAV         16.000 s, 48 kHz, PCM16, mono
  wav_report.json      format, level, loop-seam and per-second measurements
  wav_peaks.hex        one 64-sample window peak (as audio_pcm_player emits)
                       per waveform window, for the OSD bar testbench

No third-party packages, no FFT and no audio effects that would hide clipping.
"""
import argparse
import array
import hashlib
import json
import math
import random
import struct
import sys
from pathlib import Path

SR = 48000
BPM = 120.0
BEAT = 60.0 / BPM            # 0.5 s
BAR = 4 * BEAT               # 2 s
BARS = 8                     # 8 bars x 4 beats = 32 beats = 16 s
LOOP_BEATS = BARS * 4
LOOP_SECONDS = BARS * BAR    # 16.0 s
N = int(round(SR * LOOP_SECONDS))

# -2 dBFS leaves ~2 dB of headroom for the later HDMI/volume stages.
PEAK_TARGET_DBFS = -2.0
PEAK_TARGET = 10.0 ** (PEAK_TARGET_DBFS / 20.0)
FULL_SCALE = 32767.0


def midi(name):
    """Note name -> frequency.  A2=45, C4=60, A4=69."""
    names = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6,
             'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
    pitch = names[name[:-1]]
    octave = int(name[-1])
    number = (octave + 1) * 12 + pitch
    return 440.0 * 2.0 ** ((number - 69) / 12.0)


def add_wrapped(buf, start, block):
    """Add a note into the circular loop buffer, wrapping at the end."""
    n = len(buf)
    pos = start % n
    first = min(len(block), n - pos)
    for i in range(first):
        buf[pos + i] += block[i]
    for i in range(first, len(block)):
        buf[i - first] += block[i]


def voice(freq, dur, decay, attack, harmonics, detune, amp):
    """Detuned additive voice with attack, exponential decay and click-free end."""
    total = int(dur * SR)
    out = [0.0] * total
    w = 2.0 * math.pi * freq
    wd = w * (1.0 + detune)
    norm = 2.0 * sum(harmonics)
    fade = 0.005
    for i in range(total):
        t = i / SR
        env = math.exp(-t / decay)
        if t < attack:
            env *= t / attack
        left = dur - t
        if left < fade:
            env *= left / fade
        s = 0.0
        for k, h in enumerate(harmonics):
            s += h * (math.sin((k + 1) * w * t) + math.sin((k + 1) * wd * t))
        out[i] = amp * env * s / norm
    return out


def noise_hit(dur, decay, lowpass, highpass, amp, rng):
    """Filtered noise burst (hat / clap) with click-free end."""
    total = int(dur * SR)
    out = [0.0] * total
    lp = 0.0
    prev = 0.0
    fade = 0.003
    for i in range(total):
        t = i / SR
        x = rng.uniform(-1.0, 1.0)
        lp += lowpass * (x - lp)
        y = lp - prev
        prev = lp
        y *= highpass
        env = math.exp(-t / decay)
        if t < 0.001:
            env *= t / 0.001
        left = dur - t
        if left < fade:
            env *= left / fade
        out[i] = amp * env * y
    return out


def kick(dur, amp):
    """Pitch-swept sine thump."""
    total = int(dur * SR)
    out = [0.0] * total
    phase = 0.0
    for i in range(total):
        t = i / SR
        f = 45.0 + 95.0 * math.exp(-t / 0.030)
        phase += 2.0 * math.pi * f / SR
        env = math.exp(-t / 0.055)
        if t < 0.002:
            env *= t / 0.002
        left = dur - t
        if left < 0.004:
            env *= left / 0.004
        out[i] = amp * env * math.sin(phase)
    return out


CHORDS = [
    ('A2', ('A3', 'C4', 'E4'), ('A2', 'E3', 'A4')),      # Am
    ('F2', ('F3', 'A3', 'C4'), ('F2', 'C3', 'F4')),      # F
    ('C3', ('C4', 'E4', 'G4'), ('C3', 'G3', 'C5')),      # C
    ('G2', ('G3', 'B3', 'D4'), ('G2', 'D3', 'G4')),      # G
]

# 16th-note arpeggio pattern: chord tone index and octave offset, None = rest.
ARP = [(0, 1), (1, 1), (2, 1), (1, 1),
       (0, 2), (1, 1), (2, 1), (1, 1),
       (0, 1), (1, 1), (2, 1), (0, 2),
       (1, 1), (2, 1), (1, 1), None]

LEAD = {
    # bars 5-8 (the second half) carry a short lead motif on 8th notes.
    4: [(0, 0.0), (2, 0.5), (3, 1.0), (2, 1.5), (0, 2.0), (2, 3.0)],
    5: [(3, 0.0), (4, 0.5), (5, 1.0), (4, 1.5), (3, 2.0), (1, 3.0)],
    6: [(2, 0.0), (3, 0.5), (4, 1.0), (3, 1.5), (2, 2.5), (0, 3.0)],
    7: [(5, 0.0), (4, 0.5), (3, 1.0), (2, 1.5), (1, 2.0), (0, 2.5)],
}


def compose():
    buf = [0.0] * N
    rng = random.Random(0x5150A0D1)

    for bar in range(BARS):
        root, triad, pad = CHORDS[bar % len(CHORDS)]
        bar_start = bar * 4 * BEAT

        # --- pad: slow chord bed, longer than a bar so its tail wraps over
        # the loop point instead of leaving digital silence before beat 1 ----
        for name in pad:
            add_wrapped(buf, int(bar_start * SR),
                        voice(midi(name), BAR * 1.35, 1.1, 0.30,
                              (1.0, 0.30, 0.12), 0.0018, 0.16))

        # --- bass: driving 8th-note riff, root/octave alternation ----------
        bass_notes = [root, root, root, pad[0], root, root, root, pad[0]]
        for slot in range(8):
            start = int((bar_start + slot * 0.5 * BEAT) * SR)
            dur = 0.20 if slot % 2 else 0.26
            amp = 0.34 if slot % 2 == 0 else 0.22
            add_wrapped(buf, start,
                        voice(midi(bass_notes[slot]), dur, 0.11, 0.004,
                              (1.0, 0.45, 0.22), 0.0025, amp))

        # --- arpeggio: 16th-note tech motif -------------------------------
        for slot, step in enumerate(ARP):
            if step is None:
                continue
            degree, octave = step
            freq = midi(triad[degree]) * (2.0 if octave == 2 else 1.0)
            start = int((bar_start + slot * 0.25 * BEAT) * SR)
            accent = 0.20 if slot % 4 == 0 else 0.13
            add_wrapped(buf, start,
                        voice(freq, 0.155, 0.045, 0.003,
                              (1.0, 0.28, 0.10), 0.004, accent))

        # --- drums --------------------------------------------------------
        for beat in (0, 2):
            add_wrapped(buf, int((bar_start + beat * BEAT) * SR),
                        kick(0.22, 0.42))
        if bar % 2 == 1:            # extra offbeat kick every other bar
            add_wrapped(buf, int((bar_start + 3.5 * BEAT) * SR), kick(0.18, 0.24))
        for slot in range(8):
            start = int((bar_start + slot * 0.5 * BEAT) * SR)
            amp = 0.17 if slot % 2 else 0.09
            add_wrapped(buf, start, noise_hit(0.055, 0.012, 0.62, 1.55, amp, rng))
        if bar % 4 == 3:
            add_wrapped(buf, int((bar_start + 2 * BEAT) * SR),
                        noise_hit(0.13, 0.045, 0.35, 1.9, 0.16, rng))

        # --- lead motif in the second half --------------------------------
        for note, beat in LEAD.get(bar, []):
            freq = midi(triad[0]) * 2.0 ** (note / 12.0) * 2.0
            start = int((bar_start + beat * BEAT) * SR)
            add_wrapped(buf, start,
                        voice(freq, 0.30, 0.10, 0.006,
                              (1.0, 0.20, 0.07), 0.003, 0.15))

    # ---- remove DC (one-pole high pass at ~25 Hz, applied circularly) ----
    alpha = 1.0 / (1.0 + 2.0 * math.pi * 25.0 / SR)
    prev_in = 0.0
    prev_out = 0.0
    for _ in range(2):                     # two passes settle the loop state
        for i in range(N):
            x = buf[i]
            y = alpha * (prev_out + x - prev_in)
            prev_in = x
            prev_out = y
            buf[i] = y

    peak = max(abs(v) for v in buf)
    gain = PEAK_TARGET / peak if peak else 0.0
    return [v * gain for v in buf]


def quantise(buf):
    pcm = array.array('h')
    for v in buf:
        s = int(round(v * FULL_SCALE))
        s = -32768 if s < -32768 else 32767 if s > 32767 else s
        pcm.append(s)
    return pcm


def wav_bytes(pcm):
    payload = pcm.tobytes()
    header = b'RIFF' + struct.pack('<I', 36 + len(payload)) + b'WAVE'
    header += b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, SR, SR * 2, 2, 16)
    header += b'data' + struct.pack('<I', len(payload))
    return header + payload


def band_energy(pcm):
    """Rough 3-band energy split (one-pole filters), reported in dBFS."""
    a_low = 1.0 - math.exp(-2.0 * math.pi * 200.0 / SR)
    a_high = 1.0 - math.exp(-2.0 * math.pi * 2000.0 / SR)
    low = 0.0
    low2 = 0.0
    e_low = e_mid = e_high = 0.0
    for s in pcm:
        x = s / 32768.0
        low += a_low * (x - low)
        low2 += a_high * (x - low2)
        mid = low2 - low
        high = x - low2
        e_low += low * low
        e_mid += mid * mid
        e_high += high * high
    n = max(len(pcm), 1)
    return {
        'low_0_200hz_dbfs': round(10 * math.log10(max(e_low / n, 1e-12)), 2),
        'mid_200_2000hz_dbfs': round(10 * math.log10(max(e_mid / n, 1e-12)), 2),
        'high_2k_plus_dbfs': round(10 * math.log10(max(e_high / n, 1e-12)), 2),
    }


def analyse(pcm):
    n = len(pcm)
    peak = 0
    energy = 0.0
    dc = 0.0
    clipped = 0
    max_delta = 0
    seam_delta = 0
    deltas = []
    for i in range(n):
        s = pcm[i]
        a = -s if s < 0 else s
        if a > peak:
            peak = a
        if a >= 32767:
            clipped += 1
        energy += float(s) * float(s)
        dc += s
        nxt = pcm[(i + 1) % n]
        d = nxt - s
        d = -d if d < 0 else d
        if i == n - 1:
            seam_delta = d
        else:
            if d > max_delta:
                max_delta = d
            deltas.append(d)
    rms = math.sqrt(energy / n)
    deltas.sort()
    p999 = deltas[int(0.999 * (len(deltas) - 1))]
    # Second difference across the seam vs the interior distribution detects a
    # click that a single-sample delta could still hide.
    second = []
    for i in range(n - 1):
        second.append(abs(pcm[i + 1] - 2 * pcm[i] + pcm[i - 1]))
    second.sort()
    seam_second = abs(pcm[0] - 2 * pcm[n - 1] + pcm[n - 2])
    span = int(0.05 * SR)
    local = [pcm[(n - span + i) % n] for i in range(2 * span)]
    local_rms = math.sqrt(sum(float(v) ** 2 for v in local) / len(local))
    windows = []
    step = 64
    for start in range(0, n - step + 1, step):
        windows.append(max(abs(pcm[start + k]) for k in range(step)))
    per_second = []
    for sec in range(int(math.ceil(n / SR))):
        lo = sec * SR
        hi = min(n, lo + SR)
        e = sum(float(pcm[i]) ** 2 for i in range(lo, hi)) / (hi - lo)
        per_second.append({
            'second': sec,
            'rms_dbfs': round(20 * math.log10(max(math.sqrt(e), 1e-9) / 32768.0), 2),
            'peak': max(abs(pcm[i]) for i in range(lo, hi)),
        })
    return {
        'samples': n,
        'seconds': round(n / SR, 6),
        'peak_dbfs': round(20 * math.log10(peak / 32768.0), 3),
        'peak_sample': peak,
        'rms_dbfs': round(20 * math.log10(max(rms, 1e-9) / 32768.0), 3),
        'crest_db': round(20 * math.log10(max(peak, 1) / max(rms, 1e-9)), 3),
        'dc_offset': round(dc / n, 3),
        'clipped_samples': clipped,
        'max_sample_delta': max_delta,
        'loop_seam_delta': seam_delta,
        'interior_delta_p999': p999,
        'loop_seam_within_p999': seam_delta <= p999,
        'loop_seam_within_interior_max': seam_delta <= max_delta,
        'seam': {
            'samples_around_seam': [pcm[n - 2], pcm[n - 1], pcm[0], pcm[1]],
            'delta_samples': seam_delta,
            'delta_dbfs': round(20 * math.log10(max(seam_delta, 1) / 32768.0), 1),
            'interior_delta_p999': p999,
            'interior_delta_max': max_delta,
            'delta_ratio_vs_p999': round(seam_delta / max(p999, 1), 4),
            'second_difference': seam_second,
            'interior_second_p999': second[int(0.999 * (len(second) - 1))],
            'second_within_interior_p999': seam_second <= second[int(0.999 * (len(second) - 1))],
            'local_rms_100ms_dbfs': round(20 * math.log10(max(local_rms, 1e-9) / 32768.0), 2),
            'global_rms_dbfs': round(20 * math.log10(max(rms, 1e-9) / 32768.0), 2),
        },
        'window_peaks': len(windows),
        'bands': band_energy(pcm),
        'second_windows': per_second,
    }, windows


def wav_peaks_hex(windows, path):
    """One hex word per 64-sample window peak, mirroring wave_peak order."""
    lines = ['%04x' % (w & 0xffff) for w in windows]
    path.write_text('\n'.join(lines) + '\n', encoding='ascii')


def read_wav(path):
    data = path.read_bytes()
    if data[0:4] != b'RIFF' or data[8:12] != b'WAVE':
        raise SystemExit('%s is not RIFF/WAVE' % path)
    pos = 12
    fmt = None
    payload = None
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack('<I', data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b'fmt ':
            fmt = struct.unpack('<HHIIHH', body[:16])
        elif cid == b'data':
            payload = body
            break
        pos += 8 + size + (size & 1)
    if fmt is None or payload is None:
        raise SystemExit('%s has no fmt/data chunk' % path)
    encoding, channels, rate, byte_rate, align, bits = fmt
    return {
        'format': {'encoding': encoding, 'channels': channels, 'rate': rate,
                   'byte_rate': byte_rate, 'block_align': align, 'bits': bits},
        'data_bytes': len(payload),
        'pcm': array.array('h', payload),
        'sha256': hashlib.sha256(data).hexdigest(),
        'file_bytes': len(data),
        'header_bytes': len(data) - len(payload),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir', type=Path,
                    default=Path(__file__).resolve().parents[1] / 'output/probe_audio_multires')
    ap.add_argument('--analyse', type=Path, help='analyse an existing WAV and print JSON')
    a = ap.parse_args()

    if a.analyse:
        info = read_wav(a.analyse)
        stats, windows = analyse(info['pcm'])
        print(json.dumps({'path': str(a.analyse), 'format': info['format'],
                          'file_bytes': info['file_bytes'], 'data_bytes': info['data_bytes'],
                          'sha256': info['sha256'], 'stats': stats}, indent=2))
        return 0

    out_dir = a.out_dir
    media = out_dir / 'media'
    media.mkdir(parents=True, exist_ok=True)
    buf = compose()
    pcm = quantise(buf)
    blob = wav_bytes(pcm)
    wav = media / '07_MUSIC.WAV'
    wav.write_bytes(blob)

    stats, windows = analyse(pcm)
    report = {
        'generator': 'scripts/probe_audio_wav.py',
        'composition': {
            'bpm': BPM, 'bars': BARS, 'beats': LOOP_BEATS,
            'key': 'A minor (Am-F-C-G)', 'synthesis': 'circular (periodic) mix',
            'target_peak_dbfs': PEAK_TARGET_DBFS,
        },
        'file': {
            'path': 'output/probe_audio_multires/media/07_MUSIC.WAV',
            'bytes': len(blob), 'header_bytes': len(blob) - len(pcm) * 2,
            'sectors_512': (len(blob) + 511) // 512,
            'sha256': hashlib.sha256(blob).hexdigest(),
        },
        'format': {'encoding': 1, 'channels': 1, 'rate': SR, 'bits': 16,
                   'block_align': 2, 'byte_rate': SR * 2},
        'stats': stats,
        'checks': {
            'peak_within_2dbfs_headroom': stats['peak_dbfs'] <= -1.95,
            'no_clipping': stats['clipped_samples'] == 0,
            'loop_seam_continuous': stats['seam']['second_within_interior_p999']
                                    and stats['loop_seam_within_interior_max'],
            'dc_negligible': abs(stats['dc_offset']) < 2.0,
            'duration_10_to_20s': 10.0 <= stats['seconds'] <= 20.0,
        },
    }
    (out_dir / 'wav_report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    wav_peaks_hex(windows, out_dir / 'wav_peaks.hex')
    print(json.dumps(report, indent=2))
    if not all(report['checks'].values()):
        print('CHECK FAILED', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
