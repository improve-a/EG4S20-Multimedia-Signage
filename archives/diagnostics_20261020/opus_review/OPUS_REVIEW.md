# NoBot 黑屏 · Opus 独立复核（2026-10-21）

状态：`ROOT_CAUSE_PARTIALLY_ISOLATED`（仅视频锁定链路层面）· 无生产 RTL 修改 · 无新位流 · `HARDWARE_NOT_TESTED`
`media_status_001` 维持 `DO_NOT_DEPLOY`。

## 1. 端到端依赖（共享项标 ★）

```
TF/SPI(sd100) → legacy_exhibit_media → wfifo → frame_fifo_write → SDRAM(mem40)
   → write_finish → frame_write_toggle_mem(mem40) → display_valid(sd100) → display_valid_sync(video25)
SDRAM → frame_fifo_read(mem40) → rfifo → video_delay.read_en(de_d[18]) → vout_data(×display_valid_sync)
color_bar → video_timing_data(2) → video_delay(21) → video_transition(1) → pixel_adjust(1) → OSD(5) → rgb_to_axis(1)
   → HDMI core: receiver FIFO + locked/pause FSM → TMDS encode → lane_lvds_10_1(125MHz) → ODDR
音频：audio_media(sd100, sd_ready&&display_valid★) → audio_output_mux(video25: WAV 或 tone) → core data island
★ rst_all → rs_sd / rs_mem / rs_video；★ video_clk 同时驱动视频与音频封包；★ display_valid 同时门控主图与 WAV 启动
```

## 2. 新的确定性事实（源码/网表）

1. **AXIS 源端时序是纯固定延迟。** `de/vs/hs` 从 color_bar 到 `I_axis_s_valid` 全程是无使能、无内容依赖的寄存器链（2+21+1+1+5+1 拍）；
   `rgb_to_axis` 不接收 ready。因此源端 valid 是确定的 640/800 × 480/525 光栅，与 SD/SDRAM/display_valid/CDC 无关。
2. **核心锁定 FSM（网表 LUT 解码，A/Probe/legacy 常量相同）：**
   `pause' = !locked && (sof || (!user && pause))`；`locked' = (user && pause) || (locked && (!sol || valid))`；
   `fifo_rst = core_rst | !locked`。未锁定时 `pause` **冻结核心自身 h 计数器**——即失锁期间 TMDS 输出时序停摆。
   这是“黑屏+无声”与“TPG 正常”同时成立的最直接机制：TPG 不经过此 FSM。
3. **彩条也黑**（绕过内容门控与 TF/SDRAM），而 TPG 正常 ⇒ HDMI 失效位于 `AXIS→锁定/FIFO→编码/串行` 段，
   与媒体链无关。B 有 OSD ⇒ B 的 HDMI 段正常，B 的缺陷在媒体段。**A/NoBot 与 B 是两个不同层面的故障。**
4. **B 的单一解释（未观测，候选）：** `display_valid=0` 同时造成 (a) 主图被 `vout_data` 门控成 0、OSD 仍叠加；
   (b) `audio_media.sd_ready=sd_ready_out&&display_valid` 不成立，`audio_output_mux` 停在 tone。
   用户所述“音频异常”若为持续提示音，即与此一致。首图未提交的上游原因未定位。

## 3. 实验 A 的 C/D：原因、后果还是伴随？

定向测试 `tb_cd_reach.v` / `tb_cd_negctl.v`（Icarus，`D:\FPGA\EG4S20-NoBot-Opus-20261021\review`）：
网表导出的 `mapped_receiver_control.v` + 真实光栅 + 核心 ready 方程 `ready'=!last&&(empty||ready)`，
`ready_seen=ready&&!pro_full`（pro_full 阈值未知，扫 16/64/不触发）。

| 用例 | locked | drops | C | D | max occ |
|---|---|---|---|---|---|
| 7 个首帧相位（10/170/35360/35390/35392/35464/200000） | 1 | 0 | 0 | 0 | 10 |
| pro_full=16、64 | 1 | 0 | 0 | 0 | 10 |
| 负控：第 2 帧起源端滞后 50 | 1 | 1 | 0 | 0 | 10 |
| 负控：源端领先 100 | 1 | 0 | 0 | 0 | 110 |
| 负控：源端领先 200 | **1** | **0** | **325128** | **509** | 210 |

结论：

- **在网表模型中，真实光栅下 C/D 不可达**；包括启动、首帧相位、行边界。上一轮 `HARDWARE_TEST_A_B` 第 1 问
  “启动/FIFO 初始填充/行边界可能产生单拍 C/D”**与模型不符**——这是此前遗漏的关键点。
- 唯一能产生 D 的机制：**锁定保持期间核心读侧落后源端 >160 拍（行消隐长度）**。锁定 FSM 只在 `sol` 采样 valid，
  看不到这种偏移，所以会“locked=1 但每行背压”。掉锁型偏移反而复位 FIFO，不产生 C/D。
- 源端为固定延迟且不响应 ready，偏移只能来自核心侧（h 计数器/pause/读窗）或瞬态。
  因此 **C/D 是后果/症状，不是原因**；它证明实板 A 至少一次出现了**与网表模型不一致**的 video_clk 域行为。
- 模型输入：`fix_round/axis/astra_reuse/mapped_receiver_control.v`，SHA-256 `299d61af…2825368`（网表衍生物，不入 Git）。
- 边界：控制模型复用 legacy 映射（A 的 LUT 常量已核对一致，逐 FF 等价未证）；ready 方程取自上轮报告，未重新提取；
  无 TMDS/加密核内部时序生成器。

## 4. 第二阶段：`media_status_001` 的 20 条 removal

- 端点：`rs_video/pipe[1]_dup_*` 的 SR（D=pipe[0]，SET/ASYNC，CLK=video）。SDC 例外
  `-to rs_video/pipe[*]` 的通配符不匹配 PNR 复制名，所以这些复制单元回到了正常 removal 检查。
- 语义：在 rst_all 解除的同一 video 沿，pipe[0].Q 仍为 1（刚被置位），复制单元无论“置位先解除”还是“仍被置位”
  都得到 Q=1；首个 0 只能在下一沿从 pipe[0] 传入。故**同步器入口 removal 违例不改变释放周期**，与原 pipe[1] 语义一致。
- 但这依赖“复制单元的 D 恰为 pipe[0]”这一端点事实；Root 已逐例核对 19/19，另 1 例为无 Q 负载的未用 FF。
- 建议（未执行，未改 SDC）：不要放宽通配符；应在综合/PNR 阻止该同步器复制（或在例外中用精确复制实例名），
  再重新签核。在此之前保持 `DO_NOT_DEPLOY`。**这 20 条不是原 NoBot 黑屏原因**（原 NoBot 无复制，STA 通过）。
- 附：四个已实测构建的 `*_exception.timing` 均未列出 `set_false_path` 条目（仅 max_delay/multicycle）。
  可能是报告格式所致，**未确认**；建议下一次 TD 会话用 `report_exceptions` 显式核对该例外实际覆盖端点。

## 5. 已检查但排除/未支持的方向

- `lane_lvds_10_1`：载入发生在与像素沿重合的 5× 沿，依赖 hold（报告 0.164/0.172 ns），无 clock uncertainty。
  这是设计薄弱点，但**四版结构与余量几乎相同**，不能解释成败分化；不作为根因，不改。
- 读侧 CDC：`read_addr_index` 实际只有 bit0 变化（BUF0/BUF1），单比特，不构成多比特撕裂。
- `wrusedw` 9/10 位宽不匹配：BURST_BITS=9 截断 rdusedw/wrusedw，但占用最大 511，不可达 512，无功能影响。
- 例外报告中未见 HDMI receiver / lane 路径被排除。

## 6. 修复

**未实施生产修复。** 没有找到“旧实现可复现反例 → 修复后消失”的设计缺陷链；按要求不做无依据修改。

## 7. 下一次最值得的实板验证（至多两项）

两项都**复用已有且 STA 通过的位流，不需新构建**；需用户另行授权 JTAG SRAM 下载。

1. **A（`rca_no_locked_003.bit`，SHA `cce44903…`）：记录显示器输入状态。**
   断电重上电后下载，读显示器的信息/OSD：“无信号 / 不支持 / 已识别 640×480@60”。
   - 无信号或不支持 ⇒ 核心输出时序不规则（pause 冻结、反复失锁），故障在锁定/时序生成侧。
   - 稳定识别 640×480 但黑屏 ⇒ 时序正常、锁定保持，指向上表“locked 但读侧偏移”或编码/像素内容侧。
   这一项把 A 的故障分到上面两类之一，此前 A 的测试只记了“黑屏”。
2. **B（`rca_locked_only_001.bit`，SHA `41848d20…`）：细分“音频异常”并延长观察。**
   等待 ≥60 s，记录声音是**持续提示音**、杂音/断续，还是静音；同时看主图区域是纯黑还是很暗的灰（转场遮罩色 `#151615`）。
   - 持续提示音 + 纯黑 ⇒ 支持 `display_valid=0`（首图未提交，WAV 从未被选中）。
   - 暗灰遮罩 ⇒ 支持 `fifo_fault` 触发、转场停在遮罩。
   - 杂音/断续 ⇒ 上述两者都不足，指向音频数据岛/时序。
   暗灰与纯黑肉眼不易区分，可用手机相机辅助，作为次要判据。

不建议再测原 NoBot（无观测点，结果已知）；不建议再加探针或换种子。

## 8. 对必答问题的简短回答

1. 遗漏：C/D 被当作可能的正常启动/行边界事件；模型显示真实光栅下不可达。另外此前没有把“A/NoBot（HDMI 段）与 B（媒体段）是两个故障”作为工作前提。
2. A 的 C/D：后果/症状，源端不响应 ready，不可能是原因。
3. B：最简解释为 `display_valid=0`，同时屏蔽主图并让音频停在 tone；未观测确认。
4. 未找到能解释 Probe 成功的共同设计缺陷。
5. 相关节点：`top_tf_hdmi_audio.v:388`（主图门控）、`:212`（WAV 启动条件）；锁定 FSM 网表单元 `O_video_locked`、`O_video_source_pause`、`u_w24_d1024_fifo/I_rst`；20 条 removal 端点 `rs_video/pipe[1]_dup_*`.sr。
6. 未实施修复。
7. 无新位流，因而无新 STA 通过的候选。
8. 见第 7 节两项。

状态汇总：`ROOT_CAUSE_PARTIALLY_ISOLATED`（HDMI 段机制收窄，未定位到具体电路）· 无 `OFFLINE_BUILD_PASS`/`TIMING_PASS` 新项 · `HARDWARE_NOT_TESTED`。
