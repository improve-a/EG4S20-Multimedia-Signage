# 旧 Bot + HDMI Probe 受控实验结果

## 结论

**完成真实定位、探针移植、Windows TD 综合与布局尝试；构建失败，未生成位流，未烧录。核心实板问题仍未回答。**

唯一一次构建 `bot_hdmi_probe_001` 于 2026-10-20 14:30:59–14:35:03 UTC 执行，耗时 243.953 秒。SYN PASS；PNR 在 Global Placement → Place Packing 失败：

`PHY-9009 ERROR: Design's mslice number = 4925, exceeds the limit 4900.`

超出 25 个 MSLICE（约 0.51%）。日志同时列出 4925 LSLICE。没有运行最终路由、hold 修复、BITGEN 或最终 STA；**Setup/Hold/recovery/removal、关键路径覆盖均未完成验收**。prepack 的正 SWNS 仅是中间估计，不是最终时序结果。不是超时、SSH 失败或探针语法错误。

## 精确身份与隔离

- Windows worktree：`D:\FPGA\EG4S20-Bot-HDMIProbe`
- 分支：`codex/bot-hdmi-probe-20261020`
- 旧 Bot 交付：`20871da98664b2b674fbcfe94a713359ff9614a1`；对应正式构建源码 `aba266bf4ca2bdb347ed947493786cb9b6c00475`。后续 `bcbc083` 才删除 Bot。
- 原 Bot 工作区含未提交 SDRAM 修改；实验未使用、未改动这些修改。
- 本轮构建配方提交：`9a27bbe73079d987bb4592b6a724b07cc33e5d9e`。完整私有 HDL/IP 由已核验旧 Bot source ZIP 恢复至独立快照，不发布到 Git。
- 探针 donor 仅采用用户指定成功交付 `42de1dbe4a20ca78f28be54c4bf41bd0dd814481` / 实际源码 `72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`。其已验证 bit SHA256 为 `bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`。
- TD SHA256 `e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`；继承构建 Tcl SHA256 `435659587ebe31f08015f459076840825c886ccca8e8cdeac0a1e0e5a95b4a47`。

## 变更与验收

设计输入只改变三项：

1. `top_tf_hdmi_audio.v`：接出 `O_video_locked`，接入原版只读 Probe，按 donor 替换数码管显示。
2. 新增 `ext/hdmi_probe.v`：与成功 donor 逐字节相同，SHA256 `f9e820e62d2abb204e2467e4c4f6791817d0adfb042e40b0399a660be9bbcf25`，包含原 `async_reg/preserve` 属性。
3. `.al` 登记探针，CompileOrder 96 = 原最大值 95 + 1。

无信号名称适配。其余 130 项设计输入在构建路径/换行归一后相同。旧 Bot、33 项素材、音频、SDRAM/cache、OSD、页面控制、时钟、引脚和约束保留；全部 harness 输入逐字节继承。ROM 仅重定位 INIT_FILE，没有重新生成。

注意：替换的是板上数码管状态码显示，不是 HDMI OSD。原 `display_state` 显示消费者被移除，观察锥变化属于 donor 原有实现；不能把这说成整个综合设计完全不变。

Root 对完整 ZIP 核验；DS Flash 1017 独立逆变换验证顶层与 .al 撤除探针后等于基线。探针单元测试 17 项通过，五页数码管显示/CDC 测试通过；这不是六页视频实板测试，也不是完整加密 IP 整机仿真。

## 资源（综合阶段，不是最终布局报告）

| 资源 | 使用/容量 |
|---|---:|
| LUT（工具 utilization 口径） | 17843 / 19600 |
| FF | 9638 / 19600 |
| BRAM9K | 64 / 64 |
| BRAM32K | 16 / 16 |
| DSP | 20 / 29 |
| PLL | 2 / 4 |
| PNR 打包 MSLICE | **4925 / 4900，失败** |

综合网表层级包含 `extensions/bot`、`probe`、`probe_display`，Bot 未被移除。LUT 未满并不意味着异构 slice 打包一定可实现。

## 对照与证据边界

| 工程 | Probe | 实板表现 |
|---|---|---|
| 原始 NoBot | 无 | 用户已确认黑屏、无声 |
| NoBot Probe，42de1db 对应指定 bit | 有 | 用户已确认六页轮播、画面和音频正常，断电重启稳定 |
| 旧 Bot，20871da / a1492ed3… 位流 | 无 | 历史硬件记录：黑白快速闪烁、无音乐，状态 A；非 HW_PASS |
| 本轮旧 Bot Probe | 有 | **未测：PNR 资源超限，无位流** |

旧 Bot 证据：原仓库 `docs/harness/ROOT_CAUSE_AUDIT_20261018.md` 第 1 节，关联 `output/hardware/hw_20261016T095019Z` 观察/下载记录。早期四图 ext_full_005 的硬件成功不能移用给完整六页 Bot。

用户确认板卡可现场观察，但因没有新位流，不进行下载，不更改 TF 卡或 Flash。六页/Bot/音频、两轮持续运行、断电重启全部 NOT_TESTED。

素材核查发现第二个后续测试边界：旧 Bot 完整场景要求 HFXL v1、set_id `0x003adc1b` 六页素材；成功 NoBot 使用六张普通 BMP + 四张 PN。六页基础像素与 WAV 同源，但容器/加载契约不同，不能直接把当前 NoBot 卡当作完整 Bot 验收素材。后续应使用备用卡上的已封存 `unified_003adc1b_v2.img`，保留成功卡不动。现有 BitWizard 只读枚举返回 EG4S20BG256；Windows 未看到 TF 卷不代表 FPGA 板槽没卡。Root 已纠正子报告对此的错误推断，并否决旧 PENDING 记录覆盖用户明确给出的 Probe 实板成功事实。

本实验仅支持：原参数与构建策略下，完整旧 Bot + 等价成功探针此次打包超出器件容量。**不支持** Bot 的音视频一定不能正常、Probe 修好/没修好原问题、或 SDRAM/HDMI 具体根因已确定；也不证明任何实现策略下都无法放入。

后续最有区分度的选择是另行授权一次“同一 HDL/约束，仅改变面积优先映射/打包策略”的构建，并与本次独立编号；这会引入明确的新实验变量，不能暗中作为本轮重试。如果坚持所有实现策略也不变，则本轮到此停止，不能在不改实验条件的情况下承诺得到可测位流。不建议删 Bot、移植 NoBot 缓存、缩减完整 Probe 或大规模流水化。即使未来实板通过，也仍需考虑逻辑保留、综合和布局布线敏感性，不能据此宣称根治。

## 交付路径与哈希

Windows 根 `D:\FPGA\EG4S20-Bot-HDMIProbe\`：

- 完整源快照：`artifacts\bot_hdmi_probe_001_source.zip`，SHA256 `be64885e449a530ef76c104db3acc3a98513c6b9427950ec9753b62fc940c248`。
- 报告包：`output\bot_probe_delivery\bot_hdmi_probe_001_reports.zip`，SHA256 `c76bb506c65ad2ecb52e312828325813d1ebcb53dbfbec446591f63a17442327`。
- 机器可读结果：`output\bot_probe_delivery\manifest.json`、`SHA256SUMS.txt`。
- 易读 diff：`output\bot_probe_verification\normalized_probe_only.diff`。
- 原始构建与 DB：`output\html_fidelity\builds\bot_hdmi_probe_001`。
- **位流路径、位流 SHA256：不存在 / 不适用。没有拿旧 bit 冒充本轮产物。**

Mac 本地证据：`bot_probe/{build.txt,failure.txt,verification.txt,collected.json,normalized_probe_only.diff}`；DS 审计 `bot_probe_audit/BOT_PROBE_ACCEPTANCE.md`。不在 Mac 复制大型 DB 或工程中间目录。

构建后只修正运行配方的失败退出码传递与 Python 正则转义警告，并新增验证/收集脚本和本报告；未修改已构建快照、未重跑 TD。原始此次源身份仍以 9a27bbe 和 source ZIP 为准。
