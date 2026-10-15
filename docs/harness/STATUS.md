# HTML fidelity status

Updated UTC 2026-10-15T17:36:01.055299+00:00

Primary repository: D:\FPGA\EG4S20-Multimedia-Signage
Branch: codex/html-fidelity. Current integrated HEAD fd32c00; imported public HEAD fb97d76. Historical c16d3da and original sources preserved.
Remote: https://github.com/improve-a/EG4S20-Multimedia-Signage.git; fresh ls-remote returned empty, exit 0. Push not attempted this run.
Target: HX4S20C / EG4S20BG256, top top; project/td_project/hx4s20_basic.al.
Tool: G:\anlu\bin\td_commands_prompt.exe, TD 6.2.1 Engineer build 168116.
Build entry: scripts/build.py -> scripts/prepare_snapshot.py -> harness/windows_job.py -> harness/build.tcl.
Regression entry: scripts/run_regression.py plus targeted scripts/html_*_verify.py.

Explicit agent models: visual_assets gpt-6.1-sol medium; bot_osd and page_control gpt-6.1-sol high. No recursive agents.

Completed: verified 59 local dependencies; retained eight-slot scanner; six clean native pages, four independent comparison resources, body texture and glyph atlas; panel loader passes all real payloads and audio arbitration; six-page cache, previous/next, late ACK, 5.4 s schedule, zoom mapping and proportional caption/Bot unit tests. Top connects 5-bit page/direction/comparison metadata and shared commit event.

First full build html_full_20261015_01 (snapshot fd32c00) ended exit 2 after 273.313 s: SYN PASS, PNR packing FAIL (4918 mslices > 4900), BITGEN NOT_RUN. Gate area 17790/19600 LUT, 31/64 BRAM9K, 11/16 BRAM32K, 22/29 DSP. Gate setup -9.145 ns is not final routed timing. No BUILD_PASS. Earlier overlay-only probe05 SYN PASS: 7694 LUT, 11 BRAM32K, 18 DSP. Build ledger cumulative 553.377 s (five diagnostic probes plus one full flow).

The actual SDRAM aligned-four-word bridge correction is complete. Four 640x480 frames (1,228,800 logical pixels) pass the APUG011 contract model, including zoom and packed comparison, refresh and write exclusion. First full display-chain smoke passes 307,200 pixels; outside overlays clean-A comparison has zero pixel mismatch. Composite MAE 1.070/255 is scoped to this page and not a fidelity percentage. Six-page/dual/zoom/action sequence is running (first three pages PASS). Legacy regression completed 39/39 PASS on its recorded earlier snapshot, including eight input geometries and six/eight file catalogs.

Active next increment: exact-palette scene backgrounds plus independent RRGGBBAA cropped hero/giant/text components; source CSS frame-based transforms and alpha. Finite payload fits SDRAM with existing four comparison resources. A tagged BMP trailer needs explicit parser support because legacy BMP size validation permits only 64 KiB trailing bytes; plain BMP limits and negative tests remain unchanged. Root owns loader/parser/top integration; agents own asset packer, motion/OSD and finite renderer. Full-build area failure is driving caption lookup/OSD and cache resource optimization before another full flow.

Next: reduce measured overlay logic, implement/verify layered resources and renderer, actual DUT visual comparison, fresh complete TD flow, final regression/material package and normal branch push.

Output: output/html_fidelity. Prototype originals unchanged. Live CUA file opening blocked by URL policy; no workaround attempted. Offline deterministic exports are recorded separately, not claimed as live UI verification.

SIM: scoped module and first full-display-chain PASS; expanded suite running. SYN: PASS for first full snapshot. PNR: FAIL packing capacity. STA: gate setup negative; final routed STA unavailable. BITGEN: NOT_RUN. VISUAL: actual page0 clean background exact; overlay differences recorded, remaining frames running. HARDWARE: NOT_TESTED_THIS_RUN.

Resource repair freeze: overlay probe06 SYN PASS 21.078 s, 3621 LUT, 16 BRAM9K, 11 BRAM32K, 12 DSP versus probe05 7694 LUT/18 DSP. Actual column ROM BIN is parsed by TD. OSD all12 layouts/caret prefixes: 1,113,600 pixels equal independent original decoder with corrected thirds-AA. Total diagnostic/full tool time now650.392 s. Interval divide removed; response metadata pipeline and captured write bases pass targeted tests. Second full flow is next. HFXL locator/scene loader have28 header cases with extension both disabled/enabled, plus six ready-after-write scenes and16 malformed/transport cases; formal media remains first-version assets until real-payload and layered-renderer checks pass.
