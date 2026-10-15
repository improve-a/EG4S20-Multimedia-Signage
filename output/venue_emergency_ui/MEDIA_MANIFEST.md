# 场序 · 媒体交付契约

本轮只生成与验证普通目录素材，未写入物理 TF 卡。页面中的中文、图形、示例时间与模拟标识均在 PC 预渲染；它们不是动态字幕、实时告警或实际应急控制。硬件显示、物理卡布局、HDMI 音频与连续运行均为 **NOT_VERIFIED**。

## 可用播放包

每次冷启动只选择一个包；不得把全部文件夹合并复制到 TF 卡。`master_media` 保存六张母版，**不是一个可整体部署的播放包**。

| 包 | 图片 / WAV | 内容 | 用途 |
|---|---|---|---|
| `A_daily` | 2 / 1 | UI-01 欢迎；UI-02 日常信息；80 秒原创氛围音乐 | 日常场景 |
| `B_emergency` | 4 / 1 | UI-03 模拟预警；UI-04 紧急指引；UI-05 模拟路线；UI-06 演示结束；80 秒柔和 DEMO 提示音 | 预设应急演示 |
| `C_features` | 4 / 1 | 原有 320×240、320×180、640×360、640×480 色条棋盘格；原有 30 秒立体声音频 | 独立技术验收 |

| 母版 | 启动包文件名 | 画面尺寸 |
|---|---|---|
| `master_media/UI01.BMP` | `A_daily/01_WELCM.BMP` | 640×480 |
| `master_media/UI02.BMP` | `A_daily/02_DAILY.BMP` | 640×480 |
| `master_media/UI03.BMP` | `B_emergency/01_UI03.BMP` | 640×480 |
| `master_media/UI04.BMP` | `B_emergency/02_UI04.BMP` | 640×480 |
| `master_media/UI05.BMP` | `B_emergency/03_UI05.BMP` | 640×480 |
| `master_media/UI06.BMP` | `B_emergency/04_UI06.BMP` | 640×480 |

文件名是人类顺序提示。RTL 不解析 FAT、目录、文件名或这些数字；实际顺序由物理 LBA 决定。保留技术素材在独立包内，避免将缩小后的正文当作产品页面验收结果。

## 经 RTL 核对的约束

依据 `rtl/SD/sd_card_bmp.v` 的默认参数、`rtl/ext/bmp_scale.v` 的头部检查、`rtl/ext/audio_media.v` 和 `rtl/ext/wav_stream_parser.v`：

- 默认从 LBA 0 扫描到 131071（包含），发现最多四张 BMP；这是头部发现范围，不是后续文件读取范围。
- 不遍历 FAT 链。每个素材的头部必须位于 512 字节扇区边界，且文件数据必须占据连续物理扇区。
- 图片：正高度、bottom-up、24-bit BGR、BI_RGB，宽 ≤640、高 ≤480。交付统一使用 40 字节 BITMAPINFOHEADER、像素偏移 54、零填充到 4 字节行对齐。
- 六张母版都是 640×480，每张 921654 字节；二进制解码后的 top-down RGB 必须逐像素等于对应 `assets/design/UIxx.ppm`。
- WAV：RIFF/WAVE，PCM signed 16-bit，48 kHz，单声道或立体声，头部在 RTL 的 4096 字节界限内；本轮原创音频是单声道，数据偏移 44。
- 只使用发现的首个 WAV。没有页面触发音频、应急音频抢占、页面同步或 EOF 自动循环。80 秒结束后音频停止；尾部一秒静音是媒体内容，不是播放循环。
- 被删除、空闲区或其他目录残留的有效 BMP/WAV 头部仍可能被发现。普通文件名正确和文件复制成功不足以证明 FPGA 可以播放。

## 声音来源及许可

`assets/audio/ambient_80s_mono_48k.wav` 是原创和弦铺底与稀疏钟音；`demo_cues_80s_mono_48k.wav` 是柔和双音提示。均由 `scripts/package_media.py` 的标准库振荡器确定性合成，无外部录音、采样或第三方乐曲。原创音频按 CC0 1.0 提供，详见 `assets/audio/SOURCE_AND_LICENSE.md`。提示音仅用于模拟展示，不作为真实建筑疏散警报。

两个文件各 80 秒 / 3840000 帧 / 7680044 字节，具有柔和进入、退出与最后一秒精确静音。氛围乐钟音使用每音符局部相位和 20 ms 平滑进入/退出，已修复初版音符边界突跳：最大相邻样本差 1774 → 264，四秒换音边界最大差 1774 → 97；DEMO 提示音保持原哈希及正常高频波形（最大相邻差 466），没有进行样本限幅。前后证据见 `evidence/media/audio_boundary_audit.json`。峰值、RMS、削波计数与 PCM SHA256 由独立验证器写入 `evidence/media/validation.json`。`C_features` 由字节相同的原始生成器副本 `scripts/feature_fixture_source.py` 重生成四个技术 BMP 与 30 秒 WAV，并强制核对与原始素材相同的 SHA256；原始脚本与素材未修改。副本来源及原始哈希见 `tf_card_package/manifest.json`。

## 80 秒展示设计目标

建议素材画面时间：UI-01 10 秒、UI-02 20 秒、UI-03 12 秒、UI-04 12 秒、UI-05 16 秒、UI-06 10 秒，总计 80 秒。这是人工讲解/切换的画面时间目标，不是新建硬件定时或自动警情流程。

当前四图发现上限无法在一次启动中播放全部六张母版。实际展示分为 A 日常会话和 B 模拟应急会话，需要人工换卡或经授权调整素材后冷启动；换卡、部署、启动与发现素材的准备时间不计入上述 80 秒。A 包仅两图时，默认目标四图的扫描器需要扫描到 LBA131071 才完成发现，首次加载必须等待扫描完成，启动延迟尚无真实硬件时间证据。每个会话的音频独立开始并播放至 EOF，不保证与各页面时间相位一致。UI-06 是静态演示结束页，不会自动切换回 A。

## 重生成与离线检查

在仓库根目录运行 UI 生成器后执行：

```sh
python3 output/venue_emergency_ui/scripts/package_media.py
python3 output/venue_emergency_ui/scripts/validate_media.py
python3 output/venue_emergency_ui/evidence/media/self_test.py
```

`package_media.py` 只写本交付目录普通文件，拒绝覆盖包中的未知 BMP/WAV；不操作设备。`--audio-update` 仅重生成声音并更新 A/B 包的 WAV 与哈希，不写冻结的 PPM/BMP。`validate_media.py` 独立解析 BMP/WAV，不导入生成器，校验头部、字节数、颜色顺序、翻转、源像素一致性、每包上限、音频帧界限、削波与哈希。自测使用临时合成 FAT32 镜像验证只读检查器；该镜像自动删除，**不是部署素材**，不证明真实硬件成功。

## 后续 TF 卡验收

写卡前需要验证备份并取得本轮物理卡写入的明确授权。本交付不提供格式化、分区、原始写盘、自动提权或卡片清理脚本。经授权的普通文件复制后，也必须核对真实布局；碎片化、顺序不符或残留头部需要记录处理，不能通过改名来宣称已修复。

只读检查已获授权时，可对 **明确选定** 的完整磁盘镜像或 Windows 物理设备运行以下命令（示例 `N` 需由设备身份确认替换）：

```sh
python inspect_card.py --source "\\.\PhysicalDriveN" --pack A_daily --report audit_A_daily.json
```

脚本仅以 `rb` 打开源，检查 MBR/FAT32、使用链的 FAT 副本一致性、连续簇、物理文件 SHA256、全范围 BMP/RIFF 残留头部、四图上限、首 WAV 与物理顺序。它不自动查找磁盘，不自动调用管理员权限，不写卡。当前支持单一 MBR FAT32 分区或 FAT32 superfloppy；GPT、其他文件系统明确报 FAIL。只读布局 PASS 仍不替代真实板卡冷启动、画面观察与 HDMI 音频验收。
