# HTML 分层移植状态

更新2026-10-15 22:19 PDT。Windows主仓库 `D:/FPGA/EG4S20-Multimedia-Signage`，分支 `codex/html-fidelity`。最终生产构建源码为96cd7bd90f143a0d74f4b447bfd358409dd3302f，目标HX4S20C / EG4S20BG256、top、TD6.2.1 Engineer168116。本轮为赛题一，不是同目录的PH1P35摄像头工程。没有操作硬件、物理卡、JTAG或串口。

## 构建与时序

`html_full_20261015_07`：fresh SYN/PNR/BITGEN PASS，exit0，638.640秒，2026-10-15 21:57:38至22:08:17 PDT。资源17382/19600 LUT、9318/19600 REG、64/64 BRAM9K、16/16 BRAM32K、20/29 DSP、4727/4900 MSlices；两种BRAM均用满。

位流729728字节，SHA256 `f6e308a3cfbe844ffb993cc7eef6e50efc66d1c874414d07187e1517315c24ab`。路径为`output/html_fidelity/builds/html_full_20261015_07/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit`，原始报告位于同run根下`runs/html_full_20261015_07`。`audit/full07_freeze.json`核对132输入、15BIN和9处必要的快照路径改写；`audit/full07_result.json`记录工具身份、PID、阶段和退出状态。累计55次TD尝试（含隔离SYN探针）、7次完整构建、5427.814秒，无TD任务继续运行。

整体仍STA_FAIL：routed setup WNS/TNS均−1.587ns、1端点；最小延迟WNS−2.495ns/TNS−15.821ns、19端点。独立审查`audit/full07_independent_page_control_review.json`确认与full06仅报告生成时间/运行路径不同，全部路径和统计一致，报告及位流均为本次新生成。

唯一setup为mem_fifo_fault经两级故障OR进入fifo_fault_sync[0]，第二级才驱动display_state；state_code50端点为综合别名。该CDC家族此前已存在，但新增tag/panel/scene输入属于本次集成，不能全部称厂商继承或自动豁免。同域setup：SD100MHz +0.132ns、存储40MHz +0.209ns、视频25MHz +2.636ns；视频clock-summary +1.869ns包括跨域。geometry/cache/BMP/scene数据路径setup及compositor负hold已修复，memory self hold +0.032ns。

19个最小延迟违规为12 hold和7异步reset removal。配置mailbox稳定载荷至ACK，音频Gray/meta/sync与读ACK/状态同步已做结构核对，不能替代STA/CDC物理签核。coverage99.96%仍有clock/IO覆盖问题；本地时钟路由和SDRAM位置未honor等警告保留。没有改变引脚、时钟、PLL、继承reset/IP或添加时序例外。59项保护依赖为53 BASELINE_IDENTICAL及6 VERIFIED_AUTHORED_REPLAY。

## 已完成的功能验证

- engine流水54012混合像素、3107稳定背压周期及flush PASS；真实FIFO/Gray CDC后台读写压力307200逻辑/视频像素、6400有序写PASS，最低显示余量90。实际read128/write256，FIFO容量512/可用511，后台写准入储备384；物理四字SDRAM/刷新仍为有界模型。
- scene loader逐周期旧/新接口、266个错误/传输/timeout及连续字节输入PASS。实际六资源7215104字节/1803776字、14098场景扇区、96音频扇区、3500真实PCM帧、36次紧急音频仲裁PASS。11次EOF重启来自测试台，产品EOF仍静音。
- BMP parser当前12e584版本17个有效测试PASS，包括3543头部、八输入尺寸、正式HFXL完整payload及timeout/abort/error边界；八尺寸51733779拍逐周期等价，累计2764800 golden像素。无效早期fixture及真实失败记录不计PASS。
- startup/config实际loader/locator、display_commit、640×480 timing/mailbox PASS，保留旧unsafe反例；普通八图目录边界、音量/静音/EOF及Bot/OSD既有测试保留。
- Eagle字幕已将静态功耗改为静态电流，保留5 mA数值及原型原件；不等于独立验证该数值。原228glyphs/9120words不变，只追加流字形，最终229glyphs/9160words。全12布局307244拍控制等价PASS；完整字幕实际RTL307200像素比较仅183像素改变、两个字符格之外完全相同。15份BIN逐字核对PASS。输入guard再生输出精确一致。

## 最终画面与交付进度

当前生产源的normal012/natural分别为`display_chain/layered_normal012_20261016_125647`、`layered_natural_20261016_125647`，compare/zoom为`layered_compare_zoom_20261016_130114`。均有逐项96cd7bd源码关联；尚在运行，不以部分帧冒充完整PASS。三页未受影响的normal345保留`layered_normal345_20261016_120043`完整PASS捕获，并附`bot_osd/caption_current_candidate/unchanged_layouts_proof.json`证明11个其他布局、原字模及非字幕列不变；旧捕获不改写为新commit。

六个名义时刻0/84/420/1092/1545.6/1680ms的实际overlay RTL样本`bot_action_samples/run_20261016_125647`已PASS；加速空白帧、固定背景/音频，属于稀疏局部预览，不是连续整机动画。natural子集另验证真实视频时序连续8帧。此前natural进程失联记INTERRUPTED_UNKNOWN，原记录保留；旧8a的18帧仿真PASS而PNG后处理NameError，已仅从原DUT PPM恢复后处理，不冒充新生产源。

正式SET_ID003adc1b，六HFXL BMP和07_MUSIC.WAV位于`output/html_fidelity/media`；数据8214528字节，8MiB剩174080字节。统一普通FAT32镜像`card_images/unified_003adc1b_v2.img`只读检查PASS；模拟LBA不是物理卡证据。媒体未随字幕修改而改变。

Root负责Git/top/TD，B/C实际gpt-6.1-sol/high，无Astra或递归编排。完整vendor/派生源、IP、位流和未授权完整素材保留本地；公开范围经历史与增量审查。GitHub预检连接重置，尚未push；结束时正常尝试并记录结果。

当前结论：组件RTL_SIM在以上范围PASS；BUILD full07 PASS；STA FAIL；FULL_SYSTEM_SIM NOT_VERIFIED；HARDWARE NOT_TESTED_THIS_RUN。仍需最终完整画面/连续动作验证、视觉查看及Git交付。没有新的生产RTL修改或再次TD构建计划。
