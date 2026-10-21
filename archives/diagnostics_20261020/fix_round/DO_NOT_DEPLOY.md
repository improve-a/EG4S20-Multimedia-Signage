# media_status_001 — 暂不允许上板

这不是生产修复。TD SYN/PNR/BITGEN完成，但最终原始 STA 为 **FAIL**：

- SWNS +0.091 ns；HWNS −2.701 ns；HTNS −37.661 ns。
- 20 个 removal 违规端点，集中在 `rst_all_reg` → `rs_video/pipe_reg[1]` 的物理复制单元 SR；纯 hold 展示最小 +0.035 ns。
- 不以构建 exit0 或生成bit代替 STA通过，不增加例外掩盖结果。
- 已逐 FF 核实为19个第二级reset副本和1个无Q输出单元；既有例外没有覆盖相应物理对象。补充只读分析未取得有效的时序PASS，保留原始FAIL；此项不是原A/B黑屏的已确认原因。

位流：`media_status_001.bit`  
SHA-256：`6a99ffcc463f94c348452cded9fb18c982e09f1faf65a20aa4d95376e6e55166`

本轮未解除部署禁止。仍需解决时序资格问题并另行获得用户硬件授权；不能仅凭“同步器入口”说明自行下载。冻结成功Probe未修改。
