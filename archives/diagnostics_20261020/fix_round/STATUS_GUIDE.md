# media_status_001 状态页（封存，当前DO_NOT_DEPLOY）

此文件是显示编码文档，不是上板许可。该位流原始STA有20个removal违规，尚未取得合格的新验收结果。不能把本版页2–4沿用旧AXIS/帧探针含义。

六位按 `页号.ABCDE` 解释；如实物方向相反，逐行反转后解码。字段为独立同步状态，不是多位原子快照，仅读稳定状态；不从一瞬间变化码推导故障。

| 页 | A | B | C | D | E |
|---|---|---|---|---|---|
| 1 | 当前真实locked | 曾locked | 最近完整稳定窗口且此后未低 | 曾掉锁 | 曾锁定超时 |
| 2 | state_code十六进制 | catalog_ready | display_valid | fifo_fault | sd_init_done |
| 3 | wav_status十六进制 | wav_selected | wav_error | wav_underflow | wav_overflow |
| 4 | 活动页号1–6 | 当前buffer低位 | 0 | 0 | 0 |
| 5 | Sdr_init_done | video_rst | system PLL lock | video PLL lock | 0 |

页2的catalog_ready是消歧关键：

- 错误码优先：A=storage fault，B=目录不足10幅，C=扫描/loader错误，D=响应错误，E=SD初始化错误，F=阶段超时/非法状态。具体优先级以源码`fault_code`和`sd_init_error`为准。
- catalog_ready=0时state_code来自scanner，0可为reset/未就绪，1为空闲/准备，2为头读取/扫描；不能把它直接读成legacy的COVER/LOAD。
- catalog_ready=1时：1=IDLE，2=COVER，3=LOAD，4=COMMIT，5=REVEAL，8=IDLE且auto，9=paused。**8不是SCAN，0不等于已证SCAN。**

主要判别（只有在未来合格的同类诊断版本上）:

- display_valid=0：首图未被确认发布；结合state_code/catalog_ready区分扫描、加载、提交与失败。
- fifo_fault=1：存储fault遮罩有直接状态证据，不再只凭黑屏猜。
- display_valid=1且fifo_fault=0而仍缺主图：反对上述两个控制解释，转查原像素/缓冲读回/其它遮罩；不能直接认定SDRAM坏。
- wav_selected=0：当前为tone回退而非WAV输出；wav_status用于区分未启动、扫描或失败。
- wav_selected=1：选过WAV；异常声音仍需区分样本/欠载/报错，不能单凭audio_valid判成功。

本版没有实时C/D统计。页4固定0的字段不是“没有AXIS冲突”。
