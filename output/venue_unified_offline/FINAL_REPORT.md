# 六页 Unified 离线交付报告

2026-10-14 UTC。本轮 Offline Only 已完成。工程目标沿用本仓库 AGENTS.md：
HX4S20C / EG4S20BG256 / top `top`，不是父目录的 HX1P35A 项目。
没有执行 TF 检测、挂载、写卡、JTAG 识别/下载或实板观察。

| 项目 | 最终状态 |
|---|---|
| RTL | PASS |
| SIM | PASS：16 项定向模块/组件配置 |
| TD_BUILD | PASS |
| BITSTREAM | GENERATED |
| MEDIA_PACKAGE | PASS_OFFLINE |
| TF_CARD_PHYSICAL | NOT_TESTED |
| HARDWARE | NOT_TESTED |

独立阶段：SYN PASS、PNR PASS、BITGEN PASS；STA 的已报告路径 setup/hold 均通过，
但存在继承的约束覆盖限制，不能当作完整约束签核。FULL_SYSTEM_SIM 为 NOT_TESTED。

## 实现与使用

BMP 计数扩展为 4 位、图像索引 3 位、八项地址表；帧缓存索引保持原位宽。
生产顶层启用分组：日常 UI01/UI02，应急 UI03–UI06；手动和自动轮播只在组内循环。
PLAY 页 KEY2 短按松开翻页，长按约 1 秒切换模式，只触发一次且松开不再翻页。
参数页 KEY2 加值与 KEY3、KEY4 原功能保留。忙时切换先完成当前缓存提交确认，
再加载最新目标组首图，避免改写显示中的缓存。

WAV 保持独立播放，不随模式切换重播。首次构建暴露原 WAV 头长度检查路径 setup
负裕量，将边界计算提前到倒数第二个已接收头字节缓存，接口、状态和字节接收延迟不变。
源文件差异及 SHA256 在 `validation/source_scope.json`。引脚、PLL、时钟/复位、
SD 传输、SDRAM、HDMI 和加密 IP 保持不变，没有新增时序例外。

扫描目标为 8，因此六图素材会扫描到原有 LBA 0–131071 范围末端再加载首图。
文件必须在卡上物理连续，播放按物理发现顺序；文件名和离线清单不能证明物理顺序。
完整按键行为、OSD、音频及部署边界见 `README.md`。

## 实际仿真

最终计数的 16 项均已在现有 Windows Icarus 上执行，输入 SHA256 与最终源码一致：

- control_media_tb、content_modes_tb、scale_reload_tb：长短按互斥、组内手动/自动轮播、
  忙时模式切换、连续切换、缓存拥有权和显示提交。
- unified_storage_tb 两配置：legacy/scaled 各验证六图扫描结束和八图容量。
- unified_ui06_tb：真实 UI06 的 307200 像素全部逐点比对，1802 次扇区请求，
  9343790 周期；含字节间隔、写入确认和中途模式值变化。
- control_modes_tb、control_storage_tb、config_bridge_tb、transition_commit_tb、
  scale_scan_tb、scale_reject_tb、scale_scan_load_tb：受影响现有回归。
- wav_tb、audio_media_tb、video_audio_integration_tb：时序修复后的边界与联合回归；
  后者检查两帧 VGA / 614400 像素和 2082 个真实解析 PCM 帧。

UI06 首次 120 秒运行超时，保留原记录；同源 600 秒上限重跑实际 335.485 秒通过。
首次联合视频/音频通过记录也保留，但最终采用 WAV 修复后的 177.875 秒重跑结果。
存储响应和部分端点使用行为模型，没有加密 IP 全系统仿真或实板验证。
清单、输入哈希、命令、PID、退出码和日志见 `validation/simulation_summary.json`
及 `validation/sim/`。复现命令见仓库 `tests/unified_media_notes.md`。

## TD 构建与时序

通过现有 SSH `thinkpad`，在 Windows NTFS 的独立快照目录运行
`G:\anlu\bin\td_commands_prompt.exe`，TD 6.2.168116。
工具 SHA256：`e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a`。

| 本轮运行 | 结果 | setup WNS | hold WNS | 墙钟时间 |
|---|---|---:|---:|---:|
| unified_full_20261014_01 | 流程完成；时序不通过，不交付该位流 | −0.317 ns | +0.003 ns | 379.907 s |
| unified_full_20261014_02 | SYN/PNR/STA报告/BITGEN 完成，exit 0 | +0.120 ns | +0.011 ns | 369.281 s |

共 2 次完整构建，累计 749.188 秒，未超过 3 次 / 5400 秒上限。
第一次五个负 setup 端点均来自 WAV chunk 边界串联算术；第二次局部计算缓存修复后
setup/hold TNS 均为 0，Slow/Fast 两角均检查，Confidence Routed，覆盖率 99.93%。
最终最差 setup 路径已变为 SD 域复位到 WAV FIFO RAM 写使能。

资源：LUT 9482/19600（48.38%）、寄存器 5804/19600（29.61%）、
BRAM 35/64（54.69%）、DSP 8/29（27.59%）、PLL 2/4（50%）。

约束审阅：四项 local/generated-master clock、五项无输入延迟、二十项无输出延迟、
一项部分输入延迟、三十二项异常输入延迟以及 dummy-node 类别与历史基线相同。
继承 FIFO IP 的 hold 例外不变；没有新增例外。无 no-clock、无效约束、组合环、
无路径约束诊断。这里只确认已报告路径数值通过，不声明剩余 IO/跨域约束已完整签核。
见 `validation/timing_review.json`；历史报告仅用于警告对照，不充当本轮证据。

最终源码提交 `d812c8a`；特性提交 `6470652`。第二次快照含 75 个源码/工程输入文件，
快照 SHA256：`b9c5123ccf5f4add089e5567585ed1e888b67da028be07e2896dd3d8d10a330d`。
TD PID 21528，supervisor PID 43196，运行 2026-10-14 15:55:34–16:01:43 UTC。
Windows 日志采用本机时区，显示 2026-10-15 00:01 左右，与 UTC 记录对应。
`validation/builds/` 保存两次运行报告、日志、Tcl、来源清单与状态。
Supervisor 的 attempt_number 为共享历史计数 11；本轮次数以独立预算记录 2 次为准。

## 交付文件

- `hx4s20_unified.bit`：633116 字节，第二次快照新生成，下载后 SHA 与 supervisor 一致。
  SHA256 `9fc30a0efa894872571f85f4155a2d2edc82b630c5b60fc43b3d5f14c735b446`。
- `unified_media.zip`：6389442 字节；解压内容与 `media/` 字节一致。
  SHA256 `ba989bd0b08cfb387a7132d9e7ffee473679e8449b9f2ac73ada5d266efffc8a`。
- `media/`：UI01.BMP–UI06.BMP 六张不同的 640×480 BMP24 BI_RGB、
  07_MUSIC.WAV（PCM16、单声道、48 kHz、80 秒，末尾一秒静音，播放结束静音）。
  源文件一致性、格式、长度、内容哈希、顺序清单、SHA256SUMS 和 ZIP 往返检查通过。
- `STATUS.json`、`validation/`、`DELIVERY_SHA256SUMS`：机器可读状态和证据。

本轮没有修改或验证真实 TF 卡。物理连续性、扫描顺序、卡上残留数据和新版实板表现
均留待后续实卡验收，不继承上一版硬件结论。所有代码、媒体和交付证据在
`codex/unified-offline` 分支提交；最终交付提交可由该分支 Git 日志定位。
