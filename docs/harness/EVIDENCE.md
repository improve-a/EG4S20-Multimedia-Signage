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


### full03 packing failure and bounded recovery

`audit/full03_result.json` pins commit5aa8501, snapshot2f6d33865832799d25d892684db5dc582049c0cf570b5af62ab982033911871b, status/PIDs/TD identity/313.938s/exit2 and report hashes. SYN succeeded; PlacePacking required5494MSlices against4900. No final routedSTA or bitstream exists for this snapshot. The older full02 bit remains first-phase only.

`verification/20261015T194733755081Z/result.json`: streamed panel headers PASS all4panels249856words plus24 independent fixed-byte rejections and all prior transport/timeout checks. Isolated old/new SYN391LUT309REG vs328LUT118REG. `verification/locator_scene_stream_v1/verification.json`: current locator/scene fixed fields PASS6pages8831words and170 rejection cases including144singlebit faults; originals and exactdiffs retained.

Strict simultaneous reader/writer test found a real native eagle FIFO underrun with read256/write256. The identical legal continuous SPI input model passes eagle/home after read128 only; remaining page run is pending. Source rate comes from existing100MHz SPI/HIGH_SPEED_DIV=2, byteevery64systemclocks, 32bitwordevery102.4memoryclocks. Writer actualoccupied259memoryclocks. No hardwarebandwidthclaim.

OSD font and compact color candidate:3,687,348RGB/control comparisonsPASS. Spring width:1,221,490actualRTL transition checksPASS plus reachable-state closure. Data reset fill:200,004RGB/sync cycles over200resetsPASS. Isolated combinedSYN3729LUT898REG18×9K11×32K12DSP; production not replaced at this checkpoint. Formalmedia003adc1b unchanged. Optional palette candidate4c74bf6d is not a delivered asset set.


### Final candidate freeze after resume

Current source binding and protected dependency evidence: `audit/full04_freeze.json` and `audit/protected_dependencies_full04.json`. The active BG16/task32/group-return candidate passes all6native writer128 tests in `page_control/layer_final_bg16_writer128_{home_eagle,phoenix,remaining}_v1`. Eachframe307200RGBexact; legalcontinuousSPIinput and actualread/writecontrollers. BG8phoenix/dragon writerFIFO failures remain separate and are not promoted.

`regression/20261015T201246394876Z/results/regression_summary.json`: current narrowed BMP source2f308000... passes5cases,1247.062s; previous15case syncRAM suite alsoPASS. `bot_osd/final_source_proofs_v5.json` binds approvedfont8/spring/reset3RTLfiles,6byteidenticalDUTframes,fulltargetchecks and1221490actualRTLspring transitions. `audit/rom_init_font8_v1.json` proves15active/source numeric HEX/BIN roundtrips including1024×8utilityROM. Decimal andconstantforeground variants are rejectedbymeasuredarea, notclaimedproduction.

Top usesREAD_BURST_SIZE128/READ_DRAIN_CYCLES13; writerBURST_SIZE256 and legacydefaults remain. `verification/read_burst128_v1/{audit,memory_replay_v2,integration_replay_v5}.json` records exactdiffs and reproducibility. The final18displaybench uses the actual vendorFIFO/GrayCDC RTL and PCM-derived peakROM; WAVparser/player/SDaudioRTL are covered separately, not instantiated by this displaychain suite.


## 恢复后full04及资源头位宽收敛

- full04 commit8a0358f：SYN PASS/PNR FAIL_PACKING，5006>4900MSlice，17484LUT9773REG64×9K16×32K20DSP，274.156秒/exit2。源快照51ae5d994fbf57f16b0c48f157472ba7df8e37f676617ade75a55bf0bd8ece75，包3d3443b921c4410035cb15cea2df15f59d99d29bf667fc28bcb2107cedc1bac4。audit/full04_result.json保留status/area/PNR日志哈希，无新STA或BIT。
- verification/locator_compact_v1：3014组完整头部原/新对照（有效字段相同，非法字段返回载荷不作为语义）；798接受/2216拒绝。范围证明pixel_offset≤1048576、640×480×3=921600、aligned_scene≤1970176，省略的地址/长度对齐位和高位均显式检查。另6页8831字、266错误/传输/超时用例含240固定字段逐位破坏及普通BMP回退PASS。verification SHA3f47771eb364bbd10580fc914070bd6b74b7111e8927061609858333428e8b52。
- 同工具独立scene原/新综合957LUT636REG→865LUT400REG，分别9.609秒与7.531秒；不将局部综合当整机PNR结果。synthesis_comparison.json SHA26853894b186320872f66e6713088d1212f53a98302fa84bd96bed99610096e3。
- scene_verification/20261015T202112951932Z/result.json SHA530ac86c74c59cdc9d292e6d2c14fcffc79a55ffb3f7d8e6a72ef00eb328315a：压缩前冻结loader真实全6资源和PCM客户端PASS，491.437秒；不混作压缩后证据。压缩后的新run20261016T023956349464Z已启动。
- lateage25凤凰+持续写反例表明静态六页PASS不足。pending全队列排空/always-drain/read64隔离失败保留在page_control；没有放宽FIFO断言。真实vendor FIFO使用512物理字但full阈值511，新行为压力模型按511可用字校核。
- display_chain/layered_20261016_102316：8a0358f不可变18帧运行快照。public PNG函数一行误入APNG专用检查，修复后独立7×5/105RGB字节双解码往返PASS（png_roundtrip_20261016_102700）；当前VVP不受后处理修复影响，保留原异常与恢复元数据，不重新绘制DUT图像。


## 2026-10-15 19:59 PDT：等价资源压缩与新增边界复测

- 紧凑locator/scene版本真实六资源+PCM通过：scene_verification/20261016T023956349464Z，7215104字节/1803776字、14098场景扇区/96音频扇区、3500 PCM帧、36次紧急仲裁，473.093秒。11次EOF重启为测试台动作。真实HFXL接受/拒绝两项也通过：regression/20261016T024044238632Z，474.313秒；启动/config保护重测integration_review/run_20261016_104315通过。
- OSD直接5位数字字形码保留全部参数值及像素流水：589824字形索引、921837 RGB/control周期与原实现相同，native307200像素逐字节相同。direct_font_code_candidate/native_equivalence.json记录来源。SYN probe html_directfont_overlay_probe_20261015_01从3729降3690 LUT，其余898REG、18×9K、11×32K、12DSP不变，19.531秒。生产OSD SHA256 7f2e0bb01d65d805e879dc54510ac2f8c7f9ba063d97e42357203eeb7fde3361。
- BMP仅存合法尺寸/偏移的有效位，所有省略高位及planes/bitcount/compression固定字节在到达时检查。3543个完整512字节头，新旧扫描接口逐周期等价：799接受、2744拒绝，201.954秒。包含六实际HFXL头、逐位破坏、512随机合法普通BMP和49边界/符号组合；不是像素加载仿真。verification/bmp_header_compact_v1/verification.json。
- BMP独立SYN probe old1571LUT/808REG，new1436LUT/605REG；3×9K、1×32K、1DSP不变。两个probe只是综合，外部接口引脚数超封装不作布局或时序证据。分别13.656/11.391秒，TD工具SHA和源码快照见synthesis_comparison.json。生产bmp_scale.v已更新为f0a91ee9382dd048213dd38e0f2e5a4935b0cd260903a663247cab4228198c7a；实际HFXL像素/拒绝、8种自适应缩放及8目录边界的新版本回归已启动，未提前宣称通过。
- 累计48次TD尝试、4次full、3213.346秒；没有同时重型构建。
- 实际Bot/OSD六时刻样本通过：bot_action_samples/run_20261016_103251。0/5/25/65/92/100帧对应0/84/420/1092/1545.6/1680ms；加速空白期、固定背景和peak24576，仅overlay范围，不能称连续全链路动画。六帧APNG经Pillow逐帧RGB/延时往返验证，SHA c37b14be431bbe3ce830df8f453b4b62848d21bf86ea85d294ca3f01853b7385。
- 后台写物理排空候选尚未推广。真实511容量FIFO/Gray CDC已得完整RGB与有序写通过，但密集phi25有写时余量仅1；同源无writer最低266，确认需要改善准入。早期writerWait指标仅从fair_offer测量，不能当原始pending总等待；新测试分别测两项并保留旧记录。


## 2026-10-15 20:11 PDT：后台写准入修复集成

最终默认关闭兼容版本在layer_late25_actual_fifo_reserve384_compat_phoenix_v1通过：真实vendor FIFO/Gray CDC，307200 logical和307200 video像素一致，6400实际WFIFO有序字，最低90（x550/y121），最大写FIFO511，原始pending最长6664memclks，physical drain26，准入384/释放224；335.672秒。该台架40MHz memory、25MHz video、100MHz source，物理四字组、返回10周期、每312周期刷新20周期；不代表加密PHY/布局后或实板验证。兼容cache8/32各8192任务，参数0且新输入悬空对旧实现、参数1且随机pause对已测候选均逐周期相同。

Root采用最终两个SD候选和top接线，新增写准入默认关闭，生产top显式启用和384字储备。verification/physical_fairness_root_v1保存集成diff、原始基线重建、重复运行不改动和拒绝未知修改的证明；53个原样保护依赖仍逐字相同，六项授权派生差异继续由精确最小补丁重放。top SHA43e74baf569cbdfca4b75f6a84ddd44b26aaa1706564b90bb99cbf03f0201785。公开html_layer_render_verify入口已包含真实FIFO/转场时刻/储备参数，正式入口复测进行中。

Windows build.py仅修复WMI返回输出解码：原始CLIXML字节保留，避免本地中文代码页stderr在TD已经启动后触发UTF8解码异常；不修改启动命令、工具、构建步骤或系统编码。下一次完整构建将使用该真实入口验证。


### 六页局部视觉比较（真实DUT，完整套件继续运行）

原始报告display_chain/layered_20261016_102316/regional_normal6_20261016_111200.json，SHA 2a1bd4aaec878369ca65f97881712ea1c5191364f843ff0c1fd90128d2d730a0。比较范围、源参考和alpha遮罩均有哈希；不同区域允许重叠。Bot为已声明固定姿态，字幕为完整文本；音柱位于字幕遮罩之外。以下是RGB原始平均绝对差，范围0..255，不是还原百分比或PASS阈值。

| 页面 | 产品支持区 | 场景文字/数据支持区 | Bot104×100 | 眼睛区域 | 字幕源墨迹 |
| --- | ---: | ---: | ---: | ---: | ---: |
| home | 0.048 | 0.374 | 0.718 | 2.454 | 51.287 |
| eagle | 0.227 | 0.432 | 0.725 | 2.454 | 51.512 |
| phoenix | 0.234 | 0.369 | 0.717 | 2.454 | 52.476 |
| elf | 0.2 | 0.407 | 0.717 | 2.454 | 51.596 |
| dragon | 0.219 | 0.418 | 0.722 | 2.454 | 50.786 |
| eco | 0.752 | 0.277 | 0.716 | 2.454 | 51.496 |

字幕正文内容/位置已对齐，但2位覆盖率和逐字渲染的抗锯齿、子像素及字重与原浏览器存在可见差异，不宣称字形像素完全相同。六常态页共1843200像素已完成；对比/放大/自然动作帧仍在原不可变快照中继续。


### Caption coverage correction and parallel final display subsets (2026-10-16 04:00 UTC)

The caption weight difference was traced to foreground-dependent browser text rasterization, not an RTL palette or whole-pixel alignment error. The original white-on-transparent canvas mask for the same glyph/font had alpha sum66.729; source dark ink on paper gave effective linear-RGB alpha sum51.085. The original atlas reproduces all15,288 actual Phoenix say pixels exactly, while a global shift search is best at(0,0). Actual source CSS is400/12.5px, line-height18.75px, letter-spacing0.125px, ink(26,25,22), paper(237,233,226), antialiased smoothing. Fractional character origins and the second-line baseline still differ from integer ROM coordinates.

`scripts/html_caption_coverage.py` (SHA256 d3db0b141498e5875f1b1eebb8a331526ff3a7ae4e983f4ec38b17bafbad58f7) samples source dark-on-paper RGB and selects the nearest existing thirds palette. It preserves original alpha/ROM and changes only165 caption-font masks, retaining228glyphs/9120words and all12 layouts/IDs/fonts. Replay produces atlas3492deff81aae8cb50ee93e33411dda2e01471bf10593e5211c67fd2ff9065be; native binaryfe15660598e12eddd8c064d32e2ebb6a7a891ac130c1b00676e3da4cd33ba30e. Root promotion is separately recorded in `bot_osd/caption_darkpaper_candidate/promotion_applied.json`.

The isolated candidate passes six actual25MHz640x480 overlay RTL captures (1,843,200pixels,393.2s), with91,728 say-area palette pixels exactly matching the regenerated masks. All12 normal/comparison layouts and every revealed character retain cycle-identical typing/speaking/syllable/swap controls over307,244cycles. `bot_osd/caption_darkpaper_candidate/native_palette_validation.json` SHA256 aa723e0f973d675b8c05f4bcddf8860f2acd22cb58e40e6457d5d76c47cbfeac; reveal proof SHA256 345dd77e24e2637449fcc38d531283417b82cde97ae925c2cff3f3e2b51850aa. Actual full-caption rectangle MAE is6.72..8.32 and source-ink MAE37.41..41.07, improved from prior8.36..10.95 and50.79..52.48. These are raw regional differences, not fidelity percentages or pixel-perfect claims. The 1:1 source/oldDUT/candidateDUT review uses actual exported frames.

The existing display runner now supports `--subset normal012`, `normal345`, `compare_zoom`, and `natural`; default remains all18. Natural retains a fully checked, unexported static Eagle3x warmup before eight consecutive16.8ms action frames. Each process prepares private fixtures, summaries and temporary files. Four concurrent preparations/compiles pass with identical formal memory/oracle/WAV-vector hashes (`display_chain/subset_preparation/verification_parallel_v3.json`). No timing, pixel, aligned-four-beat SDRAM-model, refresh, latency or fault assertion is disabled. Layered tests enable production physical fairness/reserve384 with writer traffic explicitly idle; physicalFIFO capacity512words, usable511.

Root authorized the final engine+corrected-caption four-subset run at `display_chain/final_parallel_20261016_120043`. It is RUNNING, with exact per-child source snapshots and explicit pending-diff provenance from base38925f7; no final simulation PASS is claimed here. The older8a0358f18-frame run remains separate. Its expected original PNG postprocessing error will be preserved and recovered only from unchanged actual DUT PPMs using the retained one-line-fixed9c14b9 helper; no resimulation or redraw can relabel its source version.


## full05与关键路径修复（2026-10-15 21:06 PDT）

full05冻结38925f7，fresh SYN/PNR/BITGEN PASS，退出0，828.953秒；最终17429LUT/9202REG、64×9K/16×32K/20DSP、4733MSlices。routed setup WNS−1.967ns/TNS−256.206ns（364端点）；最小延迟WNS−2.859ns/TNS−17.669ns（24端点），包括reset removal，STA仍FAIL。coverage99.96%不等于约束签核。full05_result.json及原报告保留。位流729728字节，SHA256 c6eabeedaddbb877601b1c1c0c2d1e36e6666f6a6bd391cebed903a83d41cf57；后续源码/ROM修改不能使用它作最终证明。

最差23级存储路径的真实launch net为engine/wp，经过geometry的bank/span寻址与first-task选择后直接进入cache比较/优先级。报告OSD起点是综合共享名称。30FF弹性请求寄存分开两部分；busy计入待发缓冲，physical_busy仍只统计已发物理读。54,012混合像素、3,107稳定背压周期、254仅buffer-busy周期及flush丢弃1个尚未发送请求后重放均PASS。真实FIFO phi25继续通过307200逻辑/视频像素与6400有序写，最低显示余量90字。候选已推广，SHA dffdc73eae74d9afb4104f61abbda102112b8c20f9e9ed6efb1605151755cf94；证据page_control/late_transition_v1/task_pipeline_candidate_evidence.json与engine_pipeline_promoted.json。

wholebridge串行SYN探针50/51：4836→4678LUT，2048→2077REG，15×9K/4×32K/3DSP不变，35.484/33.453秒。这里只证明资源，不证明postroute时序。public engine两个旧位置端口TB补入新增pause输入和未使用physical输出，不删断言；历史编译失败与修复后基线/候选PASS都保留。

scene loader用局部header字段使能、对齐饱和timeout的expired寄存、body expected word寄存以及header/range判定寄存缩短SD100MHz路径。去除state范围数值比较后，TD确认自动one_hot编码。原/新接口每周期比较，六页8831字、266错误/传输/超时及普通BMP fallback，原间隔输入与每周期连续字节输入均PASS。候选ed60638a3f847fef1c624958090d9a3118a8b8bfec0363b8bc8e018cdbfd4b3e已推广；完整实际六资源+PCM复测正在进行。SYN探针52为987LUT/437REG、零BRAM/DSP，7.454秒；比此前compact scene probe增加122LUT/37REG，换取流水及one_hot，仍待整机资源/时序验证。证据verification/header_timing_v1。

累计52次TD尝试、5次完整流程、4118.690秒。没有同时运行两个重型TD。初始化caption ROM的新3492deff覆盖率由source dark-ink/paper重生，仅改变FPGA内字形ROM；正式HFXL/HFXC/WAV及SET_ID003adc1b不变，旧alpha/layout保留为生成输入。


## BMP parser时序修复集成（2026-10-15 21:14 PDT）

候选12e584e2afde569cbfd3a9461998ad9723c4e84e8afd19140c593e82ce87e954已推广：header字段使用局部使能，饱和timeout的expired位严格逐周期对齐；active显式枚举合法状态，使TD自动one_hot；已验证header边界预先寄存，PARSE仅在接受offset−1/end−1字节时开/关pixel_window，保留每字节节奏及所有头部检查。

3543完整头部与原f0a91ee逐周期等价PASS，799接受/2744拒绝，218.468秒。CASE7完整307200 golden像素、4917015拍接口等价PASS，含1字节padding、offset54、2445542 parser stalls；373.187秒。T0/1/2/7/31的timeout边界、progress同拍、SDerror/abort优先级及不reset中止后恢复PASS。7个其它scale及真实HFXL完整payload逐周期测试仍在运行，不能提前标记全回归通过；早期测试台T0晚注入/无效fixture问题保留为FAIL或INVALID_INPUT，并以修正后的独立测试为证。

SYN探针53为1321LUT/569REG，较同参数compact probe1436/605减少115LUT/36REG；3×9K/1×32K/1DSP不变，11.625秒。仅SYN，不是器件引脚可用性或postroute证明。full06将冻结此版本，与剩余仿真并行；没有修改pins、时钟、IP或全局reset。

scene实际六资源+PCM复测20261016T040044437357Z PASS，533.516秒、7215104字节/1803776字、14098场景扇区、96音频扇区、3500真实PCM帧、36紧急仲裁。EOF重启11次仍为testbench显式动作。当前startup/config边界run_20261016_120708 PASS，保留unsafe默认反例。所有15份HEX/BIN已再次逐字roundtrip，导出前后BIN完全相同（audit/rom_init_caption_darkpaper_v1.json）。

累计53次TD尝试、5次full、4130.315秒。公开历史15个commit无token/key/session内容命中；两个路径规则提示的参数字形ROM经逐版本精确再生确认是自研24字符+数值颜色表，已记录reviewed PASS而保留初筛记录；NotoSansSC仍随SIL OFL。GitHub只读ls-remote预检exit128连接重置，尚未push。

## full06与最终BMP测试（2026-10-15 21:44 PDT）

最终生产commit e26ce11c00f3b42c220cda2826a5fd8ce525b0b2，full06于21:13:39至21:24:38 PDT完成，SYN/PNR/BITGEN PASS、exit0、658.859秒。supervisor12532、TD13448。工具G:\anlu\bin\td_commands_prompt.exe，TD6.2.1 Engineer168116，SHA e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a。source.zip SHA2a55f86d6d299e063f6b2d976ca71f3ac24fc463cacb101660e76ff0d871b748，snapshot SHA45464655545a9ff88d761e6c1e9c01dab90cf69d31d40eec1d32d5b93f7a215c。audit/full06_freeze.json核对132输入、128HDL/约束、59保护依赖（53原样+6授权replay）和15BIN；8处ROM绝对路径改写逐一记录。第一次未经路径归一的断言因这些预期改写失败，核对实际diff后按prepare_snapshot原规则重新验证；没有额外HDL变更。

最终area17382LUT/9318REG/18416LE、64×9K/16×32K/20DSP；stdout末次PHY统计4727MSlices/4728LSlices，器件各4900。位流729728字节，SHA06c7154ea79f85917652e8f3d79beb6bb4ae27168b3e7d805a8c9d540d56991f。原始报告在builds/html_full_20261015_06/runs/html_full_20261015_06，机器解析audit/full06_result.json。累计54次尝试、6次full、4789.174秒，没有自动循环TD。

routed setup WNS/TNS−1.587ns，仅1端点。独立审查audit/full06_independent_page_control_review.json（SHA4b48400a387469e18bdf9e82ed073aca4e449914962c7e91c59268acbead9144）核对10项相关生产源与快照相同；同域SD+0.132ns（minperiod9.868）、mem+0.209ns（24.791）、video+2.636ns。视频clock-summary +1.869ns包含跨域，不能称同域。唯一setup实际为mem_fifo_fault→两级故障OR→fifo_fault_sync[0]，第二级才驱动display_state，state_code50是综合别名。full05已存在同状态CDC端点家族，但本次tag/panel/scene输入为集成扩展，不能一概称厂商继承或豁免。

最小延迟汇总−2.495ns/TNS−15.821ns、19端点，逐项为12hold+7reset removal；memory self hold+0.032ns，本次compositor负hold消失。mem→video−0.017ns真实launch为read_accept_mem=rd_ack_mem，落在rd_ack_sync[0]，read_session_active为别名。配置mailbox稳定载荷至ACK并延迟capture、音频Gray/meta/sync与状态同步结构已核对，但不替代CDC/hold签核。coverage99.96%，clock definition4、dummy5、no input delay5、no output20、partial input1、abnormal input32；no_clock/invalid/loops/no-path均0。保留本地路由时钟、SDRAM位置未honor等警告；未添加例外或修改reset/clock/IP，整体STA仍FAIL。独立审查未发现剩余新的geometry/cache/BMP/scene负数据路径需再改。

verification/bmp_parser_timing_v1/final_valid_suite.json记录当前12e584共17有效case全部PASS。八scale逐周期接口等价51733779拍、2457600像素；正式UI02 HFXL完整文件optin1_v3再通过10249544拍/307200像素/2290请求（1056.984秒），optin0_v3明确拒绝。共2764800 golden像素。3543头部799接受/2744拒绝、T0/1/2/7/31边界、deadline progress、SDerror/abort优先级、中止后不reset重启、0/511/513头长度及511短payload均PASS。CASE5为319×179、offset513、537padding字节、4283409parser stalls。原T0测试注入过晚和formalv2损坏fixture保留为FAIL/INVALID_INPUT，后者即使显示optin0 PASS也明确排除；只有有效v3进入结论。

## mA字幕单位修正与中断重跑

Root原生尺寸查看最终三联图发现Eagle字幕仍写“静态功耗低至5 mA”，源HTML也如此；按用户明确要求仅改为“静态电流”，数值5 mA不变，不代表另行验证该数值。原型、旧字模、原显示结果保留。caption_current_candidate生成器追加“流”ID228，“电”复用122；仅page1 caption ordinal32/33替换，42字符、坐标、换行和揭示时序不变，其余11布局不变。

Root独立核对前9120个word的字模数值与3492deff版本逐字相同，追加40word到9160（229字形），仍5×BRAM32K/14地址位。新HEX SHA e66dab4f24e304e3ab46d8ad4095d3f9bdbadabc85d899d64f1c569bca20a533，BIN c8cd33051e36e6de5c6a30b7e6b6dfd918e206459eab3fbe6d89f5d6ea01dae4。map只有两行glyph ID差异，columns仅26地址变化且低10位/ordinals不变；536568map-column一致检查PASS。OSD RTL仅GLYPH_WORDS默认9120→9160，配套html_rom_init计数同步。native/control均编译PASS，六页实际RTL和12布局控制等价继续在固定候选上运行。promotion_manifest/promotion_applied与audit/rom_init_current_wording_v1.json保存证明，全部15BIN逐字往返一致。最终需匹配full07，不沿用full06作修正版位流。

natural原子集的VVP36448及supervisor/runner在04:48UTC已不存在；原RUNNING元数据与半帧action02保留，退出原因未知，没有RTL FATAL或delta-loop证据。bounded系统事件查询无相关重启/服务记录。独立只读检查未发现engine/cache ready-valid组合回环。natural_interruption_observed.json与audit/natural_renderer_readonly_review.json记录INTERRUPTED_UNKNOWN；新候选冻结后通过既有CIM机制脱离SSH重跑natural及normal012。其它三静态子集的既有终态PASS不撤销，但源码差异必须说明。

旧8a0358f18帧RTL PASS5529600像素、4909428成对physical requests/returns、8015383同步检查、28124刷新；原PNG NameError保留exit1，postprocess_resume_20261016_123642只读取原PPM恢复后处理PASS。e26字幕版局部关键帧run_20261016_123731也PASS，均保留原源码身份，不冒充当前单位修正版本。

## 最终full07（2026-10-15 22:11 PDT）

生产commit96cd7bd90f143a0d74f4b447bfd358409dd3302f，full07于21:57:38–22:08:17 PDT fresh SYN/PNR/BITGEN PASS，exit0，638.640秒。supervisor29052、TD46820，工具SHA与full06相同。sourceZIP d576762a80ec5b082015d76e135866484deda2ccc355faccb0651541eae1134c，snapshot70ec6939b153114322ff316e6cbe554abd3589b5b9be045aa2be2e6fa137b460。Root逐项复现全部132输入，9处路径改写（8ROM+1工程位置）符合原prepare脚本；59保护依赖仍匹配，audit/full07_freeze.json SHA d3fe583463832e63d7e4df009fa2bc0a0612ffb23b1d4a795e0d00c42385f638。所有15BIN已核对，正式媒体未变。

最终17382LUT/9318REG、64×9K/16×32K/20DSP、4727MSlices；setup WNS/TNS−1.587ns/1端点，最小延迟−2.495/TNS−15.821ns/19端点，与full06数值一致但保留fresh原报告。位流729728字节，SHA f6e308a3cfbe844ffb993cc7eef6e50efc66d1c874414d07187e1517315c24ab，位于builds/html_full_20261015_07/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit。audit/full07_result.json与原始run日志对应。累计55次TD尝试、7次full、5427.814秒。

当前caption12布局控制逐周期PASS307244拍；公开native verifier是6个场景，不是6页全字幕捕获，Eagle在其中只揭示到33字符。另补实际OSD强制完整字幕307200RGB像素、507两字cell palette检查，只有183像素改变，区域外完全相同；pixels_verification.json记录这一单元范围。旧darkpaper六页验证确实使用独立custom TB逐页等待400帧并断言typed_count==total_chars，已核对不可变TB/输入SHA，无需撤销旧六页证明。

生成器新增两行校验拒绝把旧white-mask输入用于追加字形；正确darkpaper输入精确再生同e66/c8cd/mapab3c，错误输入在启动Chrome前退出1。该生成器改进不改变full07任何RTL/ROM输入，guarded_replay/guarded_promotion.json保存证明。


## full07独立最终时序复核（2026-10-15 22:15 PDT）

`audit/full07_independent_page_control_review.json`，SHA256 `09b68bbf8f06d0a7725203451808119748a548ab4c660bc621d1e1aac7534d1d`。与full06完整timing报告仅生成时间和约束路径两行不同，其他字符一致；负路径、cell延时及全部组统计可延续既有分类。full07报告SHA256为`a37471915781d64d344572bde1b8d7b1fba41f09643b52958f85e93cfc37cc08`，报告和新位流mtime均在本次fresh运行窗口，未复用旧报告。132快照文件归一化比较仅6项字幕内容/深度变化，pipeline、renderer、握手、约束和reset不变。59保护依赖为53项原基线相同与6项已核对自研replay，不能全部称厂商原件。仍为STA_FAIL，1 setup、12 hold、7 reset removal，HW_NOT_VERIFIED。


## 最终静态画面完成（2026-10-15 22:33 PDT）

normal012重跑`layered_normal012_20261016_125647` DISPLAY_CHAIN_SIM_PASS，verification SHA256 `624185e8d2e41114c6c15e223eeaea14b983ec286e7bc818b4b123173465b3c6`，921600实际像素、873032成对请求/返回、1715383同步检查、6188刷新；当前猎鹰actualPPM SHA256 `bf733e02d87a1639c803e9275e33dd636bb014dc5296032169e88fae16235a7e`。

compare_zoom重跑`layered_compare_zoom_20261016_130114` DISPLAY_CHAIN_SIM_PASS，verification SHA256 `11457dec90b8fc84d8c0a1b05ad32c2deb95af1d25bf117c0c349f81b05f068b`。当前修正HTML参考只在两个字符格内改变246像素，其他像素相同；原参考与旧metrics不覆盖。最终猎鹰及2×/3×字幕矩形MAE6.74195、源墨迹37.38374；放大产品transformed-alpha MAE2.24888/3.50867，场景文字1.69381/1.74268。指标为0..255原始RGB误差，不是还原百分比。静态总10帧中7帧来自当前源重跑，normal345三帧沿用原完整PASS及明确的未变布局证明。

Root以1:1查看当前Eagle和2×/3×三联图及字幕条，确认文案与固定OSD位置，记录最近邻块状边缘、字幕字重等已知差异。核查文件为`audit/root_visual_review_final.json`，natural仍在运行，尚不把局部预览当连续整链PASS。


## 最终连续动作显示链完成（2026-10-15 23:01 PDT）

`display_chain/layered_natural_20261016_125647/verification.json` DISPLAY_CHAIN_SIM_PASS，SHA256 `72b656a1a78821c06c0863cf7baf32d03034e254f00b7958900bc8a20db20057`。VVP36392退出0、仿真3842.517秒，runner含后处理3845.776秒。9检查帧含不导出的静态预热1帧及自然动作8帧；2764800实际像素计数、4235383同步检查、2622476成对读请求/响应、14630刷新，5..10周期延迟覆盖，欠流粘滞位与非请求返回故障注入检测PASS。

action00首像素35016181000ps，action07首像素152616181000ps、末像素167969741000ps；首像素严格相隔16800000000ps，无跳帧。动作8帧相对时刻0..117.6ms、预览循环134.4ms。实际场景motion已释放，由真实页面提交推进；动态检查同步、完整像素数、knownRGB、提交/视线/倾斜/字幕语义及故障状态，不使用静态或浏览器动画RGB oracle。旧/新页区域选择和CSS分层运动参数并用，不宣称浏览器动画逐像素一致。

静态10帧汇总`display_chain/final_current_20261016_125646/static_verification.json` SHA256 `7c4f6b8cd1cc35b35ae8b88ea6e225f150163252fa34dc74df6155ceced37e4f`。范围为底图logical golden+遮罩外finalRGB断言，以及B/C独立测试/原型局部差分；normal345旧捕获及未变布局证明单独标识。显示链使用真实511可用容量FIFO、模型SDRAM、WAV-derived峰值刺激，后台writer竞争和真实音频播放由独立套件覆盖。


## 最终显示交付冻结

`display_chain/final_current_20261016_125646/final_verification.json` SHA256 `fad96d250e941563a2944069db32e0ea2a635257609fe99aef670d3947490e0c`；`bot_osd/final_source_proofs_v6.json` SHA256 `6b5c013070acf2873dc03be6668aea0057dd59e25c8f2c256e261407ee06d6be`。18张实际导出代表帧，含warmup共19检查帧/5836800像素计数/9801532同步；是有来源边界的多个子集汇总，normal345沿用原捕获及精确不变布局证明，不是一次完整整机仿真。

连续8帧APNG SHA256 `27e476556c7eb80dbd615cdef5f3a818504e54b43cea60a644b58675d4e1ef8a`，逐帧解码RGB与原DUT PPM一致。Root查看起末帧：早期转场仍可见大部分旧Eagle底图，新Phoenix页头/OSD已随页提交更新，眼睛/身体开始反应及字幕开始揭示；不能把0..117.6ms片段当成完成整段入场的证明。稀疏0..1680ms overlay样本仍单独说明。最终132项硬件输入再次逐项匹配full07冻结源，无差异。


## 正常Git推送实际结果（2026-10-15 23:06 PDT）

在已核实origin和codex/html-fidelity上执行`git push -u origin codex/html-fidelity`，尝试HEAD `7c6fc49d235bbdbff70e83dfa3e577476140256e`，PID45752，2026-10-16T06:06:14.759363Z至06:06:35.916104Z，21.156秒、退出128。实际错误为无法连接github.com:443（约21057ms），未到成功推送状态。`audit/git_push_final.json`保留命令/源/时间/退出码，stderr SHA256 `f30d905c79b173cf9f905359445109ee61e550fa1567d292d513100aa050dfa2`。无强推/main合并/网络、SSH或认证配置改动。按用户网络失败不阻塞离线交付的要求保留本地提交；此后仅记录结果的文档提交不冒充已推送。
