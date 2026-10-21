# 无 Bot 黑屏故障离线分析（收尾）

本轮仅离线。历史硬件 A/B 显示：6ee7c70 对应 004 位流黑屏无声，ext_full_005 同卡同 HDMI_B 恢复画面和声音。该事实支持集成回归优先级，但尚未定位具体 RTL 根因。

隔离工作树：D:\FPGA\EG4S20-NoBot-HWFix；分支 codex/no-bot-hw-fix-20261019，起点 17ac5f26acb120b4ed0055010d913bf4bcd9b50e。原始 6ee7c70、17ac5f2、ext_full_005 源码、DB 和成功位流均保留。当前生产 RTL 未改，未启动新的综合、布局布线或位流生成。

## 已证伪或未见支持的候选

| 候选 | 实际证据及边界 |
|---|---|
| 新 OSD 破坏有效区/VS/SOF/TLAST | 实际尾部 RTL 原生两帧、960 行协议检查通过；该例不是加载至 HDMI 的全顶层。 |
| AXIS 数据被常量化或断开 | mapped 24 个有效数据位及 valid/user 均有真实寄存器驱动到视频 FIFO。 |
| 新 OSD 多两拍使 HDMI 持续失锁 | 实际 LUT 接收控制模型：17 相位、每例 3 帧无失锁；含 FIFO 控制的 40000 时钟有界例旧新对齐一致、无满丢写，负对照恰在 1024 写满后禁止继续写。该结果不是完整 HDMI IP 仿真。 |
| 输出时钟/管脚/PHY 模式改变 | 旧新 PNR 时钟和管脚报告对应一致；实际 mapped 视频 PLL 和四 lane PAD/数据位序/时钟复位一致。 |
| 视频 FIFO 至 TMDS 输出新增实现断连 | 3 片 BRAM 的参数/连接/24bit 位序一致；144 个后续流水数据位对应。合流至编码/PHY 的 505 个命名寄存器控制配置、306 个直接数据输入一致；5 处 LUT 打包差异以 8320 输入组合检查，零差异。未证明所有其余网表逻辑全局等价或物理串行输出。 |

主要证据在 output/offline_debug/astra_hdmi_phase/：review.md、fanin_followup.md、output_chain_review.md、three_bram_review.md 及各自 JSON 收据。历史 ext_full_005 DB 的只读导出保存在 output/offline_debug/baseline_mapped_export/；没有改写历史 DB，没有重跑历史工程。

## 当前关键验证

actual_top_boot_05 从真实交付 FAT 镜像读取扇区；使用实际 top、目录扫描、媒体加载器、顺序读写 FIFO、提交、转场、OSD、AXIS、WAV 解析与播放路径。只替换外部/受保护叶：PLL、SD 卡扇区源、SDRAM 存储和 HDMI/PHY。SDRAM 由实际 App_wr 写入，初值 deadbeef，不预填期望像素；读响应有序延迟 10 个 mem_clk，包含刷新阻塞。保持实际 100/40/25MHz 时钟、20ms 复位和 800×525 光栅；卡字节传送有明确加速。

已执行：扫描 10 个 BMP，307200 个真实写入字逐一匹配原始交付 BMP 的默认 2× 采样参考，101.053538ms 写入完成、104.29026ms 实际提交 ACK、137.8899ms 遮罩解除。139.01682–154.37038ms 捕获实际 HDMI 输入首个完整 640×480 帧：307200 像素均非零，253620 个非 OSD 底图像素由独立 Python 再比对零差异；13659 种 RGB 颜色，亮度范围 8–246。真实 FIFO→video_delay 像素和 AXIS 标记断言通过。video_input_receipt.json、actual_hdmi_image_metrics.json 和原始 PPM/PNG 均保存在 actual_top_boot_05。该结论严格截止于 HDMI 输入。同一个 actualtop05 于 195.042821ms 自然通过：原始 WAV 前 247 个 PCM 逐样本正确，HDMI 输入观察到首次 WAV 非零数据；8402 次 audio_valid 符合 520/521 pixelclk 节拍，175 次 ACR 的 N=6144、CTS≈25000。VVP exit0，墙钟 3827.062s。EOF/restart=0，本例未覆盖文件末尾、自动重播、完整加密 HDMI 音频包。

另一例只扩展 existing legacy_exhibit_loader_tb 的字节间隔/超时参数：按实际 SPI 70 sysclk/byte 核对默认整图，307200 像素全部匹配，1081 扇区，44576914 sysclk；负对照 MODE13 正确拒绝断包(error2)。两个 vvp 均 exit0；外层 SSH 收尾异常已单独记录，不替代仿真退出码。该用例仅反驳默认加载器的字节间隔依赖，未模拟命令/token/CRC或完整SPI。

HDMI 受保护核心的完整音频包、TMDS 符号和物理串行输出尚未仿真，不得写为端到端音视频 PASS。实际 RTL 预览此前仅到叠加器输出，本轮测试扩展到真实顶层 HDMI 输入，仍不跨越受保护 HDMI/PHY 边界。

## 尚未闭合

尚未复现此次实板黑屏/无声，没有确认可行动的生产 RTL 根因。不会为生成新位流而加入猜测性的 ready 适配、复位层、看门狗或状态机。两个有界试验现已收尾，停止扩展媒体/多页/长循环验证。根据用户新授权，改在独立 codex/no-bot-hdmi-colorbar-20261019 分支制作仅替换适配层像素源的诊断位流；本分支生产 RTL 保持不变，不把未复现当作修复。

| 状态 | 本分支结果 |
|---|---|
| OFFLINE_BUILD | NOT_RUN：没有生产修复，不重复构建原失败版本 |
| TIMING | NOT_RUN：不复用历史 STA 冒充新结果 |
| RTL_REGRESSION | SCOPED_PASS：上述启动路径与 SPI 字节间隔正负例 |
| VIDEO_PATH_SIMULATION | PASS_TO_HDMI_INPUT：外部/受保护叶建模，不是物理 HDMI PASS |
| AUDIO_PATH_SIMULATION | PASS_TO_HDMI_INPUT：真实 WAV 首次非零、节拍、ACR；未覆盖 EOF/自动循环/包编码 |
| HARDWARE_NOT_TESTED | 本轮严格离线；历史原无 Bot 位流仍为失败状态 |

未排除的具体边界：实际 SPI/SDRAM 叶与行为模型的时序差异；新增加载器/OSD 从 RTL 到 TD 推断 RAM/门级实现的动态语义；受保护 HDMI 核心、真实时钟/复位分发及 TMDS/PHY 串行输出。现有静态网表对照没有发现可行动差异，也没有据此认定 SDRAM 架构故障。仿真时间中的 SD 字节传输已加速，104ms 提交不是实板加载时间；70clk/byte 用例的 445.769ms 也不包含命令/token/CRC。首帧案例不等同于已完成多页切换或实板转场验收。
