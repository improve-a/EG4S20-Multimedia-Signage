# 音频优化：保留 FIFO 的 EOF 循环、16 秒原创循环音乐、放大的 PCM 柱状图

本轮工作基于 `61efa10`（Root 已移植审核过的 Probe OSD / native 1x）。状态标记：
**OFFLINE_RTL_SIM_ONLY**、**HARDWARE_NOT_TESTED**、**BUILD_NOT_RUN**（未做 SYN/PNR/STA/BITGEN）。
所有数值来自 Windows Icarus 12.0 仿真与本机 Python 分析，日志路径见第 7 节。

## 1. 摘要

1. **现音频链路**：`audio_media` 用物理扇区扫描找 RIFF/WAVE（无 FAT），`wav_stream_parser` 出 PCM16，
   `audio_async_fifo`（默认 2048 帧）+ `audio_pcm_player`（25 MHz 相位累加器，520/521 clocks/样本）
   产生 48 kHz PCM24，`wave_peak` 是每 64 个输出样本的最大绝对值。OSD 的“柱状图”是 9 个
   **时间序列 PCM 峰值**，不是 FFT 频谱。
2. **旧 EOF 行为**：`parser_done` → `source_eof` → `FINISHED` → 播放器 `drained` → `eof` →
   顶部 `wav_restart` 上升沿 → `restart` 清 FIFO、从 `SCAN_START_SECTOR` 重新逐扇区扫描。
   原基线镜像 WAV 在 LBA16491，仅扫描下界就是 6.04 s（按 36613 SD100 clocks/CMD17），
   **两次重启不能当无缝循环**。
3. **改动**：`audio_media` 增加 `LOOP_PLAY`（**默认 1**，生产即循环）。EOF 时把
   `current_sector` 指回 `candidate`（RIFF 头扇区）并重新 `parser_start`，**不清 FIFO、不清
   play_ready/prefill、不重扫**，只重读一个头扇区，PCM 流不中断。`LOOP_PLAY=0` 完整保留旧行为。
   冻结 `top_tf_hdmi_audio.v` **未修改**，其 `wav_restart` 路径原样保留（循环模式下 `eof` 不再产生，
   该路径不再触发，但语义不变）。
4. **新素材**：16.000 s、48 kHz、PCM16 **mono**、1536044 字节、3001 扇区，峰值 **-2.0 dBFS**、
   RMS **-20.9 dBFS**、无削波、循环缝一阶差 16 LSB（-66.2 dBFS），环形混音合成使波形严格周期。
5. **OSD 柱图**：区域 45×30 → **63×44 像素（2.05 倍）**，柱宽 3 → 5 px，柱高上限 29 → 44 px，
   由 `audio_peak[15:10]` 驱动（量化步长仍为1024，额外位用于表示满量程32），静音/静音键时最终**不画任何像素**。

## 2. 现音频链路与峰值来源（代码事实）

| 环节 | 位置 | 事实 |
|---|---|---|
| 选择/扫描 | `rtl/ext/audio_media.v` | 从 `SCAN_START_SECTOR=0` 逐扇区读 512 B，找 RIFF/WAVE；`SCAN_MAX_SECTOR=131071`；无 FAT，文件必须连续且起于扇区边界 |
| 解析 | `rtl/ext/wav_stream_parser.v` | PCM、16 bit、48000 Hz、1/2 声道，校验 byte_rate/block_align；头必须在文件前 4096 B；`data` 长度决定 `parser_done` |
| 缓冲 | `rtl/ext/audio_async_fifo.v` | 2048×32 bit 帧（`FIFO_ADDRESS_BITS=11`），预填 `PREFILL_FRAMES=512`（10.7 ms） |
| 播放 | `rtl/ext/audio_pcm_player.v` | `phase+SAMPLE_HZ>=CLK_HZ` → 每 520/521 个 25 MHz 时钟一个样本；`gain=min(volume,8)`，`value=raw*gain>>>3`（音量 8 = 原始 PCM）；mute 仍消耗帧、pause 不消耗 |
| 峰值 | 同上 | `wave_peak` = 每 64 个输出样本的最大 `|sample|`（mute/欠载时为 0），即 750 点/秒 |
| 复用 | `rtl/top_tf_hdmi_audio.v` | `visual_peak = wav_selected ? wav_peak : tone_abs[23:8]`；`audio_output_mux` 在 `wav_status∈{2,3,5}` 后选 WAV |
| OSD | `rtl/ext/html_osd_overlay.v` | 每个 VS 上升沿：`audio_history[0] = (mute||paused) ? 0 : min(32, audio_peak>>10)`，`history[8:1]` 依次移位；柱高只用这 9 个时间样本 |

旧柱图（改动前）：9 柱，`x455..499`（45 px），间距 5 px、柱宽 3 px，`y399..428`，柱高 ≤29 px、中心 y=414，
区域 1350 px²，`audio_peak[14:10]`（5 bit，满量程被钳到 29）。

## 3. 旧 EOF 重启的实际代价

- `top`：`wav_restart = wav_eof_sync[1] && !wav_eof_sync[2]`，即 `eof` 上升沿（真 `drained`）。
- `restart` 在 `audio_media` 中：`clear_count<=32`（`fifo_clear` 清两侧指针）、`state<=IDLE`、
  `candidate/current_sector<=SCAN_START_SECTOR`、`parser_start` 重来 → 再从 LBA0 逐扇区找 RIFF。
- 因此每次“循环”= 静音约 6 s（LBA16491 的扫描下界）+ 真实卡响应/仲裁 + 512 帧重新预填。
  这既不是无缝，也不是“同一段 PCM 连续读取”。

## 4. 改动：保留 FIFO 的 EOF 循环（`rtl/ext/audio_media.v`）

```verilog
parameter [31:0] SCAN_START_SECTOR=0,SCAN_MAX_SECTOR=131071,
parameter LOOP_PLAY=1                       // 生产默认；0 = 旧行为

PLAY_EVAL:begin
 ...
 else if(parser_done&&LOOP_PLAY!=0)begin
  current_sector<=candidate;parser_start<=1;state<=PLAY_HOLD;   // 保留 FIFO/play_ready/prefill
 end
 else if(parser_done)begin source_eof<=1;play_ready<=1;state<=FINISHED;end
```

- `candidate` 就是 RIFF 头所在扇区：`SCAN_EVAL` 命中 `header_valid` 时执行
  `current_sector<=candidate`，其后整个播放期间 `candidate` 不再被改写（`SCAN_EVAL` 只在扫描期进入，
  `restart/!enable/fifo_clear` 会把它复位成 `SCAN_START_SECTOR`）。所以回绕不需要额外 32 bit 寄存器。
- `PLAY_HOLD` 只在 `fifo_level<=2048-256=1792` 时才发下一个扇区请求，即空闲 ≥256 帧；
  单声道一整个扇区最多 256 帧（512 B），而回绕扇区只推入“头部之后”的 PCM（<256 帧），所以不会溢出。
  同时此时 FIFO 里仍有上千帧（实测全程最低水位 520 帧 ≈10.8 ms），重读一个头扇区远小于该余量。
- 头部字节会被 `wav_stream_parser` 重新解析并丢弃（`data_offset` 之前的字节不出 PCM），
  所以样本序列从文件第一个 PCM 样本重新开始，**不重复、不丢样、不插入静音**（第 7 节实测 gaps=0）。
- `LOOP_PLAY=0` 时行为、状态码（`status=5`、`eof`）与改动前逐位一致，旧的 EOF 测试显式传该参数。
- 冻结 top 不改：默认参数即为循环；`restart` 输入语义完全不变（真 `eof` 上升沿仍会清 FIFO 重扫），
  只是循环模式下不再产生 `eof`。若需要恢复旧行为，唯一动作是在实例上写 `.LOOP_PLAY(0)`。

## 5. 原创循环素材

生成器 `scripts/probe_audio_wav.py`（纯标准库，确定性；Mac 与 Windows 生成的 SHA256 相同）：

- 格式：RIFF/WAVE，`fmt ` 16 B（PCM=1，1 声道，48000 Hz，byte_rate 96000，block_align 2，16 bit），
  `data` 1536000 B = 768000 样本 = **16.000 s**，文件 1536044 B，占 3001 个 512 B 扇区。
  SHA256 `fb05ffc032a2d8b7b0269b805ca56c75830e482fba21455e044fd6b9ee4a9b16`。
- 音乐：A 小调 Am–F–C–G，120 BPM，8 小节（32 拍）循环；8 分音符 bass riff、16 分音符 arpeggio、
  跨小节 pad、四拍 kick + 8 分音符 hat + 每 4 小节 clap、后半段 lead motif。
- 循环实现：所有音符写入**环形缓冲**（尾音绕回开头），因此信号严格周期；DC 用 25 Hz 一阶高通两遍去掉。
- 电平：峰值 **-2.00 dBFS**（26028 LSB，留约 2 dB 余量），RMS **-20.9 dBFS**，crest **18.9 dB**，
  DC 0.005 LSB，削波样本 **0**，带宽分布 low/mid/high = -23.1 / -26.1 / -37.2 dB。
- 循环缝实测（第 7 节同一份 `wav_report.json`）：样本 `…329, 347 | 363, 443…`，
  缝处一阶差 **16 LSB = -66.2 dBFS**（内部 p99.9 = 6862，最大 12517），二阶差 **2**（内部 p99.9 = 12166），
  缝两侧 100 ms RMS 为 -15.25 dBFS（下拍）vs 全局 -20.92 dBFS，没有破音或静音坑。
- 与原 80 s 素材对比见第 6 节表格。

## 6. 放大的 PCM 柱状图（`rtl/ext/html_osd_overlay.v`，仅柱图段）

| 项目 | 改动前 | 改动后 |
|---|---|---|
| 区域 | x455..499 × y399..428（45×30=1350 px²） | x445..507 × y388..431（63×44=**2772 px²，2.05×**） |
| 柱数/间距/宽 | 9 / 5 / 3 px | 9 / 7 / **5 px** |
| 柱高上限 | 29 px | **44 px**（1.52×） |
| 中心 | y=414 | y=410 |
| 量化 | `audio_peak[14:10]`，≥32768 钳 29 | `audio_peak[15:10]`（6 bit，≥32768 钳 32） |
| 高度公式 | 1 px/单位（半高对称） | `h = (hist*3)>>1`，钳 44（≈1.5 px/单位） |

映射表（整段窗口峰值 → 柱高）：peak 1023→0（不画）、1024→1、4096→6、8192→12、16384→24、
26028（本素材峰值）→37、32768→44。静音键/暂停时 `history[0]=0`，9 帧（约 150 ms）内衰减到全空，
完全静音后不画任何像素；纯静音 PCM 同样不画（`bar_height!=0` 条件）。

位置选择：卡片右侧面板为 x444..509、y388..455，其中 x468..486 × y433..453 已有 18×20 小字幕，
新柱图底边止于 y431，**不遮挡任何既有文字/图标**（第 7.2 节逐像素确认 ROI 边带无柱色像素）。
仍为时间序列峰值，不是 FFT；没有新 framebuffer、没有像素级动画、没有额外 ROM。

## 6.1 与原 80 s 素材的对比（同一分析器）

| 指标 | 原 `07_MUSIC.WAV`（只读） | 本轮新素材 |
|---|---|---|
| 时长 / 样本 | 80.000 s / 3840000 | **16.000 s** / 768000 |
| 文件 / 数据 | 7680044 B / 7680000 B | 1536044 B / 1536000 B |
| 格式 | 48 kHz PCM16 mono | 48 kHz PCM16 mono |
| 峰值 | **-14.24 dBFS**（6357） | **-2.00 dBFS**（26028） |
| RMS | -26.35 dBFS | -20.92 dBFS（+5.4 dB） |
| Crest | 12.10 dB | 18.92 dB（节奏更起伏） |
| DC / 削波 | 0.0 / 0 | 0.005 / 0 |
| 三频段 low/mid/high | -28.6 / -31.3 / -47.8 dB | -23.1 / -26.1 / -37.2 dB |
| 首尾 | 两端为数字静音（缝两侧 100 ms RMS -69.6 dBFS），一次性淡入淡出 | 缝两侧 100 ms RMS -15.25 dBFS，严格周期 |
| 循环表现 | 首尾静音、句尾收束，不利于连续展陈 | 环形混音，缝一阶差 16 LSB |

原素材峰值只有 -14.2 dBFS，旧柱图（`peak>>10`）因此长期只到 6/29 左右的高度；
新素材峰值 -2 dBFS 使放大后的柱图能用到 37/44 高度，动态也更明显。

## 7. 验证（Windows Icarus 12.0）

`scripts/probe_audio_sim.py` 把本轮自己的 RTL/测试/ROM 资产生成快照（逐个记录 SHA256），编译并运行：
`LOOP_PLAY` 生产默认（不传参数）、显式 1、旧行为 0 三份 `tests/probe_audio_loop_tb.v`，
以及 `tests/probe_audio_osd_tb.v`；OSD 结果由脚本内独立像素模型逐点比对。

运行目录（Windows）：`D:\FPGA\EG4S20-Probe-Audio-Multires\output\probe_audio_multires\audio_worker\runs\r8`；
本机只读副本：`output/probe_audio_multires/evidence/runs/r8/`（`verification.json`、`sim_*.log`、
`compile_*.log`、`osd_frame0_ascii.txt`、`osd_preview.ppm`、`osd_peaks.hex`、`osd_mute.hex`）。

### 7.1 循环 / 旧行为（同一份真实 WAV 数据，三份编译）

| 运行 | 参数 | 结果 |
|---|---|---|
| `loop_default` | **不传 `LOOP_PLAY`**（生产默认 1，日志 `loop_mode=2`） | `frames=864049 loops=1 gaps=0 fifo_min=520 fifo_max=2016 peak=0..26028 requests=3449 play_requests=3384 rescan=0` |
| `loop_explicit` | `LOOP_PLAY=1` | 与上完全相同（`gaps=0 rescan=0`） |
| `legacy` | `LOOP_PLAY=0` + 顶部同款 `eof` 上升沿 `restart` | `stall_frames=2198`（**45.79 ms**，LBA64）、`rescan_sectors=64`、`eof_pulses`>0、随后 PCM 严格从文件首样本恢复 |

- 864049 个 48 kHz 帧逐个与 WAV 字节比对（LEFT/RIGHT 完全一致），跨越 1 次回绕，
  `gaps=0` 表示没有任何一个 48 kHz 时隙因 FIFO 空而被迫输出静音；`underflow/overflow/error` 均为 0。
- 回绕后 `post_play_below_lba=0`：播放开始后**没有任何低于文件起始 LBA 的请求**，即没有重扫。
- `fifo_min=520` 帧（10.8 ms）远高于回绕所需的一个头扇区（≤256 帧），说明回绕不会掏空 FIFO。
- 旧路径实测停顿 2198 帧/64 个扫描扇区 ≈ 34.3 帧/扇区；按本仿真传输模型线性折算到真实 LBA16491
  约 **11.8 s**（文档第 3 节按 36613 clocks/CMD17 的理想下界是 6.04 s；两者都说明旧路径是秒级静音）。
  仿真传输模型每字节 1 个 sys_clk，真实约 0.55，所以本测的“相对代价”比实机更差，属保守侧。
- 静音键窗口：第 96000~107999 帧 `muted=1`，其间帧被消耗且输出为 0，解除后 PCM 从第 108000 帧
  继续且与文件逐样本一致（`mute=12000`），证明静音不跳样、不重放。

### 7.2 OSD 柱图（21 帧，真实 WAV 峰值 + 边界）

- 每帧 72×50 = 3600 像素，21 帧共 **75600** 像素与脚本内独立几何模型逐点比对：
  `missing_bar_pixels=0`、`unexpected_ink_pixels=0`（柱色 `1a1916`），柱像素合计 6273。
- 逐帧（audio_peak → 9 帧历史柱高）：26028 → `[37,0,…]`；5340 → `[7,37,…]`；…；
  静音帧 `0` → `[0,18,4,16,7,19,7,37,0]`（只清最新样本，历史按设计衰减）；
  `1023 → [0,…]`（不画）；`1024 → [1,…]`（1 px）；`32768 → [44,1,…]`（**44 px 上限**）；
  最后 9 帧全静音后历史全零 → **0 个柱像素**。
- 边界对比：`audio_peak=1023/1024` 证明 `[15:10]` 量化门限；`32768` 证明钳位；
  ROI 边带（x440..444、x508..511、y384..387、y432..433）无柱色像素，即柱图不越界、不压住
  `x468..486,y433..453` 的小字幕。

### 7.3 旧契约未回归（显式 `LOOP_PLAY(0)`）

`tests/audio_media_tb.v` 在 6 个标准配方下全部 `TEST_PASS`：默认、`MONO=1`、`REQUEST_PAUSE=1`、
`FAULT=1`（no WAV）、`FAULT=2`（511 B 扇区）、`FAULT=3`（SD 错误）。
同参数下另外两个 TB 也实跑 PASS：`tests/audio_arbiter_tb.v`（2304 PCM 帧顺序、无 UF/OF）、
`tests/audio_output_mux_tb.v`（tone/WAV 切换与 48k 间隔诊断）。

其余 4 个只加了 `.LOOP_PLAY(0)` 一行的 TB 做了编译（elaboration）验证，全部 exit 0：
`tests/html_real_wav_volume_tb.v`、`tests/html_scene_real_tb.v`、`tests/no_bot_audio_delivery_tb.v`、
`tests/no_bot_audio_load_tb.v`。`tests/media_integration_tb.v` 需要 SD/IP 依赖树，未在此隔离环境编译
（改动仅为参数列表中多一项）。这 4 个 TB 的**运行**结论仍由 Root 的完整回归给出，本报告不代其确认。

额外单独指定 `BOUNDARY=1`/`SHORT=1` 会让单声道夹具与测试默认的立体声预期不符，
出现 `FATAL right frame 0 value -7680000`，不是生产RTL故障。正式边界配方必须同时使用
`MONO=1,SHORT=1,BOUNDARY=1`；Root 使用仓库既有配方重跑。

### 7.4 OSD 未回归

`scripts/probe_osd_default_1x_verify.py`（Root 的探针）在本轮改动后的
`html_osd_overlay.v` 上 **PROBE_OSD_DEFAULT_1X_PASS**：8 页逐像素模型比对通过，
且由本文件重新生成的 utility 字体 HEX/BIN 与其仓库哈希一致（digit 表未被改动）。


## 8. 局限

- 仿真把 48 kHz 节奏**加速 130 倍**（每样本 4 个音频时钟，而非 520/521），以保留真实样本顺序、
  数据长度、读写指针与 FIFO 行为；扇区传输模型相对播放更慢（每字节 1 个 sys_clk，真实约 0.55），
  因此 FIFO 余量比实机更紧，但不能替代真实 SD 卡的响应/仲裁时序。
- 仿真的 WAV 放在 LBA64（原基线离线镜像为 LBA16491；新素材布局另见交付清单）以缩短扫描；旧路径停顿按 LBA 线性缩放给出估计值，不是实卡测量。
- 未做 SYN/PNR/STA/BITGEN，未上板，未做 HDMI 音频包解码、听音、物理卡与显示器验证。
- 音乐主观听感（音色/编曲）无法离线判定，仅给出客观指标；素材为本轮原创，不使用原 80 s 文件内容。
- `audio_pcm_player` 的 64 样本峰值窗与 OSD 的帧边界相位仍为原实现，本轮未改。

## 9. 文件与兼容性

新增：`scripts/probe_audio_wav.py`、`scripts/probe_audio_sim.py`、
`tests/probe_audio_loop_tb.v`、`tests/probe_audio_osd_tb.v`、`docs/PROBE_AUDIO.md`、
`output/probe_audio_multires/media/07_MUSIC.WAV`（git 忽略，仅本地产物）。

修改：`rtl/ext/audio_media.v`（`LOOP_PLAY` 默认 1 + `candidate` 回绕）、
`rtl/ext/html_osd_overlay.v`（`audio_history` 6 bit + 柱图几何）。

为保证“默认 1”不改变旧测试语义，以下旧测试在实例上**显式**加了一行 `.LOOP_PLAY(0)`：

| 文件 | 原因 |
|---|---|
| `tests/audio_media_tb.v` | `wait(eof)`，验证 `FINISHED`/`drained`/扇区计数 |
| `tests/html_real_wav_volume_tb.v` | `wait(eof)` 后核对整段 PCM |
| `tests/html_scene_real_tb.v` | 自行用 `eof` 上升沿发 `restart` 循环 |
| `tests/no_bot_audio_delivery_tb.v` | `wait(eof)` 后重扫复测 |
| `tests/audio_arbiter_tb.v` | `wait(eof)`（位置化实例，新增 `#(.LOOP_PLAY(0))` 参数列） |
| `tests/audio_output_mux_tb.v` | `wait(eof)` 后测静音（同上） |
| `tests/media_integration_tb.v` | 固定时长内断言 `!eof`、PCM/扇区计数 |
| `tests/no_bot_audio_load_tb.v` | 固定帧数后断言 `eof==0` 与计数 |

`tests/video_audio_integration_tb.v` 不等待 `eof`，未改（默认循环不影响其固定帧数断言）。
冻结 `rtl/top_tf_hdmi_audio.v` 与其它 RTL 未改；`LED/KEY3/暂停耦合/播放器音量/HDMI 输出/SDRAM/SD 底层` 未动。

## 10. Root 复测建议

```
# 1) 素材再生 + 指标（确定性，SHA 应仍为 fb05ffc0…，约 10 s）
D:\python3.12.3\python.exe -X utf8 scripts\probe_audio_wav.py
# 2) 三份循环编译 + OSD 柱图（默认参数/显式 1/旧 0；约 16 min）
D:\python3.12.3\python.exe -X utf8 scripts\probe_audio_sim.py --run-id <id>
# 3) 旧 EOF 契约（示例；6 个标准配方）
C:\iverilog\bin\iverilog.exe -g2005-sv -s audio_media_tb -Paudio_media_tb.MONO=1 ^
 -o t.vvp rtl\ext\audio_media.v rtl\ext\wav_stream_parser.v rtl\ext\audio_pcm_player.v ^
 rtl\ext\audio_async_fifo.v tests\audio_media_tb.v
C:\iverilog\bin\vvp.exe t.vvp
```
`probe_audio_sim.py` 的 `--root/--extra` 用于“源码根 + 本人覆盖目录”，`--wav` 指向生成的 WAV；
它会把所用文件（含两份 TB）逐个复制进运行目录并记录 SHA256，结束时比对源文件未在运行中被改动。
