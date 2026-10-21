# HTML 分层移植状态

更新2026-10-15 21:44 PDT。Windows主仓库 `D:\FPGA\EG4S20-Multimedia-Signage`，分支 `codex/html-fidelity`，此前构建源码e26ce11c00f3b42c220cda2826a5fd8ce525b0b2，现已推广mA字幕单位修正待full07；目标HX4S20C / EG4S20BG256，top，TD6.2.1 Engineer168116。本轮是赛题一，不是同目录的PH1P35摄像头工程。没有硬件、物理卡、JTAG或串口操作。

## 最终完整构建

`html_full_20261015_06` 对应e26ce11，fresh SYN/PNR/BITGEN PASS，退出0，658.859秒，2026-10-15 21:13:39至21:24:38 PDT。最终17382/19600 LUT、9318/19600 REG、64/64 BRAM9K、16/16 BRAM32K、20/29 DSP、4727/4900 MSlices。位流729728字节，SHA256 `06c7154ea79f85917652e8f3d79beb6bb4ae27168b3e7d805a8c9d540d56991f`，路径：

`D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\builds\html_full_20261015_06\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit`

TIMING仍FAIL。routed setup WNS/TNS均−1.587ns，仅1个失败端点。独立审查确认真实链为mem_fifo_fault→两级故障OR→fifo_fault_sync[0]，第二级才驱动display_state；TD端点state_code50是综合别名。该CDC端点家族full05已存在，但本次新增tag/panel/scene输入，不能一概称厂商继承或自动豁免。已报告同域setup：SD100MHz +0.132ns、存储40MHz +0.209ns、视频25MHz +2.636ns；视频clock-summary +1.869ns包含跨域，不能混称同域。此前新增SD解析和存储组合长路径已经消除。

最小延迟汇总WNS−2.495ns/TNS−15.821ns、19端点，包含12个hold和7个异步复位removal，不能全称data hold。memory self hold +0.032ns，本次compositor负hold已消失。配置mailbox稳定载荷至ACK，音频Gray/meta/sync和状态两级同步已核对，但结构检查不能替代STA/CDC签核。coverage99.96%仍有继承clock/IO约束问题。没有改时钟、引脚、PLL、继承reset或加密IP，没有添加时序例外。两种BRAM均用满。

累计54次TD尝试（含隔离SYN探针）、6次完整流程、4789.174秒；无TD任务继续运行。旧失败与full05证据保留。audit/full06_freeze.json核对132输入、128HDL/约束、59保护依赖和15BIN，8处ROM初始化路径改写均明确记录。原始报告、工具身份、PID和时间见audit/full06_result.json及run目录；独立审查为audit/full06_independent_page_control_review.json。

## 最终功能验证

- engine任务寄存流水：54012混合像素、3107稳定背压周期与flush测试PASS；生产真实FIFO/Gray CDC压力测试307200逻辑/视频像素和6400有序后台写PASS，最低显示余量90。实际read128/write256、FIFO容量512/可用511、写入准入储备384，physical_busy与完整busy分开。
- scene loader：逐周期旧/新接口对照、266错误/传输/timeout及连续字节输入PASS。实际六资源7215104字节/1803776字、14098场景扇区、96音频扇区、3500真实PCM帧、36紧急仲裁PASS（533.516秒）。EOF重启11次由测试台触发，产品EOF仍静音。
- BMP parser：当前12e584版本17个有效测试全部PASS，包括3543头部、八种输入尺寸、正式HFXL完整payload、拒绝路径、timeout/abort/error边界。八尺寸逐周期等价51733779拍；累计2764800 golden像素。无效早期fixture和失败测试保留且不计PASS。
- startup/config：实际loader/locator、display_commit、640×480 timing/mailbox复测PASS，保留旧unsafe反例。八图普通目录边界、音量/静音/EOF和Bot/OSD既有回归证据保留。
- 最终显示链四子集使用相同生产源与caption3492deff，均有不可变快照和c57/e26源码关联。normal012、normal345、compare_zoom已DISPLAY_CHAIN_SIM_PASS，共六常态、两对比、两放大；natural连续8动作帧仍运行。使用实际读FIFO/CDC与有界SDRAM返回模型；writer闲置，竞争由上述压力套件单独覆盖；音柱输入为正式WAV峰值ROM，并非本套件实例化WAV/SD播放器。
- 旧8a0358f的18帧实际显示仿真已PASS（5529600像素）。原runner随后真实NameError，保留退出1和traceback，只从未改动的DUT PPM恢复后处理；该结果不冒充最终源。

## 视觉、素材与收尾

字幕覆盖率改按实际深色墨/纸色导出，保持228glyphs/9120words及12布局。实际六页overlay字幕矩形MAE6.72..8.32、源墨迹37.41..41.07，优于旧8.36..10.95和50.79..52.48；最终整链局部比较正在汇总。仍有2位覆盖率、整数glyph原点与DOM/canvas抗锯齿差异。Bot保留纹理和独立动态眼睛，仿射形变不等同原SVG逐点形变。

正式SET_ID003adc1b，六HFXL BMP与07_MUSIC.WAV在output/html_fidelity/media；总数据8214528字节，8MiB剩174080字节。统一普通FAT32镜像unified_003adc1b_v2.img只读检查PASS，模拟LBA不作物理卡地址。15份HEX/BIN逐字roundtrip PASS，正式媒体未因caption修正改变。

Root负责Git/top/TD；B、C实际使用gpt-6.1-sol/high，未用Astra或递归编排。公开仓库排除vendor/派生整源、IP、位流和未授权完整素材；本地依赖完整保留并支持精确replay。公开历史审查PASS；两个自研参数字形ROM逐版本再生核验。GitHub预检连接重置，尚未push，收尾正常尝试并记录实际结果。

RTL_SIM：上述明确范围PASS，最终连续动作仍运行。BUILD：full06 PASS。TIMING：FAIL，保留未签核范围。VISUAL：最终静态帧PASS且差异待汇总。FULL_SYSTEM_SIM：NOT_VERIFIED。HARDWARE：NOT_TESTED_THIS_RUN。剩余独立视觉收尾、动作验证、最终报告和正常Git推送，不再无依据循环完整构建。

## 收尾发现（2026-10-15 21:53 PDT）

Root实际查看e26显示链PNG发现猎鹰字幕仍把5 mA称为静态功耗，按用户原要求必须局部改为静态电流；B在隔离候选追加“流”字形，保持既有ID/布局，最终仍需一次匹配构建，full06降为此前已验证候选。正式媒体不受该字幕ROM修正影响。natural子集的VVP/runner/supervisor已不存在，原RUNNING记录陈旧；无终止原因或delta-loop证据，现场保留并标记INTERRUPTED_UNKNOWN，等待新字模冻结后重跑。三个静态子集的既有PASS不受影响。独立只读诊断为audit/natural_renderer_readonly_review.json；原型对照人工查看记录为audit/root_visual_review_full06.json。

2026-10-15 21:57 PDT：单位修正已按精确差异推广；字模9160word、15BIN核对一致，native/control compile PASS，完整验证和新快照正在进行。
