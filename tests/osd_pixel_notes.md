# OSD and pixel adjustment contracts

Both modules use synchronous active-high reset and register RGB, HS, VS and DE
in the same output stage (one pixel-clock cycle). Configuration must remain
stable through a frame; the caller supplies the frame commit.

`pixel_adjust` applies `floor((pixel-128)*quarters/4)+128+brightness`, then
saturates to 0..255, independently for R, G and B. Contrast 0..6 selects
quarters 2..8; codes 2 and 7 select unity. Brightness is signed 9-bit (-256..255).
The arithmetic uses shifts/additions; no general multiplier is requested.
Blank RGB becomes zero while HS and VS continue through the register.

`osd_overlay` requires 640x480 active video with active-high DE and a rising VS
edge during frame blanking. It counts active lines at DE falling edges and resets
its line count on VS rising. Disabled overlay preserves all input RGB, including
blank pixels. Enabled overlay changes only active pixels. Coordinates are unsigned
10-bit; extended comparisons keep a panel near the edge from wrapping. Panels
are opaque dark backgrounds with a 5x7 font. Title is doubled, 192x16; status is
376x9. The ticker is a 256-pixel repeat, shifted left by one pixel at each VS rising
edge. Layers are title > status > ticker > progress >
source. At 25 MHz 640x480 VGA, the actual frame rate follows the source timing.
The fixed progress panel is x=16..271, y=468..471. Value 0 is empty, 128 is half,
and 255 is complete. Dynamic text displays all eight selected modes, signed
brightness, decimal contrast, interval, paused/playing, auto/manual, mute/unmute,
a hex state digit, and numeric transition, scale and volume values. The ticker/title strings are built-in demo identifiers;
no filename input or audio waveform input is included in this module.

Tests use fresh Windows Icarus snapshots through `scripts/run_test.py`:

```
python3 tests/pixel_vectors.py tests/pixel_vectors.txt
python3 scripts/run_test.py pixel_001 pixel_adjust_tb tests/pixel_adjust_tb.v rtl/ext/pixel_adjust.v --data tests/pixel_vectors.txt
python3 scripts/run_test.py osd_002 osd_tb tests/osd_tb.v rtl/ext/osd_overlay.v
```

Choose unused run IDs on rerun. `pixel_vectors.py` is an independent Python
integer golden model; 22,528 vectors cover all 256 values in each channel,
all contrast codes, and 11 brightness values including signed extrema and
saturation boundaries. The OSD test checks disabled full-frame bypass, output
sync on every checked pixel, reset, layer overlap, text formatting, consecutive
frame scrolling, edge clipping, and empty/half/full progress frames. These tests
establish module-scoped UNIT_SIM_PASS only. Synthesis, timing, full-system
simulation and hardware remain separate checks.
