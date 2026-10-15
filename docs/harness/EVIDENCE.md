# HTML fidelity evidence

StartedUTC 2026-10-15T16:14:36.592861+00:00. Windows inventory found frozen build mirror and bare relay only. Imported full public-source Gitbundle into new worktree, verifiedorigin, created codex/html-fidelity.59dependencies match hashes. No hardware/card accessed.

Video25MHz and800x525 gives16.8ms/frame=59.5238095Hz.5400ms requires fractional-frame accumulation; old loader addedload/transitionlatency.

Evidence output/html_fidelity. EachTD run retains source_manifest/status/stages/logs/resource/timing/bitstreamhashes.

## Completed targeted checks

- Assets: 13 checks PASS; formal media: 6 checks PASS. Four independent HFXC panel payloads preserve standard BMP pixel data. SDRAM use 2,093,056 of 2,097,152 words, leaving 4,096 words.
- Panel loader: verification/20261015T162949479611Z/result.json; PID 45564, exit 0, 54.953 s. All 249,856 payload words checked, 1,956 panel/header sectors with real audio arbitration, delayed storage and write ACKs, malformed headers and timeout cases.
- Read tags: same run, PID 47476, exit 0, 0.125 s; 1,388 ordered requests/responses, packed halves, queue wrap/full/underflow/overflow. This tests tags only, not SDRAM address legality.
- Bot/OSD: bot_osd/verify_20261016_002121/verification.json, exit 0, 402.78 s; six 640x480 DUT frames and 2,318,100 pipeline checks. Updated dark audio bars/contrast numeric rendering verified separately. Actual full-display-chain test remains pending.
- Controller/viewport: page_control/previous_v1 and earlier scoped runs; six cached pages, late-ready/ACK, previous-key chord, 5.4 s schedule, 8-slot legacy boundary, 7,680,000 geometry address checks and explicit reverse aperture. Previous ideal memory bridge PASS is not hardware validity; see correction below.

## Primary reference check and memory correction

2026 contest title and five bonus directions checked in [Anlogic contest document](https://drive.google.com/file/d/1lV1hRE_DFhZdloVfqjA9CYWO-Yy8NBdE/view). No additional processor or PC runtime renderer is introduced.

[APUG011 v1.2 SDRAM guide](https://drive.google.com/file/d/1FdMvGjBKgTTtH4E3rBS7LOF5ucA1xVm5/view), sections 2.3.4, 2.4 and 7, specifies aligned groups of four 32-bit words; addresses within each group advance internally. The initial pixel-address bridge violated this for packed/zoom samples. It is being replaced before the first full build, and the simulation memory model now must enforce the official burst contract. No encrypted IP or inherited clocks are changed.

## First integrated flow and display evidence

The aligned four-word cache replaces the invalid arbitrary-address prototype. page_control/group_full_v2 checks 1,228,800 exact logical pixels through four-beat physical transactions; group_aperture_v3 checks 100,096 directional-aperture pixels, drain/flush and malformed responses. No encrypted IP changes.

Full flow html_full_20261015_01, HEAD fd32c00: supervisor 37808, TD 47036, exit 2, 273.313 s. Snapshot SHA256 0699903983aeeabcd2f8433473b2853415e4e1696a4761b97410b974f2178f71. Synthesis succeeds; PNR fails with 4918 mslices exceeding 4900. Gate area 17790 LUT, 31 BRAM9K, 11 BRAM32K, 22 DSP. No bitstream or routed timing success is claimed. Caption map accounts for 2378 LUT/ripple units and is an optimization target. All five earlier diagnostics and full-flow logs remain under builds; total tool time 553.377 s.

Display-chain run_20261016_005800 passes real VGA timing/FIFO and aligned four-beat SDRAM model, 307,200 pixels, 554.14 s. Outside OSD/Bot, reference clean-A pixels match exactly. Whole composite MAE 1.070/255 includes glyph antialiasing/pose and real-audio differences. This is not full encrypted-IP or hardware validation. Expanded 18-frame suite is running. Caption coverage decoder was found to use quarters while exported two-bit alpha represents thirds; next increment will correct this with pixel evidence.

## Measured resource repair

Overlay probe06: SYN PASS,21.078s,3621 LUT/16 BRAM9K/11 BRAM32K/12 DSP; all three binary ROM sources explicitly parsed in TD stdout. Compared with overlay probe05 this saves4073 LUT and6 DSP. OSD column_equivalence_v1 checks1,148,610 stream events and1,113,600 pixels across12 layouts and reveal/caret states against the old decoder with independently corrected thirds coverage. Full-frame targeted verify_20261016_012929 changes only1192 glyph-band pixels as expected; geometry and synchronization are unchanged.

Cache32 diagnostic SYN PASS67.0s:2669 LUT/2 BRAM9K. Cache16/tag8 diagnostic SYN PASS8.937s:1445 LUT/2 BRAM9K. Both8192-task APUG-unit traces PASS; these do not establish layered full-frame bandwidth.

Interval timing fix tests260 increments/decrements and existing control cases. write_contract_v1 validates2,457,600 linear/flipped words, allfour base choices and asynchronous request phases. BMP response pipeline tests data/valid/end/error alignment. panel loader now waits for write ACK release before payload, with all249856 real-resource words/arbitration/error tests rechecked at verification/20261015T173141474698Z.

Legacy regression39/39 PASS: regression/20261015T164454886669Z/results/regression_summary.json. Includes eight307200-pixel input geometry cases,6/8catalog bounds, realHFXC file load, and actualWAV volume/mute/EOF. Its plan records the earlier source snapshot; this is not claimed as later layered-system verification.

HFXL optional locator headers: verification/hfxl_headers_v1_0 and_1 each28cases PASS. scene_loader_v2: six pages become ready only after physical-write completion;7679words checked including16 malformed/transport/timeout/overflow cases. integration_replay_v2.json reconstructs allthree ignored top/writer/BMPwrapper deltas from hash-verified originals and checks idempotence/external-edit rejection.
