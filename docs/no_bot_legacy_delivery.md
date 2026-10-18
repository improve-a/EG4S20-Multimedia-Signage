# 无 Bot 商业展陈离线交付

本轮离线集成、受影响回归、最终TD构建、独立STA审查及87帧真实RTL连续预览均已完成。状态为 **BUILD_PASS**、**TIMING_PASS_WITH_DOCUMENTED_MODEL_AND_INTERFACE_BOUNDARIES**、已列范围内回归通过及视觉通过（差异见下文）。验证索引共19项、0项待完成，包含保留的历史证据并逐项注明范围；不等于完整系统验证。**FULL_SYSTEM_SIM_NOT_VERIFIED；HARDWARE_NOT_TESTED**。

## 版本与边界

- Windows 源码事实源：`D:\FPGA\EG4S20-NoBot`；隔离分支 `codex/no-bot-legacy-integration`。
- 构建源码 `SOURCE_SHA`：`6ee7c70bbf36c33f90a687f010c876de48f03ba6`。最后报告提交 `DELIVERY_SHA` 写入输出目录的 `delivery_manifest.json`，不以文档提交号冒充构建源码。
- 保留分支 `codex/no-bot-exhibit`：`bcbc083779d551987293c885ab5c7b52802593fd`。原 `D:\FPGA\EG4S20-Multimedia-Signage` 的用户工作和新版缓存试验保持原样。
- 实际取图骨架来自 `ext_full_005` / `ad5f6525cf89991101cb85bf522e7b3a715c2622`：256字顺序读写、两个完整帧缓冲、原读写FIFO、原HDMI/SDRAM IP、引脚和时钟。历史位流SHA256为 `def3d2b116f2b48b5f23dde7d3ace283322750647408ef1b68e64dad3c70cd32`，仅用于基线追溯，不作为本轮产物。
- 历史构建与对应Git源码74/76项原字节相同；另一项为空编辑器备份，工程XML在目录、条目顺序和CompileOrder编号归一后相同。正常实板记录只支持当时验证的旧版功能；未完成的长时间运行不记为通过。
- 当前工程移除Bot本体/专属ROM和逻辑，不实例化新版 `html_layer_cache`、四字随机取图或第二路完整页面扫描。原时序约束不变。

## 赛题依据与边界

已阅读[2026安路选题指南的选题一第1.3–1.5节](https://drive.google.com/file/d/1lV1hRE_DFhZdloVfqjA9CYWO-Yy8NBdE/view)。文本抽取证据保存在本轮输出的 `contest_one_source.json`，没有把赛题二的摄像头或其他赛题的处理器要求混入本项目。

| 原文要求/扩展方向（概述） | 本轮实现 | 验证范围 |
|---|---|---|
| 明确场景的FPGA多媒体系统、实时控制与音视频输出 | 六页商业展陈，FPGA内扫描/加载/帧管理/OSD/PCM控制，无运行时外部处理器 | 分段RTL和TD/STA；现场稳定性与听音未验证 |
| 图层/字幕（可选扩展） | 独立字幕卡、打字、页码、进度和峰值条 | OSD像素及状态测试；精细CSS图层已按授权近似 |
| 轮播与转场（可选扩展） | 正反切页、自动/暂停，输出遮罩与旧缓存加载衔接 | 控制测试及真实连续帧 |
| 不同分辨率读取和缩放（可选扩展） | 配套640×480页和320×480双图面板，真实1×–3×采样 | 当前专用加载器严格限定该格式；通用任意BMP分辨率适配未完成 |
| 参数实时调节与OSD（可选扩展） | 亮度、对比度、轮播间隔、OSD开关、倍率/焦点等 | 既有像素/按键及本轮集成测试 |
| 音频可视化（可选扩展） | 真实PCM峰值历史 | 最终播放器→OSD真实非零柱形专项PASS；无FFT |

本轮离线预渲染生成静态媒体，运行时扫描、取图、双图、缩放、混合与控制均在FPGA中。这里只说明实现与验证范围，不替代竞赛现场验收结论。

## 功能与实际验证范围

| 项目 | 实现与证据 | 状态 |
|---|---|---|
| 六页/前后切页/循环/自动/暂停 | 旧后台帧缓冲加载；候选页、双图、倍率、焦点与地址原子提交；忙时合并最新目标；控制器12例与按键8例 | UNIT_SIM_PASS |
| 真实双图与缩放 | 两份独立320×480面板，真实1×/2×/3×坐标采样、六焦点，默认2×；初版14例；最终地址流水级版本累计重跑12个完整帧与20个边界/错误例，12个载荷与初版逐字节等价；static11所用载荷已逐项闭合，另有默认首页2×直接加载证据 | UNIT_SIM_PASS |
| 顺序读写/FIFO/刷新 | 生产40/25/100MHz关系；600与601周期刷新请求各8帧，每轮2457600像素、307200后台写入、提交后4帧新front；读FIFO最低96/75字，最高384，写FIFO最高300；刷新请求最长等266内存周期 | LEGACY_PRESSURE600_601_PASS；有界模型 |
| OSD | 保留字幕卡、打字、换场、页名页码、进度、缩放观察窗和音频峰值历史；去尾角、署名“产品导览” | UNIT_SIM_PASS；最终12组整屏及21张导航字幕裁片PASS |
| 转场 | 当前单路输出与固定深色遮罩混合，保留wipe/右滑；cover→旧机制加载→实际write_finish→读端ACK→完整新页资格帧→帧边界reveal；FIFO故障保持遮罩 | 快测PASS；87帧原生时序连续画面及独立逐像素审计PASS |
| WAV/HDMI音频 | 原80秒单声道PCM16/48k文件；完整3,840,000样本parser精确核验；有限摘录的EOF与显式restart复播、音量/静音、并发BMP压力分别验证 | 最终13/13回归、真实摘录两圈、4096样本并发BMP压力PASS |
| HDMI音频包与整曲实时播放 | 原HDMI音频IP和连接保留；384万样本检查是加速parser测试，4096样本压力窗口约89ms，有限摘录循环由测试台显式restart，未覆盖顶层EOF跨域边沿自动重启闭环，也不等于80秒整曲实时循环 | 独立音频包解码NOT_RUN；80秒实时播放NOT_RUN；听音HARDWARE_NOT_TESTED |
| HDMI与存储物理层 | 原IP与连接保留；实际显示/写入采用分段仿真和明确的有序存储响应模型 | FULL_SYSTEM_SIM_NOT_VERIFIED；HARDWARE_NOT_TESTED |

沿用的是20871da/bcbc083既有1×–3×、六焦点和双面板的逻辑画布坐标/最近邻采样规则：36项原点表相同，保留3×的余数相位及双图左右配对；现在在TF加载阶段逐行合成，再交给 `ext_full_005` 顺序帧缓存显示。存储表示、视图提交时机和动态转场实现已改变，不能称整条取图算法原样保留。旧面板未准备时的整页回退和packed资源底部粗采样分支没有接入本轮；本轮要求完整有效的10份BMP，按满480行面板取样。倍率/焦点变化也需要覆盖与重新加载。源码对照和精确公式见 `verify/legacy_spatial_sampling_review.json`。

所有真实画面从实际 `html_video_overlay.o_rgb/o_de` 输出采集，未用HTML截图、BMP或Python重画替代。存储模型采用有序10个内存时钟返回；原控制器在每256字命令后等待固定10拍尾窗再允许清FIFO。该继承假设不扩展为对任意返回延迟的保证。

按32bit帧缓存字计算，活动区显示峰值25M字/秒（100MB/s），全帧平均307200/16.8ms=18.286M字/秒（73.143MB/s）。加载器最多每16个100MHz周期送1字，即6.25M字/秒（25MB/s）；与活动区显示合计理论峰值125MB/s。40MHz×32bit端口的原始上限为160MB/s，但突发开销、刷新和仲裁会减少可用吞吐，因此这只是预算，不能替代FIFO压力测试或真实SDRAM验收。真实TF/SPI供数通常更慢，音频输入为48k×16bit单声道约96kB/s，进入左右复制后的PCM FIFO约192kB/s。

## 视觉与节奏

原HTML SHA256：`d1171344c3cc83f371fc6875d718ea978a56746945375b3afa2224810e46ea43`。无Bot派生HTML SHA256：`ba6655385bcbab9e5c6022958e231c2b4dee08161b3daba2b9f7e5ec0f3d4c49`。保留深色背景、米白文字、系列强调色及六页布局；静态图文预渲染为普通BMP。

最终稳定画面覆盖六页、两组双图、2×与3×及双图3×，另含默认首页2×，共12组；每组均从最终视频输出点采集。静态底图ROI共3,043,440像素、去Bot区域585,000像素、旧卡片尾角936像素与独立期望逐RGB相同。字幕卡平坦纸色ROI平均绝对误差为0；文字抗锯齿与浏览器的差异单独统计：署名MAE约32.44，正文约10.84–28.94（每通道0–255尺度），正文完全相同像素比例约69.7%–86.9%。这些差异没有混入底图数据正确性指标，也没有人为设置宽松阈值宣称文字完全复原。完整数值在 `verify/final_visual_metrics/visual_metrics.json`，六页整尺寸拼图在 `verify/six_page_actual_contact.png`，12组总览在 `verify/final_visual_contact/contact_sheet.png`。

正向0→1、反向1→0及末页5→0的字幕更新另有21张真实640×83输出裁片（1,115,520像素），场事件加速以覆盖完整打字/换卡过程；它们不是原生帧率的连续全屏视频。静态整屏在消隐期预热OSD到完整字幕状态，不代表开机时序。

音频可视化另用交付WAV从68.048083秒起的真实PCM摘录，经过最终 `audio_pcm_player` 的25MHz/48kHz节奏及64样本峰值窗口直接驱动最终OSD，678个有序样本、10个峰值窗口、1350个柱形ROI像素全部通过，得到9个历史柱高 `[1,1,3,4,6,6,4,3,2]`。该专项使用加速VS和同步FIFO数据模型；未包含SD/HDMI物理层。稳定全屏和连续片中的音频刺激则是由同一WAV离线提取的16.8ms窗口峰值，不能将其称为完整PCM播放器联动。证据为 `verify/player_osd_20261019_023517/verification.json`。

25MHz像素时钟、800×525总时序对应每帧16.8ms。覆盖12帧为201.6ms，揭示18帧为302.4ms；加载、提交和完整资格帧等待另计。连续预览的加载等待是明确给定的750ms仿真刺激，不是实卡测量。现有SPI实际RTL测得最早合法单扇区36,613个100MHz时钟；单页1×的2,161次扇区事务仅传输占用下界即791.21ms，尚未计入真实卡等待、加载运算及音频仲裁。双图、倍率和焦点会改变实际读取扇区数。

连续片保存在 `verify/legacy_display_20261018T171156698167Z/actual_rtl_samples.apng`，87张完整640×480实际输出帧，每帧精确16.8ms，总播放长度1461.6ms；7,374,943字节，SHA256 `f770a5daf583de300694330babcfa0a04478608645010685586ed4f5d240b4eb`。独立解码全部PNG及APNG，与26,726,400个原始PPM像素完全一致；遮罩/底图保守ROI另外核对22,077,120像素。未重画、跳帧、复制补帧或改变播放速度。该段仿真自然完成，VVP退出0，墙钟20731.343秒；读FIFO最低97字、最高384字，写FIFO最高298字，故障0，实际后台写入307200字。

| 事件（帧号从0起） | 实际帧/时间 | 解读 |
|---|---|---|
| 首次覆盖→全覆盖 | 帧10首像素203.016021ms→帧21首像素387.816021ms | 12个覆盖位置；首尾11个帧间隔184.8ms，与名义12帧预算201.6ms分开记录 |
| 加载等待 | 模型loadstart 386.689140ms→1136.689140ms | 精确750ms；起点是消隐期观测coverACK，非实卡读请求测量 |
| 新front完整资格扫描 | 帧66、67均为新front且完全遮罩 | 确认实际读端切换后继续整帧检查，随后揭示 |
| 首次揭示 | 帧68首时刻1177.416021ms；首可见新图像素(604,0)为1177.440181ms | 帧首像素仍是遮罩；不能把两时刻混用 |
| 完全揭示 | 帧85首像素1463.016021ms；帧86也完全揭示 | 18个揭示位置；帧首间隔285.6ms，首可见新图→全开首像素285.575840ms；名义18帧预算302.4ms |

cover请求、commitACK、write_finish未单独锁存精确事件时刻，回执只提供由相邻观测界定的区间；accepted-write计数也不冒充write_finish。资格检查使用真实display_commit、旧FIFO、顺序读写和最终输出RTL；上游控制事件与TF等待由测试台驱动，实际媒体控制器另有协议测试。该段的刷新刺激为约3100内存周期一次；600/601周期压力已有独立双轮证据。结束的两张完全揭示帧包含第一张全开帧，尚未经过新页33帧字幕延迟，完整打字过程由另列的导航裁片覆盖。完整实际节奏、输入关联和独立解码回执见同目录 `final_independent_receipt.json/.md`。

默认5.4秒轮播按完整reveal后的可见停留计时，与HTML从切页事件起算并包含转场的5.4秒不同；本轮一轮的总周期还要加覆盖、加载、提交/资格检查及揭示时间。与HTML相比，静态正文/产品图不做独立漂移和分层错峰入场；倍率和焦点离散；视图提交会重启字幕；字模抗锯齿及浏览器版本存在已量化的差别。详细差异、资源预算、按键和部署步骤见 [媒体与明日验收说明](no_bot_legacy_media.md)。音频柱形是实际PCM峰值历史，不是FFT；当前镜像首次启动和每次EOF循环仅重新扫描的理论下界即6.03821596秒，还需加卡等待、仲裁与预填，因此存在显著秒级间隙，不称无缝循环。

## 构建与时序

工具固定为 `G:\anlu\bin\td_commands_prompt.exe`，TD6.2.1 Engineer build168116；目标EG4S20BG256，top `top`，工具报告Speed=NA。工具SHA256：`e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`。

| 运行 | SOURCE_SHA | 完整构建 | 最差Setup | 说明 |
|---|---|---|---:|---|
| no_bot_legacy_001 | 1751242 | PASS，394.140s | −0.354ns | 加载器行偏移组合链，7端点；后续拆同步流水级 |
| no_bot_legacy_002 | 527d3d9 | PASS，384.109s | −0.152ns | 故障OR到50MHz状态同步链，1端点 |
| no_bot_legacy_003 | 592a82c | PASS，394.141s | −0.356ns | WAV扫描边界比较到CE，1端点 |
| no_bot_legacy_004 | 6ee7c70 | PASS，386.203s | +0.813ns | 提前寄存扫描边界比较；原时钟/约束未放宽 |

004的SYN、PNR、HOLD_FIX、BITGEN均PASS，合计四轮完整构建1558.593秒。最终最差Setup +0.813ns、Hold +0.032ns、Recovery +2.189ns、Removal +0.022ns，四类数值检查均无违规；独立覆盖签核见下文。LUT10054/19600，REG6323/19600，BRAM9K53/64，BRAM32K5/16，DSP8/29，PLL2/4。

最终位流：`D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit`，677348字节，SHA256 `61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7`。最终候选只取 `phy_1/hx4s20_basic.bit`，它在 `fix_hold` 后重新生成；`best_result` 可能仍是自动流程的较早位流。

本轮完整构建输入快照保存在 `D:\FPGA\EG4S20-NoBot\artifacts\no_bot_legacy_004_source.zip`，SHA256 `dfe23f7520b126ecc8b5e15c4390c17a5f83b37dabed9862cee03750429d7b5d`，快照清单SHA256 `67b4f446a86fd141a1157bd646ced1fab21632ed571d6382d54158026118f86b`。该包保留本地厂商依赖和实际工程输入；公开Git/bundle不包含这些大文件及加密IP，不能单凭bundle视为完整可综合工程。运行记录、各阶段状态、PID、退出码、工具身份和报告在构建目录的 `runs/no_bot_legacy_004/`。

**TIMING_PASS_WITH_DOCUMENTED_MODEL_AND_INTERFACE_BOUNDARIES**：独立审查已核对最终DB的常速12.5MHz与初始化200kHz SPI分析；两模式四类最差slack相同，每份42行Max/Min组统计的违规端点和TNS均为0。最终7个物理SR端点恰好映射六条复位链的12个目标FF，没有误切其他寄存器；未新增笼统false_path或放宽生产约束。

99.93%覆盖不等于全IO约束。无时钟、无效约束、组合环、未约束路径及shadowed/ignored exception问题均为0；仍有4项时钟分类、5个无input_delay端口（按键/复位/DDC）、20个无output_delay端口（TMDS/DDC/七段）、MISO未使用边沿的1项partial input、32组厂商SDRAM模型标志。正常MISO setup/hold为+14.431/+46.012ns，初始化为+2438.431/+2506.012ns；相关SPI约束与实际CE边沿一致。SDRAM原生读/写端点仍有实际约束和正slack。未覆盖实际TF卡电气、TMDS眼图/线缆/接收器、DDC协商、原始按键/复位板级边界；完整清单见 `output/html_fidelity/no_bot/verify/sta_final_review_004.{json,md}`。

| 资源 | 上轮aba266b/交付20871da | 本轮004 | 上限 |
|---|---:|---:|---:|
| LUT | 17679 | 10054 | 19600 |
| REG | 9392 | 6323 | 19600 |
| BRAM9K | 64 | 53 | 64 |
| BRAM32K | 16 | 5 | 16 |
| DSP | 20 | 8 | 29 |
| PLL | 2 | 2 | 4 |
| 路由Slice | 9631 | 5824 | 9800 |

以上来自两轮同版TD、哈希对应的最终area报告。下降同时来自去Bot、停用复杂分层缓存和改用顺序加载时合成，不能全部归因去Bot。Bot的两个专用模块、四份ROM在最终项目/elaboration/映射中均已消失；原目录文件和删除前哈希仍保留。

最终冻结检查将129项源码/配置/ROM按构建快照的同一目录替换规则归一后逐项比对，全部与004输入相等，见 `verify/final_source_freeze_audit.json`。交付前再次核对同129项输入及7份harness文件，并重新计算源码ZIP和所选位流哈希，全部一致；新增回执 `verify/delivery_source_freeze_audit.json` 保留早期审计不覆盖。TD保存工程时重新编号CompileOrder并添加UCode，60个源条目和其余配置经只读比较相同；冻结前原始工程保存在源码ZIP。工程、顶层、映射网表及TD日志的缓存缺席审计均通过，见 `verify/final_project_tool_metadata.json` 和 `verify/final_cache_absence_audit.json`。后续报告/测试提交没有改动综合输入。

## 配套素材、Git与明日实测

媒体根目录：`D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media`。包含UI01..06.BMP、PN01..04.BMP和07_MUSIC.WAV，全部格式、像素载荷及完整FAT32镜像已核验。一套目录覆盖六页与双图，不分A/B包。镜像SHA256为 `22f08ad1161d21f2b86ee6177cd8e4c957e295e218a49a8fba53f73b64bc0f9f`。

在592a82c阶段，正常推送在Windows、Mac均返回 `fatal: unable to get password from user`，没有修改凭据或网络；最终提交未推送，不冒称远端已更新。交付使用 `git/no_bot_legacy_delivery.bundle`，仅包含本轮隔离集成分支及保留的 `codex/no-bot-exhibit`，依赖原仓库已存在的 `fb97d76fa391ef33a5b12ea0a3db976b1cc4d4a7`；两端均验证bundle，并以非强制方式在Mac更新这两个分支引用，原main与工作文件不切换、不重置。最终 `DELIVERY_SHA`、bundle哈希、原Windows工作区及Mac交付前后只读检查结果统一写入 `output/html_fidelity/no_bot/delivery_manifest.json`。

今夜没有写实体TF卡、下载到FPGA或操作JTAG。明日另行授权后，用最终位流及本套媒体；镜像LBA只适用于完整部署并读回核对的同一镜像，普通文件复制不能保证连续FAT链与物理扫描顺序。先验首次显示/默认2×，再验六页正反/回绕、自动/暂停、双图与各倍率/焦点、遮罩期间输入、OSD、WAV及循环/静音/音量/峰值条。记录实际卡、位流和媒体SHA及异常复现步骤。
