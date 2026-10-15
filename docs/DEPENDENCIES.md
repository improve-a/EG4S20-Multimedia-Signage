# 本地依赖与公开边界

用户在本次 GitHub Harness 中选择：仅发布可确认的自研代码、测试和素材，官方依赖本地补齐。
因此不推送原库历史，也不通过 ZIP、bundle、bitstream、测试输入归档等方式间接公开官方实现。

`local_dependencies.json` 逐文件列出 59 项路径、大小、SHA256。范围包括：

- `rtl/IP/`、`project/td_project/al_ip/`：厂商生成的 PLL/FIFO/SDRAM IP 和配置。
- `rtl/hdmi1.4b_transmitter_core/`、`rtl/include/`：官方 HDMI/SDRAM 加密实现及头文件。
- `rtl/SD/`：官方 TF/SPI/BMP/SDRAM 基线及项目定向修改，保留本地精确派生版本。
- `rtl/top_tf_hdmi_audio.v`、时钟、HDMI PHY/LVDS、消抖、启动脉冲、视频接口、
  音阶与 ACR 等官方原件或派生实现。不能仅凭“修改过”认定可公开发布。
- `tb/vendor_public/*.v`：从 TD `sim_release/eg4` 提取的可读仿真模块。
  目录名的 public 指可读内容，不是已取得公开再分发授权。
- `.cwc` 调试配置：非必要公开成果，保留本地。

现有厂商头含 Copyright / All Right Reserved；当前资料中没有核实到 Public 再分发授权。
本清单记录工程依赖，不替代厂商许可。字体是单独核实的例外，其 OFL 原文与来源随公开素材保留。

## 在当前 Mac 恢复完整开发环境

原仓库 `../hx4s20_extensions` 保持完整，冻结提交为
`c16d3da56c8ae175f675c112cfdd4bdc5f2c0fb6`。从新仓库根执行：

```sh
python3 scripts/local_dependencies.py --source ../hx4s20_extensions
python3 scripts/local_dependencies.py --check
```

脚本先检查全部输入，只有每项符合清单后才复制缺失文件；不覆盖不匹配的现有文件，
不联网、不下载工具、不操作卡或硬件。补齐的文件被 `.gitignore` 逐项排除，
有效自研模块、测试及约束仍照常跟踪。更新本地依赖后应重新核对来源、清单和测试范围。

其他使用者需通过合法途径取得官方例程和相应项目派生版本。
**只下载官方 Lab4/Lab5 不足以精确复现已修改的存储/顶层版本**；
缺少清单所列派生文件时，不能声称已完整复现。当前不提供这些文件的公开下载地址。

## 只准备 TD 快照，不启动构建

```sh
python3 scripts/local_dependencies.py --check
python3 scripts/prepare_snapshot.py gui_YYYYMMDD_01
```

生成 `artifacts/gui_YYYYMMDD_01_source.zip`，该 ZIP 含本地官方依赖，仅供当前合法开发环境。
经已有 SSH 复制到 Windows 的全新 NTFS 目录并解压，打开其中
`work/design/td_project/hx4s20_basic.al`；`Project Path` 写为
`D:/FPGA/hx4s20_extensions_20261013/builds/gui_YYYYMMDD_01/work/design/td_project`，
故解压根应对应这个 `builds/gui_YYYYMMDD_01` 目录。
不要提交生成的源码 ZIP，不在 Google Drive 内构建。GUI 启动综合/布局布线仍算一次真实构建。

## 发布时排除的其他内容

旧完整 `.git` 历史、源码 bundle/ZIP、厂商资料、配置位流和编译 DB 都保留本地。
TD Runs、仿真执行文件/波形、临时日志与 Python 缓存不纳入；当前已核实的构建摘要、
时序报告及测试结果按明确路径保留。物理 TF 备份、长测 184 MB WAV、原始磁盘镜像、
设备序列号和个人验收原文不公开。可复现 UI/BMP/WAV、字库许可和有价值测试向量纳入。
