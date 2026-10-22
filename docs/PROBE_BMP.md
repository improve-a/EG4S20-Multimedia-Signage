# 800×600 真实 BMP 页的 640×480 虚拟源窗口

本文件说明 `rtl/ext/legacy_exhibit_loader.v`、`rtl/ext/bmp_scale.v` 的 800×600 支持、
素材生成与全部仿真证据。仅离线仿真与素材生成，无 TD 构建、无 STA、无卡/硬件操作。

## 结论

- 画布仍为 640×480：`FRAME_PIXELS=307200`、`BUF0/BUF1`、写读长度、`WRITE_V_FLIP=1`、
  `video_delay`/HDMI 时序、PLL/CDC/引脚均未改动。
- 真实 800×600 24bpp 无压缩 BMP 通过**固定 640×480 虚拟源窗口 (80,60)** 上屏：
  窗口内容 = 原页中心 640×480 = **307200 / 480000 = 64.0000%** 面积，1:1 像素、无插值；
  窗口外 172800 像素存在于文件中但不上屏（其中 172511 个与窗口边界像素不同，见
  `window_evidence`）。
- 不新增缩放流水线：1×/2×/3× 仍是原有的整数最近邻抽样与 36 项 origin 表，
  只是 800×600 源把抽样坐标系整体平移 (+80,+60)（读取窗口起点 240 字节）。

## RTL 改动（唯一行为性文件）

`rtl/ext/legacy_exhibit_loader.v`

1. 头部几何锁存 + 严格匹配：字节 2..5（bfSize）、18..19（width）、22..23（height）
   在 HWAIT 锁存，HCHECK 与 `{640,480,922112}`、`{800,600,1440512}`、双图
   `{320,480,461312}` 逐一比对；不符 `error=1`、状态回 IDLE、**从不置 write_req**。
   其余固定格式字节（`BM`、像素偏移 512、DIB40、planes=1、24bpp、compression=0、
   20/21/24/25 为零）保持原逐字节比较（`checked/expected_byte`）。
2. `native_row_l` 9→10 bit、`row_fifteen` 13→14 bit；`native_row = wide ? 539-source_y : 479-source_y`。
   `source_y` 仍是 640×480 画布内的逻辑行，`row_numerator` 保持 `479-out_row+ry` 不变。
3. 行起点：单图 800 增加 240 字节（3×80）窗口偏移；行距 2400 = `15n×128 + 15n×32`，
   与既有 1920/960 一起由新状态 `ROW_OFFSET` 寄存到 `row_offset_l`，
   `ROW_ADDRESS` 仍是 `512 + row_offset_l` 单加法器；实际时序以最终TD报告为准。
4. 每行仍只读 **640 列 = 1920 字节**，因此 `line_buffer` 640×24 不增，
   `BYTE_USE`、`line_write`、`sample_x<=ox`、origin 表、divisor、行复用逻辑全部不变。
5. 双图分支仅把行偏移来源换成寄存值；320×480 面板行为不变。

`rtl/ext/bmp_scale.v`（扫描器）

- `height` 9→10 bit（字节 23 取 `data[1:0]`，仍拒绝 `data[7:2]!=0`）；
  `image_bytes` 21→22 bit；`pixel_end_wide` 拼接同步加宽。
- 普通**加载**接受范围保持 `width<=640`、`height<=480`；仅 `scanning && width==800 && height==600`
  额外接受（`probe_extent_ok`）。因此 800×600 只可能被目录扫描收录，
  本模块的 `bmp_scale` 实例与普通加载路径不会被 800×600 启动
  （新增 case `scan_load_path_refuses_800`：`error_code=1`、无 write_req）。
- HFXL 分支 locator 接线 `.height({22'd0,height})` 与 10 位字段对齐。

## 素材（原创，非旧图放大）

`scripts/probe_bmp_media.py` 用标准库图元（渐变/网格/卡片/雷达/色带/标尺/标定块）
绘制原创 800×600 科技展页，明确不是任何 640×480 交付页或 HTML 导出的裁剪/放大：

| 文件 | 头 | bfSize | 字节 | 扇区 | sha256 |
|---|---:|---:|---:|---:|---|
| `output/probe_audio_multires/media/UI06.BMP` | 54 | 1440054 | 1440054 | 2813 | `2ff22907891d8f18…` |
| `output/probe_audio_multires/media/UI06_512.BMP` | 512 | 1440512 | 1440512 | 2814 | `8c66a2b5c34f00c4…` |

- 两文件像素载荷逐字节相同，含全部 480000 像素；行距 2400、无行填充、正高度底向上，
  54..511 头填充全零。完整哈希见 `media/probe_bmp_manifest.json`。
- 窗口外内容（顶部标尺 y<60、右边距 x≥720 的标定块、绿色 45° 斜纹边距）证明文件中
  确实保留了窗口外的真实内容。
- Windows 侧由同一脚本重新生成，`UI06_512.BMP` sha256 与 Mac 完全一致，
  因此夹具/媒材可跨机复现，不需要传输二进制。

## 验证方式与结果

Windows（`C:\iverilog\bin\iverilog.exe` / `vvp.exe`），夹具与媒材全部在 Windows 本地生成：

```
python scripts\probe_bmp_remote.py --work <含 rtl/tests/scripts 的树根> [--out <目录>] --only loader|scan
```

原始 `returncode`、stdout、sector 统计与 dump 哈希保存在
`<out>/result_<phase>.json`；逐像素 dump 保留在 `<out>/runs/<phase>_<stamp>/`（未回传 Mac）。

### 逐像素 golden 比较（307200 像素/例）

独立 oracle（`scripts/probe_bmp_oracle.py`，只按显示规则建模，不读 RTL 常量）生成期望
像素流，bench 以 `gold` 数组逐像素比较；仿真 dump 的 sha256 与 Mac 侧 oracle 的期望流
（Windows 文本模式 CRLF）逐例相同。

| case | page/dual/zoom/focus | 扇区 | 最大扇区 | dump |
|---|---|---:|---:|---|
| `single800_1x` | 0/0/1×/默认 | 2281 | 2631 | 307200 字一致 |
| `real800_1x` | 0/0/1×（真实素材，PERIOD=16） | 2281 | 2631 | 307200 字一致 |
| `single800_2x_home` | 0/0/2×/默认 | 1141 | 2294 | 307200 字一致 |
| `single800_2x_page2` | 2/0/2×/默认 | 1141 | 2383 | 307200 字一致 |
| `single800_2x_focus5` | 2/0/2×/下 | 1141 | 1506 | 307200 字一致 |
| `single800_3x_focus3` | 3/0/3×/右 | 761 | 1881 | 307200 字一致 |
| `single800_3x_focus2` | 3/0/3×/左 | 761 | 1881 | 307200 字一致 |
| `dual320_1x` | 1/双/1× | 2642 | 5900 | 307200 字一致 |
| `dual320_3x_focus1` | 3/双/3×/中心 | 882 | 5600 | 307200 字一致 |
| `reload_800_640_800` | 同实例 800→640→800 | 2281/2161/2281 | 2631/1900/2631 | 三帧各 307200 |

### 拒绝路径（error 码正确、write_req 从未拉高、0 像素）

| case | 期望 | 结果 |
|---|---|---|
| `reject_800_width801` | error 1 | PASS |
| `reject_800_height601` | error 1 | PASS |
| `reject_800_negative_height`（32位高度符号位为1） | error 1 | Root定向复测见最终报告 |
| `reject_800_wrong_bfsize`（bfSize≠1440512） | error 1 | PASS |
| `reject_dual_with_800`（双图给 800） | error 1 | PASS |
| `reject_640_as_dual`（双图给 640） | error 1 | PASS |
| `reject_short_sector`（511 字节） | error 2 | PASS |
| `reject_sd_error` | error 3 | PASS |
| `reject_no_ack` | error 4（超时） | PASS |

### 目录扫描（`tests/probe_bmp_scan_tb.v`）

10 项（5×640×480、1×800×600、4×320×480）按序发现，LBA 11086 的 800×600 被收录，
仅 10 次 header 读；4 类畸形 800 头（801/601/负高度/bfSize<payload）均不收录
（只发现 9 项、2824 次请求 = 10 + 2814 盲扫）；`scan_load_path_refuses_800`
证明普通加载路径对 800×600 返回 `error_code=1` 且不置 write_req。

### 每拍边界断言

`line_write≤640`、`sample_x≤639`、`buffer_index≤511`、`byte_position≤1440511`、
`native_row_l≤539`、`row_fifteen≤8085`、`row_offset_l≤1293840`；
640/320 载荷 `native_row_l≤479`；每帧像素恰 307200；`pixel` 与 `gold` 全等。

## 地址与扇区证据（1×，800×600）

| 行 | 逻辑行 | 文件行 | 行首字节 | 扇区 | 行尾字节 | 行尾扇区 |
|---|---:|---:|---:|---|---:|---:|
| 流首行（屏幕底） | 479 | 60 | 144752 | 282 | 146671 | 286 |
| 中间 | 239 | 300 | 720752 | 1407 | 722671 | 1411 |
| 流末行（屏幕顶） | 0 | 539 | 1294352 | 2528 | 1296271 | 2531 |

- 文件末字节 1440511；最高请求扇区 2531 < 文件 2814 扇区，所有请求都在文件范围内
  （bench 对越界扇区直接 `$fatal`）。
- 640 列窗口 = 1920 字节，行首不按扇区对齐 → 每行 4~5 次扇区请求；1× 共 2281 次
  （640×480 为 2161，+5.6%）；2× 1141；3× 761。

## 时间与容量（模型值，非实测）

- 按既有记录的 36,613 SD100 时钟/CMD17：800×600 1× 约 **835 ms/页**，
   640×480 为 791 ms；另有像素输出与字节装配时间，不宣称这是整页实测加载时间。
- 片内 RAM 不变：loader 行 RAM 640×24、sector 512×8；扫描器 sector 512×8。
- SDRAM 不变：`BUF0` word 0..307199、`BUF1` word 307200..614399，像素 `RRGGBB00`，
  每次加载写 307200 字。
- TF 占用：800×600 文件 1,440,512 B = 2814 扇区（尾部 256 B 落在末扇区），
  比 640×480 多 1013 扇区。若替换 UI 页，WAV 起始 LBA 后移；`audio_media` 从 LBA0
   逐扇区盲扫，首次启动扫描约增加0.371 s/页（模型值）；本轮音频改动已取消EOF重扫。

## 边界与未做项

Root审查发现旧拒绝夹具误将640宽的右图读进320宽测试数组，以及“负高”只改低16位。
现已仅修测试夹具：使用合法右面板陪测左图拒绝，负高设置真实32位符号位；拒绝用例
不再读取无用的单字gold文件。生产RTL不变，只补跑受影响的拒绝用例，不重复完整像素仿真。

- 800×600 仅单图；双图仍为 320×480 面板。
- 未做 TD 合成/布局布线/STA、未接触卡或硬件：`BUILD_NOT_RUN`、`TIMING_NOT_MEASURED`、
  `HARDWARE_NOT_TESTED`。100 MHz 域新增内容（geometry 比较树、`ROW_OFFSET` 寄存级、
  头部锁存）需在整机流程的 STA 中复核。
- 报告中的加载时间来自既有 CMD17 事务模型，不是实卡测量。
