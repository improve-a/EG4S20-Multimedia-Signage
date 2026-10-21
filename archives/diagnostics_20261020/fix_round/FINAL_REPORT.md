# NoBot 无人值守离线攻关结果

执行：2026-10-20 至 2026-10-21（北京时间）。Root Astra；两个实际 DS Flash 1017 子 Agent，分别负责 AXIS 与媒体/CDC。未运行其他模型、未修改冻结成功基线、未执行 JTAG/实体TF/Flash。

## 结论与交付资格

**`ROOT_CAUSE_UNRESOLVED`。本轮没有交付可宣称解决黑屏的生产修复，也没有合格的新实板候选。**

- `OFFLINE_VERIFIED` **只适用于下述有界短测试与静态检查**，不是全系统/全接口签核。
- 唯一新诊断 `media_status_001`：SYN/PNR/BITGEN完成，但 **`STA_FAIL / DO_NOT_DEPLOY / HARDWARE_NOT_TESTED`**。
- 没有将 sticky fault 改成重试，没有门控 `valid & ready`，没有重构 SDRAM/FIFO/IP，没有更改生产SDC，没有随机换种子或重复同一设计碰运气。
- 仍未达到“不依赖完整Probe稳定六页+音频”的目标；证据不足时不制造修复成功结论。

## 1. A 的 C/D 与黑屏是否存在因果关系？

**未证实因果，也不能把C/D=1当作根因。**

原始读数 `011114` 的正确解码是 **4.11110**：曾见ready高/低，C=`valid&&!ready`、D=`valid&&!prev_valid&&!ready`都曾置位。它们保持到video_rst，无发生时间、持续长度、行号。A的locked观察被固定为0，真实锁定不可由页1判断。

已实际验证：

1. Root用冻结的真实 RGB→AXIS RTL 运行两行短测：1280像素、1个SOF、2个TLAST位置正确；checker给4拍synthetic-ready低后，数据仍有4次推进。因此源确实没有stall保持能力，不能假设它是完整的逐拍握手AXI源。
2. APUG092 §2.4.2要求一行内连续数据。真实核视频BRAM `wea` 使用valid，不是valid&ready；**这本身也不保证成功入队**，还需看指针、full、reset和读时窗。
3. DS补查真实mapped写地址/CE/full：合法受测序列中无reset之后的写阻塞、无空读，FIFO占用最高10；fill-only负控写到1024个不同地址后出现阻塞，说明不能把BRAM wea高等同于指针永远推进。
4. 复用网表导出的81 FF/27 LUT控制模型，31个首帧偏移×3种初态的扫描中，实际复位态均能在受测范围重新捕获。6个相位的Icarus控制/FIFO例及满负控进一步核对。模型可在初始锁定前阻断一帧或首拍，但未复现持续黑屏；它不含BRAM payload/TMDS，不冒称已证明屏幕像素损失。
5. `fifo_reset = core_reset | !video_locked` 是实际功能联系。A/B最终routed的**已列**locked→FIFO指针SR路径：A recovery/slow最小+34.065ns、removal/fast +1.971ns；B +34.144/+2.365ns。未找到这条已报告路径的负slack反例。端点/角落展示并不完整；旧NoBot/Probe未取得相同精确查询，不能外推完整签核。

更正旧结论：TLAST被保留的ready输出锥消费（`ready_next=!last&&(empty||ready)`）；不能因为网名被别名替换就说核完全不消费TLAST。旧NoBot不消费ready输出，所以对应TLAST/ready观察锥可被删除。

证据：`axis/SUMMARY.md`、`axis/REPORT.md`、`axis/astra_reuse/`、`axis/physical_review/`、`root_tests/actual_axis_source.txt`。

## 2. B 的主图缺失与音频异常如何解释？

**仍是有证据支持的候选链，不是已观测内部状态。**

- `display_valid=0` 可以同时导致：主BMP在OSD前被门控、WAV的`sd_ready_out&&display_valid`启动条件不成立，而后级OSD仍显示品牌、字幕、默认01/06。音频此时可能是设计内tone回退。
- `fifo_fault`若实际触发，会让transition持续遮盖主图，并使提交/媒体状态机停在故障状态。这也可保留OSD。没有证明B实板触发了它。
- “音频异常”未经细分，不能改写为WAV损坏、underflow或tone。`audio_output_mux`短测确认：首次选择WAV前为tone，选择WAV后error/EOF不会自动回tone。扫描时间只是估计，不能把用户报告轻率解释为“观察太早”。
- 01/06可能是默认页或已提交的第一页；它不证明首图成功发布。B屏蔽了媒体、帧和AXIS状态，现有读数不能区分这些情形。

真实`display_commit+video_transition`的5个相位点+5个LOAD偏移（至多10例，**不是25例**）未见所测握手丢失。人为fault测试只证明fail-stop行为，不证明正常流会误触发。

音频FIFO单边reset反例不符合当前组合使用契约；按实际共同clear/flush序列的4个释放偏移测试，power-up和restart各32字顺序正确。Root另重新编译/运行commit phase7、audio release200ns，检查日志无FAIL且errors=0。未由此证明全部CDC/RDC可达空间。

证据：`media/SUMMARY.md`、`media/REPORT.md`、`media/tb/`、`media/out/`、`root_tests/review_media_results.txt`。

## 3. 找到哪些具体错误？有没有共同根因？

**未找到能证明在原NoBot/A/B实板中触发的生产RTL、CDC或协议错误；共同根因未证。**

确定纠正了分析错误：C/D误解码、将wea等同入队、用网名缺失认定逻辑删除、把单边reset当当前top缺陷、把fail-stop当应新增重试的漏洞、用局部计数/同名节点代替全等价。还纠正了removal术语：recovery/removal都约束异步控制解除相对时钟边沿，不是一个针对assert另一个针对deassert。

新诊断的P&R确实把视频reset第二级拆/复制；这是具体实现差异，但不是原黑屏的已证根因，见第6节。A连OSD也不可见，B的OSD可见，不能预设两者同因。

## 4. 实际修改了什么？

**没有实施生产功能修复。唯一构建设计是B派生的只读媒体状态诊断。**

基线：已实测B的精确source ZIP，SHA-256 `1f49649fe00f003983ecdd80188dc86b168a81c2a09199958d75c752e16d14f3`。

三项实际设计输入变化（配方 `experiments/media_status_001.json`）：

1. `top_tf_hdmi_audio.v`：把原B被屏蔽的显示状态位接到state_code、catalog_ready、display_valid、fifo_fault、SD/SDRAM就绪、WAV状态/选择/错误和active_view；其它功能实例端口保持原样。
2. `legacy_exhibit_media.v`：只增加`diagnostic_catalog_ready`输出及其只读assign，无状态转移/错误处理/数据路径修改。
3. `hdmi_probe.v`：仅改50MHz显示页译码；视频域probe模块、真实locked观察、PLL/reset观察不变。复用原有31位双FF同步，不建立新采集平台。

六页、OSD、转场、缩放、双图、WAV、音频可视化、自动轮播逻辑未删除。归一化构建路径后，仅上述3个输入文件变化；源SDC/IP/素材/时钟/物理引脚未改。

它验证的可证伪命题：**若同类OSD-only故障下稳定读得display_valid=1且fifo_fault=0，则“首图尚未提交/存储fault遮罩”这两个具体解释被否定（仅对这个新构建）。** 若正常出图，则只能说这个观察实现正常，不能冒称根因修复。

## 5. 如何证明不是只改变布局的修复？

**无法作这个证明，所以没有把它称为修复。** 新观察负载会改综合/布局，正是本轮必须保留的混杂因素。生产功能修改需要“明确违反的不变量→旧实现反例→修复后反例消失”的链条；本轮没有取得足以解释硬件故障的这种链条，因而不改功能RTL。

## 6. 新构建、回归和STA结果

- 源码/配方提交：`70f1961a6413b11257dc4c017d2df27e3c9998f6`。
- 一次完整TD 6.2.168116，363.985秒，SYN/PNR/fix_hold/BITGEN/报告命令完成，exit0。
- 真实顶层展开（加密/物理叶为既有替代模型）、未改视频probe的17项短测、新显示的11项断言通过；包括scanner与legacy同码的catalog_ready消歧。
- LUT=10141，REG=6450，BRAM9K=53，BRAM32K=5，DSP=8，PLL=2。

| 最终检查 | 已报告该类最小slack |
|---|---:|
| Setup | +0.091ns |
| Hold | +0.035ns |
| Recovery | +0.278ns |
| Removal | **−2.701ns** |

**原始全局HWNS=−2.701ns、HTNS=−37.661ns，20个违规端点，STA_FAIL。** 初始化SPI分析同样没有消除这一失败。setup STNS=0。不能把BUILD_PASS/bit存在当成时序验收通过。

### 20个removal的定点复核

- Root按完整网表精确实例键独立验证：19个真实reset第二级副本，D均为单一stage0 `pipe[0]`，Q为`pipe[1]_dup_*`，SR=rst_all、SET/ASYNC、CLK=video；另1个单元无Q输出，其SR是未使用FF的报告端点。
- 旧B的两个同步级打包在一个LSLICE；新设计stage0与第二级物理拆开、复制。原例外可见匹配没有覆盖这些复制名。没有发现新增的功能数据FF由未同步reset直接控制。
- 这解释了为什么新诊断出现这一组STA报错，但**不是原A/B故障因果证明，也不自动等于可以忽略它们**。
- 在新DB副本上做了有界的补充分析尝试，生产SDC/DB/bit均哈希不变；一次Tcl字符串错误及两次查询记录保留。补充报告仍为20个负removal，**未取得有效PASS**。不继续调例外凑通过，不重布局碰运气，不生成第二个诊断。
- 保留 `DO_NOT_DEPLOY`；没有发布或伪造合格的新位流。

证据：`sta_media_status_001.json`、`root_reset_structure.json`、`media/reset_review/`、`reviewed_reset_sta*.txt`；完整DB/报告保留Windows，不复制大中间物到Mac。

## 7. 位流与下一次最简实板测试

本轮新文件仅封存，**现在不要下载**：

`D:\FPGA\EG4S20-NoBot-Fix-20261020\delivery\media_status_001.bit`

SHA-256：`6a99ffcc463f94c348452cded9fb18c982e09f1faf65a20aa4d95376e6e55166`，677348字节。

对应完整source ZIP：`media_status_001_source.zip`，SHA-256 `91ded9ac8af991aecc97daa5f88ecac4295724460921fab93d608014b49eace4`。源码、报告、原始失败STA和只读复核均可复现；最终Git交付提交及文件清单见本轮交付manifest。

**本轮没有可推荐上板的新修复位流。** 明日若另行授权且只做一次最小硬件取证，可使用已有、原STA已通过的原NoBot：

`D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit`

SHA-256：`61874e4fcbbd83f1eea3010f54bd4804a411c46cf9f2d9203230d53cc38a2fc7`。

它不是修复，也预计可能仍黑；新增信息是**等待媒体启动后只读原有数码管的一个稳定状态码**（无需视频、OCR或五页抄录），并说明声音是提示音/静音/音乐。`A/C/D/E/F`这类错误码比再增删探针更能区分存储故障、响应错误、初始化失败和超时；非错误码因scanner/legacy复用不能过度解读。该结果只适用于原NoBot，不能直接替代B内部状态。

如需要恢复演示，只可在用户明确同意后恢复已实板PASS的完整Probe（`bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618`）。本轮没有执行任何恢复/下载。

状态诊断显示布局和判读保存在`STATUS_GUIDE.md`，仅供后续时序资格问题被解决后使用；不作为现在下载的许可。

## 8. 工程产物及停止点

- Windows独立工程：`D:\FPGA\EG4S20-NoBot-Fix-20261020\repo`，分支`codex/nobot-fix-20261020`，从RCA交付95de104派生。
- 两份经Root审核的DS报告/摘要：`axis/`、`media/`；所有短测试、失败查询、Root复跑/检查脚本保留。
- 工具/源码/产物SHA、最终routed DB、原始STA、补充分析及位流都留在Windows独立目录。
- 成功Probe冻结29项清单与原A/B位流再次核对不变。
- 停止点：根因仍未确认、新诊断STA未验收，**不猜测性改生产RTL、不继续追加位流、不硬件操作**。
