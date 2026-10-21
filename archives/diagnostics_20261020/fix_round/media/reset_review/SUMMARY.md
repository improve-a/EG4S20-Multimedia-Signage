# reset_review SUMMARY

- **20 个 removal 负端点**全部是 `rst_all_reg_reg_syn_10`（50 MHz reset 控制 FF 的实现复制）到 `rs_video/pipe_reg[1]_syn_4..23.sr`；**不是数据 hold**（class hold min **+0.035 ns**，负值全是 removal）。
- **19 个是真实 stage1 reset 同步器复制**：`_syn_5..23`，D=`rs_video/pipe[0]`，Q=`pipe[1]_dup_5..23`，SR=`rst_all`，clk=video，REGSET=SET，SRMODE=ASYNC。
- **1 个是 dead/LUT**：`_syn_4` 无 Q，是 LUT 单元 + 未使用 FF（LUT `mux5_syn_2[19]` 参与 reset 控制）；其 SR 是 spurious 端点，不是 stage1。
- **stage0 只有 1 个**（`lt36`，Q 含 `pipe[0]`，SR=rst_all），**stage1 被 P&R 拆/复制为 19 个**；没有 stage0 复制，没有新的逻辑第一/二级合并，没有额外 functional reset 未同步；`rst_all` SR 扇出为同一 net。
- **例外匹配**：from 侧匹配 `rst_all_reg_reg_syn_10`；to 侧 `rs_video/pipe[*]` 未匹配 `pipe[1]_dup_*`。B 的 2FF 打包在 **1 个 LSLICE**（Q=`rs_video/pipe` 2 bit，含 stage0/stage1），B 的 `init_ignored` 有 `rs_video/pipe_reg[1]_syn_4.sr`；新 build 的 7 条 ignored 没有 19 个 stage1 复制，只有 stage0 的 `lt36` 等。
- **结论**：这是“原 reset 例外未覆盖 P&R 拆分/复制后的 stage1 Q 网”的覆盖问题；19 个是合法的 async assert/sync deassert reset 入口，`_syn_4` 是 dead LUT/未使用 FF。**不为了 PASS 盲目加 false_path**；本轮不改 SDC/RTL，不因此做第二个构建。
- **与 Probe 敏感**：唯一新结构是 **2FF 从单 LSLICE 拆成 stage0 + 19 个 stage1 复制**；可能引起 reset release skew，是 H2/H3 的合理实现候选，但 20 个 removal 只是 STA 暴露，**没有证据证明它导致 B 的功能状态**；hold 仍 +0.035。

证据：`mapped_cells.txt`、`negative_endpoints.txt`、`ignored_media_status.txt`、`ignored_B.txt`、`gate_reset.txt`。
