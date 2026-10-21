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
python scripts/build.py launch probe_osd_1x_004 --build-root D:/FPGA/EG4S20-Probe-OSD-1x/output/html_fidelity/builds --timeout 1800
```

No full-system encrypted HDMI simulation or new hardware acceptance is claimed.
Historical `no_bot_legacy_default_verify.py` remains a 2x-baseline test, not the
new candidate's default test; use the new directed regression above.

### Executed regression

- Root directed acceptance: PASS, 41 setting/VS commits, 78,819 final-pipeline
  pixels, 5,702 glyph-ink pixels, all 35 ROM glyphs. Exercises real debounced
  keys, P0..P7 labels and parameters, M0/M1/M2, 1x/2x/3x and down-wrap, long-key
  focus, chosen zoom surviving navigation and single/dual switching, and reset
  after choosing 2x returning the actual controls register to 0. All pages are
  rendered with captions disabled as well. HEX and synthesis BIN must exactly
  match the tested generated ROM; source hashes must remain stable.
  Evidence: `output/probe_osd_default_1x/root_acceptance/verification.json`,
  `compile.log`, `simulate.log`, exact source snapshots and tool hashes.
- Existing legacy controller: 12/12 PASS, including actual initial candidate
  metadata zoom=0, dual snapshot and existing protocol/error checks.
  Evidence: `output/html_fidelity/no_bot/verify/legacy_control_20261021_162119`.
  The earlier run `legacy_control_20261021_161922` intentionally failed the
  old hard-coded default-2x assertion; that expectation alone was updated.
- Existing OSD regression: PASS, 212,480 actual output pixels, 90,944 original
  map/opacity checks, 32-frame existing swap parameters and five-stage sync.
  Evidence: `output/html_fidelity/osd_swap/run_20261021_162127`.
- Existing non-exhibit controls: PASS, reset/defaults and legacy parameter keys.
  Evidence: `output/probe_osd_1x/control_modes_{compile,simulation}.log`.
- Production top-level zoom overrides remain unchanged: actual active view
  supplies the display multiplier. Directed pixel test models the config
  packing; it does not instantiate SDRAM, loading, encrypted HDMI or the CDC.

### Build identity

- Source commit: `991ed7a` (RTL unchanged since source fix `37232b9`; directed
  regression executed at `b6fca4c`). Subsequent changes are collection helpers
  and the one-line Windows UTF-8 status reader fix, not RTL or constraints.
- Run: `output/html_fidelity/builds/probe_osd_1x_004`.
- Source ZIP: `artifacts/probe_osd_1x_004_source.zip`.
- Source ZIP SHA256: `33abcfc66d0008e16df2d75d5b52b5d6e78e0e94b2b5d738b138873480af76bc`.
- Snapshot SHA256: `93c1f2ef10eceec61e0b26ac1bcad5113ec4a3f7a288e115ebbd405de20ee698`.
- All 130 immutable inputs match the isolated worktree with only intentional
  snapshot path rewriting; all 61 project source entries resolve inside the new
  build. Evidence: `output/probe_osd_1x/snapshot_audit_probe_osd_1x_004.json`.

The launch command above records the actual run; use a fresh run ID for a later
reproduction. Existing run directories and source archives must not be reused.

### Preserved infrastructure failures

- `probe_osd_1x_001`: SYN PASS, PNR interrupted at 304.25 seconds. The supervisor
  failed with Windows `PermissionError [WinError 5]` while replacing status.json,
  then killed its owned TD process tree. No final STA or candidate bit accepted.
  A concurrent status reader was present; exact external lock ownership is not
  proven. Subsequent monitoring waits on the process handle, never its live file.
- `probe_osd_1x_002`: TD was not started. Supervisor used Windows default GBK to
  read the previous UTF-8 status containing Chinese exception text, raising
  UnicodeDecodeError. The isolated harness now explicitly reads UTF-8 on that
  one line; the frozen harness is untouched.
- `probe_osd_1x_003`: TD was not started. Root introduced an indentation error in
  that helper edit; it was corrected and syntax-checked before the next launch.
  Its source archive and WMI dispatch log remain preserved; there is no run
  status.json because the Python interpreter exited before executing main.

All three directories/archives remain under this isolated worktree. No timing
constraints, RTL algorithms or routing strategy were altered for these retries.

### Completed TD result

SYN / PNR / HOLD_FIX / BITGEN: PASS, TD 6.2.168116 Engineer, EG4S20BG256,
top `top`. Final run exited 0 after 371.907 seconds. The only two attempts that
actually started TD were interrupted run 001 and completed run 004.

| Resource | Accepted Probe | Candidate | Delta |
|---|---:|---:|---:|
| LUT | 10,257 | 10,520 | +263 (+2.56%) |
| Registers | 6,572 | 6,566 | -6 |
| BRAM9K | 53 | 53 | 0 |
| BRAM32K | 5 | 5 | 0 |
| DSP | 8 | 8 | 0 |
| PLL | 2 | 2 | 0 |

Routed constrained-path STA: PASS (not full-interface signoff). Slow/Fast
Max/Min corners are enabled; all 40 reported path-group violation counts are 0.
Global Setup WNS +0.378 ns, Hold WNS +0.024 ns; both TNS=0. Reported Recovery
minimum +1.777 ns and Removal minimum +0.054 ns. Recovery/Removal minima refer
to the detailed listed paths (the report caps endpoints per group), not an
unbounded exhaustive path listing. Coverage is 99.93% versus baseline 99.92%.
No new timing constraints or exceptions were introduced.

Inherited check_timing counts are identical: clock-definition 4, dummy-node 3,
no-input-delay 5, no-output-delay 20, partial-input 1, internal SDRAM abnormal
input-delay 32. No-clock, invalid constraints, combinational loops and unmatched
path constraints are zero. PHY-7002 SDRAM relocation and PHY-5079 local clock
routing warnings remain present; their baseline counts are unchanged. The
conservative build parser therefore intentionally retains global STA and full
interface acceptance as NOT_VERIFIED, and HARDWARE_PASS=false. Its SIM field
describes the TD build harness only; the separately executed directed simulation
passes and exact logs are listed above.

Independent report review confirms identical PHY-7002 locations `(12,12)` and
`(164,288)` on `U3/sdram`; the PHY-5079 net is still
`sys_pll_m0/pll_inst.clkc[2] -> U3/u2_ram/SDRAM_CLK`, with one local wire.
Seven clock names/frequencies and all three constraint files are unchanged.
The final and after-hold-fix timing reports differ only in generation timestamp.

Exception qualification: FIFO hold exceptions remain 18+18 resolved paths;
reset-removal resolves 7 versus baseline 8. Physical packing aliases changed
(including `extensions/osd/font_code[3]_syn_1101` on the explicitly identified
`rst_all` source net). The constraint definitions did not change, but logical
alias correspondence was not exhaustively proven. Do not claim identical
resolved endpoint identities or full CDC/reset signoff from these reports.

### Candidate artifacts (all paths relative to the new worktree)

- Bit: `output/probe_osd_1x/delivery/probe_osd_1x_004_NEW_CANDIDATE_HARDWARE_NOT_TESTED.bit`
  (677,348 bytes), SHA256
  `674930359245616761ffff61ac93b7fadd65b153674f1b7286d8d27e0bf1b5d6`.
  Copied from the fresh final `phy_1/hx4s20_basic.bit` after hold fixing, never
  from `best_result`.
- Result: `output/probe_osd_1x/delivery/RESULT.json`.
- Reports: `output/probe_osd_1x/delivery/probe_osd_1x_004_reports.zip`, SHA256
  `be7767282ca8771fbd788badfeabdac858c35a492256d856936cb8a4331b4304`.
  Includes actual build logs, final/ignored/exception/clock/area/timing reports,
  directed regression logs and snapshots' hashes, and prior infrastructure
  failure logs. Full original run directories also remain intact.
- Source ZIP identity is recorded above; it includes restored local/IP
  dependencies and actual candidate ROM contents, without large build outputs.
- Raw final reports: `output/html_fidelity/builds/probe_osd_1x_004/runs/probe_osd_1x_004/`.

Final preservation audit rechecked accepted bit/source ZIP hashes and all 129
non-log accepted source inputs; only the intended five production inputs differ.
The frozen Probe and its materials were never written to. No JTAG/Flash/TF
operation, push or merge was performed.

Remaining risk: new physical implementation and tiny hold margin still require
real-board validation of display, controls, audio and resets. Inherited external
I/O timing coverage is not a complete electrical signoff. This delivery is
offline-validated only, **NEW_CANDIDATE / HARDWARE_NOT_TESTED**, never HARDWARE_PASS.
