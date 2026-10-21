# Worker A 报告：NoBot 黑屏 vs HDMI Probe 成功
## —— 精确构建快照的映射网表、HDMI AXIS、黑场门控、音频与复位/时钟对比

日期：2026-10-20　执行者：Worker A（DS Flash 1017）
边界：**离线只读**。未修改任何 RTL、未改原工作区/冻结目录、未构建、未做任何硬件/JTAG/板卡操作。所有远端临时文件只写 `D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a`（本次新建）；本机只写 `worker_a/`。

---

## 0. 结论摘要

1. **两者都没有 `*_map.v` 之类的文本映射网表**。TD 6.2.168116 的映射网表是二进制 `hx4s20_basic_gate.db`。我用 TD 自带的 `write_verilog` 在**副本**上只读导出两份门级网表（8.5 MB / 8.8 MB），未执行 optimize/place/route/bitgen 等任何构建命令。
2. **逐 FF / BRAM / PHY 对比后，在已检查的端点上未发现 A/B 的功能差异；但“全设计等价”未证**（未做 SAT；见第 16 节）。已检查到的差异都能归入以下四类：
   - 探针“多观测负载”导致的**逻辑保留**（HS 链 32 个 FF、last/x_cnt 12 个 FF、ready+同步器 22 个 FF、探针自身 188 个寄存器 = probe 95 + probe_display 93）；
   - 探针替换数码管导致的**显示状态链删除**（`state_code_sd[3:0]`、`state_code50[3:0]` 共 8 个 FF，仅 7 段数码管用）；
   - **FF 打包变化**（OSD 的 `b3/g3/body_base` 24 个 FF 在 B 中被并入 `EG_PHY_MSLICE`，不是删除）；
   - **wire 别名/命名变化**（`audio_valid`、`I_axis_s_user/valid/data`、`O_video_locked`、`video_clk`、`video_rst` 等）。
3. HDMI 发送核子树：A=1529、B=1551 个 `AL_MAP_SEQ`，其中 **1466 个连名字、参数、D/Q/CE/SR 引脚都完全相同**，0 个被删除，仅 +22 个（`S_video_in_ready_reg` 1 个 + FIFO 读指针同步/占用逻辑 21 个），且这 22 个只用于产生 `O_axis_s_ready` 观测值。**HDMI PHY 的 47 个 FF 与 LUT 形状完全一致。**
4. `tlast`：该配置展开后的 **mapped 锥未使用该端口**（两份网表都没有 `I_axis_s_last` 网；接口声明里确实有该输入）。A 中 `O_video_last`/`S_x_cnt` 被优化为常量 0，B 中因探针观测而保留——**不能用“未用输出被优化”直接判定设计曾经功能错误**。`O_axis_s_ready` 同理（仅输出，无内部消费者）。HS 也只在探针里被消费。
5. 黑场门控 `vout_data = display_valid_sync[1] ? vout_data_raw : 0` 在两份网表中是**同一组 LUT2（INIT=4'h8，`.a(display_valid_sync[1])`）**，未变。
6. 因此：**在映射逻辑层没有找到能解释黑屏的功能性差异**。A 的 `rs_video` 复位释放链、PLL 锁定同步、时钟资源（2 GCLK / 2 PLL）、BRAM/DSP 数量、音频 ACR/采样包/FIFO 都与 B 相同。剩余差异属于实现/物理层（布局布线、时钟与复位的扇出/偏斜、启动时序）或位流配置层，应由 B 的 STA/实现证据判定；本报告给出 2 个最有区分度的实验建议（未实施）。

---

## 1. 精确构建快照与哈希（已核对）

失败构建 A：
- 目录 `D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004`
- bit `...\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit`
  `SHA256 = 61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7`，677348 B —— **与任务给定值一致**
- 源码快照 `...\work\design\user_source\hdl_source\top_tf_hdmi_audio.v`
  `SHA256 = D90A057F2242EBF387CAA8057C85613CF43504BE791644353DC35F3B63F8209D`，20099 B
- 映射库 `...\syn_1\hx4s20_basic_gate.db`
  `SHA256 = 5345F8AD01EE2E38E73B0DD1D5CBF2EC245F74673ADB71DF0A9E65A8F8AB6F3E`，5115038 B

成功构建 B：
- 目录 `D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001`
- bit 同上相对路径
  `SHA256 = bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`，677348 B —— **与任务给定值一致**
- `top_tf_hdmi_audio.v` `SHA256 = A422B55AEC4DC4420479D80060956825DAA08BEECDB6D28B2132FA5924761CEA`，20832 B
- `ext/hdmi_probe.v` `SHA256 = F9E820E62D2ABB204E2467E4C4F6791817D0ADFB042E40B0399A660BE9BBCF25`，5175 B；
  `git hash-object` 结果 `19d54a0dd397428adc7f7f5f51441843ddf6c314` = `72e5c80e` 提交里的 `rtl/ext/hdmi_probe.v` blob，快照与源码提交一致。
- 映射库 `...\syn_1\hx4s20_basic_gate.db`
  `SHA256 = 314954CF3B62CDF368662A4E046B4FEB154DF1A5A1791146F796BF6CBE32EE56`，5233660 B

说明：`top_tf_hdmi_audio.v`、`video_rgb_to_axis_640x480.v`、`SD/video_delay.v`、HDMI enc 核、PLL 包装等都在 `docs/local_dependencies.json`（共 59 项）中、**不受 Git 跟踪**，且 A 的 top 是 `scripts/no_bot_apply_legacy.py` 生成的。因此本报告全部以**构建目录内的源码快照**为准，而不是 `git diff HEAD`。

---

## 2. 源码层差异（只比构建快照）

对两棵 `hdl_source`（121 / 122 个文件）逐个 SHA256 比对，结果只有：

| 文件 | A | B | 性质 |
|---|---|---|---|
| `ext/hdmi_probe.v` | 无 | 5175 B | 新增探针 |
| `top_tf_hdmi_audio.v` | 20099 B | 20832 B | 探针实例、6 位数码管、`O_video_locked` 接出；删除 `display_state` 数码管译码 |
| `ext/html_caption_column_rom.v` 等 6 个 | — | — | **仅 `INIT_FILE=` 绝对路径字符串不同** |
| `hdmi_1_4b_transmitter_core_wrapper.enc.v` | 328975 B | 同 | SHA256 相同 `867E0B0B…` |
| `hdmi_phy_warpper.v`、`timing.sdc`、`pin.adc` | — | — | SHA256 相同 |

工程侧：`hx4s20_basic.tcl`、syn/phy `settings.cfg`、`run.bat`、`timing.sdc`、`pin.adc` 全部相同；`.prj` 仅增加 `hdmi_probe.v` 文件项；**bitgen 参数文件 `.bitgen_param.f` 也逐字节相同**（`unused_io_status pullup`、`compress off` 等）。**综合/实现/位流生成选项没有变化**（`-packarea`、`drHoldFix on` 等一致）。

依据：`evidence/srchash.txt`、`evidence/topdiff.txt`。

---

## 3. 映射网表的获取方式（只读）

TD 6.2.168116 的 syn 目录只有：`hx4s20_basic_gate.db`（映射）、`_rtl.db`、`_elaborate.db`。没有 `*_map.v`。

在 scratch 目录复制两份 gate.db 后，用 TD 自带 Tcl 只读导出（**没有** `optimize_rtl/optimize_gate/place/route/bitgen`）：

```tcl
import_device eagle_s20.db -package EG4S20BG256
import_db D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/a_gate.db
write_verilog D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/a_gate.v -nobuf
exit
```

B 同理。得到的网表是**扁平化、带层次名前缀**的门级 Verilog（`AL_MAP_SEQ`、`AL_MAP_LUTx`、`EG_PHY_MSLICE/LSLICE`、`EG_PHY_BRAM`、`EG_PHY_PAD`、`EG_PHY_PLL`、`EG_PHY_GCLK`、`AL_BUFKEEP` 等）。本报告中的“相同”指：**同类型、同参数、同引脚连接（含网名）**。

脚本：远端 scratch 中的 `dump_a.tcl`/`dump_b.tcl`（由 `ps/mk_tcl_dump*.ps1` 生成）；本地解析脚本见第 15 节。

---

## 4. 总体资源

| 报告 | A | B | Δ |
|---|---|---|---|
| gate `#lut` | 9776 | 10002 | +226 |
| gate `#reg` | 6324 | 6569 | +245 |
| gate `AL_MAP_SEQ` | 6242 | 6463 | +221 |
| gate BRAM9K/32K | 53 / 5 | 53 / 5 | 0 |
| gate `#dsp` | 8 | 8 | 0 |
| gate `#pll` / `#gclk` | 2 / 2 | 2 / 2 | 0 |
| phy `#lut` / `#reg` | 10054 / 6323 | 10257 / 6572 | +203 / +249 |
| IO | 29 | 29 | 0 |

`gate #reg` 与 `AL_MAP_SEQ` 计数不完全相等（TD 的 reg 统计还包含 MSLICE/BRAM/PAD 内的寄存器），所以下文**层级数值用 TD area 报告**，**具体寄存器清单用 `AL_MAP_SEQ` 网表**。

证据：`evidence/area_A_GATE.txt`、`evidence/area_B_GATE.txt`、`evidence/area_A_PHY.txt`、`evidence/area_B_PHY.txt`。

---

## 5. 顺序逻辑逐层对比（TD area `seq`，含子层次）

| 层次 | A | B | 解释 |
|---|---|---|---|
| **probe** | 0 | 95 | 探针本体（新增） |
| **probe_display** | 0 | 93 | 探针显示（新增） |
| `u_video_rgb_to_axis_640x480` | 28 | 40 | **+12 = `S_x_cnt[10:0]` + `O_video_last_reg`**，只因 `al` 被观测 |
| `video_delay_m0` | 66 | 87 | **+21 = `hs_d[20:0]`**，只因 `hs` 被观测 |
| `video_timing_data_m0` | 33 | 37 | +2 本层 hs 流水、+2 `color_bar` hs 流水 |
| `color_bar_m0` | 28 | 30 | +2 hs |
| `transition` | 64 | 65 | +1 `o_hs_reg` |
| `extensions/adjust` | 26 | 27 | +1 `o_hs_reg` |
| `extensions/osd` | 650 | 655 | +5 hs 同步链（`sync0..3[2]`、`o_hs`） |
| `u_video_axi_stream_receiver` | 57 | 79 | **+1 `S_video_in_ready_reg` + 21 FIFO 读指针同步/占用 FF（`S_fifo_wr_num`）**，仅服务 `ready` |
| └ `u_w24_d1024_fifo` | 55 | 76 | +21（11 位读指针的两级同步副本；配合 11 位减法得到 `S_fifo_wr_num` 占用值） |
| `top`（本层 FF） | 45 | 37 | **−8 = `state_code_sd[3:0]` + `state_code50[3:0]`**，7 段数码管状态链 |
| `seg_scan_m0` LUT | 52 | 81 | 6 个探针数码管译码器取代 1 个 |

`AL_MAP_SEQ` 总账（含 `async_reg` 单元）：A 6242 → B 6463（+221）；其中 **6035 个完全相同**、**174 个仅部分引脚网名不同（175 处引脚）**、**A 独有 33 个**、**B 独有 254 个**。

- A 独有 33：`extensions/osd` 24（`b3/g3/body_base` 被并入 MSLICE，非删除）、`top` 8（数码管状态）、`sd_card_sec_read_write` 1（寄存器打包位置变化，未逐位展开）。
- B 独有 254：probe 95 + probe_display 93 + FIFO 同步 21 + `S_video_in_ready_reg` 1 + `video_delay` 21 + `rgb_to_axis` 12 + osd 5 + color_bar 2 + timing 2 + adjust 1 + transition 1。

TD `gate.qor` 的 `#async_reg` 从 128 增到 190（+62，恰为 `probe_display` 的 `status_meta[30:0]` + `status_sync[30:0]`），与上述账目吻合；`#syn_keep` 171、`#keep_hier` 136 两版相同。

证据：`evidence/ffsum.txt`、`evidence/seq_rgb.txt`、`evidence/subtree.txt`、`evidence/topseq.txt`、`evidence/summary_almapseq.txt`。

---

## 6. HDMI AXIS 逐信号

### 6.1 `tdata[23:0]`

A、B 中 `O_video_data_reg[23:0]` 的 24 个 FF **D/Q/CLK/CE/SR 网名完全一致**（`seqdiff` 对这些位没有输出任何 PINDIFF）。FF→`I_axis_s_data`→FIFO 写数据（`EG_PHY_BRAM.dia`）的位映射也一致：

- `I_axis_s_data[8:0]` → BRAM0 `.dia`，`[17:9]` → BRAM1，`[23:18]` → BRAM2（两份相同）。
- `.wea`：A=`.../I_axis_s_valid_syn_4`，B=`probe/av_syn_36` —— **同一信号，仅网名不同**。
- `.addra/.addrb/.ceb/.dob/.rsta/.rstb` 在 A/B 中**网名逐字相同**，其中 `ceb = .../I_fifo_rd_en_syn_8`（同一网名）。**这说明 A 的 FIFO 读使能/读地址/写地址并未因 `ready` 悬空而被削弱。**

### 6.2 `tvalid`

A：`O_video_valid_reg.q = u_hdmi.../I_axis_s_valid`（该网同时就是核的输入端口网）；
B：同一个 FF 的 q 改名为 `probe/av`，**B 中不存在 `I_axis_s_valid` 这个网**，核内部负载直接引用 `probe/av`。
两版的缓冲副本不同名：A=`I_axis_s_valid_syn_4`，B=`probe/av_syn_36`（都用于 BRAM `.wea` 与 OSD）。
**D/CE/SR 参数一致，仅网名与缓冲实例名不同，没有额外逻辑。**

### 6.3 `tuser`（SOF）

A：`O_video_user_reg.q = I_axis_s_user`，`D = S_frame_arm_i_syn_4`；
B：q 改名 `probe/au`（B 中没有 `I_axis_s_user` 网），`D` 改名 `O_video_user_n`。
两版 D 锥都是同一个 LUT3（`INIT=8'h20`，输入 `I_de`、`I_axis_s_valid`、`S_frame_arm`）；对该 3 变量锥做**穷举真值表（8 种输入）结果完全相同**（`cone_tt.py`，`evidence/tt_user.txt`）。这是有界证明，只覆盖这一锥。

### 6.4 `tlast`

- **两份网表都没有 `I_axis_s_last` / `axis_s_last` 网**：HDMI 核根本没有这个输入（被加密核在展开时去掉）。
- A：`O_video_last_reg` 与 `S_x_cnt[10:0]` 全部不存在（`O_video_last` 常量 0）。
- B：两者存在，q = `probe/al`，扇出只有探针（`probe` 内部 3 处）。
→ **last 的“恢复”纯粹是探针观测造成，不是视频功能修复。**

### 6.5 `tready`

- A：`S_video_in_ready_reg` 不存在，`axis_s_ready` 网不存在（顶层 wire 无负载 → 整条 ready 逻辑被删）。
- B：`S_video_in_ready_reg` 存在，q=`S_video_in_ready`，只被探针的 LUT 消费（探针内部 4 处），并反馈到自身 D 锥；同时 FIFO 中多出 21 个 11 位读指针同步副本 FF，并新增只在 B 出现的占用总线 `S_fifo_wr_num[10:0]`（由同步后的读指针与写指针相减，供 ready/almost-full 使用）。
- 关键：FIFO 的**读写指针/地址/读使能/BRAM 连接在 A 中仍然完整**（见 6.1）。因此 A 的“ready 被删”**没有改变 FIFO 的读写功能**，只是少了一个状态输出及其占用统计（`S_fifo_wr_num`）。

### 6.6 核内 FF 总账

`u_hdmi_1_4b_transmitter_core_wrapper` 子树：A 1529 / B 1551 个 `AL_MAP_SEQ`；**1466 个完全一致；63 个仅网名不同（62 个 audio_valid 相关：61 个 CE + 1 个 D；1 个 locked），0 个被删；+22 个 ready 相关**。`u_hdmi2phy_wrapper`：47/47 完全一致，LUT 形状与数量（12/10/10/2）也完全一致。

---

## 7. `O_video_locked`

- A：`u_video_axi_stream_receiver/O_video_locked_reg` 存在，q=`u_hdmi.../O_video_locked`，顶层无负载（悬空）。
- B：同一个 FF 的 q（也就是端口网）改名为 `probe/locked`，同时作内部反馈并送探针；**B 中没有独立的 `O_video_locked` 网**。
- 两者 D 锥相同（`O_video_locked_reg_syn_3`，由 `syn_4` LUT 产生）；该 5 变量锥的**穷举真值表（32 种输入）完全相同**（`cone_tt.py`，`evidence/tt_locked.txt`）。
→ **不是功能改动，是观测 + 网名别名**。locked 的寄存器在 A 中并没有被优化掉。

---

## 8. 黑场门控

`vout_data = display_valid_sync[1] ? vout_data_raw : 24'd0`（A 顶层第 374 行；B 同）在两份网表中实现为 24 个**完全相同的 LUT2**：

```
AL_MAP_LUT2 #(.EQN("(B*A)"), .INIT(4'h8))
  \transition/base_rgb_q_b[i]_syn_1 (.a(display_valid_sync[1]), .b(vout_data_raw[i]), .o(\transition/i_rgb [i]));
```

B 的 `transition/base_rgb_q_b[0]_syn_1` 与 A **同名、同参数、同引脚**。`display_valid_sync` 两级 FF（`sr=acr/I_rst`，即 video_rst）也完全相同。
→ 黑场门控本身没有差异；若 A 黑屏，只能是 `display_valid_sync[1]` 没有被拉高，或下游 TMDS 没有送出，而不是门控被改。

---

## 9. 音频 `audio_valid` 与数据

- `audio_valid` 由 `pcm`（`hdmi_audio_tone_pcm_scale.v(47)`）的 MSLICE 寄存器产生：
  A q=`acr/I_audio_valid`；B q=`audio_valid`。**同一条网，仅命名不同**。
- 该网在 A/B 中都驱动：`acr`、`U_audio_sample_packet_2_channel` 的 CE（61 个 FF）等。
- `pcm` 90/90 FF、70/70 LUT 形状完全一致；`acr` 47/47 FF、48/48 LUT 完全一致；`audio_output` 1 FF/4 LUT 一致；`u_w96_d1024_fifo` 55 FF、audio sample packet 142 FF 两版相同。
- `wav` 813/813 FF，781 个完全相同，32 个仅 CE 网名不同（`mux97_syn_71` vs `mux97_syn_2[0]`）。

→ **音频功能路径无差异**。“无声”不能由这段逻辑解释。

---

## 10. 时钟 / 复位 / CE

- `rs_video`：2 个 FF，`async_reg=true`、`preserve=true`，A/B 的 `pipe_reg[0/1]`、`pipe[0/1]_syn_*` 网名与参数**逐字相同**；输出 `video_rst` 在网表中名为 `acr/I_rst`（两版相同）。
- `rs_button/rs_sd/rs_mem`：各 2 个 FF，两版相同。
- `rst_cnt[19:0]`、`rst_all_reg` 的 D/CE/SR（`mux5_syn_2[19]`、`rst_all_reg_n1`）两版相同。
- `sys_lock_sync`、`video_lock_sync` 两版相同；`state_code_sd/50` 只出现在 A（数码管）。
- 时钟：`EG_PHY_GCLK` 仅 `sys_pll_m0/bufg_feedback`、`video_pll_m0/bufg_feedback` 两个，两版相同；`EG_PHY_PLL` 2 个；BRAM 时钟 `clka/clkb = extensions/osd/clk`（即 video_clk 的网名）两版相同。
- CE/SR 网名的差异只有上述 3 类重命名（audio_valid、wav mux、sd `candidate_view` CE 的等价重分解）。

---

## 11. 哪些只是 wire 别名，哪些是实际功能不同

### 11.1 纯别名（同一条网，不同名字/多一级缓冲）

| 功能 | A 网名 | B 网名 |
|---|---|---|
| AXIS tvalid | `u_hdmi.../I_axis_s_valid`（=FF Q=端口网） | `probe/av`（同网改名；缓冲副本 `probe/av_syn_36`） |
| AXIS tuser | `u_hdmi.../I_axis_s_user`（=FF Q） | `probe/au`（同网改名） |
| AXIS tlast | 不存在 | `probe/al` |
| O_video_locked | `u_hdmi.../O_video_locked`（=FF Q） | `probe/locked`（同网改名） |
| audio_valid | `acr/I_audio_valid` | `audio_valid` |
| video_clk | `extensions/osd/clk` | 同 |
| video_rst | `acr/I_rst` | 同 |
| FIFO 读使能 | `.../I_fifo_rd_en_syn_8` | 同（逐字） |
| BRAM 地址/控制 | 同 | 同（逐字） |

### 11.2 实现层重分解（同功能、不同 LUT 组合）

- `wav/parser`：373→373 LUT，38 个 INIT 形状不同（FF 引脚只差 CE 网名）。
- `sd_card_bmp_m0`：−9 LUT，`candidate_view` 的 CE 由 `cover_request_toggle_i1_syn_2` 重分解为 `write_done_i1_syn_2`（同 RTL 表达式，不同因式分解）。
- `extensions/osd`：24 个 `b3/g3/body_base` FF 在 B 中被 MSLICE 吸收（例：B 的 `EG_PHY_MSLICE \extensions/osd/b3_reg[4]_syn_4` 直接做 `b3_b4[4] + bg_calc[0] → b3[4]`，A 是 LSLICE 加法 + 独立 FF）。
- `hdmi_edid`/`iic`：±3~4 LUT，FF 全部相同。

### 11.3 已检查端点上的功能差异

**在已检查的端点（AXIS、FIFO、黑场门控、音频、复位/时钟、两个小锥）上未发现功能差异；全等价未证。** 唯一“非观测”的行为变化是 **7 段数码管显示内容**（A 显示 `display_state`，B 显示探针 5 页），以及因此删掉的 8 个状态 FF。

---

## 12. 常量传播 / FF 合并 / 逻辑保留（探针引起）

| 类别 | 具体 | 数量 |
|---|---|---|
| 观测保留 | `hs_d[20:0]`（video_delay） | 21 |
| 观测保留 | `color_bar` hs 2 + `video_timing_data` hs 2 + `transition.o_hs` 1 + `adjust.o_hs` 1 + `osd` hs 同步 5 | 11 |
| 观测保留 | `S_x_cnt[10:0]` + `O_video_last_reg` | 12 |
| 观测保留 | `S_video_in_ready_reg` + FIFO 读指针同步/占用副本（`S_fifo_wr_num`） | 22 |
| 观测保留 | 探针本体 + 探针显示（probe 95 + probe_display 93） | 188 |
| 常量传播 | A 中 `O_video_last=0`、`O_axis_s_ready`/HS 链被删（因无消费者） | — |
| FF 合并 | 未发现真正的 FF 合并；`b3/g3/body_base` 是**打包进 MSLICE**，不是合并 | 24（位移） |
| 删除 | `state_code_sd[3:0]`、`state_code50[3:0]`（7 段数码管） | 8 |

> 说明：TD 日志里 `SYN-3010: Optimized 401 DFF(s)`（A）/`403 DFF(s)`（B）是工具对 DFF 的通用优化计数，并不对应上面这些差异；上面的差异是**逐 FF 对比**出来的。同名的 D 网名相同仅是强相关证据，不等于其驱动锥已证等价（见第 16 节）。

---

## 13. 物理实现差异（供 B 参考，本报告不做 STA 结论）

| 指标 | A（黑屏） | B（成功） |
|---|---|---|
| slices | 5824 | 5945 |
| wire length | 1,187,000 | 1,209,976 |
| gate 映射阶段 `Confidence: Synthesized`（**非 post-route**） | setup −0.659 / hold +0.471 | −0.649 / +0.471 |
| place（hold fix 前） | +1.807 / −0.011 ns（13 个违例端点） | +1.857 / −0.011 ns（11 个） |
| `route.qor`（hold fix 前快照） | +0.813 / +0.019 ns | +0.039 / +0.011 ns |
| **最终签核 `runs/<id>/final_timing.rpt`**（= `after_hold_fix.rpt`，对应被测 bit） | **+0.813 / +0.022 ns** | **+0.039 / +0.030 ns** |
| video_clk fanout（gate/final） | 3012 / 1813 | 3164 / 1926 |
| STA 覆盖 | 99.92%（`runs` 报告 99.93%） | 99.92% |
| 最终报告 SHA256 | `65DF375B3DB8C018…`（`runs`） | `BFF93F0A357478C5…`（= 冻结 `reports/final_timing.rpt`） |

说明：
1. **`phy_1/final_timing.rpt` 与 `phy_1/route.qor` 是 hold fix 之前的快照**（A 为 +0.813/+0.019，B 为 +0.039/+0.011）；被测 bit 由 hold fix 之后的 `runs/<id>` 报告签核。此前“文档 +0.030 与报告不一致”的判断**撤回**：`HARDWARE_PASS_BASELINE.md` 的 +0.030 正确，是我读错了文件。
2. `hx4s20_basic_gate.timing`/`gate.qor` 的 `Confidence` 是 `Synthesized`，其负 WNS 是映射后估算，不能当作 post-route 结论。
3. A 的 setup 余量**更好**（+0.813 vs +0.039），hold 也通过（+0.022 vs +0.030），却黑屏；这只能说明“黑屏不是常规 setup/hold 违例能解释的”，嫌疑更偏向**约束覆盖之外的路径**（HDMI 5x/TMDS 域、核内复位同步/removal、启动顺序、未定义初值）或**位流配置/时钟树**。STA 仅覆盖已约束路径（99.92%），`check_timing` 显示 0 个无时钟端点、4 个 local clock、3 个 dangling 模型（列出的都是 LSLICE/MSLICE 内部未用引脚）。

---

## 14. Root 的两个反向实验：预期观察与检查方法（本报告不实施）

不再建议“换 seed 重跑 P&R”（用户明确禁止）；且即使换 seed 成功，也只能说明实现敏感，**不能单独排除未定义初值/启动类设计问题**。

### 实验 A：`Probe.locked(1'b0)`（去掉 locked 的探针观测）
预期（用 `obs_check.py` 检查新 `gate.v`）：
- `probe/locked` 网**不存在**；
- `u_hdmi…/O_video_locked` 只剩 **3 个核内负载**（`O_video_locked_reg_syn_4.b`、`O_video_source_pause_reg_syn_4.b`、`I_rst_syn_7.b`）；
- `probe_display/status_meta_reg[0]` 的 D 变为常量 0，该位 FF 可能被删除（status_meta_reg/status_sync_reg 31→30）。
若新网表里 `probe/locked` 仍存在或 `O_video_locked` 仍有探针/显示负载 → 观察锥没有真正移除，实验无判读价值。

### 实验 B：`probe_display.flags_async({23'd0,probe_flags[4:0]})`
预期：
- `probe_display/status_meta_reg` 与 `status_sync_reg` 从 31 个变为 **8 个**（bits 30:28 仍为 video_lock/sys_lock/video_rst，bits 4:0 为 flags[4:0]；bits 27:5 变常量 0）；
- `probe/flags` 被 `probe_display` 引用的位只剩 **4:0**（基线是 1,3,4,6..26）；
- `probe` 内部负责 flags[27:5] 的逻辑可能被裁剪，属预期。

> Astra 后续实测勘误：以上 status FF 数量缩减预测未发生，原 RTL 对数组的 preserve 属性使 A/B 实验均保留 31/31 个显示同步 FF。但 B 的 bits27:5 D 实际全部接常量0，ready/TLAST/帧行观察锥已删除；A 的真实 locked 外部负载已删除。实验有效性以实际输入/扇出/逻辑锥为准，不能仅用同步 FF 个数判断。

脚本：`obs_check.py gate.v`（现状基线：A 无 probe，B 为 31/31、flags 高位全被引用）；`fanout.py` 查任意网的精确负载；`ps/export_gate_v.ps1` 对 gate.db 副本只读导出。

### 判读边界
- 实验 A 若仍黑屏：由于 A 原版 bit 里 locked 的 FF 本就存在（本报告已证），应进一步**降低 H1**（“locked 悬空导致功能被删”）的权重，而不是继续围绕 locked 找根因。
- 实验 B 若仍正常：说明 flags 高位观测锥可移除而不影响出图，支持“探针主要改变实现而非功能”。
- 两个实验都不能单独证明“纯物理问题”：也可能是启动/未定义初值等不在这两个锥里的因素。

---

## 15. 复现方式

远端（只读，输出只在 scratch）：
```powershell
# 1) 复制映射库（不改原目录）
Copy-Item D:\FPGA\EG4S20-NoBot\...\syn_1\hx4s20_basic_gate.db D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a\a_gate.db
# 2) 只读导出，不执行任何优化/布局/布线/bitgen
G:\anlu\bin\td_commands_prompt.exe D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/dump_a.tcl
# 3) 结构对比（Python 3.12，远端）
python netcmp.py summary a_gate.v b_gate.v
python seqdiff.py a_gate.v b_gate.v <hierarchy>
python ffsum.py  a_gate.v b_gate.v
python subtree.py a_gate.v b_gate.v u_hdmi_1_4b_transmitter_core_wrapper
python brampins.py a_gate.v b_gate.v
python luthist.py a_gate.v b_gate.v <hierarchy>
```

本地脚本（均已放入 `worker_a/`）：
`netcmp.py`（解析/汇总/常量）、`seqdiff.py`、`listseq.py`、`ffsum.py`、`subtree.py`、`pindiff.py`、`pduniq.py`、`cmpcells.py`、`luthist.py`、`cone.py`、`leaves.py`、`brampins.py`、`toplist.py`、`findnet.py`、`regstats.py`、`paramhist.py`、`inspect_cells.py`，以及新增的 `fanout.py`（网负载）、`obs_check.py`（探针观测锥检查）、`cone_tt.py`（小锥真值表）。
远端 Tcl 由 `ps/mk_tcl_dump.ps1` / `ps/mk_tcl_dump_b.ps1` 生成（`dump_a.tcl`/`dump_b.tcl` 只存在于远端 scratch）；通用导出脚本为 `ps/export_gate_v.ps1`（参数 `-Db`/`-Out`，只读）。

紧凑证据：`worker_a/evidence.json`；明细文本在 `worker_a/evidence/`。

---

## 16. 限制与不确定点（必须随结论一起引用）

1. **没有 SAT/形式等价证明**；“整个视频/音频网表等价”**不成立为主张**。本报告的结论是：**在已检查的端点上未发现功能差异；全等价未证**。
2. `wav/parser` 373→373 LUT，其中 **38 个 LUT 形状不同，未逐位验证**其布尔等价。
3. `sd_card_sec_read_write` 的 **A 独有 1 个 FF 未展开**（只知是寄存器打包位置变化）。
4. OSD `b3/g3/body_base` 24 个 FF 移入 MSLICE，仅对 `b3[4]` 做了逐点核对，**其余 23 个未证明**。
5. **“同名 FF 的 D 网名相同”不等于其驱动锥逻辑必然相同**；本报告把它作为强相关证据，不作为证明。只有两处小锥（`O_video_user` D、`O_video_locked` D）做了**有界穷举真值表**（3 变量/8 种、5 变量/32 种），其余锥未验。
6. 加密 HDMI 核内部 RTL 不可见；核内结论来自 TD 展开后的门级网表（`write_verilog` 输出），不是厂商源码。
7. 未做 post-route 网表对比，未运行任何时序查询命令；本报告不给出时序根因结论。`phy_1/final_timing.rpt`/`route.qor` 为 hold-fix 前快照，最终值见第 13 节。
8. `tlast` 的结论仅限于“该配置展开后的 mapped 锥未使用该端口”，不代表其它配置/其它核参数下也不使用。
9. 未下载大网表到 Mac；全部在远端分析，仅回传文本证据。
