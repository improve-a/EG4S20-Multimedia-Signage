# HDMI 彩条诊断离线交付

黑屏/无声的确定根因仍未找到。已完成可信的离线输入路径检查和独立彩条诊断位流；正式无 Bot 版本保持原样，未将诊断版宣称为生产修复。用户报告原无 Bot 两次独立实板复测均失败，ext_full_005 在同一环境恢复图像和声音。今晚没有任何 Programmer、JTAG、实体 TF 或板卡操作。

## 可用产物

- 诊断位流：`D:\FPGA\EG4S20-NoBot-HDMIDiag\output\hdmi_colorbar_diag\delivery\hdmi_colorbar_diag_001.bit`（633116 字节）。
- 位流 SHA-256：`f5408a7273169cc40e57e78351b2ea181d71b90cb0b644831f33ddf67eb65e83`。
- 完整构建源码 ZIP：`D:\FPGA\EG4S20-NoBot-HDMIDiag\output\hdmi_colorbar_diag\delivery\hdmi_colorbar_diag_001_source.zip`。
- 源码 ZIP SHA-256：`627847904ed6dcc8c648cd13f968a0b85804ad4f140f507450e62684946478ca`。
- 源码提交：`944b03bf14e54ea7bd8cca267c5dc2d892b70f9e`，分支 `codex/no-bot-hdmi-colorbar-20261019`；工作树 `D:\FPGA\EG4S20-NoBot-HDMIDiag`。
- 输入调查提交：`3eb95ab52b81adfb615dd31dd2ad8e4ea1c1c7f1`，工作树 `D:/FPGA/EG4S20-NoBot-HWFix`。
- 冻结的 130 文件快照 SHA-256：`6d5cecc658895d95020ce91c99816973d872a78cf95de61585f3ea8f091b9baf`。
- 原始位流位置及两个正式/基线位流的保留哈希在 `BUILD_AND_SIM_MANIFEST.json`；最终副本逐字节等于本次新构建输出。原 61874e4f... 与 ext_full_005 的 def3d2b1... 均未覆盖。
- 新 TD 报告：`D:\FPGA\EG4S20-NoBot-HDMIDiag\output\hdmi_colorbar_diag\delivery\td_reports.zip`；清单和完整绝对路径见同目录 `BUILD_AND_SIM_MANIFEST.json`。

## 诊断改动

仅新增 21 行的 `rtl/ext/hdmi_colorbar_source.v`（行内 x 计数与组合颜色），将原 top 的 RGB→AXIS 适配器 I_rgb 换为诊断 RGB，并在工程中增加该源文件条目。I_vs/I_de 仍来自原 fx_vs/fx_de；原适配器、HDMI IP、PLL、复位、音频、pin.adc 与 timing.sdc 未修改。129 个基础输入中，仅 top 和工程源文件清单改变；其余 127 个逐字节一致，另增加一个彩条模块。原本被忽略的生成 top 在诊断分支显式受 Git 管理，构建不要重放 no_bot_apply_legacy.py。

画面为八条竖条，左到右：白、黄、青、绿、品红、红、蓝、黑，每条 80 像素，640×480。原 25MHz 像素钟、125MHz 串行钟，800×525 光栅、帧周期 16.8ms 保持不变。彩条不依赖 TF 或 SDRAM 像素准备，也不以音频成功为使能条件。原音频输入保持独立，无卡时沿用现有 tone 回退；有卡时仍按原机制可能进入 WAV。

## 根因调查与 HDMI 实现比较

详见 `docs/HDMI_IMPLEMENTATION_COMPARISON.md` 及其 SHA 收据。新旧 HDMI wrapper、参数、PLL 生成文件、PHY、引脚及音频/ACR 接线一致。真实差异包括新上游加载/提交/OSD、增加两拍视频流水、reset preserve 属性、既有 SDC 同步器例外及 UCode。17 相位和局部 mapped 接收控制实验未支持两拍偏移造成持续失锁；505 个输出寄存器控制、5 处局部 LUT 打包差异、3 片视频 FIFO BRAM 及位序核对未见可行动差异。这不是全部网表形式等价或实际串行输出证明。

本诊断 fresh mapped 中彩条 x 计数器仍存在，HDMI RGB 写入端保留三个非恒零 FF 驱动；每个颜色通道的 8 位均为 00/FF，故24位总线合并为3个重复驱动符合预期。HDMI_B fresh PNR 为 CLK C3/C2、D0 G5/G6、D1 F1/F2、D2 E1/D1，均 LVDS33，正端 DDRX1。

仍未排除：行为模型与真实 SPI/SDRAM/PLL 启动/时序差异、RTL 到 TD 推断 RAM/门级实现的动态语义、完整加密 HDMI 核与音频包、真实时钟/复位分发、TMDS/PHY 串行输出和原构建的物理实现差异。不据此认定 SDRAM 架构错误或硬件损坏。

## 实际离线结果

| 状态 | 结果与范围 |
|---|---|
| OFFLINE_BUILD | BUILD_PASS；本分支仅1次完整TD流程，SYN/PNR/BITGEN均PASS，TD exit0，296.062s；工具为 G:/anlu/bin/td_commands_prompt.exe，TD6.2.168116 Engineer。 |
| TIMING | STA_PASS（既有模型覆盖内）；slow/fast均检查，正常SPI与初始化SPI模式均0违规。覆盖99.91%，边界如下。 |
| RTL_REGRESSION | SCOPED_PASS；当前媒体例收尾、70clk/byte加载器正负例、独立彩条2帧协议例；没有追加多页/长循环/随机测试。 |
| VIDEO_PATH_SIMULATION | 原实际top媒体→SDRAM模型→FIFO→OSD→HDMI输入完整1帧PASS；诊断实际top在TF/SDRAM永远notready时，2帧614400像素全部匹配，每帧480行/480 TLAST、8色各38400像素，SOF间420000clk，HS低96/VS低1600。受保护HDMI/PHY为叶模型。 |
| AUDIO_PATH_SIMULATION | 原始WAV首247个PCM逐样本匹配，HDMI输入已见真实WAV非零、8402次48k节拍、175次ACR；诊断例1680次audio_valid继续运行。未证明每个HDMI输出PCM/包/TMDS，也未覆盖EOF自动重启。 |
| HARDWARE_NOT_TESTED | 本轮没有任何硬件操作；黑屏尚未得到实板修复验证。 |

原媒体例VVP exit0，3827.062s，模拟终点195.042821ms；卡字节流已加速，这不是实板加载耗时。诊断协议例exit0，579.73s，模拟35.01692ms；只提前启动计数器，真实复位链/时钟/视频没有force，56项输入与944b03b冻结快照一致。协议检查截止实际HDMI输入，不绕过适配器。

## 时序、资源与约束覆盖

最终全局Max/Min检查裕量 +0.203/+0.022ns。四类在报告中列出路径的最小slack：Setup +0.203ns、Hold +0.024ns、Recovery +2.439ns、Removal +0.022ns，所有路径组违规端点为0。四类最小值不冒充未列出路径的独立全局分类WNS；全局TNS也为0。初始化SPI模式使用最终routed DB副本，仅替换分析IO约束，9.312s exit0；未改最终DB、生产SDC或位流。

最紧Setup位于100MHz加载器sector_watch相关译码到sector_addr寄存器使能；0.022ns最紧Min为HDMI内部同步复位至island移位寄存器的Removal。均无违规，没有据此盲目改RTL。资源：LUT7399/19600、REG5494/19600、BRAM9K30/64、BRAM32K0/16、DSP4/29、PLL2/4。

check_timing：no-clock、invalid-constraint、combinational-loop、no-path-constraint均为0。4项local/master-clock提示、3项dummy提示以及5个无input-delay、20个无output-delay、1个partial-input-delay、32个embedded-SDRAM reference-pin提示与原无Bot相同（历史ext005的dummy为4）。无input-delay是DDC SDA及异步按键/复位；无output-delay是4条TMDS、DDC和14路数码管信号。MISO按现有下降沿/多周期模型分别分析正常divide8和初始化divide500。既有reset同步器/Gray FIFO例外原样保留，未新增掩盖违规的例外。外部接收器/DDC/板级模拟时序没有被99.91%内部覆盖率签核。

## 明天的最简操作

1. 单独启动明日实板任务并授权后，保持原HDMI_B、显示器及供电，用上述明确文件作一次SRAM下载（JTAG）；无需改写TF卡，不做Flash烧录。
2. 观察是否稳定出现白/黄/青/绿/品红/红/蓝/黑八条竖条；声音单独记有/无，不作为彩条的阻塞条件，数码管状态不能代替图像判定。
3. 若彩条成功：该诊断构建中的原HDMI输出实现能够运行，继续收敛原像素/合成控制或原构建实现差异；不能直接认定SDRAM有错。若仍为有信号黑屏：优先检查共同HDMI实现、时钟/复位、实现时序和串行输出，降低TF/SDRAM像素读取的优先级；需要时在相同下载流程下用保留的ext_full_005再做对照。这两种结果均不等于已经定位最终根因。

本轮在离线交付后停止，不执行上述明日操作。
