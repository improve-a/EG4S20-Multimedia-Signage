# EG4S20 时序收敛状态

更新：2026-10-16T08:41:19.835319+00:00。Windows唯一执行根 D:\FPGA\EG4S20-Multimedia-Signage，分支 codex/timing-fix；目标HX4S20C / EG4S20BG256，top，TD6.2.168116 Engineer168116。此前HTML轮次的记录保留在Git7325202和原output/html_fidelity/delivery_manifest.json。

本轮正式结果为 BUILD_PASS、TIMING_PASS、REGRESSION_PASS，按FINAL_REPORT记录的离线模型与接口边界验收。FULL_SYSTEM_SIM_NOT_VERIFIED；HARDWARE_NOT_TESTED。没有硬件、JTAG、串口、实体卡或系统/网络配置操作。

最终构建timing_fix_20261016_02，源码aba266bf4ca2bdb347ed947493786cb9b6c00475。SYN、PNR、BITGEN PASS，exit0，690.797秒；两次完整构建共1349.922秒。44项Max/Min组统计零违规，setup/hold/recovery/removal最差分别+0.100/+0.030/+1.653/+0.027ns。残留时钟分类与IO告警已在final_timing_acceptance.json及FINAL_REPORT逐项解释，不能称零告警。

已完成故障同步、reset/mailbox、队头逐拍等价、真实511容量FIFO后台写压力、13项音频、六场景/3500PCM、正常/初始化SPI测试。最终连续显示layered_natural_20261016_153258通过，3972.811秒，1预热+8动作帧、2764800像素、4235383同步检查、2622476配对请求/返回。8帧与旧正式RTL捕获逐字节相同，当前APNG无损且每帧16.8ms；仅为0..117.6ms动作窗口。生产132输入及显示54输入均保持匹配；没有降低分辨率/帧率、关闭音频或移除效果。

最终位流仅使用builds/timing_fix_20261016_02/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit，SHA256 a1492ed343765d27b3984701c29e7251cd279fbcfc7519a1525f68b26faf6f81。best_result为hold修复前中间结果，不交付。

修复实现分别提交于d3716457c5438cd2c2e27ae6e61e3d8701f0bc21和aba266bf4ca2bdb347ed947493786cb9b6c00475；最终报告/测试提交的完整SHA及推送实际结果以output/html_fidelity/timing_fix/delivery_manifest.json与git_push_final.json为准。不再修改生产输入或重复构建。完整产物保留Windows，Mac仅接收文本报告/路径索引。
