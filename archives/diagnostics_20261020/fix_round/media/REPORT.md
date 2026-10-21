# fix_round/media — B 媒体/音频根因边界报告

日期：2026-10-20  
Worker：B / DeepSeek V4.1 Flash 1017  
范围：只读源码与网表；新增 `fix_round/media/` 下的 testbench、脚本、报告；未改生产 RTL/约束/顶层，未构建，未上板，未启动子 Agent。  
结论级别：**没有找到能证实 B 的唯一 RTL/CDC 逻辑错误，也没有证据表明 fail-stop 在合法正常工作时误触发**。只确认了观察范围限制和若干行为/覆盖边界；commit/cover 只做了 10 个边界用例，不能排除所有 CDC；B 的音频“异常”**可能是**设计内的 fallback tone（首次启动约 6 s），不能当作 WAV 损坏证据；是 tone/静音/WAV 需用户细分。

---

## 0. 结论摘要

1. **B 的“主图缺失 + OSD 可见 + 声音异常”落在 OSD 之前的内容/门控链**，不是 TMDS/HDMI 锁定的问题：B 的真实 `locked=1`，OSD 可见证明 `fx_*`、HTML overlay、AXIS、TMDS 至少都在工作。主图在 `vout_data`/`video_transition`/SDRAM 读回这一级被抹掉，OSD 在其后注入，所以 OSD 仍可见。
2. 能把这三件事**同时**解释的最短链条是 `display_valid=0`：
   - `top_tf_hdmi_audio.v:388` `vout_data = display_valid_sync[1] ? vout_data_raw : 0` → 主图为纯黑（前提是 transition 仍在 IDLE；若已 cover 则是 `0x151615` 的 mask）；
   - `top_tf_hdmi_audio.v:192-195` OSD 在 `vout_data` 之后、独立于 `display_valid` → 品牌/字幕/`01/06` 仍可见；
   - `top_tf_hdmi_audio.v:212` `audio_media.sd_ready = sd_ready_out && display_valid` → WAV 客户端根本不启动，`audio_output_mux` 选 tone（`ext/audio_output_mux.v:10-21`），听到的是 262–523 Hz 的 8 音循环，而不是 WAV。
3. 另一条同样能解释 B 的链条是 **`fifo_fault` sticky 后 `video_transition` 把主图永久替换为 `MASK_COLOR=0x151615`**（`ext/video_transition.v:69-70, 111-112`）。它同样保留 OSD，并且 `legacy_exhibit_media` 会锁到 `FAILED`，页号停在 `01/06`。**B 的现有数码管无法区分这两条。**
4. **commit/cover 边界短测**：真实 `display_commit` + `video_transition`，video 25 MHz / sd 100 MHz，做了 **5 个相位点 + 5 个 LOAD 偏移、至多 10 个用例（不是 5×5=25 个交叉组合）**；首帧 cover ack、首帧 commit ack、`active_buf=1` 均一次成功，fault 后第二次 commit 不再 ack。**这只能说明该模型源/这些相位点没有丢脉冲，不能宣称排除所有 CDC 问题。**
5. **行为/覆盖边界（不是已确认的 RTL 缺陷；不据此加容错、清 sticky 或改重试）**：
   - **B1 fail-stop fault**：`frame_read_write` 的 `fifo_fault = wr_overflow | rd_underflow | mem_fifo_fault` 是三个域各自 sticky 的 OR（`SD/frame_read_write.v:100-112`），一旦置位没有运行时可清除路径；`display_commit`/`video_transition`/`legacy_exhibit_media` 都把它当作永久 fault。`tb_fr_fault` 只证明“一旦发生就保持”，**没有证明合法正常工作时会误触发**。
   - **B2 模块 reset 契约（当前 top 不可达）**：`ext/audio_async_fifo.v` 的 write/read 两侧 reset 独立同步（`:26-39`）；单独 `rd_rst` 会重放旧数据。但实际 top 的共同 `clear/flush` 序列在 `tb_audio_fifo_seq` 中通过（见 §4），**当前不可达序列不构成 B 的缺陷**，也不应单独修它冒充修 B。
   - **B3 观察范围**：B 把 `probe_flags[27:5]` 全部置 0（`B/.../top_tf_hdmi_audio.v:344`），`display_state`/`state_code50` 在 B 的 mapped 网表中出现 **0 次**；B 的页 2–4 和页 5 的 audio/heartbeat 都是人为 0。**这是本次观察范围的限制，不是产品 RTL 错误；但它使 B 的 `display_valid/state_code/fifo_fault/audio_valid/wav_status` 不可读，是当前不能定因的直接原因。**
   - **B4 fail-stop 错误处理**：`legacy_exhibit_media.v:157-160` 对**单次** `response_error`/`loader_error`/`sd_init_error` 直接 `state<=FAILED`，无重试；`sd_card_cmd.v:221-223` 的 CRC16 错误即可触发。**这是 fail-stop 行为/覆盖边界；没有证据表明合法正常工作时会误触发，因此不建议加重试或吞错。**
6. **B 的“声音异常”不能直接归为 WAV 坏**：`audio_output_mux` 只在 `wav_status==2/3/5` 时选 WAV；在首次选中之前一直选 tone；一旦选过 WAV，后续 error/underflow（0xd/0xe）**保持 WAV 选择**（`tb_audio_mux` 验证），不会退回 tone。所以听到 tone 反而说明 WAV **从未被选中**（display_valid=0、首次扫描未完成或扫描失败），而不是“WAV 数据坏了”。WAV 在 LBA 16491，`audio_media` 从 LBA0 逐扇区扫描，**首次**启动有约 6 s 的 tone 前奏（`bot_probe_media_audit/05_dump_docs.out`），所以前 ~6 s 听到 tone 是**设计内行为**。注意：一旦 `wav_selected` 置 1，EOF 重启/重扫期间它**保持 1**（`audio_output_mux` 只在 video_rst 清零），此时听到的是静音/保持样本，不是 tone。
7. **A 与 B 不能默认同根因**：A 的 OSD 也不可见，而 `display_valid=0` 仍应显示 OSD；A 的 page 2/3 又显示 `frame_good=1` 和 AXIS user/last 活动正常。A 的失败至少多一层（OSD/transition/下游），本轮不把 A 的结论转移给 B 或反之。

---

## 1. 精确证据边界

### 1.1 本地可读源码

`rca_ab_sources/{Probe,A,B}/work/design/user_source/hdl_source/`，三份同名 `.zip`。  
`diff -r Probe A` 与 `diff -r Probe B` 的功能差异（过滤 `INIT_FILE`/构建绝对路径）只有：

- A：`top_tf_hdmi_audio.v:342` `.locked(1'b0)`（Probe 为 `.locked(probe_video_locked)`）。
- B：`top_tf_hdmi_audio.v:344` `.flags_async({23'd0,probe_flags[4:0]})`（Probe 为 `.flags_async(probe_flags)`）。

其余差异是 ROM/OSD/motion 的 `INIT_FILE` 绝对路径；`media/commit/audio/SD` 的 RTL 逐字节相同。原始 diff 见 `out/source_diff.txt`。**这是“源码级没有媒体功能改动”的直接证据；不构成全网表形式等价。**

### 1.2 Windows 只读证据

- `D:\FPGA\EG4S20-NoBot-RCA-20261020\netcheck\{rca_no_locked_003,rca_locked_only_001}\mapped.v`
- `...\builds\<id>\runs\<id>\final_timing.rpt`（holdfix 后的最终报告）
- `...\builds\<id>\work\design\user_source\hdl_source\...`（测试编译使用的真实源码）
- 测试临时输出仅写 `D:\FPGA\EG4S20-NoBot-Fix-20261020\media\`（已 mkdir）；未复制大型网表到 Mac。

### 1.3 本地测试环境

- Mac 无 iverilog/verilator（`which` 为空），未安装。
- Windows thinkpad 已有 `C:\iverilog\bin\iverilog.exe`，Icarus Verilog 12.0。所有短测在该机运行；命令和日志见 §4。

---

## 2. B 的因果链（RTL 行号）

### 2.1 主图门控

```
top_tf_hdmi_audio.v:249-250  display_valid_sync 2FF(video)
top_tf_hdmi_audio.v:388      vout_data = display_valid_sync[1] ? vout_data_raw : 24'd0
top_tf_hdmi_audio.v:168-174  video_transition(... .enable(display_valid_sync[1]), .i_rgb(vout_data) ...)
top_tf_hdmi_audio.v:192-195  html_video_overlay(... .i_rgb(tr_rgb) ... )
```

`display_valid` 只在 sd 域 `legacy_exhibit_media` 的 `COMMIT` 中、收到 `display_commit` ack 后置 1：

```
ext/legacy_exhibit_media.v:193-196
COMMIT: if(ack_sync[1]==commit_toggle) begin
  committed_view<=candidate_view; display_valid<=1; state<=REVEAL; ...
```

任何 `COMMIT` 之前的失败都不会置 1；失败后 `FAILED` 也不会再置 1。

### 2.2 OSD 为什么还能看见

`html_video_overlay` 在 `vout_data`/`video_transition` 之后（top:192），`pixel_adjust` 和 OSD 只消费 `tr_rgb`/`tr_de`。主图区 `bg` 为 0 或 mask 色时，OSD 的 plate/text 仍按自己的坐标/调色板输出（`ext/html_osd_overlay.v:562-588`）。所以 **OSD 可见不能证明主图数据路径正常**，只能证明 OSD/AXIS/TMDS 的下游还活着。

### 2.3 音频为什么是 tone

```
top_tf_hdmi_audio.v:206-216
audio_output_mux audio_output(... .tone_valid(tone_valid), .wav_status(wav_status), .wav_selected(wav_selected))
audio_media wav(... .sd_ready(sd_ready_out&&display_valid), ... .audio_valid(wav_valid) ...)
top_tf_hdmi_audio.v:265-267  hdmi_audio_tone_pcm_scale pcm(... .O_audio_valid(tone_valid) ...)
```

- `audio_media` 的 `IDLE:if(sd_ready)`（`ext/audio_media.v:132`）在 `display_valid=0` 时永不启动；`status` 停在 1（`audio_media.v:92-100`）。
- `audio_output_mux` 只在 `wav_status==2||3||5` 时把 `wav_selected` 置 1（`ext/audio_output_mux.v:10-18`）；在**首次**选中之前，`audio_left/right = tone * gain/8`（`:20-21`）。一旦置 1，它不会再回到 0（只有 `video_rst` 清零），所以后续 error/EOF 是 WAV 保持/静音，不是 tone。
- `audio_valid` 始终是 tone 的 48 kHz valid（`:19`），所以 HDMI 音频岛一直有包，只是内容是 tone。

**短测 `tb_audio_mux`**（真实 `audio_output_mux`）：status 1 → `selected=0`，`L=0x1e8480`（tone 2,000,000）；status 2 → `selected=1`，`L=0x123456`（WAV）；status 0xd/0xe → **仍 selected=1**（保持 WAV，不会回 tone）。这直接说明：

- 听到 tone ⇒ `wav_selected` 从未置 1 ⇒ WAV 没有被找到/没有被启动，**不是 WAV 数据通路损坏**；
- WAV 选择后 underflow/error/EOF 重扫 ⇒ 保持 WAV（静音/保持样本），不是 tone。

### 2.3.1 B/A 数码管原文的实际含义

`hdmi_probe_display` 的页映射见 `ext/hdmi_probe.v:116-121`。按 `HARDWARE_TEST_A_B_20261020.md` 的读数：

- **B 页 1 = `111100`**：`page=1, f0=1, f1=1, f2=1, f3=0, f4=0` → `locked=1, lock_ever=1, stable=1, drop=0, timeout=0`。真实锁定稳定。
- **B 页 2–4 = `200000/300000/400000`**：`probe_flags[27:5]` 被 `{23'd0,...}` 强制为 0，帧/AXIS/ready 字段无意义。
- **B 页 5 = `500110`**：`{5, activity(f22,f23)=0, video_rst=0, sys_lock=1, video_lock=1, heartbeat=0}`；其中 `f22/f23` 是 `audio_valid`，被强制 0，**不能判断音频**。
- **A 页 2 = `222210`**：VS/DE/HS 活动=2，`frame_good=1, frame_bad=0`。
- **A 页 3 = `321100`**：AXIS valid 活动=2，`user_seen=1, last_seen=1, user_bad=0, line_bad=0`。
- **A 页 4 = `411110`**：`ready_high=1, ready_low=1, backpressure=1, sol_conflict=1, no_de=0`；C/D=1 是 sticky，无时间/行号。
- **A 页 5 = `520110`**：`audio_valid` 活动=2，`video_rst=0`，双 PLL=1，heartbeat=0。

因此 B 的可见异常只有“真实锁定 + OSD 可见 + 主图缺失 + 音频未细分”；A 的黑屏缺少 OSD，且 C/D=1，A 与 B 不是同一可观测集合。

### 2.4 sticky fault 的永久 mask

```
ext/video_transition.v:69-70
if(COVER_BEFORE_LOAD && display_fault_sync[1]) begin
  offset<=WIDTH; phase<=WAIT_ACK; reveal_armed<=0;
end
ext/video_transition.v:110-117
if(COVER_BEFORE_LOAD && display_fault_sync[1]) begin
  sel_ram_q<=0; base_rgb_q<=MASK_COLOR;   // 0x151615
end
```

`top_tf_hdmi_audio.v:171` `display_fault_async(fifo_fault)`；`legacy_exhibit_media.v:157-160` 也在 `fault_sync[1]` 时直接 `FAILED`。所以一个 sticky `fifo_fault` 会让：

- 主图区变成 `0x151615`（暗灰，不是纯黑），OSD 仍可见；
- `display_commit` 不再 ack 新 commit（`display_commit.v:40,46,53` 都带 `fault` 条件）；
- `legacy_exhibit_media` 锁 `FAILED`，页号停在 `01/06`；
- 若 fault 在首帧 commit 之前，则 `display_valid=0`，transition 被强制 mask，主图为 `0x151615`（不是纯黑）+ tone；
- 若 fault 在首帧 commit 之后，则 `display_valid=1`，主图暗灰 + OSD；音频可能已经在 WAV（或仍在 tone 扫描期）。

**短测 `tb_commit_chain` 的故障段**：fault 置 1 后 5 个 active pixel 的 `o_rgb` 都等于 `0x151615`（`mask pixels checked=5`），并且第二次 cover/commit 都不再 ack（`PASS second commit not acked while faulted`）。这只把 fail-stop 保持行为变成了可复现行为；**没有证明合法正常工作时会误触发，也没有证明它是 B 的原因**。

---

## 3. 逐项审计（任务清单）

| 项目 | RTL 位置 | 结论 |
|---|---|---|
| `display_valid` 产生 | `legacy_exhibit_media.v:193-196`；`top:260-264` | 只在首帧 `COMMIT` ack 后置 1；没有其他置 1 路径。`REQUIRE_INITIAL_COMMIT=1` 是合法启动基准。 |
| 首帧提交 | `display_commit.v:33-44,51-62`；`video_transition.v:92-103` | `commit_toggle`/`commit_ack_toggle` 是“保持到 ack”的 toggle；`REQUIRE_INITIAL_COMMIT` 先消费空白帧，pending commit 在下一帧被接受。**短测相位扫描无丢脉冲。** |
| `write_done`/`ack` | `top:291-298`；`legacy_exhibit_media.v:187-189` | `frame_write_finish` 单拍在 mem 域转 toggle，sd 域 3FF 取边沿；`source_done && write_done` 后 commit。toggle 保持到下一次写完成，不存在窄脉冲丢失。 |
| `frame_commit`/`readbuffer`/`active_view` | `display_commit.v:23-68`；`top:415` | `candidate_view` 是 12 位 bundled-data，源在 `IDLE` 写入并保持到 ack；目的端 2FF + settle=2 采样。`active_buf` 只在 ack 的读请求上更新，`previous_buf` 在 abort 时回滚。**没有发现错误数据/控制相位。** |
| `frame_read_write` 的 `read_ready`/`empty`/`full` | `SD/frame_read_write.v:89-112`；`frame_fifo_read.v:85-108,136-146,176-217` | `read_req` 保持到 ack；S_ACK 才清 read FIFO、锁地址/长度；`rd_underflow` 只在 `display_valid_video && read_en && rd_empty` 时置位。正常首帧有 ~33 行的预取余量（25 MHz 下 ~1.06 ms）对 512 字（40 MHz 下 12.8 µs）。**没有发现“首帧必然下溢”的逻辑。** |
| 异步 FIFO 复位/指针 | `SD/frame_read_write.v:121-186`；`ext/audio_async_fifo.v:26-39` | 视频/写侧 FIFO 使用 vendor 异步 FIFO + 各域 `*_reset`，正常。**音频 FIFO 的独立同步 reset 是模块契约（F2）；实际 top 的共同 clear/flush 序列在 `tb_audio_fifo_seq` 中通过，当前不可达，不作为 B 的缺陷。** |
| 读写同缓冲 | `top:415,433`；`legacy_exhibit_media.v:171-172` | 首帧 load 时 `read_addr_index=0`、`write_addr_index=0`，确实读写同一 buffer；但 `display_valid=0` 时主图被门控，commit 帧的 S_ACK 会清 read FIFO 并在写完成后重新预取，**不构成首帧黑屏的充分原因**。稳定态双缓冲正确交换（`~committed_view[0]`）。 |
| 共享 sector arbiter/ready | `ext/media_sector_arbiter.v:17-45`；`ext/audio_media.v:45-54,123-158` | 一个物理 SD 读口，BMP/audio 事务级轮转；音频 urgent 时连续 2 次后让 BMP；没有发现饥饿或丢 grant 的逻辑。音频启动额外依赖 `display_valid`（top:212），这是设计耦合，不是 arbiter 错误。 |
| 单次 SD/loader 错误的后果 | `legacy_exhibit_media.v:76-80,157-160`；`SD/sd_card_cmd.v:221-223` | 单次 `response_error`/`loader_error` → 永久 `FAILED`，无重试；CRC 错误即可触发。**F4 是 fail-stop 行为/覆盖边界，未证明会误触发；不据此加重试。** |
| 音频 WAV | `ext/wav_stream_parser.v:24-123`；`audio_pcm_player.v:25-47` | 解析器要求 PCM16/48 kHz/mono|stereo；卡上 WAV 符合。`audio_pcm_player` 的 48 kHz 节奏与 tone 独立，选源后保持。**没有发现 WAV 数据错误；tone 是选源状态。** |

**没有找到**：commit/cover 的窄脉冲丢失、`active_buf` 相位的确定性错误、首帧必须依赖非法状态、read/write 同缓冲导致的确定性首帧黑屏、异步 FIFO 指针比较的确定性错误。

---

## 4. 短测试与结果

全部在 Windows `C:\iverilog\bin` 12.0 上运行，RTL 直接取 B 构建的源码（`builds/rca_locked_only_001/work/design/user_source/hdl_source`），只读。日志在 `fix_round/media/out/`，远端副本在 `D:\FPGA\EG4S20-NoBot-Fix-20261020\media\out\`。

| 测试 | 目的 | 结果 |
|---|---|---|
| `tb_commit_chain.v`（PHASE_NS=0/3/7/13/19） | 真实 `display_commit` + `video_transition`；模型源按 COVER→LOAD→COMMIT；25 MHz video / 100 MHz sd 相位点 | 5 例 PASS：cover ack 1603 sd cycles；首 commit ack 1340 sd cycles；`active_buf=001`；fault 后第二次 commit 不 ack；fault 后 mask pixel=0x151615。见 `commit_phase_*.log`。 |
| `tb_commit_chain.v`（LOAD_CYCLES=0/1/50/299/300） | commit 相对 vs 的负载偏移 | 5 例 PASS，`errors=0`。见 `commit_load_*.log`。**两组合计至多 10 例，不是 5×5 交叉。** |
| `tb_fr_fault.v` | 真实 `frame_read_write`：`display_valid_video=1`、`read_en=1`、read FIFO 空 | `fifo_fault` 在人为一次 underflow 后置 1，2000 个 read clock 后仍为 1。**只证明 fail-stop 保持行为；不证明实板/合法正常工作会触发。** `fr_fault.log`。 |
| `tb_audio_mux.v` | 真实 `audio_output_mux` 的选源 | status 1→tone；2/3→WAV；0xd/0xe→仍 WAV。见 `audio_mux.log`。 |
| `tb_audio_fifo_seq.v`（AUDIO_REL_NS=0/20/200/400） | **实际 top 共同 reset/flush 顺序**：`rst`→`clear_count=32`→`fifo_clear`→`clear_sync`；power-up + WAV restart；精确 32 字 scoreboard | 4 个释放偏移全部 `errors=0`、`level=0`、32 字顺序正确；**在当前 top 的这些可达释放偏移中没有重放/丢失，F2 未触发（不是全相位证明）。** 见 `audio_fifo_seq_*.log`。 |
| `tb_audio_fifo_rdc.v` | 契约外的单边 read reset（当前 top 不可达） | 消费 `1000..1003` 后单独 `rd_rst`，再读 `1000..1005`（重放）；level=18，**不作为 fault/虚报结论**。只说明模块契约：两侧 reset 必须同时有效。`audio_fifo_rdc.log`。 |

复现脚本：`fix_round/media/tools/run_remote.ps1`（把 `media/tb` 复制到 Windows 的 `D:\FPGA\EG4S20-NoBot-Fix-20261020\media\tb` 后执行；只写该 media 目录）。  
编译告警：`frame_read_write.v:147/196` 的 `rdusedw/wrusedw` 9 位接 10 位端口，高位补 0，值域 0..511，**不是功能错误**（`compile_fr_fault.log`）。

### 4.1 测试没有覆盖的部分

- `tb_commit_chain` 的源是模型，不是完整 `legacy_exhibit_media`；它不包含 SD 扫描/loader 的真实延迟。
- `tb_fr_fault` 是人为空读，不是“实板必然发生 underflow”的证据。
- `tb_audio_fifo_rdc` 是单边 read reset 的契约外边界，不是当前 top 的正常序列；`tb_audio_fifo_seq` 覆盖 4 个释放偏移，但不是所有时钟相位/实现角。
- 没有做全媒体/全帧仿真，没有做门级形式等价；不能把 10 个 commit 用例或 4 个 reset 偏移当成全 CDC 证明。

---

## 5. mapped/最终路由证据（针对性，不是名称统计）

### 5.1 B 的状态/故障不可观测

对 `netcheck/rca_locked_only_001/mapped.v`（routed）和 `rca_no_locked_003/mapped.v` 做名称存在性检查（`out/netlist_counts.txt`）：

| 名称 | A | B |
|---|---:|---:|
| `display_state` | 0 | 0 |
| `state_code50` | 0 | 0 |
| `state_code_sd` | 0 | 0 |
| `state_code` | 36 | 38 |
| `display_valid` | 55 | 50 |
| `fifo_fault` | 15 | 17 |

- `display_state`/`state_code50`/`state_code_sd` 在 **A、B 的最终网表中都是 0**：老的 4 位状态显示被 Probe 的 `probe_display` 替换后，这条观察链已被综合移除。
- `state_code` 仍存在（sd 域，用于 config bundle 和 legacy 状态），但**没有消费者把它送到数码管**。
- B 的 `netcheck.txt` 观察者计数：`core_ready=0, axis_last=0, axis_x_count=0, probe_frame_count=0, probe_line_count=0, probe_lock_ever=1`。B 的页 2–4 是人为 0，不是真实帧/AXIS/ready。
- 所以 **B 无法从数码管判断 `display_valid`/`state_code`/`fifo_fault`/`audio_valid`/`wav_status`**。这是 F3，也是本轮不能定因的直接原因。

### 5.2 媒体控制不是 B 的时序临界路径

B `rca_locked_only_001` 的最终 `final_timing.rpt`（holdfix 后）各组（`out` 中未复制大报告，路径见 §1.2）：

| Path group | setup WNS | hold/removal HWNS |
|---|---:|---:|
| `video_clk -> video_clk` | 9.956 | 0.027 |
| `sd_card_clk -> sd_card_clk` | **0.106** | 0.030 |
| `ext_mem_clk -> ext_mem_clk` | 13.773 | 0.103 |
| `sd_card_clk -> video_clk` | 5.775 | 0.073 |
| `video_clk -> sd_card_clk` | 7.096 | 0.167 |
| `video_clk -> ext_mem_clk` | 2.008 | 0.167 |
| `ext_mem_clk -> video_clk` | 2.573 | 0.092 |

- **唯一接近 0 的 setup 是 `sd_card_clk` 的 WAV parser**：`wav/parser/pos_reg[12] -> state_reg[2]`，data 9.614 ns，slack **0.106 ns**（B）/ 0.423 ns（A）。它只影响 WAV 解析/音频状态，**不经过主图/`display_valid` 路径**。
- `candidate_view` 的 `sd_card_clk -> video_clk` hold 0.073、`active_buf -> read_addr_index_d0` 的 `video_clk -> ext_mem_clk` hold 0.438 是**多 bit bundled-data**，源在 `IDLE` 写入后保持到 ack；总线在采样前稳定 ~1 s，0.073 的“hold”不是该协议的功能要求（不是逐 bit 同步器）。该组 Min 0.167 来自 `video_delay/vs_d[11] -> read_addr_index_d0`，同样是稳定/电平信号，不是脉冲。
- `fifo_fault` 的 `mem_fifo_fault -> transition/display_fault_sync` setup 2.987 / hold 0.726，`video_clk -> ext_mem_clk` setup 2.449 / hold 1.124；sticky 位稳定，**没有负 slack**。
- **没有任何一条媒体/commit/audio 路径是负 slack。** B 的失败不能由已报告的 STA 违例直接解释；如果它是物理/启动敏感，敏感点在未报告的启动/带宽/时序窗口，而不是这些已列路径。

### 5.3 失败/成功基线的媒体 FF 结构

`worker_a/summary2.json`（失败 NoBot A vs 成功 Probe B）的层次 FF 计数：

| 层次 | 失败 NoBot | 成功 Probe |
|---|---:|---:|
| `sd_card_bmp_m0` | 529 | 529 |
| `frame_commit` | 57 | 57 |
| `config_bridge` | 137 | 137 |
| `pcm` | 90 | 90 |
| `audio_output` | 1 | 1 |
| `transition` | 64 | 65 |

这不是形式等价，但说明**媒体控制/commit/audio 的寄存器结构在失败与成功基线之间没有被删除或重建**；结合 §1.1 的源码 diff，B 的媒体功能源码与 Probe 逐字节相同。**因此 B 的差异不可能来自“媒体逻辑源码被改坏”**，只能是观察/重布局/启动/外部介质。

---

## 6. B 与 A 的可解释性

### 6.1 B

- **主图缺失 + OSD 可见**：`display_valid=0`（transition 在 IDLE 时纯黑；已 cover/fault 时 `0x151615`）或 `fifo_fault` 后的 `MASK_COLOR=0x151615`（暗灰）都能解释；两者都在 OSD 之前，OSD 在之后。
- **音频异常**：tone 是设计内的 fallback；听到 tone 说明 WAV 没被选中（display_valid=0、首次扫描未完成/失败），**不是 WAV 数据坏**。听到静音，更像 WAV 选择后的 error/underflow 或 EOF 重扫（`wav_selected` 保持 1，输出静音/保持，`tb_audio_mux` 验证）。听到 WAV 但有杂音/断续，才更像 FIFO underflow/arbiter/样本节奏问题；这需要单独的证据，不能由 tone 推出。
- **`01/06`**：`active_view=0`；若从未 commit，OSD 页天然是 01/06；若 commit 后 `FAILED`，页也停在最后提交的页。**不能从 01/06 判断是否 commit 过。** 但如果 B 的页在 **>5.4 s** 内一直停在 01/06，则“健康的 `display_valid=1` + 自动轮播”被排除（自动轮播每 5.4 s 会推进）；此时只剩“首帧前”或“FAILED”。
- **如果 B 的首次 BMP load 期间发生一次 SD CRC/响应错误**：`response_error` 使 `legacy_exhibit_media` 直接 `FAILED`（F4），`display_valid=0`；若此时 transition 已 cover，主图为 `0x151615`，若仍在 IDLE 则纯黑；OSD 可见、tone；数码管本应显示 `D`/`C`，但 B 把它屏蔽了。这与 B 的可见症状相容，且不需要任何媒体源码差异；**这是状态位流应优先排除的具体路径之一，未证明发生。**
- **不能排除“观察太早”**：BMP 扫描从 LBA0 到 2081（按 ~0.37–0.43 ms/扇区估算 ~0.8–0.9 s）+ 首图 load（~1801 扇区，~0.7–0.8 s），首图约在 2 s 量级；首次 WAV 从 LBA0 扫到 16491（审计给出的理想下界 6.04 s）才开播，所以首次 tone 约在前 6 s。若 B 的观察窗口只有几秒，主图/声音都可能只是启动时间线。**需要明确观察时长。**

### 6.2 A

- A 的 page 2/3/4/5：`frame_good=1`、AXIS valid/user/last 曾出现、C/D=1、`audio_valid` 活动=2、`video_rst=0`、双 PLL=1。A 的视频流/AXIS/tone 都在跑。
- A 的 OSD **不可见**，这与“仅 `display_valid=0`”不一致（OSD 应在主图之后显示）。A 至少还多一层 OSD/transition/下游问题，或 OSD 因暗色文本/观察条件不可见。**本轮不把 A 的 C/D=1 或黑屏转移到 B。**
- A 的 C/D=1 是真实采样事件（`av && !ready`），但 sticky、无时间/行号，不能证明持续丢像素；A 的 page 2/3 又显示帧/AXIS 正常。**它不是 B 的证据。**

---

## 7. 单一状态观察变体（待 Root 实施；本文不写顶层/模块）

### 7.1 变体边界

Root 计划：只做一个 **B 派生状态观察变体**，复用 B 现有的 31 位双 FF 显示同步和 5 页显示；把被 `{23'd0,...}` 屏蔽的 `probe_flags[27:5]` 换成状态位。**不改功能通路、不换卡、不改 PHY、不改 media/commit/audio 逻辑。** 本文只给编码/最小位/解码表，不提供顶层或模块代码。

### 7.2 实际源码的状态编码（不是旧 Bot 文档）

**A. `legacy_exhibit_media` 的 `state_code`**（`ext/legacy_exhibit_media.v:59,66-68`）：

```
localparam SCAN=0, IDLE=1, COVER=2, LOAD=3, COMMIT=4, REVEAL=5, FAILED=6;
state_code = sd_init_error ? 4'he
           : fault_code!=0 ? fault_code
           : !catalog_ready ? scan_state
           : paused_out ? 4'h9
           : (state==IDLE && auto_mode_out) ? 4'h8
           : {1'b0,state};
```

`fault_code` 的真实来源/优先级（`:157-160,167,184,190,195,198,200`）：

| 值 | 条件（源码） | 含义 |
|---|---|---|
| `A` | `fault_sync[1]` | storage fault（`fifo_fault`） |
| `B` | SCAN 结束但 `found_count!=10` | BMP 数不是 10 |
| `C` | `loader_error!=0`，或 `scan_kicked && scan_error>=2`（且 A/E/D 都不成立） | loader/scan 错误 |
| `D` | `response_error` | BMP response/CRC/超时错误 |
| `E` | `sd_init_error` | SD 初始化错误 |
| `F` | COVER/LOAD/COMMIT/REVEAL 10 s watchdog 或 default | 超时 |

**B. `!catalog_ready` 时 `state_code` 不是 legacy FSM，而是 `bmp_scale_read` 的 `scan_state`**（`ext/bmp_scale.v:85,251,255,268,278,292,295,301,307`）：

| `scan_state` | 含义 |
|---|---|
| `1` | scanner IDLE（等待/扫描开始） |
| `2` | HREQ/HRECV/HCHECK（读 BMP header） |
| `3` | WAIT_ACK（scanner 的 scale 写请求；legacy 实例 `load_start=0`，扫描路径不用） |
| `4` | DREQ/DRECV/PARSE（scanner 的 scale 数据路径；legacy 实例不用） |
| `14` | scanner 错误 |

**因此 `catalog_ready` 必须显示**：`catalog_ready=0` 且无 fault 时 `1/2/3/4/14` 是 scanner 码（fault_code 优先，会显示 A-F）；`catalog_ready=1` 时 `1/2/3/4/5/8/9/A-F` 才是 legacy 码。**不要把 `0` 读成 SCAN**：`SCAN=0` 只是内部 localparam，`state_code` 在 `catalog_ready=0` 时显示 `scan_state`（1/2/14），在 `catalog_ready=1` 后 `state=IDLE=1` 也不是 0。**`8` 是 IDLE+auto，不是 SCAN；`9` 是 paused。**

**C. `display_state`**（`top_tf_hdmi_audio.v:259`）：`fifo_fault_sync[1] ? 4'ha : state_code50`。所以 `A` 也可能是 `display_state` 的 fault 覆盖；原始 `state_code` 与 `fifo_fault` 分开显示可以消歧。

**D. `audio_media.status`**（`ext/audio_media.v:92-100`）：

| status | 含义 |
|---|---|
| `0` | `!enable`/复位（enable 固定 1，正常运行不应出现） |
| `1` | 启动/扫描/未找到 WAV |
| `2` | 找到 WAV header，预填中 |
| `3` | `play_ready`，播放中 |
| `4` | paused |
| `5` | drained/EOF |
| `B` | error code 11（扫描到 `SCAN_MAX_SECTOR`） |
| `C` | FIFO overflow |
| `D` | underflow |
| `E` | 其他 audio error |

`wav_selected` 在 status 2/3/5 时置 1，之后不回到 0（只有 `video_rst` 清零）；`error/underflow/overflow` 是原始 sticky/标志，status 可能被后续条件覆盖，所以三者要单独显示。

### 7.3 最少需显示的位（23 位，正好填 `flags[27:5]`）

| 位 | 信号 | 作用 |
|---|---|---|
| 4 | `state_code[3:0]` | legacy/scanner 码（配合 catalog_ready） |
| 1 | `catalog_ready` | 消歧 1/2/3/4 是 scanner 还是 legacy |
| 1 | `display_valid` | 首图是否已提交 |
| 1 | `fifo_fault` | storage fault（与 `A` 交叉验证） |
| 1 | `sd_init_done`（即 `sd_ready`） | SD 是否初始化完成 |
| 1 | `Sdr_init_done` | SDRAM 是否初始化完成 |
| 4 | `wav_status[3:0]` | WAV 状态 |
| 1 | `wav_selected` | 是否已选 WAV（0=tone/静音） |
| 1 | `wav_error` | audio error 原始位 |
| 1 | `wav_underflow` | audio underflow 原始位 |
| 1 | `wav_overflow` | audio overflow 原始位 |
| 6 | `active_view[5:0]` | `[1:0]` buffer、`[4:2]` page、`[5]` dual |
| **23** | 合计 | 正好替换 `flags[27:5]`；B 的 31 位 = 3 个外部位（video_rst/sys_lock/video_lock）+ 5 个真实 lock 位 + 这 23 位 |

说明：`state_code`、`display_valid`、`fifo_fault`、`sd_init_done` 在 sd 域；`Sdr_init_done` 在 mem 域；`wav_status/wav_selected/error/underflow/overflow` 在 audio(video) 域；`active_view` 在 video 域。沿用 B 现有 31 位双 FF 逐位同步到 50 MHz；这是状态显示，不是控制，逐位同步不保证多位原子快照（`wav_status`/`active_view` 在变化的单帧可能短暂混合），但足以区分稳定态。若还需要 `active_view[7:6]` scale，可从 `wav_overflow` 或非关键位借 2 位，或另开页。

### 7.4 建议的 5 页映射（示意，Root 实现）

| 页 | 显示 |
|---|---|
| 1 | 保持现有 `locked/lock_ever/stable/drop/timeout`（真实 lock） |
| 2 | `state_code`、`{catalog_ready,display_valid,fifo_fault,sd_init_done}`、`Sdr_init_done` |
| 3 | `wav_status`、`{wav_selected,wav_error,wav_underflow,wav_overflow}` |
| 4 | `active_view[7:4]`、`active_view[3:0]`（低 6 位为最小集，高 2 位可选） |
| 5 | 保持现有 `video_rst/sys_lock/video_lock/heartbeat`（可再放 `fifo_fault/display_valid` 复本） |

### 7.5 状态组合如何区分四类问题

| 目标 | 最小可判据（稳定态） |
|---|---|
| **首图未提交**（在扫描/覆盖/加载/提交） | `display_valid=0`；`fifo_fault=0`；`catalog_ready=0` 时 `state_code=1/2/14`（scanner）；`catalog_ready=1` 时 `state_code=1`（IDLE，若持续则是 loader_ready/busy/config 未放行）或 `2/3/4`（COVER/LOAD/COMMIT）；`sd_init_done=1`；`Sdr_init_done=1`。若 `state_code=F` 且持续 10 s，是 watchdog 超时；若 `state_code=1` 且 `catalog_ready=0` 且 `sd_init_done=0`，是 SD 未就绪，不是文件错误。 |
| **存储 fault** | `fifo_fault=1`，`state_code=A`（`display_state` 也为 A）；`display_valid` 0/1；`catalog_ready` 可 0/1。**`fifo_fault` 单独位消歧“A 是 display_state 覆盖还是 fault_code=A”**。 |
| **SD 错误** | `sd_init_done=0` 且 `state_code=E` → SD 初始化错误；`sd_init_done=1`、`catalog_ready=0`、`state_code=14` → 扫描/读错误；`sd_init_done=1`、`catalog_ready=1`、`state_code=D/C` → response/loader 错误；`state_code=F` → 超时。 |
| **WAV 未选中** | `wav_selected=0`：若 `display_valid=0`，`wav_status` 通常为 `1`（audio 从未启动，tone）；若 `display_valid=1`，`wav_status=1` 是首次扫描（tone），`2` 是找到/预填，`3` 是播放（此时 `wav_selected` 应为 1）。`wav_selected=1` + `status=3` → WAV 播放；`wav_selected=1` + `status=D/E/C` → WAV 后 error/underflow/overflow（静音/保持，不是 tone）。 |
| **SDRAM 未就绪** | `Sdr_init_done=0`，`display_valid=0`，`fifo_fault=0`；可与 SD/扫描/loader 区分。 |

**结论**：这 23 位在稳定态足以区分“首图未提交、存储 fault、SD 错误、WAV 未选中、SDRAM 未就绪”；`catalog_ready` 是避免把 scanner `1/2/3/4` 误读成 legacy `IDLE/COVER/LOAD/COMMIT` 的关键位。**不在此文写顶层/模块代码。**

## 8. 修复建议

1. **本轮不建议改生产 RTL。** 没有找到能证实“合法正常工作时误触发”的逻辑错误；B1/B4 的 fail-stop 是设计策略，不能在未证明误触发前加重试、清 sticky 或吞错；B2 在当前 top 的共同 clear/flush 序列中不可达，不应单修它冒充修 B。
2. **只做 Root 计划的状态观察变体**（不改功能通路/卡/PHY）：复用 B 的 31 位双 FF/5 页，把被屏蔽的 `flags[27:5]` 换成 §7.2 的状态位；这是诊断改动，不是功能修复。
3. 若状态变体显示 `A`/`D`/`C`，下一步只引出 `fifo_fault` 的三个来源和 `sd_error_code/block_error_code`，先确认原因，再决定是否需要任何容错；本轮不预设重试/清除策略。

## 9. 未做与限制

- 未上板、未下载、未改 TF/Flash、未构建、未启动子 Agent；**没有要求用户拍照/录音或做任何硬件观察**。
- 未做完整 `legacy_exhibit_media` + SD + loader 的全系统仿真（需要数小时；本轮只做边界短测）。
- 未做门级形式等价；§5.3 的 FF 计数不是等价证明。
- 未复制大型 Windows 网表到 Mac；只取计数/路径文本。
- B 的音频性质（tone/静音/WAV 间隙）未由用户细分；本报告不把它归为 WAV 坏。
- commit 只做了 5 相位 + 5 LOAD 偏移（至多 10 例），audio reset 只做了 4 个释放偏移；**不是全 CDC/全相位证明**。
- §7 的状态观察变体**未实施**；本文只给编码/最小位/解码表，不含顶层/模块代码。
- A 的 OSD 不可见与 B 不同，未定因；不把 A/B 当同根因。

---

## 10. 复现路径

- 测试 RTL：`fix_round/media/tb/{tb_commit_chain,tb_fr_fault,tb_audio_mux,tb_audio_fifo_seq,tb_audio_fifo_rdc}.v`
- 运行脚本：`fix_round/media/tools/run_remote.ps1`（Windows，只写 `D:\FPGA\EG4S20-NoBot-Fix-20261020\media`）
- 结果日志：`fix_round/media/out/*.log`；`out/netlist_counts.txt`；`out/source_diff.txt`
- 关键源码：`rca_ab_sources/Probe/work/design/user_source/hdl_source/...`（B 的同一文件在 `rca_ab_sources/B/...`）
- 最终时序：`D:\FPGA\EG4S20-NoBot-RCA-20261020\builds\<id>\runs\<id>\final_timing.rpt`
- 状态/观察计数：`netcheck.txt`、`D:\...\netcheck\<id>\mapped.v`
