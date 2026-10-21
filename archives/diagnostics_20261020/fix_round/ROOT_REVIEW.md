# Astra 审核笔记（进行中）

## 根复位与外部 SPI 边沿的定点复核

依据成功冻结源 `top_tf_hdmi_audio.v:157–248`、`SD/spi_master.v:53–69,82–108,125–135`、`timing.sdc:12–28`：

- `rst_all_reg` 有显式初值1，锁定同步有显式初值0；正常释放前需两个PLL同步状态连续满足约20ms，之后分别经各域 reset_sync。没有找到“顶层完全没初始化/没等待PLL”的源码证据；单次当前lock=1也不证明所有上电历史正确。
- CPHA=0时 `MISO_shift` 在偶数 `clk_edge_cnt` 的 `DCLK_EDGE` 采样，同拍DCLK从低翻高；正常 `clk_div=2` 下两个边沿之间是4个sys100周期（40ns），不是DS上一轮曾误写的30ns。
- SDC由前向DCLK下降沿预算到内部100MHz采样，4/7多周期与上述逻辑半周期对应。不同参考/采样时钟本身不是错误。未发现足以支持修改 SPI 分频或例外的新证据；不重跑已完成的大规模I/O审查、不更改SDC。

## 第一轮 AXIS 报告审查

已核对本地 APUG092(v1.0) §2.4.2 原文及文档目录页码。行内必须连续输入，不支持简单 `valid & ready` 门控。

有价值的新定位是实际核中 `fifo_reset = core_reset | !video_locked`。但仅这个方程不能宣称已定位“永不恢复”；锁相状态机可重新捕获。原版锁定FF始终存在，此处不是Probe接出后才增加的功能。

未采纳第一稿的下列推论/实验：

- A 恢复 `.locked(probe_video_locked)` 就是原完整Probe输入，重复它不是新受控修复实验。
- BRAM `wea=valid` 不等于FIFO必定完整入队；仍必须核对写地址/复位/占用/读取时窗。
- 固定 `locked=1`、理想指针/自选period的Python队列模型仅能举示“C/D可以不是充分丢数条件”；不能证明真实IP首帧、持续正确显示或唯一丢失机制。
- B 某个同名 `S_fifo_empty` 单元没找到，不证明空判断逻辑被删除；要追实际BRAM ceb的驱动。
- 观测等价/小锥等价不证明全网或实际物理时序等价；不以此直接修RTL。

已要求DS沿真实mapped locked/pause/指针控制补足有界启动/恢复检查，并修正TLAST表述：本配置中TLAST被额外保留的ready输出锥消费，不能因 `I_axis_s_last` 网名消失就说核完全不消费该端口。

## Root 独立实际 RTL 短测试

不是Python转写：使用完整Probe的实际 `video_rgb_to_axis_640x480.v`（SHA `c051f6df03d8010e36d28980c63f68b9ffa7363e669f759893b0af17220c2c77`）在现有Windows Icarus执行 `root_tests/axis_source_hold_tb.v`。

- 2个完整640像素行：1280个valid、1个SOF、2个TLAST，像素序列与TLAST位置精确匹配。
- checker设4个synthetic-ready低的有效拍，随后4次数据仍改变。**实际发送器确实自由推进，并不保持stall数据**，与没有ready输入端口一致。
- 结果 `ACTUAL_RTL_OBSERVATION_PASS`，仿真64.56µs，编译/执行共约0.08秒。它是对实际源行为的观测通过，不是AXI正确性PASS，也不是实板C/D持续性/真实IP丢数证明。
- 如将此源接到要求逐拍ready握手的标准AXI接收端，它无法响应stall；但当前厂商核有特殊行连续契约，且真实写口/复位语义仍须联合判读。不能仅凭此测试添加 `valid & ready`。

## 媒体方向审核与复跑

- Root未采纳把永久sticky fault、单次错误进入FAILED、B主动屏蔽观察位称作产品RTL缺陷的表述；未证明合法流中误触发前，不加重试、不清除故障、不改FIFO。
- 独立读侧reset的音频FIFO反例违反当前组合reset/flush使用契约。DS已改正测试写入边沿，撤回把第三次实际写入引起的level=19称作计数错误。合法共同reset/flush的4个释放偏移测试未触发重放，不代表全可达空间证明。
- commit/cover共5个相位点+5个LOAD偏移，至多10例，且源/内存ack是模型；不宣称25例笛卡尔积或排除所有CDC问题。
- Root重新编译并运行phase7 commit和audio release200ns两例，检查进程返回码、日志无FAIL且errors=0（不是仅凭`$finish`退出0），通过。证据 `root_tests/review_media_results.txt`。
- 实际 `state_code` 有两种来源：catalog_ready=0时来自scanner，catalog_ready=1时来自媒体sequencer；因此新增状态观察必须同时显示catalog_ready。本候选仅增加一个只读诊断输出，不改state机器条件。

## 唯一诊断构建的 STA 阻塞

`media_status_001`（源码70f1961）SYN/PNR/BITGEN完成，363.985秒；显示11项短测、原探针17项短测、顶层展开通过。但原始最终STA HWNS **−2.701ns** / HTNS **−37.661ns**，20个removal违规端点均为rst_all_reg→rs_video/pipe[1]物理复制的SR。纯hold展示最小+0.035ns、recovery+0.278ns、setup+0.091ns。

这不是“exit0所以PASS”。已保存 `delivery/DO_NOT_DEPLOY.md`，没有更改例外。该直接新证据允许针对性检查同步器复制与既有例外的匹配，不重复泛化7入口审查，也不把新诊断的timing问题倒推成原NoBot/A/B根因。

## 后续精确复核及停止条件

- Root用完整网表解析器精确键验证20个负端点：19个第二级reset副本，D=同一pipe[0]、SR=rst_all、SET/ASYNC、CLK=video；另一个单元无Q输出。stage0唯一且D=0。捕获了DS摘录的一个错误：不存在`_syn_1/_syn_2`别名，它们是子串误匹配`_syn_10/_syn_20`，已纠正。
- 这支持“既有同步器入口例外的对象/名称覆盖没有跟随P&R复制”的解释，但不证明原NoBot/A/B黑屏由此引起。不得把同样的negative count推成新的媒体或HDMI RTL错误。
- 仅在新DB副本上尝试精确SR入口的分析规则；没有修改生产SDC/RTL/最终DB/bit。一次Tcl输出字符串方括号错误和两次补充查询均有记录；后两次虽然命令exit0，重读报告仍是−2.701ns/20个removal。**没有取得有效的补充PASS报告，不以退出码或人工过滤宣称STA通过。停止继续尝试例外。**
- 因此media_status_001维持 **STA_FAIL / DO_NOT_DEPLOY**。不随机换seed、不重跑相同逻辑碰运气，不生成第二种诊断。

## AXIS最终新增证据

DS复用实际网表导出的81 FF/27 LUT接收控制模型，结合实际锁相状态函数，31个首帧相位×3个初态的受测情形可重新捕获；实际初态下无永久失锁。Icarus额外首帧/后续帧及fill-only测试检查了写地址推进、满后阻塞和空读，不再仅看BRAM wea。模型不含BRAM payload/TMDS，初始1拍或1帧被reset阻断是控制层现象，不称为已测屏幕像素丢失。

对A/B真实最终routed DB，另外获取了原默认128端点报告中未列出的locked→FIFO SR路径：A已列recovery/slow +34.065ns、removal/fast +1.971ns；B +34.144ns/+2.365ns。正余量反对“这条已报告路径存在负slack”的解释，但端点/角落展示不全，旧NoBot/Probe未取得相同精确查询，不能外推成完整签核。Root还更正了DS的术语：removal和recovery都针对异步控制解除，不是一个assert一个deassert。
