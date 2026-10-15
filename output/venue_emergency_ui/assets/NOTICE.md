# 素材来源与使用说明

- 场序 / VENUE FLOW 品牌标记、界面版式、抽象建筑插画、图标和虚构疏散示意图为本项目原创矢量/程序绘制。没有使用真实学校、指导教师或参赛团队标识；地图不对应真实建筑。
- 六页汉字在 PC 端栅格化到 BMP，不是 FPGA 动态中文字库。完整场景/文本和生成器随包交付。
- A/B 背景声由随包 Python 脚本用数学振荡器合成，没有采样第三方音乐或真实告警录音。它们是演示音轨，不是经过安全认证的公共建筑警报。
- 中文字体 Noto Sans SC 来自 [Google Fonts 官方仓库](https://github.com/google/fonts/tree/main/ofl/notosanssc)，使用 SIL Open Font License 1.1。字体及原许可全文保存在 `fonts/NotoSansSC.ttf` 和 `fonts/OFL.txt`；以实际文件 SHA256 清单为准。
- C_features 的几何测试图及测试音继承本工程既有 `scripts/make_demo_media.py` / `artifacts/demo_media`，用于独立技术验收，保持原素材来源可追溯。
- 未使用外部照片、商标、库存图标或商业音乐。渲染器依赖现有 macOS AppKit/CoreGraphics/Swift；媒体打包与验证使用 Python 标准库，不安装字体到系统、不引入额外运行依赖。
