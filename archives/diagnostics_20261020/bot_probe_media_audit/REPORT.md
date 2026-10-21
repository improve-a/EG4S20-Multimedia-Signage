# bot_probe_media_audit — 结论汇总（只读）

任务：1) 旧 Bot 六页 HFXL/BMP/WAV 素材 vs 当前 NoBot Probe TF 卡素材是否兼容；2) 硬件下载脚本/TD 编程器 CLI/设备/TF 可见性，给最小安全测试命令与备用卡判断。
边界：未烧录、未写 Flash、未改 TF、未写硬件、未跑构建；唯一硬件动作是 JTAG `list_cable`/`read_device_id` 只读枚举。

## 回答 1：兼容性

| 维度 | 结论 |
|---|---|
| 六页画面像素 | **完全兼容**：6/6 页 640×480 RGB24 逐字节相同（HFXL 文件从其 pixel_offset 起 vs NoBot UI0x 从 512 起） |
| 音频 | **完全相同**：WAV 7,680,044 B，SHA256 `c0671b03…18886` |
| 容器格式 | **不兼容**：旧 Bot 必须 HFXL v1（`set_id=0x003adc1b`、页 0..5、payload/base 表固定）；NoBot 是 10 张普通 BMP（无 trailer），`ENABLE_HFXL=0` |
| 卡布局 | **互斥**：两者都必须在扫描窗口 LBA 0..131071 内按物理顺序出现，不能共卡 |
| NoBot 固件 + HFXL 卡 | **0 张可用**：`bmp_read` 要求 `file_len ≤ pixel_end+64KiB`，HFXL 为 2.0–2.4 MB，全部被拒；且只提供 6 张 < 需要的 10 张 |
| 旧 Bot 固件 + NoBot 卡 | 页 0 无 HFXL → 走遗留 BMP 回退，六页可显示但 **分层/Bot 场景不生效**（假阳性风险） |

实测的旧卡内容（10-19 22:07 只读备份）：6 个 HFXL 文件（2,022,912 / 2,416,128 / 2,390,528 / 2,419,200 / 2,418,176 / 2,080,256 B）+ WAV，与 `unified_003adc1b_v2.img` 对应切片逐字节相同；`file_len == scene_offset + payload` 六页全部 OK。
冻结源 `timing_fix_20261016_02_source.zip` 内的加载器参数与目标树相同 → 同一套 HFXL 素材适用。
详见 `MEDIA_COMPATIBILITY.md`。

## 回答 2：硬件

- **没有 td_programmer.exe**。TD 6.2.1（`G:\anlu`）的编程器 CLI 是 BitWizard `G:\anlu\bin\bw_commands_prompt.exe`（SHA `513B024C…`，与历史证据一致）；`td_commands_prompt.exe`（`E2E04ADA…`）只做构建。
- 既有下载脚本模板：`…\hw_20261016T095019Z\program_sram.tcl` 等（`download -bit … -mode jtag -spd N -cable 0`，volatile SRAM，`flash_written=false`）。tcl 路径必须用正斜杠。
- **设备在线**：`Anlogic usb cable v0.1`（VID_0547/PID_1002）；本次 `list_cable → 0:EG4S20BG256`，`read_device_id → EG4S20BG256`，exit 0，总计 0.08 s。root 的 `td_commands_prompt` PID 50504 在跑，勿并发构建/下载。
- **Root 修正：TF 卡在 Windows 中不可见**。这只说明不能通过当前 Windows 读卡器读取，不能推断 FPGA 板槽无卡或只能验证无媒体路径。用户已确认板卡接好；板槽素材内容本轮未读回。
- **最小安全命令**：`enum_only.tcl`（只读，0.1 s）→ 见 `HARDWARE_READINESS.md` §5；T2 才是 `download`（SRAM，7–51 s）。
- **备用卡：需要**。卡 A 保持 NoBot 布局（`no_bot_fat32.img`，`22f08ad1…`，精确回读过）；卡 B = HFXL 布局（`unified_003adc1b_v2.img` 或 `card_before\files`）。同卡改写虽可无损恢复，但需明确授权且在本次范围外。

## 证据文件

| 文件 | 内容 |
|---|---|
| `00_env.out` | 主机/卷/磁盘 |
| `13_parse_images.out` | 4 个 64 MiB 镜像的 BM/HFXL 头解析（页序、set_id、base、payload） |
| `24_compare_media.out` / `25_compare2.out` | 文件/像素/WAV 逐字节比对；v1 vs v2 差异 |
| `36_compare3.out` / `38_compare4.out` | 实卡前 64 MiB vs 镜像；实卡 6 文件 = v2 |
| `37_zip_check.out` | 冻结 zip 内 `SET_ID/BASE_WORDS/LENGTH_WORDS` |
| `39_manifests.out` | 实卡身份、文件哈希、header_candidates、deployment.json |
| `21_dump_prog.out` | 既有下载 tcl/日志/status |
| `28_params_obs.out` | NoBot 观测记录（initial_screen=FAIL，其余 PENDING） |
| `34_jtag_probe2.out` | 本次只读 JTAG 枚举 |
| `43_scan_inst.out` / `44_bmpread.out` / `45_bmpscale.out` | 扫描参数、bmp_read 尺寸判据、HFXL 接受条件 |

脚本：`run_remote_py_stdin.py`（ssh stdin 执行远端 python，不落盘）、`parse_images.py`、`compare_media.py`、`compare2.py`、`compare3.py`、`compare4.py`，及各 `*.ps1` 采集脚本。

## 明确未做

未运行任何 `download`/`program`；未写 Flash；未格式化/写入 TF；未修改 `EG4S20-Bot-HDMIProbe`、`EG4S20-Multimedia-Signage`、`EG4S20-NoBot*`；未运行综合/布局布线；未重复 Probe 审计与基线定位。
