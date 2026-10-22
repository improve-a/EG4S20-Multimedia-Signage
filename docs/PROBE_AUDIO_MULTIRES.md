# Probe audio / multi-resolution candidate

Status: offline implementation, directed regression and TD build complete.
Classification: **NEW_CANDIDATE_HARDWARE_NOT_TESTED**. No hardware or physical-card operation performed.

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
Final integrated regression and routed timing are recorded below.

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

## 最终离线验收 — 2026-10-22

### 提交与范围

- 成功基线 `72e5c80`；OSD/默认1×独立移植 `61efa10`；音频 `69d51af`；
  BMP及最终构建源码 `837da6f389bb749f958d2aaa2cd8fe6190bf48fb`。
- 最后报告/收集器提交不改变RTL。交付提交号见 `FINAL_MANIFEST.json`。
- 生产差异仅6个RTL与2个字体文件：`media_controls.v`、
  `ext/html_video_overlay.v`、`ext/html_osd_overlay.v`、`ext/audio_media.v`、
  `ext/bmp_scale.v`、`ext/legacy_exhibit_loader.v`，以及原字体HEX/BIN。
- 无新增独立状态机；BMP只增加既有加载状态机的一个行地址寄存步骤。
  未改冻结top、HDMI时钟/同步、SD底层、SDRAM控制/仲裁、单双图控制状态机或按键定义。

### 音频与图像

- 原创120BPM、16秒、48kHz PCM16 mono；峰值−2.00dBFS，RMS−20.92dBFS，
  比原音乐RMS提高约5.4dB；削波0，循环缝相邻样本差16LSB。
- EOF回到已发现的RIFF起点，不清FIFO、不重新扫描卡，不改变PCM输出接口。
  生产默认循环；旧EOF测试显式选择兼容模式0。
- 柱图由9个时间序列PCM峰值驱动：45×30 → **63×44**，面积2.05倍，柱宽3→5。
  静音约9帧衰减到空；不遮挡小字幕/P0–P7状态栏，无新增像素流水级或FFT。
- UI06为真实800×600 BMP；只显示源坐标x80..719、y60..539的中心640×480，
  **保留64%面积，不是整幅800×600缩小显示**。部署文件仍含全部480000像素。
- TF共11个媒体文件、9,432,364字节、18,424扇区；只有UI06和WAV替换。
  800×600行跨度2400字节；两帧SDRAM总量仍2,457,600字节，无新增帧缓存。

### 实际仿真结果

Root审查源码、原始日志及哈希后独立复测，不直接采用DS的PASS标签：

- 音频：默认/显式循环与旧EOF三模式通过；默认循环逐样本检查864,049帧，
  跨EOF缺帧0、UF/OF/error均0、最低FIFO水位520帧；静音/恢复不跳样。
- 新柱图：21帧、75,600像素，缺失/越界像素均0。
- BMP：加载19项、扫描6项；Root独立重算并比对10份实际RTL dump，
  共3,072,000像素一致；800→640→800同实例连续加载三帧通过。
- 审查修正了拒绝夹具的右数组越界和负高度符号位，只补跑9个拒绝用例及
  真实负高扫描，全部通过，无仿真ERROR/WARNING；生产RTL未因此改变。
- 原回归22/22通过：SD/SPI、BMP行填充与读取、WAV跨扇区头、FIFO、48kHz节奏、
  音频仲裁、视频/音频子系统614400像素与同步、反复加载、控制等。
- legacy控制12/12通过；P0–P7/default1×定向回归通过；既有OSD回归212480像素通过。
- 原素材双图、2×、3×、焦点锁存4例各307200像素通过；另独立检查108组几何组合，
  共120960个坐标，无源窗口或SDRAM边界越界。

仿真范围是未加密RTL子系统与显式传输/内存模型，不是完整加密HDMI/SDRAM实物仿真。
完整日志及输入哈希在交付 `regression_reports.zip`；大像素dump留在Windows原运行目录。

### TD完整构建与时序

`probe_audio_multires_001`，TD 6.2.168116 / EG4S20BG256 / top，首次构建372.203秒：
SYN、PNR、原有fix_hold、BITGEN全部通过，未改时序约束或增加例外。

| 检查 | 最差Slack(ns) | 违规 |
|---|---:|---:|
| Setup | +0.298 | 0 |
| Hold（汇总HWNS） | +0.027 | 0 |
| Recovery（详细已列路径） | +1.469 | 0 |
| Removal（详细已列路径） | +0.027 | 0 |

TD的HWNS含移除检查；详细纯hold最小值为+0.032ns。Slow/Fast、Max/Min均启用，
40项路径组违规统计均0，Setup/Hold TNS均0。详细报告每组最多128个端点，
因此Recovery/Removal数值是报告所列路径最小值，不声称无限端点枚举。

| 资源 | 成功基线 | 本候选 | 变化 |
|---|---:|---:|---:|
| LUT | 10257 | 10681 | +424 |
| 寄存器 | 6572 | 6658 | +86 |
| BRAM9K | 53 | 53 | 0 |
| BRAM32K | 5 | 5 | 0 |
| DSP | 8 | 9 | +1 |
| PLL | 2 | 2 | 0 |

新增DSP映射位于现有OSD幅度几何计算（OSD由4→5），不是新增频谱/视频缩放流水线。
所有warning类别及数量与成功Probe一致；Critical Warning仍为原PHY-7002两项和
PHY-5079一项（`U3/u2_ram/SDRAM_CLK`本地时钟线），无新增Critical Warning。
STA覆盖99.93%；继承的外部I/O/CDC覆盖限制仍在，**已约束路径通过不等于完整接口电气签核**。
27ps保持/移除余量较小，必须由用户完成冷启动、复位和实际显示器验收。

### 来源一致性与保护

129个构建输入均与启动时哈希、源ZIP及当前源码核对。TD保存项目时只自动加入UCode并
重编号CompileOrder；XML比较确认源文件顺序/设置不变，原始输入保存在源ZIP。
报告收集器曾因此停止，修复收集逻辑后原构建被正常收集，**没有重新构建或更改RTL**。
成功Probe、原素材与历史源/报告共452个文件复核，变化0；未操作FPGA、Flash或真实TF卡。

### 交付与GitHub

目录：`D:\FPGA\EG4S20-Probe-Audio-Multires\output\probe_audio_multires\delivery\probe_audio_multires_001`

- 位流：`probe_audio_multires_001_NEW_CANDIDATE_HARDWARE_NOT_TESTED.bit`
- SHA256：`5ca811192541c91fcba9b74469a0fcc1fa4c5f0a47f11163d99453c3102265af`
- `TF/`：11份部署素材、64MiB FAT32镜像、部署说明与LBA/哈希清单。
- `source_media/`：真实800×600原始BMP、512头版本及音乐/BMP分析清单。
- 源ZIP、TD报告ZIP、`regression_reports.zip`、`FINAL_MANIFEST.json`、
  `ROOT_ACCEPTANCE.json`、`SHA256SUMS.txt`、代码差异与实板验收清单。
- GitHub分支：`feature/probe-audio-multires`（已推送）；不自动合并main，未创建PR。

用户操作顺序：核对哈希并保留原卡 → 备用卡部署离线镜像 → 临时SRAM加载候选 →
验六页/默认1×/P0–P7 → 验UI06居中裁剪及单双图缩放 → 连续听45秒并测KEY3 →
反复切页、冷启动和复位。详见独立部署说明与硬件清单。
