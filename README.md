# 基于国产 FPGA 的公共场馆多媒体信息发布与应急引导系统

**EG4S20 Multimedia Signage and Emergency Guidance System**  
2026 FPGA 创新设计竞赛安路赛题一；HX4S20C / EG4S20BG256。

面向展馆、校园和公共场馆的 TF 卡图片、字幕与 HDMI 音频演示系统。
六页“场序 / VENUE FLOW”界面提供日常信息和模拟应急疏散展示；地图为虚构示意，
页面切换由按键控制，没有接入真实告警传感器。音乐与页面模式独立播放。

## 公开内容与工程来源

本仓库从完整工程 `c16d3da56c8ae175f675c112cfdd4bdc5f2c0fb6` 整理为独立 `main` 历史。
旧工程和全部提交在本地保留。**公开版本仅含可确认的自研模块、测试、工程配置及素材；
官方源码、由官方修改的集成顶层/存储链路、生成 IP 和 TD 仿真模型不随仓库分发。**
首次克隆不能直接完成整机综合，需按 [本地依赖说明](docs/DEPENDENCIES.md) 补齐精确版本。
文件范围和 SHA256 分别见 [导入清单](docs/import_manifest.json) 和
[本地依赖清单](docs/local_dependencies.json)。不能把旧库历史或完整源码 ZIP 推到 Public 仓库。

## 硬件、工具与架构

| 项目 | 配置 |
|---|---|
| 开发板 / 芯片 / 顶层 | HX4S20C / EG4S20BG256 / `top` |
| FPGA 工具 | 安路 TD 6.2.1 Engineer build 168116；Windows NTFS 工作区 |
| 视频 | HDMI，640×480，25 MHz 像素时钟，800×525 总时序，约 59.524 Hz |
| 存储 | TF 卡 SPI 扇区读取，SDRAM 双帧缓存，后台加载与显示提交握手 |
| 音频 | TF WAV → PCM FIFO/播放 → HDMI；PCM 波形和峰值可视化 |
| 控制 | KEY1 逻辑复位；KEY2/3/4 播放与参数操作 |
| 开发环境 | Mac 管理源码；已有 `ssh thinkpad`；Windows Python 3.12.3 / Icarus |
| UI 生成 | Python 标准库、macOS Swift / AppKit / CoreGraphics；无需安装字体 |

```text
TF SPI → BMP 扇区扫描/解码/整数缩放 → SDRAM 后台帧 → 提交握手 → 前台帧
                                                        ↓
                                        转场 / 亮度对比度 / OSD → HDMI
TF SPI → 扇区仲裁 → WAV 解析 → PCM FIFO → 音量/静音 → HDMI 音频 + 可视化
按键 → 播放/内容分组/参数 → 帧边界配置快照
```

## 现有功能与边界

- BMP24 BI_RGB 正高度图片读取、双帧缓存、手动切图、自动轮播、暂停/恢复。
- 字模 OSD、标题、滚动字幕、进度条与状态；亮度、对比度、轮播间隔实时调整。
- 最近邻整数 1×/2×、保持比例居中与黑边；擦除/右滑经过黑场切换。
  没有任意比例缩放、双线性插值或双帧淡化。
- WAV PCM16、48 kHz、单/双声道；音量、静音、暂停、EOF 静音；可视化取自实际 PCM。
  音频不随日常/应急模式切换重播，没有页面联动音效、自动 EOF 循环或 FFT。
- 扫描表容量八张；当前六页产品分组为日常 UI01/UI02、应急 UI03–UI06。
  额外位置 6/7 不参与六页分组；没有已验证的并排双图显示功能。

PLAY 页 KEY2 短按松开切下一页，长按约 1 秒切日常/应急；忙时等待当前加载/提交完成。
KEY3 短按暂停、长按静音；KEY4 短按轮播或参数减值、长按循环操作页
`PLAY→BRIT→CONT→TIME→OSD→TRAN→ZOOM→VOL`。参数页 KEY2 为增加/切换参数。
KEY1 为逻辑复位；CONFIG1 / PROGRAM_B 会清除易失配置，两者不要混用。

## 目录

| 路径 | 用途 |
|---|---|
| `rtl/ext/` | 自研 OSD、像素调整、缩放、转场、WAV/PCM、仲裁、配置跨域与可视化 |
| `rtl/{media_controls,display_commit,reset_sync}.v` | 控制、显示提交和复位同步 |
| `project/` | TD 工程清单、引脚与时序约束；项目路径在快照准备时重定位 |
| `tests/`, `tb/` | 模块/组件 testbench、可复现向量、测试说明；厂商模型除外 |
| `scripts/`, `harness/` | 素材、仿真、隔离构建和报告脚本 |
| `output/venue_emergency_ui/assets/`, `scripts/` | 原始六页 UI、场景文本、字体许可与生成器 |
| `output/venue_emergency_ui/tf_card_package/` | 历史 A/B/C 单独演示包及 canonical 媒体 |
| `output/venue_unified_offline/media/` | 当前六页统一素材与 SHA256 清单 |
| `output/venue_unified_offline/validation/` | 已有统一版构建报告、测试结果、时序覆盖说明 |
| `docs/` | 来源、依赖和本次发布 PLAN / STATUS / EVIDENCE |

`output/` 中上述内容是保留的工程成果，不是可以整体忽略的缓存目录。
旧单独 A/B/C 包描述其历史部署方式，当前六页统一版以本 README 和
`output/venue_unified_offline/README.md` 为准。

## 打开与构建 TD 工程

先补齐依赖并运行 `python3 scripts/local_dependencies.py --check`。
源码库使用精简布局；**不要直接打开库内 `.al` 后在原处构建**，它的 HDL 相对路径对应
由脚本生成的完整 TD 目录。使用唯一 run ID 建立 Windows NTFS 快照：

```sh
# 会启动一次完整 TD 构建；仅在实际需要构建时执行。
python3 scripts/build.py launch replay_YYYYMMDD_01 --timeout 1800
python3 scripts/build.py status replay_YYYYMMDD_01
# 完成后收集，再审阅数值和约束覆盖。
python3 scripts/build.py collect replay_YYYYMMDD_01
python3 scripts/summarize_build.py replay_YYYYMMDD_01
```

脚本使用既有 `thinkpad`、`D:\python3.12.3\python.exe` 和
`G:\anlu\bin\td_commands_prompt.exe`。路径需与现有环境一致，不修改系统 PATH。
生成的 GUI 工程为
`D:\FPGA\hx4s20_extensions_20261013\builds\<run_id>\work\design\td_project\hx4s20_basic.al`。
仅准备快照/打开 GUI 的步骤见 [依赖说明](docs/DEPENDENCIES.md)。
每次新快照保留输入哈希、工具身份、PID、退出码、阶段状态与耗时；不复用旧报告作为新结果。

定向测试配方见 [统一版验证说明](tests/unified_media_notes.md)。部分自研单元测试无需官方依赖，
例如 `pixel_tb`；整合测试需清单内的本地存储/顶层等依赖。

## TF 卡素材与部署

```sh
python3 scripts/package_unified_offline.py --validate-only
# 需要重新生成全部 UI 时（Mac）：
python3 output/venue_emergency_ui/scripts/rebuild_assets.py
python3 scripts/package_unified_offline.py
```

当前素材：六张 640×480、24 位、BI_RGB、正高度 BMP；一个 80 秒 PCM16/48 kHz
单声道 `07_MUSIC.WAV`，最后一秒静音、EOF 后保持静音。硬件支持尺寸 1..640 × 1..480。
文件必须扇区对齐且物理连续；读取器扫描 **LBA 0..131071（前 64 MiB）** 的文件头，
忽略 FAT 目录与文件名，找到头后可以继续读取范围外的数据。
六图需依物理发现顺序 UI01–UI06，对应日常 0–1、应急 2–5；目标扫描数八张，
仅六张时会扫到范围末端才显示首图。文件名和普通复制顺序均不能证明实际 LBA 顺序。

后续经授权部署时：备份原卡 → 普通文件复制当前 `media/` 中的六 BMP 和 WAV →
只读审计连续簇链、双 FAT、发现顺序、残留头和物理回读哈希 → 加载对应位流 → 实板验收。
不要把历史 A/B/C 包和统一包混放，不要将原始扇区镜像当普通素材文件复制。
本次 Git 发布没有写卡、加载位流或重新上板。

## 验证状态（历史证据，非本次新构建）

| 范围 | 核实结果 |
|---|---|
| 当前统一版模块/组件仿真 | 16 项配置 PASS；含六/八图扫描、分组控制、真实 UI06 的 307200 像素比对和 WAV 修复回归 |
| SYN / PNR / BITGEN | `unified_full_20261014_02` PASS，exit 0，369.281 秒 |
| 静态时序 | 已报告 routed Slow/Fast setup +0.120 ns、hold +0.011 ns；TNS 0，覆盖 99.93% |
| 资源 | LUT 9482/19600（48.38%）；BRAM 35/64（54.69%）；FF 5804/19600 |
| 完整约束签核 | 未宣称；继承的时钟及外部 IO 延迟覆盖限制保留，无新增时序例外 |
| 加密 IP 全系统仿真 | NOT_TESTED |
| 当前统一版 TF 物理布局 / 实板 | NOT_TESTED，需重新上板验收 |
| 历史 `94051b8` / ext_full_005 | setup +0.140 ns、hold +0.003 ns、LUT 46.74%、BRAM 54.69%；不能替代新版结果 |

历史旧版有用户目视/听音确认的切图、轮播、字幕、缩放、转场和音频功能记录，
不是当前六页统一版的硬件验收；30 分钟稳定性由用户提前终止，仍未通过。
完整原始实板证据保留在旧工程，不公开卡备份、磁盘镜像、设备序列号或个人操作记录。

最新构建输入来自 `d812c8a`，交付记录提交 `c16d3da`。详细报告为
[统一版报告](output/venue_unified_offline/FINAL_REPORT.md) 与
[状态](output/venue_unified_offline/STATUS.json)。历史位流 SHA256
`9fc30a0efa894872571f85f4155a2d2edc82b630c5b60fc43b3d5f14c735b446`，
在原工程保留；本仓库不分发包含官方 IP 的位流或源码归档。

## 后续 Git 工作流

本 Mac 仓库是后续源码主目录，旧 `hx4s20_extensions` 留作冻结来源；不要在两边并行开发。
Windows 的裸仓库只中转提交，没有第二份工作分支或工作区。

```sh
git pull --ff-only origin main
# 修改自研源码、测试、文档后检查文件范围；不要使用 git add -f 添加本地依赖。
git status --short
git add <明确要提交的路径>
git commit -m "描述具体改动"
python3 scripts/push_via_thinkpad.py
```

推送脚本用 Git bundle 经已有 SSH 传输到 Windows，复用现有 Git Credential Manager
向 HTTPS 远端推送，并回查远端 SHA。不复制或输出凭据，不强推。
公开仓库的 `git pull` / `git fetch` 可由 Mac 直接使用 HTTPS；有冲突时保留双方提交并处理，
不执行 `reset --hard`。本地依赖被逐文件忽略，仍需随工程变更更新本地哈希清单。

字体 Noto Sans SC 按随包 SIL OFL 1.1 分发；程序合成音频的已有 CC0 声明随包保留。
本次未为其他代码擅自增加开源许可证，公开可读不等于授予未声明的再分发许可。
