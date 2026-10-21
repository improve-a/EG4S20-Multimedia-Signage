# worker_a 目录索引

- `SUMMARY.md` —— 勘误版精简摘要（先读这个）
- `REPORT.md` —— 主报告（中文，含结论、逐层数据、别名/功能差异清单、实验建议）
- `evidence.json` —— 紧凑机读证据（构建哈希、资源、FF 总账、别名、物理指标）
- `run_remote.sh` —— 可复现的远端只读流程（复制 gate.db → `write_verilog` → Python 对比）

## 脚本（Python 3，需在含 `a_gate.v`/`b_gate.v` 的目录运行）

| 脚本 | 作用 |
|---|---|
| `netcmp.py` | 解析 TD `write_verilog` 网表；`summary` / `seq` / `net` / `const` |
| `seqdiff.py` | 按层次比较 `AL_MAP_SEQ` 的名字与 D/Q/CE/SR 引脚 |
| `listseq.py` | 列出某层次的 FF 清单 |
| `ffsum.py` | 全设计及逐层 FF 相同/改名/增删统计 |
| `subtree.py` | 子树级 FF 统计（HDMI 核/PHY/音频等） |
| `pindiff.py` / `pduniq.py` | 展示/归并 FF 引脚差异，确认是否只是网名 |
| `cmpcells.py` | 全单元名字级相同/新增/变化统计（含 LUT/BRAM） |
| `luthist.py` | 按层次比较 LUT 类型+INIT 形状的多重集 |
| `cone.py` / `leaves.py` | 组合锥展开 / 叶节点集合（用于别名与重分解判定） |
| `brampins.py` | 打印 FIFO BRAM 的 addra/addrb/ceb/dia/dob/rsta/rstb 连接 |
| `toplist.py` | 列出顶层（无层次前缀）的 FF |
| `findnet.py` | 按子串检索网表行（网名、端口、注释） |
| `fanout.py` | 某网的驱动/全部消费引脚，`--outside HIER` 标出层次外负载（查观察锥是否移除） |
| `obs_check.py` | 探针观测锥检查：status FF 数、`probe/flags` 位引用、locked 精确负载 |
| `cone_tt.py` | 小组合锥真值表穷举（仅 LUT1-5/BUF/SEQ） |
| `regstats.py` / `paramhist.py` / `inspect_cells.py` | 寄存器/参数/单元样例辅助 |

## `ps/`（远端 PowerShell / Tcl 生成脚本）

- `t00_env.ps1` 环境与目录存在性
- `t01..t39` 逐步取证：文件清单、源码 SHA、工程设置、area/qor、日志、TD 命令探测、`gate.db` 复制、`write_verilog` 导出等
- `mk_tcl_dump.ps1` / `mk_tcl_dump_b.ps1` 生成并执行 `dump_a.tcl` / `dump_b.tcl`（**只读导出，无综合/布局/布线/bitgen**）
- `export_gate_v.ps1` / `export_gate_v.tcl` 通用导出：`-Db <gate.db 副本> -Out <gate.v>`，只做 import/write_verilog

## `evidence/`（明细文本，约 0.5 MB）

关键文件：
- `area_A_GATE.txt` / `area_B_GATE.txt` / `area_A_PHY.txt` / `area_B_PHY.txt` —— TD 层级面积（seq/lut/bram/dsp）
- `ffsum.txt` —— FF 总账；`subtree.txt` —— HDMI 核/PHY/音频子树
- `seq_rgb.txt`、`seq_rx.txt`、`seq_osd.txt`、`seq_vid.txt`、`toplist.txt` —— 逐 FF 差异
- `bram.txt` —— FIFO BRAM 连接（A/B 对照）
- `luthist*.txt` —— LUT 形状对比
- `pduniq.txt` —— 175 处引脚差异的归并（audio_valid 62、wav CE 32、sd CE 75、探针别名 6）
- `srchash.txt` / `topdiff.txt` / `synlog_grep.txt` —— 源码快照差异与综合日志
- `qor.txt` —— gate/place/route QoR
- `c_u_a.txt` / `c_u_b.txt` —— tuser(SOF) 组合锥逐节点对照（除名字外相同）
- `fn_*.txt`、`f45.txt`、`f56.txt`、`sir.txt`、`rsv.txt`、`dvs.txt`、`tri.txt` —— 关键网/端口的原始行
- `tt_user.txt` / `tt_locked.txt` —— 两个小锥的穷举真值表结果
- `obs_a3.txt` / `obs_b3.txt` —— 观察锥基线检查（status FF 31/31、locked 负载 10）
- `fan_locked.txt` / `fan_meta.txt` / `fan_outside.txt` —— 负载检查样例
- `src/top_nobot.v`、`src/probe_mods.v` —— 关键 RTL 快照摘录（只读副本）

> 两份 8.5/8.8 MB 的门级网表**未回传本机**，只存在于 ThinkPad scratch 目录，符合“不要下载大型网表到 Mac、远端分析”的要求。
