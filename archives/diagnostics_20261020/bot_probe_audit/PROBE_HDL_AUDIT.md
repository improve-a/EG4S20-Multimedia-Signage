# NoBot HDMI 探针 HDL 独立核查与移植规范

独立只读核查，2026-10-20。目标：确认成功提交 `42de1dbe4a20ca78f28be54c4bf41bd0dd814481`
（`D:\FPGA\EG4S20-NoBot-HDMIProbe`）真正进入综合的探针 HDL 改动，给出可执行移植规范。

结论摘要：

1. **`42de1db` 本身不含探针 HDL 改动**。它是文档提交（+`.al` 重排、配方换行修正、光栅短测试），
   父提交为 `72e5c80`（真正的探针源码提交）。冻结 ZIP 里的探针模块与 `72e5c80`/`42de1db` 的 git blob 逐字节相同
   （顶层不在 Git，只能以 ZIP 为准）。
2. 顶层 HDL 的**全部**改动是 3 处：新增 `wire probe_video_locked`；把原本悬空的
   `O_video_locked` 接上；用探针实例替换原 `seg_decoder_m0` 并改写 `seg_scan` 六个字模输入。
   已用配方对失败版顶层做**逐字节重建**，结果与成功版顶层 SHA-256 完全相同。
3. 除上述顶层文件外，`user_source/hdl_source` 只有 `ext/hdmi_probe.v` 一个新增文件；
   其余 6 个文件仅差 INIT_FILE 绝对路径（非功能）。约束、`exported_syn.tcl`、`exported_phy.tcl` 逐字节相同。
4. **音频功能路径未改变**：`audio_valid` 只是多了一个只读负载。
   **显示功能路径（HDMI 图像）未改变**；改变的是**数码管状态显示**（原 `display_state` 数字状态被五页统计取代，
   该显示锥因此失去唯一读者）。

---

## 1. 身份与不可混淆的三层对象

| 层 | 对象 | 证据 |
|---|---|---|
| 交付提交 | `42de1db`（tag `hw-pass-no-bot-probe-20261020` → 指向该提交） | `git rev-parse HEAD`；`git tag -l --format='%(refname:short) %(*objectname)'` |
| 源码提交 | `72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`（`42de1db` 的父） | `git show --name-status 42de1db`：父行 = `72e5c80…` |
| 冻结构建输入 | `baseline_copies/hdmi_probe_001_source.zip`，SHA-256 `5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f`（139 条目，含 1 个 `hdmi_probe.v`） | 直接读取 ZIP 条目 |

`42de1db` 相对 `72e5c80` 只改：`docs/HDMI_PROBE.md`、`docs/HDMI_PROBE_BUILD.md`、
`project/td_project/hx4s20_basic.al`(+8)、`scripts/apply_hdmi_probe.py`(7 行，仅换行/读取方式)、
`tests/hdmi_probe_raster_tb.v`。**`rtl/ext/hdmi_probe.v` 与构建快照相同**（该文件在 `72e5c80^..42de1db`
区间只出现为“新增”，此后无修改）。

关键结构事实：**顶层 `top_tf_hdmi_audio.v` 不在 Git 中**（`rtl/` 只有 43 个条目，`git grep "module seg_scan|seg_decoder"` 在该树中无命中；
顶层、`seg_decoder.v`、`seg_scan.v` 都不在仓库里）。
顶层是本地依赖，由 `scripts/apply_hdmi_probe.py` 在构建前施加到工作副本。因此“提交里的探针改动”必须理解为
`配方 + 新探针模块`，真实顶层在冻结 ZIP 中。**单凭 `42de1db` 这个提交无法重建该构建**：
顶层与 `seg_*` 模块只存在于冻结 source ZIP / 本地 `work/design` 工作副本。

---

## 2. 真实顶层差异（逐字节已验证）

失败版 `no_bot_legacy_004` 顶层 SHA-256 `d90a057f2242ebf387caa8057c85613cf43504be791644353dc35f3b63f8209d`
（与配方里的 hash 守卫一致）；成功版 `hdmi_probe_001` 顶层 `a422b55aec4dc4420479d80060956825daa08beecdb6d28b2132fa5924761cea`。
两者均 LF 换行（CRLF=0），编码同为 UTF-8。

**重建验证**：取失败版顶层 → 施加配方两步 `Replace` → 用 `"seg_decoder seg_decoder_m0("` 与下一个 `// ====` 锚点做区间替换
→ 长度 20542 字符，与成功版顶层 `-ceq` 全等（`13_rebuild2.ps1`：`equal=True`）。
说明成功版顶层**没有**任何第 4 处隐藏改动。

三处差异（H1–H3）如下，顺序与行号按失败版文件：

### H1（第 138 行后，新增一行）

```verilog
 wire        axis_s_ready;
+wire        probe_video_locked;
```

### H2（失败版第 330 行起，删除原 `seg_decoder_m0` 实例与旧 `seg_scan` 接线，替换为下列块）

```verilog
// Read-only video-clock probes; display statistics in the existing 50MHz scanner.
wire [27:0] probe_flags;
wire [23:0] probe_digits;
wire [41:0] probe_segments;
hdmi_probe probe(
 .clk(video_clk),.rst(video_rst),.vs(fx_vs),.hs(fx_hs),.de(fx_de),
 .av(axis_s_valid),.au(axis_s_user),.al(axis_s_last),.ready(axis_s_ready),
 .locked(probe_video_locked),.audio_valid(audio_valid),.flags(probe_flags));
hdmi_probe_display probe_display(
 .clk(clk),.rst(button_reset50),.flags_async(probe_flags),
 .video_rst_async(video_rst),.sys_lock_async(sys_pll_lock),.video_lock_async(video_pll_lock),
 .digits(probe_digits),.page_number());
genvar probe_digit;
generate for(probe_digit=0;probe_digit<6;probe_digit=probe_digit+1)begin:probe_decode
 seg_decoder digit_decoder(.bin_data(probe_digits[probe_digit*4+:4]),
  .seg_data(probe_segments[probe_digit*7+:7]));
end endgenerate
seg_scan seg_scan_m0(
 .clk(clk),.rst_n(rst_n),.seg_sel(seg_sel),.seg_data(seg_data),
 .seg_data_0({1'b1,probe_segments[6:0]}),
 .seg_data_1({1'b1,probe_segments[13:7]}),
 .seg_data_2({1'b1,probe_segments[20:14]}),
 .seg_data_3({1'b1,probe_segments[27:21]}),
 .seg_data_4({1'b1,probe_segments[34:28]}),
 .seg_data_5({1'b0,probe_segments[41:35]})
);
```

被删除的原代码（供对照，勿移植）：

```verilog
seg_decoder seg_decoder_m0(
    .bin_data          (display_state),
    .seg_data          (seg_data_0)
);
seg_scan seg_scan_m0(
    .clk (clk), .rst_n (rst_n), .seg_sel (seg_sel), .seg_data (seg_data),
    .seg_data_0 ({1'b1,7'b1111_111}), … .seg_data_4 ({1'b1,7'b1111_111}),
    .seg_data_5 ({1'b1,seg_data_0})
);
```

### H3（失败版第 502 行 / 成功版第 512 行，HDMI 核锁输出接出）

```verilog
-    .O_video_locked     (),
+    .O_video_locked     (probe_video_locked),
```

---

## 3. 精确连接表（必须照抄的部分）

时钟域：`probe` 在 `video_clk` / `video_rst`（25 MHz 像素域）；`probe_display` 在 `clk`（50 MHz）/`button_reset50`。

| 探针端口 | 顶层实际信号 | 来源 / 消费端（映射网表可核对） | 性质 |
|---|---|---|---|
| `vs` | `fx_vs` | `html_video_overlay` 的 `o_vs`（`extensions/osd/o_vs_reg`） | 新增只读负载 |
| `hs` | `fx_hs` | `extensions/osd/o_hs_reg`；**原设计无任何消费者** | 仅为观察而保留 |
| `de` | `fx_de` | `extensions/osd` 的同步流水输出 | 新增只读负载 |
| `av` | `axis_s_valid` | `u_video_rgb_to_axis_640x480` → HDMI 核 `I_axis_s_valid` | 新增只读负载 |
| `au` | `axis_s_user` | 同上 → HDMI 核 `I_axis_s_user` | 新增只读负载 |
| `al` | `axis_s_last` | 同上 → HDMI 核 `I_axis_s_last`（`O_video_last_reg`；原本无消费者而被优化掉） | 仅为观察而保留 |
| `ready` | `axis_s_ready` | HDMI 核 `O_axis_s_ready`；**原设计无消费者**（网表中为 `S_video_in_ready`） | 仅为观察而保留 |
| `locked` | `probe_video_locked` | HDMI 核 `O_video_locked`（原为 `()` 悬空） | 由悬空改为接出 |
| `audio_valid` | `audio_valid` | `audio_output_mux` 输出，同线进 HDMI 核 `I_audio_valid` 与 ACR 计算 | 新增只读负载 |
| `clk`,`rst` | `video_clk`,`video_rst` | `rs_video` 二级释放输出（高有效），同线进 HDMI 核 `I_rst` | 复用 |
| display `clk`,`rst` | `clk`,`button_reset50` | `reset_sync rs_button(clk, ~rst_n, button_reset50)` | 复用（**不是** `rst_all`，也不是 `rst_n`） |
| display 异步输入 | `video_rst`,`sys_pll_lock`,`video_pll_lock` | 复位链与两路 PLL `extlock` | 两拍同步后显示 |
| display 输出 | `probe_digits` → 6×`seg_decoder` → `probe_segments`(42b) → `seg_scan` | 见下 | — |
| `page_number` | `()` 空接 | — | 不移植也可，恒被优化 |

`seg_scan` 位序（务必一致，`seg_data[7]` 是小数点，**低有效**）：

- `seg_data_0` ← `{1'b1, probe_segments[6:0]}` ← `digits[3:0]` = E
- `seg_data_1` ← `{1'b1, probe_segments[13:7]}` ← D
- `seg_data_2` ← `{1'b1, probe_segments[20:14]}` ← C
- `seg_data_3` ← `{1'b1, probe_segments[27:21]}` ← B
- `seg_data_4` ← `{1'b1, probe_segments[34:28]}` ← A
- `seg_data_5` ← `{1'b0, probe_segments[41:35]}` ← 页号（小数点**点亮**）

`seg_decoder` 输出低有效（0 点亮），`7'b111_1111` 为全灭；`seg_scan` 的 `SCAN_FREQ=200`、`CLK_FREQ=50000000`。

---

## 4. 模块结构与必须保留的属性

`ext/hdmi_probe.v` 只有两个模块，无 `initial`、无第三方依赖、不使用 Xilinx/Anlogic 原语。

```
hdmi_probe  #(WINDOW_CYCLES=25000000, FRAME_PIXELS=307200, LINE_PIXELS=640)
  in : clk,rst,vs,hs,de,av,au,al,ready,locked,audio_valid
  out: flags[27:0]
hdmi_probe_display #(PAGE_CYCLES=150000000)
  in : clk,rst,flags_async[27:0],video_rst_async,sys_lock_async,video_lock_async
  out: digits[23:0], page_number[2:0]
```

**唯一的综合属性，必须逐字保留**：

```verilog
(* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;
```

说明（**2026-10-20 验收后修正**）：这是设计唯一的 25 MHz → 50 MHz 跨域点，作者为两级同步器写了
`async_reg` + `preserve`；移植时应**逐字保留**，使目标构建与原设计的作者意图一致。

但本核查**没有**做“去掉属性再综合”的对照，因此**不能**断言“去掉 `preserve` 就会被合并/重定时”。
此前草稿这样写是未经证明的因果推断，现撤回。

映射网表里这些寄存器与功能逻辑**共处同一小片**（如 `\probe_display/status_meta_reg[0]_syn_4`、
`\frame_read_write_m0/frame_fifo_write_m0/add11_syn_60`、`\extensions/osd/lt171_syn_27`）。
这只是资源打包的观察事实：**不等于** `status_meta` 与 `status_sync` 彼此被合并，也**不是**该属性有效的证据。
要判断属性作用，需要同一份 RTL 的带/不带属性 A/B 综合对比，本轮未做。

源码中除此之外没有其他综合属性/`keep`；`flags[27]` 恒 0、`status_sync[27]` 被优化属于预期（常量传播）。

`flags` 位定义（与显示页一致，移植后请勿改动位序）：

| bit | 含义 | bit | 含义 |
|---|---|---|---|
| 0 | `locked` 当前值 | 14 | `user_seen` |
| 1 | `lock_ever` | 15 | `last_seen` |
| 2 | 完整 1 s 窗口保持锁定且此后未低 | 16 | `user_bad` |
| 3 | `lock_drop` | 17 | `line_bad` |
| 4 | `lock_timeout` | 18 | `ready_high` |
| 5 | `ever[0]` VS 上升沿曾出现 | 19 | `ready_low` |
| 6 | `recent[0]` VS 活动码 | 20 | `backpressure` |
| 7 | `ever[2]` DE 曾出现 | 21 | `sol_conflict` |
| 8 | `recent[2]` DE 活动码 | 22 | `ever[4]` 音频脉冲曾出现 |
| 9 | `frame_good` | 23 | `recent[4]` 音频活动码 |
| 10 | `frame_bad` | 24 | `heartbeat` |
| 11 | `no_de` | 25 | `ever[1]` HS 边沿曾出现 |
| 12 | `ever[3]` AV 翻转曾出现 | 26 | `recent[1]` HS 活动码 |
| 13 | `recent[3]` AV 活动码 | 27 | 保留 0 |

`status_meta = {video_lock_async, sys_lock_async, video_rst_async, flags_async}`，
故 `status_sync[30:28]` = 视频 PLL lock / 系统 PLL lock / 视频复位。

五页编码见 `hdmi_probe_reference.v` 第 114–123 行；移植时以该文件为唯一参考副本（本地已核对：
`sha256=f9e820e6…`、git blob `19d54a0…`、冻结 ZIP 内同名文件 `f9e820e6…` 三者相同）。

---

## 5. 音频 / 显示功能路径：是否被改变

**音频：功能路径未变。** 顶层差异只有 H1–H3。`audio_valid` 由 `audio_output_mux`（第 204–207 行）单驱动，
原有 2 个消费者：`audio_arc_calculate acr` 的 `I_audio_valid`（第 266 行）与 HDMI 核 `I_audio_valid`（第 505 行）；
探针（第 338 行）是新增的第 3 个**只读**负载，不回馈、不改数据。音频数据、`I2S`/PCM、采样率、ACR 参数、
`audio_muted`/音量、`audio_media`/`wav_stream_parser` 全部未动；`exported_syn.tcl`/`exported_phy.tcl` 逐字节相同。

**HDMI 图像显示路径未变。** RGB→AXIS 的 24 位数据、`fx_hs/vs/de` 的同步来源、HDMI 核 `I_axis_s_data`、
TMDS/PHY、引脚约束都没有改动；差异只在“观察负载”和数码管。

**数码管状态显示确实被替换（这是唯一“看得见的行为变化”）：**

1. 原 `display_state`（`fifo_fault_sync[1] ? 4'ha : state_code50`）原本只驱动 `seg_decoder_m0`；
   替换后它只剩声明与赋值、**没有任何读者**（该标识符在失败版出现 3 次：声明、`assign`、`seg_decoder_m0` 使用；成功版只剩 2 次）。随之失去负载的还有
   `state_code_sd`、`state_code50` 两级寄存器与 `fifo_fault_sync` 二级同步器（`fifo_fault_mem_sync` 侧）。
   即：**原数字故障码显示及其锥体被移除**，不是“多接了显示”。
2. `seg_data[7]`（小数点，低有效）由常量 1（六位小数点全灭）变为随扫描位切换（仅页码位为 0 即点亮），
   由常量变成真实寄存器输出；引脚分配不变（交付文档记为 A6）。
3. 六位由“第 6 位显示 4 位状态码、其余全灭”变为“五位统计 + 一位页码，每 3 s 换页，5 页 15 s 循环”。

所以：**探针没有改变视频/音频功能通路，但改变了原有状态显示语义**；任何“与原版逐位等价”的说法
都不能覆盖这一条。

---

## 6. 不可移植 / 必须重算的部分

| 项 | 原因 | 处理 |
|---|---|---|
| `D:/FPGA/.../work/design/` 绝对路径 | 顶层与 `.al` 的 `Path` 属性、6 个 ROM/OSD/Motion 的 `INIT_FILE` 参数 | 由构建流程重定位；不要手改 |
| `project/td_project/hx4s20_basic.al`（Git 中那份） | 其 `Path` 指向 `D:/FPGA/hx4s20_contest1_20261013/builds/m5_004`，探针条目 `CompileOrder=97`；**实际构建的 `.al`** 是 `hdmi_probe_001` 根、`CompileOrder=59`。两者文件集合相同（61 条）但顺序/路径不同 | 不要复制 Git 中 `.al`；对目标工程**追加**条目并令 `CompileOrder=max+1` |
| `.al` 条目的序列化细节 | 原生工程用 CRLF 且写 `P&R` 字面量（不是 `&amp;R`） | 按目标文件现有换行与写法生成（配方 42de1db 版已处理） |
| `rtl/top_tf_hdmi_audio.v` | 不在仓库；配方要求其 SHA-256 = `d90a057f…` | 移植时以目标工程顶层为准，锚点自行确认 |
| `seg_decoder.v` / `seg_scan.v` | 位于 `user_source/hdl_source/SD/`，**不在 Git**，只在冻结 ZIP | 目标工程须已有这两个模块，或一并移植 |
| 参数常量 | `WINDOW_CYCLES=25000000` 依赖 25 MHz 像素时钟；`FRAME_PIXELS=307200/LINE_PIXELS=640` 依赖 640×480；`PAGE_CYCLES=150000000` 依赖 50 MHz | 换分辨率/时钟必须重算，否者统计全错 |
| 信号名 | `fx_vs/fx_hs/fx_de`、`axis_s_*`、`video_clk/video_rst`、`button_reset50`、`sys_pll_lock/video_pll_lock`、`seg_*` | 逐一映射到目标顶层同名语义信号，不可按名字猜 |
| `genvar probe_digit` / `begin:probe_decode` | 模块级 `genvar` 与块名可能撞名 | 目标工程若已有同名，重命名 |
| `page_number` | 顶层空接、恒被优化 | 可删，但保留不影响功能 |
| 复位极性 | `probe`/`probe_display` 用高有效同步 `if(rst)`；`seg_scan` 用低有效异步 `rst_n` | 目标工程若复位极性不同必须换，不能直接接 |
| `display_state` 旧显示 | 移植后该锥体失去读者 | 若目标工程仍需状态码显示，**必须另留输出**，否则等于删功能 |

---

## 7. 移植规范（可执行）

前置：目标工程须有等价顶层（含 `fx_*`、`axis_s_*`、`O_video_locked`、`seg_scan`、`seg_decoder`），
时钟/复位语义同第 3 节。

1. 复制 `hdmi_probe.v`（**逐字节**，SHA-256 必须仍为 `f9e820e6…`），置于 `ext/`，不要改名、不要动属性行。
2. 顶层声明区加 `wire probe_video_locked;`（与其他 axis 声明同处）。
3. 把 HDMI 核实例的 `.O_video_locked (),` 改成 `.O_video_locked (probe_video_locked),`（**只在核实例上改这一处**）。
4. 找到原 `seg_decoder`+`seg_scan` 代码段，整段替换为第 2 节 H2 的块；`seg_scan` 的参数
   （`SCAN_FREQ`/`CLK_FREQ`）沿用目标工程原值。
5. 若目标工程 50 MHz 复位不是 `button_reset50`，改用等价的高有效同步复位；`seg_scan.rst_n` 保持低有效原信号。
6. `.al` 追加 `../user_source/hdl_source/ext/hdmi_probe.v` 条目：
   `UsedInSyn=true`、`UsedInP&R=true`、`BelongTo=<目标 design 名>`、`CompileOrder=max+1`；
   换行/转义与文件现有风格一致。**不要移除任何既有源文件**。
7. 运行只读检查（本目录）：

```powershell
$env:PROBE_TOP   = '<目标>/user_source/hdl_source/top_tf_hdmi_audio.v'
$env:PROBE_AL    = '<目标>/td_project/hx4s20_basic.al'
$env:PROBE_PROBE = '<目标>/user_source/hdl_source/ext/hdmi_probe.v'
powershell -NoProfile -ExecutionPolicy Bypass -File check_probe_port.ps1
```

   预期 `RESULT: ALL CHECKS PASSED`（27 项）。该脚本已在真实成功构建上 27/27 通过，
   在无探针失败基线上 18 项失败，判别力已验证。

8. 综合后复查两点：`\probe_display/status_meta*` 与 `status_sync*` 两套寄存器都在；
   `display_state`（或你保留的状态输出）仍有预期读者。

---

## 8. 证据索引（全部为只读操作）

| 结论 | 证据 |
|---|---|
| 提交身份、父提交、tag | `01_git_identity.out` |
| 探针提交只动 5 个文件；顶层不在 Git | `02_tree.out`、`03_rtltree.out`、`04_trees2.out` |
| 配方原文（hash 守卫 `d90a057f…`）与新探针源码 | `05_applier_probe.out` |
| 42de1db 只改配方换行处理 | `06_commit_al.out` |
| 顶层三处差异（逐行） | `08_real_topdiff.out` |
| 配方重建 == 成功顶层（逐字节） | `13_rebuild2.out`：`rebuilt len=20542 pass len=20542 equal=True` |
| hdl_source 全树比较：1 新增 + 1 内容差异 + 6 仅路径 | `10_treecmp.out` |
| 6 个 ROM/OSD/Motion 文件去掉构建根路径后**逐字节相等**（连 CRLF 数量都相同） | `30_rompath.out` |
| ZIP 内 top/probe/约束哈希；ZIP vs 工作副本一致 | `17_zip_al.out` |
| 工作 `.al` 仅差 Path 与新增条目（CompileOrder 59） | `17_zip_al.out` |
| Git `.al` 来自 m5_004 根（CompileOrder 97） | `18_alcompare.out` |
| 约束与 `exported_*.tcl` 逐字节相同 | `17_zip_al.out`、`25_final.out` |
| `display_state` 失去读者；状态锥体明细 | `14_signals.out`、`15_cone.out`、`19_state.out` |
| 音频消费者与驱动点原文 | `26_audio_ctx.out` |
| 三处改动行号 | `27_lineno.out` |
| 仓库内不存在顶层与 `seg_*` 模块 | `28_gitgrep.out` |
| `video_rst` = `reset_sync rs_video(video_clk,rst_all,video_rst)`，同线进 HDMI 核 `I_rst` | `29_rst.out` |
| `seg_decoder`/`seg_scan` 语义（低有效、扫描顺序） | `16_seg.out` |
| 映射层：真实网名、时钟/复位、ready/last 保留 | `23_cells.out` |
| 27 项移植检查：成功版全过 / 基线 18 失败 | `check_pass.out` / `check_fail.out` |

跨副本一致性（三方同哈希）：本地 `hdmi_probe_reference.v` = git blob `19d54a0dd397…` = 冻结 ZIP/工作副本
`f9e820e62d2abb204e2467e4c4f6791817d0adfb042e40b0399a660be9bbcf25`（5175 字节，124 行）。

---

## 9. 不确定与边界

- `42de1db` 的 `.al` 与真实构建 `.al` 不是同一份（路径与顺序不同）。文件集合相同、探针条目都在，
  但**不能**用 Git 中 `.al` 的 `CompileOrder=97` 作为端口号。
- 映射证据中 `mapped_probe_audit.json` 只有 25 个 meta + 25 个 sync 单元名，且部分被识别到别的小片
  （`\sd_card_bmp_m0/...`、`\frame_read_write_m0/...`），说明这些寄存器与功能逻辑共片；
  “30 位全部两级独立”这一结论来自 `mapped_cdc_final.json` 的逐位表，本核查**未**重做网表导出，
  移植后应以新构建的映射网表复核，而不是引用本次结论。
- 本核查只覆盖源码/工程/明文网表证据，不含综合、PnR、时序与硬件；综合/PnR/位流身份沿用已有交付与冻结校验，
  本轮未重新构建、未操作硬件。
- 未评估探针对原有失败版行为的因果作用；那是 Root 与 Worker A/B 的范围。
