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

Fresh regression, source identity, media hashes, routed timing and final artifact
paths will be recorded here after integration. Any final bit is classified
`NEW_CANDIDATE_HARDWARE_NOT_TESTED`.
