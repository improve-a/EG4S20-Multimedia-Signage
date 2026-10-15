# Offline demo media

From the repository root run:

```sh
python3 scripts/make_demo_media.py
```

The script writes only `artifacts/demo_media/`. It creates four 24-bit,
uncompressed, positive-height (bottom-up) BMPs at 320x240, 320x180, 640x360,
and 640x480, plus a 30-second PCM16 stereo 48 kHz WAV (use `--seconds 8` for a short EOF test). BMPs use color bars,
checker fields, a red frame, coordinate ticks, and different top-left/bottom-left
markers for checking orientation and centering. WAV channels use 440 Hz and
660 Hz tones with a stepped amplitude ramp and a silent final second.

`demo_media_raw.img` is a raw concatenation for the sector scanner, not a FAT
volume: the first BMP starts at LBA 0, each following asset starts at the next
512-byte boundary, and padding bytes are zero. `manifest.json` records exact
LBA/offset/length/sector counts and SHA-256 values. The image is intentionally
ignored by Git and must only be used as an offline test fixture; this generator
does not write to a card or raw device.
