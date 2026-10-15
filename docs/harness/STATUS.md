# HTML fidelity status

Updated UTC 2026-10-15T17:58:23.819162+00:00

Primary: D:\FPGA\EG4S20-Multimedia-Signage; branch codex/html-fidelity; committed HEAD15a8e2e038824436c387c9025a15d80f6f9c2dcb. Public history fb97d76 and baseline c16d3da preserved. Remote https://github.com/improve-a/EG4S20-Multimedia-Signage.git: fresh ls-remote exit0/empty; push pending.
Target HX4S20C/EG4S20BG256, top top, project/td_project/hx4s20_basic.al. TD G:\anlu\bin\td_commands_prompt.exe,6.2.1 Engineer168116. Windows primary; Mac single task temporary directory. No physical hardware/card operations.

## Current build result

First-phase full02 SYN/PNR/BITGEN PASS, exit0,564.016s, fresh702956-byte bitstream. Routed13905/19600 LUT,47/64 BRAM9K,11/16 BRAM32K,16/29 DSP. Snapshot72a155b70dee8d9a36ebbaf4f0639a141ca07aeaeee09f5bc63b66947fd556ad. Provenance output/html_fidelity/audit/full02_result.json.
TIMING does not pass: setup WNS-0.797ns/TNS-3.204ns, hold WNS+0.003ns/TNS0;99.95% reported coverage with inherited IO/clock-definition warnings unsigned. Two setup endpoints: SD response→panel loader(-0.084ns), BMP stride→row position(-0.005ns). Eight recovery endpoints: inherited video-reset→HDMI125MHz. Reset and HDMI connections match baseline; no exceptions added. Complete resource-response1clk pipeline now passes targeted tests but is later than full02.
Full01 SYN passed/PNR packing failed4918>4900mslices,273.313s. Two full flows so far; diagnostic attempts separately recorded. Completed tool time through full02:1214.408s; scene-loader probe adds15.062s. Ledger output/html_fidelity/audit/build_budget.json.

## Current integration

Working tree is newer than full02:51bit atomic config/fractional5.4s OSD, CSS motion, OSD swap/eye-alpha corrections, HFXL loading, finite renderer and plain-BMP fallback. A fresh final unified build is required; root top replay must be regenerated.
Six finite scenes use1803776words/7215104bytes; four comparison panels249856words from1843200. Total8214528bytes,174080free in8MiB. Content-derived SET_ID003adc1b is prepared; old-ID actual full transport remains immutable until completion, then all assets/defaults synchronize.
Locator tests28cases in each enabled/disabled mode. Loader tests six ready-after-write pages,7679checked words,17 malformed/transport cases and ordinary BMP mode selection. Runtime controller waits for mode resolution, then uses layer ready flags or original adaptiveBMP path. Plain comparison uses actual two fullRGB sources when packed panels are absent.
Layer core:16slot4word cache, sequential line geometry, pipelined blend and BRAM join queue. Core44894contexts/54012pixels pass with real textures/palettes,1/2/3repeats,twoRGBA,packed and plainRGB,refresh/write exclusion/backpressure. Complete renderer/full-frame throughput pending. Scene loader SYN1104LUT/noBRAM/noDSP; pixel engine standalone SYN running.

## Verification scope

Legacy regression39/39PASS on recorded snapshot;8input geometry cases,6/8catalog bounds, realBMP/HFXC and WAV/mute/EOF. Aligned bridge1,228,800pixels; aperture100096pixels; write contract2,457,600words pass. These are scoped module/contract tests; encrypted-IP full-system simulation unverified.
Real full display-chain smoke307200pixels PASS, cleanA exact, whole composite MAE1.070/255. Immutable18-frame suite completed all6normal pages(1,843,200pixels), now dual/zoom/actions. Column thirds-AA oracle1,113,600pixels/12layouts PASS. Final updated overlay/layer DUT comparisons pending; no fidelity percentage claimed.
Offline first_static.img FAT32 image+inspector passes6BMP/1WAV hashes/chains/scan. Only ordinary files used; final layered media/image pending. SyntheticLBAs are not physical card evidence.

## Ownership and next work

Root owns sharedtop/project/serialTD/Git/fourreports. Explicit agents: original visual_assets gpt-6.1-sol medium failed twice with model capacity; replacement visual_assets_recovery gpt-6-luna medium owns bounded asset/test continuation. bot_osd/page_control remain gpt-6.1-sol high. At most3 active subagents. No recursive agents.
Next: sealedassets sync, complete bridge+fallback, top/ROM integration, targeted/full regression and realDUT comparisons, final matching TD build, formalmedia/image/acceptance, commits and normal branch push. User8–10h scope remains active; first-phase BUILD_PASS is not completion.
Entries: scripts/build.py→prepare_snapshot.py→harness/windows_job.py→build.tcl; run_regression.py and html_*_verify.py. Output output/html_fidelity. Live CUA HTML file open was URL-policy blocked; no workaround. Offline deterministic exports recorded separately.
SIM scoped PASS/final pending; BUILD first-phase PASS/final pending; TIMING not passed; VISUAL first-phase clean regions exact/final pending; HARDWARE NOT_TESTED_THIS_RUN.

Latest18:12UTC: sealed003adc1b assets/defaults active and verified; Root topresource integration landed, AL newhelpers added, finalbridge/replaypending. Focusedactualpage0 transport PASS63.594s; allsix running. Oldallscene timeout124 is preserved asFAIL. Core16 SYN4619LUT;8ctx fullframeunderflow rejected. Overlay08 SYN5062LUT; exactfactor/serialROM09 running. See EVIDENCE for scopes/hashes.
