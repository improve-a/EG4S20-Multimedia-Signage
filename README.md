# 安路赛题一：HTML 分层展陈 FPGA 版本

目标为 HX4S20C / EG4S20BG256，顶层 `top`，使用 TD 6.2.1 Engineer build 168116。当前开发分支 `codex/html-fidelity` 将认可的六页 HTML 原型移植为离线 FPGA 展示，包括真实图层运动与透明混合、纹理 Bot、字幕/OSD、双图比较、局部放大及 PCM 音柱。

**e26ce11已通过full06综合、布局布线和位流生成；后续mA字幕单位修正正在做匹配full07。** 同域SD/内存/视频setup已转正，但跨域首级同步、hold/removal和约束覆盖仍未签核，TIMING为FAIL。最终六页/双图/放大显示链已通过，连续动作和交付记录正在收尾。实时进度见 [STATUS](docs/harness/STATUS.md)，证据见 [EVIDENCE](docs/harness/EVIDENCE.md)，按键、素材要求和明日验收见 [FINAL_REPORT](docs/harness/FINAL_REPORT.md)。本次没有操作开发板、JTAG、物理 TF 卡或串口。

## 当前工作区与目录

源码主工作区为 Windows `D:\FPGA\EG4S20-Multimedia-Signage`，Mac 目录用于本次传输和结果查看。历史 `hx4s20_extensions` / c16d3da 保持冻结。既有 `ssh thinkpad` 连接、工具路径和系统配置不变。

| 路径 | 用途 |
| --- | --- |
| `rtl/ext/`, `rtl/media_controls.v`, `rtl/display_commit.v` | 自研渲染、字幕、音频、参数控制与显示提交 |
| `project/` | TD 工程清单及继承的引脚/时序约束 |
| `scripts/`, `harness/`, `tests/` | 素材生成、集成回放、仿真及隔离构建 |
| `output/html_fidelity/media/` | 正式六张 HFXL BMP、07_MUSIC.WAV 和哈希清单；本地交付文件 |
| `output/html_fidelity/builds/` | 每次构建独立的 NTFS 源快照、日志和报告 |
| `output/html_fidelity/display_chain/` | 实际 DUT 帧、原型对照、差分及来源记录 |
| `docs/harness/` | 本次四份计划、状态、证据和验收报告 |
| `output/venue_unified_offline/` | 前一版公共场馆系统的历史成果，不能替代本分支结果 |

## 功能与限制

六页使用有限场景资源，背景采用精确 RGB 调色板，主图/文字图层读取实际 RGBA 纹理。Bot、字幕与参数叠加独立于底图局部 1×/2×/3×放大。双图比较使用两份独立产品资源。普通 BMP 路径保留输入自适应缩放；扫描容量八图，正式展示包是六页。

视频为 640×480，像素时钟 25 MHz，总时序 800×525，约 59.524 Hz。默认轮播间隔 5.4 秒，按 0.1 秒调节。实际按键及范围以 [验收报告](docs/harness/FINAL_REPORT.md) 为准。

音频为真实 WAV/PCM，音柱取自峰值/包络历史；没有 FFT、TTS 或页面语音。80 秒 PCM16/48 kHz 单声道音轨结束后保持静音。Bot 的纹理量化、仿射形变和固定点运动与原型仍有明确差异，报告中逐项说明，不给未经测量的还原百分比。

## 公开内容和本地依赖

公开仓库仅包含可确认的自研源码、测试、生成器、配置和最小集成补丁。官方/派生顶层、存储链路、生成及加密 IP、厂商模型、位流、未获再分发许可的完整素材不随仓库公开。首次克隆不能直接整机综合；先按 [依赖说明](docs/DEPENDENCIES.md) 补齐 [精确本地依赖](docs/local_dependencies.json)。原件与公开历史不修改。

`scripts/apply_html_integration.py`、`apply_html_sd_controller.py`、`apply_html_memory_controller.py` 对校验通过的本地原件应用最小集成修改，拒绝未知内容并支持重复运行。自研模块不替代官方 IP。生成的本地资产及其许可/来源记录也必须补齐；Git 源码包不等于已完整封装的可综合工程。

## 构建和验证

只在 Windows 主仓库启动明确的一次构建，脚本生成干净、唯一的 NTFS 快照，不在源码目录或 Google Drive 构建。示例命令会真正启动工具，按实际授权使用：

```powershell
D:\python3.12.3\python.exe scripts/build.py launch replay_YYYYMMDD_01 --timeout 1800
D:\python3.12.3\python.exe scripts/build.py status replay_YYYYMMDD_01
```

工具为 `G:\anlu\bin\td_commands_prompt.exe`。生成的 GUI 工程位于 `output\html_fidelity\builds\<run_id>\work\design\td_project\hx4s20_basic.al`。每次保留源码 SHA256、工具身份、PID、阶段状态、退出码、耗时与报告来源。综合诊断不能代替完整布局布线/位流，历史成功不能代替之后修改的验证。

模块/组件测试、完整系统仿真、SYN、PNR、STA、BITGEN 和硬件状态分别报告。加密 SDRAM/HDMI IP 全系统仿真和本版本硬件均未验证。当前资源与时序限制见 STATUS；不通过添加无依据的例外制造 STA_PASS。

## 初始化资源复核

当前数值ROM包括眼睛半径表和OSD参数字形表。`html_osd_utility_rom.py`保留现有576字节颜色表，再装入RTL原有24个5×7参数字符；它不替换正文中文字形。正文继续使用实际用字覆盖率图集。

在已补齐本地素材的工作区，可把以下结果生成到独立输出目录并与当前HEX/BIN哈希比较；这两条命令不会修改RTL：

```powershell
D:\python3.12.3\python.exe scripts/html_bot_eye_radius.py --output-dir output/html_fidelity/numeric_replay
D:\python3.12.3\python.exe scripts/html_osd_utility_rom.py --output-dir output/html_fidelity/numeric_replay
```

完整资源生成顺序是素材/字形与caption columns、scene/layer数值表、OSD颜色表、上述OSD共享字体表，最后运行 `scripts/html_rom_init.py` 逐字校验HEX并导出TD使用的明确位宽二进制初始化文本。不要把早期结构实验用的 `html_bot_eye_tables.py` 当作当前眼睛ROM的再生入口。构建快照必须同时保留仿真HEX和TD BIN，证据见 `output/html_fidelity/audit/rom_init_current_wording_v1.json`。

后台读写压力使用真实511容量FIFO与Gray CDC，复现命令如下。该测试采用40MHz存储/25MHz视频/100MHz源时钟、四字物理组及有界刷新/返回延时；不替代加密SDRAM PHY或实板验证。默认旧参数保留用于历史反例，不能把它当当前顶层配置。

```powershell
D:\python3.12.3\python.exe -X utf8 scripts/html_layer_render_verify.py --whole-bridge --writer-stress --real-fifo --read-burst 128 --transition-age 25 --write-reserve 384 --case phoenix --run-id layer_final_real_fifo_phi25_v1
```

当前顶层明确启用物理读排空/写入准入，读burst128、写burst256，显示FIFO达到384字后才锁定后台写入。完整busy继续用于帧握手与flush，新增physical_busy只表示已经发送且尚未完成的读取。每次复现使用新的run-id。

## 素材与后续实板验收

只使用 `output/html_fidelity/media/` 的 UI01.BMP 至 UI06.BMP 与 07_MUSIC.WAV。BMP 含原生图像及标识明确的 HFXL/HFXC 尾部资源，不能重编码、裁剪头或删除尾部。读取器扫描前 64 MiB 的物理文件头，不按 FAT 文件名排序；要求连续存储、正确物理发现顺序和无残留旧头。普通复制顺序不能证明卡布局。

离线 `.img` 是普通测试文件，不能当素材文件复制入卡；其中模拟 LBA 也不是物理卡证据。只读检查器为 `scripts/html_inspect_card.py`。任何写卡、烧录或实板测试另行授权；明日验收顺序已列入 FINAL_REPORT。

## Git 和历史证据

所有修改在 `codex/html-fidelity` 分支，正常提交并在收尾尝试正常推送，不强推或合并 main。当前推送尚未执行；历史认证失败不能当作本次结果。保留历史 [统一版报告](output/venue_unified_offline/FINAL_REPORT.md)，其中历史 LUT、时序和实板观察不适用于当前分层版本。

已有 Noto Sans SC 的 SIL OFL 1.1 和合成音频 CC0 声明继续随原包保留。不擅自为其他来源代码或图片补写许可证，公开可读不等于获得再分发许可。

正式字幕还包含一处局部事实措辞修正：mA对应静态电流，不是静态功耗。`html_caption_coverage.py --correct-current --layout <原darkpaper布局> --map <原228字形map> --css <原CSS路径> --out <独立输出目录>` 保留既有字形ID并追加“流”228，仅修改Eagle两个字符；之后生成caption columns和15份BIN。原输入和修正输出均保留本地，系统字体不发布。当前字模229字形/9160word，仍使用5个32K块。
