# Probe 候选 TF 素材部署说明

状态：`NEW_CANDIDATE_HARDWARE_NOT_TESTED`。本轮只生成普通文件，未操作任何实体卡。

## 已准备的文件

Windows 交付目录：
`D:\FPGA\EG4S20-Probe-Audio-Multires\output\probe_audio_multires\delivery\probe_audio_multires_001`

`TF/` 内包含 UI01..UI06、PN01..PN04、07_MUSIC.WAV，以及
`probe_audio_multires_fat32.img`（64 MiB FAT32 离线镜像）。只有 UI06 和 WAV 被替换。

- UI01..UI05：原 640×480；PN01..PN04：原 320×480 独立面板。
- UI06：真正的 800×600、24bpp BI_RGB、bottom-up，像素偏移512。
  FPGA 显示中心 `(80,60)` 起的640×480窗口，**不是完整缩小显示**。
- WAV：16秒、48kHz、16-bit、单声道，支持保留FIFO的连续循环。
- `source_media/UI06_original_800x600.BMP` 保留54字节头的原始图。
  **不要把这个原始版本部署到卡上**；TF/UI06.BMP 才是512偏移的兼容版本。

## 用户后续部署

1. 保留原成功 Probe 位流和原TF卡，另备一张卡；先核对交付 `SHA256SUMS.txt`。
2. 推荐由用户自行把已验证的 `.img` 逐扇区写入备用卡，并读回比对。
   整卡写入会覆盖所选目标卡，请确认盘符/容量；本轮没有执行此操作。
3. 不要把 `.img` 当普通文件复制到卡上，也不要在写镜像后重新复制或移动素材。
4. 本镜像的首UI LBA=2081、UI06 LBA=11086、WAV LBA=17504。
   FPGA扫描物理扇区，不遍历FAT；普通复制/重命名不能保证连续簇和物理发现顺序。
5. 若不用镜像，必须另行验证10张BMP的物理顺序、各文件连续性、首扇区范围及无旧媒体头残留；不能沿用旧卡LBA。

复现素材：在新Windows候选目录运行 `probe_audio_wav.py`、`probe_bmp_media.py`，
再使用 `probe_package_media.py` 指定只读基线、新素材和新的输出目录，最后运行
`no_bot_media_image.py --pack <新目录> --output <新的.img路径>`。完整命令见主交付报告。
