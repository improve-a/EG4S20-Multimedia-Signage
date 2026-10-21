# Probe OSD / native default scale candidate

Status: NEW_CANDIDATE / HARDWARE_NOT_TESTED. No programming, TF writes, merge or push.

## Provenance and isolation

The user confirmed this is the successfully accepted Probe after the requested
`local_temp/no_bot/HDMI_PROBE_ACCEPTANCE.md` could not be found. Hardware download
record: original Probe `output/hdmi_probe/hardware/accept_20261020/load.json`.
The download log itself proves SRAM loading only; functional acceptance is the
user's confirmation, not a new hardware claim.

- Accepted delivery commit: `42de1dbe4a20ca78f28be54c4bf41bd0dd814481`.
- Accepted build source commit: `72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`.
- Frozen bit SHA256: `bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`.
- Frozen source ZIP SHA256: `5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f`.
- Original directory: `D:/FPGA/EG4S20-NoBot-HDMIProbe` (read-only throughout).
- New worktree: `D:/FPGA/EG4S20-Probe-OSD-1x`.
- Branch: `fix/probe-osd-default-1x`, based on the accepted delivery commit.

`scripts/probe_osd_restore_frozen.py` restores missing local dependencies from the
verified frozen archive, never overwriting existing files. It is Windows-only and
targets the named isolated worktree. `scripts/probe_osd_provenance.py` compares all
129 non-log frozen inputs, normalizing only CRLF and snapshot path relocation.
Only three RTL files and the font HEX/BIN differ; palette and old font words
0..750 remain identical. Original top, constraints, IP, audio, loader, controller,
SDRAM, display and Probe modules remain unchanged.

## RTL changes

- `rtl/media_controls.v`: common synchronous `rst` branch sets `scale_mode=0`,
  replacing exhibit-mode `1`. Existing boot and hardware reset reach this branch
  via `sd_rst`; no independent software-reset/init path was found. The original
  KEY2/KEY4 updates and mode-navigation logic are unchanged.
- `rtl/ext/html_video_overlay.v`: routes existing configuration `transition_mode`
  into the OSD; no configuration bus or CDC changes.
- `rtl/ext/html_osd_overlay.v`: two-bit VS-latched transition state, page-specific
  status characters, expanded font index. Original five-stage pixel pipeline is
  unchanged. Control labels remain visible when captions are switched off.
- Font generator and existing 1024x8 utility ROM: add ten English letters in
  unused words, retain the same ROM instance and all existing glyph indices.

The actual loader receives the shared `scale_mode` through candidate_view[7:6]
for both single and dual layouts. Its unchanged divisor selection is
`zoom==0 ? 1 : zoom==1 ? 2 : 3` (`legacy_exhibit_loader.v:136`). Page changes
cannot reset the selected multiplier. The unchanged top-level `display_config`
overrides the zoom bits with `active_view[7:6]`: OSD reports the committed image
multiplier at the next VS, consistent with the existing zoom badge, not a
premature requested value while a new image is loading. Image loading/commit
latency is unchanged. Transition mode uses the existing video configuration bus.

## Actual status strings

Fixed columns, with the parameter starting at character 10 (zero-based):

```text
P0 PLAY
P1 BRIGHT +000
P2 CONTR  1.00
P3 INTV   05.4s
P4 OSD    1
P5 TRANS  M1
P6 ZOOM   1.0X
P7 VOL    08
```

P0..P7 are control modes, not the six content pages. Transitions show their
actual RTL codes M0/M1/M2. Zoom shows 1.0X/2.0X/3.0X. P4 displays 0/1.
Playback feedback is a persistent 52x11-pixel bottom strip (x24..75,
y467..477); parameter strips are 112x11. No timer or UI state machine is added.

## Verification and build

Run from the new worktree only:

```text
python scripts/probe_osd_provenance.py
python scripts/probe_osd_default_1x_verify.py
python scripts/no_bot_legacy_control_verify.py
python scripts/html_osd_swap_verify.py
python scripts/build.py launch probe_osd_1x_001 --build-root D:/FPGA/EG4S20-Probe-OSD-1x/output/html_fidelity/builds --timeout 1800
```

Results and final artifact identities are recorded below after execution.
No full-system encrypted HDMI simulation or new hardware acceptance is claimed.
Historical `no_bot_legacy_default_verify.py` remains a 2x-baseline test, not the
new candidate's default test; use the new directed regression above.
