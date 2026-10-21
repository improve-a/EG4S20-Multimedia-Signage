# TD `infer_add` / `MSLICE` 只读核查

日期：2026-10-20
范围：只读。查阅 Windows thinkpad 上 `G:/anlu/doc` 的随机官方文档、安路官方 FAQ、
以及前次失败快照 `D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_001`
的日志。**未运行 TD/综合/布局布线，未修改 Windows 文件，未改 HDL/SDC，未写硬件。**
本轮只评估 `infer_add` 一项；不涉及 `min_ripple_len` 的实际切换。

---

## 1. 结论摘要

### 1.1 `infer_add` 的含义（有明确官方文字）

官方 SWUG106（TD6.0 综合编码指南）表 3-1 把它列在 **Read Design** 下：

- **ON**：当加/减法长度 **大于等于 `min_ripple_len`** 时，使用**硬件进位链**实现加/减法，
  提高 timing，**需要更大的面积**。
- **OFF**：使用 **LUT** 实现加/减法，timing 会差，**节省面积**。

即 `infer_add` 不是“是否识别加法器”，而是“满足位宽阈值时，加法器用进位链还是 LUT 实现”的
全局综合策略。它作用于 RTL/Read Design 阶段。

### 1.2 `MSLICE` 的含义（有明确官方文字）

官方 SALEAGLE（EG4/EAGLE）数据手册 DS300 v3.9.4 §2.1/§2.1.1：

- 官方命名：`logical programmable module (LSLICE)` 与 `memory logical module (MSLICE)`；
  两者都具备 logic 和 arithmetic 功能，MSLICE 额外支持分布式 RAM/ROM。
- EAGLE 的 PFB 含 4 个 SLICE：**Slice 0/1 是 MSLICE，Slice 2/3 是 LSLICE**。
- `MSLICE contains 2 LUT4s, 2 registers and two-level carry chain`，可配置为分布式 RAM/ROM；
- `1 MSLICE can implement 2bits addition/subtraction and fast carry/borrow output (FCOM)`；
- MSLICE 有 logic / arithmetic / distributed RAM / ROM 四种模式，支持算术模式（进位链）。
- 对比：LSLICE 是 2 个增强 LUT5 + 2 个寄存器 + 四级进位链，可做 4-bit 加/减法。

所以 **MSLICE 是物理逻辑 slice 资源（器件容量单位），不是 Tcl 命令**；用硬件进位链实现的
加/减法会占用 MSLICE/LSLICE 这类 slice 资源。TD 资源报告中的 `mslices` 计数就是它。

### 1.3 官方 FAQ 明确把两者联系起来

安路官方 FAQ（`http://tech.anlogic.com/`）条目：

> **mslice超标该如何解决？**
> 可以尝试打开TD，选择process->properties->Read Design->infer_add，调整该属性的开关。
> 如果还没有解决，建议联系FAE。

这是本次检索到的官方资料中，唯一直接把 “mslice 超标” 与 `infer_add` 开关关联起来的说明。

### 1.4 默认值：**官方文档没有给出，不能猜**

- SWUG106 表 3-1 只列 ON/OFF 行为，**没有 Default 列、没有“默认”字样**。
- SWUG105（2024.11）表 4-1 的 `set_param` 参数表中**根本没有 `infer_add`**。
- TD User Guide 6.2（2025.01）§9.6 的 Read Design 表只列
  `default_reg_initial`、`hdl_warning_level`，**没有 `infer_add`**；可提取文本中也无 `infer_add`。
- 官方 FAQ 也没有给默认值。
- 失败快照的 `syn_1/settings.cfg` 中没有 `infer`/`ripple` 项，说明该次运行**未显式设置**，
  用的是工具默认值；但快照本身不能证明默认值是多少。

**结论：`infer_add` 的默认值必须由 root 在实际 TD 6.2.1 工程里读取（GUI 或
`report_param`）确认；本地官方文档不足以回答，不能用 ON 或 OFF 猜测。**

### 1.5 版本一致性风险（重要）

本地文档存在版本差异：

| 文档 | 版本/日期 | 是否出现 `infer_add` |
|---|---|---|
| SWUG106 综合编码指南 | TD6.0_V1.0 / 2024.04 | 有（表 3-1，唯一给出语义的本地文档） |
| SWUG105 Tcl 命令指南 | 2024.11 | 无（表 4-1 未列） |
| TD User Guide | 6.2 / 2025.01 | 无（§9.6 Read Design 表未列；可提取文本中无） |
| 官方 FAQ（在线） | 访问于 2026-10-20 | 有（GUI 路径 Read Design->infer_add） |

因此：**在 TD 6.2.1 / EG4S20 上，`infer_add` 是否仍是可写参数、接受哪些值、默认是什么，
必须以 root 的工具查询为准。** 如果工具中不存在或为只读，则本轮“只切换 infer_add”不可执行，
应停下报告，而不是改用 HDL 属性或改约束。

---

## 2. 前次失败快照的事实（只读）

快照：`D:\FPGA\EG4S20-Bot-HDMIProbe\output\html_fidelity\builds\bot_hdmi_probe_001`

`...\runs\bot_hdmi_probe_001\stdout.log:1977/1985`（`phy_1\run.log:333/341` 同文）：

```
RUN-1001 : 4925 mslices, 4925 lslices, 88 pads, 80 brams, 20 dsps
PHY-9009 ERROR: Design's mslice number = 4925, exceeds the limit 4900.
There are more MSlices exceeding the limit of the device. ...
```

- 失败发生在 `Stage 2.8.1 | Packing`（Place Packing，Global Placement 之后）。
- mslice 4925 / 上限 4900，**超出 25 个（约 0.51%）**；lslices 也同时是 4925。
- 快照全目录 `findstr /S /I /C:"infer_add"` **无匹配**；`syn_1\settings.cfg` 也无
  `infer`/`ripple` 项。即该次运行没有显式设置 `infer_add`。
- 该错误是器件容量/打包失败，不是时序失败；但换成 LUT 实现后 timing 会变差，后续仍需重新确认时序。

---

## 3. 对“本轮仅切换 infer_add”的边界说明（基于文档，不作承诺）

1. **方向**：文档只说明 OFF “节省面积”、ON “需要更大面积”。就面积而言 OFF 是朝有利于
   放下的方向；但**官方 FAQ 只说“调整开关”，没有说必须开还是关，也没有保证能放下**。
2. **幅度未知**：MSLICE 还承载普通逻辑、latch、分布式 RAM（TD UG 错误码 PHY-9049 明确
   latch 也占 mslice 容量）。`infer_add` 只影响用进位链的加/减法那部分，**没有任何官方文档
   量化它能省多少 mslice**。不能承诺 25 个的缺口一定能补上。
3. **时序代价**：SWUG106 明确 OFF 时 “timing 会差”。本次虽在 packing 阶段失败，但若放下后
   进入布线，必须重新检查时序；不能把“能放下”当成“能收敛”。
4. **生效阶段**：`infer_add` 属于 Read Design/RTL 综合属性。失败快照的 `phy_1` 在
   `read_design` 用 `import_db $parent/${prj_name}_gate.db` 导入 syn_1 的网表；
   因此**只重跑 phy_1 不会让 infer_add 生效**，必须先重跑 syn_1（read_design→opt_rtl→opt_gate）
   生成新的 gate.db，再跑 phy_1。参考 `bot_probe/bot_build_reference.tcl` 的顺序是
   `launch_runs syn_1` → `launch_runs phy_1`。
5. **HDL 约束不变**：TD UG §9.6 还提供 `(*use_ripple *)` 逐实例覆盖，但那是 HDL 修改，
   本轮禁止；本轮只能动全局属性。
6. **`min_ripple_len` 是另一个参数**（默认 AUTO），本轮不应改；它决定 ON 时“多宽的加法器
   才走进位链”，与 `infer_add` 配合，但不是本轮变量。

---

## 4. 证据文件与出处

### 4.1 本地官方文档（Windows，只读）

| 证据 | 路径 | 页/节 | SHA256 |
|---|---|---|---|
| `infer_add` 语义 | `G:\anlu\doc\SWUG\SWUG106_HDL_Coding_Synthesis_User_Guide.pdf` | PDF p22 / 印刷 p15，§3.2 表3-1 | `79cd0c21…32bb8ba` |
| `infer_add` 缺失 | `G:\anlu\doc\SWUG\SWUG105_TCL_Command_User_Guide.pdf` | PDF p28 / 印刷 p22，表4-1 | `c6d97356…d2431380` |
| TD6.2 无 `infer_add`、`min_ripple_len` 默认 AUTO、mslice 错误码 | `G:\anlu\doc\TD_User_Guide_V6.2.pdf` | PDF p258/p278/p279，§9.6 | `5bd0028e…6479f087` |

### 4.2 官方在线资料（只读）

| 证据 | URL | 说明 |
|---|---|---|
| FAQ：mslice 超标 → 调 infer_add | `http://tech.anlogic.com/Cn/Index/index/cdk/mslice/p/1.html` | 访问 2026-10-20；条目原文见 `evidence/03_faq_mslice.txt` |
| SALEAGLE/EG4 数据手册 DS300 v3.9.4 | `https://anlogic.oss-cn-shanghai.aliyuncs.com/web_doc/工具与资料下载/技术文档/EG4/数据手册/DS300_Eagle_Datasheet_en.pdf` | §2.1/§2.1.1，PDF p11–14；SHA256 `6d87c11a…95437595` |

### 4.3 失败快照

- `...\runs\bot_hdmi_probe_001\stdout.log:1977,1985`
- `...\work\design\td_project\hx4s20_basic_Runs\phy_1\run.log:333,341`
- `...\work\design\td_project\td_20261020_223100.log:1949,1957`
- `...\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.tcl:72-73`（phy 导入 gate.db）
- `...\work\design\td_project\hx4s20_basic_Runs\syn_1\settings.cfg`（无 infer/ripple）

### 4.4 本地证据摘录

- `evidence/01_swug106_infer_add.txt`
- `evidence/02_ds300_mslice.txt`
- `evidence/03_faq_mslice.txt`
- `evidence/04_tdug62_read_design_and_errors.txt`
- `evidence/05_swug105_param_table.txt`
- `evidence/06_failure_snapshot.txt`
- `evidence/07_flow_implication.txt`
- `extracted/`：上述 PDF 的 pypdf 文本提取（仅用于检索核对，不是原始文档）
- `official_strategy_ph1.json`：官方策略文件（`AdderChainThresholdHigh` 用
  `min_ripple_len=18`，说明“把更多加法链转成 LUT 以利布局”；本轮不改）

---

## 5. 未决 / 交给 root 的事项

1. 在实际 TD 6.2.1 / EG4S20BG256 工程中读取 `infer_add` 的**当前值、默认值、可写性、
   接受值**（GUI 或 `report_param`）。本审计不调用工具、不替代该查询。
2. 确认本轮要切到 ON 还是 OFF（文档只给行为，不给方向）。
3. 若执行实验：只改 `infer_add`，**重跑 syn_1 再跑 phy_1**；HDL/SDC 保持不变；
   记录 mslice/lslice、packing 是否通过、以及后续 timing。不要预先承诺能放入。
