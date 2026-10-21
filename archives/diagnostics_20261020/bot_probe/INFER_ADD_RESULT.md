# Bot + HDMI Probe：仅关闭 infer_add 的单次构建结果

## 结论

**BUILD_PASS，TIMING_FAIL，HARDWARE_NOT_TESTED。**

只切换 `infer_add: on → off` 后，旧 Bot + 原 HDMI Probe 可以完成 SYN、PNR、继承的 fix_hold、BITGEN，确实生成了新位流；但最终 Setup 最差余量 **−5.783 ns**，因此**没有生成满足时序验收要求的位流**。

按用户停止条件：不再构建，不改 RTL，不尝试其他优化参数；不准备/写入 HFXL 卡、不下载位流、不改成功 TF 卡。本轮目标到此完成判定，未进入实板验收。

## 参数、版本与唯一变量

- TD：**6.2.168116**，官方安装路径 `G:\anlu\bin\td_commands_prompt.exe`。
- 工具 SHA256：`e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`，与前轮一致。
- 原工程未显式设置 infer_add；实际工具 `report_param -all -detail` 确认 Current / Default 都为 **on**。
- 本次显式设 **off**；查询副本完整参数报告只差这一行。本轮实际综合日志也出现 `set_param rtl infer_add off`，并非仅修改未生效的配置。
- `.al` 两处 `Property/DesignProperty` 与 `syn_1/Strategy/DesignProperty` 是同一 infer_add 选项的项目/运行层级。另仅改变 Project Path 以隔离构建。没有修改其他选项、频率、种子、约束或优化策略。
- 官方 FAQ 建议对 MSLICE 超限切换此选项；SWUG106 §3.2 明确 OFF 改用 LUT 实现加减法，节省面积但可能降低时序性能，不保证成功。

## 隔离、源码和测试数量

- 工程：`D:\FPGA\EG4S20-Bot-HDMIProbe`
- 分支：`codex/bot-hdmi-probe-20261020`
- 配置：`experiments/bot_probe_infer_add_off.json`
- 本次构建源码/配方提交：`297d1b64130d32704e3c50a6e5ab5c85c68d42a9`
- 实验 ID：`bot_hdmi_probe_infer_add_off_001`
- 起止 UTC：2026-10-20 14:54:52.381 → 15:06:13.362，680.984 秒。
- **本轮只执行一次完整构建**。supervisor 的 `attempt_number=2` 是该工作区累计计数：第 1 次为前轮 infer_add 默认 on 的 PHY-9009 构建；不是本轮重试。
- 三次独立参数查询只进行工程分析/参数读取和查询副本设置，不执行综合或布局。首次查询用 `help name` 和 `save_project` 未取得预期帮助/保存，随后采用真实 `commit_param` / `close_project` 核实；未作用于原工程。最终新输入只含受验证的 off 值。

**HDL/约束保留证明：**

1. 与前轮已封存 Bot + Probe ZIP 比较，132 项非 `.al` 设计输入全部逐字节相同，含 Bot、探针、HDMI、音频、SDRAM/缓存、OSD、页面控制、PLL、引脚、SDC、33 项素材。
2. 6 项 harness 输入逐字节相同；`build.tcl` SHA256 仍为 `435659587ebe31f08015f459076840825c886ccca8e8cdeac0a1e0e5a95b4a47`。
3. 为做到 **HDL 连路径字符串也不改**，保留 INIT_FILE 指向前轮独立 `_001` 源资产；12 个引用和全部 33 个原资产均已逐字节核验。冻结资产不能删除，否则后续复现需重新绑定依赖。
4. 构建结束后再校验，实际构建目录中 132 项非 `.al` 输入仍完全一致；导出的 SYN/PHY Tcl 与前轮逐字节相同，参数由项目数据库加载。
5. DS Flash 1017 独立静态验收通过，见 `INFER_ADD_OFF_SOURCE_ACCEPTANCE.md`。探针原 `async_reg/preserve` 属性未改。

原 NoBot / 成功 Probe / 旧 Bot 分支 HEAD 与既有工作区改动列表保持不变；成功 Probe 最终 bit 重新计算仍为用户指定 SHA256 `bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`。

## 资源与流程

| 项目 | 前轮 infer_add=on | 本轮 infer_add=off |
|---|---:|---:|
| MSLICE（打包/布局日志口径） | 4925 / 4900，超限 | 初次打包 4527；末次布局/路由日志 4542 / 4900 |
| LSLICE（同上） | 4925 / 4900 | 4542 / 4900 |
| LUT | 17843（综合） | 17533（最终 report_area） |
| FF | 9638（综合） | 9638（最终） |
| BRAM9K / BRAM32K | 64/64、16/16 | 64/64、16/16 |
| DSP / PLL | 20/29、2/4 | 20/29、2/4 |
| SYN / PNR / BITGEN | PASS / FAIL / NOT_RUN | PASS / PASS / PASS |

资源口径说明：最终 `final_area.rpt` 提供 LUT/FF/BRAM 等，**不含 MSLICE/LSLICE 总数**；4542 来源于末次布局/路由日志，不冒称是 fix_hold 后另一次片数统计。完整 PNR、fix_hold 与 BITGEN 成功，已消除本轮容量阻塞。不能把前轮综合与本轮最终 LUT 差直接解释为纯综合节省量。

## 最终 STA（实际 routed DB、hold 修复之后）

报告：`runs\bot_hdmi_probe_infer_add_off_001\final_timing.rpt`，Both Slow/Fast、Max/Min 均启用、CRPR 开启。

| 检查 | 报告中该类最差余量 | 结果 |
|---|---:|---|
| Setup | **−5.783 ns** | **FAIL** |
| Hold | +0.024 ns | 展示路径无负余量 |
| Recovery | +0.501 ns | 展示路径无负余量 |
| Removal | +0.022 ns | 展示路径无负余量 |

- 全局 SWNS **−5.783 ns**，STNS **−324.923 ns**；最终路径组统计确认失败端点 **304 = sd_card_clk 93 + ext_mem_clk 211**，两组 STNS 分别 −97.328 / −227.595 ns。20 个路径组的 Min 违规统计均为零，其中 5 个 Min 零端点占位不参加最小余量统计。详细展示条数不是全网路径总数。
- 全局 HWNS **+0.022 ns**、HTNS 0，包含 removal，**不是纯 Hold 的 +0.024 ns**。
- 报告详细展示 setup/hold/recovery/removal 为 977/897/42/77 条，其中 setup 展示负路径 255 条；报告上限为每组 128 端点、每端点 2 路径，不能把 255 当作全网失败端点数。
- 最坏 Setup：100 MHz `sd_card_clk` 域，`wav/parser/file_length_reg[2]_syn_10.clk → wav/parser/chunk_space_reg[31]_syn_4.a[1]`；数据路径 15.531 ns，16 级 LUT（13 LUT5、2 LUT4、1 LUT3）。没有对该链做 RTL 修复。
- `ext_mem_clk` 40 MHz 域也有 **−5.565 ns** 余量，不能把失败缩小成单一 WAV 路径。
- `STA_REPORT PASS` 仅表示报告命令成功，**不代表 timing pass**；TD exit 0 与生成 bit 同样不代表时序验收。

### 约束覆盖与告警

覆盖率 99.96%；no clock、invalid constraint、PLL/clock buffer constraint、combinational loops、no path constraints、shadowed/ignored exception 均为 0。仍有 4 项 clock definition/local/master 分类、5 项 dummy node 分类、5 个 no input delay、20 个 no output delay、1 个 partial input delay、32 个 hard-IP abnormal input delay 分类。

这些继承接口/时钟边界不能因覆盖率高就全部签核；此版本已经存在明确的内部约束路径 Setup 违例，无需把无约束边界当失败原因或增加例外。日志还保留 `PHY-7002` SDRAM location 和 `PHY-5079` 一条本地时钟路由告警，未修改约束消除它们。没有执行额外 TD 时序建模试验，也没有开启时序攻关。

## 位流与证据（隔离保存，不作为合格下载版本）

位流：

`D:\FPGA\EG4S20-Bot-HDMIProbe\output\bot_probe_infer_add_delivery\bot_hdmi_probe_infer_add_off_001.bit`

- 729728 字节。
- SHA256：`49c9eeab267d894f6988d3469b831e8459acb4e2e4c8bc5cbcbce6c8ae4d6151`。
- 与本次 **phy_1 最终位流**逐字节相同（不是 best_result 的中间产物），匹配本次 artifacts.json 的哈希/新鲜度记录。
- **TIMING_FAIL / DO_NOT_DEPLOY：仅作为实验产物封存，未烧录。**

同目录：`manifest.json`、`SHA256SUMS.txt`、`bot_hdmi_probe_infer_add_off_001_reports.zip`。

- reports ZIP SHA256：`6c707f2baddba5796dcbeec6c4efa499350d1711fe3fd81626cccad11aeefd6e`。
- 源快照 `artifacts\bot_hdmi_probe_infer_add_off_001_source.zip` SHA256：`509746e9f247c1f6dab43fedb6b1e2d97c63b0ae1b3bc0c5bdaabff821b83eba`。
- 完整 DB/原日志保留在 `output\html_fidelity\builds\bot_hdmi_probe_infer_add_off_001`，Mac 不复制大中间工程。
- Mac 证据：`bot_probe/infer_collected.json`、`infer_timing_excerpt.txt`、`infer_final_area.rpt`、`infer_check_timing.rpt`、`infer_post_verify.txt`；独立审计位于 `bot_probe_infer_*_audit/`。

收集脚本初次因 Windows 路径分隔符比较触发断言，尚未写 bit/ZIP；只修正收集器路径归一后重新收集，**没有重跑 TD 或更改结果**。

独立 DS 时序审计已复现全部四类最差值、304 失败端点分组及位流哈希，并确认 hold 修复前后 area 报告逐字节相同、修复为 pin/net delay 调整。Root 已纠正审计初稿中“R-Freq 实测”“显示链没有失败”“正 22ps 等于零余量”等过度表述；最终以本报告的范围为准。

## 能支持与不能支持的结论

能支持：在同一 HDL、约束、工具和其他构建参数下，仅关闭 infer_add 足以使此次完整 Bot + Probe 放入并生成位流；代价是出现不可接受的 Setup 违例，故此单变量调整**未达成本轮时序目标**。

不能支持：该位流实板一定好/坏、探针是否能使 Bot 六页音画正常、原黑屏的根因已确定、或者任何实现策略下都无解。

下一步：本轮按要求停止，保留失败位流与证据；不自行提出并执行新的 RTL/SDRAM/Bot/渲染器修复，也不随机切换下一项优化参数。HFXL 备用卡与实板操作未进入条件。
