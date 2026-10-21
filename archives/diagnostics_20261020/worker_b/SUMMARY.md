# Worker B 摘要（Root review 后更正版）

> 详细数据、路径原文与脚本索引见 `REPORT.md`；本文件只列**事实**与**假设**，并明确哪些初版推论已撤回。

## A. 事实（有直接证据）

1. **位流**
   - FAIL `phy_1` = `61874e4f…a2fc7`；PASS `phy_1` = `bbb83a71…f618`，与冻结件逐字节一致（677348 B）。
   - 两版 `best_result` 位流都与 `phy_1` 不同且早于 HOLD_FIX，不是被测镜像。
2. **约束/引脚**
   - `timing.sdc` = `93d101bd…4051`，`pin.adc` = `ae389336…b6c1`，两版相同。
3. **WNS 归属**
   - 全局 `0.813 / 0.039` 都是 **sd_card_clk 域**：
     FAIL `wav/parser/pos_reg[30] → state_reg[1].ce`（D=8.907，K=0.064）；
     PASS `loader/timeout_count_reg[9] → sample_x_reg[4].ce`（D=9.609）。
   - video_clk 时钟表 `2.525/2.756` 是 **`ext_mem_clk→video_clk` recovery**；
     hdmi_5x_clk `3.156/2.248` 是 **`video_clk→hdmi_5x_clk` recovery**；都不是数据 setup。
   - 数据 setup：video 域内 **9.578 / 4.493**；5x 域内 **4.974 / 4.933**；video→5x **6.296 / 6.179**。
4. **串行捕获**
   - hold 最薄 `S_odd_even`：**0.164 / 0.172 ns**（组内最薄，不是全局最薄）。
   - 报告路径：pixel 到达 `6.585 ns`（PLL 4.175 + BUFG 2.410），5x 到达 `6.174 ns`（PLL 4.008 + 局部网 2.166）。
   - 5x 不经 BUFG；局部网 fanout 33/32、skew 0.480。两版在该报告路径上同值。
5. **报告条目受上限**
   - `128 EP/path group × 2 path/EP`；31/31/21/22、256、172、38 都是**可见条目**，不是全量路径数。
6. **全局最薄**
   - TD 全局 `HWNS 0.022` 是 hold/removal 合并口径；报告条目中对应 clk 的 **removal**。
   - 按 Check Type 拆分，纯 hold 报告条目最小 **0.032**；未进入报告的路径不受 128EP×2 保证。
7. **HOLD_FIX**
   - 改写 DB/bit，hold 余量改变（`+0.019→+0.022`、`+0.011→+0.030`）；fix 前后不是同一物理实现。
   - 仅“报告级”的 setup WNS、R-period、fanout、skew、时钟表数值未动。
8. **彩条构建（关键新证据）**
   - 诊断位流 `hdmi_colorbar_diag_001.bit` = `f5408a72…e83`（633116 B）；冻结 source zip 563189 B，`62784790…478ca`。
   - top 第 448 行 `hdmi_colorbar_source … .i_de(fx_de) .o_rgb(diagnostic_rgb)`；
     第 451–456 行 RGB→AXIS 适配器 `.I_vs(fx_vs) .I_de(fx_de) .I_rgb(diagnostic_rgb)`。
   - 因此彩条**绕过** `display_valid` 0 门、OSD 与 transition 遮罩，且不依赖 TF/SDRAM；只借用 `fx_vs/fx_de`。
9. **约束覆盖**
   - 20 个输出无 output delay（4×TMDS、2×DDC、14×seg）；TMDS 4 ns UI/lane skew 未签核。
   - `sd_miso` 有 input delay：`sd_spi_clk`（前向 DCLK，÷8=12.5 MHz）`-clock_fall` 16/0 ns + multicycle 4/7。
     `partial input delay` 只是参考沿/极性口径。
10. **复位**
    - 两份 routed 的 removal 全为正：全局最小 `+0.022`（clk）；video 内 `+0.035`；
      `rs_video→lane ODDR.rst` `+0.678/+1.098`；`rs_video→lane shift.sr` recovery `3.156/2.248`。

## B. 假设（未定，需判读）

- **H1**：NoBot loader 未首次提交/fault 锁死 → `vout_data=0` + WAV 关闭。仅对 NoBot；彩条已排除。
- **H2**：`rst_all`/`video_rst` 未释放或 video PLL 无时钟 → 无 TMDS、无 tone。若彩条“有信号”成立则基本排除。
- **H3**：`S_odd_even` 同相捕获滑移 → 10 位字移 2 位 → TMDS control/DC 失衡 → 可黑屏/静音。
  彩条绕过内容门仍黑，使 H3/H4 权重上升；但两版余量只差 8 ps，无直接滑移证据。
- **H4**：`axis_s_ready` 悬空、源不遵守反压 → 丢像素/island 包。彩条同样不接 ready。
- **H5**：SD 卡/接触/内容。仅 NoBot；彩条不依赖 TF/SDRAM。

> 彩条与 NoBot 是不同位流，不能证明同一根因；但彩条把**它自己**的故障边界压到 RGB→AXIS 之后。

## C. 初版已撤回/降级的推论

1. “所有外部像素源都经过 `display_valid` 0 门” → **错**，彩条绕过（E-1）。
2. “`sd_miso` 是错误 clock relation” → **撤回**，改为外部 launch/内部 capture 的覆盖/预算限制（E-2）。
3. “两版路径数/结构相同” → **撤回**，只是相同 report scheme 下的可见条目（E-3）。
4. “`S_odd_even` 是全设计最薄 hold” → **错**，0.164 是组内最薄；全局 HWNS 0.022 是 removal，纯 hold 最小 0.032（E-3）。
5. “HOLD_FIX 没有改变实现” → **错**，DB/bit 与余量都变了（E-4）。
6. “同一报告时钟延迟 ⇒ 全网逐点相同” → **降级**为仅该路径的到达/站点相同（E-4）。
7. “TMDS 2-bit 移位必然仍有图像” → **撤回**，持续移位可致失锁/黑屏/静音（E-5）。
8. 3-seed/额外构建建议 → **删除**；用户禁止，仅保留授权实验与离线核查（E-6）。

## D. 离线后续（不要求上板/换卡/构建）

- O1（已完成）：彩条 source zip 的 top 注入点核实（见事实 8）。
- O2（可选）：`legacy_exhibit_media`/`frame_read_write` 故障注入仿真，固化 H1 的可观测签名。
- O3（可选）：独立 DB 拷贝导出 4 条 lane 的 ODDR/走线，估算 clock-to-data skew（仅辅助 H3）。
- O4（判读已有记录）：NoBot 数码管码、彩条“有信号/无信号”；有信号 → H3/H4，无信号 → H2 也进入候选。
