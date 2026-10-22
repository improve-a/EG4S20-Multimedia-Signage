#!/usr/bin/env python3
"""Generate the original 800x600 probe page used by the virtual-window test.

This artwork is drawn by this script from primitives (gradient, grid, cards,
radar, colour ramps, rulers, calibration tiles). It is NOT derived from, nor an
upscale of, the delivered 640x480 exhibit pages: every one of the 800x600
pixels exists in the file and the outer margin carries content that the
640x480 virtual window never shows.

Outputs (never overwrites the baseline pages):
  output/probe_audio_multires/media/UI06.BMP      original, 54-byte header
  output/probe_audio_multires/media/UI06_512.BMP  deploy copy, 512-byte header
  output/probe_audio_multires/media/probe_bmp_manifest.json

Only the Python standard library is used; no image library, no resampling.
"""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/probe_audio_multires/media'
W, H = 800, 600
STRIDE = W * 3                      # 2400, exactly 4-byte aligned, no padding
VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 80, 60, 640, 480

BG0 = (10, 16, 32)
BG1 = (26, 38, 64)
GRID = (32, 46, 78)
HATCH = (20, 28, 46)
ACCENT = (0, 196, 180)
MAGENTA = (232, 60, 180)
TEXT = (228, 238, 250)
DIM = (124, 144, 176)
CARD = (17, 26, 45)
EDGE = (60, 90, 134)
WARM = (255, 150, 64)
OK = (96, 220, 120)
RED = (238, 86, 86)
YELLOW = (250, 224, 96)

# 5x7 font, one string per row. Enough for the labels used below.
FONT = {
 'A': ('01110','10001','10001','11111','10001','10001','10001'),
 'B': ('11110','10001','10001','11110','10001','10001','11110'),
 'C': ('01110','10001','10000','10000','10000','10001','01110'),
 'D': ('11110','10001','10001','10001','10001','10001','11110'),
 'E': ('11111','10000','10000','11110','10000','10000','11111'),
 'F': ('11111','10000','10000','11110','10000','10000','10000'),
 'G': ('01110','10001','10000','10111','10001','10001','01111'),
 'H': ('10001','10001','10001','11111','10001','10001','10001'),
 'I': ('11111','00100','00100','00100','00100','00100','11111'),
 'J': ('00111','00010','00010','00010','00010','10010','01100'),
 'K': ('10001','10010','10100','11000','10100','10010','10001'),
 'L': ('10000','10000','10000','10000','10000','10000','11111'),
 'M': ('10001','11011','10101','10101','10001','10001','10001'),
 'N': ('10001','11001','10101','10011','10001','10001','10001'),
 'O': ('01110','10001','10001','10001','10001','10001','01110'),
 'P': ('11110','10001','10001','11110','10000','10000','10000'),
 'Q': ('01110','10001','10001','10001','10101','10010','01101'),
 'R': ('11110','10001','10001','11110','10100','10010','10001'),
 'S': ('01111','10000','10000','01110','00001','00001','11110'),
 'T': ('11111','00100','00100','00100','00100','00100','00100'),
 'U': ('10001','10001','10001','10001','10001','10001','01110'),
 'V': ('10001','10001','10001','10001','10001','01010','00100'),
 'W': ('10001','10001','10001','10101','10101','11011','10001'),
 'X': ('10001','10001','01010','00100','01010','10001','10001'),
 'Y': ('10001','10001','01010','00100','00100','00100','00100'),
 'Z': ('11111','00001','00010','00100','01000','10000','11111'),
 '0': ('01110','10001','10011','10101','11001','10001','01110'),
 '1': ('00100','01100','00100','00100','00100','00100','01110'),
 '2': ('01110','10001','00001','00110','01000','10000','11111'),
 '3': ('11110','00001','00001','01110','00001','00001','11110'),
 '4': ('00010','00110','01010','10010','11111','00010','00010'),
 '5': ('11111','10000','11110','00001','00001','10001','01110'),
 '6': ('00110','01000','10000','11110','10001','10001','01110'),
 '7': ('11111','00001','00010','00100','01000','01000','01000'),
 '8': ('01110','10001','10001','01110','10001','10001','01110'),
 '9': ('01110','10001','10001','01111','00001','00010','01100'),
 ' ': ('00000','00000','00000','00000','00000','00000','00000'),
 '.': ('00000','00000','00000','00000','00000','01100','01100'),
 ',': ('00000','00000','00000','00000','01100','01100','01000'),
 '-': ('00000','00000','00000','11111','00000','00000','00000'),
 ':': ('00000','01100','01100','00000','01100','01100','00000'),
 '/': ('00001','00010','00010','00100','01000','01000','10000'),
 '(': ('00010','00100','01000','01000','01000','00100','00010'),
 ')': ('01000','00100','00010','00010','00010','00100','01000'),
 '+': ('00000','00100','00100','11111','00100','00100','00000'),
 '=': ('00000','00000','11111','00000','11111','00000','00000'),
 '%': ('11001','11010','00010','00100','01000','01011','10011'),
 'X': ('10001','10001','01010','00100','01010','10001','10001'),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = bytearray(w * h * 3)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 3
            self.buf[i:i + 3] = bytes(c)

    def fill(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            base = (y * self.w) * 3
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.buf[base + x * 3:base + x * 3 + 3] = bytes(c)

    def rect(self, x0, y0, x1, y1, c, t=1):
        for k in range(t):
            self.fill(x0 + k, y0 + k, x1 - k, y0 + k, c)
            self.fill(x0 + k, y1 - k, x1 - k, y1 - k, c)
            self.fill(x0 + k, y0 + k, x0 + k, y1 - k, c)
            self.fill(x1 - k, y0 + k, x1 - k, y1 - k, c)

    def line(self, x0, y0, x1, y1, c, t=1):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if t > 1:
                self.px(x0 + 1, y0, c); self.px(x0, y0 + 1, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def text(self, x, y, s, c=TEXT, scale=1):
        cx = x
        for ch in s.upper():
            g = FONT.get(ch, FONT[' '])
            for ry, row in enumerate(g):
                for rx, bit in enumerate(row):
                    if bit == '1':
                        for sy in range(scale):
                            for sx in range(scale):
                                self.px(cx + rx * scale + sx, y + ry * scale + sy, c)
            cx += 6 * scale

    def text_w(self, s, scale=1):
        return len(s) * 6 * scale

    def circle(self, cx, cy, r, c, thick=1):
        steps = max(64, r * 8)
        import math
        for k in range(steps):
            a = 2 * math.pi * k / steps
            for t in range(thick):
                self.px(int(round(cx + (r - t) * math.cos(a))),
                        int(round(cy + (r - t) * math.sin(a))), c)


def render():
    cv = Canvas(W, H)
    # Vertical background gradient plus a 40px technical grid.
    for y in range(H):
        f = y / (H - 1)
        c = (int(BG0[0] + (BG1[0] - BG0[0]) * f),
             int(BG0[1] + (BG1[1] - BG0[1]) * f),
             int(BG0[2] + (BG1[2] - BG0[2]) * f))
        cv.fill(0, y, W - 1, y, c)
    for x in range(0, W, 40):
        cv.fill(x, 0, x, H - 1, GRID)
    for y in range(0, H, 40):
        cv.fill(0, y, W - 1, y, GRID)

    # Margin marker: 45-degree hatch and a strip pattern outside the viewport.
    for k in range(-H, W, 10):
        for y in range(H):
            x = k + y
            if 0 <= x < W and not (VIEW_X <= x < VIEW_X + VIEW_W and VIEW_Y <= y < VIEW_Y + VIEW_H):
                cv.px(x, y, HATCH)

    # Measurement rulers for the physical page and the virtual window.
    cv.line(VIEW_X, 44, VIEW_X + VIEW_W - 1, 44, ACCENT)
    cv.line(VIEW_X, 38, VIEW_X, 50, ACCENT)
    cv.line(VIEW_X + VIEW_W - 1, 38, VIEW_X + VIEW_W - 1, 50, ACCENT)
    cv.text(VIEW_X + VIEW_W // 2 - 15, 30, '800', ACCENT, 1)
    cv.line(44, VIEW_Y, 44, VIEW_Y + VIEW_H - 1, ACCENT)
    cv.line(38, VIEW_Y, 50, VIEW_Y, ACCENT)
    cv.line(38, VIEW_Y + VIEW_H - 1, 50, VIEW_Y + VIEW_H - 1, ACCENT)
    cv.text(14, VIEW_Y + VIEW_H // 2 - 4, '600', ACCENT, 1)
    cv.text(56, 46, 'PHYSICAL PAGE 800x600x24 PIXELS, STRIDE 2400, NO ROW PADDING', DIM, 1)

    # Virtual-window frame (2px) and corner brackets exactly at (80,60)-(719,539).
    cv.rect(VIEW_X, VIEW_Y, VIEW_X + VIEW_W - 1, VIEW_Y + VIEW_H - 1, MAGENTA, 2)
    for (cx, cy, dx, dy) in ((VIEW_X, VIEW_Y, 1, 1), (VIEW_X + VIEW_W - 1, VIEW_Y, -1, 1),
                             (VIEW_X, VIEW_Y + VIEW_H - 1, 1, -1),
                             (VIEW_X + VIEW_W - 1, VIEW_Y + VIEW_H - 1, -1, -1)):
        cv.fill(cx, cy - 4, cx + dx * 8, cy + 4, YELLOW)
        cv.fill(cx - 4, cy, cx + 4, cy + dy * 8, YELLOW)

    # Title band inside the virtual window.
    cv.fill(VIEW_X + 2, VIEW_Y + 2, VIEW_X + VIEW_W - 3, VIEW_Y + 38, CARD)
    cv.text(VIEW_X + 12, VIEW_Y + 12, 'EG4S20 PROBE 800x600 ORIGINAL PAGE', TEXT, 2)
    cv.text(VIEW_X + 12, VIEW_Y + 30, 'VIRTUAL 640x480 SOURCE WINDOW AT (80,60) - FULL PIXELS, NO RESAMPLE', DIM, 1)
    cv.text(VIEW_X + VIEW_W - 88, VIEW_Y + 12, '01/01', ACCENT, 2)

    # Four product cards with independent colour identity and a bar row.
    cards = [
        (VIEW_X + 16, VIEW_Y + 50, 'EG4S20', 'HX4S20C', OK, 0.82),
        (VIEW_X + 328, VIEW_Y + 50, 'TD 6.2.1', 'BITGEN', WARM, 0.64),
        (VIEW_X + 16, VIEW_Y + 226, 'SDRAM', '8 MIB', ACCENT, 0.71),
        (VIEW_X + 328, VIEW_Y + 226, 'TF SPI', '12.5 MHZ', MAGENTA, 0.58),
    ]
    for i, (x, y, t1, t2, col, frac) in enumerate(cards):
        cv.fill(x, y, x + 288, y + 160, CARD)
        cv.rect(x, y, x + 288, y + 160, EDGE, 1)
        cv.fill(x, y, x + 288, y + 3, col)
        cv.text(x + 10, y + 12, t1, TEXT, 2)
        cv.text(x + 10, y + 32, t2, col, 2)
        # bar chart (the radar card keeps its lower half free)
        for b in range(8):
            if i == 2:
                continue
            bh = 10 + ((b * 37 + i * 23) % 46)
            cv.fill(x + 12 + b * 14, y + 146 - bh, x + 22 + b * 14, y + 146, col)
        cv.fill(x + 12, y + 148, x + 276, y + 148, EDGE)
        # progress rule
        cv.fill(x + 12, y + 56, x + 12 + int(264 * frac), y + 60, col)
        cv.rect(x + 12, y + 56, x + 275, y + 60, EDGE, 1)

    # Radar panel inside the third card, below its progress rule.
    RCX, RCY, RR = VIEW_X + 96, VIEW_Y + 331, 34
    cv.circle(RCX, RCY, RR, EDGE, 1)
    cv.circle(RCX, RCY, RR * 2 // 3, (44, 66, 100), 1)
    cv.circle(RCX, RCY, RR // 3, (44, 66, 100), 1)
    cv.line(RCX, RCY - RR, RCX, RCY + RR, (40, 60, 92))
    cv.line(RCX - RR, RCY, RCX + RR, RCY, (40, 60, 92))
    cv.line(RCX, RCY, RCX + 26, RCY - 26, ACCENT, 2)
    for (dx, dy) in ((18, -9), (-12, 16), (8, 21), (-22, -5)):
        cv.fill(RCX + dx, RCY + dy, RCX + 1 + dx, RCY + 1 + dy, WARM)

    # Per-pixel calibration tile inside the window (unique value per pixel).
    for y in range(64):
        for x in range(64):
            cv.px(VIEW_X + 540 + x, VIEW_Y + 250 + y,
                  ((x * 3 + 7) & 255, (y * 5 + 3) & 255, ((x ^ y) * 7 + 11) & 255))
    cv.rect(VIEW_X + 540, VIEW_Y + 250, VIEW_X + 603, VIEW_Y + 313, YELLOW, 1)
    cv.text(VIEW_X + 540, VIEW_Y + 318, 'CAL TILE 64x64', DIM, 1)

    # Colour ramps: R, G, B and a deterministic dither strip.
    ramp_y = VIEW_Y + 420
    for x in range(640):
        v = x * 255 // 639
        cv.px(VIEW_X + x, ramp_y + 0, (v, 0, 0))
        cv.px(VIEW_X + x, ramp_y + 4, (0, v, 0))
        cv.px(VIEW_X + x, ramp_y + 8, (0, 0, v))
        d = 255 if ((x >> 2) + ((x >> 6) & 1)) & 1 else 0
        cv.fill(VIEW_X + x, ramp_y + 12, VIEW_X + x, ramp_y + 19, (d, d // 2, 255 - d))
    cv.text(VIEW_X + 8, ramp_y + 22, 'R / G / B RAMPS + DITHER - EVERY PHYSICAL PIXEL STORED', DIM, 1)
    cv.text(VIEW_X + 8, ramp_y + 34, 'WINDOW 640x480 = 307200 OF 480000 PIXELS = 64.0 PERCENT', ACCENT, 1)
    cv.text(VIEW_X + 8, ramp_y + 46, 'OUTSIDE WINDOW 172800 PIXELS CARRY FLAG + RULER CONTENT', WARM, 1)

    # Bottom margin annotation and one calibration tile that only exists
    # outside the virtual window (proof the file is a real 800x600 page).
    cv.fill(0, 556, W - 1, 559, EDGE)
    cv.text(8, 566, 'FILE 800x600 24BPP BI_RGB BOTTOM-UP, PIXEL OFFSET 54 OR 512', TEXT, 1)
    cv.text(8, 580, 'PAYLOAD 1440000 BYTES, BFSIZE 1440054 OR 1440512, MARGIN TILE AT 720,26', DIM, 1)
    for y in range(48):
        for x in range(48):
            cv.px(720 + x, 26 + y, ((255 - x * 5) & 255, (y * 5) & 255, 128))
    cv.rect(719, 25, 768, 74, YELLOW, 1)
    return cv


def bmp_payload(cv):
    """Bottom-up BGR rows, stride 2400, no padding."""
    out = bytearray()
    for row in range(H - 1, -1, -1):
        base = row * W * 3
        line = cv.buf[base:base + W * 3]
        for x in range(W):
            r, g, b = line[x * 3], line[x * 3 + 1], line[x * 3 + 2]
            out += bytes((b, g, r))
    return bytes(out)


def build(payload, header_bytes):
    dib = bytearray(40)
    struct.pack_into('<IiiHHIIiiII', dib, 0, 40, W, H, 1, 24, 0, len(payload),
                     2835, 2835, 0, 0)
    head = bytearray(14)
    struct.pack_into('<2sIHHI', head, 0, b'BM', header_bytes + len(payload), 0, 0, header_bytes)
    assert len(head) + len(dib) == 54
    body = bytes(head) + bytes(dib)
    if header_bytes == 54:
        return body + payload
    return body + bytes(header_bytes - 54) + payload


def check(data, expect_offset):
    sig, size, r0, r1, off = struct.unpack_from('<2sIHHI', data, 0)
    dib, w, h, planes, bits, comp, image, xppm, yppm, used, imp = struct.unpack_from('<IiiHHIIiiII', data, 14)
    assert (sig, r0, r1, dib, w, h, planes, bits, comp) == (b'BM', 0, 0, 40, W, H, 1, 24, 0), 'header'
    assert size == len(data) and off == expect_offset, (size, len(data), off)
    assert image == STRIDE * H == 1440000, image
    payload = data[off:]
    assert len(payload) == STRIDE * H, len(payload)
    assert any(data[54:off]) is False, 'header gap must be zero'
    return payload


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cv = render()
    payload = bmp_payload(cv)
    assert len(payload) == 1440000
    files = {}
    for name, hb in (('UI06.BMP', 54), ('UI06_512.BMP', 512)):
        data = build(payload, hb)
        p = OUT / name
        p.write_bytes(data)
        check(data, hb)
        files[name] = {
            'path': str(p.relative_to(ROOT)), 'bytes': len(data),
            'sha256': hashlib.sha256(data).hexdigest(),
            'header_bytes': hb, 'pixel_offset': hb,
            'sectors': (len(data) + 511) // 512,
            'width': W, 'height': H, 'bits_per_pixel': 24,
            'row_stride_bytes': STRIDE, 'row_padding_bytes': 0,
            'pixel_bytes': len(payload),
            'pixel_sha256': hashlib.sha256(payload).hexdigest(),
        }
    inside = [(x, y) for y in range(VIEW_Y, VIEW_Y + VIEW_H) for x in range(VIEW_X, VIEW_X + VIEW_W)]
    outside = [(x, y) for y in range(H) for x in range(W) if not (VIEW_X <= x < VIEW_X + VIEW_W and VIEW_Y <= y < VIEW_Y + VIEW_H)]
    manifest = {
        'schema': 1,
        'purpose': 'original 800x600 page for the legacy loader virtual-window probe',
        'provenance': 'drawn by scripts/probe_bmp_media.py from primitives; not derived from, '
                      'cropped from or upscaled out of any delivered 640x480 page or HTML export',
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'geometry': {'width': W, 'height': H, 'bits_per_pixel': 24, 'compression': 'BI_RGB',
                     'orientation': 'positive height, bottom-up file rows',
                     'row_stride_bytes': STRIDE, 'row_padding_bytes': 0,
                     'virtual_window': {'x': VIEW_X, 'y': VIEW_Y, 'w': VIEW_W, 'h': VIEW_H,
                                        'window_pixels': len(inside),
                                        'outside_window_pixels': len(outside),
                                        'area_percent': round(100.0 * len(inside) / (W * H), 4)}},
        'files': files,
        'outside_window_evidence': {
            'margin_tile_origin': [720, 26], 'margin_tile_size': [48, 48],
            'ruler_rows': [30, 44], 'note': 'content at x>=720 and y<60 is stored but never shown by the 640x480 window'},
    }
    m = OUT / 'probe_bmp_manifest.json'
    m.write_bytes(json.dumps(manifest, indent=2).encode())
    print(json.dumps({'files': {k: {kk: vv for kk, vv in v.items() if kk in ('bytes', 'sha256', 'sectors')} for k, v in files.items()},
                      'manifest': str(m.relative_to(ROOT))}, indent=2))


if __name__ == '__main__':
    main()
