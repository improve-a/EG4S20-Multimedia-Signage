# 硬件下载链路 / 设备 / TF 可见性 只读核查 + 最小安全上板测试

日期：2026-10-20 22:27–22:40（host thinkpad，本地时区 +08:00）
范围：只读枚举。**未烧录、未写 Flash、未改 TF、未运行构建**。唯一一次主动硬件访问是 JTAG 的 `list_cable` / `read_device_id`（只读命令）。证据：同目录 `00_env.out`、`17_hw_enum.out`、`19_td_bin.out`、`21_dump_prog.out`、`22_hw_sessions.out`、`34_jtag_probe2.out`、`40_bot_dir.out`、`43_scan_inst.out`。

## 1. 工具链（实测存在性）

TD 安装：`G:\anlu`（注册表 `TD_6.2.1_Engineer 6.2.168.116`，InstallLocation `G:\anlu\`；`G:\anlu\bin\td.exe`，快捷方式参数 `TD_6.2.1_Engineer6.2.168.116`）。

| 工具 | 路径 | 大小 | SHA256（前缀） | 用途 |
|---|---|---:|---|---|
| TD 批处理（构建） | `G:\anlu\bin\td_commands_prompt.exe` | 76,680,976 | `E2E04ADA5E25`（与文档记录一致） | SYN/PNR/BITGEN |
| BitWizard GUI | `G:\anlu\bin\bw.exe` | 15,005,960 | `B4018B6D6042` | 编程器 GUI |
| **BitWizard CLI（实际在用的“Programmer CLI”）** | `G:\anlu\bin\bw_commands_prompt.exe` | 12,588,304 | `513B024C8C18`（与 10-16、10-19 证据中的 tool_sha256 相同） | `list_cable` / `download` |
| SVF→AJE | `G:\anlu\bin\svf2aje.exe` | 89,352 | `DDF670EBBE9B` | 转换（未使用） |
| hw server | `G:\anlu\bin\hwserver.exe` | 475,400 | `D3EB6BB5EBF6` | GUI 后端 |
| alps | `G:\anlu\bin\alps.exe` | 1,901,568 | `A6925C6BFF89` | 未在既有证据中出现 |
| TD GUI | `G:\anlu\bin\td.exe` | 114,448,144 | — | GUI |

文档：`G:\anlu\doc\SWUG\SWUG110_BitWizard_User_Guide.pdf`、`SWUG105_TCL_Command_User_Guide.pdf`。

**不存在 `td_programmer.exe`**：`G:\anlu\bin` 全列、`C:\Anlogic`/`D:\Anlogic`/`C:\Program Files*`（深度 6）搜索、`Get-Command td_programmer` 均为空。本机 TD 6.2.1 的编程器 CLI 就是 **BitWizard 的 `bw_commands_prompt.exe`**（`td_commands_prompt.exe` 只做工程/构建，不是编程器）。既有全部上板记录都走 bw，未出现 td_programmer。

## 2. 现有的硬件下载脚本（可直接复用为模板）

`D:\FPGA\EG4S20-Multimedia-Signage\output\hardware\hw_20261016T095019Z\`：

| 文件 | 内容要点 |
|---|---|
| `program_sram.tcl` (419 B) | `list_cable` + `download -bit {...} -mode jtag -spd 1 -cable 0` + `read_device_id -cable 0` |
| `program_sram.stdout.log` | `PRG-1000 : Connect device: 0:EG4S20BG256`；`bit_to_vec … -freq 0.200000`；`program -cable 0 -mode svf -spd 1 -p`；`SRAM_DOWNLOAD_RETURN`；`read_device_id → EG4S20BG256`；全程 51.2 s |
| `program_sram_status.json` | `state=PROGRAM_COMMAND_PASS`、`flash_written=false`、`exit_code=0` |
| `program_hdmi_tpg.tcl` / `.stdout.log` | 同结构，`-spd 3`，31.8 s |
| `program_sdram_*.tcl/.log/.json`、`reprogram_gaps05_powerloss_*.tcl` | 同一模板的多次复用 |

NoBot 侧：`D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\sram_01\sram.tcl|stdout.log`（`-spd 6`，7.1 s，`DOWNLOAD_RC=0`）、`jtag_preflight\read_id.tcl`（只 `read_device_id`）、`no_bot_retest_20261019T152547Z\sram.tcl`（7.4 s）。全部为 **volatile JTAG SRAM**，`persistent_flash_write=false`。

约定（从证据归纳，建议照抄）：
- tcl 里路径必须用**正斜杠**（`D:/…`）；反斜杠会被 TCL 当转义吃掉（本次实测 `C:\Users\...\Temp\x.tcl` 被解析成 `C:Users*760AppDataLocalTempot_...` 而失败）。
- 用 `-cable 0`；`-mode jtag` 是 SRAM；`-spd` 1/3/6 实测约 51 / 32 / 7 s（与 677 KB 位流）。
- 退出码用 `bw_commands_prompt.exe` 的 `%ERRORLEVEL%` + tcl 内 `catch` 双保险；证据里 status.json 记录 `exit_code`、`wall_seconds`、bit SHA256、tool SHA256。
- 切勿把 `program -mode svf` 当作“SRAM”；它出现在 `download` 的内部日志中。既有记录没有一次写 Flash。

## 3. 设备连接（本机现在，实测）

```
Get-PnpDevice → OK  USB  Anlogic usb cable v0.1   USB\VID_0547&PID_1002\7&2BAF49FB&0&3
```

本次只读枚举（`bw_commands_prompt.exe` + 临时 tcl，退出码 0）：

```
ENUM_BEGIN
list_cable            → PRG-1000 : Connect device:  0:EG4S20BG256     (0.051 s)
read_device_id -cable 0 → EG4S20BG256                                  (0.029 s)
ENUM_END              → BW_EXIT=0
```

结论：**下载线已插、板已上电、JTAG 链路正常，芯片 EG4S20BG256 可识别**。
注意：核查期间 `td_commands_prompt`（PID 50504，22:31 启动）正在运行（root 的构建）。bw 的只读枚举与之共存无异常，但**不要再启动第二个 TD/构建或并发 `download`**。

## 4. TF 卡可见性（本机现在）

- `Get-Disk`：仅 2 块 NVMe（BIWIN NV7400 2TB - Disk1；YMTC 953.9 GB - Disk0）。**无 USB 大容量存储设备**。
- `Get-Volume`：无 `Removable` 卷；仅有 C/D/E(Google Drive)/F/G/H 固定卷与 WINRE/SYSTEM 无盘符卷。
- `Get-PnpDevice`：`BayHubTech Integrated MMC/SD controller` 存在（板载读卡器），但**无介质**。
- 已知那张卡（10-19 记录）：`Generic USB STORAGE DEVICE`，Serial `000000001532`，62,531,305,472 B，FAT32，卷标 `ANLOGIC2026`，当时为 `K:`；`readback64MiB.img` = `no_bot_fat32.img`（`22f08ad1…0f9f`）。

**Root 修正：当前 Windows 未枚举到可读 TF 卷**。不能由此判断 FPGA 板槽是否插卡，也不能推断无画面：
- 板槽是否有卡及其实际内容仍需用户确认/后续安全读回；用户已确认板卡接好。
- 也不能在不插卡的情况下核对卡内容是否仍是 NoBot 布局。

## 5. 最小安全测试命令（按风险递增，均不写 Flash、不写卡）

### T0 只读枚举（0.1 s，推荐现在就可做）
`enum_only.tcl`（同目录已提供）：
```tcl
puts "ENUM_BEGIN"
if {[catch {list_cable} c]} { puts stderr "LIST_CABLE_ERROR $c"; exit 2 }
puts "LIST_CABLE_RETURN $c"
if {[catch {read_device_id -cable 0} d]} { puts stderr "READ_ID_ERROR $d"; exit 3 }
puts "READ_ID_RETURN $d"
puts "ENUM_END"
exit 0
```
```powershell
& 'G:\anlu\bin\bw_commands_prompt.exe' 'C:/Users/52760/AppData/Local/Temp/enum_only.tcl'
```
期望：`0:EG4S20BG256`、`READ_ID_RETURN EG4S20BG256`、退出码 0。（本次已实测通过。）

### T1 只读核对卡内容（插卡后，前提：卡在读卡器、盘符如 K:）
不挂载写入、不算哈希整卡：
```powershell
# 1) 卡身份与容量
Get-Disk | Where-Object BusType -eq 'USB' | Select Number,FriendlyName,SerialNumber,@{n='GB';e={[math]::Round($_.Size/1GB,2)}}
# 2) 前 64 MiB 只读快照并与预期比较（不写入）
$p='\\.\PhysicalDriveN'   # 上一步得到的 USB 盘号；先确认 IsBoot/IsSystem 为 false
$fs=[IO.File]::Open($p,'Open','Read','ReadWrite')
$buf=New-Object byte[] 67108864; $null=$fs.Read($buf,0,$buf.Length); $fs.Close()
(Get-FileHash -InputStream ([IO.MemoryStream]::new($buf)) -Algorithm SHA256).Hash
```
预期：NoBot 布局 → `22f08ad1…0f9f`；旧 Bot HFXL 布局 → 文件字节应与 `unified_003adc1b_v2.img` 的 6 段一致（整卡前 64 MiB 哈希不必等于镜像，实卡曾为 `d7d07b92…fbf9`，因 FAT 布局不同）。

### T2 下载探针位流到 SRAM（仅在明确授权、卡已插好、板已上电时）
```tcl
list_cable
if {[catch {download -bit {D:/FPGA/EG4S20-Bot-HDMIProbe/output/.../hx4s20_basic.bit} -mode jtag -spd 3 -cable 0} r]} {puts stderr "PROGRAM_ERROR $r"; exit 1}
puts "DOWNLOAD_OK"
read_device_id -cable 0
exit 0
```
- 用**移植后的 probe 位流**，勿用 NoBot 交付位流 `bbb83a71…` 之外的旧 bit 混淆结论。
- `-mode jtag` = 掉电丢失；不写 Flash。
- 预计 7 s（`-spd 6`）/32 s（`-spd 3`）/51 s（`-spd 1`）。
- 页 5 心跳、页 2 有效视频、页 1 locked 的判读顺序见 NoBot `docs/HDMI_PROBE.md`（本次不重复）。

## 6. 是否需要备用卡：**需要，建议两块**

理由（全部有证据）：
1. 两种固件要求**互斥的卡内容**（HFXL 六页 vs 10 张普通 BMP），见 `MEDIA_COMPATIBILITY.md`。唯一那张 64 GB 卡现在装的是 NoBot 布局（`22f08ad1…` 精确回读），而它是 NoBot 侧**唯一已上板工作过的媒体**（10-19 人工报告“旧版 ext_full_005 画面和声音恢复”，同一张卡）。
2. 若把这张卡改写成 HFXL，就破坏了已确认可用的 NoBot 基线；虽然可以从 `no_bot_fat32.img` 精确恢复（哈希固定），但会多一次不可并行验证的写入窗口。
3. 两块卡可做同板 A/B：同一 probe 位流、同一台显示器，只换卡，就能把“无画面”归因到固件/媒体之一。

- 卡 A（保持现状）= NoBot 布局：`no_bot_fat32.img`（`22f08ad1…`），可随时重建。
- 卡 B（新/备用）= 旧 Bot HFXL 布局：`unified_003adc1b_v2.img`，或 `card_before\files\UI01..UI06.BMP + 07_MUSIC.WAV`（与实卡字节一致，含 `manifest.json` 哈希）。普通拷贝后必须复核物理顺序/首 LBA 在 0..131071 且 6 个 HFXL 头页序正确；顺序与文件名本身不构成证据。
- 若只有一张卡：HFXL 与 NoBot 布局都可无损重建（两侧镜像/文件都在），但**改写属于“改 TF”操作，需 root 明确授权**，不在本次范围。

## 7. 遗留不确定项

- `alps.exe` 的确切产品名/用途未核实（TD 文档目录无对应 SWUG；本次未运行它）。
- 本次只读枚举时板子在线，但**未读取 SRAM 中当前是哪一版位流**（设计无回读通道）。
- `post_unlock64MiB.img`（`0707992a…`）与 `readback64MiB.img` 不同的原因未核实（推测为卷解锁/重挂载后的快照），与媒体兼容性判断无关。
- Root 修正：旧 observations.json 的 PENDING/FAIL 不得覆盖用户本轮给出的明确事实。42de1db 对应 hdmi_probe_001.bit（SHA256 bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618）已实板六页、音频、断电重启通过；原始 NoBot 无探针仍按黑屏无声记录。
