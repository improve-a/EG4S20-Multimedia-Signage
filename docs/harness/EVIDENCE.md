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

## 首帧边界、有限图层和资源优化（19:07 UTC）

- 首帧及配置：integration_review/run_20261016_023857/verification.json SHA256 694171e02cb4cc77f770f1075c1d225e1f14e316c69c5af16dc6f7aa1cf84354。原失败复现保留；REQUIRE_INITIAL_COMMIT=1 空白帧零读取，首个就绪帧与原始请求边界配置一致。顶层声明顺序修复后 SHA256 e87a626c8059e3640afc1bf2935a4bdbc16880a4b71540dab7111cf99bb7414a，integration_replay_v4.json 三项精确原件重放/幂等/未知修改拒绝均PASS。
- 新场景流式校验：verification/scene_stream_v1 保存修改前源码、diff、工具/源码哈希、PID/退出码/耗时。源 SHA256 b840a01fba871b1cfc85f7f5844817fb68dd120e75adf5c6b4acb26cbb162dc3，8831字、26个异常及普通BMP回退PASS。scene_verification/20261015T185829824020Z 全6场景/PCM复测PASS，424.875秒、1803776字、3500PCM帧，日志SHA256 fdb0d04f1fdd9708d4af3661091597741d06c74ec26fad4936e8d2d5de9a1980。
- html_scene_stream_probe_20261015_01：SYN PASS，11.250秒，1006LUT/777reg/无BRAM或DSP；snapshot 02e2c0296861d3b047dc975d5df3d8449aef9973d6ba73e064aa0d0290869245。
- html_compact_engine_probe_20261015_01：退出0但面积无效；TD把前向声明accept/dispatch_slot当作未驱动，导致删去大部分电路。audit/compact_engine_probe_v1.json 明确标记INVALID，不计为容量成果。修复声明顺序后probe02：21.281秒、3228LUT/1165reg/6×9K/2×32K/2DSP，snapshot 2833da42f271a0640f2e4724b819b0af3a710468790e7b675717090d7c58ec71。probe03直连首RGBA：21.265秒、3158LUT，相同RAM/DSP，snapshot 781b03d3f8759a1c5baf536c5b0bbbfdfa70dd377d693b1dfcbcda0b3b442314。两项无上述未驱动警告；独立探针不是整机时序/功能签核。
- html_geometry_span4_probe_20261015_01：13.390秒、1809LUT/662reg/3×32K/1DSP；snapshot ba8ae3f39f4b2b1ca51eada44d237c6be81802d2a712166cc983492d601c05ac。720场景对/年龄/行用例，921600个地址和alpha样本通过；完整候选吞吐继续验证。
- display_chain/layered_20261016_024345：实际分层smoke PASS，715.84秒，307200像素、267880请求/返回、无故障。DUT帧SHA256 a85b4bd824185b743aa73ec407b4ab172bf94a3a6d88b3b3dbe2d8661c81f792；cleanA MAE0.03570/255为整数alpha舍入，整幅MAE1.06313/255包含Bot姿态及真实音柱差异。仅该冻结cache16版本和首页，非最终全套。
- 第一阶段display_chain/run_20261016_011100：18帧5529600像素通过，负向诊断原记录FAIL；pixel_frames_evidence.json SHA256 1e4967a89fe9baf48d83a3e6f17cd510fa3defc3fef6b115b29bd2b2cc8f1b3e。diagnostic_delta_20261016_025134 短复现证明组合故障标记delta-cycle竞争，修复测试观察时机，不改RTL、不覆盖旧结果。
- 正式BMP头未使用区域统一清零，HFXC保持；audit/formal_media_transport_identity.json 六文件字节一致。card_images/unified_003adc1b_v2.img SHA256 be88671cd1e5732c5a94892fb4427b02db2ce82e03924b3f82346b474a73b1e4，inspection PASS/无issues，旧v1保留。未进行物理卡操作。

## 资源候选冻结前检查（19:34 UTC）

- 整机SYN03：18779 LUT/10866 REG/64×9K/16×32K/18DSP；187.812秒，exit0，supervisor4348/TD17040；快照86649724cebc3ec1f379905438fec48d950819efddb331bb6f83a0330c05ff7a，源包a4e1d8175d0d106063d3cec90e777b0101cbd265a1913fdbe85d7f2ed9d3a87c。独立probe时钟不用于时序结论。完整报告、初始化输入和警告见audit/top_area_probe03.json及builds/html_top_area_probe_20261015_03。
- 眼睛ROM独立SYN为4018 LUT，较原4364节省346 LUT和2 DSP，使用新增1×9K。生产六帧与原实现逐字节相同；verification.json SHA77209fee3c44855fa5d046a215657c387953f07d47a055193b0795bc884ed459。数值ROM14份均完成HEX/BIN roundtrip（audit/rom_init_eye_v1.json）。
- returnFF版本cache SHA8aa97cab14d8cd958d3d5d4b26988428cb6cbc8a873d765869006b6e458385c5；8192单元事务、home/eagle连续25/40MHz全帧通过；其他页和266周期后台写占用继续。
- BMP sector同步RAM候选独立SYN1737 LUT、3×9K/1×32K/1DSP；原生case3及scan/load/reject已过，其余兼容回归继续。最小diff/before/provenance在verification/bmp_sector_sync_v1。
- control_storage旧替身参数遗漏导致原快照编译FAIL，补齐ENABLE_HFXL声明后regression/20261015T193237292810Z PASS，未改DUT或放宽断言。
- 受保护依赖审计audit/protected_dependencies_20261015T1914.json：59项中53项与基线相同，6项为授权的最小可重放补丁。引脚、时钟/复位架构和vendor IP未更改。
- 两bank调色板只读穷举31种分组，最优UI01/04/05=1060色、UI02/03/06=1059色，各超1024；因此不采用，SET_ID仍003adc1b。总色并集1994，不以总数误判分组可行。
