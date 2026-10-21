# NoBot HDMI 探针离线交付记录 — 2026-10-20

本版本用于观测真实HDMI视频锁定、AXIS接收和上游有效视频，不是功能修复。HW=NOT_VERIFIED；未操作任何实体板卡、JTAG、TF或Flash。

## 位流身份

- Windows：`D:\FPGA\EG4S20-NoBot-HDMIProbe\output\hdmi_probe\delivery\hdmi_probe_001.bit`
- SHA-256：`bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`
- 大小：677348字节。
- 来源：本次fresh `phy_1/hx4s20_basic.bit`，在既有流程的`fix_hold`后重新bitgen。不要拿`best_result`中较早的bit替换它。
- 基线：`17ac5f2`（完整身份以交付manifest为准）；RTL源历史`6ee7c70`。
- 构建源码提交：`72e5c80e223f53953f6bb7b53dbb704e41d7c2d6`。交付提交另含光栅短测试、文档及工程文件换行恢复；探针/顶层RTL与构建快照相同。
- source ZIP SHA-256：`5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f`。冻结130个文件，包含完整顶层及依赖。
- 分支：`codex/no-bot-hdmi-probe-20261020`；原NoBot工作目录保留。

## 验证结果

| 项目 | 结果与证据 |
|---|---|
| UNIT_SIM | PASS，17项正/负向断言；5页显示测试PASS。包括行间ready低、行内冲突、行首冲突、超时/失锁/恢复。 |
| 光栅短仿真 | PASS，实际color_bar/video_timing_data/AXIS加固定同步延迟投影，默认640×480计数，检查两个完整帧，仿真35.016ms；不是媒体/SDRAM全系统仿真。 |
| 顶层展开 | PASS；HDMI加密核/PHY采用既有替代叶模型，仅证明连接可展开。 |
| SYN / PNR / BITGEN | PASS，TD 6.2.168116 Engineer，EG4S20BG256，top。完整构建仅1次，394.157秒，退出码0；supervisor PID37144，TD PID5100。 |
| STA已约束路径 | PASS（限定范围），Slow/Fast两角Max/Min，Setup/Hold TNS均0，无违例端点。常速SPI及只读分析的初始化SPI模式均无负裕量。 |
| 全接口时序签核 | UNVERIFIED，报告覆盖99.92%，继承的I/O覆盖限制见下文。 |
| 映射保留/CDC | PASS，真实locked输入、各诊断状态及30个有意义状态/电平的两级显示同步FF保留；计数器未跨域采样。 |
| 引脚/时钟 | PASS，88条IO报告行（包括内置SDRAM）的引脚/电气字段不变；29个逻辑外部IO、33个PAD不变。25MHz视频/125MHz串行等主时钟不变。 |
| FULL_SYSTEM_SIM / HW | NOT_VERIFIED；未运行长媒体仿真，未执行上板。 |

STA：全局Setup +0.039ns，Hold +0.030ns。详细报告中的最小Recovery +2.248ns、Removal +0.035ns（详细路径列表有数量上限；全组违例统计为零）。最紧Setup路径是100MHz加载器timeout_count→sample_x使能，Hold也是加载器；没有为探针增加时序例外。

覆盖说明：原版99.93%→99.92%；check_timing告警数量与原版一致：clock definition4、dummy node3、无输入延迟5、无输出延迟20、partial input1、内置SDRAM abnormal input32；无时钟/无效约束/组合环/未匹配路径约束为0。按钮、复位、DDC、TMDS及显示接口未构成完整外部电气签核，MISO保持既有单边沿建模。原复位释放链的hold/removal例外、FIFO Gray指针hold例外未扩大到探针；44条被例外覆盖路径中没有探针端点。自动构建摘要故意保留STA=NOT_VERIFIED，本记录增加限定范围的人工核查结论，不将其改成无条件全接口STA_PASS。

## 对原实现的影响

LUT 10054→10257（+203，2.02%），寄存器6323→6572（+249，3.94%）。BRAM9K=53、BRAM32K=5、DSP=8、PLL=2均不变。HDMI/RGB/VS/HS/DE、AXIS数据和控制连线、音频、TF/SDRAM功能实例及约束未改；只增加观测负载并替换数码管内容。页号小数点使seg_data[7]从固定输出变为OREG，仍在A6。

重新布局确有影响：全局Setup从原版+0.813ns降到+0.039ns，仍为正但余量很小；视频域时钟扇出1813→1926。不能把此位流当作与原版物理实现完全等价；即使它恢复显示，也不能据此宣称已找到根因。本次资源增加较小、所有已约束路径非负，因此没有增加保护逻辑或盲目重复构建。

## 后续判定

板前编码和下一次SRAM观察步骤见`HDMI_PROBE.md`。先确认页5复位/PLL/心跳，再看页2有效视频、页3AXIS标记、页4有效传输背压，最后结合页1真实locked判断捕获/相位匹配。此前ready恒1、locked恒0的替代模型不能证明真实核锁定。当前尚无足够证据判定黑屏根因。

证据目录：`evidence/hdmi_probe`、`output/html_fidelity/builds/hdmi_probe_001/runs/hdmi_probe_001`及`output/html_fidelity/no_bot/verify/routed_init_hdmi_probe_001`。包含PID、时间、退出码、工具/源码/报告哈希、失败的早期辅助验证记录、fresh mapped与STA报告。交付manifest记录最终提交和所有包的哈希。
