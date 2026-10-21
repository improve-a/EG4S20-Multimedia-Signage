# Mac 赛题一源码归档

这里保存从 Mac 多个工作目录和本地 Git bundle 提取的自研成果。原目录、原始文件和
本地历史均保留；没有改动根目录既有 FPGA RTL、引脚或时钟架构，没有执行新构建或上板。
当前公开仓库仍采用“自研代码公开，官方/派生依赖本地补齐”的边界。

## 目录与版本

| 目录 | 来源与用途 | 结果应如何解释 |
|---|---|---|
| `variants/html_full07/` | `96cd7bd` 的分层 HTML、Bot、OSD、素材生成与显示测试改动 | 构建证据存在，原报告整体 STA_FAIL；不作为实板通过 |
| `variants/html_timing_closed/` | `20871da` 的后续离线时序修复与回归 | 按随附报告的时序与模型边界解释，不推定硬件通过 |
| `variants/no_bot_exhibit/` | `bcbc083` 的去 Bot 参考实现与自研显示模块 | 离线参考版本 |
| `variants/no_bot_legacy/` | `17ac5f2` 的顺序双帧缓存集成、加载器和验证 | 原交付限定范围时序通过；后续实板问题须同时查阅诊断记录 |
| `variants/no_bot_hwfix/` | `3eb95ab` 的黑屏输入路径调查及测试 | 调查记录，不能将名称 HWFix 当作根因已修复 |
| `variants/hdmi_colorbar/` | `c6eb2c7` 的 HDMI 彩条输入诊断 | 独立诊断用途，不是生产功能修复验收 |
| `html_prototype/` | 原型 ZIP 中的 HTML 模板、CSS、JavaScript、构建脚本及 FPGA 说明 | 源码设计参考；厂商产品图片未分发 |
| `diagnostics_20261020/` | `Documents/openCamber/安路一` 的 RCA、自研探针、A/B/Probe 模块、定向测试与工具 | 保留 `ROOT_CAUSE_UNRESOLVED`；`fix_round/media_status_001` 明确 STA_FAIL / DO_NOT_DEPLOY |
| `local_work/` | Mac 中后续加载器、显示链路、字幕、协议检查与未合入的实验源文件 | 工作副本/候选，不自动覆盖冻结版本 |
| `historical_tools/` | 早期赛题一工程、TF 验证、USB/JTAG 的自研 Python/PowerShell/Tcl 工具 | 历史工具源码；归档本身没有执行这些脚本 |
| `baseline_source/` | 与已发布内容不同的早期自研控制、提交握手、测试或约束 | 历史版本；相同内容已存在时不重复保存 |
| `reports/` | 与这些工作对应的原始自研交付摘要 | 只证明报告明确覆盖的范围；不把旧结果当作本次新测试 |

## 如何使用版本归档

`variants/` 是相对于已发布基线 `fb97d76` 的文件覆盖集：与该基线逐字节相同的文件
不再重复复制。先阅读对应版本报告和源码清单，再在单独的本地开发副本上准备所需版本；
不要把不同目录的同名模块同时加入一个 TD 工程，也不要直接把所有覆盖集叠加。
目录内保留原文件相对路径，脚本中的 Windows 工作目录和 run ID 是原环境记录。

[mac_source_inventory.json](../docs/mac_source_inventory.json) 记录实际文件 SHA256、大小、
来源以及每个版本的完整提交 SHA。原始 Git bundle 只在本地读取，用于提取这些明确文件，
没有推送其分支、完整历史或源包。公开文件是快照归档，不能冒充完整私有构建快照。
根目录新纳入的 `scripts/html*.py`、`tests/html*.v` 和 `rtl/ext/html_assets/` 同样记录在清单中，
它们是原先已存在的 Mac 文件，内容未重写；不因此宣称根目录已经完成其整机集成。

## 仍需本地保留的依赖

- 官方 HDMI/SDRAM 加密核、生成 IP、厂商模型、官方原件及从它们修改的顶层/存储链路。
- 包含官方原文上下文的集成/补丁脚本；不同版本的精确完整输入仍以原本地快照为准。
- 从映射网表提取的厂商内部实现和相应编译网表。
- 原型中的厂商产品图片、照片及包含这些像素的成品 HTML/BMP/截图/图层数据，当前未核实再分发条款。
  `html_prototype/src/build.py` 仍可读取使用者合法取得的本地 `assets/`，本次不随包提供这些图片。
- 浏览器 profile、cookies、数据库、设备/卡备份、凭据、配置位流、TD 数据库及原始 ZIP/bundle。

旧 `local_temp/` 和 `output/html_fidelity/` 包含上述混合内容，现按原始工作区保留并忽略；
有价值且可公开的自研源码已按清单复制到这里。Google Drive 的安路目录本次仅见 HX1P35A
赛题二原始资料，未将其混入本仓库；其他赛题二和麦克风工程也未纳入。

## 验证口径

本次只做来源整理、文件哈希、公开范围检查与 Git 远端核验，不运行这些历史工具、
仿真或完整 TD 构建，也不更改历史失败的结论。报告中的硬件观察属于对应版本、对应日期；
它们不构成所有归档版本或当前根目录的新硬件验收。
