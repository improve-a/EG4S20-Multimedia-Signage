# `!locked` → FIFO 指针异步复位：路由后 STA 定向复查

**范围**：只读已有最终 routed `pr.db`/`final_timing.rpt`；未综合、未 PnR、未 bitgen、未改 SDC/RTL/IP、未硬件。
**本轮对象**：旧 NoBot `no_bot_legacy_004`、完整 Probe `hdmi_probe_001`、实验 A `rca_no_locked_003`、实验 B `rca_locked_only_001`。
**结论先行**：A/B 的路由后精确报告都能找到 `O_video_locked` FF Q → `I_rst` LUT2 → 视频 FIFO 指针 `.sr` 的 recovery/removal 路径，**已报告路径全部正 slack**：A recovery slow 最小 **+34.065 ns**、removal fast 最小 **+1.971 ns**；B recovery slow **+34.144 ns**、removal fast **+2.365 ns**。未发现负 slack、未发现该路径中插入/重定时寄存器。但 TD 的 summary 只列出 recovery/slow 与 removal/fast 两种组合（39 个 SR 端点中 A 报 37、B 报 27），**不是四角全签核**；旧 NoBot/Probe 的既有 `final_timing.rpt` 未包含该端点，未做旧/Probe 精确查询，因此旧/Probe 的这条路径 **未签核**。没有精确反例；不能据此宣称硬件不会亚稳态，也不能据此把旧核 reset 路径判失败。

---

## 1. 方法：先查既有报告，再只对缺端点做精确报告

### 1.1 既有 `runs/<id>/final_timing.rpt`

四个最终报告头部均为 `Confidence: Routed`、`Check Corner: Both (Slow and Fast)`。扫描所有 recovery/removal path block，查找：
- Begin 含 `O_video_locked_reg_syn_8`；
- End 含 `u_w24_d1024_fifo` 且 `.sr`。

结果（`existing_coverage.py` / `existing_coverage.json`）：

| 构建 | final_timing.rpt SHA-256 | blocks | recovery | removal | 目标 locked→FIFO SR |
|---|---|---:|---:|---:|---:|
| 旧 NoBot `no_bot_legacy_004` | `65df375b3db8c01848786164e8eabef5d24b36cb77e4ce7359b1d140c3f5cf87` | 1815 | 36 | 143 | **0** |
| 完整 Probe `hdmi_probe_001` | `bff93f0a357478c59c5bc88f45e062615b6aff8b6047d6ed0aafc0acb94849df` | 1862 | 36 | 140 | **0** |
| A `rca_no_locked_003` | `9e91bb2a8519499dcd496f02921cbe8d39df1d0f745d6a2c1feafaaaab703728` | 1852 | 36 | 125 | **0** |
| B `rca_locked_only_001` | `b029a3a6f53c0ae746819ecabd072cb02ee1a6e0a415aba8898f2eb026357b4c` | 1819 | 36 | 146 | **0** |

默认报告受 `128 end point(s) per path group, 2 path(s) per end point` 限制；**0 不表示路径不存在**，只表示该端点未进入默认报告。故 A/B 需要精确报告。

### 1.2 精确报告（只读 DB 副本）

把 A/B 最终 `phy_1/hx4s20_basic_pr.db` 复制到 `D:\FPGA\EG4S20-NoBot-Fix-20261020\physical_review\`，只执行：

```tcl
import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
report_timing_summary -file A_all_endpoints_p2.rpt -ep_num 20000 -path_num 2
exit
```

命令参数取自本地 `SWUG105_TCL_Command_User_Guide` §4.8：`report_timing_summary [-file][-ep_num][-path_num]`（文档页 74/80），未猜 flag。`report_timing_path -from` 在本 TD 6.2 上对打包寄存器返回 `TMR-6526 Failed to find any valid -from targets`（`get_regs/get_pins -o` 也被报 `invalid option`），故改用文档支持的 `report_timing_summary` 高 `ep_num` 全端点报告，再从报告中按起终点过滤；这不是新综合/PNR。

| 精确报告 | 大小 | SHA-256 | STA coverage | SWNS/HWNS |
|---|---:|---|---:|---:|
| `A_all_endpoints_p2.rpt` | 219,435,325 | `76c3aacbac63360fddc5509ac8f2a3d56120bfa236e8cbbc88488022625f7b48` | 99.93% | +0.423/+0.024 ns |
| `B_all_endpoints_p2.rpt` | 217,508,209 | `1b33ae22736a59740cc07ffb2beae3b83ed9c6de8acf3366aa07e5f5e2904b86` | 99.92% | +0.106/+0.027 ns |

DB 输入哈希：

| 构建 | 最终 `hx4s20_basic_pr.db` SHA-256 | 大小 |
|---|---|---:|
| 旧 NoBot | `a4012ee561d4081e2983a3478db0cbcf67b2dff021508d80745c410656005b8b` | 7,995,610 |
| 完整 Probe | `622d8ee4f5a78bbe5cd910da224561df6306e4f42549aec6f91e2d243c641a46` | 8,158,528 |
| A | `b4d69bfdf3b1345f9dff2de46281ea0e60e68c750671b949a470b4d1ab6f16e3` | 8,133,844 |
| B | `279b0ee6354871390a71156b85bf98601a4d4e1b61ada7c24027c0295271f467` | 8,083,930 |

A/B 的副本 `physical_review/{A,B}_pr.db` 与上表 A/B 哈希一致；旧/Probe 只读原文件，未复制 DB。

---

## 2. 精确起终点与路径（A）

### 2.1 起终点链

TD 报告把 Begin Point 写成 `O_video_locked_reg_syn_8.clk`（寄存器时钟脚），但 path detail 的 **数据 launch** 是同一单元的 `q[0]`：

```text
Begin (report): u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.clk
Data launch:    .../O_video_locked_reg_syn_8.q[0]
  net:          u_hdmi_1_4b_transmitter_core_wrapper/O_video_locked  (A: fanout 6)
  LUT2:         .../u_hdmi_video_data_assemble/O_video_data_ch2_reg[6]_syn_4.f[0]   // packed I_rst = A|~B
  net:          .../u_w24_d1024_fifo/I_rst_dup_9  (fanout 55)
End:            .../u_w24_d1024_fifo/u_logic_ramfifo[...].sr
```

A 中该 LUT 被打包进 `O_video_data_ch2_reg[6]_syn_4`（OSD/data 共享 slice），不是原先 gate 名 `I_rst_syn_7`；这是**物理打包/扇出复制**，路径中仍是单个 LUT2，没有插入 FF/retiming。

### 2.2 A worst recovery（Slow）

```text
Slack               : +34.065 ns
Check Type          : recovery
Process             : slow
Begin Point         : .../O_video_locked_reg_syn_8.clk   (data launch q[0])
End Point           : .../u_w24_d1024_fifo/u_logic_ramfifo[10]__0_syn_3.sr
Data Path Delay     : 5.399 ns (cell 0.483 / net 4.916)
Clock Skew          : 0.136 ns
launch edge         : 0.000 ns
capture edge        : 40.000 ns
recovery            : -0.300 ns
clock uncertainty   : -0.100 ns
clock pessimism     : +0.275 ns
Required            : 46.049 ns
Arrival             : 11.984 ns
Slack               : +34.065 ns
```

### 2.3 A worst removal（Fast）

```text
Slack               : +1.971 ns
Check Type          : removal
Process             : fast
Begin Point         : .../O_video_locked_reg_syn_8.clk   (data launch q[0])
End Point           : .../u_w24_d1024_fifo/u_logic_ramfifo[3]__3_syn_4.sr
Data Path Delay     : 2.432 ns (cell 0.312 / net 2.120)
Clock Skew          : 0.108 ns
removal             : +0.253 ns
clock uncertainty   : -0.100 ns
clock pessimism     : -0.211 ns
Required            : 4.888 ns
Arrival             : 6.859 ns
Slack               : +1.971 ns
```

A 报告共 **37 recovery/slow + 37 removal/fast** 目标路径；recovery min `+34.065`，max `+36.013`；removal min `+1.971`，max `+3.279`。全为正。

---

## 3. 精确起终点与路径（B）

B 的同一链走 `probe/locked`，LUT 名为 `I_rst_syn_10`：

```text
Begin (report): .../O_video_locked_reg_syn_8.clk
Data launch:    .../O_video_locked_reg_syn_8.q[0]
  net:          \probe/locked   (fanout 10)
  LUT2:         .../u_w24_d1024_fifo/I_rst_syn_10.f[1]   // I_rst = A|~B
  net:          .../u_w24_d1024_fifo/I_rst  (fanout 48)
End:            .../u_w24_d1024_fifo/u_logic_ramfifo[7]__6_syn_4.sr
```

B worst removal（fast）：

```text
Slack               : +2.365 ns
Check Type          : removal
Process             : fast
Data Path Delay     : 2.763 ns (cell 0.398 / net 2.365)
Clock Skew          : 0.045 ns
removal             : +0.253 ns
clock uncertainty   : -0.100 ns
clock pessimism     : -0.274 ns
Required            : 4.825 ns
Arrival             : 7.190 ns
Slack               : +2.365 ns
```

B recovery/slow 最小 `+34.144 ns`（endpoint `u_logic_ramfifo[2]__4_syn_4.sr`）；报告共 **27 recovery/slow + 27 removal/fast**，removal max `+3.326`，全为正。

A/B 的路径差异来自：
- A 的 locked 负载 6、I_rst 扇出 55；B 的 `probe/locked` 负载 10、I_rst 扇出 48；
- A LUT 打包在 `O_video_data_ch2_reg[6]_syn_4`，B 在 `I_rst_syn_10`；
- 不是逻辑/retiming 改变；是布局、打包和扇出复制差异。

---

## 4. 四角/覆盖边界（必须准确读）

- TD 的 `report_timing_summary` 报告头写 `Check Corner: Both (Slow and Fast)`，但对这些异步 SR 端点，**实际列出的目标路径只有**：
  - A：recovery / slow（37 条）、removal / fast（37 条）；
  - B：recovery / slow（27 条）、removal / fast（27 条）。
- **没有列出 recovery/fast 或 removal/slow 的目标路径**。因此这不是四角逐项表；只能证明已报告的 recovery-slow 与 removal-fast 正 slack。全局 SWNS 正（A +0.423、B +0.106）说明**所有被 STA 纳入分析的路径**（含未列出的同端点其它 corner，若被分析）没有负 slack；但它不等于四角全签核，也不覆盖未约束/ignored 路径。
- `get_pins -o *u_w24_d1024_fifo*.sr` 在 A 返回 **39 个 SR 端点**；A 报告列出 37 个端点（recovery/removal 各 37 条），B 列出 27 个端点。**端点级覆盖不完整**：未列出的 SR 端点没有逐端点正 slack 证据；只有全局正 SWNS 的间接界限。缺失端点清单未逐项枚举。
- A/B STA coverage 99.93%/99.92%；不是 100%。旧/Probe 默认报告目标 0，未做精确查询，**旧/Probe 的这条路径不在本轮签核范围**。

**旧 NoBot / Probe**：默认 `final_timing.rpt` 中没有目标路径（0/0/0/0）；按用户“最多一两个查询进程”的约束，本轮只对 A/B 做了精确全端点报告，未对旧/Probe 复制 DB 重跑。因此旧/Probe 的这条 `locked→FIFO SR` 路径 **exact signoff = not obtained**，不能从 A/B 外推。

---

## 5. retiming / 物理复制 / 异步 deassert

- **没有 retiming/插入 FF**：A/B 的 Q→SR 数据路径都是 `q[0] → net → LUT2 → net → .sr`，逻辑级 1，没有中间 `AL_MAP_SEQ`。A/B 的 LUT 函数仍是 `~(B*~A) = A|~B`（gate 证据），只是物理 cell/打包不同。
- **物理复制/扇出**：A `O_video_locked` fanout 6，`I_rst_dup_9` fanout 55；B `probe/locked` fanout 10，`I_rst` fanout 48。A/B 的多个 SR 分支由同一 LUT 输出复制/布线，路径延迟有差异（A removal slack 1.971–3.279，B 2.365–3.326），但每个已报端点正 slack。
- **异步 deassert（Root术语更正）**：`O_video_locked` 是 FF Q，launch 在 `video_clk`；`I_rst` LUT 输出直接进 FIFO 指针 FF 的 **SRMODE=ASYNC / sr**。recovery与removal都约束异步控制的**解除**相对有效时钟边沿的间隔，分别类似setup/hold；removal不是reset assertion检查。对这里高有效reset，拉低是解除。A/B最小removal +1.971/+2.365ns、recovery +34.065/+34.144ns。**静态正slack不等于完整动态/硅验证**；本轮没有负slack反例，也没有证明所有复位/时钟波形均正确。
- **BRAM**：视频 BRAM `RESETMODE("SYNC")`，但指针/地址 FF 是 `SRMODE("ASYNC")`；所以“见 .sr 就说异步”在本路径上成立，且已核对物理 `SRMODE="ASYNC"`，不是只看端口名。

---

## 6. 结论与界限

1. **有直接证据**：A/B 最终 routed DB 中存在 `O_video_locked` FF Q → `I_rst` LUT2 → 视频 FIFO 指针 SR 的 recovery/removal 路径；已报告端点全正 slack；没有 retiming/额外 FF；A/B 差异是布局/打包/扇出，不是功能改写。
2. **没有精确反例**：A/B 的 37/27 个已报告目标端点均正；未发现负 slack。旧/Probe 默认报告不含该端点，未做精确查询；因此**不能**说旧/Probe 也没有问题，也不能说四角全通过。
3. **四角/覆盖不完整**：只报告 recovery/slow 与 removal/fast；39 个 SR 端点中 A 报 37、B 报 27；未列出的端点没有逐端点证据。要完成四角签核，需要另做 per-check/per-corner 精确报告或补充查询；本轮不做（遵守查询进程限制）。
4. **物理风险仍开放**：异步 deassert 的静态 slack 正，不代表无亚稳态/MTBF；复制分支到达差 ~1.3 ns（A）/0.96 ns（B）未做动态验证；没有硬件。
5. **不新增位流建议**；不把本报告当修复或根因确认。原根因仍未明；`media_status_001` 的 rawSTA_FAIL 与旧 A/B 因果未证，本报告不使用它推断旧核 reset 路径失败。

---

## 7. 文件、命令、哈希

本地 `fix_round/axis/physical_review/`：

| 文件 | 内容 |
|---|---|
| `REPORT.md` | 本报告 |
| `SUMMARY.md` | 短摘要 |
| `A_worst_recovery_block.txt` / `A_worst_removal_block.txt` | A 最差 recovery/removal 完整 path block |
| `B_worst_removal_block.txt` / `B_worst_recovery_block.txt` | B 最差 removal/recovery block |
| `A_target_summary_p2.txt` / `B_target_summary.txt` | 目标路径 JSON 行 + SUMMARY |
| `A_locked_fifo_sr_paths.json` / `B_locked_fifo_sr_paths.json` | 74/54 条目标路径结构化结果 |
| `existing_coverage.json` | 四份 final_timing 的目标端点计数（均 0） |
| `query_all_A_p2.tcl` / `query_all_B_p2.tcl` | 只读 TD 查询脚本 |
| `existing_coverage.py` / `parse_target_paths*.py` / `find_target_block*.py` | 只读解析脚本 |

远端大报告保留在 `D:\FPGA\EG4S20-NoBot-Fix-20261020\physical_review\`：
`A_all_endpoints_p2.rpt`（219,435,325 B，SHA `76c3…7b48`）、`B_all_endpoints_p2.rpt`（217,508,209 B，SHA `1b33…4b86`）；未复制到 Mac，避免堆积大报告。

**TD 命令**（文档 SWUG105 §4.8，未猜 flag）：

```text
import_device eagle_s20.db -package EG4S20BG256
import_db {.../A_pr.db 或 B_pr.db}
report_timing_summary -file ..._all_endpoints_p2.rpt -ep_num 20000 -path_num 2
exit
```

**输入/报告哈希**见 §1.1/§1.2。没有新综合/PNR/bitgen；没有改生产 SDC/RTL/IP；没有硬件操作。
