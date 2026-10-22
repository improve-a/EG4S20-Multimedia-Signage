# Probe audio / multi-resolution candidate

Status: in development; no hardware operation authorized or performed.

## Baseline and isolation

- Hardware-passed source: `72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`.
- Historical delivery: `42de1dbe4a20ca78f28be54c4bf41bd0dd814481`.
- Preserved bit SHA-256: `bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`.
- Branch: `feature/probe-audio-multires`, created directly at the passed source.
- Mac isolated clone: `probe_audio_multires`; Windows isolated clone/build root:
  `D:/FPGA/EG4S20-Probe-Audio-Multires`.
- No historical source, material, build directory or NoBot workspace is modified.

## Reviewed OSD inheritance

Commit `61efa10` ports only the OSD/native-1x production changes from `a288923`,
with the focused regression and updated default expectation. It does not adopt
that untested candidate as the stable baseline. The three RTL differences are
the reset default in `media_controls.v`, existing transition-state wiring in
`html_video_overlay.v`, and status text in `html_osd_overlay.v`. Two font files
extend unused ROM words; the existing five-stage pixel pipeline is retained.
The former candidate's hardware and build results are not claimed for this one.

`scripts/probe_restore_baseline.py` restores missing, untracked dependencies from
the exact hardware-passed source archive. Existing files are not overwritten;
frozen absolute ROM paths are returned to relative form for build relocation.
Vendor/derived sources and build artifacts remain private and untracked.

The existing Windows build supervisor receives only the previously reviewed
UTF-8 status-reader fix. There are no new build gates, timing exceptions, or
changes to clocks, SDRAM arbitration, pins, HDMI interfaces or key assignments.

## Verification and delivery

The fresh inherited `probe_osd_default_1x_verify.py`,
`no_bot_legacy_control_verify.py` and `html_osd_swap_verify.py` runs all exited 0
in the isolated Windows checkout (before audio/BMP integration). Their logs are
under `output/probe_audio_multires/inherited_regression_002`.

Review of all 129 non-log frozen production inputs found only the intended eight
differences: four audio/BMP RTL files, the three OSD/default RTL files (OSD is
shared by both groups), and two font files. Frozen top, HDMI, SD protocol,
SDRAM/FIFO writer/reader, constraints, PLL and key definitions remain unchanged.
Final integrated regression and routed timing remain to be recorded.

### BMP interpretation

The 800×600 source is **not** displayed in full. The FPGA reads its central
640×480 window at physical source coordinates (80,60); 64% of the source area
is visible at 1×. The unchanged 2×/3× sampling and focus operate within that
window. This is on-FPGA crop/address adaptation, not host-side downsampling.

Both SDRAM buffers remain 307,200 × 32-bit words at bases 0 and 307,200; the
highest frame word is 614,399 and the combined storage is 2,457,600 bytes.
The 800×600 BMP's 2,400-byte source row stride does not become a framebuffer
stride. One existing 640×24-bit line RAM and one 512-byte sector RAM are reused.

### Windows-local workflow

All media generation, unpacking, regression, TD snapshots and final bitstreams
stay under `D:/FPGA/EG4S20-Probe-Audio-Multires`. Only source commits, small
reports and hash manifests are synchronized to the Mac. The interrupted Mac
`baseline_media.zip` is incomplete and is not an input or delivery artifact.

Use `scripts/run_regression.py --local --evidence-root
output/probe_audio_multires/regression` on Windows for the existing recipe set.
Any final bit is classified `NEW_CANDIDATE_HARDWARE_NOT_TESTED`.
