# Worker A 修订摘要（HDMI/AXIS，2026-10-20）

**结论**：没有可行动的 AXIS RTL 修复；不要加 `valid&=ready`，不要因 C/D 改 FIFO/加寄存器，也不要把“恢复 locked 观测”当新实验（那就是已 PASS 的 full Probe 同一 top）。`!locked` 的物理/STA 审计已在 `physical_review/` 完成：A/B 已报告路径正 slack（A removal min +1.971 ns，B +2.365 ns），但四角/旧/Probe 覆盖不完整，不能据此改 RTL。

## 关键更正

1. **`wea=valid` 不等于入队成功**
   - A/Probe/B 视频 FIFO BRAM `.wea` 是 valid 别名，但 `write_go`/`write_address` 还受 FIFO 状态控制。
   - fill-only 负控：写 1024 个唯一地址后 `write_go` 停住、再 1963 拍 blocked；合法 640×480 测试 `blocked=0`、max occ=10。
   - 不能把 `wea=valid` 当作 C/D 无害的证明。

2. **C/D 不再称“唯一丢失机制/已定位永不恢复节点”**
   - C/D 只是 `valid && !(S_video_in_ready && !pro_full)` 的 sticky；
   - 合法 source 时序 + 实际 locked/pause FSM 的 31 相位 × 3 帧扫描：actual reset 全部 lock、无 drop、末态 locked；
   - 帧边界相位偏移最多延迟一帧捕获（first_lock≈420000+offset），第二帧恢复，无 blocked；
   - 只有 FIFO full 时 `wea=valid` 仍高而地址停住才会覆盖/丢数据；合法测试未触发。
   - **具体启动行为**：lock 捕获时 `fifo_rst=!locked` 会吞 1 个首像素（A35390 reset_blocked=1）；first user 在捕获窗口外时先丢整帧（FIRST=10 reset_blocked=307201），下一帧恢复。不是 C/D，也不是永久失锁；若 locked 反复掉锁会重复丢帧。

3. **B 的 `S_fifo_empty` MISSING 不是 empty 逻辑删除**
   - B `I_fifo_rd_en_syn_8` 仍是 LUT4 `(D*~(C*B*A))`：D=period，A/B/C=11 位指针 XNOR empty；
   - BRAM `ceb` 仍接它；B 的固定名 ready/pro_full 节点缺失只是名称层面，不能据此断言整个分支删除。

4. **TLAST 更正**
   - `S_video_in_ready_next = !last && (empty || ready)`，TLAST 被 ready 输出锥消费；
   - 旧 RCA “HDMI 两版都不消费 TLAST”应改为：TLAST 被 ready 输出锥消费，未见数据写口/locked/pause 锥依赖。
   - legacy A 中 ready 输出无观察者，TLAST 随 ready 锥被优化。

5. **物理属性**
   - 视频 FIFO 指针 FF：`SRMODE="ASYNC"`、`sr=I_rst`；BRAM `RESETMODE("SYNC")`。
   - `I_rst = core_reset | !locked`，所以 locked 低/跳变会异步清 FIFO 指针。这是启动/恢复的直接功能路径，但功能模型可恢复，未证明永不恢复；需要 physical/STA recovery-removal 检查。

6. **CDC/等价收窄**
   - “稳定 sticky 经 2FF”不能保证绝对无 CDC 误报；
   - same-cell 函数相同不证明整个实现/布局/到达时间/复位时序全等；A locked 扇出 3 vs Probe 10 正是边界。

## 测试证据

- `astra_reuse/phase_reacquire_sweep.py`：31 偏移 × 3 帧 × 3 初态；actual reset `all_lock_no_drop=true`；扰动初态可额外 drop/re-lock，但无永久失锁；负控（SOL 处去 valid）drops>0。
- `tb_phase_capture4.v`：35360/35390/35392/35464，四个 case 均 lock、drops=0、blocked=0、dup=0、maxocc=10。
- `tb_phase_capture3.v`：FIRST=10/170，first_lock=420011/420171，第二帧恢复，drops=0、blocked=0。
- `tb_fill_addr.v`：writes=1024、dup=0、after_full=1963。

完整报告：`fix_round/axis/REPORT.md`。模型边界：控制模型来自 legacy NoBot mapped（复用），非 A/Probe 专属全锥；无 TMDS/音频/媒体/物理仿真。
