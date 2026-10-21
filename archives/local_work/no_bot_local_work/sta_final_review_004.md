004 最终独立 STA、映射及资源审查

结论：在下述时钟、例外及接口模型边界内，可以标记 `TIMING_PASS_WITH_DOCUMENTED_MODEL_AND_INTERFACE_BOUNDARIES`。本次未发现真正阻止该范围签核的缺陷。该结论不是仅依据四个最小 slack；已核对完整分组统计、约束覆盖、有效例外、本次物理映射及实际 SPI 相位。FULL_SYSTEM_SIM 仍为 NOT_VERIFIED，HARDWARE 仍为 NOT_TESTED。

本报告只审查 004，替代 001 的待办审查条件；不把 001/002/003 结果作为最终结果。本审查人未启动 TD、未修改生产 RTL/约束/IP、未访问实际板卡。Root 在最终路由 DB 的独立副本上启动了初始化模式诊断，只有分析和映射导出，没有重新实现或 bitgen。

可复核入口：`sta_final_review_004.json`（各文件完整路径、SHA256、详细最差路径、全部 42 行分组统计、124 个冻结输入记录、Bot 删除清单与资源比较）；`sta_final_review_004.py`（标准库只读重核）；`reset_mapping_final_004.json` 和 `reset_mapping_init_final_004.json`（正常/初始化报告各自的 12 位复位证明）。以上位于 `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify`。

本次身份

- SOURCE：`6ee7c70bbf36c33f90a687f010c876de48f03ba6`。
- 工具：Tang Dynasty 6.2.168116，EG4S20BG256，top。TD 工具二进制 SHA256 `e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`。
- 构建目录：`D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004`；正常报告 `runs\no_bot_legacy_004`。
- 最终 phy_1 bit：SHA256 `61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7`。
- 最终路由 DB：SHA256 `a4012ee561d4081e2983a3478db0cbcf67b2dff021508d80745c410656005b8b`。独立诊断的 `init_pr.db` 逐字节哈希相同。
- 本次 `mapped.v`：SHA256 `36edbd1af5b40b4c0ade94c00ccb18408a9f9a5abff75afb9bfae30360a4d10d`，来自该最终路由 DB，在替换用户 SDC 前导出。
- 生产 SDC：SHA256 `93d101bdc89fa6ddb75ba17edb7c42bc04dd3eeecade0a649bfafa0a966e4051`，当前生产文件与冻结构建文件相同。
- 初始化诊断：`...\no_bot\verify\routed_init_no_bot_legacy_004`，supervisor PID 28416、TD PID 16032，exit 0，13.109 s，PASS，输入未改变。诊断 SDC 除六项有依据的 SPI 初始化替换外与生产约束相同：divide8→500、MISO max16→52、两个 setup4→250、两个 hold7→499。生产文件未改。

数值与覆盖

| 004 路由模式 | setup | hold | recovery | removal | 覆盖 |
|---|---:|---:|---:|---:|---:|
| 正常 SPI 12.5 MHz | +0.813 ns | +0.032 ns | +2.189 ns | +0.022 ns | 99.93% |
| 初始化 SPI 200 kHz | +0.813 ns | +0.032 ns | +2.189 ns | +0.022 ns | 99.93% |

两份报告都是 Routed，Slow/Fast 的 max/min 均检查、CRPR 开启。每份报告全部 42 行 Max/Min 分组统计均无负 WNS、TNS 为 0、违反端点为 0。正常报告打印 setup/hold/recovery/removal 详细条数 893/743/36/143；初始化为 583/478/36/98，打印详细条目没有负值。这些详细条数受 report 的端点/路径上限限制，不能当全芯片路径总数。报告顶部 HWNS +0.022 ns 包含 removal；单独数据 hold 最小值为 +0.032 ns。

实际 clock_summary 是一个 clk 根组、7 个时钟、3911 endpoints、nonclocks 0。实际源/路由预算保留输入 50、SD100、memory40、shifted memory40（rise12.5 ns）、video25、serializer125 MHz；没有添加异步或互斥时钟组。

两种模式 check_timing 的保留情况完全相同：no_clock 0、invalid_constraint 0、PLL/clock buffer 约束问题 0、combinational_loop 0、soft_FIFO 例外问题 0、no_path 0、shadowed/ignored exception 问题 0。仍有 clock_definition 4、dummy node 类别 3、no_input_delay 5、no_output_delay 20、partial_input_delay 1、abnormal_input_delay 32。不能声称零警告、100% I/O 覆盖；99.93% 的差额也不能机械等同于 25 个端口数量。

四个 local/master 分类警告仍存在，其工具分类原因没有独立解决。范围签核依据实际同源 PLL 配置、derive_clocks/频率/相位、七时钟根组以及实际路由 launch/capture 预算；没有为消除警告伪造例外。

复位及继承例外

最终正常与初始化 ignored 报告均只有 7 条 root reset removal 路径和 36 条继承 Gray 首级 hold 路径；没有 root reset setup/recovery cut，没有新增用户 payload 或 mailbox 的笼统 false_path。

7 个物理 SR 引脚逐个检查到 12 个逻辑位，恰为六条两级同步释放链：rs_sd/pipe、rs_mem/pipe、rs_video/pipe，以及 frame_read_write_m0 的 mem_reset_sync、write_reset_sync、read_reset_sync。每个有效 REG 位都为 ASYNC SET、MI 旁路，stage0 输入 0，stage1 输入本链 stage0，时钟域分别正确；未发现与无关功能 FF 打包后误切路径。12 位因 packing 使用 7 个 SR 引脚，不能要求固定为 6 个物理引脚。

当前 root reset 还驱动 fifo_fault_sync 和 state_code50 等其他功能寄存器；它们不在这 7 个例外中，仍正常受时序约束。最终映射另确认人类故障状态两级同步的来源为已经注册的 `fifo_fault_mem_sync[1]`，不是原组合 OR 源；本报告没有据此扩展任何例外。

继承原生 FIFO 的两组 Gray datapath_only max delay 各 18 条（24.7/9.7 ns），对应两组 hold false path 各 18 条，均生效且不被 shadow/ignore。这里只接受原 IP 的范围，没有把新增数据路径排除。

SPI 的实际 CE 与边沿

冻结 spi_master.v / sd_card_cmd.v 的 SHA256 与已有实际源 CE/CS 仿真完全一致（分别 `37f7a21144fa5cca3cc5c3b5f68a5ad40b3108336b600e45a1367734ac61403c`、`7d108a1efb9c5f6f756c1fd7bf88eea84715fbbd921f9a78241393ff4d70604d`）。当前 sd_card_top 仍是 CPOL=1/CPHA=1，高速 divider2（8 个 SD100 周期/SCLK），初始化 divider248（500 个 SD100 周期/SCLK）。复用历史 16 bytes/128 bits 两种 divider、16/52 ns 输入模型及真实 CS controller 测试证据；本审查没有重跑历史仿真。有效性限定为这些被确认没有改动的源、相位及 divider。

正常模式 MISO 的真实路由路径是 card falling40 ns→SD100 capture80 ns；hold 检查 falling40 ns 相对 previous capture0 ns。MOSI/CS 为 SD100 launch40 ns→card rise80 ns，hold 对应下一 launch120 ns 相对 rise80 ns。setup4/end 或 start 与 hold7/end 或 start 是该 CE 边沿推导，不是任意增加周期。

初始化模式对应 card falling2500 ns→capture5000 ns、hold falling2500 ns vs capture0 ns；输出 launch2500 ns→card rise5000 ns；setup250、hold499。MISO 只有相关 falling card launch 约束，因此有 partial-input 警告；max/min 两种实际 PAD/LUT/FF 路径均存在，并非缺少 min 或 max。

| SPI 路径 | 正常 setup/hold | 初始化 setup/hold |
|---|---:|---:|
| MISO（各 1 路径） | +14.431 / +46.012 ns | +2438.431 / +2506.012 ns |
| MOSI/CS（各 2 路径最差） | +33.426 / +33.501 ns | +2493.426 / +2493.501 ns |

继承的接口模型为卡 tOD14/50 ns、tSU/tH5 ns、PCB 每线 0..1 ns。它们不是对用户实际 TF 卡、PCB 负载或电气环境的实测认证。

32 个 native SDRAM 警告

每种模式均有 U3/sdram.dq[31:0] 的 32 组、共 128 项原生 hard-IP 输入约束（fast/slow，max5/min1 ns，reference_pin 为 SDRAM clock）。实际最终报告有 32 个读端点 setup/hold +1.725/+16.753 ns，48 个写端点 +5.423/+12.164 ns，路由中包含 hard-IP PAD 及 shifted clock 路径。接受 TD 的原生共封装 SDRAM 时序模型，不等于独立解码 vendor 全部 characterization 表，也不等于实板 SDRAM 稳定性证明；没有捏造外部 SDRAM 约束清除这 32 个标志。

尚未覆盖的板级边界

5 个 no_input_delay：HDMI_DDC_SDA、key1、key2、key3、rst_n。人类按键异步输入经本次实际映射的 PAD meta 级、后续同步级和 20 ms debounce；没有周期到达预算，未做 MTBF 认证。主复位先经过 50 MHz 同步再按域释放；继承七段数码管 raw rst_n 的外部释放/启动边界仍未验证。

最终 mapped 的 HDMI_DDC_SDA PAD 只有 bpad/do/ts/ce/osclk/rst，没有 di/diq 接收端口，证明固定显示模式中未使用的 EDID 接收通路已优化；不证明 DDC 电气或 EDID 协商通过。20 个 no_output_delay 是 4 个 TMDS 正端输出、2 个 DDC 输出/双向端以及 14 个七段状态输出。TMDS 外部眼图、线缆、接收器、DDC 电气及人类可视输出负载未纳入本次范围，没有为了变成全绿而伪造 output delay。

Bot 资源确实移除

七个专用名称 `html_bot_overlay`、`html_eye_radius_rom`、`bot_body_argb4444`、`html_eye_radius`、`bot_overlay`、`bot_body`、`eye_radius` 在本次 final mapped.v、综合/实现日志和冻结项目文件中均为 0 命中；冻结源码树没有旧 html_bot_overlay.v / html_eye_radius_rom.v。由项目输入、elaboration 和最终映射三处交叉核对，不能只靠某一层名称被优化消失作结论。

以下四份专用 ROM 在当前目录及 004 冻结源码均不存在。只读原目录中的文件仍存在，哈希与删除前记录一致：

| 原文件 | 原 SHA256 |
|---|---|
| bot_body_argb4444.hex | 2d60d127bea5ee61acaaba3497cf6af809a347f3512e1b12dc71fd555be2c338 |
| bot_body_argb4444.hex.bin | 65925a088154b30c82accb722eb417179967b10fcf206805f7f928a6d9d6570e |
| html_eye_radius.hex | bb99da44c45a94b0cf115378c9be15dd53e8917cd8a2a0298f0d530bca0ed0ff |
| html_eye_radius.hex.bin | b986f4e365ebfc3dcb8e678d367f238a34ffeb491ebbff73d5081293bbab6e91 |

同口径资源比较

找到原 `D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\builds\timing_fix_20261016_02\runs\timing_fix_20261016_02\final_area.rpt`，其 SHA256 `c73573e5181e36671ba0c2c56f41a48de0a2126ac622548f20c68aa16f7e469a` 与原 timing_fix/delivery_manifest.json 一致；构建源 aba266bf4ca2bdb347ed947493786cb9b6c00475、交付 20871da98664b2b674fbcfe94a713359ff9614a1。下表直接取同一版本 TD 的最终 area，不由 Slice 推算 LUT。

| 资源 | 原最终报告 | 004 最终报告 | 器件上限 |
|---|---:|---:|---:|
| LUT | 17679 | 10054 | 19600 |
| REG | 9392 | 6323 | 19600 |
| BRAM9K | 64 | 53 | 64 |
| BRAM32K | 16 | 5 | 16 |
| DSP | 20 | 8 | 29 |
| PLL | 2 | 2 | 4 |
| 路由 Slice（stdout 最终统计） | 9631 | 5824 | 9800 |

这表示去 Bot、停止复杂分层/缓存渲染、改用顺序 loader 在加载时合成双图/缩放以及相应控制流水的整体架构差异。没有隔离实验能把全部下降归因于删除 Bot，也不能把 Slice 和 LUT 混用。
