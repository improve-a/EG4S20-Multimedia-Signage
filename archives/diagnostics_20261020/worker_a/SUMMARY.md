# Worker A 摘要（勘误版）
## NoBot 黑屏 vs HDMI Probe：已检查端点未发现功能差异；全等价未证

日期：2026-10-20　范围：离线只读；用 TD 导出 gate DB 副本，未运行综合/PNR/bitgen、未碰硬件。勘误补充阶段未再运行 TD。

---

## 1. 勘误（优先阅读）

1. **最终时序以 `runs/<id>/final_timing.rpt` 为准**，其时序指标与 `after_hold_fix.rpt` 一致（并非声称文件哈希相同）；`phy_1/final_timing.rpt` 与 `phy_1/route.qor` 是 hold fix **之前**的快照：
   - A：`runs/no_bot_legacy_004/final_timing.rpt` = **SWNS +0.813 ns / HWNS +0.022 ns**（`SHA256 65DF375B…`），与 `after_hold_fix.rpt` 一致；
     `phy_1/final_timing.rpt` = +0.813 / +0.019（旧），`before_hold_fix.rpt` = +0.813 / +0.019。
   - B：`runs/hdmi_probe_001/final_timing.rpt` = **+0.039 / +0.030**（`SHA256 BFF93F0A357478C5…`，与冻结 `reports/final_timing.rpt` 相同）；
     `phy_1/final_timing.rpt` = +0.039 / +0.011（旧）。
   - **撤回“文档 hold +0.030 与报告不一致”的说法**：`HARDWARE_PASS_BASELINE.md` 是正确的，是我读错了文件。
2. **gate 映射阶段（`hx4s20_basic_gate.timing` / `gate.qor`）的 `Confidence: Synthesized`**，其 setup −0.659/−0.649 ns 是映射后估算，不是 post-route 签核值；不应与最终时序混用。
3. 结论措辞收窄：**“已检查端点未发现功能差异；全等价未证”**，不再说“整个视频音频网表等价”或“所有差异只有观测”。已知未证项见第 5 节。
4. 删除“2–3 个 seed 重跑 P&R”实验建议（用户明确禁止）。且即使换 seed 成功，也只能说明实现敏感，不能单独排除未定义初值/启动类设计问题。

---

## 2. 核心计数（映射网表，TD `write_verilog` 导出）

| 项 | A（黑屏） | B（成功） |
|---|---|---|
| `AL_MAP_SEQ` 总数 | 6242 | 6463 |
| 完全同名同引脚 | — | 6035 |
| 仅引脚网名不同 | — | 174 个单元 / 175 处引脚 |
| A 独有 | 33 | — |
| B 独有 | — | 254 |
| gate `#reg` / `#lut` | 6324 / 9776 | 6569 / 10002 |
| phy `#reg` / `#lut` | 6323 / 10054 | 6572 / 10257 |

B 独有 254 = probe 95 + probe_display 93 + FIFO 读指针同步/占用 21 + ready 1 + `hs_d[20:0]` 21 + last/x_cnt 12 + osd 5 + color_bar 2 + timing 2 + adjust 1 + transition 1。

A 独有 33 = OSD `b3/g3/body_base` 24（B 并入 MSLICE，非删除）+ 数码管状态 8 + SD 1（打包位置变化，未展开）。

---

## 3. 关键节点

- **HDMI 发送核子树**：A 1529 / B 1551 FF；1466 个完全相同，0 删除，+22（ready 1 + FIFO 读指针同步 21）。63 个仅网名不同（62 个 `audio_valid` 相关 + 1 个 locked）。
- **HDMI PHY**：47/47 FF 完全相同；LUT 形状 12/10/10/2 相同。
- **AXIS 数据**：`O_video_data_reg[0..23]` 的 `clk=extensions/osd/clk`、`d=I_rgb[i]`、`sr=acr/I_rst`、`q=I_axis_s_data[i]` **两版逐字相同**。
- **FIFO**：`ceb=I_fifo_rd_en_syn_8`、`addra/addrb/dia/dob/rsta/rstb` 两版网名逐字相同；A 的读写通路未因 ready 悬空被削弱。
- **tlast**：该配置展开后的 mapped 锥未使用该端口（两版都没有 `I_axis_s_last` 网；接口声明里确实有输入）。A 中 `O_video_last`/`S_x_cnt` 被删 = 常量 0，不等于“曾经功能错”。
- **ready**：A 无 ready 逻辑；B 有 `S_video_in_ready_reg` + 21 个读指针同步 FF + 只在此版出现的 `S_fifo_wr_num[10:0]` 占用计算。均为观测/状态输出，不改变 FIFO 读写。
- **O_video_locked**：同一 FF 两版都存在；A 的 Q 网 `u_hdmi…/O_video_locked` 只有 3 个核内负载（反馈等），B 改名为 `probe/locked` 并多出 7 个探针/显示负载。
- **黑场门控**：`display_valid_sync[1] ? vout_data_raw : 0`，24 个 LUT2（INIT=4'h8）同名同参数同引脚。
- **音频**：`pcm` 90/90、`acr` 47/47、`audio_output` 1/1、audio sample packet 142/142 FF 相同；`audio_valid` 与 `acr/I_audio_valid` 同网异名。
- **复位/时钟**：`rs_video` 2 FF、`pipe_reg[0/1]` 参数与网名逐字相同；`video_rst=acr/I_rst`；GCLK 2、PLL 2、BRAM/DSP 数量相同。

---

## 4. 有界真值表检查（已做，仅两处）

用现有 `a_gate.v`/`b_gate.v` 在远端 Python 穷举（脚本 `cone_tt.py`）：

| 锥 | 变量 | LUT | 结果 |
|---|---|---|---|
| `O_video_user` 的 D（A `…/S_frame_arm_i_syn_4`，B `…/O_video_user_n`） | 3：`I_de`、`I_axis_s_valid`、`S_frame_arm` | 1×LUT3 | 8 种输入**完全相同** |
| `O_video_locked` 的 D（两版同网 `…/O_video_locked_reg_syn_3`） | 5：`I_video_source_sol`、`O_video_locked`、`O_video_source_pause`、`I_axis_s_user`、`I_axis_s_valid` | 1×LUT4/5 | 32 种输入**完全相同** |

边界：只对这两个组合锥、以叶节点为自由输入成立；不覆盖任何时序行为，也不代表其它锥已证。

---

## 5. 明确未覆盖 / 未证

1. **没有 SAT/形式等价**；“全设计等价”未证。
2. `wav/parser` 373→373 LUT，其中 **38 个 LUT 形状不同，未逐位验证**。
3. `sd_card` 的 A 独有 1 个 FF（`sd_card_sec_read_write`）**未展开**其功能等价性。
4. OSD `b3/g3/body_base` 24 个 FF 移入 MSLICE 只做了 1 处（`b3[4]`）逐点核对，**未全部证明**。
5. “同名 FF 的 D 网名相同”**不等于其驱动锥逻辑必然相同**；本报告只把它作为强相关证据，不作为证明。
6. 加密 HDMI 核内部 RTL 不可见，结论来自 TD 展开后的门级网表。
7. 未做 post-route 网表对比；未运行任何时序查询；本报告不给出时序根因结论。

---

## 6. Root 两个实验的检查方法（脚本已备）

基线与预期（`obs_check.py`）：

| 检查项 | 现 B 基线 | 实验 A：`Probe.locked(1'b0)` | 实验 B：`flags_async={23'd0,flags[4:0]}` |
|---|---|---|---|
| `probe/locked` 网 | 存在，10 个负载 | 应不存在；`O_video_locked` 仅剩 3 个核内负载 | 同基线 |
| `probe_display/status_meta_reg` | 31 | **30**（bit0 常量 0，该 FF 可能被删） | **应为 8**（bits 30:28 与 4:0 保留；27:5 常量 0） |
| `probe_display/status_sync_reg` | 31 | **30** | **应为 8** |
| `probe/flags` 被引用位 | 1,3,4,6..26 | 同基线 | **只应见 4:0**（display 侧不再引用 27:5） |

- 若实验 A 后 `probe/locked` 仍存在或 `O_video_locked` 仍有探针负载 → 观察锥未被真正移除，实验无效。
- 检查实验 B 时应看 flags 高位的实际消费端，不能仅以同步 FF 数量判断是否移除（见下面 Astra 实测勘误）。
- 另注：实验 A 只是去掉 locked 的探针观测；**A 原 NoBot 位流里 locked 的 FF 本来就存在**（本报告已证），因此该实验若仍黑屏，应进一步降低 H1（“locked 悬空导致功能被删”）的权重。

**Astra 实测补充（两项 fresh 构建后）：** 上表 31→30/8 的 FF 数量预测未发生；两版都仍是 31/31，因为原模块对整个 `status_meta/status_sync` 数组带 `preserve="true"`。实验 B 的 `status_meta_reg[27:5].d` 已全部是 `1'b0`，高位不再连接真实观察信号；ready/TLAST/x计数及帧/行观察计数确已删除。实验 A 的 locked 仅剩原有 3 个核内负载，Probe locked 网不存在。因此两实验观察边界改动有效，保留常量显示同步 FF 不等于仍有功能信号观察负载。证据：Root `observer_fanout.txt`、`preserved_status_pins.txt`、`netcheck.txt`。

可复用脚本（本地 `worker_a/`，可 scp 到远端）：

| 脚本 | 用途 |
|---|---|
| `ps/export_gate_v.ps1` + `ps/export_gate_v.tcl` | 对任意 `gate.db` 副本只读导出 `gate.v` |
| `fanout.py gate.v NET [--outside HIER]` | 打印某网驱动与全部消费引脚，可标出层次外负载 |
| `obs_check.py gate.v` | 上面那张表的自动检查（status FF 数、flags 位引用、locked 精确负载） |
| `netcmp.py summary/seq/net/const` | primitive 统计、按层次 FF 清单、常量统计 |
| `cone_tt.py A.v B.v NET_A NET_B` | 小锥真值表穷举 |
| `ffsum.py` / `subtree.py` / `seqdiff.py` | 全设计/子树/逐层次 FF 差异 |
| `brampins.py` / `luthist.py` | FIFO BRAM 连接 / LUT 形状对比 |

> 说明：`ps/export_gate_v.ps1` 只做 `import_device` + `import_db` + `write_verilog`，不执行 optimize/place/route/bitgen；请在 scratch 目录对 .db **副本**运行，不要指向原构建目录的输出。

---

## 7. 结论

- 在两个实验关心的端点上（AXIS data/valid/user、FIFO 读写、黑场门控、音频、复位时钟、locked 的 D 锥），**未发现 A/B 的功能差异**。
- 已检查的差异均为：观测保留（HS/last/ready/探针）、数码管状态删除、FF 打包、网名别名。
- **但全设计等价未证**；上述第 5 节的未证项在最终结论中必须保留。
- 黑屏根因仍未由本报告定位；本报告只把“mapped 逻辑层确定性功能错误”这一假设的证据强度降低，不排除实现/启动/未定义初值等问题。
