# fix_round/media — SUMMARY（交付用）

日期：2026-10-20  
Worker：B / DS Flash1017  
范围：只读源码/网表；新增 `fix_round/media/` 下的短 TB、脚本、日志、报告；未改生产 RTL/约束/顶层，未构建，未上板，未启动子 Agent。

## 事实

1. **源码级 B 与成功 Probe 的媒体/commit/audio/SD RTL 逐字节相同**；B 的唯一功能改动是 `top_tf_hdmi_audio.v:344` `.flags_async({23'd0,probe_flags[4:0]})`。A 的唯一功能改动是 `:342` `.locked(1'b0)`。其余差异是 ROM/OSD 的 `INIT_FILE` 绝对路径。
2. **B 的最终 STA 没有媒体/commit/audio 负 slack**：`video_clk` 自域 9.956/0.027，`sd_card_clk` 自域 0.106/0.030，`sd_card_clk→video_clk` 5.775/0.073，`video_clk→sd_card_clk` 7.096/0.167，`ext_mem_clk→video_clk` 2.573/0.092。最薄 setup 是 WAV parser `0.106 ns`（只影响音频，不经过主图/`display_valid`）。
3. **B 的状态/故障不可观测**：B 的 mapped 网表中 `display_state/state_code50/state_code_sd` 均为 0；页 2–4 与页 5 的 audio/heartbeat 是人为 0。B 读不到 `display_valid/state_code/fifo_fault/audio_valid/wav_status`。
4. **B 的可见症状**：真实 `locked=1`、OSD 可见、主图缺失、音频未细分。OSD 在 `vout_data` 之后注入，所以 OSD 可见只证明下游（HTML overlay/AXIS/TMDS）活着；主图在 `display_valid` 门控、`video_transition` mask 或 SDRAM 读回这一级被抹掉。
5. **音频 tone 不能归为 WAV 坏**：`audio_output_mux` 只在 `wav_status==2/3/5` 选 WAV；首次选中前是 tone，选中后 error/EOF 保持 WAV（静音/保持）。首次 WAV 从 LBA0 扫到 16491 约 6 s，前 ~6 s 的 tone 是设计内行为。
6. **A 与 B 不默认同根因**：A 的 OSD 也缺失，且 C/D=1；A 的 page 2/3 显示 VS/DE/HS 活动和 AXIS valid 活动正常。A 至少多一层（OSD/transition/下游）。

## 行为/覆盖边界（不是已确认缺陷）

- **B1 fail-stop fault**：`fifo_fault` 三域 sticky OR，一旦置位不可清除；`tb_fr_fault` 只证明“发生即保持”，**没有证明合法正常工作时会误触发**。不据此加清除/重试。
- **B2 模块 reset 契约**：`audio_async_fifo` 单边 `rd_rst` 会重放旧数据（`tb_audio_fifo_rdc`），但实际 top 的共同 `clear/flush` 序列（`tb_audio_fifo_seq`，power-up + WAV restart，释放偏移 0/20/200/400 ns）32 字精确通过、`level=0`；**当前 top 可达序列未触发，不修它冒充修 B**。
- **B3 观察范围**：B 的 `flags[27:5]` 置 0 是本次观察变体的限制，不是产品 RTL 错误；它导致 B 不能定因。
- **B4 fail-stop 错误处理**：单次 `response_error/loader_error/sd_init_error` → 永久 `FAILED`；CRC 错误即可触发。**未证明合法正常工作时会误触发，不加重试/吞错。**

## 短测（实际执行）

| 测试 | 结果 |
|---|---|
| `tb_commit_chain`（5 相位点 + 5 LOAD 偏移，至多 10 例） | 全部 PASS；首帧 cover/commit ack、`active_buf` 正确；fault 后 mask=0x151615 且不再 ack。**不是 5×5=25 个交叉组合，也不是全 CDC 证明。** |
| `tb_fr_fault` | 人为一次 underflow 后 `fifo_fault` 保持 2000 个 read clock；只证 fail-stop 行为。 |
| `tb_audio_mux` | status 1→tone；2/3→WAV；0xd/0xe→仍 WAV。 |
| `tb_audio_fifo_seq`（0/20/200/400 ns） | 建模的实际共同 reset/flush 序列中32字顺序正确、`level=0`；这些受测序列未触发F2，不是全部可达性证明。 |
| `tb_audio_fifo_rdc` | 契约外单边 `rd_rst` 重放 1000；level=18，不作为 fault/虚报结论。 |

## 结论

- **没有找到能证实 B 的、可修的生产 RTL/CDC 逻辑错误**；也没有证据表明 B1/B4 在合法正常工作时误触发。
- B 的具体状态仍不可判：`display_valid=0` 与 sticky `fifo_fault` 两条链都能解释可见症状；现有数码管无法区分。
- **唯一建议的下一步**：Root 计划的 B 派生 **状态观察变体**（不改功能通路/卡/PHY，复用 31 位双 FF/5 页），把 `flags[27:5]` 换成 23 位状态字。最小位、实际源码编码、5 页映射、四类问题解码见 `REPORT.md` §7。
  - 关键：`state_code[3:0] + catalog_ready + display_valid + fifo_fault + sd_init_done + Sdr_init_done + wav_status[3:0] + wav_selected + wav_error/underflow/overflow + active_view[5:0]` 正好 23 位。
  - `catalog_ready` 是消歧关键：`catalog_ready=0` 时 `1/2/3/4/14` 是 scanner 码；`=1` 时 `1/2/3/4/5/8/9/A-F` 是 legacy 码。`8` 是 IDLE+auto，不是 SCAN；`0` 不应读成 SCAN。

## 边界

- commit 只做 10 例、audio reset 只做 4 个释放偏移；**不是全 CDC/全相位证明**。
- 未做完整 media+SD+loader 全系统仿真、门级形式等价、上板、照片/录音；本报告不含顶层/模块代码。
- B 的音频是 tone/静音/WAV 未细分；不归为 WAV 数据坏。A/B 不同根因未定。

## 路径

- 报告：`fix_round/media/REPORT.md`
- TB：`fix_round/media/tb/{tb_commit_chain,tb_fr_fault,tb_audio_mux,tb_audio_fifo_seq,tb_audio_fifo_rdc}.v`
- 结果：`fix_round/media/out/*.log`、`netlist_counts.txt`、`source_diff.txt`
- 远端临时输出：`D:\FPGA\EG4S20-NoBot-Fix-20261020\media\`
