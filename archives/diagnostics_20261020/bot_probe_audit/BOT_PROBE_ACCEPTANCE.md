# Bot-HDMIProbe 输入只读验收（2026-10-20）

范围：**仅静态源**。只读两个 source ZIP 的内容与 Git 对象；**未读取 `status.json`、未检查 TD 进程/构建状态、
未重新导出综合网表、未构建、未操作硬件、未修改任何 Windows 文件**。所有比较在内存中完成。

前稿 `PROBE_HDL_AUDIT.md` 已按要求修正一处未经证明的因果断言（见第 8 节）。

---

## 1. 被验收对象

| 对象 | SHA-256 | 条目 |
|---|---|---|
| 新输入 `D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip` | `be64885e449a530ef76c104db3acc3a98513c6b9427950ec9753b62fc940c248` | 143 |
| 基线 `D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip` | `2923dfe9667f1cb1472c87ae52e47fae743dda64054cb1978578decc2a4d84c3` | 140 |
| 探针 donor `D:\FPGA\EG4S20-NoBot-HDMIProbe\artifacts\hdmi_probe_001_source.zip` | `5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f` | — |

基线与 donor 的 SHA-256 与 `audit/bot_probe_audit.json`、`EXPERIMENT.md` 记录一致。

ZIP 内 `audit/bot_probe_audit.json` 自述：`baseline_commit 20871da…`、`git_commit 9a27bbe…`、
`probe_delivery 42de1db…`、`probe_sha256 f9e820e6…`、`signal_adaptations: []`、
`relocation_only: D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02`。

Git 对象只读核对（`cat-file`/`show -s`，未用 `status`）：`9a27bbe73079d987bb4592b6a724b07cc33e5d9e`
存在于 `EG4S20-Bot-HDMIProbe`，父提交 `20871da…`，标题
`Add controlled old-Bot proven HDMI Probe build recipe`。该提交树中**不含** `hdmi_probe.v`
（探针源在 prepare 时从 donor ZIP 注入），符合“私有派生 HDL 不入 Git”的既定做法。

---

## 2. 方法

1. `ZipFile.OpenRead` 逐条读入内存，按 ZIP 内的相对路径建表。
2. 归一：把两侧各自的构建根绝对路径（`.../builds/<run>/work/design`，正反斜杠两种写法）替换为 `<ROOT>`，
   并把 CRLF 统一为 LF。**只**归一这两个维度，其他任何差异都会保留。
3. 集合比较 + 逐文件字节比较 + 归一后文本比较。
4. 对两个"应当只差探针"的文件做**逆变换证明**：从新文件里撤掉探针改动，结果必须与基线**逐字符相等**。
5. 探针与 donor 的等价性：文件 SHA-256 + 顶层探针块文本 SHA-256 + `.locked` 连接行 + 属性行。

---

## 3. 文件集合

```
新 143 = 基线 140 + 3
ONLY_IN_BASELINE: (无)   ← 没有任何旧文件被删除
ONLY_IN_NEW:
  work/design/user_source/hdl_source/ext/hdmi_probe.v   ← 唯一新增的设计输入
  audit/bot_probe_audit.json                            ← 构建方自审计记录（非设计输入）
  audit/probe_only.diff                                 ← 构建方差异记录（非设计输入）
```

`work/design/user_source/hdl_source/` 共 126 个条目（基线 125），差值即 `ext/hdmi_probe.v`。
分布（新 / 基线）：`hdl_source/` 根 14 / 14，`ext/` 递归 70 → 71（其中 `ext/*.v` 37 → 38，新增项即
`hdmi_probe.v`；`ext/html_assets/` 33 / 33 不变），`SD/` 17 / 17，`IP/` 19 / 19，`include/` 4 / 4，
加密核目录 1 / 1，`constraints_source/` 3 / 3，`td_project/al_ip` 3 / 3。

---

## 4. 归一后的差异：只有 Probe 三项

140 个共有文件中：字节相同 129，字节不同 11。归一后：

```
归一后相等 137 / 仅换行不同 0 / 内容不同 3
内容不同：
  work/design/user_source/hdl_source/top_tf_hdmi_audio.v      ← Probe 项 1
  work/design/td_project/hx4s20_basic.al                      ← Probe 项 2
  audit/baseline_manifest.json                                ← 构建方清单（见第 7 节）
```

11 个字节不同的文件里，除上述 3 个外，其余 **8 个仅差构建根路径**（归一后完全相等，连行数都相同）：

```
ext/html_bot_overlay.v          ext/html_caption_column_rom.v   ext/html_eye_radius_rom.v
ext/html_layer_descriptor_rom.v ext/html_layer_palette.v        ext/html_osd_overlay.v
ext/html_osd_swap_rom.v         ext/html_scene_motion.v
```

即：ROM/OSD/Motion 的 `INIT_FILE` 与 `html_bot_overlay` 的路径参数被重定位，**资产内容未动**。

---

## 5. 逆变换证明（本次验收的核心依据）

### 5.1 顶层

对新顶层依次撤销三处探针改动：

1. `.O_video_locked     (probe_video_locked),` → `.O_video_locked     (),`
2. 把从 `// Read-only video-clock probes` 到下一个 `// ====` 的整块，替换回基线的
   `seg_decoder seg_decoder_m0(` … 到其下一个 `// ====` 的整块
3. 删除 `wire        probe_video_locked;` 一行

结果：

```
rebuilt-equals-baseline: True   rebuiltLen=25046 baselineLen=25046
```

新顶层 607 行、基线 597 行（+10 行 = 声明 1 行 + 探针块相对原块净增 9 行）。
**除这三处外，顶层与基线逐字符相同**——包括全部 Bot 模块实例、音频链、缓存/帧缓存、SDRAM、PLL、引脚。

### 5.2 工程文件 `.al`

```
entry present exactly once: True
al rebuilt-equals-baseline: True   len=32441 vs 32441
```

即新 `.al` = 基线 `.al` + 恰好 8 行的 `hdmi_probe.v` 条目，其余（含 `Path`、`CompileOrder` 序列、
源文件顺序、`al_ip`、ADC/SDC 引用）完全相同。

```
基线 max CompileOrder = 95（81 条）   新 max = 96（82 条）
```

新条目的 `CompileOrder=96 = 95+1`，是**重新计算**追加，不是照抄 donor 的 59 / 42de1db 的 97。
条目写法与原生序列化一致：`UsedInSyn=true`、`UsedInP&R=true`（`&` 字面量）、`BelongTo=design_1`。

---

## 6. 探针与 donor 等价

| 检查 | 结果 |
|---|---|
| `ext/hdmi_probe.v` SHA-256 | `f9e820e62d2abb204e2467e4c4f6791817d0adfb042e40b0399a660be9bbcf25`，与 donor 构建输入**逐字节相同** |
| 顶层探针实例块（1216 字符）SHA-256 | 新 `59b2bb3cb450d32aa5edb7269b59be04593e697611d2a11b9f26e3a2d9ff78e2` = donor 同值 |
| `.O_video_locked     (probe_video_locked),` | 两侧都存在且文本相同 |
| `(* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;` | 新探针文件中存在，与 donor 同行 |
| 端口/参数常量 | 块级逐字符相同，故 `WINDOW_CYCLES/FRAME_PIXELS/LINE_PIXELS/PAGE_CYCLES`、11 个输入、5 个连线、6 位字模映射全部一致 |

因此"探针连接与属性等价 donor"成立，且是**字节级**而非结构级等价。

---

## 7. `audit/baseline_manifest.json` 的差异是派生的

该文件是构建方自己的输入清单，共 133 条 `path`，归一后 3 处差异全部为派生字段：

- `task_root` / `run_id`：`…Multimedia-Signage…`/`timing_fix_20261016_02` → `…Bot-HDMIProbe…`/`bot_hdmi_probe_001`；
- 各输入条目的 `sha256`/`bytes`：因为 8 个文件被重定位、顶层与 `.al` 变化而随之变化；
- 新增 1 条 `hdl_source/ext/hdmi_probe.v`（`sha256 f9e820e6…`、`bytes 5175`）。

133 = 130 未变 + 3 变化，这正是 Root `verification.txt` 里 `unchanged_count: 130` 的口径；
我这里的 137/140 是**整包**口径（额外包含 assets、IP、SD、harness 等）。两者不矛盾。

ZIP 内 `audit/probe_only.diff` 与 Root 本地 `bot_probe/probe_only.diff` **逐字节相同**
（SHA-256 `68ed4b4e219ca72f6fe03b52802d6a169c6e041655a0f93444fe0c6419d3a986`，75599 字节，5 个 hunk，1620 行）。

---

## 8. 保留性结论与对前稿的纠正

**保留**（由集合相等 + 逆变换共同保证，不是抽样）：

- 基线 140 个条目**全部存在**，无删除、无改名；
- 顶层除三处探针改动外**逐字符相同**，故 Bot 的全部功能实例（`html_bot_overlay`、`media_controls`、
  `audio_media`/`audio_output_mux`/`audio_pcm_player`/`audio_async_fifo`/`audio_visualizer`、
  `wav_stream_parser`、`html_layer_cache`、`html_layer_join_ram`、`html_layer_memory_bridge`、`html_memory_bridge`、
  `frame_config_bridge`、`media_sector_arbiter`、`video_transition`、`bmp_scale`、`exhibit_viewport`、
  OSD/HTML 各模块、HDMI 核与 PHY、SDRAM 控制器）及其参数**未变**；
- `constraints_source/pin.adc`、`timing.sdc` 字节相同（引脚与时钟约束未动）；
- 音频相关源文件全部字节相同（`audio_media.v`、`audio_output_mux.v`、`audio_pcm_player.v`、
  `audio_async_fifo.v`、`audio_visualizer.v`、`wav_stream_parser.v`）；
- 缓存/帧缓存源文件全部字节相同（`html_layer_cache.v`、`html_layer_join_ram.v`、
  `html_layer_memory_bridge.v`、`html_memory_bridge.v`）；
- `al_ip`、`IP/`、`SD/`、`include/`、加密核目录条目数与内容集合一致；
- 媒资 `ext/html_assets/` 33 个文件全部字节相同（未重生成 ROM）。

**对前稿的纠正**：`PROBE_HDL_AUDIT.md` 第 4 节原写"若删除 `preserve` 极易被合并/重定时，因此属性不是风格而是功能要求"。
这是**未经证明的因果断言**，现撤回并改写为：

- 事实：作者对唯一的 25 MHz→50 MHz 两级同步器写了 `async_reg` + `preserve`；本次新构建的探针文件与之逐字节相同，
  属性因此原样保留。移植时应逐字保留。
- 事实：映射网表中这些寄存器与功能逻辑**共处同一小片**（如 `\probe_display/status_meta_reg[0]_syn_4` 与
  `\frame_read_write_m0/frame_fifo_write_m0/add11_syn_60`、`\extensions/osd/lt171_syn_27`）。
- **不成立**：由此推断"两级寄存器被合并"，或推断"去掉属性就会合并"。两者都不是该观察能支撑的结论。
  要判定属性作用需带/不带属性的 A/B 综合，本轮未做，也不在本步骤范围内。

---

## 9. 本步骤**不能**证明的事项

1. 未看综合/PnR/STA/位流：本验收只覆盖"喂给工具的设计输入"，不涉及任何时序、资源或实现结论。
2. 探针必然改变实现负载：`O_video_locked`、`O_axis_s_ready`、`TLAST`、`fx_hs`、`audio_valid`
   从"无消费者/仅内部"变为"有观察负载"，旧数码管状态码显示锥失去唯一读者。这与 donor 的语义一致，
   但**新构建的物理结果不能等同于 bot 基线或 donor**。
3. 未验证 TD 是否已用该 ZIP 构建完成；未读取任何 `status.json`/日志。
4. `audit/` 下两个文件是构建方自述，本次只核对它们与本地副本一致、与我的独立结论一致，不把它们当作独立证据。

---

## 10. 证据索引（`bot_probe_audit/`）

| 结论 | 证据 |
|---|---|
| 条目集合、+3/‑0、11 个字节差异 | `41_zipcmp1.out` |
| 归一后 137 相等 / 3 内容差异 | `42_zipnorm.out` |
| 差异行明细（含 `.al` 仅 8 行条目、顶层三处） | `43_showdiff.out`（**注意**：脚本里 `Compare-Object` 的 `SideIndicator` 标签写反，"only in NEW" 一栏实为基线独有行） |
| 逆变换：顶层与 `.al` 撤掉探针后与基线逐字符相等 | `44_proof.out` |
| manifest 派生差异、关键输入 rawEqual、目录计数 | `45_manifest.out` |
| 目录分布 | `46_dirs.out`（其中本地路径探测误用了仓库内相对路径，显示 MISSING，可忽略） |
| `audit/probe_only.diff` 与 Root 本地副本逐字节相同 | `48_diffhash.out`：两侧 raw `68ed4b4e…` / norm `0ff57008…` / 75599 字节 / 832 个 CR |
| ZIP 内自审计 JSON 全文 | `47_auditjson.out` |
| 两个 ZIP 与 donor ZIP 的 SHA-256、Git 提交对象 | `49_identity.out` |
| manifest 133 条 = 130+3；`ext/` 与根级模块清单 | `50_reconcile.out` |

复跑方式（只读，不落文件）：

```bash
python3 bot_probe_audit/remote_ps_stdin.py bot_probe_audit/42_zipnorm.ps1
python3 bot_probe_audit/remote_ps_stdin.py bot_probe_audit/44_proof.ps1
```

`remote_ps_stdin.py` 把本地脚本经 stdin 管道给 thinkpad 上的 `powershell -NoProfile -Command -`，
不在远端创建任何文件。
