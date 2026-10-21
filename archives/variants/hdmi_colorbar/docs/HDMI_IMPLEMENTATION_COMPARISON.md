# HDMI_IMPLEMENTATION_COMPARISON

2026-10-19 离线审查结论：**黑屏、无声的确定根因仍未找到**。同卡、同 HDMI_B、同供电条件下，新版 TD004 黑屏无声，历史 ext_full_005 恢复画面和声音，是既有实板 A/B 事实；以下离线 PASS 不等于实板修复成功。本文件记录原新版与历史基线的比较，不把正在准备的彩条诊断版视为修复。

## 比较对象及证据

历史源码：`D:\FPGA\hx4s20_extensions_20261013\builds\ext_full_005\work\design\user_source\hdl_source`。新版冻结源码：`D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source`。

历史 mapped SHA256：`87bb1cba7edc820e853f6458adc89e192f75c8a58d8cb3598ad7f0bb7bd9ca34`；新版 mapped：`36edbd1af5b40b4c0ade94c00ccb18408a9f9a5abff75afb9bfae30360a4d10d`。原始审查保留于 `D:\FPGA\EG4S20-NoBot-HWFix\output\offline_debug\astra_hdmi_phase`，本文件 receipt 列出引用文件的绝对路径和 SHA256。

## 确认存在的差异

| 项目 | 实际差异及判断 |
|---|---|
| 上游集成 | 新 top 使用 HTML overlay、legacy_exhibit_media/loader、12 位 view 提交与 51 位配置、更新的加载/缩放/提交连接和 WAV EOF 自动重启。它们是实质改动，不能以“显示状态在循环”认定像素正常。 |
| 视频流水 | 旧 video_extensions 4 拍，新 html_video_overlay 6 拍，增加 2 个像素时钟（80ns）。局部映射控制实验不支持“完整流平移 2 拍导致持续失锁/丢写”这一解释；不是全系统物理时序证明。 |
| reset_sync | 增加 `preserve="true"` 属性，异步置位、同步释放的 RTL 逻辑未变。映射中检查的 HDMI clock/reset 连接保持对应。 |
| 约束 | pin.adc 和 edid_debug.cwc 同 SHA；SDC 新增针对 6 条 resetSync 的 removal/hold 例外。例外改变时序分析覆盖，不能作为行为修复或自行证明时序安全。 |
| 工程配置 | 去除源文件清单后的完整非 File 配置比较，唯一差异为新增 `UCode=10011110`；ERAM init、default_reg_initial、gated_clock_conversion 配置一致。 |
| 布局打包 | 5 个寄存器由 LSLICE F 改用 MSLICE FX；规范化输入后共 8320 个真值表组合零差异。物理位置、布线和延迟并未据此证明一致。 |

共同文件集合中 57 个同 SHA、11 个不同；不是整个工程只改了 11 个文件，新增加的文件另计。11 个为 display_commit、media_controls、reset_sync、top_tf_hdmi_audio、audio_media、bmp_scale、video_transition、wav_stream_parser、bmp_read、frame_read_write、sd_card_bmp。

## HDMI、音频和 IP 配置无新增差异的范围

- HDMI 加密 wrapper、PHY、lane_lvds_10_1、PLL 源码/生成文件、video timing/delay、RGB→AXIS 文件均同 SHA。冻结 HDMI 目录仅有同一个加密 wrapper；本审查核对实际实例参数，没有重新生成 IP，也没有解密证明内部行为。
- HDMI core 整个参数和端口实例文本一致：EG、RGB、VIC=1、640×480，H=800/96/16/48、V=525/2/10/33，TPG Disable、音频 48K、IIC divider=250。pixel clock/reset、AXIS user/valid/last/data、音频 valid/24 位左右声道、20 位 ACR CTS/N 及 ACR valid 接线一致。
- tone 为 25MHz/48kHz；ACR_N=6144；tone、ACR、audio_output_mux 实例及模块同源，audio_pcm_player、audio_async_fifo 同 SHA。mux 持续使用 tone_valid 作为采样节拍，WAV 选择与上游数据状态仍是独立行为边界；接口相同不代表实板一定有有效 PCM。
- HDMI 合流→三个 TMDS encoder→PHY 的 505 个命名寄存器集合一致；逐位核对的 clock/CE/reset/FF 配置一致，306 个直接 MI 数据输入一致。pixel clock 的 video_clk / extensions/osd/clk 只是同一 PLL GCLK 输出的网名差异；不同 core-reset dup 均追到相同两级同步释放结构。未做全部组合逻辑的全网表形式等价证明。
- 四路 TMDS PAD 的模式、位序、serial clock、reset 完全一致；实际视频 PLL 参数及已连接端口一致。
- 视频 FIFO 三片 BRAM 的 DP8K、9-bit A/B、NOREG、SYNC reset、NORMAL write 参数及控制/地址端口一致；两版均未连接 bea/beb。24 位 payload 位序完整一致，RAM 至合流输出的 6×24 个直接流水寄存器数据和控制连接一致。
- mapped 中 TLAST 已优化掉，接收控制没有遗漏一个由 TLAST 参与的状态反馈。已审查 source SOF/SOL、active/read-enable、pause/locked 控制连接；未发现为 +2 拍另加补偿 FSM 的依据。继承的 SDRAM undriven 告警也不能单独认定新版根因。

## 已完成验证及尚未排除的边界

实际原版 top 的 `actual_top_boot_05` 已自然完成，exit=0：307200 写像素、一次提交、一帧 HDMI 输入；非 OSD 区 253620 像素逐像素匹配，整帧 13659 种颜色。音频核对 247 个真实 WAV PCM 样本、8402 个 audio_valid（520/521 拍节拍）、175 次 ACR，观察到非零 HDMI 输入 WAV。模拟结束 195.042821ms。最终依据为 `actual_top_input_verification.json`；较早 video_input_receipt 中 RUNNING/音频 pending 字样是历史中间状态。

局部 receiver 控制测试比较旧/新相位：完成的 40000 拍窗口内，写阻塞 0、锁丢失 0、最大占用 10，逐拍比较无差异。其范围是约 1.6ms 启动窗口；不能写成完整帧或完整加密 HDMI 核动态验证。

仍未排除：模型替代的实体 TF/SDRAM/PLL 行为与实际时钟/复位启动、完整加密 HDMI 内部及音频打包行为、实际映射/布线时序和 TMDS 串行输出、长期运行及 WAV EOF/自动重启（本例 EOF=0）。这些是覆盖缺口，不是已定位故障；不推断芯片损坏或 SDRAM 架构错误。独立分支的彩条诊断沿用现有音频输入，音频结果独立记录；只用于划分故障边界。

| 状态 | 本次审查含义 |
|---|---|
| OFFLINE_BUILD | 本审查未运行新 TD；历史导出和既有构建不冒充本次诊断版构建。 |
| TIMING | 未重新签核 STA；静态一致不替代 setup/hold、跨时钟和实际布线检查。 |
| RTL_REGRESSION | 既有针对性检查与 actual-top 输入测试 PASS；未声称全面回归。 |
| VIDEO_PATH_SIMULATION | 实际 top 至 HDMI 输入的一帧 PASS；加密核/PHY 全路径未验证。 |
| AUDIO_PATH_SIMULATION | 实际 WAV 至 HDMI 输入及采样/ACR 检查 PASS；EOF/重启和 HDMI 音频输出未验证。 |
| HARDWARE_NOT_TESTED | 本轮没有硬件操作；保留既有 A/B 事实，未宣称修复验证完成。 |
