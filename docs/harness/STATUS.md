# HTML 分层移植状态

更新2026-10-15 20:08 PDT。Windows主仓库 `D:\FPGA\EG4S20-Multimedia-Signage`，分支 `codex/html-fidelity`；full04冻结8a0358fc7ceb4457ea1ab90086538ca3cb01e74e；资源头和PNG修复已提交e024987，随后BMP头和OSD数字寻址压缩正在增量提交。目标HX4S20C / EG4S20BG256、top、TD6.2.1 Engineer168116。本轮赛题一工程，不是同目录的PH1P35摄像头项目。没有硬件/物理卡操作，尚未推送。

## 最新完整构建

full04（8a0358f）SYN PASS，PNR packing FAIL：5006 MSlices超过4900。相比full03的5494有实质下降，但仍无最终位流。SYN17484LUT、9773寄存器、64/64 BRAM9K、16/16 BRAM32K、20/29 DSP；耗时274.156秒、退出2。STA未完成，BITGEN未运行。详情audit/full04_result.json；不可把placed estimate当routed STA。

full02只证明第一阶段BUILD_PASS，不含当前有限图层。其setup/recovery WNS−0.797ns、hold+0.003ns，覆盖率99.95%且有继承的IO/时钟警告，不代表最终STA通过。full01/03/04的失败证据全部保留。

累计48次TD尝试、4次完整流程、工具耗时3213.346秒，目前无重型TD运行。没有同时运行两个TD，也不会无改动自动重复完整构建。

## 目前两项收敛工作

资源：紧凑locator仅存已对齐字段的有效位，同时逐字节检查所有被省略位；scene loader的40/640/480固定头字段边到边比较。3014组完整512字节头部与旧实现对照PASS（798接受、2216拒绝）；6页8831字、266错误/传输/超时用例及普通BMP回退PASS，包括240固定字段逐位破坏。独立scene综合957→865LUT、636→400REG，零新增BRAM/DSP。生产已采用该候选，实际7215104字节全资源+真实PCM和HFXL BMP接受/拒绝复测均通过。证据verification/locator_compact_v1。

后台写：16BG/8cache/8计算上下文的静态六页read128/write256测试均PASS，但新增phoenix入场age25在持续合法SD写入时发生writer饥饿。该状态在目标页已ready而其它页/对比资源仍加载时真实可达。每burst等待全部prefetch清空、pending才清空、缩读burst64三个隔离候选分别出现视频欠流，均未推广。

物理排空候选区分已发送physical reads与尚未发送jobs；保留原fullbusy用于frame ACK/flush。只在writer pending、logical burst结束且显示FIFO至少384字时锁定写入准入，暂停新4word组、排空已开始组及returns。真实511容量FIFO/Gray CDC的phi25已通过307200像素、6400有序写、最低90显示余量；最长原始pending等待6664memclks。旧256/320候选最低1，均不推广。当前再测默认参数关闭兼容的最终源码；生产尚未切换。Root准备最小replay/top接线，不能将旧候选hash冒充最终版本。

额外等价资源优化：OSD直接数字字形码589824索引、921837周期及307200原生像素等价，独立SYN省39LUT；BMP头压缩3543完整头部逐周期等价，独立SYN省135LUT/203REG，BRAM/DSP不变。生产已采用两项，BMP实际payload/8种缩放/目录边界11项回归正在进行。

## 功能和视觉验证

暂停前最终BMP五项专项PASS1247.062秒；15项同步扇区RAM专项PASS。40项兼容快照39PASS，唯一旧替身缺ENABLE_HFXL参数的编译失败已单独修复复测，原失败保留。新的资源头版本不沿用旧BMP头解析结果冒充新验证。

当前资源头压缩前的实际六资源+PCM复测20261015T202112951932Z PASS：1803776字、14098场景扇区、96音频扇区、3500真实PCM帧、36紧急仲裁、491.437秒。EOF重启11次由测试台触发，产品EOF仍静音。

首帧门控/配置边界20261016_102325 PASS：实际loader/locator、display_commit和640×480 timing/mailbox；包含旧unsafe默认反例和受保护路径。资源头修改后run_20261016_104315复测亦通过。

18帧实际显示链正在display_chain/layered_20261016_102316运行，冻结8a0358f；已导出前5页，每页307200像素并通过，剩余帧仍在运行。使用真实读FIFO/CDC，writer端闲置；writer竞争由独立压力测试覆盖。音柱输入为正式WAV提取的峰值ROM，不等于该套件实例化了WAV/SD音频系统。PNG后处理发现误插的未定义变量检查，已单行修复并通过独立codec往返；旧runner/运行快照不修改，后处理恢复将保留来源记录。

Bot/OSD已有六帧像素等价、1221490实际RTL弹簧转移、720事件、alpha/缩放/中文字模和复位填充验证。另已通过0/5/25/65/92/100帧时刻的局部overlay实际RTL样本，明确加速空白期、固定背景/音频刺激，不能称连续全系统动画。

## 素材、公开边界与接续

正式SET_ID003adc1b，六HFXL BMP与07_MUSIC.WAV仍在output/html_fidelity/media。场景1803776字、四对比资源249856字，总8214528字节，8MiB剩174080字节。原型和原件保留。未推广两bank调色板候选。

离线普通FAT32镜像unified_003adc1b_v2.img已只读检查PASS；模拟LBA不作物理卡证据。公开仓库排除vendor/派生整源、IP、位流、未授权完整素材；本地59依赖已审计53原样+6授权可重放差异。新增writer握手若推广，必须更新精确最小replay及哈希审计。

SIM：明确范围通过，新后台写场景修复中。BUILD：最终FAIL_PACKING。TIMING：未通过/最终未完成。VISUAL：实际DUT帧套件进行中。FULL_SYSTEM_SIM：未验证。HARDWARE：NOT_TESTED_THIS_RUN。

继续完成公平仲裁、等价面积优化、匹配最终SYN/PNR/BITGEN/时序、区域视觉对照、验收报告和正常分支推送。不能以第一阶段成功或仅部分静态测试结束任务。
