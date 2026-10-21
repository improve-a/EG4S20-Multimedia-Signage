# infer_add on→off 独立输入验收（只读）

**结论：输入级 PASS。** 新包 `bot_hdmi_probe_infer_add_off_001_source.zip` 相对基线
`bot_hdmi_probe_001_source.zip`，除允许的 `design.infer_add` 由 on 改为 off（`.al` 两个层级各一个
`off` 节点）以及 `.al` 的 Project Path 重定位外，**132 个非 `.al` 设计输入、6 个 harness 脚本、
PLL 参数、探针属性、约束和所有其他工程属性均逐字节相同**。未发现任何隐藏的 HDL、约束、素材或
harness 改动。

本验收仅针对**静态输入**；不评价本次构建是否成功、时序/资源是否收敛，也不代表任何硬件结果。

---

## 0. 边界与操作

- 主机：Windows `thinkpad`（SSH）。
- 只读：仅执行 `Get-ChildItem`、`Get-FileHash`、`ZipFile.OpenRead`、ZIP 条目流哈希/文本扫描。
- **未读取 `status.json`，未检查 TD 构建进度，未运行 TD/构建，未操作硬件/烧录，未修改任何 Windows 文件。**
- 未做递归委托。
- 本地仅写入 `bot_probe_infer_source_audit/`。
- 当前 TD 构建运行中，本报告与之无交互。

---

## 1. 对象与包级哈希

| 对象 | 字节 | 条目 | SHA-256 |
|---|---:|---:|---|
| 基线 `artifacts\bot_hdmi_probe_001_source.zip` | 542489 | 143 | `be64885e449a530ef76c104db3acc3a98513c6b9427950ec9753b62fc940c248` |
| 新包 `artifacts\bot_hdmi_probe_infer_add_off_001_source.zip` | 546584 | 145 | `509746e9f247c1f6dab43fedb6b1e2d97c63b0ae1b3bc0c5bdaabff821b83eba` |

两包均无重复 ZIP 条目名（duplicate entry names = 0），不存在用同名条目覆盖差异的情况。
条目按解压后内容逐条计算 SHA-256，不是只比 ZIP 目录或时间戳。

---

## 2. 集合比较结果

| 项目 | 基线 | 新包 | 结论 |
|---|---:|---:|---|
| 总条目 | 143 | 145 | 新增 2 个 audit 元数据文件 |
| `work/design/` 条目 | 133 | 133 | 无增删 |
| 其中非 `.al` 设计输入 | 132 | 132 | **132/132 SHA-256 与字节数完全相同** |
| `harness/` 脚本 | 6 | 6 | **6/6 逐字节相同** |
| `audit/` 元数据 | 4 | 6 | 3 个相同，1 个更新，2 个新增 |
| 共同且完全相同文件 | — | — | **141**（132 设计输入 + 6 harness + 3 audit） |

- `ONLY_IN_BASELINE`：**无**。没有删除任何工作输入。
- `ONLY_IN_NEW`：仅 `audit/infer_add_audit.json`、`audit/infer_add_only.diff`（构建方审计记录，非设计输入）。
- 共同但不同：仅
  - `work/design/td_project/hx4s20_basic.al`（允许的选项与路径变化）
  - `audit/baseline_manifest.json`（包元数据，记录本次 run_id/commit/selected 哈希，非构建输入）

`audit/baseline_manifest.json` 的 `selected` 列表覆盖全部 133 个 `work/design/` 条目；
逐项核对后**只有 `.al` 一项哈希/字节数不同**，其余 132 项与基线清单一致。
该 manifest 的 `snapshot_sha256` 可由其 `selected` 列表独立重算并吻合（基线
`3f34a1d1…`、新包 `80ea8f68…`）。

---

## 3. `.al`：只有允许的三处变化

文本 diff 仅 3 个 hunk：

1. `<Project … Path="…/builds/bot_hdmi_probe_001/work/design/td_project">`
   → `…/builds/bot_hdmi_probe_infer_add_off_001/work/design/td_project`
2. `<Property>` 下新增
   ```xml
   <DesignProperty>
       <infer_add>off</infer_add>
   </DesignProperty>
   ```
3. `<Run Name="syn_1" …><Strategy Name="Default_Synthesis_Strategy">` 下新增同一个
   `<DesignProperty><infer_add>off</infer_add></DesignProperty>`。

强证据：

- **字节级重构**：取基线 `.al`，只做“Project Path 替换一次 + 上述两个节点块各插入一次”，
  得到的结果与新 `.al` **逐字节完全相等**（33112 字节；基线 32894 字节）。
- **XML 结构比较**：忽略 `Project/@Path` 和这两个 `infer_add` 节点后，两侧规范化 XML 树完全相同。
  即设备设置、Runs/Strategy、约束集、源文件清单、CompileOrder、UserParams 等所有其他工程属性均未变。
- 新 `.al` 中唯一一个绝对 `D:/` 路径就是 `Project/@Path`；所有源文件和约束路径仍是
  `../user_source/...` 相对路径，没有隐藏的项目根重写。
- 对所有 `work/design/` 与 `harness/` 文本扫描，只有 `.al` 中这 **2 个** `infer_add` 节点，值均为 `off`；
  设计输入与 harness 中没有 `on`，也没有第三处 `infer_add` 设置（audit JSON 里的 `only_option` 等字样是元数据，不是设置）。
- `audit/infer_add_only.diff` 与用 Python `difflib.unified_diff` 对两侧 `.al` 生成的结果**逐字节相等**（1175 字节）。

> 注：TD 生成的 `.al` 在 `UsedInP&R` 属性中有未转义的 `&`，本身不是严格良构 XML；两侧都有该写法。
> 上面的结构比较仅对该 token 做了解析转义；字节级重构才是权威结论。

---

## 4. 132 个非 `.al` 设计输入

分类（均位于 `work/design/`）：

| 类别 | 数量 |
|---|---:|
| Verilog `.v` | 79 |
| 加密 Verilog `.enc.v` | 4 |
| VHDL `.vhd` | 5 |
| include `.vh` | 1 |
| IP Tcl `.tcl` | 3 |
| IP 配置 `.ipc` | 6 |
| ROM 素材 `.hex` / `.hex.bin` | 30 |
| 素材 manifest `.json` | 1 |
| 约束 `.adc` | 1 |
| 约束 `.cwc` | 1 |
| 约束 `.sdc` | 1 |
| 工程 `.al` | 1 |
| **合计** | **133** |

排除 `.al` 后 **132 个输入全部 SHA-256 与字节数相同**。关键文件：

| 文件 | 字节 | SHA-256（两侧相同） |
|---|---:|---|
| `hdl_source/top_tf_hdmi_audio.v` | 26069 | `8a867d43e85619359e0fb0aad033b07ed2dfb038ebe7d0b58e2e165b07f0d144` |
| `hdl_source/ext/hdmi_probe.v` | 5175 | `f9e820e62d2abb204e2467e4c4f6791817d0adfb042e40b0399a660be9bbcf25` |
| `constraints_source/pin.adc` | 5533 | `ae389336106ded640427eb1af73adec46b6ce13d9c07808577533c953a95b6c1` |
| `constraints_source/timing.sdc` | 3083 | `93d101bdc89fa6ddb75ba17edb7c42bc04dd3eeecade0a649bfafa0a966e4051` |
| `constraints_source/edid_debug.cwc` | 59256 | `6716411e2346de08976e0ad8ed2e09eb93bdc0f60efc31bf75ba70e6cebe1f95` |
| `IP/sys_pll.v` | 2527 | `02da17afa1b3f23c880254924437b9529ef7ab872b888073fce43d3dce07a4f6` |
| `IP/video_pll.v` | 2349 | `57e45a062814673e97773cf6c58ff1629fa45895e30de9d2c2b6bdd30bd9bb13` |
| `td_project/al_ip/PLL.v` | 2438 | `4e873eef9499fa93508d8cf2cac90eea0e16c6f649ae29502cdc4c5886cd32aa` |
| `td_project/al_ip/PLL.ipc` | 1511 | `8cb6df3a1bb99cf2f95f9a535d7f33213b837207b36e336848a6ed0db29ab8b5` |

没有新增、删除或重命名任何 `work/design/` 输入。
对 132 项按“路径 + NUL + 内容 SHA-256 + LF”排序后计算集合指纹，两侧均为
`7294910866d8bc547b5cf4b380250f5d250d97f5b5ef641823f84b2e8492aec8`；
6 个 harness 的集合指纹两侧均为 `abdd370d31e706692e4e81021e835ac02704deade3a49332f574bfba13c62289`。

---

## 5. PLL 参数与探针属性

### PLL（9 个相关文件全部相同：`sys_pll`、`video_pll` 的 `.v/.vhd/.ipc`，`al_ip/PLL` 的 `.v/.vhd/.ipc`）

| PLL | 输入 | 倍频/分频 | 输出 | 关键参数 |
|---|---|---|---|---|
| `sys_pll` | 50 MHz | ×2 / ÷1 | C0 100 MHz 0°，C1 125 MHz 0°，C2 125 MHz 180° | GMC_GAIN=4, ICP=29, KVCO=4, LPF_CAP=1, LPF_RES=2, REFCLK_DIV=1, FBCLK_DIV=2 |
| `video_pll` | 50 MHz | ×1 / ÷2 | C0 25 MHz 0°，C1 125 MHz 0° | GMC_GAIN=2, ICP=9, KVCO=2, LPF_CAP=1, LPF_RES=8, REFCLK_DIV=2, FBCLK_DIV=1 |
| `al_ip/PLL.ipc` | 50 MHz | ÷2 / ×3 | C0 75 MHz 0°，C1 375 MHz 90° | Bandwidth=Medium, feedback=Normal |

### 探针

`hdl_source/ext/hdmi_probe.v` 两侧逐字节相同（5175 字节，SHA-256 `f9e820e6…`，与已验收 donor 记录一致）。
文件内只有 1 个属性块，原样保留：

```verilog
(* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;
```

未因本次选项改变而移除、改写或重新命名任何探针属性。

---

## 6. INIT_FILE 与素材资产

- 新包 HDL 中所有绝对 `INIT_FILE` / `BODY_FILE` / `GLYPH_FILE` / `*_FILE` 路径**仍指向原
  `builds/bot_hdmi_probe_001/.../html_assets`**，没有改到 `infer_add_off_001` 新目录。
- manifest 明确列出的 12 个外部素材：逐个 `Get-FileHash` 与清单哈希比对，**12/12 OK**。
- 更严格的全量检查：ZIP 内 `html_assets/` 的 **33 个文件**（含所有 `.hex`、`.hex.bin`、
  `html_caption_map.v`、`html_layer_layout.vh`、`layer_roms_manifest.json`）与磁盘上原
  `_001` 构建目录中的对应文件逐一比对，**33/33 存在且哈希/字节数 OK，0 缺失/0 不匹配**。
- 因此 `.hex` 及其 `.bin` 伴随文件都属于原 `_001` 已验收资产；本次没有重新生成 ROM，也没有把
  INIT_FILE 指向新构建目录。

---

## 7. Harness 脚本

`harness/` 共 6 个文件，**6/6 逐字节相同**：

- `build.tcl`（3874 字节，SHA-256 `435659587ebe31f08015f459076840825c886ccca8e8cdeac0a1e0e5a95b4a47`）
  与上轮 `collected.json` 的 `tcl_sha256`、本地 `bot_build_reference.tcl` 一致。
- 其余 `report_parser.py`、`synth_probe.tcl`、`test_runner.py`、`windows_job.py`、`windows_runner.py`
  也全部相同。
- `build.tcl` 不读取 `infer_add`、`baseline_manifest.json` 或新增的 audit 文件；它只
  `open_project hx4s20_basic.al`，然后按原流程跑 `syn_1` / `phy_1`。新增 audit 文件不在构建输入路径内。

---

## 8. TD 完整参数：仅 infer_add 一行不同

本地 `bot_probe/default_params.txt` 与 `bot_probe/off_params.txt` 都是 `report_param -all -detail`
的完整输出，各 **309 行**，覆盖 `flow / rtl / gate / place / route / timing / sim / bitgen`
全部阶段。

统一 diff 只有一行：

```diff
-              infer_add              |       on        |       on        |
+              infer_add              |       off       |       on        |   *
```

即：当前值 on → off；默认值仍为 on；`*` 表示非默认。**除此之外没有任何参数差异**。
`query_off.txt` 记录的设置为：

```
set_param design infer_add off -run syn_1
PRJ-1105 : Update param syn_1 design::infer_add::off succeed.
set_param rtl infer_add off
```

随后 `report_param` 输出为 off，与 `.al` 中两个层级的 `off` 节点一致。

---

## 9. 与初始 Bot + Probe 移植的身份链（不重审前轮）

- 基线 `bot_hdmi_probe_001_source.zip` SHA-256 `be64885e…` 与上轮交付记录
  （`bot_probe/RESULT.md`、`collected.json`、`bot_probe_audit/BOT_PROBE_ACCEPTANCE.md`）一致；
  本报告只引用该基线身份，不重新审计其 HDL/探针功能正确性。
- 基线 manifest：`git_commit = 9a27bbe73079d987bb4592b6a724b07cc33e5d9e`；
  其实验 `baseline_commit = 20871da98664b2b674fbcfe94a713359ff9614a1`（旧 Bot 交付）；
  probe donor `42de1dbe4a20ca78f28be54c4bf41bd0dd814481`，donor ZIP
  `5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f`，
  probe SHA-256 `f9e820e6…`。
- 新包 manifest/audit：`baseline_sha256 = be64885e…`，`baseline_commit = 9a27bbe…`，
  `source_commit = 297d1b64130d32704e3c50a6e5ab5c85c68d42a9`（与本地
  `infer_prepare.txt` / `infer_add_off.json` 一致）。
- 新包的 `audit/bot_probe_audit.json` 与基线**逐字节相同**（旧 Bot 基线、probe donor、
  signal_adaptations 为空、probe_sha256 均相同）；`audit/scope.json` 与 `audit/probe_only.diff`
  也与基线逐字节相同。
- 新包 `audit/infer_add_audit.json` 的内容等于 `baseline_manifest.json` 的 `experiment` 字段，
  且其 `config` 与本地 `bot_probe/infer_add_off.json` 完全一致。
- 结论：新包就是同一初始 Bot + 已验证 Probe 移植包的受控派生；唯一实验变量是
  `design.infer_add on→off`。未发现身份被替换或夹带其他改动。

---

## 10. 不声称 / 限制

1. 本报告是**静态输入验收**；没有位流、没有综合/布局/时序/资源结论，也没有硬件结果。
2. 当前 TD 构建运行中；**没有读取 `status.json`，没有检查进度**，因此不对该构建作任何判断。
3. 没有重做前轮的 HDL/探针功能审计；以“与已验收基线逐字节相同”作为输入身份依据。
4. `default_params.txt` / `off_params.txt` 是此前从同一工程捕获的 TD 参数快照，本次未重新运行 TD 捕获。
5. `audit/baseline_manifest.json` 的变化是包元数据（run_id、时间、commit、selected 哈希、experiment 字段）；
   两个新增 `infer_add_*` 文件也是审计记录。它们不是构建输入，`build.tcl` 不引用。
6. `.al` 的 `UsedInP&R` 未转义 `&` 是 TD 既有写法，两侧相同；不影响上述字节级结论。

---

## 11. 证据文件（本目录）

- `acceptance.json`：机器可读结论与哈希。
- `zip_manifest_raw.txt`：两包逐条目长度/SHA-256 清单及集合比较。
- `zip_text_raw.txt` + `extracted/`：关键条目的 Base64 原样提取（`.al`、manifest、audit、PLL、probe、build.tcl）。
- `al.diff` / `td_params.diff`：仅有的两处 diff。
- `initfile_scan.txt`：全包 `INIT_FILE` / `_001` 路径扫描（含行号）。
- `asset_hash_check.txt`：manifest 12 个外部素材的磁盘哈希核对。
- `assets_all_check.txt`：ZIP 内 33 个 `html_assets` 与磁盘 `_001` 资产的全量核对（33/33 OK）。
- `infer_scan.txt`：全包 `infer_add` 字符串扫描（仅 `.al` 两个 off 节点及 audit 记录）。
- `windows_*.ps1`：只读核验脚本；均通过 SSH stdin 执行，未落盘到 Windows。

---

## 12. 最终判定

**输入级通过。** 在允许范围内：
`design.infer_add` 由 on 改为 off；`.al` Project Path 重定位；
其余 132 个非 `.al` 设计输入、6 个 harness 脚本、全部 PLL 参数、探针属性、约束、素材和
所有其他工程属性均与基线逐字节一致。可以作为“唯一实验变量为 infer_add”的输入包接受。
