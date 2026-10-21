# media_status_001 reset removal — 定向只读复核

日期：2026-10-21  
范围：只读 `builds/media_status_001` 的既有 gate/mapped/init_ignored、`netcheck/media_status_001`、B `netcheck/rca_locked_only_001`、Probe gate、`fix_round/sta_media_status_001.json`。未改 SDC/RTL，未构建，未上板，未重新导出完整 TD 过程。输出仅本目录。

## 0. 结论（先看这里）

1. **20 个 removal 负端点不是新的功能数据 hold。** 它们是 `rst_all_reg_reg_syn_10`（50 MHz reset 控制 FF 的复制/实现）到 `rs_video/pipe_reg[1]_syn_4..23.sr` 的 **异步 reset 解除（removal）入口**；同一设计的 **hold 类最小值是 +0.035 ns**（`class_minima.hold`），`-2.701/-37.661` 全部是 removal。
2. **20 个端点里只有 19 个是真正的第二级 reset 同步器复制 FF**：`_syn_5..23`，每个 `D=rs_video/pipe[0]`（`mi`），`Q=rs_video/pipe[1]_dup_5..23`，`SR=rst_all`，`clk=video_clk`，`REGSET=SET`，`SRMODE=ASYNC`，`SRMUX=SR`。**`_syn_4` 没有 Q**：它是一个 **LUT 单元 + 未使用 FF**（LUT 输出 `mux5_syn_2[19]` 参与 reset 控制），其 SR 是**悬空/未使用 FF 的 spurious removal 端点**。所以 20 = **19 个真实 stage1 复制 + 1 个 dead LUT/未使用 FF**。
3. **stage0 只有 1 个**（`extensions/osd/lt36_syn_36` 的 Q 中打包 `rs_video/pipe[0]`，SR=rst_all，D=0，clk=video）；**stage1 被 P&R 复制/分裂为 19 个真实 FF**。B 的 2FF 是**打包在同一个 LSLICE**；新 build 是**stage0 单 + stage1 复制**，没有出现新的逻辑第一/二级合并，没有 stage0 复制/分裂，没有额外 functional reset 未经同步；`rst_all` 的 SR 扇出是同一 net，未重新合并。
4. **既有 `set_false_path -hold -from [get_regs {rst_all_reg}] -to [get_regs {rs_sd/pipe[*] rs_mem/pipe[*] rs_video/pipe[*] frame_read_write...}]` 的 from 侧匹配到了 `rst_all_reg_reg_syn_10`，to 侧没有匹配 19 个 `pipe[1]_dup_*` Q 网。** B 的单一 2FF cell `rs_video/pipe_reg[1]_syn_4`（Q=`rs_video/pipe` 2 bit，含 stage0/stage1）在 B 的 `init_ignored.rpt` 中是被匹配的；新设计的 19 个 stage1 复制 Q 网被 P&R 改名为 `pipe[1]_dup_*`，`get_regs {rs_video/pipe[*]}` **不再匹配**，所以 20 个 removal 未被例外覆盖。
5. **这是“原 reset 例外未覆盖 P&R 复制后的 stage1 Q 网”的覆盖问题，不是新的功能数据路径违例。** 19 个真实 stage1 复制是合法的 async assert/sync deassert reset 入口；`_syn_4` 是 LUT/未使用 FF 的 spurious 端点，不应作为 reset 同步器豁免。**不为了 PASS 盲目加 false_path**；若未来处理，只可能覆盖 19 个 `pipe[1]_dup[*]`，不应覆盖 `_syn_4`；但本轮不改 SDC/RTL。
6. **与之前 Probe 敏感的直接实现机制**：B/Probe 的 2FF（stage0+stage1）打包在 **1 个 LSLICE**（Q=`rs_video/pipe` 2 bit）；新 build 被 P&R 拆成 **stage0 单 FF + 19 个 stage1 复制 Q 网**。这是新 build 唯一的 reset-tree 结构差异，可能引起 **reset release skew**，是 H2/H3 的合理候选；但 20 个 removal 只是该结构的 STA 暴露，**没有证据证明它导致 B 的功能状态**，hold 仍 +0.035，且没有功能 FF 被新增 reset 控制。**不建议仅凭这个负 removal 做 SDC/RTL 改动或第二个构建。**

## 1. 精确 primitive / 源节点

### 1.1 20 个 removal 端点（`negative_endpoints.txt`）

全部：

```
rst_all_reg_reg_syn_10.clk -> rs_video/pipe_reg[1]_syn_4..23.sr
```

- 19 个真实 stage1：`_syn_5..23`
- 1 个 dead/LUT：`_syn_4`（无 Q）
- 端点类型：`removal`（异步 reset 解除），不是 hold/setup。
- 起点：`rst_all_reg_reg_syn_10`（D=`rst_all_reg_n1`，Q=`rst_all`，clk=`clk_dup_1`，`SRMUX=0`，`REGSET=SET`；源 `top_tf_hdmi_audio.v(225)`）。它是 **reset 控制 FF**，不是同步器 stage；既有例外的 from 侧确实匹配到它（`init_ignored.rpt` begin point）。
- `rst_all` 源：`top_tf_hdmi_audio.v:156` `assign rst_all = rst_all_reg;`，fanout 48。

### 1.2 stage0（单一）

`extensions/osd/lt36_syn_36`（`EG_PHY_MSLICE`，packed）：
- `.q({rs_video/pipe[0], frame_read_write_m0/read_reset_sync[1]})`
- `.sr(rst_all)`, `.clk(video_clk)`
- `mi` 包含 `read_reset_sync[0]`；`pipe[0]` 的 FF D=0
- 源 `reset_sync.v:5`（该 MSLICE 同时打包了 OSD 的 LUT，源注释 `html_osd_overlay.v(403)` 是 packing 注释，不是功能 FF 名称）
- **stage0 只有一个；没有 stage0 复制/分裂。** `lt36` 的 SR 端点 `extensions/osd/lt36_syn_36.sr` 在 media_status_001 的 7 条 ignored path 中，**stage0 被既有例外覆盖**。

### 1.3 stage1 真实复制（19 个）

`rs_video/pipe_reg[1]_syn_5..23`（`EG_PHY_LSLICE`）：

| 端口/属性 | 值 |
|---|---|
| `D` | `rs_video/pipe[0]`（`mi`） |
| `Q` | `rs_video/pipe[1]_dup_5..23` |
| `SR` | `rst_all` |
| `clk` | `video_clk`（net 名 `extensions/osd/clk`） |
| `REG0_REGSET` | `SET` |
| `SRMODE` | `ASYNC` |
| `SRMUX` | `SR` |
| `REG0_SD` | `MI` |
| 源 | `reset_sync.v:5` |

**不是功能 data FF**：Q 是 reset 网；D 是 stage0；SR 是 raw `rst_all`；没有功能数据/控制进入 Q 路径。`a/b/c/d` 是同一 LSLICE 的 LUT 输入（用于邻近逻辑），**不是 FF D**；FF D 是 `mi=pipe[0]`。

**B 的对照**：B `rca_locked_only_001` 的 `rs_video/pipe_reg[1]_syn_4` 是一个 **Q=`rs_video/pipe`（2 bit，含 stage0/stage1）、D=`{pipe[0],1'b0}` 的 LSLICE**；即 B 把 **stage0+stage1 打包在同一个 cell**，其 SR 端点被 B 的 `init_ignored.rpt` 匹配。新 build 把 stage0 放到 `lt36`，stage1 拆成 19 个 `dup_*` cell；**不是逻辑合并/拆分，是 P&R packing 从 2FF 合一变成 stage0 单 + stage1 复制**。

### 1.4 `_syn_4`：名称误导的 LUT/未使用 FF

`rs_video/pipe_reg[1]_syn_4`（`EG_PHY_LSLICE`）：

- **无 `.q`**；`mi=rs_video/pipe[0]`；`SR=rst_all`；`clk=video_clk`；LUT 输出 `.f=mux5_syn_2[19]`。
- 该 LUT 输出参与 `rst_all_reg_reg_syn_10` 的 reset 控制（`.c(...mux5_syn_2[19])`），但该 cell 的 **FF 未使用**。
- 因此 `_syn_4.sr` 是 **未使用 FF 的 spurious removal 端点**；它不是 stage1 reset 同步器，不应按 reset 同步器豁免。
- 20 个端点里只有它一个 dead；19 个 `_syn_5..23` 是真实 stage1。

### 1.5 `_syn_1/_syn_2`：Root 精确查找更正

Root 使用完整primitive解析器按精确实例键复核：`_syn_1`、`_syn_2` 实际均不存在。此前摘录工具的子串匹配分别误命中了 `_syn_10`、`_syn_20`，不能作为物理别名证据。其余20个负端点已按精确键逐个验证，仍为19个stage1副本+1个无Q输出单元；stage0精确Q驱动仅一个。证据：Root `audit_reset_cells.py`、`root_reset_structure.json`。

## 2. gate → routed：复制发生在 P&R

`netcheck/media_status_001/gate.v`：

- gate 是 **2 个独立 FF**：`rs_video/pipe_reg[0]`（q=`pipe[0]_syn_3`）和 `rs_video/pipe_reg[1]`（q=`pipe[1]_syn_3`），都 `async_reg=true`。
- 没有 `pipe[1]_dup`，没有 20 个 `pipe_reg[1]_syn_*`。

`mapped.v`（P&R）：

- 19 个真实 stage1 Q=`pipe[1]_dup_5..23`；`_syn_4` dead LUT；`_syn_1/2` alias。
- `pipe[1]_dup_*` wire 属性：`/* synthesis async_reg=false */ /* synthesis preserve=true */`；
- 原 `rs_video/pipe` wire：`/* synthesis async_reg=true */ /* synthesis preserve=true */`。

**结论**：B 的 2FF 在 mapped 中打包成一个 LSLICE（Q=`rs_video/pipe` 2 bit，含 stage0/stage1）；新 build 被 P&R 拆成 **stage0 单 FF（`lt36`） + 19 个 stage1 复制**。stage1 复制不是 RTL 新增；复制后的 Q 网失去 `async_reg=true` 标记（变成 `async_reg=false`），但 `set_false_path` 是 **名字/对象匹配**，不需要假设工具用 `async_reg` 做例外判断；实际未匹配的直接原因是 Q 网名 `pipe[1]_dup_*` 不在 `rs_video/pipe[*]` 的匹配对象内。**stage0 的 `lt36` 仍被覆盖；stage1 的 19 个复制不被覆盖。**

## 3. 例外实际匹配

`init_ignored.rpt` 的 `set_false_path -hold ...`（media_status_001）：

- **from 侧匹配**：Begin Point `rst_all_reg_reg_syn_10`（7 条 ignored path 都是它）。
- **匹配到 7 个端点**：
  - `rs_mem/pipe_reg[1]_syn_4.sr`
  - `frame_read_write_m0/write_reset_sync_reg[1]_syn_3.sr`
  - `frame_read_write_m0/mem_reset_sync_reg[1]_syn_3.sr`
  - `extensions/osd/lt36_syn_36.sr`
  - `frame_read_write_m0/read_reset_sync_reg[0]_syn_3.sr`
  - `extensions/osd/lt37_syn_36.sr`
  - `frame_read_write_m0/mem_reset_sync_reg[0]_syn_3.sr`
- **没有**任何 `rs_video/pipe_reg[1]_syn_*`；但 `lt36_syn_36.sr` 是 **stage0**，已覆盖。
- B `rca_locked_only_001/init_ignored.rpt` 的 7 个端点中 **有** `rs_video/pipe_reg[1]_syn_4.sr`（B 的单一 2FF cell，Q=`rs_video/pipe` 2 bit，含 stage0/stage1）；新 build 没有，因为 stage1 Q 被改成 `pipe[1]_dup_*`。

**因此**：

- B 的 **2FF 单 cell**（stage0+stage1）被例外覆盖；新 build 的 **stage0 单 cell（`lt36`）仍被覆盖**，**19 个 stage1 复制 Q 网没有被覆盖**。
- 20 个负 removal 是 **既有 reset 例外未覆盖 P&R 拆分/复制后的 stage1 Q 网**；不是新 functional data hold，也不是 from 侧没匹配。
- 其中 19 个是合法 reset stage1 的 async assert/sync deassert 入口；1 个 `_syn_4` 是 LUT/未使用 FF 的 spurious 端点。
- **不为了 PASS 盲目加 false_path**；若要处理，覆盖对象应是 19 个 `rs_video/pipe[1]_dup[*]`（及同 Q 的 alias），不包含 `_syn_4`；但这是 STA 例外，不改变已生成位流的硬件 reset 结构。本轮不改 SDC/RTL。

## 4. 合法 reset 入口 vs 功能危险路径

- **合法**：19 个 `_syn_5..23` 的 `SR=rst_all` 是 2FF reset 同步器的 **async assert / sync deassert** 入口；D=`pipe[0]`，Q=reset 网；没有功能数据。
- **spurious**：`_syn_4` 的 FF 未使用；其 SR 端点不应作为功能 reset 路径。
- **功能危险路径**：没有发现新的功能 FF 被未同步 reset 直接控制；`rst_all` 的 `.sr` 端点（27 个）全部是 reset 同步器 stage（stage0/stage1）或 `_syn_4` 的未使用 FF；没有 functional data FF。
- 真正的数据 hold 最小值是 +0.035 ns；20 个负值是 removal；不能把 removal 负值当成数据 hold 或功能路径违例。

## 5. 与 Probe 敏感 / 结构约束

- **唯一新结构**：B 的 2FF（stage0+stage1）打包在同一 LSLICE（Q=`rs_video/pipe` 2 bit）；media_status_001 被 P&R **拆成 stage0 单 FF（`lt36`）+ 19 个真实 stage1 复制 Q 网**。stage0 仍 1 个，SR 仍同一 `rst_all`；没有 stage0 复制，没有逻辑第一/二级合并，没有额外 functional reset 未同步；**是物理 packing split + stage1 replication**。
- **可能的机制**：19 个 stage1 的 Q 网有不同 routing/负载，reset release 可能有 skew；这是 H2/H3 的合理实现敏感机制，也是与 B/Probe 的直接差异。**但 20 个 removal 只是 STA 覆盖暴露，不证明 skew 已导致功能失败；hold 仍 +0.035，且没有功能 FF 被新 reset 控制。**
- **必要结构约束错误？** 就“例外应覆盖 reset 同步器 deassert”这一意图而言，**to 侧覆盖不完整**：`rs_video/pipe[*]` 没有覆盖 `pipe[1]_dup_*`。这是覆盖/命名问题，不是功能数据路径。**不建议仅凭此扩大例外或做第二个构建**；若后续要研究 reset skew，应针对“是否允许 stage1 复制/是否保留单一 stage1”做结构决策（不得猜 attribute 支持），而不是用 false_path 掩盖。
- **对 media_status_001 状态诊断的影响**：20 个负值都是 removal，不影响 50 MHz `probe_display` 的状态采样功能；但新 build 的 reset tree 与 B/Probe 不同，若状态读出异常，reset release skew 是 confounder。

## 6. 证据

- `negative_endpoints.txt`：20 个端点/ slack / type。
- `mapped_cells.txt`：22 个 `pipe_reg[1]_syn_*` 的 Q/D/SR/clk/REGSET/SRMODE；`rst_all_reg_reg_syn_10`；stage0 context。
- `ignored_media_status.txt`：media_status_001 的 false_path 7 个端点 + 其他 ignored。
- `ignored_B.txt`：B 的 false_path 7 个端点（含 `rs_video/pipe_reg[1]_syn_4.sr`）。
- `gate_reset.txt`：gate.v 的单一 stage1/stage0 与 buffer。
- 原始：`D:\FPGA\EG4S20-NoBot-Fix-20261020\netcheck\media_status_001\{gate.v,mapped.v,init_ignored.rpt}`；`...builds\media_status_001\...`；B `D:\FPGA\EG4S20-NoBot-RCA-20261020\netcheck\rca_locked_only_001\{mapped.v,init_ignored.rpt}`；Probe gate `worker_a/b_gate.v` 或既有 gate DB。

## 7. 未做

- 未改 SDC/RTL/顶层，未构建，未上板，未重新导出完整 TD 过程，未增加 false_path。
- 未把 20 个 removal 当作功能 hold 或 pass 证据；未修改旧记录。
