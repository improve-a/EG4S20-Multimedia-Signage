# NoBot RCA A/B 实板测试记录

日期：2026-10-20  
板卡：HX4S20C / EG4S20BG256 / HDMI_B  
工具：Tang Dynasty 6.2.168116，JTAG SRAM 下载  
范围：仅测试实验 A、B；未修改 RTL、未重新构建、未操作 TF 卡或 SPI Flash。

## 结论状态

- 实验 A：**HARDWARE_FAIL**（黑屏、无声音）。
- 实验 B：**HARDWARE_PARTIAL**（HDMI 锁定稳定、OSD 可见，但主图片缺失、音频异常）。
- 完整 HDMI Probe：既有实板 PASS 记录，本次未重新测试。
- 根因：**ROOT_CAUSE_UNRESOLVED**；C/D 异常的因果关系尚未确认。

## 精确位流与预检查

| 实验 | 位流 | SHA-256 | 构建 |
|---|---|---|---|
| A | `D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_no_locked_003.bit` | `cce449034505c4d5c61a856b94b48c4c3d7e20a3eb86627972763a1981ca46a5` | `5162f235103c1d55af346706141ed0c6d4aad5ec`，FINISHED，Setup +0.423 / Hold +0.024 ns |
| B | `D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_locked_only_001.bit` | `41848d2090bc22695be98f096167005c4aceaecffbd6d20ecb0dc5b7440dba4a` | `90263aa08c7c9625178b92b3eaccbe3a368b9c5b`，FINISHED，Setup +0.106 / Hold +0.027 ns |

- 两位流均为 677348 字节；交付目录 16 项哈希全部通过。
- JTAG `read_device_id -cable 0` 返回 `EG4S20BG256`。
- A、B 均由用户手动断电/重新上电后分别下载；A 下载后观察到结果，B 在再次断电重上电后下载。
- 未自动恢复其他位流。

## 实验 A

### 人工观察

- 画面：黑屏。
- 声音：无。
- 六页图像轮播：黑屏无法判断。

### 数码管原始读数与还原

原始读数：`100001, 012222, 001123, 011114, 011025`。  
按实际显示方向逐页反序：`100001, 222210, 321100, 411110, 520110`。

| 页 | 还原值 | 含义 |
|---|---|---|
| 1 | `100001` | A 已固定 `.locked(1'b0)`：locked=0、曾锁定=0、稳定=0、失锁=0、超时=1；**不是真实锁定证据** |
| 2 | `222210` | VS/DE/HS 活动码均为 2；frame_good=1、frame_bad=0 |
| 3 | `321100` | AXIS valid 活动码=2；user/last 均曾出现；user_bad=0、line_bad=0 |
| 4 | `411110` | ready 曾高=1、曾低=1、**C=valid且ready低=1、D=有效行首且ready低=1**、no_de=0 |
| 5 | `520110` | audio_valid 活动码=2；video_rst=0；sys PLL=1；video PLL=1；heartbeat 采样为 0（正常翻转） |

**更正：此前把 `011114` 误记为“无 C/D 冲突”。正确还原为 `4.11110`，C、D 均为 1。**  
C/D 是保留到 `video_rst` 的 sticky 标志，因此只能证明自上次视频复位以来至少发生过一次，不代表观察时仍持续发生。

## 实验 B

### 人工观察

- 画面：非全黑；可见字幕、品牌、OSD 页码 `01/06`，但主要图片缺失。
- 声音：异常（未细分杂音、断续、变调或其他性质）。
- 六页图像轮播：主图缺失，无法确认正常轮播。

### 数码管原始读数与还原

原始读数：`001111, 000002, 000003, 000004, 011005`。  
反序还原：`111100, 200000, 300000, 400000, 500110`。

| 页 | 还原值 | 含义 |
|---|---|---|
| 1 | `111100` | locked=1、曾锁定=1、稳定=1、失锁=0、超时=0；真实 HDMI 锁定稳定建立 |
| 2–4 | `200000/300000/400000` | B 实验只显示 `flags[4:0]`，帧/AXIS/ready 字段被固定为 0；**不能据此判断这些路径** |
| 5 | `500110` | video_rst=0；sys PLL=1；video PLL=1；音频活动码和 heartbeat 被屏蔽/为 0，不能据此判断音频 |

B 的 OSD 可见说明 HDMI 视频链路至少能输出有效 TMDS/视频帧；主图缺失和音频异常更偏向内容提交、显示门控或媒体数据路径，而不是简单的 PLL/视频复位未释放。

## 探针 RTL 的 C/D 条件

`hdmi_probe.v` 在 `video_clk` 上采样：

```text
C = backpressure
  = sticky(av && !ready)

D = sol_conflict
  = sticky(av && !prev_av && !ready)
```

其中 `av` 是 RGB→AXIS 的 `O_video_valid`，`ready` 是 HDMI 核 `O_axis_s_ready`。  
两者都在 video_clk 域；`prev_av` 是前一拍 valid。C/D 只在 `rst`（`video_rst`）时清零，否则一旦置位永久保持。

实际 mapped LUT 表明探针看到的 `ready` 等价于：

```text
ready_seen = S_video_in_ready && !S_fifo_pro_full
```

因此：

```text
C = flags[20] | (av && (S_fifo_pro_full || !S_video_in_ready))
D = flags[21] | (av && !prev_av && (S_fifo_pro_full || !S_video_in_ready))
```

`S_fifo_pro_full` 是 HDMI 接收 FIFO 的 programmable-full 状态，参与正常流控。C/D 不区分“启动瞬态”“行边界/FIFO 满”和“行内持续冲突”。

## 映射网表对照

- 完整 Probe 和实验 A 的 C、D 组合锥在各自 gate 网表上分别以 4 个、5 个自由叶变量穷举，**真值表完全相同**。
- 完整 Probe 和 A 的 `probe` 模块、`video_rgb_to_axis_640x480.v` 逐字节相同；A 的顶层唯一探针差异是 `.locked(1'b0)` 代替真实 locked。
- 原始 NoBot 没有 C/D 探针，且 ready 未观察，不能从原版网表直接得到 C/D。
- 因此 C/D 从完整 Probe 的 0 变为 A 的 1，**不能归因于 C/D 逻辑被改写**；它只能来自运行时/启动相位、FIFO 流控状态，或重新布局后 valid/ready 在探针采样点的相对时序。

## 显示 CDC

- `flags` 在 video_clk 产生，`probe_display` 在 50MHz 域用两级 `async_reg` 同步。
- 28/31 位状态是逐位同步，不保证多位原子快照；但 C/D 是单 bit、且为 sticky，稳定后不会因 CDC 产生单周期假 1。
- 页计数在 50MHz 域独立运行，约 3 秒一页；C/D 显示的是异步同步后的保持值，不是实时脉冲。
- `video_rst_async` 也单独同步；复位释放附近显示可能出现短暂旧值，不能据此判断模拟毛刺。

## 四个问题的当前回答

1. **C/D 能否在正常行间背压或启动过渡时置位？**  
   可以。行间 `valid=0` 时不会置位；但如果行首 valid 已经为高而 ready 仍低，或 FIFO 进入 pro-full，C/D 会置位。启动/复位释放、FIFO 初始填充和行边界都可能产生这种单拍事件，之后 sticky 到下次视频复位。

2. **C/D=1 是否说明真实 AXIS 接收时序冲突？**  
   它证明探针采样点上至少发生过一次 `valid && !ready`，D 还证明发生在 valid 上升沿；这是真实采样事件，不只是显示噪声。但当前标志没有时间、持续拍数或行号，不能区分一次性启动/边界事件和持续行内冲突。D=1 比 C=1 更值得优先追查，但仍不足以单独证明接收器持续丢像素。

3. **去掉 locked 观测后，为什么 ready/valid 相对行为可能变化？**  
   逻辑上不应变化：C/D 锥、RGB→AXIS 和 ready 产生逻辑均未改，两个 C/D 真值表相同。变化只能来自重新布局/布线后 valid 与 ready 的到达相位、FIFO 初始占用/启动顺序，或探针在 video_clk 上对两者采样时的相对延迟；也可能是不同上电周期的 run-to-run 差异。锁定位负载的移除改变了核心/观察逻辑的物理布局，但不能据此说 locked 功能导致 C/D。

4. **这些冲突足以解释 HDMI 黑屏，还是伴随现象？**  
   目前只能作为**优先异常/可能 contributory，不能作为充分根因**。A 的 C/D=1 与黑屏同时出现，但它是 sticky 的单次事件记录；A 的页 2/3 同时显示完整帧和 AXIS user/last 正常，不能证明持续丢行。B 的 HDMI 锁定和 OSD 正常而主图缺失，说明 B 的剩余故障更偏内容/门控，不是全局视频链路；B 又屏蔽了 C/D，不能用于对照。需要时间分辨的 C/D 和 `display_valid`/loader 状态才能判定。

## 假设影响

- **综合优化敏感（H1）**：仍有支持。两个只改变观察边界的版本都未恢复完整功能，且 C/D 逻辑相同但行为不同；但这不是某个具体逻辑被错误删除的证明。
- **布局/物理实现敏感（H2）**：支持增强。C/D 真值表相同而 sticky 结果不同，且 A/B 的失败层面不同，符合重布局/启动相位敏感；仍不能排除 run-to-run 差异。
- **时钟/复位/CDC（H3）**：简单“PLL 未锁/复位未释放”被 B 的 `locked=1`、`video_rst=0`、双 PLL=1 削弱；但 ready/valid 采样相位、FIFO 启动和跨域显示仍是候选。
- **探针意外功能改动（H4）**：没有源码级支持；探针/功能模块逐字节相同，差异只在顶层观察连接。

## 禁止的修复方向

- 不采用 `valid &= ready` 直接门控；APUG092 要求有效行内保持连续输入，直接门控会制造行内断流。
- 不因 C/D=1 就增加随机寄存器、延长复位或改 FIFO/SDRAM 架构。
- 不在未确认持续冲突前修改 RTL 或生成新位流。

## 后续建议（本轮不执行）

1. 如需确认 B 的主图/音频异常是否可重复：再次手动断电、重上电，仅重测 B 一次；这不改变位流，也不自动切换。
2. 下一轮若获授权，做一个**时间分辨**的最小观察版本：按窗口统计 C/D 次数、首次置位所在行/帧，并同时观察 `display_valid`、loader 状态和音频 WAV 状态；不要只增加 sticky 位。
3. 在确认 C/D 是否持续后再决定是否修改流控。若确认行内冲突，应修正接收 FIFO/ready 边界或源端缓冲策略，同时保持 APUG092 要求的行内连续输入，而不是简单 gating。
4. 如需恢复完整 Probe，先向用户确认；本轮不自动恢复。
