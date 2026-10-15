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

## Second full flow checkpoint

html_full_20261015_02 at15a8e2e: SYN/PNR/BITGEN PASS, exit0,564.016s. Routed area13905/19600 LUT,47/64 BRAM9K,11/16 BRAM32K,16/29 DSP. Final timing setup WNS-0.797ns/TNS-3.204ns, hold WNS+0.003ns/TNS0; reported coverage99.95% does not resolve existing input/output constraints. The ten negative endpoints comprise two setup paths (SD response to panel loader-0.084ns; BMP row stride to row position-0.005ns) and eight video-reset to125MHz HDMI recovery paths. No clock/reset/IP or timing exception changes made. Resource response registration is being extended to address the measured new path; inherited reset recovery is recorded, not waived. BUILD_PASS applies to this immutable first-phase snapshot only, TIMING does not pass. Hashes and paths: output/html_fidelity/audit/full02_result.json. Completed tool time1214.408s across2full flows and8diagnostic attempts. Later layers/fraction/motion are not in this bitstream.

## Layer resource and area checkpoint

Scene-loader probe01 SYN PASS15.062s,1104LUT,0BRAM/0DSP. Core32 probe01 SYN PASS59.109s,6365LUT/2148reg/2BRAM9K/2BRAM32K/2DSP; actual DP32 join consumes two32K blocks. Core16 probe01 SYN PASS41.172s,4619LUT/1561reg/sameRAM/DSP. Exact real-payload core comparison passes44894contexts/54012logicalpixels. Eight-context fullframe configuration actually underflows atrow1,x306 and is rejected; do not cite its smaller unit run as real-video success. Alternative16context/8cache/8BG fullframe test in progress.

Updated Bot/OSD probe07 measured6261LUT (+2640 vsold3621), motivating measured resource repair. Probe08 after sharing one eye coverage and existing blend multipliers:5062LUT,16BRAM9K/11BRAM32K/11DSP; corrected crop remains byte-identical to the preoptimization corrected model. Probe09 adds exact factored eye radius and serial palette ROM; in progress. New OSD swap has32frame numeric/pixel checks,212480pixels per selected crop; swap affects card text only, notplate/Bot/audio. Eye correction improves matched source eyeROI MAE11.05→2.45/255 and whole104x100 region1.652→0.718/255; remaining coverage/texture quantization is disclosed.

SET_ID003adc1b is now active in sixpayloadheaderw13s, sixlocatorBMPs, schema/manifest/headerROM and regenerated layout.vh. AtlasSHA256 da35f21eb4b91b467c8f2f39b51d1a8a45b88ea8b08b1be89920f4d5c96865c3. A stale layout.vh was caught and regenerated using the manifest-based authoring tool; do not use the unregenerated package. Allhex/binary ROM siblings are present. Rootdefault and synthetic loaderTB now use003adc1b; scene_loader_sealed_v1 passes7679checkedwords/17negativecases/plainfallback.

Old actual allscene transfer scene_verification/20261015T174053058714Z timedout1200.094s/exit124; no pass claimed. Focused new-ID page0 with whole response1clk pipeline passes275200words,2152scene sectors,16audio sectors,534PCMframes,63.594s at scene_verification/20261015T180705601006Z. Allsix run20261015T180953784326Z uses immutable snapshot,progress/cyclewatchdog,3600s wall ceiling. Only genuine allword completion can pass it.

Rootworkingtop now connects scene-first/panel-second ownership, linear resource writes, mode probe and ordinaryBMP fallback, plus2FF mode synchronization to memory clock. Newbridge module integration is pending. AL lists completed newloaders/helpermodules; replay stillpending and no freshfullbuild represents this workingtree. Four rootreports remain the only narrative reports.

## Sealed media and corrected overlay checkpoint

All-six actual scene transport20261015T180953784326Z passes1803776words/7215104bytes,14098scene sectors and7370893cycles. Actual audio client consumes3500PCMframes,11EOF restarts,96audiosectors and36urgent grants. Supervisor41904/vvp44888,exit0,435.125s; response pipeline and delayed write ACK/finish included. This is a behavioral transport model, not physical SD timing or encrypted-IP full-system simulation. Earlier1200s timeout remains failed evidence.

Overlay09 SYN PASS33.172s:4364LUT,17BRAM9K,11BRAM32K,13DSP. Exact radius factorization and serial OSD palette preserve corrected pixels; latest event-age fix is subsequently tested at bot_osd/verify_20261016_021659 (six307200pixel frames,2318100sync checks). overlay_target/run_20261016_021958 passes1113600glyph pixels/12layouts,720event-timeline checks, exhaustive blend/radius math,48zoom configurations, intervalfraction and first-activepixel palette readiness. Full proof/source allowlist: bot_osd/final_source_proofs.json SHA353b2e4bebd858e45012c818e318e5bb3205c6667d9585571db673cded94b3aa. Body texture uses affine deformation, not an exact animated28-point SVG outline; quantized far-eye/speaking/blink details and fixed-point motion remain disclosed differences.

Wholebridge probe01 SYN PASS71.36s but9360LUT/11BRAM9K/6BRAM32K makes the aggregate design too large. Geometry3884LUT and16contextengine dominate. Static wholebridge307200pixels match the real scene source-over oracle at layer_whole_unit_v2; this explicitly holds motion atsettledage127 and does not prove natural animation or real25/40MHz delivery. Eightcontext and16context/8cache configurations underflowed in real-cadence tests and are rejected. Optimization continues before fullflow.

Formal output/html_fidelity/media is now a single six-HFXL-BMP/one-WAV pack. scripts/html_fidelity_unified_pack.py staged, verified and activated it twice; native921600-byte BGR data and four HFXC payloads are unchanged. Existing WAV SHA c0671b03 is preserved (full hash in manifest). Root generated ordinary64MiB card_images/unified_003adc1b.img, SHA7cb3db222979a0daab3f62ce8ea667c5ef52183967b7760ebec529d7e5067175. Inspector PASS checks all file hashes, twoFAT chains, contiguity, sixphysicalheader scan/order and oneWAV; issues[]. No physical card/device opened. First_static image and manifest remain immutable. Descriptor ROM16 export has1536words and exactlow/high reconstruction; binarySHA0bc3896d9036ee0923dc687dc96999d1518cc59dbc877f8d5817945a827d4acc.
