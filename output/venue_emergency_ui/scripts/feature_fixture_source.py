#!/usr/bin/env python3
"""Generate deterministic BMP/WAV fixtures and a sector-aligned raw image.

The raw image has no partition table or filesystem. BMP files begin at LBA 0;
each next asset begins at the next 512-byte boundary. Output is confined to
artifacts/demo_media under this repository.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "demo_media"
SECTOR = 512
RATE = 48_000


def align_sector(size: int) -> int:
    return (size + SECTOR - 1) // SECTOR * SECTOR


def rgb_at(x: int, y: int, width: int, height: int, variant: int) -> tuple[int, int, int]:
    # A small orientation key: green near top-left, blue near bottom-left.
    if x < max(8, width // 24) and y < max(8, height // 12):
        return (0, 255, 64)
    if x < max(8, width // 24) and y >= height - max(8, height // 12):
        return (32, 96, 255)
    # Red outline, with labeled-by-spacing coordinate ticks on top/left edges.
    if x < 3 or y < 3 or x >= width - 3 or y >= height - 3:
        return (255, 32, 32)
    if y < 12 and x % max(16, width // 8) < 4:
        return (255, 255, 255)
    if x < 12 and y % max(16, height // 6) < 4:
        return (255, 255, 0)

    bars = ((255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0),
            (255, 0, 255), (255, 0, 0), (0, 0, 255), (24, 24, 24))
    bar = bars[min(7, x * 8 // width)]
    if y < height // 3:
        return bar
    cell_w = max(8, width // 16)
    cell_h = max(8, height // 12)
    checker = ((x // cell_w) ^ (y // cell_h) ^ variant) & 1
    factor = 1.0 if checker else 0.35
    # Lower field combines the color bars and checker pattern.
    return tuple(int(c * factor) for c in bar)


def make_bmp(width: int, height: int, variant: int) -> bytes:
    row_bytes = width * 3
    padding = (-row_bytes) & 3
    image_size = (row_bytes + padding) * height
    file_size = 14 + 40 + image_size
    header = struct.pack("<2sIHHI", b"BM", file_size, 0, 0, 54)
    dib = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 24, 0,
                      image_size, 2835, 2835, 0, 0)
    pixels = bytearray()
    for y in range(height - 1, -1, -1):  # BMP positive height means bottom-up.
        for x in range(width):
            red, green, blue = rgb_at(x, y, width, height, variant)
            pixels.extend((blue, green, red))
        pixels.extend(b"\0" * padding)
    return header + dib + pixels


def make_wav(path: Path, seconds: int) -> int:
    frames = RATE * seconds
    data = bytearray()
    for index in range(frames):
        t = index / RATE
        if t >= seconds - 1:
            left = right = 0
        else:
            # One-second amplitude ramp, with distinct steady 440/660 Hz tones.
            envelope = 0.12 + 0.68 * ((index // RATE) / max(1, seconds - 2))
            left = int(24_000 * envelope * math.sin(2.0 * math.pi * 440.0 * t))
            right = int(24_000 * envelope * math.sin(2.0 * math.pi * 660.0 * t))
        data.extend(struct.pack("<hh", left, right))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data)
    return frames


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=int, default=30, help='WAV duration, 2..120 seconds; default30 permits button demonstrations')
    args = parser.parse_args()
    if not 2 <= args.seconds <= 120:
        parser.error('--seconds must be between2 and120')
    OUT.mkdir(parents=True, exist_ok=True)
    specs = (("00_bars_checker_320x240.bmp", 320, 240),
             ("01_bars_checker_320x180.bmp", 320, 180),
             ("02_bars_checker_640x360.bmp", 640, 360),
             ("03_bars_checker_640x480.bmp", 640, 480))

    assets: list[dict[str, object]] = []
    raw_path = OUT / "demo_media_raw.img"
    offset = 0
    with raw_path.open("wb") as raw:
        for variant, (name, width, height) in enumerate(specs):
            payload = make_bmp(width, height, variant)
            file_path = OUT / name
            file_path.write_bytes(payload)
            padded_size = align_sector(len(payload))
            if offset % SECTOR:
                raise AssertionError("asset offset is not sector aligned")
            raw.write(payload)
            raw.write(b"\0" * (padded_size - len(payload)))
            assets.append({
                "name": name, "kind": "bmp", "lba": offset // SECTOR,
                "byte_offset": offset, "file_bytes": len(payload),
                "padded_bytes": padded_size, "sectors": padded_size // SECTOR,
                "width": width, "height": height, "sha256": sha256(payload),
            })
            offset += padded_size

        wav_path = OUT / f"04_stereo_48k_{args.seconds}s.wav"
        frames = make_wav(wav_path, args.seconds)
        wav_payload = wav_path.read_bytes()
        padded_size = align_sector(len(wav_payload))
        raw.write(wav_payload)
        raw.write(b"\0" * (padded_size - len(wav_payload)))
        assets.append({
            "name": wav_path.name, "kind": "wav", "lba": offset // SECTOR,
            "byte_offset": offset, "file_bytes": len(wav_payload),
            "padded_bytes": padded_size, "sectors": padded_size // SECTOR,
            "sample_rate": RATE, "channels": 2, "sample_width_bytes": 2,
            "frames": frames, "duration_seconds": args.seconds,
            "sha256": sha256(wav_payload),
        })
        offset += padded_size

    manifest = {
        "format": "raw contiguous sectors; no FAT or partition table",
        "sector_bytes": SECTOR,
        "raw_image": raw_path.name,
        "raw_image_bytes": raw_path.stat().st_size,
        "raw_image_sha256": sha256(raw_path.read_bytes()),
        "assets": assets,
        "checks": {
            "all_offsets_sector_aligned": all(a["byte_offset"] % SECTOR == 0 for a in assets),
            "assets_contiguous_with_sector_padding": True,
            "bmp_positive_height_bottom_up_24bpp_uncompressed": True,
            "wav_pcm16_stereo_48000_hz": True,
            "wav_final_one_second_silent": True,
        },
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(assets)} assets to {OUT}")
    for asset in assets:
        print(f"LBA {asset['lba']:>5}  {asset['name']}  {asset['file_bytes']} bytes  sha256 {asset['sha256']}")
    print(f"Raw image: {manifest['raw_image_bytes']} bytes, sha256 {manifest['raw_image_sha256']}")


if __name__ == "__main__":
    main()
