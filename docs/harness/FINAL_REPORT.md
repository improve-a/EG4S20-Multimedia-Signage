# 分层 HTML 展陈版本验收报告

最终生产构建源码96cd7bd90f143a0d74f4b447bfd358409dd3302f通过full07的综合、布局布线和位流生成，包含“静态电流”文案修正。新增图层、BMP和scene数据路径setup已经转正，但整体TIMING仍FAIL：状态CDC setup、hold及异步reset removal未签核。此版本有离线功能和构建证据，不能称实板通过或完成时序签核。

六页常态、两组双图及2×/3×放大共10个静态代表帧已完成验证：当前源重跑7帧，另3帧按精确未变布局/字模证明保留此前捕获；不将旧快照改写成新commit。当前源的连续8动作帧也已通过显示链测试，原中断记录保留。没有访问开发板、JTAG、物理TF卡或串口。

## 当前完成范围

六页保持原有产品构图、文字和纹理。HFXL 场景资源由 FPGA 实时读取、移动、缩放、透明混合；Bot 身体纹理、独立眼睛和动作、逐字字幕、参数显示、真实 PCM 峰值条均由 RTL 驱动。对比模式使用两份独立产品资源；普通 BMP 保留原有自适应输入缩放，局部1×/2×/3×放大另行实现。

源代码位于 D:\FPGA\EG4S20-Multimedia-Signage，分支 codex/html-fidelity。正式素材目录为该根目录下 output\html_fidelity\media，仅使用 UI01.BMP 至 UI06.BMP 和07_MUSIC.WAV这一套。

## 视觉差异和边界

Bot 使用真实渐变身体纹理和仿射形变；与原型逐点变形的28点SVG轮廓仍有差异。固定点弹簧、浮动相位、远侧眼距及眨眼/说话压缩有量化差异；圆眼的名义几何和 alpha 混合已用像素测试修正。字幕采用229个实际用字覆盖率图集与固定排版，支持逐字揭示和实时参数，不宣称通用字体排版引擎。 正文产品文字与图层保持原型栅格；独立字幕使用2位覆盖率及整数glyph原点。原白字透明底alpha直接用于深色字纸底导致字幕偏粗，现已按原型实际墨色/纸色重新导出，该步骤保持原9120word、glyph ID与排版；之后的电流文案修正再追加40word。实际RTL六页overlay测试的字幕墨迹RGB平均绝对差由50.79–52.48降至37.41–41.07/255；字幕矩形由8.36–10.95降至6.72–8.32。六页整链结果采用最终修正参考与明确未变帧：猎鹰/两种放大的字幕矩形MAE6.74195、源墨迹37.38374；其他字幕保留上述区间。源产品与场景文字的RGB平均绝对差分别约0.048–0.752与0.277–0.432/255；Bot104×100区域约0.716–0.725，眼睛区域2.454。固定姿态与完整字幕刺激已记录，不能由静态分数推断全部动作还原度。残差主要包括逐字符原点±0.5px舍入、浏览器DOM/canvas栅格差异与2位量化；指标不是视觉质量百分比或通过门槛。

独立后台写压力测试使用与生产相同的40MHz存储、25MHz视频、100MHz源时钟比例，包含真实FIFO/Gray CDC，物理四字返回与刷新仍为有界模型。新写入准入在显示FIFO至少384字后锁定，密集转场最低余量90；它不能代替加密SDRAM PHY或硬件验证。

猎鹰字幕仅把“静态功耗低至5 mA”改成“静态电流低至5 mA”，保留数值和排版；这项单位术语修正不等于独立验证5 mA数值。原型原件保留，另存仅改这一处的HTML参考副本。原228字形数据不变，追加“流”字形；实际RTL完整帧比较仅183像素改变，两个字区域外逐像素一致，全部12布局揭示控制在307244拍中相同。

双图独立资源使用RGB565，暗色渐变存在色带；原型顶部的小“双图对比”标签尚未重现。局部放大采用真实最近邻地址映射，边缘比浏览器插值更硬。对比页产品/文字区域和缩放源alpha区域分别统计，不用全屏暗背景的平均误差掩盖局部差异。

页面转场同时使用采样的CSS分层运动参数和旧/新页区域选择，合成方式不等同浏览器逐像素crossfade。连续动作测试释放场景motion计数并通过真实页提交运行；它核对流、像素数、同步及错误状态，没有浏览器动态RGB oracle。静态局部差分和单独的曲线/几何测试不能据此扩大为全部动画像素一致。

音柱来自真实 PCM 的峰值/包络历史，不是 FFT 频谱。没有语音讲解音轨、TTS 或口型同步。现有80秒WAV结束后保持静音；测试中的EOF重启由测试台显式触发，不代表产品自动循环音轨。

## 验证状态

| 范围 | 结论 |
| --- | --- |
| RTL_SIM | BMP八尺寸/正式HFXL、资源+PCM、控制与Bot/OSD、真实FIFO后台读写及10静态代表帧与连续8动作帧PASS，覆盖边界见下文 |
| SYN / PNR / BITGEN | full07全部PASS，exit0，638.640秒 |
| TIMING | STA_FAIL；setup WNS/TNS−1.587ns、1端点；最小延迟WNS−2.495ns/TNS−15.821ns、19端点 |
| VISUAL | 10个静态代表帧及差分已生成，Root已查看最终猎鹰与两种放大；局部残差如上，连续8帧实际输出已生成 |
| FULL_SYSTEM_SIM | NOT_VERIFIED：未验证加密SDRAM/HDMI IP全系统功能 |
| HARDWARE | NOT_TESTED_THIS_RUN |

full07最终使用17382/19600 LUT、9318/19600 REG、64/64 BRAM9K、16/16 BRAM32K、20/29 DSP、4727/4900 MSlices。两种BRAM均已满。累计55次TD尝试（含隔离SYN探针）、7次完整构建、5427.814秒，没有并行重型构建或自动循环。

真正同域setup为SD100MHz +0.132ns、存储40MHz +0.209ns、视频25MHz +2.636ns；memory self hold +0.032ns。唯一setup违规为粘滞故障经OR送往fifo_fault_sync[0]首级，第二级才驱动状态显示。该CDC家族此前已存在，但本次扩展了故障输入，不能全称厂商继承或自动豁免。19个最小延迟违规分为12 hold和7异步reset removal，不能全部称data hold。配置mailbox、音频Gray同步和读ACK同步结构已核对，仍不能替代STA/CDC物理签核。coverage99.96%尚有clock/IO覆盖问题及本地时钟路由、SDRAM位置未honor等警告。没有改动时钟、引脚、继承PLL/reset/IP或添加时序例外。

最终位流：`D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/html_full_20261015_07/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit`，729728字节，SHA256 `f6e308a3cfbe844ffb993cc7eef6e50efc66d1c874414d07187e1517315c24ab`。

原始area/timing/check_timing、阶段、PID、工具身份和退出记录：`D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/html_full_20261015_07/runs/html_full_20261015_07`。输入关联见`output/html_fidelity/audit/full07_freeze.json`，132项输入与15份BIN已核对；8处ROM初始化路径和1处工程工作目录仅改写为不可变构建快照路径。

最终独立审查为`audit/full07_independent_page_control_review.json`，SHA256 `09b68bbf8f06d0a7725203451808119748a548ab4c660bc621d1e1aac7534d1d`。本轮时序报告和位流的时间戳、哈希均在本次运行窗口内；与full06的时序报告除生成时间及约束路径外逐字符一致。59项受保护依赖中53项与基线相同、6项为已核对的自研集成回放，不能全部称为未修改厂商源。没有用历史报告替代本次结果。

BMP最终17个有效测试全部PASS，八尺寸51733779拍逐周期等价，加上正式HFXL共2764800 golden像素；实际scene+PCM传输1803776字、3500PCM帧，36次紧急音频仲裁PASS。静态golden逐像素比较B/C叠加之前的底图，最终输出在B/C遮罩外核对底图；Bot/字幕由单独像素单测与局部原型差分评估。完整显示测试使用真实FIFO和有界SDRAM返回模型；后台writer竞争和WAV播放器行为由独立套件覆盖，不把这些组件证据包装成一次完整系统仿真。

## 正式素材和存储要求

六张BMP包含原生640×480、24位BI_RGB正高度图像，以及显式标识的场景尾部资源；四张产品页还包含独立HFXC对比资源。六场景用1803776个32位字，对比区从1843200开始用249856字，总数据8214528字节，8MiB SDRAM剩174080字节。不要裁剪BMP头、重编码图片或删掉尾部数据。

读取器按物理扇区扫描前64MiB的有效文件头，不按文件名或FAT目录排序。要求媒体文件物理连续，六图发现顺序为UI01至UI06，只有一个正确WAV候选，不能残留旧BMP/WAV头。普通复制顺序不能证明这些条件。

离线镜像 output\html_fidelity\card_images\unified_003adc1b_v2.img 已通过只读检查。它是测试文件，不能当作普通素材文件拷入卡中，也不能把其中的模拟LBA当成真实卡地址。正式六BMP与已完成的全字传输测试输入逐字节一致；完整哈希在media\manifest.json和audit\formal_media_transport_identity.json。

## 实际按键

| 操作 | 行为 |
| --- | --- |
| KEY1 | 逻辑复位；与CONFIG1/PROGRAM_B清除配置不同 |
| PLAY页KEY2短按松开 | 下一页，六页回绕 |
| PLAY页KEY2+KEY4共同按下后松开 | 上一页；该手势消耗两个单键动作 |
| PLAY页KEY2长按约1秒 | 切换普通/双图对比 |
| PLAY页KEY4短按 | 自动轮播开关，默认间隔5.4秒 |
| KEY4长按 | PLAY→BRIT→CONT→TIME→OSD→TRAN→ZOOM→VOL |
| 参数页KEY2/KEY4短按 | 参数增/减或切换；TIME以0.1秒调整 |
| ZOOM页KEY2/KEY4短按 | 1×/2×/3×放大循环增/减 |
| ZOOM页KEY2长按 | 六个观察位置循环 |
| KEY3短按/长按 | 暂停/恢复；静音/取消静音 |

双图配对为猎鹰/凤凰、精灵/飞龙；首页和生态页进入对比时默认猎鹰/凤凰。局部放大只作用于底图，Bot和字幕保持屏幕位置。亮度范围−128..127、步长16并夹紧；对比度0..6；轮播1.0..15.0秒；音量0..15。

## 明天验收顺序（尚未执行）

1. 确认目标HX4S20C/EG4S20BG256，记录上述未签核时序项；后续另行授权的实板验收使用full07位流和上述一套素材，不混用历史版本。
2. 备份卡后部署六BMP和WAV，使用 scripts\html_inspect_card.py 对明确选定的卡做只读布局核验；未确认连续簇、顺序和哈希时不要把异常归咎于渲染器。
3. 待首次扫描和场景加载完成，确认六页完整轮播、文字与产品图、Bot透明边缘和圆眼、字幕逐字显示。记录首次出图时间，不套用仿真秒数。
4. 检查上一页/下一页、快速连续操作、自动/暂停、字幕关闭、两组双图和1×–3×及观察位置。检查参数数字与图像效果在同一帧生效。
5. 听取真实WAV，检查音量、静音、暂停与PCM条响应；同时换页、放大，观察闪屏、欠流、音频断续。EOF后静音属于当前行为。
6. 进行持续显示测试并记录现象和时间。数码管A为FIFO/资源错误诊断；保留失败现象，对照本报告最终构建及output\html_fidelity中的对应日志，不用旧位流替代新版本结论。

## 交付位置与Git

Windows主仓库为`D:\FPGA\EG4S20-Multimedia-Signage`，生产构建commit为96cd7bd90f143a0d74f4b447bfd358409dd3302f；后续报告和生成器输入校验提交不改变RTL/初始化数据或该位流身份。公开仓库包含自研源码、测试、生成器与最小集成replay；完整vendor/派生整源、加密IP、位流和未授权素材保留本地，不能声称公开克隆即可直接整机综合。公开范围与依赖见README和docs/DEPENDENCIES.md。

正式媒体绝对目录：`D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\media`；manifest SHA256 `80e07f0267c136e1c6fb344f534f2c1621d08a935053929a67e7ac273190abc0`。离线测试镜像为`D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img`，SHA256 `be88671cd1e5732c5a94892fb4427b02db2ce82e03924b3f82346b474a73b1e4`。

实际显示证据根目录：`D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\display_chain`。当前重跑normal012/natural子集为`layered_normal012_20261016_125647`与`layered_natural_20261016_125647`，compare/zoom为`layered_compare_zoom_20261016_130114`，均逐项关联96cd7bd。三页未受影响的normal345保留原`layered_normal345_20261016_120043`捕获，11个未变布局/原9120word字模/1394非字幕列精确不变证明在`bot_osd/caption_current_candidate/unchanged_layouts_proof.json`；不伪造旧快照为新commit。

最终交付清单：`D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/delivery_manifest.json`。实际画面汇总为`display_chain/final_current_20261016_125646/final_verification.json`（SHA256 `fad96d250e941563a2944069db32e0ea2a635257609fe99aef670d3947490e0c`）：18张导出代表帧；连同预热共19检查帧/5836800像素计数，来自明确记录的多个子集而非一次整机运行。连续APNG位于`display_chain/layered_natural_20261016_125647/frames/action_samples.apng`，逐帧解码RGB与DUT PPM一致。

六个时刻的局部动作预览已经PASS：`D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\bot_action_samples\run_20261016_125647`。它是实际overlay RTL在0/84/420/1092/1545.6/1680ms六个名义时刻的样本，使用加速空白帧、固定背景和固定音频刺激；不是连续整机动画。连续8帧显示链在natural子集中已通过：另有1个不导出的预热帧，共9帧/2764800像素计数、4235383同步检查、2622476成对物理请求/返回、14630次刷新；覆盖5..10周期返回延迟和异常响应/欠流检测。动作帧首像素相隔16.8ms，覆盖0..117.6ms，循环预览时长134.4ms；不是完整1.68秒动作的逐帧捕获。原中断子集与旧PNG后处理失败都单独保留。

GitHub只读预检本次返回连接重置（exit128），尚未执行push；收尾将正常推送codex/html-fidelity，不强推、不合并main，并记录实际结果。全部预定离线验证及画面清单已完成；最后执行正常Git推送并保存结果。时序签核和实板验证不写成已完成。
