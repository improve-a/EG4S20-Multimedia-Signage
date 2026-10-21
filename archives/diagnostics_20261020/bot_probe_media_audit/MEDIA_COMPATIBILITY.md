# 旧 Bot 六页 HFXL 素材 vs 当前 NoBot Probe TF 卡素材 — 只读兼容性核查

日期：2026-10-20（host thinkpad，TD 6.2.1 Engineer 168116）
范围：只读。未烧录、未改 TF、未写硬件、未运行构建；证据见同目录 `*.out`。
被检查的仓库：旧 Bot `D:\FPGA\EG4S20-Multimedia-Signage`（HEAD=20871da，工作树仅有 SDRAM 修复类改动，未触及加载器）、成功 NoBot `D:\FPGA\EG4S20-NoBot` / `D:\FPGA\EG4S20-NoBot-HDMIProbe`、移植目标 `D:\FPGA\EG4S20-Bot-HDMIProbe`（只读）。

## 结论（先看这里）

1. **六页画面内容与 WAV 完全同源**：6/6 页 640×480 RGB24 像素区逐字节相同，WAV 同一 SHA256。素材本身兼容。
2. **容器/卡布局不兼容，不能互换使用**：
   - 旧 Bot 的 `html_scene_loader` 只认 **6 个带 HFXL v1 定位器（set_id=0x003adc1b）的 BMP**，按物理 LBA 顺序分配页 0..5；
   - NoBot 用的是 **6 张 640×480 普通 BMP + 4 张 320×480 PN + WAV**（`no_bot_fat32.img` 布局），**没有 HFXL 尾部**；
   - 同一张卡不可能同时满足两者：两套都必须在扫描窗口 LBA 0..131071 内按物理顺序出现，混放会改变页序。
3. **两块固件的实际表现**（由 RTL 判据推出，非实测）：
   - NoBot 固件 + HFXL 卡：`bmp_read.v` 的 `header_size_ok=(file_len>=pixel_end)&&(file_len<=pixel_end+65536)`，HFXL 文件 2.0–2.4 MB 远大于 `pixel_end+64KiB`，且 NoBot 实例化 `ENABLE_HFXL=0` → **6 个头全部被拒，扫到 0 张图**（NoBot 需 10 张），无画面。
   - 旧 Bot 固件 + NoBot 普通卡：页 0 有 `BM` 但无 HFXL → `html_scene_loader` 走 `page==0 && !locator_present` 的**遗留 BMP 回退**（`layer_mode=0`）；能显示六页普通图，但 **Bot/分层场景、双面板路径全部不生效**。外表“有画面”但并未验证被测设计。
4. 因此：**旧 Bot/移植 Probe 的硬件观察必须用 HFXL 六页卡**；**NoBot 侧必须保留普通 BMP 卡**。建议备用卡（见 HARDWARE_READINESS.md）。

## 依据 A：旧 Bot 的加载器契约（源码，非文件名）

`rtl/ext/html_scene_loader.v`（SHA256 前缀 `ED60638A3F84`）与移植目标 `EG4S20-Bot-HDMIProbe\rtl\ext\html_scene_loader.v` **逐字节相同**；`html_resource_locator.v`（`67ED4A690B41`）也相同。参数：

```
SET_ID      = 32'h003adc1b
BASE_WORDS  = {1514240,1202688,890880,586240,275200,0}     // page5..page0
LENGTH_WORDS= {289536,311552,311808,304640,311040,275200}
```

`html_resource_locator.v` 要求每个文件（6 个，页 0..5）：
- 头 80..83 = `HFXL`；84=1、86=32、102=6；85/87/103/108..111=0；
- bytes 89/90 → `scene_sector`（512B 对齐）；93/94 → `payload_blocks`（`payload_bytes=blocks×1024`；必须 = `LENGTH_WORDS[page]×4`）；
- 97/98 → `word_base`（必须 = `BASE_WORDS[page]`，即 0/275200/586240/890880/1202688/1514240 字）；
- byte 100 → `page_index` 必须等于当前页；104..107 → `set_id` 必须 = `0x003adc1b`；
- `pixel_offset` 512..1 MiB，DIB40，640×480，`file_len == scene_offset + payload_bytes`；
- `scene_offset == align512(pixel_offset+921600)`；`memory_end <= 1,843,200` 字。

`rtl/top_tf_hdmi_audio.v:349` 使用 `.ENABLE_LAYER_RESOURCES(1)`，`:351` 传 `.SCAN_TARGET_COUNT(4'd6)`；`sd_card_bmp.v:194` 要求 `scan_done && img_found_count>=6` 才置 `resource_catalog_ready`。即**卡的扫描窗口内前 6 个 BM 头必须正好是 HFXL 页 0..5**。

`sd_card_bmp.v`（旧仓库与 NoBot 仓库 **SHA256 完全相同** `6F99F19F2585`）：扫描 LBA 0..131071，512B 步进，命中后按 `ceil(bfSize/512)` 跳过，忽略 FAT 与文件名。

冻结源 `artifacts\timing_fix_20261016_02_source.zip`（SHA256 `2923DFE9…84C3`，532769 B）内 `html_scene_loader.v` 的 `SET_ID/BASE_WORDS/LENGTH_WORDS` 与此**完全一致** → 该 HFXL 套件同样适用于 root 正在移植的冻结源。

## 依据 B：真实卡上的内容（10-19 22:07 只读备份）

`D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\`（备份时卡为 `K:`，Generic USB STORAGE，Serial `000000001532`，62,531,305,472 B，FAT32 `ANLOGIC2026`）：

| 文件 | 字节 | SHA256(前 12) | HFXL 页 | pixel_offset | payload |
|---|---:|---|---:|---:|---:|
| UI01.BMP | 2,022,912 | 00b22cbf45d6 | 0 | 512 | 1,100,800 |
| UI02.BMP | 2,416,128 | 875fb77822ee | 1 | 250,368 | 1,244,160 |
| UI03.BMP | 2,390,528 | b6528d33decb | 2 | 250,368 | 1,218,560 |
| UI04.BMP | 2,419,200 | c00073c9a632 | 3 | 250,368 | 1,247,232 |
| UI05.BMP | 2,418,176 | 9a4b6c2d8cd5 | 4 | 250,368 | 1,246,208 |
| UI06.BMP | 2,080,256 | 945c8408ef9e | 5 | 512 | 1,158,144 |
| 07_MUSIC.WAV | 7,680,044 | c0671b035fdd | — | — | — |

- 6 个文件与 `output\html_fidelity\card_images\unified_003adc1b_v2.img` 的对应切片**逐字节相同**（page 0/5 只与 `_v2` 匹配；v1 与 v2 的差异仅在 page0/page5 头的 54..511 区，426 字节不同，v2 已清零该填充）。
- `file_len == scene_offset + payload_bytes` 对 6 页全部 OK（`13_parse_images.out`）。
- 卡上物理顺序：BM@24704(page0)、HFXL@26505、BM@28672、…，与页序一致（`card_before/manifest.json` 的 `header_candidates`）。
- `card_before/first64MiB.bin` SHA256 `d7d07b92…fbf9`，与两个 64 MiB 镜像都不同（FAT/簇布局不同），但文件字节相同 → **不要按镜像 LBA 假定实卡布局**，应按文件内容校验。

## 依据 C：NoBot 侧真实卡内容（已上卡并精确回读）

- `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media\no_bot_fat32.img`，64 MiB，SHA256 `22f08ad1161d…0f9f`。
- `card_deployed\deployment.json`：写入物理盘前 64 MiB（`\\.\PhysicalDrive3`），`readback_exact=true`，回读 SHA256 与镜像相同；`post_unlock64MiB.img` 为解卷后快照（`0707992a…d958`，非同一件事）。
- 镜像内（`13_parse_images.out`）：6 张 640×480 `922112 B`、`pixel_offset=512`、无 HFXL 的 UI01..UI06（LBA 2081/3882/5683/7484/9285/11086），4 张 320×480 `461312 B` PN01..PN04（LBA 12887/13788/14689/15590），WAV 在 LBA 16491。
- 固件侧：`rtl/ext/legacy_exhibit_media.v:92` `bmp_scale_read #(.ENABLE_HFXL(0))`，`:94` `scan_target_count=10` → 需要 10 张普通 BMP，绝不解析 HFXL。

## 像素级比对（关键证据，`25_compare2.out`）

| 页 | HFXL 文件像素区（从各自 pixel_offset 起 921600 B） | NoBot UI0x 像素区（从 512 起） | 结果 |
|---|---|---|---|
| 1 | 33a249e7… | 33a249e7… | 相同 |
| 2 | 5a975a50… | 5a975a50… | 相同 |
| 3 | 0eb84f83… | 0eb84f83… | 相同 |
| 4 | 493d597d… | 493d597d… | 相同 |
| 5 | 26011051… | 26011051… | 相同 |
| 6 | ac5056e8… | ac5056e8… | 相同 |

WAV：两侧同为 `c0671b035fdd04465ae6280427bbd5732e065693dd066a511a74e9426e818886`（7,680,044 B，PCM16 mono 48 kHz）。

即：**同一组六页画面 + 同一段音频，仅封装不同**（HFXL 在像素区之后追加 ~1.1–1.25 MB 分层负载并把第 2–5 页像素挪到 250368）。

## 对移植的直接影响

- 移植后的 Bot 顶层若保留 `.ENABLE_LAYER_RESOURCES(1)`（当前目标树 `html_scene_loader.v` 与旧版相同），则上板必须插 HFXL 六页卡；用 NoBot 卡只会走遗留 BMP 回退，**会给出“有画面”的假阳性**。
- 已核实的 HFXL 套件三份等价来源（任选其一重建卡）：
  1. `output\html_fidelity\card_images\unified_003adc1b_v2.img`（推荐，与实卡文件字节一致）；
  2. `...\card_before\files\UI01..UI06.BMP + 07_MUSIC.WAV`（实卡原样拷贝，含 `manifest.json` 哈希）；
  3. `unified_003adc1b.img`（v1，仅 54..511 的 458 B 差异，加载器不校验该区，但**不推荐**，避免与实卡证据分叉）。
- NoBot 卡内容随时可从 `no_bot_fat32.img` 精确恢复（哈希已固定）。
