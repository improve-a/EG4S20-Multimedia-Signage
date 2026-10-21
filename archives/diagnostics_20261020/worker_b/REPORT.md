# Worker B 报告：NoBot 黑屏 vs HDMI Probe 通过 — 真实 routed 报告的 PNR / STA / CDC 只读对照

范围：`no_bot_legacy_004`（FAIL，黑屏）与 `hdmi_probe_001`（PASS，实板通过）两份**真实 routed** 构建。
本报告只做只读分析与可复现取数；未修改任何 RTL/约束/原目录/冻结件，未启动 TD 构建，未操作硬件。
远端只读访问 `thinkpad`，未创建远端临时目录，未加载 `.db`（原因见 §12）。

---

## 勘误（Root review 2026-10-20 后，优先阅读）

> 以下 6 条更正**推翻或降级**了本报告初版的相应推论；原始取数全部保留，正文已同步修改。
> 结论以本节为准。

**E-1 彩条绕过内容闸门（初版 §0.1-7 / H1 / §14 错误）**
- 初版写“所有外部像素源都经过 `display_valid` 的 0 门”，**错误**。
- 直接证据：该 zip 对应实板诊断位流 `hdmi_colorbar_diag_001.bit`（`f5408a72…e83`，633,116 B）；
  冻结 `hdmi_colorbar_diag_001_source.zip`（563,189 B，SHA-256 `62784790…478ca`）内
  `work/design/user_source/hdl_source/top_tf_hdmi_audio.v`：
  - 第 448 行 `hdmi_colorbar_source diagnostic_source(.clk(video_clk),.rst(video_rst),.i_de(fx_de),.o_rgb(diagnostic_rgb));`
  - 第 451–456 行 `video_rgb_to_axis_640x480 … .I_vs(fx_vs), .I_de(fx_de), .I_rgb(diagnostic_rgb);`
  - 第 378 行的 `vout_data = display_valid ? raw : 0` 与第 191 行 OSD 只影响 `fx_rgb`，而 `fx_rgb` 已不再进入适配器。
- 影响：彩条**不经过** `display_valid` 0 门、`video_transition` 或 OSD 遮罩；它只借用 `fx_vs/fx_de` 时序，
  且不依赖 TF/SDRAM 像素准备（无卡时音频走 tone 回退）。
  “彩条也黑”不能再用来支持内容闸门。相反，它说明该构建的像素已到达 RGB→AXIS 适配器，
  黑屏在其**下游**（AXIS 握手、HDMI 核输入、TMDS 编码/串行、时钟/复位）或“有信号”判读需复核。
  H1 降级为“仅对 NoBot 可能”，不再是首推。

**E-2 `sd_miso` 不是“错误 clock relation”（初版 §7.1-1 撤回）**
- `sd_spi_clk` 是 `sd_dclk` 上的 generated clock（divide_by 8 = 12.5 MHz，与高速 SCLK 一致），
  `set_input_delay -clock sd_spi_clk -clock_fall` 描述的是**外部卡相对前向 DCLK 的 launch**；
  内部由 100 MHz `sd_card_clk` 采样，是标准的“外部源同步 launch / 内部 capture”模型，不是参考时钟选错。
- multicycle 4/7 与 RTL 的半周期 4 个 sys100 周期对应（`DCLK_IDLE` 3 拍 + `DCLK_EDGE` 1 拍）；
  `partial input delay` 只说明只给了 falling-edge 参考（CPHA/CPOL 需要），不能据此判错。
- 更正为**签核口径/预算依赖**（外部卡 tOD/tSU 与 16/0 ns 假设），并注明已有 normal/init 专项分析；
  本报告不再把它列为“错误 clock relation”，也不重开该专项。

**E-3 路径计数与“最薄 hold”（初版 §0.1-5 / §3 / §4 / §6）**
- 报告头固定 `128 end point(s) per path group, 2 path(s) per end point`；
  文中 31/31/21/22、256、172、38 等都是**报告条目数**，不是全量路径数。
  不能据此断言“两版路径数相同/结构相同”，只能说“在相同 report scheme 下可见条目相同”。
- TD 全局 `Timing Status HWNS 0.022` 是 hold/removal 合并口径；在**报告条目**中它对应 clk 的 **removal**。
  按 Check Type 拆分，纯 hold 报告条目最小是 **0.032**（FAIL video BCH FIFO）。不排除未进入报告的路径更小（E-3 的 128 EP × 2 path 上限）。
  `S_odd_even` 的 **0.164 只是串行捕获组内最薄**，不是全局最薄。初版“全设计最薄”表述已删除。

**E-4 HOLD_FIX 改变了实现（初版 §1 / §0.1 措辞）**
- HOLD_FIX 后 `phy_1` 的 DB/bit 与 fix 前不同（bit 哈希、DB 大小/内容均变），hold 余量也变；
  不能写“hold fix 没有改变实现”。
- 可保留的事实仅是：before/after **报告级**的 setup WNS、R-period、fanout、skew、时钟表数值未动；
  这不等于物理实现相同。
- 同理，同一路径报告的 PLL/BUFG 站点与插入延迟相同，只证明该路径的时钟到达与资源站点相同，
  **不是整个物理时钟网络逐点相同**。

**E-5 TMDS 2-bit 移位不必然“仍有图像”（初版 §4.3 / H3）**
- 撤回“2-bit 移位必然仍有图像、只是花屏”。TMDS 10-bit 字符含 2-bit control 组与 DC 平衡；
  持续移位会造成 control token 错位/无效字符，接收机可能失锁、黑屏或静音。
- 因此 H3 **可以**解释“黑屏+无声”，不能再用“应该还有图像”排除它。

**E-6 实验边界（初版 §10 E4/E5）**
- 删除 3-seed 扫种子与任何额外构建建议：用户已明确禁止，且只授权两项受控实验（由 Root 执行）。
- 本报告只保留离线核查与既有观测的判读，不提出新的上板、换卡或构建动作。

## 0. 摘要（先给结论边界）

### 0.1 已确证（有直接证据）

1. **位流同一性**：FAIL `phy_1\hx4s20_basic.bit` = `61874e4f…a2fc7`（677348 B），
   PASS `phy_1\hx4s20_basic.bit` = `bbb83a71…f618`（677348 B），且与冻结件
   `D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\bit\hdmi_probe_001.bit` **逐字节一致**。
2. **约束与引脚完全相同**：两份 `timing.sdc` SHA-256 均为 `93d101bd…4051`，`pin.adc` 均为 `ae389336…b6c1`；
   7 个时钟名、频率、PLL 参数、BUFG 站点、IO 位置全部相同。
3. **“FAIL +0.813 / PASS +0.039”不是视频域余量**：
   - FAIL `SWNS 0.813 ns` 属于 **sd_card_clk→sd_card_clk**（`wav/parser/pos_reg[30]` → `wav/parser/state_reg[1].ce`，D=8.907 ns，K=0.064 ns）。
   - PASS `SWNS 0.039 ns` 也属于 **sd_card_clk→sd_card_clk**（`sd_card_bmp_m0/loader/timeout_count_reg[9]` → `loader/sample_x_reg[4].ce`，D=9.609 ns）。
   - 视频/串行域除 hold 差 8 ps 外 **FAIL 更好**：video_clk 时钟表 SWNS **2.525 vs 2.756**、125 MHz **3.156 vs 2.248**、
     video→5x setup **6.296 vs 6.179**、hold **0.164 vs 0.172**。
   - **重要口径**：video_clk 与 hdmi_5x_clk 的“SWNS”并不是数据 setup，而是 **recovery**（异步复位释放）：
     `2.525/2.756` = `ext_mem_clk→video_clk` 的 `mem_reset_sync → read_buf/asy_r_rst1.sr`；
     `3.156/2.248` = `video_clk→hdmi_5x_clk` 的 `rs_video/pipe[1] → lane S_shift_data.sr`。
     真正的数据 setup 是：video 域内 **9.578 vs 4.493**、5x 域内 **4.974 vs 4.933**。
   ⇒ 用全局 WNS 或“视频 WNS”解释黑屏都不成立，且方向相反。
4. **时钟站点与报告插入延迟相同**（不等于全网逐点相同）：video PLL `x040y071`、sys PLL `x000y071`、BUFG `x039y070z2` / `x001y070z2` 两版一致；
   同一条被分析路径上 video_clk 插入 `4.175+2.410=6.585 ns`、hdmi_5x_clk `4.008+2.166=6.174 ns`。
   这只证明该路径的到达时间与资源站点一致，不能外推为整个物理时钟网络逐点相同（见 E-4）。
5. **串行捕获的可见报告条目相同**（受 128 EP × 2 path 限制，非全量）：`video_clk→hdmi_5x_clk` 两版均为 setup 31 / hold 31 / removal 21 / recovery 22 条；
   `hdmi_5x_clk→hdmi_5x_clk` 均为 setup 80 / hold 79 条。不能据此断言总路径数相同。
6. **唯一的功能性 RTL 差异**（逐文件 SHA 比对 124/125 个文件）：
   新增 `ext/hdmi_probe.v`；`top_tf_hdmi_audio.v` 增加 probe/probe_display、`O_video_locked` 由悬空改为接出；
   其余 6 个“不同”文件仅是参数里的**构建路径字符串**不同（`html_scene_motion`、`html_osd_overlay`、`html_layer_palette`、
   `html_caption_column_rom`、`html_layer_descriptor_rom`、`html_osd_swap_rom`），逻辑无差异。
7. **NoBot 存在一个“硬黑屏闸门”**（仅对经过 `vout_data` 的源成立）：`top` 第 378 行
   `assign vout_data = display_valid_sync[1] ? vout_data_raw : 24'd0;`
   `display_valid` 只由 `legacy_exhibit_media` 的 `COMMIT` 状态置 1；任何 `fault_sync/sd_init_error/response_error/loader_error/scan_error`
   都会锁存到 `FAILED`，此后 `display_valid` 保持 0，像素恒 0，且 `video_transition` 被 `display_fault_sync` 强制合上遮罩（`MASK_COLOR=24'h151615`）。
   同时 WAV 播放使能是 `.sd_ready(sd_ready_out && display_valid)`。
   **重要更正**：外部彩条诊断构建把 `diagnostic_rgb` 直接接到 RGB→AXIS 的 `I_rgb`（只保留 `fx_vs/fx_de`），
   不经过该 0 门、也不经过 OSD/transition 遮罩（见 E-1）。因此彩条黑屏**不能**归因于该闸门。
8. **7 段数码管是现成的状态探针**：`display_state = fifo_fault_sync[1] ? 4'ha : state_code50`，
   `state_code` 直接给出 SD/loader 状态与故障码（E=SD init、A=storage fault、D=response error、C/F=loader/超时、0..5=SCAN/IDLE/COVER/LOAD/COMMIT/REVEAL）。
9. **`best_result` 位流不是被测位流**：两版 `best_result\hx4s20_basic.bit` 与 `phy_1` 位流哈希都不同
   （FAIL `aba40df0…`、PASS `c1a1ac88…`），其 mtime 早于 HOLD_FIX；`readMe` 记录的是 **fix 前** SWNS/HWNS。
   任何“重新烧 best_result”的操作都会引入不同镜像。

### 0.2 未确定（本报告不给根因）

两份 STA 报告**不能**判定 NoBot 黑屏发生在 HDMI 链路还是内容闸门；但彩条诊断构建已把**它自己**的故障边界压到
RGB→AXIS 之后（E-1），因此“内容闸门”不再是彩条的解释，也不应作为 NoBot 的默认首推。
给出 5 个可证伪机制与判读矩阵（§9），以及仅限离线的后续核查（§10）。
已有观测（NoBot 数码管码、彩条是否真的“有信号”）可直接用于判读，但本轮不要求新的硬件动作。

---

## 1. 材料、哈希与时间线

| 项 | FAIL `no_bot_legacy_004` | PASS `hdmi_probe_001` |
|---|---|---|
| 构建目录 | `D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004` | `D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001` |
| 构建时间 | 2026-10-19 01:25–01:31 | 2026-10-20 17:46–17:53 |
| TD | v6.2.168116 | 同 |
| `phy_1` bit SHA-256 | `61874e4f…a2fc7` (677348 B, 01:31:24) | `bbb83a71…f618` (677348 B, 17:53:25) |
| `runs\…\final_timing.rpt` | 10,520,780 B, SHA-256 `65df375b…` | 10,969,776 B, `bff93f0a…`（与冻结 manifest 一致） |
| `phy_1\final_timing.rpt` | 1,511,688 B（PNR 阶段导出） | 1,567,457 B |
| `before/after_hold_fix.rpt` | 10,523,150 / 10,520,780 B | 10,967,014 / 10,969,776 B |
| stages | LOAD/SYN/PNR/HOLD_FIX/BITGEN/STA_REPORT 全 PASS，exit 0 | 同（时序完全相同） |
| `timing.sdc` / `pin.adc` | `93d101bd…` / `ae389336…` | 相同 |

HOLD_FIX 把 hold WNS 从 `+0.019 → +0.022`（FAIL）与 `+0.011 → +0.030`（PASS）改变，并**改写了 DB/bit**；
因此 fix 前、fix 后不是同一物理实现（见 E-4）。
可保留的只是：两版**固定下来的最终报告**在 setup WNS、R-period、fanout、skew、时钟表数值上相同，
这是报告级指标相同，不是实现相同。

> 说明：`phy_1\final_timing.rpt` 与 `runs\…\final_timing.rpt` 大小不同是导出范围不同（PNR 阶段 vs 全量 STA），
> 二者的 WNS/TNS/时钟表一致。

---

## 2. 时钟域实测对照

`Timing Status`（routed, slow/fast 都查）：

| | FAIL | PASS |
|---|---|---|
| SWNS / STNS | 0.813 / 0.000 | 0.039 / 0.000 |
| HWNS / HTNS | 0.022 / 0.000 | 0.030 / 0.000 |
| Period Check WNS | 6.586 | 6.586 |

Period Check 唯一项：`ERAM 10.000 / required 3.414 / slack 6.586 @ sd_card_bmp_m0/scanner/mult0_syn_2.clk`，两版相同。

### 2.1 Clock Summary（C-Period / R-Period / WNS / skew / fanout / level）

| Clock | 约束 | FAIL R-Period(Fmax) | FAIL SWNS/HWNS | FAIL skew/fanout/level | PASS R-Period(Fmax) | PASS SWNS/HWNS | PASS skew/fanout/level |
|---|---|---|---|---|---|---|---|
| video_clk | 40 ns / 25 MHz | 30.422 (32.871) | 2.525* / 0.032 | 0.326 / 1813 / 24 | 35.507 (28.163) | 2.756* / 0.035 | 0.326 / 1926 / 27 |
| sd_card_clk | 10 ns / 100 MHz | 9.187 (108.849) | **0.813** / 0.095 | 0.326 / 1518 / 9 | 9.961 (100.392) | **0.039** / 0.030 | 0.326 / 1494 / 9 |
| ext_mem_clk | 25 ns / 40 MHz | 21.550 (46.404) | 1.725 / 0.118 | 0.480 / 501 / 10 | 21.550 (46.404) | 1.725 / 0.038 | 0.480 / 505 / 10 |
| clk | 20 ns / 50 MHz | 16.252 (61.531) | 0.937 / **0.022** | 0.254 / 50 / 4 | 8.576 (116.604) | 11.424 / 0.223 | 0.326 / 102 / 6 |
| hdmi_5x_clk | 8 ns / 125 MHz | 4.844 (206.441) | 3.156* / 0.164 | 0.480 / 33 / 1 | 5.752 (173.853) | 2.248* / 0.172 | 0.480 / 32 / 1 |
| sys_pll clkc[2] | 25 ns / 40 MHz 180° | 14.154 (70.651) | 5.423 / 12.164 | 0 / 1 / 1 | 14.160 (70.621) | 5.420 / 12.164 | 0 / 1 / 1 |
| sd_spi_clk | 80 ns / 12.5 MHz | 80.000 | 0 / 0 | 0 / 0 | 同 | 同 | 同 |

`*` = 该 SWNS 是 **recovery**（异步复位释放）路径，不是数据 setup；详见 §3 / §4。
同理 **HWNS 列也可能混入 removal**：报告条目中 PASS video 的 0.035 对应 removal，组内可见 hold 最小是 0.086；
FAIL video 的 0.032 才是 hold。跨版本比较时必须按 Check Type 拆开。

关键读法：
- `hdmi_5x_clk` 的 R-Period **4.844 ns**（FAIL）说明 125 MHz 域内最坏寄存器到寄存器只需 4.84 ns，
  对 8 ns 约束有 3.16 ns 余量；PASS 更差（5.752）仍过。
- **时钟表 SWNS 列的口径**：对 video_clk / hdmi_5x_clk，该列被 **recovery** 路径占据（见 §0.1-3），
  不是数据 setup；两者的数据 setup 分别在 §3（9.578/4.493）与 §4（4.974/4.933）。
  因此不能把 clock summary 的 2.525/3.156 当成“视频数据余量”。
- `clk` 域从 50 → 102 扇出、SWNS 0.937 → 11.424，完全是 probe_display 增加的 ~52 个 50 MHz 触发器/比较器。
- `sd_card_clk` 域两版都处在 **0.8 / 0.04 ns** 的边缘，但失败的是余量更大的那版。

### 2.2 时钟树（Clock Resource Statistics + 路径原文）

| | FAIL | PASS |
|---|---|---|
| video_clk 驱动 | `video_pll_m0/clk0_buf` Global / PLL，fanout 1813 | 同站点/同类型，fanout 1926 |
| sys clk0 | `sys_pll_m0/clk0_buf` Global / PLL，1518 | 同，1494 |
| ext_mem_clk | 报告只列 2 个 global 项（未见该项；时钟表 fanout 501） | 列出 `U3/u2_ram/u1_init_ref/Sdr_clk` Global，505 |
| hdmi_5x_clk | **非 global**：PLL `clkc[1]` → 局部网 `u_hdmi2phy_wrapper/uN_lane_lvds_8_1/I_serial_clk`，fanout 33 | 同，32 |

launch/capture 实际到达时间（同一路径原文，两版一致）：

```
video_clk : PAD 1.660 → PLL 2.515 (=4.175) → BUFG clki/clko 0.000 → net fo=1813/1926 2.410 → launch edge 6.585
hdmi_5x   : PAD 1.493 → PLL 2.515 (=4.008) → net fo=33/32     2.166 → capture edge 6.174
```

即在这条被报告的路径上，**5x 捕获沿比 pixel 发射沿早 0.411 ns 到达**（CPPR 后 skew 记 0.244 ns setup / 0.201 ns hold）。
两版都是 C0 经 BUFG、C1 由 PLL 出局部网；这是**该路径与资源站点**的一致，不是全网逐点一致（E-4）。

---

## 3. 25 MHz 像素域（video_clk）

> 时钟表里的 video_clk `SWNS 2.525/2.756` 是 **`ext_mem_clk→video_clk` 的 recovery**（复位释放），
> 不是本组数据 setup。真正的 video 域内 setup 如下表。

| 指标 | FAIL | PASS |
|---|---|---|
| 报告条目数（128 EP × 2 path 上限） | 256 | 256 |
| setup 最差 | **9.578 ns** | **4.493 ns** |
| — 起点 | `extensions/osd/glyph_rom/storage_syn_28.clka` | `extensions/osd/glyph_rom/storage_syn_37.clka` |
| — 终点 | `extensions/osd/b3_reg[10]_syn_3.mi[0]` | `extensions/osd/r3_reg[10]_syn_4.mi[0]` |
| — Data Path Delay | 30.279 ns (cell 15.777 / net 14.502)，K=0.073 | 35.436 ns (cell 16.471 / net 18.965)，K=0.145 |
| hold 最差 | 0.032 ns（音频 BCH FIFO `u_logic_ramfifo_syn_584.dia[0]`） | 0.086 ns（`u_logic_ramfifo_syn_554.dia[3]`） |
| removal 最差 | 0.035 ns | 0.035 ns |
| recovery | 组内无 recovery 路径（无跨域异步复位端） | 同 |

（全局 recovery 最小 2.189 ns 属于 `ext_mem_clk→sd_card_clk`，不在视频域。）

结论：**FAIL 的视频域数据 setup 比 PASS 快约 5 ns**，视频域不存在 setup 风险。
32 ps 是 **FAIL 报告条目中的纯 hold 最小值**（TD 全局 HWNS 0.022 为 hold/removal 合并口径，报告条目中对应 removal，见 E-3；PASS 纯 hold 最小为 sd 的 30 ps）；
同组比 PASS 只差 54 ps，且两版都为正，不能单独解释“只失败一版”。

---

## 4. 125 MHz 串行域与 TMDS 软串行器

> 时钟表的 hdmi_5x_clk `SWNS 3.156/2.248` 是 **`video_clk→hdmi_5x_clk` 的 recovery**（`rs_video`→lane `.sr`），
> 不是本组数据 setup。5x 域内数据 setup 见 4.1。

### 4.1 `hdmi_5x_clk` 域内

| 指标 | FAIL | PASS |
|---|---|---|
| setup 最差 | 4.974 ns | 4.933 ns |
| — 起/终 | `u1_lane_lvds_8_1/S_oddr_data_reg[0]_syn_3.clk` → `HDMI_D1_P_syn_2.do[1]` | `u3_lane.../S_oddr_data_reg[0]_syn_4.clk` → `HDMI_CLK_P_syn_2.do[1]` |
| — Delay / K | 2.414 ns (cell 6% / net 94%) / 0.451 | 2.455 ns / 0.451 |
| hold 最差 | 0.445 ns | 0.350 ns |
| 四条输出寄存器 setup（D0/D1/D2/CLK） | 5.482 / 5.678 / 5.228 / 6.101 | 6.142 / 5.888 / 5.733 / 6.488 |

### 4.2 像素→串行的跨域（`video_clk → hdmi_5x_clk`）

| 检查 | FAIL | PASS |
|---|---|---|
| setup | **6.296**（`u2_hdmi_tmds_encode/O_tmds_code_data_reg[0]` → `u2_lane/S_shift_data_reg[8].c[1]`，D=1.244，K=0.244） | **6.179**（`u0…O_tmds_code_data_reg[0]` → `u0_lane/S_shift_data_reg[1].c[1]`，D=1.361，K=0.244） |
| hold | **0.164**（`u0_lane/S_odd_even_reg` → `u0_lane/S_odd_even_1d_reg.mi[0]`，D=0.526，K=0.201） | **0.172**（`u0_lane/S_odd_even_reg` → 核心 `u_hdmi_video_source/lt8_syn_45.mi[0]`，D=0.534） |
| removal | 0.678（`rs_video/pipe_reg[1]` → `HDMI_D2_P_syn_2.rst`，D=0.885，net 88%） | 1.098（→ `HDMI_CLK_P_syn_2.rst`，D=1.305） |
| recovery | 3.156（`rs_video/pipe[1]` → `u2_lane/S_shift_data_reg[2].sr`，D=4.200，net 95%） | 2.248（→ `u1_lane/S_shift_data_reg[1].sr`，D=5.108） |
| 报告条目数（非全量） | 31 / 31 / 21 / 22 | 31 / 31 / 21 / 22 |

> 该组的 **recovery 3.156 / 2.248 就是 hdmi_5x_clk 时钟表 SWNS 的来源**；组内数据 setup 是 6.296 / 6.179。

### 4.3 串行器结构（`lane_lvds_10_1.v`，两版 RTL 相同）

- 像素域只产生 `S_odd_even`（每 40 ns 翻转），5x 域用 `S_odd_even_1d/2d`、`S_load_en=1d^2d`、
  `S_load_en_1d/2d` 生成每 40 ns 一次的 load；`S_shift_data` 每 8 ns 左移 2 位；`S_oddr_data<=S_shift_data[9:8]` 送 `EG_LOGIC_ODDR`。
- 因此 **`S_odd_even` 的跨域捕获是“发射沿与捕获沿同相（都是 PLL 0°）的窄保持握手”**，
  这是**串行捕获唯一的薄点**（0.164 / 0.172 ns；比 sd→video 的 0.073、video→sd 的 0.158 都厚）。
- 失败模式判别（**已更正**）：若捕获错 1 个 5x 周期 → `load_en` 平移 8 ns → 10 位字移 2 位。
  TMDS 的 10-bit 字符含 2-bit control 组与 DC 平衡，持续移位会造成 control token 错位/无效字符，
  接收机可能失锁、黑屏或静音；**不能**再说“必然仍有图像”。因此 H3 可以解释黑屏+无声。

### 4.4 布局

- lane 触发器与 ODDR 都紧邻输出 bank：如 FAIL `u2` 的 `S_shift_data_reg[8]` 在 `x017y051`，PASS `u0` 在 `x006y054`；
  四条 lane 的 `S_oddr_data`/`do` 路径都在同一 bank 内，未跨区。
- 5x 时钟以**局部网**到 4 条 lane（0.480 ns skew，33/32 扇出），不是 BUFG 全局网；这是设计固有风险，但两版相同。

---

## 5. PLL / BUFG / 复位

### 5.1 PLL 配置（两版相同）

- `video_clocks`：FIN 50 MHz，NOCOMP/VCO_PHASE_0，REFCLK_DIV=2，FBCLK_DIV=40，C0 DIV40（25 MHz）→ **BUFG**，C1 DIV8（125 MHz）**不经 BUFG**。
- `system_clocks`：FIN 50 MHz，C0 100 MHz→BUFG，C1 40 MHz，C2 40 MHz 180°（CPHASE11/FPHASE4）。
- 2 个 PLL、2 个 GCLK，两版资源数完全一致。

### 5.2 复位链

`rst_n → reset_sync rs_button(clk) → button_reset50`；
`clk` 域 `rst_all_reg` 要求 `sys_lock_sync[1] && video_lock_sync[1]` 连续 20 ms（1,000,000×20 ns）才释放；
`rs_sd / rs_mem / rs_video` 各自两级异步置位/同步释放；`video_rst` 同时送 HDMI 核 `I_rst`、PHY `I_rst`、音频、OSD。

### 5.3 removal 现状（不重做专项分析）

- FAIL 全局 removal 最差 **+0.022 ns**：`rst_all_reg_reg_syn_10.clk → state_code50_reg[3]_syn_4.sr`（clk 域，D=0.420，K=0.045）。
- video 域 removal 最差 **+0.035 ns**：`u_hdmi_video_source/lt3_syn_45.clk → S_col_cnt_reg[8].sr`（D=0.417）。
- HDMI 侧：`rs_video/pipe[1] → lane ODDR .rst` **+0.678（FAIL）/ +1.098（PASS）**；→ lane shift `.sr` recovery **3.156 / 2.248**。
- `ignored_timing.rpt`：`set_false_path -hold -from rst_all_reg -to {rs_*/frame_*_reset_sync}` 的 dominated 数 **7（FAIL）/ 8（PASS）**，
  没有 shadowed/ignored；其余 SFP 为导入 FIFO 约束（18/18、18/18）。
- 与“7 条 reset_sync 入口 removal 负余量”专项结论不冲突：当前两份 routed 均无负余量，且失败版在 HDMI 侧 removal 更差但仅 0.678 vs 1.098，仍为正。

---

## 6. 关键 CDC 与跨域预算

| 组（Path Group） | FAIL 最小 setup / hold | PASS 最小 setup / hold | 备注 |
|---|---|---|---|
| sd_card_clk → sd_card_clk | 0.813 / 0.095 | 0.039 / 0.030 | **全局 WNS 来源** |
| video_clk → video_clk | 9.578 / 0.032 | 4.493 / 0.086 | 像素内容域；**时钟表 video SWNS 不在此组** |
| ext_mem_clk → video_clk | recovery 2.525 | recovery 2.756 | `mem_reset_sync → read_buf/asy_r_rst1.sr`（即 video 时钟表 SWNS 的来源） |
| ext_mem_clk → ext_mem_clk | 1.725 / 0.118 | 1.725 / 0.038 | SDRAM/FIFO |
| clk → clk | 0.937 / 0.022 | 11.424 / 0.223 | 启动/按键/数码管 |
| sd_card_clk → video_clk | 172 条，hold 0.073 | hold 0.073 | config/commit 打包总线 |
| video_clk → hdmi_5x_clk | 6.296 / 0.164 | 6.179 / 0.172 | **TMDS 串行捕获** |
| hdmi_5x_clk → hdmi_5x_clk | 4.974 / 0.445 | 4.933 / 0.350 | lane 内部 |
| video_clk → sd_card_clk | 38 条，hold 0.158 | 38 条，hold 0.352 | wav 状态回读 |
| clk → video_clk | recovery 20.237 | 20.356 | 复位释放 |
| clk → sd_card_clk | recovery 10.134 | 10.072 | 复位释放 |
| ext_mem_clk → clkc2 | 5.423 | 5.420 | SDRAM DQ 写 |
| clkc2 → ext_mem_clk | 1.725 | 1.725 | SDRAM DQ 读 |

要点（表中所有 N 条均为 128 EP × 2 path 上限下的**可见条目**，不是全量路径数）：
- 跨域**没有** exclusive clock group，video_clk 与 hdmi_5x_clk 是真实的 setup/hold 检查（好事，不是被 false path 掉了）。
- 唯一的 `set_false_path` 是 `rst_all_reg → 六个 reset_sync` 的 **hold**（断言沿），recovery 与下游全部保留。
- `sd_card_clk → video_clk` 的 `candidate_view/commit` 是“toggle + 2FF + settle=3”协议，多 bit 总线未做 gray 编码；
  它被 STA 按普通跨域 setup/hold 检查，但**协议正确性不在 STA 覆盖内**（见 §8）。

---

## 7. 约束覆盖与“空洞”

`STA coverage 99.93%（FAIL）/ 99.92%（PASS）`。`check_timing.rpt` 两版**逐项相同**：

| 项 | 数量 | 内容 |
|---|---|---|
| no clock | 0 | — |
| local clocks | 4 | `clk`, `sd_card_clk`, `sys_pll_m0/pll_inst.clkc[2]`, `video_clk` |
| clock on internal net | 0 | — |
| dangling nodes | 3 | 仅 LUT 未用输入/扇出（含 `desired_page_reg`、`catalog_reg[244]` 等），非功能网 |
| no input delay | 5 | 工具未逐项列出；见 `check_timing.rpt` 第 10 节 |
| **no output delay** | **20** | **HDMI_CLK_P / D0..D2_P、HDMI_DDC_SCL/SDA、seg_data[7:0]、seg_sel[5:0]** |
| partial input delay | 1 | **`sd_miso`** |
| abnormal input delay | 32 | SDRAM `dq[31:0]` 的 fast/slow × max/min |

### 7.1 约束覆盖空洞与需注意的口径

1. **`sd_miso` 的源同步输入模型（初版“错误 clock relation”已撤回，见 E-2）**：
   `sd_spi_clk` 是 `sd_dclk` 上的 generated clock（÷8 = 12.5 MHz，与实际高速 SCLK 一致）；
   `set_input_delay -clock sd_spi_clk -clock_fall -max 16 / -min 0` 描述的是**外部卡相对前向 DCLK 的 launch**，
   内部由 100 MHz `sd_card_clk` 捕获，属于标准的“外部 launch / 内部 capture”模型。
   `set_multicycle_path 4 -setup / 7 -hold` 与 RTL 的半周期 4 个 sys100 拍（`DCLK_IDLE` 3 + `DCLK_EDGE` 1）对应；
   `partial input delay` 只表示只给了 falling-edge 参考（CPHA/CPOL 所需），不是错误。
   **剩下的只是覆盖/预算限制**：结论依赖外部卡 tOD/tSU 与 16/0 ns 假设；已有 normal/init 专项分析，本报告不重开。
2. **TMDS 输出没有任何 output delay / 位周期约束**：4 条 TMDS 是源同步 DDR 输出，
   没有约束表达 4 ns UI、lane-to-lane skew、clock-to-data skew。`0.480 ns` 的 5x skew 只是时钟内部 skew，
   不是四条 lane 之间的输出偏斜。因此“TMDS 眼图/偏斜”在 STA 上是**完全未签核**的。
3. **加密 HDMI 核**：RTL 不可读，但综合后内部 FF（`u_hdmi_*`）出现在 STA 路径中，说明其寄存器路径被时序分析覆盖；
   未做门级/全系统仿真，核内协议、复位同步器与 island 打包行为未验证。
4. **多 bit CDC 协议**：`candidate_view[11:0]`、`display_config[50:0]` 类打包总线用 toggle+2FF+settle 传递，
   STA 只保证每一位的 setup/hold，**不保证多位同时被采到同一版本**。这是黑屏/错页的候选通道之一。
5. **`axis_s_ready` 在 FAIL 中完全悬空**（`O_axis_s_ready` 只接到未使用的 wire `axis_s_ready`；RTL 级判断，未在 routed DB 中逐网确认），源端不遵守反压；
   probe 只是把它接给观测器（PASS 的页 4 记录 ready 高/低都出现过、无 valid∧!ready 冲突）。
   这是**功能握手空洞**，不是时序空洞，但会随实现/启动相位变化。

> `set_false_path -from primary_addr_gray_reg -to sync_r1` 是导入的 FIFO 约束，不覆盖上述任何一项。

---

## 8. 布局 / 资源差异（“实现相关”的量化）

| 指标 | FAIL | PASS | Δ |
|---|---|---|---|
| LUT / REG / LE | 10054 / 6323 / 11206 | 10257 / 6572 / 11371 | +203 / +249 / +165 |
| BRAM9K / BRAM32K / DSP / PLL / GCLK | 53 / 5 / 8 / 2 / 2 | 相同 | 0 |
| slices | 5824 (59.43%) | 5945 (60.66%) | +121 |
| wire length | 1,187,000 | 1,209,976 | +1.94% |
| place setup WNS | 1807 ps | 1857 ps | +50 ps |
| place hold WNS/TNS/FEP | −11 ps / −143 / 13 | −11 ps / −121 / 11 | — |
| route setup WNS | 813 ps | 39 ps | −774 ps |
| route hold WNS | 19 → 22 ps（fix 后） | 11 → 30 ps | — |
| 顶层 `clk_dup_1` 扇出（PLL refclk 网） | 47 | 99 | +52 |
| 域内 LUT（clk / video / sd / 5x） | 42 / 2164 / 2314 / 32 | 103 / 2370 / 2101 / 34 | +61 / +206 / −213 / +2 |

- probe 只增加了 clk/video 域的观测逻辑，却让 **sd 域的 LUT 归属减少 213**、video 增加 206；
  这说明 **两个 netlist 的布局/打包被整体重排**，而不是“sd 域逻辑变少”。
- 失败版的 route WNS 反而更大（813 vs 39 ps），进一步说明**“余量更小所以黑屏”不成立**。

---

## 9. 黑屏 + 无声 + RGB 彩条也黑 + TPG 正常的机制候选（可证伪，不先验）

编号 H1..H5 **不代表优先级**。NoBot / 彩条 / TPG 是**三个不同位流**，跨构建只能做边界推断，不能证明同一根因。
先固定事实链：
- NoBot 的外部像素（HTML 六页）经过 `vout_data = display_valid ? raw : 0` 与 `video_transition` 遮罩；
  **彩条构建是例外**：它把彩条直接接到 RGB→AXIS 的 `I_rgb`，只保留 `fx_vs/fx_de`，不经过这两级（E-1）；
- HDMI 核内部 TPG **绕过 AXIS 输入**，因此 TPG 正常只能证明 PHY/TMDS/PLL/显示器链路在该 TPG 位流中可用；
- `display_valid` 只在 loader 首次 `COMMIT` 后置 1，任何 fault 都锁死 `FAILED`；
- 数码管 `display_state` 直接输出 loader 状态/故障码。

### H1（仅 NoBot 内容闸门；非首推，彩条已排除）
- 证据：`top:378` 硬 0 门；`legacy_exhibit_media` 的 `FAILED` 分支；`audio_media .sd_ready(sd_ready_out && display_valid)`。
- **边界**：只对经过 `vout_data` 的源成立。彩条诊断把 `diagnostic_rgb` 直接接适配器 `I_rgb`（E-1），
  **不经过该门**，所以“彩条也黑”不能支持 H1。
- 可解释：NoBot 黑屏、WAV 无声、六页不出；不解释彩条。
- 预测：NoBot 失败板数码管稳定显示 **A / C / D / E / F**（fault）或长期停在 **2/3/4**（COVER/LOAD/COMMIT），而不是 0/1。
- 反证：显示 **0**（且不是 SCAN 瞬间）或显示器报“无信号”，H1 对 NoBot 也不成立。

### H2（复位/时钟未启动）：`rst_all` 或 `video_rst` 未释放 / video PLL 未出时钟
- 证据：`video_rst` 同时复位 tone、video_delay、HDMI 核与 PHY；若 video_clk 停或 `rst_all=1`，
  则 TMDS 无输出（显示器“无信号”）、tone 也被复位（**无声**）、像素恒 0（黑）。
  这比 H1 更能解释“连测试音都没有”，因为 tone 不依赖 display_valid。
- 预测：数码管稳定 **0**；显示器报无信号；50 MHz 数码管扫描仍工作（`seg_scan` 用 `rst_n`，不受 `rst_all` 影响）。
- 反证：显示器报有信号/有分辨率，或数码管进入 1..8，则 H2 不成立。

### H3（软串行器 / TMDS 字符相位；彩条证据后上调）
- 证据：彩条构建绕过内容闸门、OSD 与 TF/SDRAM，仍黑；该构建的共同剩余路径正是 AXIS→核心→TMDS 串行。
  `S_odd_even` 的 hold 只有 0.164/0.172 ns（组内最薄，不是全局最薄），两时钟同源同相、C0/C1 插入差 0.411 ns。
- 失败模式（已更正）：10 位字移 2 位会破坏 TMDS 的 2-bit control 组与 DC 平衡，接收机可能失锁、黑屏或静音；
  **不能**用“应该还有图像”排除。
- 反证/限制：两版该路径的 STA 余量只差 8 ps，且都为正；没有直接证据证明实板发生了滑移。
- 结论：**可解释彩条黑屏的候选之一**，但仍是假设；需要离线网表/串行输出核查或既有观测判别。

### H4（AXIS 反压被忽略）：`axis_s_ready` 悬空，源端不遵守 tready
- 证据：FAIL 中 `O_axis_s_ready` 只接未使用 wire（RTL 级）；彩条同样不接 ready，且不依赖内容闸门。
  probe 页 4 证明正常构建里 ready 会高会低，但 valid∧!ready 未发生。
- 预测：若启动相位使 core FIFO 满，会丢像素/丢 island 包，可能黑屏或音频断。
- 限制：probe 的正常记录说明该构建没有发生反压冲突；不能据此推断 FAIL/彩条构建也没有。
- 判据（若已有记录）：敲 key1/key2 触发重新 load，恢复则更像可恢复事件；不恢复则更像 sticky fault/复位。

### H5（SD 卡/接触/内容，非位流）
- 证据：NoBot 构建需要 `sd_init_done` 才可能产生 `display_valid`；同一卡在 10-20 的 probe 运行中可读六页。
  彩条构建不依赖 TF/SDRAM 像素准备，**H5 不适用于彩条**。
- 预测：换卡/重插/重新上电后可复现性改变；数码管显示 **E**（sd_init_error）。
- 反证：同一 FAIL 位流重复上电多次结果稳定一致，且 SD 状态码始终正常。

### 机制—观测判别矩阵

| 观测 | H1 loader 闸门（仅 NoBot） | H2 复位/时钟 | H3 串行相位 | H4 反压 | H5 SD/卡（仅 NoBot） |
|---|---|---|---|---|---|
| 显示器“无信号” | 否 | **是** | 可能（无时钟） | 否 | 否 |
| 有信号但纯黑 | **是** | 否 | **是** | **是** | **是** |
| 数码管 A/C/D/E/F | **是** | 否 | 否 | 否 | **E** |
| 数码管稳定 0 | 否（除非 SCAN） | **是** | 否 | 否 | 否 |
| 有测试音（tone） | 应**有** | 无 | 应有 | 应有 | 应有 |
| 重新 load 后恢复 | 可能 | 否 | 否 | 可能 | 可能 |
| TPG 位流正常 | 是 | 是 | 是 | 是 | 是 |
| 彩条构建（无 TF/SDRAM） | **不适用** | **可能**（若真无信号） | **是** | **是** | **不适用** |

> 注意“无声”这一项：`hdmi_audio_tone_pcm_scale` 在 `video_rst` 释放后**无条件**产生 262–523 Hz 方波，
> `audio_output_mux` 在无 WAV 时默认选 tone，`volume=8`、`muted=0`。因此 **若 video_rst 已释放，应当能听到测试音**。
> 失败时“完全无声”更支持 H2，或 H3/H4（core 未发送/未正确编码 audio island），而不利于纯 H1。
> 本轮仅离线，不要求用户再做硬件确认；若已有“是否只是没有音乐、还是连提示音也没有”的记录，可直接用于判读。

---

## 10. 判别与后续（本轮仅离线，不提出上板/换卡/构建）

> 用户已明确禁止扫种子，且只授权两项受控实验（由 Root 执行）。本节**不新增**构建、上板、换卡或硬件确认动作；
> 只列出离线可做的核查，以及已有观测的判读方式。

**O1（本轮已完成）彩条构建的注入点核实**
- 冻结 `hdmi_colorbar_diag_001_source.zip`（SHA-256 `62784790…478ca`）内的 top：
  第 448 行 `hdmi_colorbar_source ... .i_de(fx_de), .o_rgb(diagnostic_rgb)`；
  第 451–456 行适配器 `.I_vs(fx_vs), .I_de(fx_de), .I_rgb(diagnostic_rgb)`。
- 结论：彩条绕过 `display_valid` 0 门、OSD 与 transition 遮罩；只借用 `fx_vs/fx_de` 时序。见 E-1。

**O2（离线，若 Root 需要）故障注入仿真**
- 对 `legacy_exhibit_media` + `frame_read_write` 强制 `fifo_fault/wr_full/rd_empty/response_error` 各一拍，
  确认 `FAILED` 粘滞、`display_valid` 不再置 1、`vout_data` 恒 0、tone 仍在。
- 目的只是把 H1 的“可观测签名”固化；不涉及上板。

**O3（离线，若 Root 需要）串行输出静态核查**
- 在独立 DB 拷贝上导出四条 lane 的 ODDR/走线，估算 clock-to-data skew；
  但 STA 没有 4 ns UI/lane skew 约束，这只能辅助 H3，不能签核。

**O4（判读已有记录，不要求新动作）**
- 若已有 NoBot 失败板的数码管/OSD 记录：`A/C/D/E/F` → H1/H5；稳定 `0` → H2；`1..8` 仍黑 → H3/H4。
- 若已有彩条构建的“有信号/无信号”记录：有信号 → H3/H4（内容门与 SD 已被 O1 排除）；无信号 → H2 也进入候选。

---

## 11. 对“是否某功能路径完全未约束 / clock relation 错误 / reset 时序”的直接回答

| 问题 | 答案 |
|---|---|
| 有完全没有约束的功能路径吗？ | 有：**20 个输出无 output delay**（4×TMDS、2×DDC、14×seg）；TMDS 位周期/lane skew 完全未签核。内部同步逻辑都被时钟覆盖（99.93%）。 |
| 有错误的 clock relation 吗？ | **没有可确证的错误。** 初版把 `sd_miso` 判为“错误 clock relation”已撤回（E-2）：`sd_spi_clk` 是前向 DCLK 的 generated clock，`-clock_fall` 16/0 ns + multicycle 4/7 对应外部 launch/内部 capture 模型；`partial input delay` 只是参考沿/极性口径，属覆盖限制。其余跨域关系正确，无 exclusive group。 |
| 能否比较两版“路径数/结构”？ | **不能按报告条目数下结论。** 128 EP × 2 path 的上限使 31/31/21/22、256、172、38 都只是可见条目；只能说“相同 report scheme 下可见条目相同”（E-3）。 |
| reset 时序有问题吗？ | 当前两份 routed 的 removal 全为正（最小 +0.022 clk / +0.035 video；HDMI 侧 +0.678/+1.098）。没有新的负余量；与已专项 review 的 7 条不冲突。但 `video_rst` 是否**在实板上释放**是 H2 的关键，STA 不能回答。 |
| HDMI 输入时钟分支 / serial capture 有问题吗？ | 报告路径上：pixel 经 BUFG（6.585 ns），5x 直接 PLL 局部网（6.174 ns），两版同值；serial capture setup 6.2–6.3 ns、hold 0.164/0.172 ns，均通过。**在可见报告内没有 build 间差异**（不代表全网逐点相同）。风险点是 5x 不走 BUFG（0.48 ns skew）与 `S_odd_even` 的同相 hold。 |

---

## 12. 工具能力限制 / 未覆盖

1. **未加载 `.db`**：`hx4s20_basic_pr.db` 7.99/8.16 MB 为二进制；本任务只读、且现有 `final_timing.rpt` 已给出完整路径、
   时钟插入、skew、CRPR、removal/recovery，足以支持本报告的分析。但它不覆盖未约束路径，也不是全量路径（128 EP × 2 path 上限）。加载 DB 需要 TD 交互会话与独立拷贝，收益低、风险高，故未做。
2. **STA 只覆盖已约束路径**（99.93%/99.92%）；`no output delay`、lane skew、SD 外部 tOD/tSU 假设、加密核内部协议均不在其中。
3. **没有门级/全系统仿真**，也没有厂商 PHY 模型；H3/H4 只能靠实验排除。
4. **报告命名噪声**：部分 5x 域路径的 Begin Point 出现 `sd_card_bmp_m0/loader/...` 名字（如 `header_bad_reg_syn_139` 被标为 `hdmi_5x_clk`），
   这是 TD 对复制寄存器/域归属的命名复用，**不要按名字判断逻辑归属**；应以 Path Group、时钟脚、端点为准。
5. **`best_result` 不是最终位流**（见 §0.1-9），不要用于复现实板结果。
6. 彩条方面：已读冻结 source zip 的 top（O1/E-1）；未解析 `f5408a72…` 位流本体或其 DB，
   因此“彩条构建的下游实现”仍只能按源码与已有观测判断。

---

## 13. 复现脚本（均在 `worker_b/`，只读）

| 脚本 | 作用 |
|---|---|
| `t02_hash.ps1` | 3 个位流 + 2 个 best_result 的 SHA-256/大小 |
| `t07_status.ps1` | 两版 Timing Status + Clock Summary |
| `t09_records.ps1` | 全路径记录解析：按 check type 统计、setup<1 ns、removal、video→5x、5x 域 |
| `t10_focus.ps1` | video/video→5x/5x 三组的最小 setup/hold/removal/recovery 与端点 |
| `t21_detail.ps1` | 打印 video→5x 最差 setup 的完整延迟链（含 PLL/BUFG/局部网） |
| `t22_ser.ps1` | `S_odd_even` / `S_load_en` / ODDR 路径 |
| `t30_sd.ps1` | sd 域 setup top22 + fault/display_valid/loader 路径 |
| `t31_prov.ps1` / `t39_best.ps1` | 报告/位流时间线与 best_result 归属 |
| `t16_qor.ps1` | place/route QoR、时钟域 LUT、global clock 资源 |
| `t29_cov2.ps1` | check_timing 末段：no/partial/abnormal input delay |
| `t18_diff.ps1` | 两份 user_source 的逐文件哈希差异 |
| `t43_docs.ps1` / `t44_mute.ps1` / `t42_tone.ps1` | 冻结说明、mute/volume 默认值、tone 生成条件 |

调用方式：

```bash
python3 scripts/remote_ps.py worker_b/t07_status.ps1
```

（`scripts/remote_ps.py` 用 base64 UTF-16LE 经既有 `thinkpad` SSH 执行，不落盘、不改远端。）

---

## 14. 给 Root 的结论（更正后）

- **彩条构建**（`62784790…478ca` source）已证明绕过 `display_valid` 0 门、OSD 与 transition，且不依赖 TF/SDRAM；
  它仍黑，说明该构建的故障边界在 **RGB→AXIS 适配器之后**（AXIS/核心/TMDS/串行/时钟复位），
  而不是内容闸门或 SD 卡。若“有信号”判读准确，则 H2 也基本排除，剩下 **H3/H4**。
- **NoBot 构建**是否同一根因**未定**：它仍可能停在 loader/`display_valid`（H1）或 SD（H5），也可能与彩条共有下游问题。
  不能用彩条结果直接替 NoBot 定性，也不能用 NoBot 的 0 门解释彩条。
- 两份 routed 报告能确证的只有：视频/串行域的**数据 setup 与复位释放余量都为正，且失败版不差于通过版**；
  HOLD_FIX 改写 DB/bit，实现不同；报告条目受 128 EP × 2 path 限制。
  因此**不能**用 WNS/时钟余量差解释黑屏；应转向彩条构建的下游离线核查（串行字符相位、ready/握手、核心输入）
  或已有实板判据，而不是继续比较 WNS。

---

### 附录 A：关键路径原文（video→5x setup，FAIL）

```
Slack               : 6.296ns
Begin Point         : u_hdmi_1_4b_transmitter_core_wrapper/.../u2_hdmi_tmds_encode/O_tmds_code_data_reg[0]_syn_4.clk
End Point           : u_hdmi2phy_wrapper/u2_lane_lvds_8_1/S_shift_data_reg[8]_syn_4.c[0]
Check Type          : setup   Process: slow
Budget              : 8.000ns { hdmi_5x_clk rising@8.000ns - video_clk rising@0.000ns }
Data Path Delay     : 1.244ns (cell 0.506 / net 0.738)   Clock Skew: 0.244ns
... PLL clkc[0] 4.175 → BUFG → net fo=1813 2.410 → launch 6.585
    clk2q 0.146 → net 0.738 → LUT3 0.360 → Arrival 7.829
... PLL clkc[1] 4.008 → net fo=33 2.166 → capture 6.174
setup -0.116 / uncertainty -0.100 / pessimism +0.167 → Required 14.125 → Slack 6.296
```

### 附录 B：软串行器 hold（FAIL，串行捕获组内最薄）

```
Slack               : 0.164ns
Begin Point         : u_hdmi2phy_wrapper/u0_lane_lvds_8_1/S_odd_even_reg_syn_5.clk   (video_clk)
End Point           : u_hdmi2phy_wrapper/u0_lane_lvds_8_1/S_odd_even_1d_reg_syn_5.mi[0] (hdmi_5x_clk)
Check Type          : hold    Data Path Delay: 0.526ns (cell 0.204 / net 0.322)   Clock Skew: 0.201ns
```

### 附录 C：硬黑屏闸门（RTL 原文）

```
// top_tf_hdmi_audio.v:378
assign vout_data = display_valid_sync[1] ? vout_data_raw : 24'd0;

// legacy_exhibit_media.v
COMMIT: if(ack_sync[1]==commit_toggle) begin
          committed_view<=candidate_view; display_valid<=1; state<=REVEAL; ...
        end
// fault 分支：fault_sync[1] || sd_init_error || response_error || loader_error!=0 → state<=FAILED
// top:211
.sd_ready(sd_ready_out && display_valid)
```
