# EG4S20 时序收敛交付报告

状态更新：2026-10-16。Windows 执行根为 D:\FPGA\EG4S20-Multimedia-Signage，分支 codex/timing-fix。此前 HTML 交付保存在 Git 7325202 和原 delivery_manifest.json；本报告描述后续时序修复。正式构建、有效时序检查及本次必要离线回归已完成：BUILD_PASS、TIMING_PASS、REGRESSION_PASS。最终提交和推送记录由 output/html_fidelity/timing_fix/delivery_manifest.json 封存；不等于完整整机仿真或硬件通过。

## 结果与时序

正式配置：HX4S20C / EG4S20BG256，top，TD 6.2.168116（Engineer build168116）。SYN、PNR、BITGEN 均 PASS；最终有效 setup、hold、recovery、removal 检查均零违规；按下述已核对模型和接口边界判定离线TIMING_PASS，独立接受台账为timing_fix/final_timing_acceptance.json。两次串行完整构建分别659.125秒和690.797秒，合计1349.922秒。没有硬件、JTAG、串口、卡或系统配置操作。

| 检查 | 原 full07：违规端点 / 最差 ns | 最终 full02：违规端点 / 最差 ns |
| --- | ---: | ---: |
| Setup | 1 / -1.587 | 0 / +0.100 |
| Hold | 12 / -0.033 | 0 / +0.030 |
| Recovery | 0 / +1.197 | 0 / +1.653 |
| Removal | 7 / -2.495 | 0 / +0.027 |

最终报告包含 slow/fast 两 corner、max/min、CRPR，128端点/组、2路径/端点。44项 Max/Min 组统计全部零违规；详细报告覆盖959条setup、810条hold、35条recovery、141条removal。这些是报告展示数量，不是全芯片路径总数。全局 HWNS +0.027ns 包含 removal，不能误记为纯 hold 裕量。工具报告覆盖率99.96%；边界和残留告警见下文。

最紧 setup 为 SD100 域图像缩放器到状态寄存器；hold 为音频FIFO写地址；recovery 为 video25复位到HDMI125；removal 为HDMI25域内部复位。裕量虽小，但没有降低频率、uncertainty 或删除必要检查。

## 根因和修复

1. 原40MHz故障信号经多项OR再进入50MHz状态同步器，仅有5ns跨域边沿预算。将六项已注册故障分别两级采样，再在50MHz域OR；原FIFO/图层安全消费者保持不变。
2. 异步断言、两拍释放的复位同步链入口存在 removal 报警。保留同步FF，新增仅从 rst_all_reg 到六条同步链的 hold/removal 例外；recovery与所有下游检查保留。最终7个物理共享SR引脚准确对应12个目标FF，没有无关功能FF被豁免。
3. 设计接近满片，TD自动路由阶段因Slice使用率超过90%跳过hold修复。采用本版本官方支持的独立 fix_hold，然后导出修复后DB并重新bitgen；最终14个初始min违规消除。phys_opt 的独立旧DB实验发生原生崩溃，未用于交付流程。
4. 首轮新路由暴露两组setup长链：音频FIFO Gray解码/水位比较到SD地址仲裁，以及显示请求队列异步读到图层地址。分别注册低水位判定、预取60位完整队头。队头转发保持逐周期入出队、停顿和顺序；音频仲裁优先级最多滞后一个100MHz周期（10ns），请求/容量保护不变，并通过实际PCM竞争回归。

关键公开文件：rtl/ext/audio_media.v、rtl/ext/html_layer_memory_bridge.v、rtl/reset_sync.v、project/user_source/constraints_source/timing.sdc、harness/build.tcl、harness/spi_init_timing.tcl，以及相关测试/复现脚本。top_tf_hdmi_audio.v和frame_read_write.v属于本地派生依赖，公开Git只提交apply_html_integration.py / apply_html_memory_controller.py的作者增量重放，不发布完整vendor/派生源码。

保持640×480、25MHz像素时钟、原刷新时序、六页/八槽能力、BMP/HFXL格式、SDRAM容量、WAV/PCM、Bot/字幕/转场/缩放/双图、按键和素材。未更换PLL、引脚、HDMI/SDRAM IP或重新制作美术素材。

## 约束覆盖和边界

主50、SD100、memory40/180度、video25、HDMI125时钟保持原关系；没有设置异步时钟组或放宽周期。实际PLL配置、共同输入、派生频率/相位、跨域路径以及7时钟同根分组均已核对。check_timing仍报告4项local/master clock分类告警，其工具分类原因没有被证明或修复；不能声称工具“零告警”。无no-clock、invalid-constraint、PLL频率不匹配、组合环或未命中时序例外问题；残留分类告警不替代下面的真实路径级覆盖证据。

SD正常传输12.5MHz：实际MISO setup +14.530ns、hold +45.967ns；MOSI/CS setup +33.426ns、hold +33.501ns。TD例外汇总把MISO路径数记作0，但详细段有真实PAD、布线、LUT和采样路径；此前据汇总判定未覆盖的结论已纠正。真实CE测试证明fall40→capture80及next fall40→previous capture0，MCP4/7有对应依据。

SD初始化200kHz在独立新TD进程、同一最终路由DB副本中分析：MISO setup +2438.530ns、hold +2505.967ns；MOSI/CS +2493.426/+2493.501ns。内部时序仍+0.100/+0.027ns。该模式仅改真实SPI分频对应的分析模型，不修改RTL或交付位流。

外部SD模型采用tOD14ns/50ns、输入tSU/tH5ns的文档包络，加既有PCB每线0..1ns工程假设，故MISO16/0、52/0ns及MOSI/CS6/-6ns。依据Kingston SDCIT 4900180-001.A00第15页Table7-1：https://www.kingston.com/datasheets/SDCIT-specsheet-8gb-32gb_vn.pdf 。这不是对用户具体卡、负载或PCB的实测资格认证。

封装内SDRAM采用TD原生hard-IP模型，read min1/max5ns及对应output模型来自工具，而非新增板级假设。最终32个读端点setup/hold为+1.725/+16.753ns，48个写端点为+4.728/+12.164ns；局部clock路由和PAD延迟均进入真实路径。底层characterization表未独立解码，结论为采用厂商模型的离线签核。HDMI25→125串行化/ODDR内部路径保留实际检查。外部HDMI眼图、板路/线缆偏斜与接收端兼容性没有验证，不能用像素时钟output_delay虚构这些检查。

5个无周期input_delay的端口为按键、外部复位和DDC SDA。按键有实际保留的两级同步FF及20ms去抖；主复位在50MHz同步，再分域释放。七段扫描器保留原raw异步外部复位，释放启动边界未作为周期输入时序签核。DDC SDA综合后没有接收连接，EDID输出未被使用；固定显示/音频模式不依赖EDID，不能宣称EDID协商通过。20个未设普通output_delay的端口属于TMDS、DDC和人机显示边界；未制造任意外设参数。32项SDRAM输入分类告警和MISO partial-input标记均以实际详细路径检查解释，不据标记删除约束。

原native FIFO Gray约束保留；没有增加payload→shadow或音频数据的豁免。Mailbox协议测试虽验证握手稳定窗口，最终仍通过真实物理hold修复，未用例外掩盖其负裕量。

## 已执行回归

- reset/fault：15复位/重断言、129故障汇总比较、两拍释放与实际粘滞故障源；真实模块加精确顶层块提取，非完整顶层仿真。
- mailbox：WIDTH51/3、五种时钟相位、1198次捕获、1184次后续更新和26次复位中止；已验证稳定窗口，未增加相应例外。
- 队头预取：对原Git冻结实现逐周期对照及独立60位队列scoreboard，20122拍，包含2863次末项pop/push、1730回绕、4875停顿。
- 实际Gray FIFO压力：307200逻辑与输出像素、6400次有序写入，最低读水位90/511，最大后台写水位511，PASS，312.281秒。
- 音频13用例：FIFO、PCM音量/节拍、边界/短文件、单双声道、暂停、无WAV/截断/SD错误、可视化、视频音频控制和共享仲裁。初次短文件参数误设为立体声，按RIFF单声道修正测试参数后单独重跑通过；RTL与断言未因此修改。共享仲裁2304PCM帧顺序正确，无UF/OF。
- 实际六场景与PCM共享读取：7215104字节/1803776字、14098场景扇区、96音频扇区、3500PCM帧、36紧急仲裁，PASS，511.938秒。
- SPI CE/引脚模型：两种真实分频、16字节/128位，16/52ns输入模型，真实CS控制4命令，最小setup90ns/hold70ns，PASS。
- 当前源连续显示：layered_natural_20261016_153258 已 DISPLAY_CHAIN_SIM_PASS，编译和仿真均exit0，总耗时3972.811秒。1帧预热加8帧原速连续动作，2764800逻辑像素、4235383同步检查、2622476成对请求/返回、14630次刷新全部通过。8张实际DUT PPM与上一轮正式RTL捕获逐字节一致；当前导出文件逐字节匹配本次捕获，APNG逐帧无损RGB与16.8ms帧时序校验通过。仅覆盖动作0..117.6ms，不等于完整转场动画。原150913运行因队头源变更标为SUPERSEDED，原日志保留。

显示链使用真实511可用容量FIFO和有界SDRAM返回模型；音频峰值由正式WAV生成，真实播放器/后台写竞争由上述独立套件覆盖。不是完整加密IP整机仿真；FULL_SYSTEM_SIM_NOT_VERIFIED，HARDWARE_NOT_TESTED。

## 源码和产物身份

构建源码提交：aba266bf4ca2bdb347ed947493786cb9b6c00475。构建后新增或修改的测试参数、初始化STA脚本与报告不改变132项综合输入。当前报告所在交付提交仅增加测试参数、诊断脚本和报告；132项综合输入及54项显示回归输入重新校验一致，见final_input_identity.json。为避免文档自引用提交SHA，最终交付SHA、正常推送命令对应SHA及实际退出结果记录在同根delivery_manifest.json和git_push_final.json，并随Mac文本索引返回。不得把本地提交当作远端已推送。

正式最终构建根：
D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\builds\timing_fix_20261016_02

- 位流：work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit
- 位流大小729728字节；SHA256 a1492ed343765d27b3984701c29e7251cd279fbcfc7519a1525f68b26faf6f81。
- 路由DB：同目录hx4s20_basic_pr.db；SHA256 47f7bba20dc8c0e7970ed8ec265e9d7473e21622e36f010b7dd7ae65884b5825。
- 完整STA/阶段/工具/PID/退出记录：runs\timing_fix_20261016_02。supervisor26212、TD39300，exit0，2026-10-16T07:38:23.252950Z至07:49:54.038710Z。
- source ZIP SHA256 2923dfe9667f1cb1472c87ae52e47fae743dda64054cb1978578decc2a4d84c3；snapshot SHA256 5ca43173c2dcdfa27af0934d04fe9d8f5be33d5ea67c8c396a00612d19c3f4f3。
- best_result目录中的位流是独立hold修复之前的中间产物，不作为最终交付位流。
- TD SHA256 e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a。
- 最终布局9631/9800 Slice；64/64 BRAM9K、16/16 BRAM32K，20/29 DSP。未减少功能释放资源。

证据根为 D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\timing_fix：
full02_freeze.json、full02_timing_analysis.json、full02_independent_review.json、final_timing_acceptance.json、clock_reset_findings.json、final_input_identity.json、final_render_identity.json、spi_init_full02、spi_io_current、audio_regression_final.json、pressure_20261016T073408Z。六场景证据位于output\html_fidelity\scene_verification\20261016T073556224317Z。连续显示证据位于output\html_fidelity\display_chain\layered_natural_20261016_153258。所有路径均为本次实际运行产物，没有用旧报告替代。

复现入口：Windows现有Python执行scripts/build.py launch <全新run_id> --timeout3600；现有scripts/timing_reset_fault_verify.py、scripts/timing_head_prefetch_verify.py、scripts/timing_audio_verify.py、scripts/html_fidelity_verify_scenes.py，以及scripts/html_display_chain_verify.py --layered --subset natural --timeout10800。初始化STA在独立空目录、新TD进程中source harness/spi_init_timing.tcl，ANLOGIC_DB_SOURCE和ANLOGIC_PROD_SDC必须指向同一次已完成构建。完整vendor/加密依赖只保留本地，公开Git不承诺无依赖直接综合。

最终连续显示复核：supervisor PID27800、Icarus compile PID47180、vvp PID45992；实际仿真3969.548秒、exit0。APNG位于连续显示根下frames/action_samples.apng，SHA256 27e476556c7eb80dbd615cdef5f3a818504e54b43cea60a644b58675d4e1ef8a；来源清单位于frames/action_samples_provenance.json。Root查看实际首末帧，保留了既有布局和动作窗口；显示像素一致不扩张为HDMI电气或完整整机验证。
