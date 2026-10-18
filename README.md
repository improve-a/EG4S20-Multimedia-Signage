# 安路赛题一：无 Bot 商业展陈

目标为 HX4S20C / EG4S20BG256，顶层 `top`，工具 TD 6.2.1 Engineer build 168116。当前分支 `codex/no-bot-legacy-integration` 采用已核对源码、位流和正常实板记录的 `ext_full_005` 顺序取图链路，选择性集成六页无 Bot 素材、字幕和控制。

构建源码冻结为 `6ee7c70bbf36c33f90a687f010c876de48f03ba6`。最终结果、四类时序、验证范围及交付清单见 [本轮交付报告](docs/no_bot_legacy_delivery.md)；素材格式、所有按键、HTML差异和明日实测步骤见 [媒体与验收说明](docs/no_bot_legacy_media.md)。**HARDWARE_NOT_TESTED**，完整加密IP系统仿真未验证。

## 当前结构

- 六张640×480普通BMP和四张320×480独立面板按需加载到两个完整帧缓存；单路256字顺序显示读取，原读写FIFO与HDMI/SDRAM IP保持。
- 六页、前后切页、自动轮播、暂停、真实双图、1×/2×/3×取图及六焦点，默认2×。
- 输出端遮罩覆盖旧页后加载，完成实际写入、读端提交及完整资格帧后揭示；名义覆盖201.6ms、揭示302.4ms，加载等待另计。
- OSD字幕卡、打字、页码、进度和真实PCM峰值条继续实时合成；Bot专用实例与ROM已移除。
- WAV读取、音量/静音、HDMI音频连接及EOF重启保留。当前镜像首次启动/每次循环仅重新扫描的理论下界已约6.04秒，另加卡等待和预填；不属于无缝循环。

当前生产工程不使用 `html_layer_cache`、四字随机取图或HFXL/HFXC资源。精细CSS分层动画已按授权近似为静态BMP与输出转场。专用加载器仅接受本套640/320×480媒体约定，不声明支持任意BMP尺寸。旧分层结果保留在 `codex/no-bot-exhibit`；`docs/harness/` 及旧渲染脚本是历史证据，不是本轮交付入口。

## 目录与复现

Windows事实源为 `D:\FPGA\EG4S20-NoBot`，Mac负责SSH调度和少量预览。原Windows工程及用户改动不覆盖；不在Google Drive构建。

| 路径 | 用途 |
|---|---|
| `rtl/ext/legacy_exhibit_media.v`、`legacy_exhibit_loader.v` | 旧式双缓存管理及真实加载时双图/缩放 |
| `rtl/ext/video_transition.v`、`html_video_overlay.v` | 单路输出遮罩、既有OSD与峰值条 |
| `scripts/no_bot_apply_legacy.py` | 从精确校验的本地旧版原件生成最小集成顶层/工程 |
| `docs/no_bot_legacy_inputs.json` | 受忽略的厂商派生输入和ROM身份 |
| `output/html_fidelity/no_bot/` | 本轮唯一状态入口、媒体、真实RTL验证及交付清单 |
| `artifacts/no_bot_legacy_004_source.zip` | 包含本地厂商依赖的冻结构建输入快照 |
| `output/html_fidelity/builds/no_bot_legacy_004/` | TD日志、阶段状态、最终路由及位流 |

公开Git不包含完整官方/加密IP、派生骨架、位流和大素材。需保留原件及本地依赖；Git bundle不等于完整可综合项目。补齐步骤见 [依赖说明](docs/DEPENDENCIES.md)，最终输入哈希以本轮清单为准，不能用旧基线检查器覆盖当前集成结果。

以下命令仅在已准备的Windows工作树复现媒体检查；构建示例会启动一次真实TD流程，应按后续授权运行并使用全新run-id。

```powershell
D:\python3.12.3\python.exe -X utf8 scripts\no_bot_media_image.py --validate-only
D:\python3.12.3\python.exe -X utf8 scripts\build.py launch new_run_id --timeout 3600
D:\python3.12.3\python.exe -X utf8 scripts\build.py status new_run_id
```

正式位流只取004的 `phy_1/hx4s20_basic.bit`，其在hold修复后重新生成；完整路径及SHA见交付报告。媒体采用 `output/html_fidelity/no_bot/media/` 的UI01..06、PN01..04和07_MUSIC.WAV，一套包完成六页及双图。普通拷贝不能保证连续FAT链和物理扫描顺序；今夜未操作实体卡或FPGA。

已有Noto Sans SC的SIL OFL1.1和合成音频CC0声明继续保留。不为其他来源代码/图片补写许可证。
