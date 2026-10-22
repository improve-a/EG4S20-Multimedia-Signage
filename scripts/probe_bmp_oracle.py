#!/usr/bin/env python3
"""Independent geometry oracle for the 640x480 / 800x600 virtual-window loader.

This module never reads RTL constants. It models the documented display rule
(integer 1/2/3x nearest neighbour over a centre-anchored source window) and the
one 800x600 rule under probe:

    physical source pixel = (80 + logical_x, 60 + logical_y)

so a real 800x600 page is seen through a fixed 640x480 window whose stored
content is the centre 64.0% of the page.  The loader must emit exactly these
pixels for out_row = 0..479 in stream order (stream row 0 is the framebuffer
bottom row because WRITE_V_FLIP=1 reverses the memory rows).

Also models the loader's SD sector sequence so the bench can assert the exact
request count and the highest sector touched.
"""
import hashlib
import struct
from pathlib import Path

CENTERS = [(435, 192), (320, 240), (160, 240), (480, 240), (320, 120), (320, 360)]
PAGE0_ALT_CENTER = (448, 173)   # focus 0 default on pages 1..5 (home bit 0)
WIDE = {(800, 600): (80, 60)}


class Bmp:
    def __init__(self, path):
        self.path = Path(path)
        b = self.path.read_bytes()
        if b[:2] != b'BM':
            raise ValueError(f'{path}: missing BM signature')
        self.size = struct.unpack_from('<I', b, 2)[0]
        self.offset = struct.unpack_from('<I', b, 10)[0]
        dib, self.w, self.h, planes, bpp, comp = struct.unpack_from('<IiiHHI', b, 14)
        if dib != 40 or planes != 1 or bpp != 24 or comp != 0:
            raise ValueError(f'{path}: expected DIB40/1/24/BI_RGB')
        if self.h <= 0:
            raise ValueError(f'{path}: expected positive (bottom-up) height')
        if (self.w, self.h) not in ((320, 480), (640, 480), (800, 600)):
            raise ValueError(f'{path}: geometry {self.w}x{self.h} not authored')
        if self.offset not in (54, 512):
            raise ValueError(f'{path}: offset {self.offset} not authored')
        if self.size != len(b):
            raise ValueError(f'{path}: declared bfSize {self.size} != {len(b)}')
        self.stride = (self.w * 3 + 3) & ~3
        if self.offset + self.stride * self.h > len(b):
            raise ValueError(f'{path}: truncated payload')
        if self.offset > 54 and any(b[54:self.offset]):
            raise ValueError(f'{path}: header gap not zero')
        self.payload = b[self.offset:self.offset + self.stride * self.h]
        self.sha256 = hashlib.sha256(b).hexdigest()
        self.payload_sha256 = hashlib.sha256(self.payload).hexdigest()

    def pixel(self, x, y):
        """RGB triple at top-down (x,y)."""
        row = self.h - 1 - y
        i = row * self.stride + x * 3
        b, g, r = self.payload[i:i + 3]
        return (r, g, b)


def source_xy(x, y, zoom, focus, page):
    """Logical 640x480 source coordinate for canvas pixel (x,y)."""
    d = min(3, max(1, int(zoom) + 1))
    if d == 1:
        return x, y
    cx, cy = CENTERS[focus if 0 <= focus < 6 else 0]
    if focus == 0 and page != 0:
        cx, cy = PAGE0_ALT_CENTER        # pages 1..5 use the alternate default
    return cx + (x - 320) // d, cy + (y - 240) // d


def physical(bmp, sx, sy, page):
    """Map a logical source pixel into the stored page."""
    ox, oy = WIDE.get((bmp.w, bmp.h), (0, 0))
    px, py = ox + sx, oy + sy
    if not (0 <= px < bmp.w and 0 <= py < bmp.h):
        raise AssertionError(f'logical ({sx},{sy}) leaves {bmp.w}x{bmp.h} page at ({px},{py})')
    return px, py


def window(bmp):
    """Physical rectangle of the 640x480 virtual window."""
    ox, oy = WIDE.get((bmp.w, bmp.h), (0, 0))
    return ox, oy, 640, 480


def expected_words(left, right, page, dual, zoom, focus):
    """307200 24-bit words in loader emit order (stream row 0 = bottom)."""
    words = []
    for out_row in range(480):
        y = 479 - out_row                      # display row, top-down
        for x in range(640):
            sx, sy = source_xy(x, y, zoom, focus, page)
            if dual:
                img, lx = (right, sx - 320) if sx >= 320 else (left, sx)
            else:
                img, lx = left, sx
            px, py = physical(img, lx, sy, page)
            r, g, b = img.pixel(px, py)
            words.append((r << 16) | (g << 8) | b)
    return words


def rows_read(zoom, focus):
    """Distinct logical rows read, in first-seen order."""
    d = min(3, max(1, int(zoom) + 1))
    seen = []
    for out_row in range(480):
        y = 479 - out_row
        _, sy = source_xy(0, y, zoom, focus, 0)
        if not seen or seen[-1] != sy:
            seen.append(sy)
    return seen


def row_windows(images, dual, zoom, focus):
    """(image, first_byte, byte_count) per row window, in request order."""
    out = []
    for sy in rows_read(zoom, focus):
        for img in images:
            ox, oy, _, _ = window(img)
            file_row = (img.h - 1) - (oy + sy)
            out.append((img, 512 + img.stride * file_row + ox * 3, 960 if dual else 1920))
    return out


def sectors_of(first, nbytes):
    res = []
    pos, left = first, nbytes
    while left > 0:
        res.append(pos // 512)
        step = min(512 - (pos % 512), left)
        pos += step
        left -= step
    return res


def sector_sequence(left, right, dual, zoom, focus):
    """Sector indices in request order, mirroring the loader's row windows."""
    images = [left, right] if dual else [left]
    seq = [0] * len(images)                      # one 512-byte header per file
    for img, first, nbytes in row_windows(images, dual, zoom, focus):
        seq += sectors_of(first, nbytes)
    return seq


def gold_sha(words):
    return hashlib.sha256(dump_text(words).encode()).hexdigest()


def dump_text(words):
    """Exactly the bench dump format (%06x per line) so hashes compare."""
    return ''.join(f'{w:06x}\n' for w in words)


def verify_dump(path, expected):
    words = [int(n, 16) for n in Path(path).read_text().split()]
    if len(words) != 307200:
        raise AssertionError(f'loader emitted {len(words)} pixels, expected 307200')
    for i, (got, want) in enumerate(zip(words, expected)):
        if got != want:
            x, y = i % 640, 479 - i // 640
            raise AssertionError(f'pixel mismatch out_row={i // 640} x={x} y={y} got={got:06x} want={want:06x}')
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def topdown_rgb(words):
    """Convert emit-order words to a top-down RGB byte image."""
    out = bytearray(640 * 480 * 3)
    for n, w in enumerate(words):
        x, out_row = n % 640, n // 640
        y = 479 - out_row
        at = (y * 640 + x) * 3
        out[at:at + 3] = bytes(((w >> 16) & 255, (w >> 8) & 255, w & 255))
    return bytes(out)


def window_evidence(bmp, zoom=0, focus=0, page=0):
    """Prove the stored page is a real full page, not a pre-cropped window."""
    ox, oy, w, h = window(bmp)
    inside = outside = 0
    differing = 0
    for y in range(bmp.h):
        for x in range(bmp.w):
            if ox <= x < ox + w and oy <= y < oy + h:
                inside += 1
            else:
                outside += 1
                # mirror the pixel to the nearest in-window column/row
                mx = min(max(x, ox), ox + w - 1)
                my = min(max(y, oy), oy + h - 1)
                if bmp.pixel(x, y) != bmp.pixel(mx, my):
                    differing += 1
    words = expected_words(bmp, bmp, page, 0, zoom, focus)
    return {
        'page_width': bmp.w, 'page_height': bmp.h,
        'window': {'x': ox, 'y': oy, 'w': w, 'h': h},
        'window_pixels': inside, 'outside_window_pixels': outside,
        'window_area_percent': round(100.0 * inside / (bmp.w * bmp.h), 4),
        'outside_pixels_differing_from_edge': differing,
        'emitted_pixels': len(words),
        'window_pixel_sha256': hashlib.sha256(topdown_rgb(words)).hexdigest(),
    }


def stride_evidence(bmp, zoom=0, focus=0):
    """Byte/sector boundaries of the first, middle and last row windows."""
    rows = rows_read(zoom, focus)
    ox, oy, _, _ = window(bmp)
    out = {'stride_bytes': bmp.stride, 'row_padding_bytes': bmp.stride - bmp.w * 3,
           'window_start_byte_in_row': ox * 3, 'rows_read': len(rows)}
    picks = {}
    for label, idx in (('first', 0), ('middle', len(rows) // 2), ('last', len(rows) - 1)):
        sy = rows[idx]
        file_row = (bmp.h - 1) - (oy + sy)
        first = 512 + bmp.stride * file_row + ox * 3
        last = first + 1920 - 1
        picks[label] = {'logical_row': sy, 'file_row': file_row,
                        'first_byte': first, 'first_sector': first // 512,
                        'last_byte': last, 'last_sector': last // 512,
                        'last_byte_in_file': bmp.offset + bmp.stride * bmp.h - 1}
    out['rows'] = picks
    seq = sector_sequence(bmp, bmp, 0, zoom, focus)
    out['requests'] = len(seq)
    out['max_sector'] = max(seq)
    out['file_sectors'] = (bmp.size + 511) // 512
    out['max_sector_within_file'] = max(seq) < (bmp.size + 511) // 512
    return out


# ---------------------------------------------------------------------------
# Shared fixtures and case table. The Mac driver and the Windows runner import
# this single module, so fixture bytes, case parameters and expected values
# cannot drift between the two sides.
# ---------------------------------------------------------------------------
WIDE_SEED = {'syn800': 0x51, 'syn640': 0x27, 'syn320': 0x33}

FIXTURES = {
    # name           width height offset header seed/source
    'syn800': dict(w=800, h=600, offset=512, seed=0x51),
    'syn640': dict(w=640, h=480, offset=512, seed=0x27),
    'syn320': dict(w=320, h=480, offset=512, seed=0x33),
    'real800': dict(w=800, h=600, offset=512, media='UI06_512.BMP'),
}


def synthetic_payload(w, h, seed):
    """Unique-ish RGB per pixel so any coordinate error changes the output."""
    stride = (w * 3 + 3) & ~3
    out = bytearray(stride * h)
    for row in range(h):
        y = h - 1 - row                     # stored bottom-up
        base = row * stride
        for x in range(w):
            r = (x * 7 + y * 3 + seed) & 255
            g = (x * 3 + y * 11 + seed * 2 + 37) & 255
            b = (x * 13 + y * 5 + seed * 3 + 73) & 255
            i = base + x * 3
            out[i] = b; out[i + 1] = g; out[i + 2] = r
    return bytes(out)


def bmp_bytes(w, h, offset, payload):
    stride = (w * 3 + 3) & ~3
    assert len(payload) == stride * h
    dib = bytearray(40)
    struct.pack_into('<IiiHHIIiiII', dib, 0, 40, w, h, 1, 24, 0, len(payload), 2835, 2835, 0, 0)
    head = bytearray(14)
    struct.pack_into('<2sIHHI', head, 0, b'BM', offset + len(payload), 0, 0, offset)
    body = bytes(head) + bytes(dib)
    return body + (bytes(offset - 54) if offset > 54 else b'') + payload


def fixture_bytes(name, media_dir):
    spec = FIXTURES[name]
    if 'media' in spec:
        return (media_dir / spec['media']).read_bytes()
    payload = synthetic_payload(spec['w'], spec['h'], spec['seed'])
    return bmp_bytes(spec['w'], spec['h'], spec['offset'], payload)


LOADER_CASES = [
    dict(name='single800_1x', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=0, period=2),
    dict(name='real800_1x', fixture='real800', page=0, dual=0, zoom=0, focus=0, mode=0, period=16),
    dict(name='single800_2x_home', fixture='syn800', page=0, dual=0, zoom=1, focus=0, mode=0, period=2),
    dict(name='single800_2x_page2', fixture='syn800', page=2, dual=0, zoom=1, focus=0, mode=0, period=2),
    dict(name='single800_2x_focus5', fixture='syn800', page=2, dual=0, zoom=1, focus=5, mode=0, period=2),
    dict(name='single800_3x_focus3', fixture='syn800', page=3, dual=0, zoom=2, focus=3, mode=0, period=2),
    dict(name='single800_3x_focus2', fixture='syn800', page=3, dual=0, zoom=2, focus=2, mode=0, period=2),
    dict(name='dual320_1x', fixture='syn320', right='syn320', page=1, dual=1, zoom=0, focus=0, mode=0, period=2),
    dict(name='dual320_3x_focus1', fixture='syn320', right='syn320', page=3, dual=1, zoom=2, focus=1, mode=0, period=2),
    dict(name='reload_800_640_800', fixture='syn800', reload=['syn640', 'syn800'], page=0, dual=0, zoom=0, focus=0, mode=20, period=2),
    # authored-header rejections (error 1, no write_req, no pixels)
    dict(name='reject_800_width801', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=1, period=2, bad_byte=18, bad_mask=1),
    dict(name='reject_800_height601', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=1, period=2, bad_byte=22, bad_mask=1),
    dict(name='reject_800_negative_height', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=1, period=2, bad_byte=25, bad_mask=0x80),
    dict(name='reject_800_wrong_bfsize', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=1, period=2, bad_byte=2, bad_mask=1),
    dict(name='reject_dual_with_800', fixture='syn800', right='syn320', page=1, dual=1, zoom=0, focus=0, mode=1, period=2, bad_byte=28, bad_mask=0),
    dict(name='reject_640_as_dual', fixture='syn640', right='syn320', page=1, dual=1, zoom=0, focus=0, mode=1, period=2, bad_byte=28, bad_mask=0),
    dict(name='reject_short_sector', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=2, period=2),
    dict(name='reject_sd_error', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=3, period=2),
    dict(name='reject_no_ack', fixture='syn800', page=0, dual=0, zoom=0, focus=0, mode=4, period=2),
]

SCAN_POSITIONS = [2081, 3882, 5683, 7484, 9285, 11086, 13900, 14801, 15702, 16603]
SCAN_FIXTURES = ['syn640', 'syn640', 'syn640', 'syn640', 'syn640',
                 'real800', 'syn320', 'syn320', 'syn320', 'syn320']

SCAN_CASES = [
    dict(name='scan_catalog_10', mode=0),
    dict(name='scan_reject_width801', mode=1),
    dict(name='scan_reject_height601', mode=2),
    dict(name='scan_reject_negative_height', mode=3),
    dict(name='scan_reject_bfsize_below_payload', mode=4),
    dict(name='scan_load_path_refuses_800', mode=5),
]


def gold_text(words):
    return ''.join(f'{w:06x}\n' for w in words)


def gold_sha(words):
    return hashlib.sha256(gold_text(words).encode()).hexdigest()


if __name__ == '__main__':
    import argparse, json
    ap = argparse.ArgumentParser()
    ap.add_argument('bmp', type=Path)
    a = ap.parse_args()
    img = Bmp(a.bmp)
    print(json.dumps({'w': img.w, 'h': img.h, 'stride': img.stride,
                      'offset': img.offset, 'size': img.size,
                      'sha256': img.sha256,
                      'window': window_evidence(img), 'stride_evidence': stride_evidence(img)}, indent=2))
