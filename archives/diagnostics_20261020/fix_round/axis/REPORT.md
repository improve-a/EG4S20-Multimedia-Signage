# HDMI/AXIS 定向复查（Worker A，修订版 2026-10-20）

**身份**：DeepSeek V4.1 Flash 1017（Root 子 Worker）。
**范围**：只读源码/映射网表 + 本地/远端 iverilog 短测试；未改生产 RTL/顶层/约束/构建，未重跑 TD 综合/PNR，未 JTAG/Flash/TF，未覆盖旧证据。
**本轮修订**：按 Root 审查更正 5 点，并复用 `D:\FPGA\EG4S20-NoBot-HWFix\output\offline_debug\astra_hdmi_phase` 的 netlist-derived 控制模型做启动/重捕获有界测试。

## 0. 结论（收窄后）

1. **`wea=I_axis_s_valid` 只说明 BRAM 写端口在 valid 拍被使能，不能证明像素成功入队。** 真正入队还需要 FIFO 写地址 CE/指针推进、非 full、复位释放；这些由 `mapped_receiver_control` 的 `write_go`/`write_address` 控制。复用模型显示：合法 640×480 时序下 `write_go` 与 valid 同步、地址每次写都推进、无 blocked write、最大占用 10；fill-only 负控在 1024 次写后地址停住并 blocked，证明“wea=valid 但 full 时地址不推进”是真实机制。
2. **C/D（`valid && !ready`）不是本轮可证明的丢失机制，也不能称为“已定位的永不恢复节点”。** 它只记录 ready 输出锥（`S_video_in_ready && !pro_full`）的一次采样；在合法时序下复用模型未找到 C/D 导致的 FIFO 丢失反例。
3. **`locked` 是功能信号**：`fifo_reset = core_reset | !locked`。FIFO 指针 FF 的物理 `SRMODE="ASYNC"`、`sr=I_rst`；BRAM 为 `RESETMODE("SYNC")`。因此 `locked` 低会清 FIFO 指针，`locked` 跳变是**异步复位沿**。这是目前最强的“启动/恢复状态”直接联系，但功能模型没有复现永不恢复；它指向物理/复位路径风险，不是可直接改的 AXIS 逻辑错误。
4. **A 的 `.locked(1'b0)` 只改探针输入，不等于内部 locked=0**；A 的真实 locked 不可观测。**A 只恢复 `.locked(probe_video_locked)` 就是原完整 Probe 的同一 top**，不能当新实验；此建议已删除。
5. 实验 B 的 `S_fifo_empty` 节点名 MISSING **不等于 empty 逻辑删除**：B 的 `I_fifo_rd_en_syn_8` 仍是 LUT4 `period && !empty`，empty 为 11 位指针 XNOR 比较，BRAM `ceb` 仍接它。B 的固定名 ready/pro_full 节点缺失只是名称层面，不能据此断言整个 ready 分支删除。
6. **合法 source 下具体会丢什么**：lock 捕获时 `fifo_rst=!locked` 会吞掉 **1 个首像素**（A35390: reset_blocked=1）；若 first user 在捕获窗口外，会先丢 **整帧 307200 像素**、下一帧再锁（FIRST=10: reset_blocked=307201），之后 blocked=0。前者是 1 像素，后者是首帧；都不是 C/D，也不是永久失锁。若 locked 反复掉锁/重捕获，才会重复丢帧/首像素——这是真正与启动状态直接相关的路径。
7. **APUG092 的 ready 方程确实消费 `I_axis_s_last`**：`S_video_in_ready_next = !last && (empty || ready)`。此前“HDMI 两版都不消费 TLAST”的表述应更正为：**TLAST 被 ready 输出锥消费；未见数据写口 `wea`、locked/pause 锥依赖 TLAST**。legacy NoBot 中 ready 输出无观察者，TLAST 随 ready 锥被优化，这不等于核心完全不用 TLAST。

**给 Root 的一句话**：目前没有可行动的 AXIS RTL 修复；不要加 `valid&=ready`，不要为 C/D 改 FIFO/加寄存器，也不要把恢复 locked 观测当新实验。若继续追，优先检查 `!locked` 作为 FIFO 指针异步复位沿的 recovery/removal/物理稳定性；否则把 AXIS 从本轮根因候选降级，转查 `display_valid`/媒体/TMDS。

---

## 1. APUG092 原文契约

本地真实文件：
`/Users/mac/Documents/ChatGPT/安路赛题一/reports/hardware_APUG092_HDMI1.4b_Transmitter_V1.0.txt`
SHA-256 `a6051ff95cc26dd1f30d9d0071675fea5f9e5895ca60502dbd403925a625878f`；docx `070b22d3…1543`。

页码取自文档目录：
- **§2.4.2 Video Interface，文档页码 9**；
- **§2.3.2 接口信号说明 / 表 2-2，页码 7**。

逐字要点：

> `I_axis_s_user`是帧起始信号，为一个单时钟周期信号，在第一行第一个有效数据拉高。`I_axis_s_valid`是数据有效信号，`I_axis_s_last`是行结束信号，在一行数据的结尾拉高。`O_axis_s_ready`是接收端准备信号，为高表示可以写入数据。
>
> 需要注意的是：`O_axis_s_ready`只会在`I_axis_s_last`为高之后拉低，再次拉高表示能够正常写入数据，因此 Video Interface **不支持断续的数据输入，一行数据输入必须连续**。

同节：

> 当内部和外部的视频时序对准并且锁定之后 `O_video_locked` 信号会拉高，表明视频输入数据被正确捕捉。

以及 `line_length=HACTIVE`、`line_space=HTOTAL`、`frame_space=VTOTAL`。

**契约解释**：ready 是**行级信用/相位握手**，不是逐拍 `valid` 许可；行内必须连续。`locked` 是内外时序相位对准/正确捕捉，不是普通 PLL lock。

---

## 2. 源端：何时推进像素，以及“入队”还缺什么

源码：`rca_ab_sources/A/work/design/user_source/hdl_source/video_rgb_to_axis_640x480.v`
A/Probe/B 三份提取源逐字节相同，SHA-256 `c051f6df…c2c77`。

等价节选：

```verilog
O_video_valid <= I_de;       // 每个 I_de 拍都推进，无 ready 输入
O_video_data  <= I_rgb;
if (I_de && !S_de_1d) begin  // 行首
    S_x_cnt <= 0;
    if (S_frame_arm) O_video_user <= 1;
end else if (I_de) S_x_cnt <= S_x_cnt + 1;
if (S_de_1d && S_x_cnt == 638) O_video_last <= 1; // 第640个有效像素
```

- 源没有 `ready/tready` 端口；valid 只随 DE 推进。
- `user` 与首个 valid 对齐；`last` 与第 640 个 valid 对齐。模型 `sample_line`：`(640,1,1)`、随后 `(640,0,1)`。
- 源满足“行内连续”，但不等待 ready 再起一行。

**重要更正**：`wea=I_axis_s_valid` 不能推出“每个 valid 像素都成功入队”。实际 FIFO 写地址/指针由 `write_go`/`write_address` 控制；`write_go` 还受 FIFO 状态影响。见 §4。

---

## 3. mapped 接收核关键节点（A/Probe/B）

数据源：

| 标签 | 文件 | SHA-256 |
|---|---|---|
| A `rca_no_locked_003` gate | `netcheck\rca_no_locked_003\gate.v` | `7d3c349e25bfa66a5fcd4d6699a747ad418a3d2185a1da3a0d3eeff8f6004012` |
| A 布线后 | 同目录 `mapped.v` | `d4b08f73ed8d59efe5487483846b17e281b843702456706ca76aea3e06f96bab` |
| Probe 基线 gate | `worker_a\b_gate.v` | `9a55c0109bebc486d93893e66ba44ec76994a0a8251968a92f8fa713ee84b7c0` |
| B `rca_locked_only_001` gate | `netcheck\rca_locked_only_001\gate.v` | `e134095c91135bf9cf407098ca6d6354cabb8cbe52c7c295b5cdbca72f18cf26` |

### 3.1 写口与地址

A 三块视频 FIFO BRAM：

```text
.wea(\probe/av_syn_36)     // valid 别名；不是 valid&&ready
.addra(write_address bits)
.rsta/rstb(.../u_w24_d1024_fifo/I_rst)
.ceb(.../I_fifo_rd_en_syn_8)
.clka=clkb=\extensions/osd/clk
```

Probe 同 `probe/av_syn_36`；B 为 `probe/av_syn_4`。`wea` 不使用 ready。

但 `wea` 只是 BRAM 写端口；**写地址/指针推进**由 FIFO 控制锥的 `write_go`/`write_address` 决定。复用 `mapped_receiver_control.v`（来自 legacy NoBot mapped，81 FF/27 LUT outputs）显示：

- `write_go` 与合法源 valid 同步；合法 640×480 测试中 blocked write = 0；
- 写地址是 Gray 码（0,0,1,3,2,6,7,5,4,12,…），每次 accepted write 都变化，无重复地址；
- fill-only 负控（valid 恒高、read_en=0）写入 1024 个唯一地址后 `write_go` 停住，之后 1963 拍 blocked；
- 因此“wea=valid”在 full 时不会继续推进地址，不能把 wea 当作入队成功证明。

### 3.2 ready 方程与 TLAST

A/Probe：

```text
S_video_in_ready_reg_syn_4:
  AL_MAP_LUT3 .EQN("(~C*~(~B*~A))") .INIT(8'h0e)
    .a = S_fifo_empty
    .b = S_video_in_ready
    .c = \probe/al              // I_axis_s_last
```

即：

```text
S_video_in_ready_next = !last && (fifo_empty || S_video_in_ready)
```

`S_video_in_ready_reg` 的 `REGSET("SET")`：复位置 1。

**TLAST 更正**：`last` 被 ready 输出锥消费；legacy A 无 ready 观察者时，ready 锥被优化，TLAST 随之消失。**不能再说“HDMI 在两版都不消费 TLAST”**。但数据写口 `wea`、locked/pause 锥没有 TLAST 依赖；TLAST 不是数据入队条件。

### 3.3 观察到的 ready 与 pro_full

A 中 `S_fifo_pro_full` 的 4 个负载全部在 probe 的 ready/C/D LUT 里；`ready` 输入被内联为：

```text
ready_seen = S_video_in_ready && !S_fifo_pro_full
```

`pro_full` 只服务 ready 输出/探针，不是写使能。

### 3.4 读口

```text
I_fifo_rd_en_syn_8  AL_MAP_LUT2 .EQN("(B*~A)") .INIT(4'h4)
  .a = S_fifo_empty
  .b = I_fifo_rd_en       // u_hdmi_video_source/O_video_period_reg
```

即 `fifo_rd_en = video_period && !empty`；不依赖 locked/pause/pro_full。

### 3.5 FIFO reset 与 locked（功能路径）

```text
I_rst_syn_7 AL_MAP_LUT2 .EQN("~(B*~A)") .INIT(4'hb)
  .a = core reset (iic receiver I_rst)
  .b = O_video_locked (Probe/B: probe/locked)
  .o = u_w24_d1024_fifo/I_rst
```

`~(B*~A) = A | ~B`，即：

```text
fifo_reset = core_reset | !locked
```

- 同一 LUT2 在 legacy NoBot `worker_a/a_gate.v`（SHA `844540a4…b4bd`）也存在。
- **物理属性（不是只看 .sr）**：视频 FIFO 指针/地址 FF `u_logic_ramfifo[0]`:
  `SRMODE("ASYNC")`, `SRMUX("SR")`, `sr=I_rst`；BRAM 参数 `RESETMODE("SYNC")`。
  因此 `locked` 低/跳变会异步清 11 位 FIFO 指针/地址；BRAM 复位是同步模式，但指针 FF 是异步 SR。
- 这使 `locked` 不只是状态输出；它是“启动/恢复状态”的直接功能路径。但**功能模型没有证明它会永不恢复**，见 §5。

### 3.6 locked/pause FSM

```text
locked_next = (user && pause) || (locked && (!sol || valid))
pause_next  = !locked && (sof || (!user && pause))
```

两个锥都不使用 ready/TLAST。`locked` 在 `user&&pause` 置位；在 `locked && !valid && sol` 掉锁。

---

## 4. A / Probe / B 定向对照

### 4.1 A vs Probe

逐细胞 diff（`evidence/snippets_diff_expA_vs_probe.txt`；**cell 函数/引脚层面，不是 whole implementation/timing 等价**）：
- ready LUT3、`wea`、`I_fifo_rd_en`、`O_video_period`、locked/pause D 锥相同；
- 唯一功能差异是 locked 网名：A `O_video_locked` vs Probe `probe/locked`（同一 FF Q 别名）；
- 其他差异只有 `open_n` 自动编号。

A 的 `O_video_locked` 3 个负载（自身 D、pause D、FIFO `I_rst_syn_7.b`）；Probe 10 个（+7 探针/显示）。功能负载都在 A 中；**移除 locked 探针没有删除 locked 功能，但把扇出 10→3，可能改变 `I_rst` 到达/复位沿时序**。这是 H2 物理敏感的具体节点，不是 C/D 逻辑改写。

### 4.2 实验 B：empty 逻辑没有整体删除

B 中固定名 `S_fifo_empty`/`S_fifo_pro_full` 节点名未找到；**这不能证明 empty/ready 逻辑整体删除**（可能被改名/打包）。因此我们直接追 B 的 `I_fifo_rd_en_syn_8` 实体，其驱动锥：

```text
AL_MAP_LUT4 .EQN("(D*~(C*B*A))")
  a/b/c = 11 位指针 XNOR 比较树（empty）
  d     = O_video_period_reg
```

即 **`rd_en = period && !empty` 仍在**；BRAM `.ceb` 仍接 `I_fifo_rd_en_syn_8`。所以 B 的 empty/读控制没有被整体删除；固定名 ready/pro_full 节点缺失只是名称层面，不能据此断言整个 ready 分支消失。证据：`evidence/expB_rd_en_cone.txt`，`check_mapped_contract` PASS。

### 4.3 B 的现象

B 页1 locked=1、稳定=1；HDMI 出 OSD/字幕/品牌；主图缺失、音频异常。B 的固定名 ready/pro_full 节点缺失（名称层面），但 empty/read 控制仍在，HDMI 仍出图 → 不能把“ready 节点名缺失”当作 HDMI 出图必需性的证明；能说的是这些固定名观测节点不是 B 出 OSD 的必要条件。主图/音频更指向 `display_valid`/媒体/内容，而不是 AXIS；但这是不同故障层面，不假设与 A 共同根因。

### 4.4 CDC/时序边界收窄

- 上述节点都在 `extensions/osd/clk` 25 MHz；FIFO 读写同钟。
- probe 的 25→50 MHz 状态位用 `async_reg/preserve` 两级同步；**“稳定 sticky 经 2FF”不能保证绝对无 CDC 误报**：单 bit 慢变信号通常安全，但多位/异步复位释放附近仍可能有采样不确定性；本报告不把“2FF”当绝对证明。
- “same cell 函数相同”只证明该 cell 的布尔函数/引脚；**不证明整个相关实现、布局、到达时间、复位 recovery/removal 全等**。A/Probe 的 locked 扇出差异就是反例边界。

---

## 5. 复用 netlist-derived 控制模型：启动/重捕获有界测试

### 5.1 模型与边界

- 复用 `/D:/FPGA/EG4S20-NoBot-HWFix/output/offline_debug/astra_hdmi_phase/mapped_receiver_control.v`：
  由 legacy NoBot mapped `routed_init_no_bot_legacy_004/mapped.v`（SHA `36edbd1a…d10d`）提取的 81 FF/27 LUT 输出接收/FIFO 控制锥；包含 locked/pause、fifo_rst、write_go/read_go、10 位 write/read address。
- **不是 A/Probe 专属重新提取**。共享依据：A/Probe 的 locked LUT5 INIT `32'hfcccf444`、pause LUT4 INIT `16'h2232`、fifo_rst LUT2 `~(B*~A)` 与 old 模型常量一致；A 解码的 source SOF/SOL 时序与 old 相同（`timing_expA.json` = `decoded_timing.json`）。写地址/CE 的 A 专属逐 FF 等价未证；这是本模型的边界。
- 不含 BRAM 数据、TMDS、音频、EDID、PHY；不含物理 SR recovery/removal；`video_period` 用实际解码的 `h>=160 && y>=45`，不是任意自选 period。

### 5.2 合法 source 时序与相位/初始化扫描

`phase_reacquire_sweep.py`：实际 locked/pause FSM + 解码 source 时序（SOF h=150,y=45；SOL h=160,y>=45；read window同），外部 AXIS 为 640/800、480/525、每帧一个 user；`pause` 停 h 计数器。

- **31 个 FIRST 偏移 × 实际复位 (locked,pause)=(0,0) × 3 帧**：
  - 全部获得 locked；`drops=0`；3 帧末 locked=1；
  - 偏移 0..800：在**下一帧**锁（first_lock = 420000+offset），属首次捕获窗口外的延迟，不是永久失锁；
  - 偏移 35360..35464：立即锁（first_lock≈offset）；419999 也立即锁；
  - 最大 first_lock（实际复位）420800；运行约 68 s。
- **初始化扰动** (0,1)/(1,0)：可出现一次额外 drop/re-lock，但 3 帧末均 locked；没有永久失锁。这是人为初始态，不是正常复位态。
- **负控**：在真实 SOL 处去掉 valid → drops>0、末态 locked=0，证明测试对相位/valid 敏感。

### 5.3 控制/FIFO 有界 iverilog 测试

`tb_phase_capture4.v`（4 个 FIRST=35360/35390/35392/35464，一帧 420000 拍）：

```text
A35390 first_lock=35391 locked=1 drops=0 blocked=0 writes=307199 reads=307199 dup=0 maxocc=10
B35392 first_lock=35393 locked=1 drops=0 blocked=0 writes=307199 reads=307199 dup=0 maxocc=10
C35360 first_lock=35361 locked=1 drops=0 blocked=0 writes=307199 reads=307199 dup=0 maxocc=10
D35464 first_lock=35465 locked=1 drops=0 blocked=0 writes=307199 reads=307199 dup=0 maxocc=10
```

`tb_phase_capture3.v`（FIRST=10/170，两帧）：

```text
C10  first_lock=420011 locked=1 drops=0 blocked=0 writes=307199 reads=307199 maxocc=10
D170 first_lock=420171 locked=1 drops=0 blocked=0 writes=307199 reads=307199 maxocc=10
```

即：帧边界相位偏移会**延迟一帧捕获**，但在第二帧恢复，无 drop、无 blocked write、占用 10。输出里的 `jumps` 不是错误：写地址是 Gray 码（0,0,1,3,2,6,…），不是二进制 +1；真正的检查是 `dup=0`（连续写不重复地址）与 fill-only 的 1024 唯一地址。**未找到“合法时序下永不锁/FIFO 异常”的反例。**

`tb_fill_addr.v`（valid 恒高、read=0，fill-only 负控）：

```text
FILL writes=1024 dup=0 after_full=1963 wa=0 locked=1 pause=0 fiforst=0
```

前 1024 次写地址**没有重复**（覆盖 1024 个唯一地址），之后 full 使 `write_go` 停住，再 1963 拍 blocked。说明写地址推进是真实的，`wea=valid` 不能替代它；full 时继续 valid 会造成覆盖/丢失。

### 5.3b 启动/重捕获时具体丢什么（`fifo_rst=!locked`）

`tb_one_frame.v` 从 first user 起跑一个完整帧 + margin，单独统计“valid 但 fifo_rst=1”和“locked 后 valid 但 write_go=0”：

```text
A35390: valid=308040 accepted=308039 reset_blocked=1    blocked_after_reset=0 reads=308029 read_invalid=0 drops=0 first_lock=35391
C10:    valid=615240 accepted=308039 reset_blocked=307201 blocked_after_reset=0 reads=308029 read_invalid=0 drops=0 first_lock=420011
```

解读：

- A35390（first user 在捕获窗口内）：lock 在下一拍建立；**恰有 1 个 valid 像素落在 fifo_rst=1**，未入队；locked 后 blocked=0。即 **每次 lock 捕获丢 1 个首像素**，不是 C/D，也不导致整行/永久丢失。这是 mapped 控制的实际行为；它可能是核心用 SOF 首像素做锁相的有意对齐，也可能是 1 像素 off-by-one，需厂商语义确认，不能仅凭模型判为 bug。
- C10（first user 在帧边界/捕获窗口外）：第一整帧 307200 个 valid 全部落在 fifo_rst=1，未入队；下一帧 lock 前的首像素再计 1，共 reset_blocked=307201；下一帧 lock 后 blocked=0。即 **首帧整体被丢弃 + 首像素 1 个**，第二帧恢复；这是帧相位启动行为，不是永久失锁。
- `read_invalid=0`：每次 `rgo` 的读地址都对应一个先前 accepted 的写地址，未出现“读未写/被覆盖地址”；reads 比 accepted 少 10，是 FIFO 中仍有 10 拍未读，不是无效读。此检查只证明地址配对，不证明 BRAM 数据值。
- 若 `locked` 反复掉锁/重捕获，每次都会重复“整帧或首像素丢弃”；这才是与黑屏/闪烁直接相关的启动/恢复状态路径。功能模型在合法相位下可恢复，物理 `!locked` 异步复位沿是否稳定未证。

### 5.4 能得出/不能得出

能得出：
- 在**实际复位态 + 合法 640×480 AXIS + 解码 source 时序**下，测试范围内（31 相位、3 帧、4 个 iverilog 相位、fill 负控）没有永不锁，也没有合法期间的 blocked write/满溢出；最大占用 10。
- 帧边界相位偏移最多延迟一帧捕获，随后恢复；`locked` 掉锁/复位 FIFO 的功能模型可恢复。
- **精确反例（非永久）**：合法 `FIRST=10` 源的第一整帧 307200 个 valid 全部被 `fifo_rst=!locked` 挡住（reset_blocked=307201）；A35390 每次捕获 1 个首像素被挡住。它们证明“合法源也有启动丢帧/丢首像素”，但不是永不恢复；若 locked 反复掉锁才会重复丢。
- B 的 empty/rd_en 逻辑仍在；TLAST 只进 ready 输出锥。

不能得出：
- 不能证明加密 HDMI IP 全实现/时序等价；不能证明物理异步 SR（`!locked`）的 recovery/removal、亚稳态、布局/时钟偏斜；
- 不能证明 A 的真实 internal locked 稳定；A 强制 0 不可观测；
- 不能把“模型 PASS”当真实 IP 通过；不能证明 TMDS/音频/媒体正确；
- 不能从 C/D sticky 推断丢失；不能从 `wea=valid` 推断入队成功。

---

## 6. C/D 的收窄判读

- C/D 只表示 `valid && !ready_seen` 至少发生过一次；ready 是行级信用（last 后低）且受 pro_full 影响。
- 合法模型下，C/D 可以在 ready 低/帧边界出现而 `write_go` 仍推进、无 blocked；**C/D 本身不是写口门控**。
- 但若 FIFO 真的 full，`wea=valid` 仍高而 `write_go` 停住 → 覆盖/丢失。C/D 只有在伴随 full/占用到深度时才可能间接相关；现有合法测试未出现。
- A 页2/3 完整帧 + AXIS user/last 正常，说明源侧帧/行/首尾完整；A 页4 C/D=1 不能证明丢首像素/整行。
- A 的真实 locked 不可见；若 locked 低/跳变，`fifo_reset=!locked` 会清 FIFO 指针。这是目前比 C/D 更直接的“永不恢复”候选，但功能模型在合法相位下可恢复，**不能称已定位**。

---

## 7. 给 Root 的优先建议（修订）

**不建议**：
- 不修改 `video_rgb_to_axis`，不加 `valid&=ready`（会丢拍/断行；模型 `dropped_by_gate=3838`、首个缺口 1270）；
- 不因 C/D 改 FIFO/加寄存器/延长复位；
- **不把“只恢复 `.locked` 观测”当新实验**：A 只改这一根线就是原完整 Probe 的同一 top；Probe 已 PASS，重构建不能提供新判别信息。此前的 A2 建议删除。
- 不把模型 PASS 当真实 IP 通过。

**可行动的下一步（按优先级）**：
1. **物理/STA 检查已在 `fix_round/axis/physical_review/REPORT.md` 完成**：A/B 最终 routed `pr.db` 的 `O_video_locked_reg_syn_8.q[0]` → LUT2 → 视频 FIFO `.sr` 路径，A recovery slow min **+34.065 ns**、removal fast min **+1.971 ns**；B **+34.144 / +2.365 ns**。已报告端点全正，无 retiming/额外 FF；A 功能负载 3（routed net fanout 6）vs Probe 10，差异是打包/扇出/布局。**但** TD summary 只列 recovery/slow 与 removal/fast（39 个 SR 端点中 A 报 37、B 报 27），不是四角全签核；旧/Probe 默认报告目标端点 0、未做精确查询。没有精确反例，也没有证明硬件无亚稳态。
2. 本轮**不提议任何新构建**：恢复 `.locked` 就是 full Probe，不能作为新实验；A/Probe 的既有记录已足够做对比。若 Root 另有不改变 top 的时间分辨数据，可复用；否则不做。
3. 若上述都排除，AXIS 从本轮根因候选中降级，转查 `display_valid`/媒体（B 的 OSD-only 现象）与 TMDS/PHY 共享边界。

**结论**：当前没有可辩护的 AXIS RTL 修复；`locked→FIFO async reset` 的 A/B 已报告端点正 slack，但四角/旧/Probe 覆盖不完整，不能据此改 RTL 或宣称根因。`media_status_001` 的 rawSTA_FAIL 与旧 A/B 因果未证，本报告不据此推断旧核 reset 路径失败。

---

## 8. 新增/复用脚本与证据

本地 `fix_round/axis/`：

| 文件 | 用途 |
|---|---|
| `astra_reuse/mapped_receiver_control.v` | 复用的 netlist-derived 81FF/27LUT 接收/FIFO 控制模型 |
| `astra_reuse/phase_reacquire_sweep.py` | 实际 locked/pause FSM + 解码 source 时序，31 相位×3 帧×3 初态 |
| `astra_reuse/phase_reacquire_result.json` | 上述结果（actual reset 全部 lock/no-drop） |
| `astra_reuse/tb_phase_capture4.v` | 4 相位一帧 iverilog，含 write/read/lock/blocked/占用 |
| `astra_reuse/tb_phase_capture3.v` | FIRST=10/170 两帧重捕获 |
| `astra_reuse/tb_fill_addr.v` | fill-only 地址唯一性/full 负控 |
| `astra_reuse/tb_one_frame.v` | 首帧/首像素 reset_blocked 计数（A35390、FIRST=10） |
| `astra_reuse/one_frame_A35390.txt` / `one_frame_C10.txt` | 实际输出：reset_blocked=1 / 307201 |
| `astra_reuse/phase_capture_4cases.txt` / `phase_capture_reacquire.txt` / `fill_addr.txt` | 实际输出 |
| `astra_reuse/timing_expA.json` | A mapped 解码 SOF 150/45、SOL 160、row terminal 524 |
| `evidence/expB_rd_en_cone.txt` | B 的 `rd_en=period&&!empty` 实际驱动锥 |
| `evidence/snippets_*.txt` | A/Probe/B 关键 cell（含 SRMODE） |
| `check_mapped_contract.py` | 自动检查 ready/wea/rd_en/locked/pause/FIFO reset/SRMODE/TLAST |
| `test_axis_contract.py` | 3 个源侧静态测试（源/时序/APUG） |

**实际命令/结果**：
```bash
python3 astra_reuse/phase_reacquire_sweep.py   # ~68 s；actual_reset_all_lock_no_drop=true
python3 test_axis_contract.py -v               # 3 tests OK (~1 s)
python3 check_mapped_contract.py               # PASS A / Probe / B / B_rd_en / A_route
```
远端 iverilog（`C:\iverilog\bin`，非 TD 构建）：
```text
phase_capture_4cases.txt: 4 cases lock, drops=0, blocked=0, dup=0, maxocc=10
phase_capture_reacquire.txt: C10/D170 lock at 420011/420171, drops=0, blocked=0, maxocc=10
fill_addr.txt: writes=1024, dup=0, after_full=1963
one_frame_A35390.txt: valid=308040, accepted=308039, reset_blocked=1, blocked_after_reset=0
one_frame_C10.txt: valid=615240, accepted=308039, reset_blocked=307201, blocked_after_reset=0
```

**模型边界**：控制模型来自 legacy NoBot mapped，非 A/Probe 专属重新提取；A/Probe 仅 key cell 对照 + 同 source timing。没有证明写地址/CE 的 A 专属逐 FF 等价；没有物理 SR/TMDS/音频/媒体仿真；没有 hardware。

---

## 9. 未决

1. A 的真实 internal locked 未观测；`!locked` 异步复位 FIFO 指针的物理 recovery/removal 未查。
2. 复用控制模型不是 A/Probe 专属；写地址/CE 全锥等价未证；`full` 在合法测试中未触发（max 10）。
3. `video_period` 的真实占空比用解码 `h>=160,y>=45`，未做全 LUT 动态仿真；`pro_full` 阈值/占用未在 A/Probe 专属模型中重算。
4. 未建模 TMDS/PHY、音频、SD/媒体；B 的主图/音频异常仍需单独证据。
5. 未做 hardware/JTAG/Flash/TF；所有上板结论只引用既有记录。
6. APUG092 页码取自目录；读的是 txt 抽取版。
