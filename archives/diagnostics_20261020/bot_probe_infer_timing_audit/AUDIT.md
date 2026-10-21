# INFER_ADD_OFF_001 —— 只读结果核验报告（时序 / 面积 / 比特流完整性）

审计对象：`D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001`
审计方式：**只读**。仅通过 SSH 执行 `dir` / `type` / `certutil` / `powershell Get-FileHash` 与 `scp` 取回文件；
未运行 TD、未重新构建、未触碰硬件、未修改 Windows 侧任何文件。
本地证据目录：`bot_probe_infer_timing_audit/`（`reports/`、`bit/`、`delivery/`、`evidence/`）。

结论速览：Root 的时序数字**全部复现**，以下补充独立证据。Root 审阅边界：R-Freq 是 STA 推算而非实板实测；video_clk 自域无负 Setup 不代表整条显示供数链通过，ext_mem_clk 中的 view_reader 本身也服务显示；正的 22–24 ps 是小幅正余量，不能写成零余量或已发生失效。MSLICE 4542 的来源仍是布局/路由日志，而非 final_area 独立列出的计数。
(a) `+0.022 全局 HWNS` **是 removal 检查**，不是 hold；hold 类最坏是 `+0.024`；
(b) `final_area.rpt` **没有 MSLICE/LSLICE 字段**，4542/4542 只能取自 route 日志/`route.qor`，且 hold 修复后**未变**（有字节级证据）；
(c) 304 个失败端点 = `sd_card_clk` 93 + `ext_mem_clk` 211；`video_clk` 自域 setup WNS 为 `+2.231`，但不能把 ext_mem_clk 的显示供数链排除出显示系统。

---

## 1. 证据完整性（先证明"我读到的就是交付的"）

| 项目 | 结果 |
|---|---|
| `final_timing.rpt` sha256 | `57939c7ed88c…997df`，与 `artifacts.json` **一致** |
| `final_area.rpt` sha256 | `280e6b857dff…ecf79`，与 `artifacts.json` **一致**；且与 route 阶段 `hx4s20_basic_phy.area` **逐字节相同** |
| `check_timing.rpt` / `ignored_timing.rpt` / `exceptions.rpt` / `before_hold_fix.rpt` / `after_hold_fix.rpt` / `clocks.rpt` / `status.json` / `build.tcl` / `stdout.log` / `route.qor` / `place.qor` | 全部与 `artifacts.json` 哈希**一致** |
| 交付 bit `bot_hdmi_probe_infer_add_off_001.bit` | 本机重算 **`49c9eeab267d894f6988d3469b831e8459acb4e2e4c8bc5cbcbce6c8ae4d6151`**，与声明一致；Windows 侧 `Get-FileHash` 同值（双端一致） |
| 交付 bit 与 `phy_1/hx4s20_basic.bit` | 哈希**相同**（`49c9eeab…`），即"bitgen 产物 = 交付物" |
| `best_result/hx4s20_basic.bit`（23:05:04） | **`f94654e6…c886f`，与交付 bit 不同**；字节差异 2666 B / 0.365%。时间戳早于 `fix_hold`，是修复前 route 阶段存档，**不是**交付物 |
| `status.json` | `state=FINISHED, exit_code=0, flow_complete=true`；`attempt_number=2`；TD `6.2` sha 记录在案 |
| 交付 `SHA256SUMS.txt` | bit / source.zip / reports.zip 三项哈希与本地重算一致（source.zip `509746e9…` = status.json 记录） |

> 说明：`artifacts.json` 中另有一份 `phy_1/final_timing.rpt`（1.8 MB，`cab647c3…`），是 TD 在 route 阶段自带的精简报告（`ep_num=10`），其 `HWNS -0.044`，与 harness 的 `before_hold_fix.rpt` 相互印证；不要把它与 run 目录的 12.7 MB `final_timing.rpt` 混淆。

时序报告自述：`Confidence: Routed`、`Check Corner: Both (Slow and Fast)`、`CRPR Enabled: Yes`、`STA coverage 99.96%`、`Report Scheme: 128 end point(s) per path group, 2 path(s) per end point`。

---

## 2. 时序总账（独立重解析，而非引用 Root）

```
SWNS -5.783 ns   STNS -324.923 ns
HWNS +0.022 ns   HTNS   0.000 ns
Period Check WNS +6.586 ns
```

**算术闭合（程序化校验，见 `evidence/checks.json`）**

* `全局 SWNS = min(各组 Max SWNS) = -5.783` ✔
* `全局 STNS = Σ 各组 Max STNS = -97.328 + (-227.595) = -324.923` ✔（仅两个组贡献，无第三组）
* `失败端点 = 93 + 211 = 304` ✔，且与 route 阶段 `route.qor` 的 `Num of violated S-EP = 304` **完全一致**
* `全局 HWNS = 在"Min 有端点"的组中取 min = 0.022` ✔
* `Σ 各组 Min 违例端点 = 0`（20 个组全部为零）✔
* 端点总量 18738，失败率 1.62%

### 2.1 全部 20 个组（Max/Min 统计，非详细条目）

| 类型 | Path Group | Max SWNS | Max STNS | 失败EP / 总EP | Min HWNS | Min 失败EP |
|---|---|---:|---:|---:|---:|---:|
| Self | sd_card_clk → sd_card_clk | **-5.783** | -97.328 | **93 / 6559** | 0.032 | 0 |
| Self | video_clk → video_clk | +2.231 | 0 | 0 / 5856 | **0.022** | 0 |
| Self | ext_mem_clk → ext_mem_clk | **-5.565** | -227.595 | **211 / 5707** | 0.076 | 0 |
| Self | clk → clk | +10.466 | 0 | 0 / 204 | 0.214 | 0 |
| Same Domain | sd_card_clk → video_clk | +4.728 | 0 | 0 / 84 | 0.073 | 0 |
| Same Domain | video_clk → hdmi_5x_clk | +2.910 | 0 | 0 / 56 | 0.179 | 0 |
| Self | hdmi_5x_clk → hdmi_5x_clk | +4.427 | 0 | 0 / 49 | 0.446 | 0 |
| Same Domain | sd_card_clk → ext_mem_clk | +1.397 | 0 | 0 / 29 | 0.075 | 0 |
| Same Domain | video_clk → clk | +13.199 | 0 | 0 / 28 | 1.572 | 0 |
| Same Domain | video_clk → ext_mem_clk | +0.501 | 0 | 0 / 16 | 0.272 | 0 |
| Same Domain | video_clk → sd_card_clk | +6.300 | 0 | 0 / 16 | 0.167 | 0 |
| Same Domain | ext_mem_clk → sd_card_clk | +1.372 | 0 | 0 / 6 | 0.182 | 0 |
| Same Domain | ext_mem_clk → video_clk | +2.112 | 0 | 0 / 3 | 0.193 | 0 |
| Same Domain | clk → ext_mem_clk | +4.876 | 0 | 0 / 3 | 0.000* | 0 |
| Same Domain | clk → sd_card_clk | +9.494 | 0 | 0 / 3 | 0.000* | 0 |
| Same Domain | clk → video_clk | +19.712 | 0 | 0 / 3 | 0.000* | 0 |
| Same Domain | ext_mem_clk → pll clkc[2] | +5.135 | 0 | 0 / 48 | 12.164 | 0 |
| Same Domain | pll clkc[2] → ext_mem_clk | +1.725 | 0 | 0 / 32 | 16.753 | 0 |
| SMD | set_max_delay …24.700 | +23.410 | 0 | 0 / 18 | 0.000* | 0 |
| SMD | set_max_delay …9.700 | +7.667 | 0 | 0 / 18 | 0.000* | 0 |

\* `Min HWNS 0.000` 的 5 个组 **Min 侧端点数为 0**（未做 min 分析的空占位），不是违例，也不参与全局 HWNS。**只 grep 最小值会误判"HWNS=0.000"**；全局 0.022 是排除这些空组后的真实最小。

**只有 2 个组有负 slack，其余 18 组（含全部 CDC 组与显示相关组）Max/Min 均为正、零失败端点。**
失败分布：`ext_mem_clk` 211 EP（69.4% 端点、70.0% TNS），`sd_card_clk` 93 EP（30.6% 端点、30.0% TNS）。

### 2.2 逐时钟 Clock Summary（与组统计互校）

| clk | 频率约束 | STA 推算 R-Period / R-Freq | SWNS | STNS | HWNS |
|---|---|---:|---:|---:|---:|
| clk0 video_clk | 25 MHz (40 ns) | 37.769 ns / 26.477 MHz | +2.112 | 0 | **+0.022** |
| clk1 ext_mem_clk | 40 MHz (25 ns) | 30.565 ns / 32.717 MHz | -5.565 | -227.595 | +0.075 |
| clk2 sd_card_clk | 100 MHz (10 ns) | 15.783 ns / 63.359 MHz | **-5.783** | -97.328 | +0.032 |
| clk3 clk | 50 MHz (20 ns) | 9.534 ns / 104.888 MHz | +10.466 | 0 | +0.214 |
| clk4 hdmi_5x_clk | 125 MHz (8 ns) | 5.090 ns / 196.464 MHz | +2.910 | 0 | +0.179 |
| clk5 pll clkc[2] | 40 MHz | 14.730 ns / 67.889 MHz | +5.135 | 0 | +12.164 |

> 注意 clk0 的 `HWNS +0.022` 与全局同值 —— 全局 HWNS 就来自 video_clk 域的 removal 路径（见 §3.1）。
> STA 模型推算 `sd_card_clk` R-Freq 为 **63.36 MHz**（约束 100 MHz），`ext_mem_clk` 为 **32.72 MHz**（约束 40 MHz）；不是实际频率测量，也不建议据此改变频率。

---

## 3. 四类检查的最坏 slack（按 Check Type 独立归类）

| 类别 | 最坏 slack | 组 | Process | 起点 → 终点 | 备注 |
|---|---:|---|---|---|---|
| setup | **-5.783 ns** | sd_card_clk → sd_card_clk | slow | `wav/parser/file_length_reg[2]` → `wav/parser/chunk_space_reg[31].a[1]` | 纯组合 16 级 |
| hold | **+0.024 ns** | video_clk → video_clk | fast | HDMI island `S_packet_body_1d_reg[20].clk` → `u_w96_d1024_fifo/u_logic_ramfifo_sia[3]` | 触发器 → BRAM 写口（EMB=1） |
| removal | **+0.022 ns** | video_clk → video_clk | fast | `view_reader/engine/local_fault_reg_syn_1105.clk` → `local_fault_reg_syn_1164.sr` | 异步复位释放，**= 全局 HWNS** |
| recovery | **+0.501 ns** | video_clk → ext_mem_clk | slow | `frame_read_write_m0/frame_fifo_read_m0/sel2_syn_201.clk` → `read_buf/asy_w_rst1_reg_syn_5.sr` | 同一路径也是该组 Max WNS 0.501 |

hold/removal/recovery 的最坏值都出现在 **视频/HDMI 与帧缓冲复位** 相关逻辑；全局最坏 setup 位于 `sd_card_clk` 的 WAV 解析链，另一失败簇位于 `ext_mem_clk` 的显示供数链。四类中只有 setup 存在负 slack。

### 3.1 `+0.022` 全局 HWNS 的归属（关键澄清）

* `video_clk → video_clk` 组 `Min` 段落的**第一条**（排序即最差）就是 slack `0.022`、`Check Type = removal`，起点 `view_reader/engine/local_fault_reg_syn_1105.clk`，终点 `local_fault_reg_syn_1164.sr`；
* 该组 `Min HWNS = 0.022`；其它组最小为 `0.032`（sd_card）；
* 因此 **全局 `HWNS 0.022` 是 removal 检查，不是 hold**。若把 removal 剔除，hold 类最坏是 `+0.024`。
* `+0.022` 是异步控制释放相对时钟的 removal 检查正余量，不是数据 hold 或 recovery 余量；余量很小但不是零，也没有实板失效证据。

### 3.2 显示路径（video_clk / HDMI）当前真实状态

* `video_clk` 自域 setup：**+2.231 ns**（40 ns 周期的 5.58%），最差路径为 26 级（含 MULT18、fanout 65 的网络，数据路径 37.626 ns）。
* `video_clk → hdmi_5x_clk`：+2.910；`hdmi_5x_clk` 自域：+4.427 / hold +0.446。
* 显示域 hold 最差 +0.024（HDMI 音频 sample packet FIFO → BRAM），removal 最差 +0.022（view_reader fault 标志的异步复位释放；第二条 0.022 同样落在 `u_w96_d1024_fifo`）。
* video_clk 自域所展示的 hold 24 ps、removal 22 ps 均为小幅正余量；本报告未规定额外工程裕量门槛，不把它们当作零或负值。

---

## 4. 最坏 Setup：起终点域与"直接组合链"结构

**域**：起点、终点**同为 `sd_card_clk`**（rise@0, period 10 ns），`Budget 10.000 ns`，**不是 CDC**，是单周期内的纯组合深链。

**路径**：

```
wav/parser/file_length_reg[2]_syn_10.q[0]
  → 16 级 LUT（Level 1..16）→ wav/parser/chunk_space_reg[31]_syn_4.a[1]
```

* `Logic Level 16 (LUT5=13, LUT4=2, LUT3=1)` —— **全 LUT，无 BRAM/DSP/carry/寄存器中断**；
* `Data Path Delay 15.531 ns = cell 7.820 (50%) + net 7.711 (50%)`，即**单元与布线各占一半**，不是单纯布线问题；
* 该链经过 `wav/parser/chunk_outside_n66/n62/n58/n54/n50/n46/n42/n38…` 一串中间网，逐级串接（每级 LUT 输出接下一级输入），是典型的**宽位比较/优先级链被综合成串行 LUT 链**；
* `Arrival 21.982` vs `Required 16.199`（launch latency 6.451 + 捕获沿 10.000 + 6.053，含 setup -0.116 / uncertainty -0.100 / pessimism +0.362）→ `Slack -5.783` 自洽；
* 同一 begin 点还驱动 `chunk_space_reg[*]`、`chunk_outside_reg` 多位（第二条 -5.759），说明是**一个扇出锥**而非单点。

**第二簇**（`ext_mem_clk`，211 EP）：最差 -5.565，`view_reader/head_reg[23]` → `view_reader/engine/request_buffer_addr_reg[20].a[1]`，`Logic Level 32 (LUT5=21, LUT4=6, LUT3=4, DRAM=1)`，32 级且含分布式 RAM 读出。

**失败集中度**（仅统计被展示的路径，见 §10 截断说明）：`sd_card_clk` 组展示的负 slack 端点集中在 `wav/parser`（47 条）与 `sd_card_bmp_m0/bmp_read_m0`（42 条）；`ext_mem_clk` 组集中在 `view_reader/engine`（98 条）。被展示的 255 条负 slack 明细分布为：`< -4 ns` 30 条、`-4~-2` 50 条、`-2~-1` 111 条、`-1~-0.5` 25 条、`-0.5~0` 39 条 —— 即**少数 -5.8/-5.6 的深链拖尾 + 一大片 -1~-2 ns 的轻度超时**。

---

## 5. 面积：MSLICE / LSLICE 的真实来源（Root 说法需修正）

**`final_area.rpt` 里没有 `MSLICE`/`LSLICE` 字段**（全文无该 token）。它给的是 LUT/FF/LE 口径：

```
#lut 17533 / 19600 (89.45%)   #reg 9638 / 19600 (49.17%)   #le 17822
  #lut only 8184   #reg only 289   #lut&reg 9349
#bram 64/64 (100%) + #bram32k 16/16 (100%)   #dsp 20/29 (68.97%)   #pll 2/4   #gclk 2/16
```

MSLICE/LSLICE 只出现在 route 日志与 `route.qor`：

| 证据 | 数值 |
|---|---|
| `RUN-1001 : 4527 mslices, 4527 lslices …`（place 内 Stage 2.8 打包） | 4527 |
| `RUN-1001/PHY-1001 : 4542 mslices, 4542 lslices …`（**route 日志最后一次出现**，route 开始打印） | **4542 / 4542** |
| `route.qor`：`#slices 9084`，`slices percentage 92.69%` | 9084 = 4542+4542 |
| 反推容量 | 9084 / 0.9269 = **9800** → 4900 MSLICE + 4900 LSLICE，各 **4542/4900 = 92.69%** |
| LE 密度校验 | 17822 LE / 9084 slice = **1.962 LE/slice**（满配 2 LE/slice，即 slice 内 LE 已近 100% 占用） |

**"hold 修复后是否变"——不变，且有字节级证据**：
`hx4s20_basic_phy.area`（route 阶段写，mtime **23:04**，早于 `fix_hold`）与 `final_area.rpt`（**23:06**，bitgen 之后）**sha256 完全相同**（`280e6b85…`）。
即 `fix_hold` 之后 **LUT/FF/LE 计数一个都没变**，slice 占用自然仍是 4542/4542。
这与修复日志一致：33 个端点全部由 **pin delay**、最后 1 个由 **net delay** 修复，属于**布线层 ECO**，不新增逻辑单元。
（`LutBridge` 阶段打印 `Bridge count = 32`，但修复前后时序未变、面积逐字节相同，可判定其未产生净资源增量；这是本次审计唯一无法从报告字段直接量化、只能由"面积文件逐字节相同"反证的点。）

因此：**MSLICE 4542 / LSLICE 4542 / 合计 9084 slice = 92.69%**，hold 修复后未变；但请注意该数字**不是** `final_area.rpt` 提供的，引用时应注明来源为 `route.qor` + route 日志。

资源压力判断：BRAM 已 **100%**（64/64 BRAM9K + 16/16 BRAM32K）、slice 92.69%、LE 90.9%，这正是 TD 在 route 阶段拒绝自动 hold 修复的直接原因（>90%）。

---

## 6. Hold 修复过程的完整性（这条时间线很关键）

| 时刻(本地) | 事件 | HWNS / 违例 |
|---|---|---|
| 23:04:46 | route 阶段自带 `phy_1/final_timing.rpt` | -0.044 / HTNS -0.450，18 H-EP |
| route 内 Stage 3 | `Slice utilization … higher than 90%, hold fixing is skipped.` | 未修 |
| 23:04:5x | `route.qor`：Hold WNS **-44 ps**，HTNS -450 ps，**18 违例端点** | -0.044 |
| 23:05:04 | TD 存 `best_result/hx4s20_basic.bit`（**修复前**比特流 `f94654e6…`） | — |
| 23:05:31 | harness `before_hold_fix.rpt`（open_run + `update_timing -mode final`） | -0.044 / -0.450 |
| 23:05:31–55 | harness 调 **独立 `fix_hold`**：目标 33 端点（worst -44 ps，best +189 ps）→ LB 32 bridge → **pin delay 33/33** → 剩 1 个 -11 ps → **net delay 1/1** | 逐步 -0.044 → -0.011 → **+0.022** |
| 23:05:53 | `after_hold_fix.rpt` | +0.022 / 0.000 |
| 23:06:05 | `bitgen` → `phy_1/hx4s20_basic.bit` = **交付 bit** | — |
| 23:06:11/12 | `final_timing.rpt` / `final_area.rpt` / `check_timing.rpt` | +0.022 |

要点：

1. **"hold fix 被跳过"是 TD route 内建步骤**（利用率 >90%），但 harness 之后用**独立 `fix_hold`** 实际修了 33 个端点，两者不要混为一谈；
2. 修复**只把余量做到 +22 ps**（最后一条 removal 由 net delay 从 -11 ps 抬到 +22 ps），**没有留任何 sign-off 余量**；且被修端点里 best slack 已达 +189 ps，属于"顺带过修"，说明工具目标是"刚好不违例"；
3. `after_hold_fix.rpt` 与 `final_timing.rpt` **仅时间戳不同**（逐行 diff 只有 `Generated` 一行），证明最终报告就是修复后的同一数据库；
4. 交付 bit 与修复前 `best_result` bit **不同**（2666 B 差异），证明交付物确实是 ECO 之后的比特流，不是旧档。

---

## 7. 覆盖率与约束缺口（影响"时序已收敛"这一结论的边界）

来自 `check_timing.rpt`（独立读取）：

* `STA coverage 99.96%` —— 仍有 0.04% 端点未覆盖，报告未逐点列出。
* **20 个输出端口没有 output delay**：`HDMI_CLK_P`、`HDMI_D0_P/D1_P/D2_P`、`HDMI_DDC_SCL/SDA`、`seg_data[7:0]`、`seg_sel[5:0]`。
  → **HDMI TMDS 外部发送时序完全没有被 STA 约束/验证**；报告里的 `hdmi_5x_clk` 大余量只覆盖芯片内部到末级寄存器/串化器输入，不含 PAD→引脚→线缆。
* **5 个输入无 input delay**：`HDMI_DDC_SDA`、`key1..3`、`rst_n`（准静态，可接受）。
* **1 个输入仅部分约束**：`sd_miso`（`-clock_fall`，配合 multicycle 4/7）。
* **32 条 "abnormal set_input_delay"**：全部是 `U3/sdram.dq[*]` 同时写了 `-fast`/`-slow` 的 max/min（reference_pin = `U3/sdram.clk`），工具判为异常写法；SDRAM 读捕获窗口的建模可信度需另行确认。
* **5 个 dangling 节点**（2×BRAM32K dob[9]、若干 LSLICE 输入脚）。
* critical warning：`U3/sdram` 位置约束多次未被遵守；`sys_pll_m0/…clkc[2]` 走 local routing（`PHY-5079`）。
* `ignored_timing.rpt` 的 Min 侧例外（均为 Dominated，非 Ignored）：`set_false_path -hold primary_addr_gray→sync_r1` 两条约束各覆盖 **18** 个端点（24.700 / 9.700，共 36），另 9 个端点由 reset 同步器 hold 例外覆盖（CDC 格雷码/复位同步，合理）。
* `exceptions.rpt`：`set_multicycle_path 4`（setup）与 `7`（hold）对 `sd_miso` / `sd_mosi,sd_ncs` 的匹配数分别为 **0** 和 **2** —— SPI 的 multicycle 基本没有命中实际端点，SPI 接口时序实际靠 IO delay 约束兜底。

**结论边界**：芯片内部寄存器到寄存器时序（除已列失败项）可认为已核；**HDMI 输出接口、SDRAM 读捕获、0.04% 未覆盖端点** 不在"时序通过"的证据链内。

---

## 8. 与 Root 初步结论逐条对照

| Root 说法 | 核验 | 说明 |
|---|---|---|
| SWNS -5.783 / TNS -324.923 / 304 失败端点 | ✅ 全部复现 | 304 = 93(sd) + 211(ext)，与 route QoR 一致 |
| "显示路径纯 hold +0.024" | ✅ 成立 | hold 最坏 0.024，确在 HDMI 音频 FIFO→BRAM；显示 setup +2.231，不缺 |
| "recovery +0.501" | ✅ 数值正确，**归属需补** | 组是 `video_clk → ext_mem_clk`（frame_fifo_read 复位同步），不是 video 自域 |
| "removal +0.022" | ✅ 数值正确 | 但它是 **全局 HWNS 的来源**；端点是 `view_reader/engine/local_fault`，不是显示路径 |
| "+0.022 全局 HWNS 包含 removal" | ✅ 确认，且**就是 removal** | hold 最低 0.024；5 个空组 0.000 是占位，勿误读 |
| "route 日志末期 4542 MSLICE" | ✅ 正确 | 但 `final_area.rpt` 无此字段；`route.qor` 记 9084 slice / 92.69%；修复后**未变** |
| 失败端点在显示路径 | ❌ 需修正 | 失败全在 `sd_card_clk`（wav parser/bmp read）与 `ext_mem_clk`（view_reader），显示域无负 slack |
| hold 修复"可能改变面积" | ❌ 未改变 | 修复前后 area 文件逐字节相同；ECO 仅 pin/net delay |

---

## 9. 残余风险（按优先级）

1. **hold/removal 余量 22–24 ps**：属于"工具刚好收敛"，未含 PVT/老化/电源噪声余量；且 hold 修复被利用率挡住、无法再抬。若需量产级把握，应把 video_clk 域 hold 目标余量显式设到 ≥0.1–0.2 ns 再修（本次未做，也不在本审计范围）。
2. **setup 违约 304 端点（TNS -324.9 ns）**：`sd_card_clk` 实际 Fmax 63.4 MHz（约束 100）、`ext_mem_clk` 32.7 MHz（约束 40）；这是功能级不收敛，不是"边缘擦过"。
3. **HDMI 输出无 output delay**：外部显示接口未被验证，`hdmi_5x` 余量不能外推到引脚/线缆。
4. **SDRAM 输入延迟写法异常 + U3 位置约束未遵守**：读捕获窗口可信度存疑。
5. **BRAM 100% 占用**：后续任何逻辑改动都可能无法布局。
6. **0.04% 端点未覆盖** 与 5 个 dangling 节点。

---

## 10. 审计局限（明示）

* 未运行 TD/未重建，所有数字来自既有报告与日志；**不验证工具本身正确性**，只验证"报告内部自洽 + 报告与交付物一致"。
* 报告明细按 `128 paths / 组` 截断：sd 组仅展示 127 条、ext 组仅 128 条负 slack 明细（分别对应 76 / 68 个不同终点引脚），**按明细清点会远少于统计的 93 / 211 个失败端点**；本报告一律以 `Statistics` 行与 `route.qor` 为准（两者互相吻合）。
* MSLICE/LSLICE 无最终报告字段，采用 `route.qor` + route 日志 + "修复前后面积文件逐字节相同"的推断；若需绝对确认，只能在 TD 内重跑 `report_area`（本次禁止）。
* bit 哈希只证明**完整性/同一性**，不证明功能或硬件可用；`HARDWARE_PASS=false`、`HW=NOT_VERIFIED` 与本次结论一致。

---

## 11. 证据文件

```
bot_probe_infer_timing_audit/
├─ AUDIT.md                      本报告
├─ audit.json                    机器可读结论
├─ parse_timing.py               独立解析器（重解析 final_timing.rpt）
├─ make_evidence.py              证据生成器（算术校验/哈希/面积）
├─ reports/                      从 Windows 只读取回的原件
│   final_timing.rpt final_area.rpt check_timing.rpt ignored_timing.rpt exceptions.rpt
│   before_hold_fix.rpt after_hold_fix.rpt phy1_final_timing.rpt clocks.rpt timing.sdc
│   status.json artifacts.json stages.tsv inputs.json build.tcl stdout.log route.qor place.qor
│   parsed_timing.json parsed_before.json
├─ bit/
│   bot_hdmi_probe_infer_add_off_001.bit          (49c9eeab…, 交付物)
│   best_result_hx4s20_basic.bit                  (f94654e6…, 修复前存档)
├─ delivery/SHA256SUMS.txt, manifest.json
└─ evidence/
    checks.json groups.csv hashes.txt slices.json holdfix_timeline.txt
```
