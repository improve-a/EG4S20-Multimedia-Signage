# NoBot 黑屏离线根因调查（2026-10-20）

## 权限与证据边界

Root：GPT-6 Astra。两个实际子模型调用均为 `deepseek/deepseek-flash`，模型目录名称 **DeepSeek V4.1 Flash 1017**。Worker A 负责综合网表；Worker B 负责物理实现/STA。无其他模型、无硬件操作。本记录不将 Probe 的实板成功转移给任何新构建。

## 1. 精确基线身份与冻结核验

- 成功冻结目录：`D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020`。实际重新计算 `SHA256SUMS.txt` 中 29 项，全部匹配；`git bundle verify` 成功；tag 解引用为 `42de1dbe4a20ca78f28be54c4bf41bd0dd814481`。
- 失败：`D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004`，源码 `6ee7c70bbf36c33f90a687f010c876de48f03ba6`，交付 `17ac5f2`；bit SHA-256 `61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7`。
- 成功：`D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001`，**实际构建源码** `72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`，交付/tag `42de1db`；bit SHA-256 `bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`。
- 两个构建目录已完整复制至独立 `D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\`，逐文件校验相等。包含原始 source ZIP、mapped/gate DB、routed DB、完整日志及 STA。不是在成功冻结目录补写文件，也没有覆盖旧构建。
- 失败 source ZIP：`dfe23f7520b126ecc8b5e15c4390c17a5f83b37dabed9862cee03750429d7b5d`，129 个输入；成功 source ZIP：`5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f`，130 个输入。ZIP 中全部输入与各自构建时 `inputs.json` 一致。
- 现存构建目录 `.al` 与构建前输入哈希不同：TD 添加 UCode、整理 compile order/AutoExcluded 等；因此输入比较使用构建前 ZIP，而不是事后 `.al`。两个构建后 `.al` 归一化仅差新增探针源文件。

### 精简输入差异

移除构建目录绝对路径及 CRLF/LF 的非功能差异后，全部源输入仅有三项变化：

1. `top_tf_hdmi_audio.v`：接出 `O_video_locked`；添加只读 probe/probe_display；替换原数码管 `display_state` 显示。
2. 新增 `ext/hdmi_probe.v`。
3. `.al` 新增上述探针编译文件。没有移除编译源。

六个 ROM/OSD/Motion HDL 的字节差异仅是 INIT_FILE 的构建绝对路径；对应资产字节相同。加密 IP、PLL、PHY、约束及其余输入相同。`exported_syn.tcl`、`exported_phy.tcl` 均逐字节相同。两者实际 TD 可执行文件 SHA-256 都为 `e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`，构建入口 Tcl SHA-256 同为 `435659587ebe31f08015f459076840825c886ccca8e8cdeac0a1e0e5a95b4a47`；TD 6.2.168116 Engineer。

支持证据：`verify.txt`、`snapshot_audit.txt`、`snapshot.diff`、`source_audit.txt`、`compact_inputs.txt`；完整哈希索引保存在 Windows RCA 根目录 `provenance_audit.json`。

注意：冻结交接文档中“不是确定性逻辑错误”的表述不是本轮已证明结论；本轮仍需独立区分逻辑、综合、启动及物理敏感性。

## 2. Worker B：物理实现与时序（Astra 审核后的摘要）

详见 `worker_b/REPORT.md`、`worker_b/SUMMARY.md`、`worker_b/metrics.csv`。Root 重新运行 `t10_focus.ps1` 抽查；原始结果见 `root_sta_spotcheck.txt`。

- 全局 SWNS 失败 `+0.813ns`：`wav/parser/pos_reg[30] → state_reg[1].ce`；成功 `+0.039ns`：`loader/timeout_count_reg[9] → sample_x_reg[4].ce`。都是 100MHz SD 域，不能拿来解释 HDMI 成败。
- 报告中像素域内部 setup 最小值：失败 `9.578ns`、成功 `4.493ns`；像素→5×串行 setup `6.296/6.179ns`，hold `0.164/0.172ns`。报告中的最紧串行握手是 `S_odd_even → S_odd_even_1d` 一类路径。**没有发现失败版独有、已建模的负余量。**
- 像素/串行时钟来自同一 PLL；检查到的 PLL/BUFG 站点相同，所列代表路径的时钟到达时间分别 `6.585ns` / `6.174ns`。这仅证明已列路径的模型数值，不证明两份完整路由逐点相同。
- 像素时钟扇出 `1813→1926`，资源和布局确实变化。5×串行采用 PLL 直出局部时钟路径；两版共有，不能直接视作故障。持续 TMDS 码字错位理论上可以导致接收器黑屏/静音，不能以“应该只花屏”排除。
- 约束覆盖 `99.93%→99.92%`；20 个输出无 output delay、MISO 单边沿等继承边界仍在。源同步 SPI 使用外部 generated DCLK 作输入延迟参考、内部 100MHz 捕获，本身**不是错误的时钟关系**；本轮没有修改 SPI 约束，也没有添加 false path。
- 详细路径报告设有 `ep_num=128/path_num=2` 上限；条目数相同不是全网路径数或结构相同证明。SWNS/HWNS 摘要可能含 recovery/removal，不能混作纯 setup/hold。
- `fix_hold` 改写 DB 与位流，必须使用实际被测的 `phy_1` 最终位流，不能用较早的 `best_result` 替代。

### 对子 Agent 初稿的纠错

Root 没有采纳初稿中“所有外部彩条经过内容黑场门”“SPI 参考钟不同就是约束错误”“TMDS 错位必然仍有图像”“3 个布局种子实验”等推论。Worker B 已回查并更正。尤其彩条冻结 ZIP `627847904ed6dcc8c648cd13f968a0b85804ad4f140f507450e62684946478ca` 的顶层，直接将 `diagnostic_rgb` 接入 RGB→AXIS 的 `I_rgb`，绕过内容门控；只有 `fx_vs/fx_de` 沿用原同步路径。因此“仅仅媒体加载失败”不能作为整个事实集合的充分解释。

## 3. 根因假设与区分能力

### Worker A 的综合网表证据（Astra 审核）

DS 从两份确切 `syn_1/hx4s20_basic_gate.db` 的独立副本只读导出 Verilog；不是重综合。失败 gate DB SHA-256 `5345f8ad01ee2e38e73b0dd1d5cbf2ec245f74673adb71df0a9e65a8f8ab6f3e`；成功 `314954cf3b62cdf368662a4e046b4feb154df1a5a1791146f796bf6cbe32ee56`。详见 `worker_a/SUMMARY.md`、`REPORT.md` 和 `evidence.json`。

- **locked 本来就存在**：失败版 `u_video_axi_stream_receiver/O_video_locked_reg` 保留，有 3 个核内负载；成功版同一 FF 的 Q 网名变为 `probe/locked`，增加 7 个观察/显示负载。不是 Probe 恢复了一个被错误删掉的 locked FF。
- **ready 确实被额外保留**：成功版多出 `S_video_in_ready_reg` 和 21 个 FIFO 读指针同步/占用统计 FF；现有证据指向状态输出锥，而非恢复被删除的 FIFO 数据路径。已核对的 BRAM 数据/地址/读使能/复位引脚保持对应。
- **TLAST/HS 只因观察而保留**：该 IP 配置映射锥不消费 TLAST（接口声明仍有 TLAST）；新增 `O_video_last`/11 位 `S_x_cnt` 及 32 个 HS 链 FF。不能把“未用输出被优化”当设计错误。
- HDMI 核 `AL_MAP_SEQ` 从 1529→1551：1466 个单元的名字、参数、引脚完全匹配，63 个有网名变化，增加 22 个 ready 相关 FF；PHY 47/47 FF 引脚/参数匹配。全设计 `AL_MAP_SEQ` 6242→6463；这与包含硬核/切片内部 FF 的资源总数不是同一统计口径。
- 24 位 RGB→AXIS FF、24 个黑场 LUT2、所查 PCM/ACR/复位链节点没有发现对应功能缺失。
- **实际局部等价验证**：对 `O_video_user` 的 D 组合锥穷举 3 个自由叶输入，8/8 相同；对 `O_video_locked` 的 D 锥穷举 5 个自由叶输入，32/32 相同。Root 审阅脚本并重新运行，见 `root_cone_spotcheck.txt`。只证明这两个组合锥，不证明顺序启动行为。

必须保留的未知：未做全网 SAT/形式等价；WAV/parser 有 38 个 LUT 形状变化未逐位验证；SD 路径 1 个原版独有 FF 未完整展开；24 个 OSD 打包 FF 只抽查一处；同名 D 网不证明其上游锥全等。Worker A 使用 gate 层，不是完整 post-route 等价检查。Root 已撤回其初稿“全音视频网表等价”及“冻结 hold 文档不一致”的过强/错误结论。

### H1：综合优化敏感

支持：探针把原本无外部负载的 locked/ready/TLAST 接入观测网络，且替换了原数码管状态观察，可能改变锥形逻辑保留、等价 FF 合并及 LUT 打包。

反对证据：locked FF 原本存在且两版 D 小锥真值表一致；ready/TLAST/HS 的额外保留目前只发现观察用途。**H1 中“关键 locked 功能被删、探针救回”的具体解释已被反证。** 一般的综合重映射敏感仍未完全排除，不能把未完成的全网等价当成已证明。

### H2：布局布线/物理边界敏感

支持：成功 Probe 改变资源、扇出、打包与路由，而功能 RTL 输入高度一致。内部 TPG/历史版本与外部输入版本的成败差异也允许下游捕获/串行实现敏感。

反证/限制：目前报告中的已约束路径没有失败版独有违例，失败版部分余量更好；不存在一条已证实导致黑屏的物理路径。未签核的板级 TMDS、电气时序、启动等仍是缺口，不是既成根因。

### H3：时钟、复位或 CDC/启动敏感

支持：视频锁定、接收 FIFO/同步路径、pixel↔5×捕获均涉及启动/时序；STA 不证明跨域协议或上电实际行为。Probe 的正常状态不能倒推原失败版内部同样正常。

反证/限制：两版 PLL、复位 RTL、时钟关系和约束相同，未找到新的具体设计违例。不重做已审查的 7 条复位同步器入口 removal，不凭猜测延长复位或加寄存器。

### H4：探针集成有意外功能变化

已有较强反对证据：精确 source ZIP 对比排除了功能源码/IP/参数/约束的意外变化，顶层改动仅观测与显示。仍不能把这种源码核对提升为整个后综合设计的形式等价证明。

## 4. 两个受控实验（不是生产修复）

两项都以**同一个成功 Probe source ZIP**为基线，每项仅一处顶层观察边界替换。构建路径统一重定位；除此之外，不改 IP、功能通路、时钟、复位、引脚、约束、种子或工具参数。保留全部六页/OSD/转场/缩放/双图/音频逻辑。没有将探针永久保留当修复。

### A — `rca_no_locked_003`

- 唯一主变化：观察模块 `.locked(probe_video_locked)` 改成 `.locked(1'b0)`；保留其它光栅、AXIS、音频活动及复位/PLL 观察。真实 HDMI locked 输出因此没有观测消费端。
- 可证伪命题：“真实 locked 的外部观察是成功所必需”。A 实板通过可否定这个必要性；A 失败不能单独证明命题，因为布局也变化。
- 页 1 是人为固定输入的结果：锁定/曾锁定/稳定/掉锁为 0，超时变为 1，**不能当真实失锁**。其余页保持原定义。

同一实验的 `001` 在 TD 运行约 246 秒时，监控读取与 Windows supervisor 的 `status.json` 原子替换发生访问冲突（WinError 5），supervisor 按原安全机制终止了自身 TD 子进程；不是 RTL/SYN/STA 的功能失败。`002` 随后在读取含中文异常的 UTF-8 账本时被 Windows 默认 GBK 解码阻止，**TD 尚未启动**。最终 `003` 使用等待 supervisor 进程退出、Python UTF-8 模式；实验 HDL、约束和种子未变。两份失败记录原样保留，未覆盖/删除。它们不算新增第三种设计实验。

### B — `rca_locked_only_001`

- 唯一主变化：显示器输入 `probe_flags` 改成 `{23'd0,probe_flags[4:0]}`。只消费锁定 5 位；复位/PLL 的独立显示接线保留。让综合器移除不再被消费的 AXIS/光栅/音频活动监测，而不是重写模块。
- 可证伪命题：“完整 AXIS/光栅观察锥是成功所必需”。B 通过可否定必要性；B 失败也不能单凭它归咎于被移除信号。
- 只有页 1 和页 5 的复位/PLL 位有意义。页 2–4 及页 5 音频/心跳字段刻意归零，不能解读为协议或音频故障。

### 共同局限

两项均会重综合/重布局，都保留 Probe 版的显示结构而非恢复原版状态码。它们是探针集合的互补缩减，**不是保持路由不变的物理 A/B**；也不能完全隔离“删除原状态显示观察”这一因素。若两个缩减版本都通过，最合理的下一步是定向物理/启动证据，而不是宣布某个被保留寄存器修好了故障。

## 5. 明日最短实板判定（本轮不执行）

保持现有卡、HDMI_B、线缆、显示器与上电/下载流程，不改 TF、不烧 Flash。另行授权的硬件会话中，以交付清单中的完整 SHA-256 确认文件，依次测试 A、B；每项观察 ≥一个完整六页轮播周期，记录视频、持续音频、五页数码管及显示器有信号/无信号。不要仅以数码管或音频单项判全通过。

| A 去 locked 观察 | B 仅 locked 观察 | 可得结论（不能越界） |
|---|---|---|
| PASS | PASS | locked 外部观察、完整 AXIS/光栅观察各自都不是成功的必要条件。偏向实现/观察组合敏感；仍未识别错误。 |
| PASS | FAIL | 否定“必须接出 locked”；其它观察负载或布局差异仍候选，不能证明 AXIS 功能错。 |
| FAIL | PASS | 否定“必须保留完整 AXIS/光栅探针”；小锁定观察版本足以运行，但不能证明锁定输出悬空是 bug。 |
| FAIL | FAIL | 两个缩减都不足，完整 Probe 的组合或物理布局仍重要；不做随机重种子。保留原成功位流作恢复对照。 |

额外区分信息不需第三个位流：

- A 的页 2/3/4/5 可观察同步/像素计数/AXIS 冲突与复位/PLL；页 1 为人为常量，不能使用其“失锁”判故障。
- B 的页 1是真实锁定；若持续 locked=1 且视频仍黑，说明这个**新构建**至少建立了锁定，需继续查内容或锁定之后的输出。若 locked=0 而复位/PLL 正常，优先查同步/AXIS输入到锁定的控制，但不能排除未观察输入异常。
- 这些结果只描述被测试的新构建，不能倒推原失败 NoBot 的内部状态。外部彩条仅排除了它自身的像素载荷/内容门控，`fx_vs/fx_de` 同步源仍未被该实验绕过。

## 6. 离线复现规则

实验由 Git 中的 `experiments/<ID>.json` 和 `scripts/rca_build.py` 复现，而不是把厂商/派生顶层直接提交到公开仓库。完整实际 HDL、IP、本地依赖及参数保存在 Windows 私有 source ZIP；不在 Mac 堆积 DB/PNR 中间物，不发布厂商源码。

在交付所列源码提交上，使用已校验的成功 source ZIP 和一个**从未存在的** build-root/run ID 路径执行：

```powershell
python scripts/rca_build.py --config experiments/<ID>.json --baseline-zip D:/FPGA/EG4S20-NoBot-RCA-20261020/baseline_copies/hdmi_probe_001_source.zip --build-root D:/FPGA/EG4S20-NoBot-RCA-20261020/builds
```

原 ID 已构建时脚本拒绝覆盖。重现需修改 ID 并提交新配置或选择新的父目录。脚本校验基线 ZIP，逐处计数替换，仅重定位绝对路径，保存新的 source ZIP/输入哈希和源码 Git 提交，再执行真实顶层展开（加密/物理叶使用既有替代模型）、短探针单元测试、TD SYN→PNR→fix_hold→BITGEN→STA。固定基线不等于保证未来构建 bit 字节完全相同；实板测试必须绑定实际输出哈希。

`scripts/rca_collect.py` 只收集 fresh `phy_1` 最终位流，附带 TD 日志、STA、源 ZIP、报告 ZIP 和 SHA 清单。正 Slack 只代表已建模路径，没有无条件全接口时序签核或硬件 PASS。

## 7. 对核心问题的直接回答

1. **失败与成功的关键网表差异？** 已识别的差异是 HS/TLAST/ready 观察锥保留、探针/显示逻辑、原状态显示链删除，以及部分 FF/LUT 打包和网名变化。HDMI locked FF、已查视频 FIFO/AXIS数据 FF/黑场/音频/PHY连接，没有找到失败版缺失的对应功能。
2. **探针是否改变优化？** 是，确实改变了逻辑保留与映射；但目前没有证据说明这些保留修复了功能错误。尤其 locked FF 本就存在，其 D 小锥与成功版穷举等价。
3. **是否发现真正危险的物理/CDC路径？** 找到了需要继续关注的 pixel→5×握手、局部串行时钟、复位启动及板级 TMDS 签核边界；没有找到失败独有的 STA 违例或被证实有错误的 CDC 协议。因此没有针对这些路径改 RTL/约束。
4. **能解释为何原版黑而 Probe 正常吗？** 只能解释 Probe 为何会改变实现，尚不能从证据闭合到“这条具体机制导致原版故障”。新位流是否成功需要实板结果；本轮没有伪造这一步。
5. **哪些是证明，哪些是猜测？** source ZIP/位流身份、冻结完整性、已列节点/资源差异、两个组合小锥真值表和各报告数值是直接证据。综合重分解的全等价、启动失锁、CDC亚稳态、TMDS物理边界、原版运行时内部状态仍未证实。

**根因结论：`ROOT_CAUSE_UNRESOLVED`。** 已缩小若干具体解释的空间，但未定位实际故障机制，故不使用 `ROOT_CAUSE_CONFIRMED`，也不将这种排除工作冒称为“已隔离根因”。没有生产 RTL 修复，没有功能删减，没有 SDRAM/FIFO 重构、IP 替换、新 false path 或盲目加寄存器。

## 8. 已完成的工程交付与验收

**两项新诊断版本均为 `OFFLINE_BUILD_PASS`、`HARDWARE_NOT_TESTED`。**

| 项目 | 失败 NoBot（历史） | 成功 Probe（历史） | A 去 locked 观察 | B 仅 locked 观察 |
|---|---:|---:|---:|---:|
| SWNS / HWNS（ns） | +0.813 / +0.022 | +0.039 / +0.030 | +0.423 / +0.024 | +0.106 / +0.027 |
| LUT / REG | 10054 / 6323 | 10257 / 6572 | 10246 / 6557 | 10148 / 6440 |
| BRAM9K / BRAM32K / DSP / PLL | 53 / 5 / 8 / 2 | 同左 | 同左 | 同左 |
| TD 完整构建耗时 | 历史记录 | 历史记录 | 373.828 秒 | 373.765 秒 |
| 本次新硬件测试 | 无 | 无（仅引用既有 PASS） | **未测试** | **未测试** |

SWNS/HWNS 是 TD 汇总 Max/Min 口径，可能含 recovery/removal。两实验正常 SPI 与初始化 SPI 模式的 slow/fast Max/Min，40 条路径组统计均为 0 违规端点；初始化模式 WNS 与表中相同。88 条 IO 报告行与成功 Probe 完全相同，约束逐字节不变；没有新增 critical-warning 类型。继承 `PHY-5079`（局部时钟布线）与 `PHY-7002`（内置 SDRAM 位置处理）告警仍保留，不当作无告警签核。STA 覆盖 A 99.93%、B 99.92%，完整外部接口/CDC/启动签核仍未完成。

### 实验真实映射检查

- A：core locked FF=1；真实 locked 只剩 **3 个核内消费者**，Probe locked 网和 lock_ever 观察寄存器消失；ready FF=1、TLAST FF=1、x计数 FF=11、帧/行观察计数 FF=20/11，保留了其它观察。
- B：core locked FF=1，locked 的观察负载保留；ready/TLAST/x计数/帧计数/行计数均 **0**。不是“源码改了但逻辑还没删”。
- 两版 `status_meta/status_sync` 仍各31个 FF：原 Probe 的 `preserve` 数组属性保留了常量显示同步寄存器。B 的 `status_meta[27:5].D` 全接0，**并无这些高位真实信号的观察负载**。Root 纠正了 DS 根据数量预测“应变8个”的错误预期。这里没有新增 preserve/冗余寄存器，也没有冒称 B 是最小生产设计。
- 两版完成真实顶层展开（加密/物理叶沿用替代模型），17项探针单测与五页显示单测通过。没有重跑数小时媒体仿真；这些测试不证明加密 HDMI 核或输出链实板行为。

### 实际位流、源码与提交

交付根目录：`D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery`

**A**

- 位流：`D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_no_locked_003.bit`
- SHA-256：`cce449034505c4d5c61a856b94b48c4c3d7e20a3eb86627972763a1981ca46a5`
- 源码提交：`5162f235103c1d55af346706141ed0c6d4aad5ec`
- source ZIP：`rca_no_locked_003_source.zip`，SHA-256 `6972abf47493250655e40ada146d4fa00fb0f0dde9cae3f5d913017ff7d42357`

**B**

- 位流：`D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_locked_only_001.bit`
- SHA-256：`41848d2090bc22695be98f096167005c4aceaecffbd6d20ecb0dc5b7440dba4a`
- 源码提交：`90263aa08c7c9625178b92b3eaccbe3a368b9c5b`
- source ZIP：`rca_locked_only_001_source.zip`，SHA-256 `1f49649fe00f003983ecdd80188dc86b168a81c2a09199958d75c752e16d14f3`

两位流大小均677348字节；副本均与各自 fresh `phy_1` 最终 bit 相同。每个 ID 有独立构建目录、源码/报告 ZIP 和 `<ID>_manifest.json`。`BUILD_RESULTS.json` 保留通用解析器的保守 `STA=NOT_VERIFIED`；`ROOT_ACCEPTANCE.json` 单独记录本轮人工范围审查结论，不把外部接口覆盖缺口涂成无条件 PASS。

Windows 工作分支：`D:\FPGA\EG4S20-NoBot-RCA-20261020\repo`，`codex/nobot-rca-20261020`。交付提交及 Git bundle 哈希见 `FINAL_MANIFEST.json`；bundle 名 `nobot_rca_20261020.bundle`。只在本地提交/归档，没有推送公开仓库。

证据定位：

- `baseline_copies/`：两个原始完整构建、精确输入ZIP、gate/routed DB、原始STA；新归档逐文件hash相等。
- `builds/<ID>/`：新实验完整TD、输入与产物哈希、短测试、阶段日志。
- `netcheck/<ID>/`：真实 gate/route Verilog导出、init模式STA、DB不变校验、观察锥断言。
- `delivery/rca_verification.zip`：Root审查、DS两份报告/摘要、可复现脚本及紧凑证据；大型DB/映射文件留在Windows上述目录。
- 成功冻结29项哈希与两份被测位流再次校验不变；NoBot/Probe工作区的HEAD与原有git状态保持不变（Probe原本就有未跟踪`output/hdmi_probe/`）。

本轮到离线交付为止。未操作开发板、JTAG、TF卡或Flash。
