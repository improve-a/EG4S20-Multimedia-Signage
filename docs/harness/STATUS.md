# HTML 分层移植状态

更新2026-10-15 21:04 PDT。Windows主仓库 `D:\FPGA\EG4S20-Multimedia-Signage`，分支 `codex/html-fidelity`；full04冻结8a0358fc7ceb4457ea1ab90086538ca3cb01e74e；资源头和PNG修复已提交e024987，BMP头和OSD数字寻址压缩已提交6c80f82；后台写修复已提交38925f7，full05已完成BUILD_PASS但TIMING_FAIL；现已推广经测试的engine任务流水、scene时序调整和字幕覆盖率修正，等待BMP timing候选与下一轮构建。目标HX4S20C / EG4S20BG256、top、TD6.2.1 Engineer168116。本轮赛题一工程，不是同目录的PH1P35摄像头项目。没有硬件/物理卡操作，尚未推送。

## 最新完整构建

full05（38925f7b2f7e75d2353696d3767f682b18a3e1ac）fresh SYN/PNR/BITGEN PASS，退出0，828.953秒。最终17429 LUT、9202 REG、64/64 BRAM9K、16/16 BRAM32K、20/29 DSP，4733 MSlices（器件4900），资源装载问题已解决。位流729728字节，SHA256 c6eabeedaddbb877601b1c1c0c2d1e36e6666f6a6bd391cebed903a83d41cf57；路径output/html_fidelity/builds/html_full_20261015_05/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit。

TIMING仍FAIL：routed setup WNS−1.967ns/TNS−256.206ns/364端点；最小延迟汇总WNS−2.859ns/TNS−17.669ns/24端点，含异步reset removal，不能全部称data hold。coverage99.96%仍需约束签核。实际SD/source100MHz、存储40MHz、视频25MHz；未改变时钟、引脚或继承reset/IP。full01/03/04等失败证据保留，不作新版本证明。

full05最差存储路径是geometry寻址→first-task bypass→cache tag匹配，报告起点的OSD名称是综合共享别名；真实launch为engine/wp。30FF弹性请求寄存候选经过54,012像素、3,107稳定背压周期、pending flush以及307,200像素/6,400后台写的真实FIFO测试后推广。成对wholebridge SYN 4836→4678 LUT、2048→2077 REG，BRAM/DSP不变。SD100MHz的header CE、宽超时与寻址比较另行进行针对性修复。

累计截至full05为49次TD尝试、5次完整流程、4042.299秒；其后只运行串行SYN探针，账本继续累计。最终BUILD_PASS必须重跑新RTL/初始化输入，不能沿用full05。

## 目前两项收敛工作

资源：紧凑locator仅存已对齐字段的有效位，同时逐字节检查所有被省略位；scene loader的40/640/480固定头字段边到边比较。3014组完整512字节头部与旧实现对照PASS（798接受、2216拒绝）；6页8831字、266错误/传输/超时用例及普通BMP回退PASS，包括240固定字段逐位破坏。独立scene综合957→865LUT、636→400REG，零新增BRAM/DSP。生产已采用该候选，实际7215104字节全资源+真实PCM和HFXL BMP接受/拒绝复测均通过。证据verification/locator_compact_v1。

后台写：16BG/8cache/8计算上下文的静态六页read128/write256测试均PASS，但新增phoenix入场age25在持续合法SD写入时发生writer饥饿。该状态在目标页已ready而其它页/对比资源仍加载时真实可达。每burst等待全部prefetch清空、pending才清空、缩读burst64三个隔离候选分别出现视频欠流，均未推广。

物理排空候选区分已发送physical reads与尚未发送jobs；保留原fullbusy用于frame ACK/flush。只在writer pending、logical burst结束且显示FIFO至少384字时锁定写入准入，暂停新4word组、排空已开始组及returns。真实511容量FIFO/Gray CDC的phi25已通过307200像素、6400有序写、最低90显示余量；最长原始pending等待6664memclks。旧256/320候选最低1，均不推广。最终默认参数关闭兼容源码已通过相同真实FIFO测试（335.672秒），生产已集成。Root完成最小replay/top接线及基线重建/重复运行/未知修改拒绝检查；正式公开入口复测PASS，production_proof_match.json将41项输入绑定到38925f7。

额外等价资源优化：OSD直接数字字形码589824索引、921837周期及307200原生像素等价，独立SYN省39LUT；BMP头压缩3543完整头部逐周期等价，独立SYN省135LUT/203REG，BRAM/DSP不变。生产已采用两项，BMP实际payload/8种缩放/目录边界11项回归全部PASS（regression/20261016T025903658697Z）；不覆盖后续尚未推广的BMP timing候选。

## 功能和视觉验证

暂停前最终BMP五项专项PASS1247.062秒；15项同步扇区RAM专项PASS。40项兼容快照39PASS，唯一旧替身缺ENABLE_HFXL参数的编译失败已单独修复复测，原失败保留。新的资源头版本不沿用旧BMP头解析结果冒充新验证。

当前资源头压缩前的实际六资源+PCM复测20261015T202112951932Z PASS：1803776字、14098场景扇区、96音频扇区、3500真实PCM帧、36紧急仲裁、491.437秒。EOF重启11次由测试台触发，产品EOF仍静音。

首帧门控/配置边界20261016_102325 PASS：实际loader/locator、display_commit和640×480 timing/mailbox；包含旧unsafe默认反例和受保护路径。资源头修改后run_20261016_104315复测亦通过。

18帧实际显示链正在display_chain/layered_20261016_102316运行，冻结8a0358f；已通过六常态、双对比、双缩放及前两动作帧，剩余帧继续运行。使用真实读FIFO/CDC，writer端闲置；writer竞争由独立压力测试覆盖。音柱输入为正式WAV提取的峰值ROM，不等于该套件实例化了WAV/SD音频系统。PNG后处理发现误插的未定义变量检查，已单行修复并通过独立codec往返；旧runner/运行快照不修改，后处理恢复将保留来源记录。

Bot/OSD已有六帧像素等价、1221490实际RTL弹簧转移、720事件、alpha/缩放/中文字模和复位填充验证。另已通过0/5/25/65/92/100帧时刻的局部overlay实际RTL样本，明确加速空白期、固定背景/音频刺激，不能称连续全系统动画。

## 素材、公开边界与接续

正式SET_ID003adc1b，六HFXL BMP与07_MUSIC.WAV仍在output/html_fidelity/media。场景1803776字、四对比资源249856字，总8214528字节，8MiB剩174080字节。原型和原件保留。未推广两bank调色板候选。

离线普通FAT32镜像unified_003adc1b_v2.img已只读检查PASS；模拟LBA不作物理卡证据。公开仓库排除vendor/派生整源、IP、位流、未授权完整素材；本地59依赖已审计53原样+6授权可重放差异。新增writer握手若推广，必须更新精确最小replay及哈希审计。

SIM：明确范围通过，后台写已修复并通过真实FIFO测试。BUILD：full05 PASS，当前修改待新构建。TIMING：FAIL，针对新负路径修复中。VISUAL：旧18帧继续运行，修正字幕和engine后新四子集准备/运行中。FULL_SYSTEM_SIM：未验证。HARDWARE：NOT_TESTED_THIS_RUN。

继续完成公平仲裁、等价面积优化、匹配最终SYN/PNR/BITGEN/时序、区域视觉对照、验收报告和正常分支推送。不能以第一阶段成功或仅部分静态测试结束任务。
