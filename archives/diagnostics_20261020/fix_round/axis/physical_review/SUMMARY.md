# `!locked` → FIFO 指针异步复位：STA 定向复查摘要

- 范围：旧 NoBot / Probe / A / B 最终 routed `pr.db` + 已有 `final_timing.rpt`；只读 TD，未综合/PNR/bitgen，未改 RTL/SDC/IP，未硬件。
- 既有 `final_timing.rpt` 均**未包含** `O_video_locked → 视频 FIFO SR` 端点（四份均 0；受 128 EP/组限制）。
- 对 A/B 复制最终 `hx4s20_basic_pr.db`，只读 `report_timing_summary -ep_num 20000 -path_num 2`：
  - **A**：37 recovery/slow + 37 removal/fast；recovery slow min **+34.065 ns**，removal fast min **+1.971 ns**（worst endpoint `u_logic_ramfifo[3]__3_syn_4.sr`）。
  - **B**：27 recovery/slow + 27 removal/fast；recovery slow min **+34.144 ns**，removal fast min **+2.365 ns**（worst endpoint `u_logic_ramfifo[7]__6_syn_4.sr`）。
- 精确链：`O_video_locked_reg_syn_8.q[0]` → `O_video_locked`（A fo=6）/`probe/locked`（B fo=10）→ LUT2（A 打包在 `O_video_data_ch2_reg[6]_syn_4`，B `I_rst_syn_10`）→ `I_rst_dup_9`（A fo=55）/`I_rst`（B fo=48）→ FIFO 指针 `.sr`。**单 LUT2，无额外 FF/retiming**。
- A/B 的差异是打包/扇出/布局；A removal min 1.971 与 B 2.365 均正，已报端点全正，无负 slack。
- **覆盖限制**：TD summary 只列 recovery/slow 与 removal/fast，不是四角逐项；39 个 SR 端点中 A 报 37、B 报 27；A/B STA coverage 99.93/99.92%。旧/Probe 目标端点未精确查询，**不能外推**。
- **物理风险**：FIFO 指针 FF `SRMODE="ASYNC"`、`sr=I_rst`；正 slack 不等于无亚稳态/MTBF；复制分支到达差未动态验证。无硬件/无误判旧核 reset 失败。
- 没有精确反例；没有新位流建议；原根因仍未知。

完整数据、起终点、四角/覆盖说明、DB/报告哈希见 `fix_round/axis/physical_review/REPORT.md`。
